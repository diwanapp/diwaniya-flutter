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

  Widget _buildRequestCard(CL c, JoinRequest request) {
    final statusText = request.isApproved
        ? 'تم قبول الطلب'
        : request.isRejected
            ? 'تم رفض الطلب'
            : 'قيد مراجعة المدير';
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

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: c.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: c.border),
      ),
      child: Row(
        children: [
          Icon(icon, color: color),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  request.diwaniyaName.isNotEmpty
                      ? request.diwaniyaName
                      : 'ديوانية',
                  style: TextStyle(
                    color: c.t1,
                    fontWeight: FontWeight.w700,
                    fontSize: 14.5,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  statusText,
                  style: TextStyle(color: c.t2, height: 1.5),
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
    );
  }
}
