import 'dart:io';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import '../../config/theme/app_colors.dart';
import '../../core/models/chat_models.dart';
import '../../core/models/mock_data.dart';
import '../../core/models/expense_models.dart';
import '../../core/services/expense_service.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/maqadi_service.dart';
import '../../core/services/poll_service.dart';
import '../../core/services/user_service.dart';
import '../../core/services/chat_service.dart';
import '../../core/services/album_service.dart';
import '../../core/services/notification_preferences_service.dart';
import '../../core/services/entitlement_service.dart';
import '../../core/services/paywall_service.dart';
import '../../core/services/analytics_event_names.dart';
import '../../core/api/join_request_api.dart';
import '../../core/api/diwaniya_api.dart';
import '../../core/repositories/app_repository.dart';
import '../../core/navigation/app_routes.dart';
import '../../l10n/ar.dart';
import '../maqadi/maqadi_screen.dart';
import '../welcome/join_request_pending_screen.dart';
import '../settings/manager_join_requests_screen.dart';
import 'widgets/home_header_section.dart';
import 'widgets/home_stats_section.dart';
import 'widgets/home_quick_actions_section.dart';
import 'widgets/home_activity_section.dart';
import 'widgets/home_handle.dart';
import 'widgets/home_poll_banner.dart';
import 'widgets/home_notifications_sheet.dart';
import 'widgets/home_members_sheet.dart';
import 'widgets/home_balances_sheet.dart';
import 'widgets/home_polls_sheet.dart';
import 'widgets/home_poll_detail_sheet.dart';
import 'widgets/home_create_poll_sheet.dart';

// ═══════════════════════════════════════════════════════════
// HOME SCREEN
// ═══════════════════════════════════════════════════════════

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _upgradeBannerDismissed = false;
  int _pendingJoinRequestCount = 0;
  bool _isRefreshingHome = false;
  int _refreshGeneration = 0;
  String? _lastUpgradeBannerViewKey;
  @override
  void initState() {
    super.initState();
    dataVersion.addListener(_onDataChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _bootstrapHome();
    });
  }

  @override
  void dispose() {
    dataVersion.removeListener(_onDataChanged);
    super.dispose();
  }

  void _onDataChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _bootstrapHome() async {
    await _refreshHomeData(refreshMemberships: true, showErrors: false);
  }

  Future<void> _refreshHomeData({
    bool refreshMemberships = false,
    bool showErrors = false,
  }) async {
    if (_isRefreshingHome && !refreshMemberships) return;

    final generation = ++_refreshGeneration;
    if (mounted) {
      setState(() => _isRefreshingHome = true);
    }

    try {
      if (refreshMemberships) {
        await AuthService.refreshMembershipsFromServer(
          preferredDiwaniyaId: currentDiwaniyaId,
        );
      }
      if (!mounted || generation != _refreshGeneration) return;

      final did = _diwaniyaId;
      if (did.isEmpty) return;

      await Future.wait<void>([
        MaqadiService.syncForDiwaniya(did, bumpVersion: false)
            .catchError((_) {}),
        AlbumService.syncForDiwaniya(did, bumpVersion: false)
            .catchError((_) {}),
        ExpenseService.syncForDiwaniya(did).catchError((_) {}),
        PollService.syncForDiwaniya(
          did,
          endedLimit: 50,
          recentDays: 30,
          bumpVersion: false,
        ).catchError((_) {}),
        ChatService.syncUnreadSummary(bumpVersion: false).catchError((_) {}),
        ChatService.syncForDiwaniya(
          did,
          bumpVersion: false,
          refreshUnread: false,
        ).catchError((_) {}),
        _syncPendingJoinRequests(did).catchError((_) {}),
        _syncServerNotifications(did).catchError((_) {}),
      ]);

      if (!mounted || generation != _refreshGeneration) return;
      setState(() {});
    } catch (_) {
      if (showErrors && mounted) {
        _snack('تعذر تحديث بيانات الرئيسية');
      }
    } finally {
      if (mounted && generation == _refreshGeneration) {
        setState(() => _isRefreshingHome = false);
      }
    }
  }

  List<DiwaniyaInfo> get _visibleDiwaniyas => _buildSwitcherDiwaniyaList();

  List<DiwaniyaInfo> _buildSwitcherDiwaniyaList() {
    final seen = <String>{};
    final items = <DiwaniyaInfo>[];
    for (final d in allDiwaniyas) {
      final id = d.id.trim();
      if (id.isEmpty || seen.contains(id)) continue;
      seen.add(id);
      items.add(d);
    }
    items.sort((a, b) {
      final aSelected = a.id == currentDiwaniyaId;
      final bSelected = b.id == currentDiwaniyaId;
      if (aSelected != bSelected) return aSelected ? -1 : 1;
      return a.name.trim().compareTo(b.name.trim());
    });
    return items;
  }

  bool get _showUpgradeBanner =>
      _hasDiwaniya && !EntitlementService.isPremium && !_upgradeBannerDismissed;

  Future<void> _openUpgradeFromBanner() async {
    final upgraded = await PaywallService.showFullPaywall(
      context,
      trigger: PaywallTrigger.homeBanner,
    );
    if (!mounted) return;
    if (upgraded) {
      _snack(Ar.premiumActivated);
    }
  }

  void _dismissUpgradeBanner() {
    PaywallService.trackEvent(
      AnalyticsEvents.upgradeBannerDismissed,
      properties: {'source': 'home'},
    );
    setState(() {
      _upgradeBannerDismissed = true;
    });
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _syncPendingJoinRequests(String diwaniyaId) async {
    final normalizedId = diwaniyaId.trim();
    if (normalizedId.isEmpty) {
      if (mounted) setState(() => _pendingJoinRequestCount = 0);
      return;
    }

    try {
      final requests =
          await JoinRequestApi.listPendingForDiwaniya(normalizedId);
      if (!mounted) return;
      setState(() => _pendingJoinRequestCount = requests.length);
    } catch (_) {
      // Non-managers receive 403 here. The home screen should simply hide
      // the manager-review badge rather than showing a technical error.
      if (!mounted) return;
      setState(() => _pendingJoinRequestCount = 0);
    }
  }

  Future<void> _syncServerNotifications(String diwaniyaId) async {
    final did = diwaniyaId.trim();
    if (did.isEmpty) return;

    final personal = await DiwaniyaApi.getMyNotifications();
    final feed = await DiwaniyaApi.getFeed(did);
    final feedActivitiesRaw = feed['activities'];
    final Iterable<Map<String, dynamic>> feedActivities =
        feedActivitiesRaw is List
            ? feedActivitiesRaw
                .whereType<Map>()
                .map((e) => Map<String, dynamic>.from(e))
            : const <Map<String, dynamic>>[];

    final activityMapped = <DiwaniyaActivity>[];
    final seenActivityIds = <String>{};
    for (final raw in feedActivities) {
      final id = (raw['id'] ?? '').toString().trim();
      final message = (raw['message'] ?? '').toString().trim();
      if (id.isEmpty || message.isEmpty || !seenActivityIds.add(id)) continue;
      final type = (raw['type'] ?? 'activity').toString();
      activityMapped.add(
        DiwaniyaActivity(
          type: type,
          diwaniyaId: did,
          actor: (raw['actor'] ?? '').toString(),
          message: message,
          createdAt: DateTime.tryParse((raw['created_at'] ?? '').toString()) ??
              DateTime.now(),
          icon: _activityIcon(type),
          iconColor: _activityColor(type),
        ),
      );
    }
    if (activityMapped.isNotEmpty) {
      activityMapped.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      diwaniyaActivities[did] = activityMapped.take(80).toList();
      await AppRepository.saveActivities();
    }

    final feedNotificationsRaw = feed['notifications'];
    final Iterable<Map<String, dynamic>> feedNotifications =
        feedNotificationsRaw is List
            ? feedNotificationsRaw
                .whereType<Map>()
                .map((e) => Map<String, dynamic>.from(e))
            : const <Map<String, dynamic>>[];

    final activeDiwaniyaIds = allDiwaniyas
        .map((d) => d.id.trim())
        .where((id) => id.isNotEmpty)
        .toSet();
    final incomingPersonal = personal.where((n) {
      final notificationDiwaniyaId =
          ((n['diwaniya_id'] ?? '').toString().trim());
      final type = (n['type'] ?? '').toString();
      if (notificationDiwaniyaId == did) return true;

      // Rejected join requests belong to a diwaniya the user is not a member of,
      // so they may not have a matching home context after login. Surface them
      // in the current notification sheet rather than dropping them silently.
      return type.contains('join_request_rejected') &&
          !activeDiwaniyaIds.contains(notificationDiwaniyaId);
    });

    final incoming = <Map<String, dynamic>>[
      ...feedNotifications,
      ...incomingPersonal,
    ];
    if (incoming.isEmpty) return;

    final existing = diwaniyaNotifications[did] ?? <DiwaniyaNotification>[];
    final existingById = {for (final n in existing) n.id: n};

    final mapped = <DiwaniyaNotification>[];
    for (final raw in incoming) {
      final id = (raw['id'] ?? '').toString().trim();
      final message = (raw['message'] ?? '').toString().trim();
      if (id.isEmpty || message.isEmpty) continue;
      final type = (raw['type'] ?? 'activity').toString();
      final old = existingById[id];
      mapped.add(
        DiwaniyaNotification(
          id: id,
          diwaniyaId: did,
          message: message,
          type: type,
          createdAt: DateTime.tryParse((raw['created_at'] ?? '').toString()) ??
              DateTime.now(),
          isRead: old?.isRead ?? (raw['is_read'] == true),
          icon: _notificationIcon(type),
          iconColor: _notificationColor(type),
          referenceId: raw['reference_id']?.toString(),
        ),
      );
    }

    final mergedById = {for (final n in existing) n.id: n};
    for (final n in mapped) {
      mergedById[n.id] = n;
    }
    final merged = mergedById.values.toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    diwaniyaNotifications[did] = merged.take(80).toList();
    await AppRepository.saveNotifications();
  }

  IconData _activityIcon(String type) {
    if (type.contains('poll')) return Icons.how_to_vote_rounded;
    if (type.contains('album') || type.contains('photo')) {
      return Icons.photo_library_rounded;
    }
    if (type.contains('maqadi') || type.contains('shopping')) {
      return Icons.shopping_cart_rounded;
    }
    if (type.contains('expense') || type.contains('settlement')) {
      return Icons.account_balance_wallet_rounded;
    }
    if (type.contains('member') || type.contains('join')) {
      return Icons.groups_rounded;
    }
    return Icons.history_rounded;
  }

  Color _activityColor(String type) {
    if (type.contains('removed') || type.contains('deleted')) {
      return const Color(0xFFF87171);
    }
    if (type.contains('maqadi') || type.contains('shopping')) {
      return const Color(0xFFFBBF24);
    }
    if (type.contains('poll')) return const Color(0xFF60A5FA);
    if (type.contains('album') || type.contains('photo')) {
      return const Color(0xFF34D399);
    }
    return const Color(0xFF60A5FA);
  }

  IconData _notificationIcon(String type) {
    if (type.contains('approved')) return Icons.check_circle_rounded;
    if (type.contains('rejected')) return Icons.cancel_rounded;
    if (type.contains('removed')) return Icons.person_remove_rounded;
    if (type.contains('join')) return Icons.group_add_rounded;
    return Icons.notifications_active_rounded;
  }

  Color _notificationColor(String type) {
    if (type.contains('approved')) return const Color(0xFF34D399);
    if (type.contains('rejected') || type.contains('removed')) {
      return const Color(0xFFF87171);
    }
    return const Color(0xFF60A5FA);
  }

  void _openMyJoinRequests() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const JoinRequestPendingScreen(
          autoRedirectWhenResolved: false,
        ),
      ),
    );
  }

  Future<void> _capturePhotoQuick() async {
    if (!_hasDiwaniya) {
      return;
    }

    // Free-tier photo limit gate — check BEFORE opening the camera so the
    // user isn't asked to take a photo only to have it rejected.
    final photoLimitStatus = EntitlementService.checkPhotoLimit(_diwaniyaId);
    if (photoLimitStatus == LimitStatus.atLimit) {
      PaywallService.trackEvent(
        AnalyticsEvents.photoLimitHit,
        properties: {
          'source': 'home_quick_capture',
          'diwaniyaId': _diwaniyaId,
          'count': _albumCount,
        },
      );

      final upgraded = await PaywallService.showContextualPaywall(
        context,
        trigger: PaywallTrigger.photoLimit,
        title: 'ذكرياتك غالية 📸',
        message:
            'وصلت الحد الأقصى (10 صور) في الباقة المجانية.\nترقّى واحتفظ بكل لحظة بدون قيود.',
        icon: Icons.photo_library_rounded,
      );

      if (!mounted) return;
      if (!upgraded) {
        _snack('تم إيقاف الحفظ حتى تتم الترقية');
        return;
      }

      _snack(Ar.premiumActivated);
    }

    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 82,
    );
    if (picked == null) {
      return;
    }

    if (!mounted) return;

    final dir = await getApplicationDocumentsDirectory();
    final imgDir = Directory('${dir.path}/album_images');
    if (!await imgDir.exists()) {
      await imgDir.create(recursive: true);
    }

    final saved = await File(picked.path).copy(
      '${imgDir.path}/album_${_diwaniyaId}_${DateTime.now().millisecondsSinceEpoch}.jpg',
    );

    try {
      await AlbumService.uploadPhoto(
        saved,
        diwaniyaId: _diwaniyaId,
      );
      if (!mounted) return;
      _addActivity(
        'album_photo_added',
        UserService.currentName,
        'تمت إضافة صورة جديدة إلى الألبوم',
        Icons.photo_library_rounded,
        const Color(0xFF34D399),
      );
      _addNotif(
        'صورة جديدة أضيفت إلى الألبوم',
        'album',
        Icons.photo_library_rounded,
        const Color(0xFF34D399),
      );
      await _persistHomeFeed();
      if (!mounted) return;
      setState(() {});
      _snack('تم حفظ الصورة في الألبوم');
    } catch (_) {
      if (!mounted) return;
      _snack('تعذر رفع الصورة');
    }
  }

  String get _diwaniyaId {
    final resolved =
        _visibleDiwaniyas.where((d) => d.id == currentDiwaniyaId).firstOrNull;
    if (resolved != null) {
      return currentDiwaniyaId;
    }

    if (_visibleDiwaniyas.isNotEmpty) {
      currentDiwaniyaId = _visibleDiwaniyas.first.id;
      AppRepository.saveSelectedDiwaniya(currentDiwaniyaId);
      return currentDiwaniyaId;
    }

    if (currentDiwaniyaId.isNotEmpty) {
      currentDiwaniyaId = '';
      AppRepository.saveSelectedDiwaniya('');
    }
    return '';
  }

  DiwaniyaInfo? get _diw =>
      _visibleDiwaniyas.where((d) => d.id == _diwaniyaId).firstOrNull;
  // Crash guard: require that the current diwaniya id actually resolves
  // to a DiwaniyaInfo. Protects against stale currentDiwaniyaId pointing
  // at a diwaniya that was removed, failed to sync, or never hydrated.
  bool get _hasDiwaniya => _diwaniyaId.isNotEmpty && _diw != null;
  List<DiwaniyaMember> get _members => diwaniyaMembers[_diwaniyaId] ?? [];
  List<DiwaniyaPoll> get _polls => diwaniyaPolls[_diwaniyaId] ?? [];
  List<DiwaniyaActivity> get _activities =>
      diwaniyaActivities[_diwaniyaId] ?? [];
  List<DiwaniyaNotification> get _notifs =>
      diwaniyaNotifications[_diwaniyaId] ?? [];
  List<MockShoppingItem> get _maqadiItems =>
      diwaniyaShoppingItems[_diwaniyaId] ?? [];
  List<Debt> get _debts => ExpenseService.optimized(_diwaniyaId);

  DiwaniyaPoll? get _activePoll => _polls.where((p) => p.isActive).firstOrNull;
  int get _activePolls => _polls.where((p) => p.isActive).length;
  int get _maqadiNeeded =>
      _maqadiItems.where((i) => i.status == 'needed').length;
  int get _unreadNotifs =>
      _notifs.where((n) => !n.isRead && n.type != 'chat').length;
  double get _myBalance =>
      ExpenseService.balanceFor(UserService.currentName, _diwaniyaId);
  int get _chatUnread => ChatService.unreadCount(_diwaniyaId);

  ChatMessage? get _lastChatMessage => ChatService.lastMessage(_diwaniyaId);

  String? get _chatSender => _lastChatMessage?.senderName;

  String? get _chatPreview {
    final last = _lastChatMessage;
    if (last == null) return null;
    if (last.messageType == 'image' &&
        (last.text == null || last.text!.trim().isEmpty)) {
      return 'أرسل صورة';
    }
    final text = (last.text ?? '').trim();
    if (text.isEmpty) {
      return 'رسالة جديدة';
    }
    return text.length > 56 ? '${text.substring(0, 56)}...' : text;
  }

  int get _albumCount => AlbumService.activePhotos(_diwaniyaId).length;

  void _showDiwaniyaLimitDialog() {
    final c = context.cl;
    showDialog(
      context: context,
      builder: (d) => AlertDialog(
        backgroundColor: c.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Text(
          'تعذر إنشاء ديوانية جديدة',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: c.t1,
          ),
        ),
        content: Text(
          'بلغتم الحد المتاح من الديوانيات ضمن الباقة الحالية. يمكنكم الانضمام إلى ديوانية قائمة برمز الدعوة، أو الترقية للاستفادة من سعة أعلى وإدارة أوسع.',
          style: TextStyle(
            fontSize: 14,
            height: 1.8,
            color: c.t2,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(d);
              context.push(AppRoutes.joinDiwaniya);
            },
            child: Text(
              'الانضمام لديوانية',
              style: TextStyle(
                color: c.accent,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(d),
            child: Text(
              Ar.cancel,
              style: TextStyle(color: c.t3),
            ),
          ),
        ],
      ),
    );
  }

  void _openCreateDiwaniyaOrWarn() {
    final status = EntitlementService.checkDiwaniyaLimit();
    Navigator.pop(context);
    if (status == LimitStatus.atLimit) {
      Future.microtask(_showDiwaniyaLimitDialog);
      return;
    }
    context.push(AppRoutes.createDiwaniya);
  }

  void _openJoinDiwaniyaFromSwitcher() {
    Navigator.pop(context);
    context.push(AppRoutes.joinDiwaniya);
  }

  // مساحة محجوزة لاحقًا للبطاقات العامة مثل:
  // - إعلانات يضيفها مدير النظام وتظهر لجميع المستخدمين
  // - تصويتات عامة مشتركة على مستوى التطبيق
  List<Widget> _buildGlobalSpotlightCards(BuildContext context) {
    return const [];
  }

  bool get _hasGlobalSpotlights =>
      _buildGlobalSpotlightCards(context).isNotEmpty;

  Future<void> _switchDiwaniya() async {
    final c = context.cl;
    final refreshed = await AuthService.refreshMembershipsFromServer(
      preferredDiwaniyaId: currentDiwaniyaId,
    );
    if (mounted && refreshed) {
      setState(() {});
    }
    if (!mounted) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => SafeArea(
        top: false,
        child: FractionallySizedBox(
          heightFactor: 0.82,
          child: Container(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
            decoration: BoxDecoration(
              color: c.card,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Column(
              children: [
                HomeHandle(c),
                const SizedBox(height: 16),
                Text(
                  Ar.switchDiwaniya,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: c.t1,
                  ),
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: _visibleDiwaniyas.isEmpty
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 18),
                            child: Text(
                              'لا توجد ديوانيات حالية. ابدأ بإنشاء ديوانيتك الأولى.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 14,
                                color: c.t3,
                                height: 1.7,
                              ),
                            ),
                          ),
                        )
                      : ListView.separated(
                          padding: EdgeInsets.zero,
                          itemCount: _visibleDiwaniyas.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 8),
                          itemBuilder: (_, index) {
                            final d = _visibleDiwaniyas[index];
                            final sel = d.id == _diwaniyaId;
                            final cnt = AuthService.memberCountFor(d.id,
                                fallback: d.memberCount);
                            return GestureDetector(
                              onTap: () async {
                                final navigator = Navigator.of(context);
                                await AuthService.switchSelectedDiwaniya(d.id);
                                if (!mounted) return;
                                await _refreshHomeData(showErrors: false);
                                if (!mounted) return;
                                navigator.pop();
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 14,
                                ),
                                decoration: BoxDecoration(
                                  color: sel ? c.accentMuted : c.inputBg,
                                  borderRadius: BorderRadius.circular(14),
                                  border: sel
                                      ? Border.all(
                                          color:
                                              c.accent.withValues(alpha: 0.4),
                                        )
                                      : null,
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 40,
                                      height: 40,
                                      decoration: BoxDecoration(
                                        color: d.color.withValues(alpha: 0.15),
                                        borderRadius: BorderRadius.circular(11),
                                      ),
                                      child: Center(
                                        child: Text(
                                          d.name.trim().isEmpty
                                              ? 'د'
                                              : d.name.trim().substring(0, 1),
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w800,
                                            color: d.color,
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            d.name,
                                            style: TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w600,
                                              color: sel ? c.accent : c.t1,
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            '${d.district} · $cnt عضو',
                                            style: TextStyle(
                                                fontSize: 12, color: c.t3),
                                          ),
                                        ],
                                      ),
                                    ),
                                    if (sel)
                                      Icon(
                                        Icons.check_circle_rounded,
                                        size: 20,
                                        color: c.accent,
                                      ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _SwitchActionCard(
                        title: 'إنشاء ديوانية',
                        subtitle:
                            'بدء ديوانية جديدة وإصدار رمز الدعوة الخاص بها',
                        icon: Icons.add_rounded,
                        onTap: _openCreateDiwaniyaOrWarn,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _SwitchActionCard(
                        title: 'الانضمام لديوانية',
                        subtitle: 'الدخول إلى ديوانية قائمة عبر رمز الدعوة',
                        icon: Icons.login_rounded,
                        onTap: _openJoinDiwaniyaFromSwitcher,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _openNotifications() {
    final list = diwaniyaNotifications[_diwaniyaId];
    if (list != null) {
      final updated = list
          .map(
            (n) => DiwaniyaNotification(
              id: n.id,
              diwaniyaId: n.diwaniyaId,
              message: n.message,
              type: n.type,
              createdAt: n.createdAt,
              isRead: true,
              icon: n.icon,
              iconColor: n.iconColor,
              referenceId: n.referenceId,
            ),
          )
          .toList();
      diwaniyaNotifications[_diwaniyaId] = updated;
      AppRepository.saveNotifications();
    }

    setState(() {});

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => HomeNotificationsSheet(
        notifs: (diwaniyaNotifications[_diwaniyaId] ?? [])
            .where((n) => n.type != 'chat')
            .toList(),
        onTap: _onNotificationTap,
      ),
    );
  }

  void _openMembers() {
    final diw = _diw;
    if (diw == null) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => HomeMembersSheet(
        members: _members,
        managerId: diw.managerId,
        onAddMember: () {
          Navigator.of(context).pop();
          // Free-tier member limit gate
          final status = EntitlementService.checkMemberLimit(_diwaniyaId);
          if (status == LimitStatus.atLimit) {
            PaywallService.trackEvent(
              AnalyticsEvents.memberLimitHit,
              properties: {'diwaniyaId': _diwaniyaId},
            );
            PaywallService.showContextualPaywall(
              context,
              trigger: PaywallTrigger.memberLimit,
              title: 'حد الأعضاء للنسخة المجانية',
              message:
                  'الخطة المجانية تسمح بـ ${EntitlementService.freeMaxMembers} أعضاء. للترقية اضغط على زر الترقية.',
              icon: Icons.groups_rounded,
            );
            return;
          }
          context.push(
            AppRoutes.inviteMember,
            extra: InviteMemberArgs(
              diwaniyaName: diw.name,
              invitationCode: diw.invitationCode ?? '',
            ),
          );
        },
      ),
    );
  }

  void _openBalances() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => HomeBalancesSheet(
        debts: _debts,
        onSettle: _settleBalance,
      ),
    );
  }

  Future<void> _openPolls() async {
    final did = _diwaniyaId;
    if (did.isEmpty) return;

    try {
      await PollService.syncForDiwaniya(
        did,
        endedLimit: 50,
        recentDays: 30,
        bumpVersion: false,
      );
      if (!mounted) return;
      setState(() {});
    } catch (_) {
      if (!mounted) return;
      _snack('تعذر تحديث التصويتات');
    }

    if (!mounted) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => HomePollsSheet(
        polls: _polls,
        onCreatePoll: () {
          Navigator.of(sheetContext).pop();
          Future.microtask(() {
            if (!mounted) return;
            _openCreatePoll();
          });
        },
        onTapPoll: (poll) {
          Navigator.of(sheetContext).pop();
          Future.microtask(() {
            if (!mounted) return;
            _openPollDetail(poll);
          });
        },
      ),
    );
  }

  void _openPollDetail(DiwaniyaPoll poll) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => HomePollDetailSheet(
        poll: poll,
        isManager: UserService.isManager(),
        onVote: (option) => _votePoll(poll.id, option),
        onEnd: () => _endPoll(poll.id),
      ),
    );
  }

  Future<void> _votePoll(String pollId, String option) async {
    final did = _diwaniyaId;
    if (did.isEmpty) return;

    final before = _polls.where((p) => p.id == pollId).firstOrNull;
    final previousVote = before?.votedMembers[UserService.currentName];
    final isChange = previousVote != null && previousVote != option;
    if (previousVote == option) return;

    Navigator.pop(context);

    try {
      await PollService.vote(did, pollId, option);
      if (!mounted) return;

      final poll = _polls.where((p) => p.id == pollId).firstOrNull;
      if (poll != null) {
        final name = UserService.currentName;
        if (isChange) {
          _addActivity(
            'vote_changed',
            name,
            '$name عدّل صوته — ${poll.question}',
            Icons.how_to_vote_outlined,
            const Color(0xFFFB923C),
          );
          _addNotif(
            '$name عدّل صوته في "${poll.question}"',
            'poll',
            Icons.how_to_vote_outlined,
            const Color(0xFFFB923C),
            referenceId: pollId,
          );
        } else {
          _addActivity(
            'vote_submitted',
            name,
            '$name صوّت — ${poll.question}',
            Icons.how_to_vote_outlined,
            const Color(0xFF38BDF8),
          );
          _addNotif(
            '$name صوّت في "${poll.question}"',
            'poll',
            Icons.how_to_vote_outlined,
            const Color(0xFF38BDF8),
            referenceId: pollId,
          );
        }
      }

      await _persistHomeFeed();
      if (!mounted) return;
      setState(() {});

      Future.microtask(() {
        if (!mounted) return;
        final updated = _polls.where((p) => p.id == pollId).firstOrNull;
        if (updated != null) {
          _openPollDetail(updated);
        }
      });
    } catch (_) {
      if (!mounted) return;
      _snack('تعذر تسجيل التصويت. تحقق من الاتصال وحاول مرة أخرى');
      await PollService.syncForDiwaniya(did, bumpVersion: false)
          .catchError((_) {});
      if (mounted) setState(() {});
    }
  }

  void _endPoll(String pollId) {
    Navigator.pop(context);
    showDialog(
      context: context,
      builder: (d) {
        final dc = d.cl;
        return AlertDialog(
          backgroundColor: dc.card,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Text(
            Ar.endPoll,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: dc.t1,
            ),
          ),
          content: Text(
            Ar.endPollConfirm,
            style: TextStyle(color: dc.t2),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(d),
              child: Text(
                Ar.cancel,
                style: TextStyle(color: dc.t2),
              ),
            ),
            TextButton(
              onPressed: () async {
                Navigator.pop(d);
                final did = _diwaniyaId;
                if (did.isEmpty) return;

                try {
                  await PollService.close(did, pollId);
                  if (!mounted) return;

                  final poll = _polls.where((p) => p.id == pollId).firstOrNull;
                  if (poll != null) {
                    final name = UserService.currentName;
                    _addActivity(
                      'poll_ended',
                      name,
                      'تم إنهاء التصويت — ${poll.question}',
                      Icons.how_to_vote_rounded,
                      const Color(0xFFF87171),
                    );
                    _addNotif(
                      'تم إنهاء التصويت — ${poll.question}',
                      'poll',
                      Icons.how_to_vote_rounded,
                      const Color(0xFFF87171),
                      referenceId: pollId,
                    );
                  }

                  await _persistHomeFeed();
                  if (!mounted) return;
                  setState(() {});
                } catch (_) {
                  if (!mounted) return;
                  _snack('تعذر إنهاء التصويت. تحقق من الاتصال وحاول مرة أخرى');
                  await PollService.syncForDiwaniya(did, bumpVersion: false)
                      .catchError((_) {});
                  if (mounted) setState(() {});
                }
              },
              child: Text(
                Ar.confirm,
                style: TextStyle(
                  color: dc.error,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  void _openCreatePoll() {
    // Free-tier active poll limit gate
    final status = EntitlementService.checkPollLimit(_diwaniyaId);
    if (status == LimitStatus.atLimit) {
      PaywallService.trackEvent(
        AnalyticsEvents.pollLimitHit,
        properties: {'diwaniyaId': _diwaniyaId},
      );
      PaywallService.showContextualPaywall(
        context,
        trigger: PaywallTrigger.pollLimit,
        title: 'حد التصويتات النشطة',
        message:
            'الخطة المجانية تسمح بتصويت نشط واحد فقط. أغلق تصويتًا حاليًا أو رقّ الديوانية.',
        icon: Icons.how_to_vote_rounded,
      );
      return;
    }
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => HomeCreatePollSheet(
        onSave: (q, opts) async {
          final did = _diwaniyaId;
          if (did.isEmpty) return;

          try {
            final created = await PollService.createPoll(
              did,
              question: q,
              options: opts,
            );
            if (!mounted) return;

            _addActivity(
              'poll_created',
              UserService.currentName,
              'تصويت جديد — $q',
              Icons.how_to_vote_rounded,
              const Color(0xFF60A5FA),
            );
            _addNotif(
              'تصويت جديد — $q',
              'poll',
              Icons.how_to_vote_rounded,
              const Color(0xFF60A5FA),
              referenceId: created.id,
            );

            await _persistHomeFeed();
            if (!mounted) return;
            setState(() {});
            _snack('تم إنشاء التصويت');
          } catch (_) {
            if (!mounted) return;
            _snack('تعذر إنشاء التصويت. تحقق من الاتصال وحاول مرة أخرى');
          }
        },
      ),
    );
  }

  void _openAlbum() {
    context.push(AppRoutes.album);
  }

  void _addActivity(
    String type,
    String actor,
    String message,
    IconData icon,
    Color iconColor,
  ) {
    addGlobalActivity(_diwaniyaId, type, actor, message, icon, iconColor);
  }

  void _addNotif(
    String message,
    String type,
    IconData icon,
    Color iconColor, {
    String? referenceId,
  }) {
    if (type == 'chat') return;
    if (!NotificationPreferencesService.isTypeAllowed(type)) {
      return;
    }
    addGlobalNotification(
      _diwaniyaId,
      message,
      type,
      icon,
      iconColor,
      referenceId: referenceId,
    );
  }

  Future<void> _persistHomeFeed() async {
    final did = _diwaniyaId;
    if (did.isEmpty) return;

    final activities = diwaniyaActivities[did];
    if (activities != null && activities.length > 80) {
      diwaniyaActivities[did] = activities.take(80).toList();
    }

    final notifications = diwaniyaNotifications[did];
    if (notifications != null && notifications.length > 80) {
      diwaniyaNotifications[did] = notifications.take(80).toList();
    }

    await AppRepository.saveActivities();
    await AppRepository.saveNotifications();
  }

  Future<void> _settleBalance(Debt bal) async {
    final actor = UserService.currentName;
    setState(() {
      ExpenseService.addSettlement(bal.from, bal.to, bal.amount);
    });

    _addActivity(
      'settlement_created',
      actor,
      'تم تسجيل تسوية مالية بين ${bal.from} و ${bal.to}',
      Icons.account_balance_wallet_rounded,
      const Color(0xFF34D399),
    );
    _addNotif(
      'تم تسجيل تسوية مالية جديدة',
      'settlement',
      Icons.account_balance_wallet_rounded,
      const Color(0xFF34D399),
    );

    await AppRepository.saveExpenses();
    await _persistHomeFeed();
    if (!mounted) return;
    Navigator.pop(context);
    Future.microtask(() => _openBalances());
  }

  void _onNotificationTap(DiwaniyaNotification n) {
    Navigator.pop(context);
    switch (n.type) {
      case 'expense':
        context.go(AppRoutes.expenses);
        return;
      case 'poll':
        final poll = n.referenceId != null
            ? _polls.where((p) => p.id == n.referenceId).firstOrNull
            : _polls.where((p) => p.isActive).firstOrNull;
        if (poll != null) {
          _openPollDetail(poll);
        } else {
          _openPolls();
        }
        return;
      case 'maqadi':
        context.go(AppRoutes.maqadi);
        return;
      case 'settlement':
        _openBalances();
        return;
      case 'member':
        _openMembers();
        return;
      default:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.cl;

    if (!_hasDiwaniya || _diw == null) {
      return Scaffold(
        backgroundColor: c.bg,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: c.accent.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Icon(
                    Icons.groups_outlined,
                    size: 36,
                    color: c.accent,
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  'ابدأ بإنشاء ديوانيتك الأولى',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: c.t1,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'ليس لديك أي ديوانية حالية. أنشئ ديوانية جديدة أو انضم إلى ديوانية موجودة عبر رمز الدعوة.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.8,
                    color: c.t3,
                  ),
                ),
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () => context.push(AppRoutes.createDiwaniya),
                    icon: const Icon(Icons.add_rounded),
                    label: const Text('إنشاء ديوانيتي الأولى'),
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () => context.push(AppRoutes.joinDiwaniya),
                    icon: const Icon(Icons.login_rounded),
                    label: const Text('الانضمام برمز دعوة'),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final diw = _diw!;
    final bal = _myBalance;
    final balStr = bal >= 0 ? '+${bal.toInt()}' : '${bal.toInt()}';

    if (_showUpgradeBanner) {
      final bannerKey = 'home:$_diwaniyaId:${EntitlementService.isPremium}';
      if (_lastUpgradeBannerViewKey != bannerKey) {
        _lastUpgradeBannerViewKey = bannerKey;
        PaywallService.trackEvent(
          AnalyticsEvents.upgradeBannerViewed,
          properties: {'source': 'home', 'diwaniyaId': _diwaniyaId},
        );
      }
    }

    return Scaffold(
      backgroundColor: c.bg,
      body: RefreshIndicator(
        onRefresh: () => _refreshHomeData(
          refreshMemberships: true,
          showErrors: true,
        ),
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverAppBar(
              floating: true,
              snap: true,
              backgroundColor: c.bg,
              surfaceTintColor: Colors.transparent,
              toolbarHeight: 64,
              title: HomeHeaderSection(
                diwaniyaName: diw.name,
                district: diw.district,
                unreadNotifs: _unreadNotifs,
                myJoinRequestCount: AuthService.pendingJoinRequests
                    .where((r) => r.isPending)
                    .length,
                onSwitchDiwaniya: _switchDiwaniya,
                onOpenSettings: () => context.push(AppRoutes.settings),
                onOpenNotifications: _openNotifications,
                onOpenMyRequests: _openMyJoinRequests,
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              sliver: SliverList(
                delegate: SliverChildListDelegate(
                  [
                    const SizedBox(height: 8),
                    ..._buildGlobalSpotlightCards(context),
                    if (_hasGlobalSpotlights) const SizedBox(height: 12),
                    if (_pendingJoinRequestCount > 0) ...[
                      _HomeJoinRequestManagerBadge(
                        count: _pendingJoinRequestCount,
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => ManagerJoinRequestsScreen(
                              diwaniyaId: _diwaniyaId,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                    if (_activePoll != null)
                      GestureDetector(
                        onTap: _openPolls,
                        child: HomePollBanner(
                          poll: _activePoll!,
                          activeCount: _activePolls,
                        ),
                      )
                    else
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: c.card,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: c.border),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 38,
                              height: 38,
                              decoration: BoxDecoration(
                                color: c.inputBg,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(
                                Icons.how_to_vote_outlined,
                                size: 18,
                                color: c.t3,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'لا يوجد تصويت قائم حاليًا',
                                style: TextStyle(
                                  fontSize: 12.8,
                                  color: c.t3,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    const SizedBox(height: 16),
                    if (_showUpgradeBanner) ...[
                      _HomeUpgradeBanner(
                        onTap: _openUpgradeFromBanner,
                        onDismiss: _dismissUpgradeBanner,
                      ),
                      const SizedBox(height: 16),
                    ],
                    HomeStatsSection(
                      memberCount: _members.length,
                      balanceStr: balStr,
                      balanceColor: bal >= 0 ? c.success : c.error,
                      activePolls: _activePolls,
                      maqadiNeeded: _maqadiNeeded,
                      chatPreview: _chatPreview,
                      chatSender: _chatSender,
                      chatUnread: _chatUnread,
                      albumCount: _albumCount,
                      onOpenMembers: _openMembers,
                      onOpenBalances: _openBalances,
                      onOpenPolls: _openPolls,
                      onOpenMaqadi: () => Navigator.of(context).push(
                        MaterialPageRoute(
                            builder: (_) =>
                                const MaqadiScreen(initialFilter: 'needed')),
                      ),
                      onOpenChat: () => context.push(AppRoutes.chat),
                      onOpenAlbum: _openAlbum,
                    ),
                    const SizedBox(height: 24),
                    HomeQuickActionsSection(
                      onAddExpense: () => context.go(AppRoutes.expenses),
                      onCreatePoll: _openCreatePoll,
                      onAddMaqadi: () => context.go(AppRoutes.maqadi),
                      onCapturePhoto: _capturePhotoQuick,
                    ),
                    const SizedBox(height: 24),
                    HomeActivitySection(
                        activities: _activities
                            .where((a) => !a.type.startsWith('chat'))
                            .toList()),
                    const SizedBox(height: 100),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HomeJoinRequestManagerBadge extends StatelessWidget {
  final int count;
  final VoidCallback onTap;

  const _HomeJoinRequestManagerBadge({
    required this.count,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.cl;
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: c.accent.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: c.accent.withValues(alpha: 0.18)),
        ),
        child: Row(
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Icon(Icons.person_add_alt_1_rounded, color: c.accent),
                PositionedDirectional(
                  top: -8,
                  end: -10,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: c.error,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      '$count',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                count == 1
                    ? 'يوجد طلب انضمام بانتظار مراجعتك'
                    : 'يوجد $count طلبات انضمام بانتظار مراجعتك',
                style: TextStyle(
                  color: c.t1,
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            Icon(Icons.chevron_left_rounded, color: c.t2),
          ],
        ),
      ),
    );
  }
}

class _HomeUpgradeBanner extends StatelessWidget {
  final VoidCallback onTap;
  final VoidCallback onDismiss;

  const _HomeUpgradeBanner({
    required this.onTap,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.cl;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            c.accent.withValues(alpha: 0.16),
            c.accent.withValues(alpha: 0.08),
          ],
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: c.accent.withValues(alpha: 0.18)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: c.accent.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              Icons.workspace_premium_rounded,
              color: c.accent,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'ارتقِ بإدارة الديوانية',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: c.t1,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'صور أكثر، سعة أعلى للأعضاء، ومزايا تنظيمية أوسع عند الحاجة.',
                  style: TextStyle(
                    fontSize: 12.5,
                    color: c.t2,
                    height: 1.55,
                  ),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: onTap,
                  style: TextButton.styleFrom(
                    padding: EdgeInsets.zero,
                    minimumSize: const Size(0, 0),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: const Text('الترقية'),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            onPressed: onDismiss,
            icon: Icon(Icons.close_rounded, size: 18, color: c.t3),
            tooltip: Ar.notNow,
          ),
        ],
      ),
    );
  }
}

class _SwitchActionCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;

  const _SwitchActionCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.cl;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: c.accent.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: c.accent.withValues(alpha: 0.18)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: c.accentMuted,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, size: 22, color: c.accent),
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: c.accent,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 12,
                height: 1.6,
                color: c.t2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
