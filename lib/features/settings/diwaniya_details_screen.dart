import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';

import '../../config/theme/app_colors.dart';
import '../../core/api/api_exception.dart';
import '../../core/models/mock_data.dart';
import '../../core/models/subscription_status.dart';
import '../../core/navigation/app_routes.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/diwaniya_management_service.dart';
import '../../core/services/subscription_service.dart';
import '../../core/services/user_service.dart';
import '../../l10n/ar.dart';

class DiwaniyaDetailsScreen extends StatefulWidget {
  final String diwaniyaId;
  const DiwaniyaDetailsScreen({super.key, required this.diwaniyaId});

  @override
  State<DiwaniyaDetailsScreen> createState() => _DiwaniyaDetailsScreenState();
}

class _DiwaniyaDetailsScreenState extends State<DiwaniyaDetailsScreen> {
  late String _did;
  bool _editing = false;
  late final TextEditingController _nameCtrl;
  late final TextEditingController _cityCtrl;
  late final TextEditingController _districtCtrl;
  final _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _did = widget.diwaniyaId;
    final diw = _diw;
    _nameCtrl = TextEditingController(text: diw?.name ?? '');
    _cityCtrl = TextEditingController(text: diw?.city ?? '');
    _districtCtrl = TextEditingController(text: diw?.district ?? '');
    dataVersion.addListener(_refresh);
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _cityCtrl.dispose();
    _districtCtrl.dispose();
    dataVersion.removeListener(_refresh);
    super.dispose();
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  DiwaniyaInfo? get _diw => allDiwaniyas.where((d) => d.id == _did).firstOrNull;
  List<DiwaniyaMember> get _members => diwaniyaMembers[_did] ?? [];
  bool get _isManager => UserService.isManager(_did);

  List<DiwaniyaMember> get _sortedMembers {
    final list = List<DiwaniyaMember>.from(_members);
    list.sort((a, b) {
      if (a.role == 'manager' && b.role != 'manager') return -1;
      if (a.role != 'manager' && b.role == 'manager') return 1;
      return a.name.compareTo(b.name);
    });
    return list;
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<bool> _confirm(String message) async {
    final c = context.cl;
    return await showDialog<bool>(
          context: context,
          builder: (d) => AlertDialog(
            backgroundColor: c.card,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
            ),
            content: Text(
              message,
              style: TextStyle(fontSize: 15, height: 1.7, color: c.t1),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(d).pop(false),
                child: Text(Ar.cancel, style: TextStyle(color: c.t3)),
              ),
              TextButton(
                onPressed: () => Navigator.of(d).pop(true),
                child: Text(
                  Ar.confirm,
                  style: TextStyle(
                    color: c.accent,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ) ??
        false;
  }

  Future<void> _saveInfo() async {
    await AuthService.updateDiwaniyaViaApi(
      _did,
      name: _nameCtrl.text,
      city: _cityCtrl.text,
      district: _districtCtrl.text,
    );
    if (!mounted) return;
    setState(() => _editing = false);
    _snack(Ar.infoSaved);
  }

  Future<void> _pickImage() async {
    final c = context.cl;
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (d) => Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: c.card,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(Icons.camera_alt_rounded, color: c.accent),
              title: Text(Ar.camera, style: TextStyle(color: c.t1)),
              onTap: () => Navigator.pop(d, ImageSource.camera),
            ),
            ListTile(
              leading: Icon(Icons.photo_library_rounded, color: c.accent),
              title: Text(Ar.gallery, style: TextStyle(color: c.t1)),
              onTap: () => Navigator.pop(d, ImageSource.gallery),
            ),
            if (_diw?.imagePath != null)
              ListTile(
                leading: Icon(Icons.delete_outline_rounded, color: c.error),
                title: Text(Ar.removeImage, style: TextStyle(color: c.error)),
                onTap: () {
                  DiwaniyaManagementService.updateDiwaniyaInfo(
                    _did,
                    removeImage: true,
                  );
                  Navigator.pop(d);
                },
              ),
          ],
        ),
      ),
    );
    if (source == null) return;

    final picked = await _picker.pickImage(source: source, imageQuality: 80);
    if (picked == null) return;

    await Future<void>.delayed(Duration.zero);
    if (!mounted) return;

    final dir = await getApplicationDocumentsDirectory();
    final imgDir = Directory('${dir.path}/diwaniya_images');
    if (!await imgDir.exists()) {
      await imgDir.create(recursive: true);
    }

    final filename = 'diw_${_did}_${DateTime.now().millisecondsSinceEpoch}.jpg';
    final saved = await File(picked.path).copy('${imgDir.path}/$filename');
    DiwaniyaManagementService.updateDiwaniyaInfo(_did, imagePath: saved.path);
  }

  Future<void> _removeMember(DiwaniyaMember m) async {
    final ok = await _confirm(Ar.removeConfirm);
    if (!ok || !mounted) return;
    // ignore: deprecated_member_use_from_same_package
    if (DiwaniyaManagementService.removeMember(_did, m.name)) {
      _snack(Ar.memberRemoved);
    }
  }

  Future<void> _promote(DiwaniyaMember m) async {
    final uid = m.userId;
    if (uid == null || uid.isEmpty) {
      _snack(Ar.errMemberNotSyncedYet);
      return;
    }
    final ok = await _confirm(Ar.promoteConfirm);
    if (!ok || !mounted) return;
    try {
      await DiwaniyaManagementService.promoteMember(
        diwaniyaId: _did,
        userId: uid,
      );
      if (!mounted) return;
      setState(() {});
      _snack(Ar.memberPromoted);
    } on ApiException catch (e) {
      if (!mounted) return;
      _snack(_arabicForError(e));
    }
  }

  Future<void> _demote(DiwaniyaMember m) async {
    final uid = m.userId;
    if (uid == null || uid.isEmpty) {
      _snack(Ar.errMemberNotSyncedYet);
      return;
    }
    final ok = await _confirm(Ar.demoteConfirm);
    if (!ok || !mounted) return;
    try {
      await DiwaniyaManagementService.demoteMember(
        diwaniyaId: _did,
        userId: uid,
      );
      if (!mounted) return;
      setState(() {});
      _snack(Ar.memberDemoted);
    } on ApiException catch (e) {
      if (!mounted) return;
      _snack(_arabicForError(e));
    }
  }

  String _arabicForError(ApiException e) {
    switch (e.code) {
      case 'not_a_manager':
        return Ar.errNotAManager;
      case 'last_manager':
        return Ar.errLastManager;
      case 'sole_member_must_delete':
        return Ar.errSoleMemberMustDelete;
      case 'has_members':
        return Ar.errDiwaniyaHasMembers;
      default:
        return Ar.errGeneric;
    }
  }

  Future<void> _leave() async {
    if (DiwaniyaManagementService.isLastManager(_did, UserService.currentName)) {
      _snack(Ar.lastManagerWarning);
      return;
    }
    final ok = await _confirm(Ar.leaveConfirm);
    if (!ok || !mounted) return;
    try {
      await DiwaniyaManagementService.leaveDiwaniya(_did);
      await AuthService.refreshMembershipsFromServer(removedDiwaniyaId: _did);
      if (!mounted) return;
      _snack(Ar.leftDiwaniya);
      if (allDiwaniyas.isEmpty) {
        context.go(AppRoutes.diwaniyaAccess);
      } else {
        Navigator.of(context).pop();
      }
    } on ApiException catch (e) {
      if (!mounted) return;
      _snack(_arabicForError(e));
    }
  }

  Future<void> _deleteDiwaniya() async {
    if (_members.length > 1) {
      _snack(Ar.deleteDiwaniyaOnlySoleMember);
      return;
    }
    final ok = await _confirm(Ar.deleteDiwaniyaConfirm);
    if (!ok || !mounted) return;
    try {
      await DiwaniyaManagementService.deleteDiwaniya(_did);
      await AuthService.refreshMembershipsFromServer(removedDiwaniyaId: _did);
      if (!mounted) return;
      _snack(Ar.diwaniyaDeleted);
      if (allDiwaniyas.isEmpty) {
        context.go(AppRoutes.diwaniyaAccess);
      } else {
        Navigator.of(context).pop();
      }
    } on ApiException catch (e) {
      if (!mounted) return;
      _snack(_arabicForError(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.cl;
    final diw = _diw;
    if (diw == null) {
      return Scaffold(
        backgroundColor: c.bg,
        appBar: AppBar(backgroundColor: c.bg),
        body: Center(
          child: Text(Ar.loading, style: TextStyle(color: c.t2)),
        ),
      );
    }

    final sorted = _sortedMembers;
    final sub = SubscriptionService.forDiwaniya(_did);

    return Scaffold(
      backgroundColor: c.bg,
      appBar: AppBar(
        backgroundColor: c.bg,
        surfaceTintColor: Colors.transparent,
        title: Text(
          Ar.diwaniyaDetails,
          style: TextStyle(color: c.t1, fontWeight: FontWeight.w700),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
        children: [
          _buildInfoCard(c, diw, sub),
          const SizedBox(height: 20),
          _Lbl(c, '${Ar.allMembers} (${sorted.length})'),
          const SizedBox(height: 8),
          ...sorted.map((m) => _buildMemberTile(c, m)),
          if (!_isManager) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: c.infoM,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline_rounded, size: 18, color: c.info),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      Ar.managerOnlyNote,
                      style: TextStyle(
                        fontSize: 13,
                        height: 1.6,
                        color: c.t1,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 24),
          SizedBox(
            height: 48,
            child: OutlinedButton.icon(
              onPressed: _leave,
              icon: Icon(Icons.exit_to_app_rounded, color: c.error, size: 18),
              label: Text(Ar.leaveDiwaniya, style: TextStyle(color: c.error)),
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: c.error.withValues(alpha: 0.3)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ),
          if (_isManager) ...[
            const SizedBox(height: 24),
            _Lbl(c, Ar.dangerZone),
            const SizedBox(height: 8),
            SizedBox(
              height: 48,
              child: ElevatedButton.icon(
                onPressed: _deleteDiwaniya,
                icon: const Icon(Icons.delete_forever_rounded, size: 18),
                label: const Text(Ar.deleteDiwaniya),
                style: ElevatedButton.styleFrom(
                  backgroundColor: c.error,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildInfoCard(CL c, DiwaniyaInfo diw, SubscriptionStatus? sub) {
    final hasImage = diw.imagePath != null && File(diw.imagePath!).existsSync();

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: c.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: c.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              GestureDetector(
                onTap: _isManager ? _pickImage : null,
                child: Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: diw.color.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(18),
                    image: hasImage
                        ? DecorationImage(
                            image: FileImage(File(diw.imagePath!)),
                            fit: BoxFit.cover,
                          )
                        : null,
                  ),
                  child: hasImage
                      ? null
                      : Stack(
                          children: [
                            Center(
                              child: Text(
                                diw.name.trim().isEmpty
                                    ? 'د'
                                    : diw.name.trim().substring(0, 1),
                                style: TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w800,
                                  color: diw.color,
                                ),
                              ),
                            ),
                            if (_isManager)
                              Positioned(
                                bottom: 0,
                                left: 0,
                                child: Container(
                                  width: 20,
                                  height: 20,
                                  decoration: BoxDecoration(
                                    color: c.accent,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: const Icon(
                                    Icons.camera_alt_rounded,
                                    size: 11,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                          ],
                        ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      diw.name,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: c.t1,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        _RoleBadge(c: c, isManager: _isManager),
                        if (sub != null) ...[
                          const SizedBox(width: 6),
                          _SubBadge(c: c, sub: sub),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              if (_isManager && !_editing)
                IconButton(
                  onPressed: () => setState(() => _editing = true),
                  icon: Icon(Icons.edit_rounded, size: 20, color: c.accent),
                  tooltip: Ar.editInfo,
                ),
            ],
          ),
          const SizedBox(height: 16),
          if (_editing) ...[
            _Field(c: c, label: Ar.diwaniyaName, controller: _nameCtrl),
            const SizedBox(height: 10),
            _Field(c: c, label: Ar.city, controller: _cityCtrl),
            const SizedBox(height: 10),
            _Field(c: c, label: Ar.district, controller: _districtCtrl),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 42,
                    child: ElevatedButton(
                      onPressed: _saveInfo,
                      child: const Text(Ar.saveChanges),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                SizedBox(
                  height: 42,
                  child: TextButton(
                    onPressed: () {
                      _nameCtrl.text = diw.name;
                      _cityCtrl.text = diw.city;
                      _districtCtrl.text = diw.district;
                      setState(() => _editing = false);
                    },
                    child: Text(Ar.cancel, style: TextStyle(color: c.t3)),
                  ),
                ),
              ],
            ),
          ] else ...[
            _InfoRow(
              c: c,
              icon: Icons.location_city_rounded,
              label: Ar.city,
              value: diw.city,
            ),
            const SizedBox(height: 8),
            _InfoRow(
              c: c,
              icon: Icons.place_rounded,
              label: Ar.district,
              value: diw.district,
            ),
            if (diw.invitationCode != null && diw.invitationCode!.isNotEmpty) ...[
              const SizedBox(height: 8),
              GestureDetector(
                onTap: () {
                  Clipboard.setData(ClipboardData(text: diw.invitationCode!));
                  _snack(Ar.codeCopied);
                },
                child: _InfoRow(
                  c: c,
                  icon: Icons.vpn_key_rounded,
                  label: Ar.invitationCode,
                  value: diw.invitationCode!,
                  trailing: Icon(Icons.copy_rounded, size: 14, color: c.t3),
                ),
              ),
            ],
            if (sub != null) ...[
              const SizedBox(height: 12),
              _buildSubSection(c, sub),
            ],
          ],
        ],
      ),
    );
  }

  Widget _buildSubSection(CL c, SubscriptionStatus? sub) {
    if (sub == null) return const SizedBox.shrink();

    final planLabel = _subLabel(sub);
    final startDate = sub.billingStartsAt;

    DateTime? endDate;
    if (startDate != null) {
      endDate = sub.plan == SubscriptionPlan.yearly
          ? startDate.add(const Duration(days: 365))
          : startDate.add(const Duration(days: 30));
    }
    final remaining = endDate?.difference(DateTime.now()).inDays;
    final isExpiring = remaining != null && remaining > 0 && remaining <= 7;
    final isExpired = remaining != null && remaining <= 0;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: c.accentSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: c.accent.withValues(alpha: 0.12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.payments_rounded, size: 18, color: c.accent),
              const SizedBox(width: 8),
              Text(
                Ar.subscriptionStatus,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: c.t1,
                ),
              ),
              const Spacer(),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: isExpired
                      ? c.errorM
                      : isExpiring
                          ? c.warningM
                          : c.successM,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  isExpired
                      ? Ar.subscriptionExpired
                      : isExpiring
                          ? Ar.expiringSoon
                          : Ar.subscriptionActive,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: isExpired
                        ? c.error
                        : isExpiring
                            ? c.warning
                            : c.success,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _SubRow(c: c, label: Ar.planType, value: planLabel),
          if (startDate != null)
            _SubRow(c: c, label: Ar.activatedOn, value: _fmtDate(startDate)),
          if (endDate != null)
            _SubRow(c: c, label: Ar.expiresOn, value: _fmtDate(endDate)),
          if (remaining != null && remaining > 0)
            _SubRow(
              c: c,
              label: Ar.remainingDays,
              value: '$remaining ${Ar.days}',
            ),
        ],
      ),
    );
  }

  String _fmtDate(DateTime dt) => '${dt.day}/${dt.month}/${dt.year}';

  String _subLabel(SubscriptionStatus? sub) {
    if (sub == null) return Ar.noSubscriptionYet;
    switch (sub.plan) {
      case SubscriptionPlan.monthly:
        return Ar.monthlyPlan;
      case SubscriptionPlan.yearly:
        return Ar.yearlyPlan;
      default:
        return Ar.joinedMember;
    }
  }

  Widget _buildMemberTile(CL c, DiwaniyaMember m) {
    final isMe = m.name == UserService.currentName;
    final isMgr = m.role == 'manager';
    final joinLabel = m.joinedAt != null
        ? '${m.joinedAt!.month.toString().padLeft(2, '0')}/${m.joinedAt!.year}'
        : null;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: c.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: c.border),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: m.avatarColor.withValues(alpha: 0.15),
            child: Text(
              m.initials,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: m.avatarColor,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        m.name,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: c.t1,
                        ),
                      ),
                    ),
                    if (isMe)
                      Text(
                        ' (أنت)',
                        style: TextStyle(fontSize: 11, color: c.t3),
                      ),
                  ],
                ),
                const SizedBox(height: 3),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: isMgr ? c.accentMuted : c.cardElevated,
                        borderRadius: BorderRadius.circular(5),
                      ),
                      child: Text(
                        isMgr ? Ar.manager : Ar.memberUnit,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: isMgr ? c.accent : c.t3,
                        ),
                      ),
                    ),
                    if (joinLabel != null) ...[
                      const SizedBox(width: 6),
                      Text(
                        '${Ar.joined} $joinLabel',
                        style: TextStyle(fontSize: 10, color: c.t3),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          if (_isManager && !isMe)
            ...(() {
              final menuItems = <PopupMenuEntry<String>>[
                if (!isMgr)
                  PopupMenuItem(
                    value: 'promote',
                    child: Row(
                      children: [
                        Icon(Icons.star_rounded, size: 18, color: c.warning),
                        const SizedBox(width: 8),
                        Text(Ar.promoteMember, style: TextStyle(color: c.t1)),
                      ],
                    ),
                  ),
                if (isMgr &&
                    !DiwaniyaManagementService.isLastManager(_did, m.name))
                  PopupMenuItem(
                    value: 'demote',
                    child: Row(
                      children: [
                        Icon(Icons.swap_vert_rounded, size: 18, color: c.info),
                        const SizedBox(width: 8),
                        Text(Ar.demoteMember, style: TextStyle(color: c.t1)),
                      ],
                    ),
                  ),
                if (!isMgr)
                  PopupMenuItem(
                    value: 'remove',
                    child: Row(
                      children: [
                        Icon(
                          Icons.person_remove_rounded,
                          size: 18,
                          color: c.error,
                        ),
                        const SizedBox(width: 8),
                        Text(Ar.removeMember, style: TextStyle(color: c.error)),
                      ],
                    ),
                  ),
              ];

              if (menuItems.isEmpty) {
                return <Widget>[];
              }

              return <Widget>[
                PopupMenuButton<String>(
                  icon: Icon(Icons.more_vert_rounded, size: 20, color: c.t3),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  color: c.card,
                  onSelected: (action) {
                    switch (action) {
                      case 'promote':
                        _promote(m);
                        break;
                      case 'remove':
                        _removeMember(m);
                        break;
                      case 'demote':
                        _demote(m);
                        break;
                    }
                  },
                  itemBuilder: (_) => menuItems,
                ),
              ];
            })(),
        ],
      ),
    );
  }
}

class _Lbl extends StatelessWidget {
  final CL c;
  final String text;
  const _Lbl(this.c, this.text);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(right: 2),
        child: Text(
          text,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: c.t2,
          ),
        ),
      );
}

class _InfoRow extends StatelessWidget {
  final CL c;
  final IconData icon;
  final String label;
  final String value;
  final Widget? trailing;

  const _InfoRow({
    required this.c,
    required this.icon,
    required this.label,
    required this.value,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) => Row(
        children: [
          Icon(icon, size: 16, color: c.t3),
          const SizedBox(width: 8),
          Text(label, style: TextStyle(fontSize: 13, color: c.t3)),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: c.t1,
              ),
            ),
          ),
          if (trailing != null) trailing!,
        ],
      );
}

class _Field extends StatelessWidget {
  final CL c;
  final String label;
  final TextEditingController controller;

  const _Field({
    required this.c,
    required this.label,
    required this.controller,
  });

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: c.t3,
            ),
          ),
          const SizedBox(height: 6),
          TextField(
            controller: controller,
            style: TextStyle(fontSize: 14, color: c.t1),
            decoration: const InputDecoration(
              contentPadding: EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 10,
              ),
            ),
          ),
        ],
      );
}

class _RoleBadge extends StatelessWidget {
  final CL c;
  final bool isManager;
  const _RoleBadge({required this.c, required this.isManager});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: isManager ? c.accentMuted : c.cardElevated,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          isManager ? Ar.manager : Ar.memberUnit,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: isManager ? c.accent : c.t3,
          ),
        ),
      );
}

class _SubBadge extends StatelessWidget {
  final CL c;
  final SubscriptionStatus sub;
  const _SubBadge({required this.c, required this.sub});

  @override
  Widget build(BuildContext context) {
    final isActive = sub.active == true;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: isActive ? c.successM : c.errorM,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        isActive ? Ar.subscriptionActive : Ar.subscriptionExpired,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: isActive ? c.success : c.error,
        ),
      ),
    );
  }
}

class _SubRow extends StatelessWidget {
  final CL c;
  final String label;
  final String value;
  const _SubRow({required this.c, required this.label, required this.value});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Row(
          children: [
            Text(label, style: TextStyle(fontSize: 12, color: c.t3)),
            const SizedBox(width: 8),
            Text(
              value,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: c.t1,
              ),
            ),
          ],
        ),
      );
}
