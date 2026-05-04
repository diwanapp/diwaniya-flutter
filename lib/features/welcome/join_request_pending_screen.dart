import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../config/theme/app_colors.dart';
import '../../core/api/join_request_api.dart';
import '../../core/models/join_request.dart';
import '../../core/navigation/app_routes.dart';
import '../../core/services/auth_service.dart';
import '../../l10n/ar.dart';

class JoinRequestPendingScreen extends StatefulWidget {
  const JoinRequestPendingScreen({super.key});

  @override
  State<JoinRequestPendingScreen> createState() =>
      _JoinRequestPendingScreenState();
}

enum _JoinRequestFilter { all, pending, resolved }

class _JoinRequestPendingScreenState extends State<JoinRequestPendingScreen> {
  bool _loading = false;
  String? _errorMessage;
  _JoinRequestFilter _filter = _JoinRequestFilter.all;
  late List<JoinRequest> _requests;

  @override
  void initState() {
    super.initState();
    _requests = _sorted(AuthService.pendingJoinRequests);
    WidgetsBinding.instance.addPostFrameCallback((_) => _refresh());
  }

  List<JoinRequest> _sorted(Iterable<JoinRequest> source) {
    final list = source.toList();
    list.sort((a, b) => b.requestedAt.compareTo(a.requestedAt));
    return list;
  }

  Future<void> _refresh() async {
    if (_loading) return;
    setState(() {
      _loading = true;
      _errorMessage = null;
    });

    try {
      final rows = await JoinRequestApi.getMyJoinRequests();
      final parsed = _sorted(rows.map(JoinRequest.fromJson));
      AuthService.pendingJoinRequests
        ..clear()
        ..addAll(parsed);

      if (parsed.any((r) => r.isApproved)) {
        await AuthService.refreshMembershipsFromServer();
      }

      if (!mounted) return;
      setState(() {
        _requests = parsed;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _errorMessage = 'تعذر تحديث طلبات الانضمام';
      });
    }
  }

  List<JoinRequest> get _visibleRequests {
    switch (_filter) {
      case _JoinRequestFilter.pending:
        return _requests.where((r) => r.isPending).toList();
      case _JoinRequestFilter.resolved:
        return _requests.where((r) => !r.isPending).toList();
      case _JoinRequestFilter.all:
        return _requests;
    }
  }

  JoinRequest? get _latestResolvedRequest {
    final resolved = _requests.where((r) => !r.isPending).toList();
    if (resolved.isEmpty) return null;
    resolved.sort((a, b) {
      final aDate = a.resolvedAt ?? a.requestedAt;
      final bDate = b.resolvedAt ?? b.requestedAt;
      return bDate.compareTo(aDate);
    });
    return resolved.first;
  }

  @override
  Widget build(BuildContext context) {
    final c = context.cl;

    return Scaffold(
      backgroundColor: c.bg,
      appBar: AppBar(
        backgroundColor: c.bg,
        surfaceTintColor: Colors.transparent,
        title: Text(
          'طلباتي للانضمام',
          style: TextStyle(color: c.t1, fontWeight: FontWeight.w700),
        ),
        actions: [
          IconButton(
            onPressed: _loading ? null : _refresh,
            icon: Icon(Icons.refresh_rounded, color: c.t1),
          ),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _refresh,
          color: c.accent,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
            children: [
              _buildSummaryCard(c),
              const SizedBox(height: 12),
              if (_latestResolvedRequest != null) ...[
                _buildLatestResolutionBanner(c, _latestResolvedRequest!),
                const SizedBox(height: 12),
              ],
              _buildFilters(c),
              const SizedBox(height: 12),
              if (_loading && _requests.isEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 80),
                  child:
                      Center(child: CircularProgressIndicator(color: c.accent)),
                )
              else if (_errorMessage != null)
                _buildMessage(c, Icons.error_outline_rounded, _errorMessage!)
              else if (_visibleRequests.isEmpty)
                _buildMessage(
                    c, Icons.inbox_rounded, 'لا توجد طلبات في هذا التصنيف')
              else
                ..._visibleRequests
                    .map((request) => _buildRequestCard(c, request)),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () async {
                  await AuthService.signOutFromApi();
                  if (!context.mounted) return;
                  context.go(AppRoutes.auth);
                },
                icon: Icon(Icons.logout_rounded, color: c.error),
                label: Text(Ar.signOut, style: TextStyle(color: c.error)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryCard(CL c) {
    final pending = _requests.where((r) => r.isPending).length;
    final approved = _requests.where((r) => r.isApproved).length;
    final rejected = _requests.where((r) => r.isRejected).length;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: c.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: c.border),
      ),
      child: Row(
        children: [
          Icon(Icons.pending_actions_rounded, color: c.accent),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'قيد المراجعة: $pending • مقبولة: $approved • مرفوضة: $rejected',
              style: TextStyle(color: c.t2, height: 1.6),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilters(CL c) {
    Widget chip(String label, _JoinRequestFilter value) {
      final selected = _filter == value;
      return ChoiceChip(
        selected: selected,
        label: Text(label),
        onSelected: (_) => setState(() => _filter = value),
        selectedColor: c.accentMuted,
        labelStyle: TextStyle(
          color: selected ? c.accent : c.t2,
          fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
        ),
        backgroundColor: c.inputBg,
        side: BorderSide(color: selected ? c.accent : c.border),
      );
    }

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        chip('الكل', _JoinRequestFilter.all),
        chip('قيد المراجعة', _JoinRequestFilter.pending),
        chip('محسومة', _JoinRequestFilter.resolved),
      ],
    );
  }

  Widget _buildMessage(CL c, IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(top: 60),
      child: Column(
        children: [
          Icon(icon, size: 54, color: c.t3),
          const SizedBox(height: 12),
          Text(
            text,
            textAlign: TextAlign.center,
            style: TextStyle(color: c.t2, height: 1.7),
          ),
        ],
      ),
    );
  }

  Widget _buildLatestResolutionBanner(CL c, JoinRequest request) {
    final accepted = request.isApproved;
    final color = accepted ? c.success : c.error;
    final icon = accepted ? Icons.check_circle_rounded : Icons.cancel_rounded;
    final title = accepted
        ? 'تم قبول طلبك — يمكنك الآن الدخول إلى الديوانية'
        : 'تم رفض طلب الانضمام';
    final subtitle = accepted
        ? _diwaniyaLabel(request)
        : '${_diwaniyaLabel(request)} • يمكنك إرسال طلب جديد لاحقًا إذا كان الرمز متاحًا';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: c.t1,
                    fontWeight: FontWeight.w800,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(color: c.t2, height: 1.5),
                ),
              ],
            ),
          ),
          if (accepted)
            TextButton(
              onPressed: () => context.go(AuthService.nextRoute()),
              child: Text('الدخول', style: TextStyle(color: c.accent)),
            ),
        ],
      ),
    );
  }

  String _diwaniyaLabel(JoinRequest request) {
    final name = request.diwaniyaName.trim();
    final city = request.diwaniyaCity.trim();
    if (name.isEmpty && city.isEmpty) return 'الديوانية';
    if (city.isEmpty) return name;
    if (name.isEmpty) return city;
    return '$name • $city';
  }

  String _statusTitle(JoinRequest request) {
    if (request.isApproved) {
      return 'تم قبول طلبك';
    }
    if (request.isRejected) {
      return 'تم رفض طلب الانضمام';
    }
    return 'طلبك قيد مراجعة المدير';
  }

  String _statusDescription(JoinRequest request) {
    if (request.isApproved) {
      return 'يمكنك الآن الدخول إلى الديوانية ومشاهدة محتواها كأي عضو آخر.';
    }
    if (request.isRejected) {
      return 'لم تتم إضافتك إلى الديوانية. سيبقى الطلب محفوظًا في السجل للرجوع إليه.';
    }
    return 'تم إرسال الطلب للمدراء. ستتحدث الحالة هنا عند القبول أو الرفض.';
  }

  String _formatDate(DateTime value) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(value.day)}/${two(value.month)}/${value.year} ${two(value.hour)}:${two(value.minute)}';
  }

  Widget _buildRequestCard(CL c, JoinRequest request) {
    final icon = request.isApproved
        ? Icons.check_circle_rounded
        : request.isRejected
            ? Icons.cancel_rounded
            : Icons.hourglass_top_rounded;
    final color = request.isApproved
        ? c.success
        : request.isRejected
            ? c.error
            : c.accent;
    final statusTitle = _statusTitle(request);
    final description = _statusDescription(request);
    final resolvedAt = request.resolvedAt;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: c.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: c.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.10),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _diwaniyaLabel(request),
                      style: TextStyle(
                        color: c.t1,
                        fontWeight: FontWeight.w800,
                        fontSize: 14.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      statusTitle,
                      style: TextStyle(
                        color: color,
                        fontWeight: FontWeight.w800,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
              if (request.isApproved)
                TextButton(
                  onPressed: () => context.go(AuthService.nextRoute()),
                  child: Text('الدخول', style: TextStyle(color: c.accent)),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            description,
            style: TextStyle(color: c.t2, height: 1.65),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildMetaChip(
                c,
                Icons.schedule_rounded,
                'أُرسل ${_formatDate(request.requestedAt)}',
              ),
              if (resolvedAt != null)
                _buildMetaChip(
                  c,
                  request.isApproved
                      ? Icons.verified_rounded
                      : Icons.block_rounded,
                  'حُسم ${_formatDate(resolvedAt)}',
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMetaChip(CL c, IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: c.inputBg,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: c.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: c.t3),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(color: c.t3, fontSize: 12.5),
          ),
        ],
      ),
    );
  }
}
