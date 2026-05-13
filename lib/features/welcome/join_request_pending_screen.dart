import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../config/theme/app_colors.dart';
import '../../core/api/join_request_api.dart';
import '../../core/models/join_request.dart';
import '../../core/models/mock_data.dart';
import '../../core/navigation/app_routes.dart';
import '../../core/repositories/app_repository.dart';
import '../../core/services/auth_service.dart';
import '../../l10n/ar.dart';

class JoinRequestPendingScreen extends StatefulWidget {
  final bool autoRedirectWhenResolved;

  const JoinRequestPendingScreen({
    super.key,
    this.autoRedirectWhenResolved = true,
  });

  @override
  State<JoinRequestPendingScreen> createState() =>
      _JoinRequestPendingScreenState();
}

class _JoinRequestPendingScreenState extends State<JoinRequestPendingScreen> {
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _refresh());
  }

  Future<void> _refresh() async {
    if (mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }

    try {
      final serverRequests = await JoinRequestApi.getMyJoinRequests();
      AuthService.pendingJoinRequests
        ..clear()
        ..addAll(serverRequests.map(JoinRequest.fromJson));
      await AppRepository.saveJoinRequests();
      await AuthService.refreshMembershipsFromServer();

      if (!mounted) return;
      final hasPending =
          AuthService.pendingJoinRequests.any((r) => r.isPending);
      if (widget.autoRedirectWhenResolved &&
          !hasPending &&
          allDiwaniyas.isNotEmpty) {
        context.go(AppRoutes.home);
        return;
      }

      setState(() => _loading = false);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'تعذر تحديث طلباتك، حاول مرة أخرى.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.cl;
    final requests = [...AuthService.pendingJoinRequests]..sort((a, b) {
        final ap = a.isPending ? 0 : 1;
        final bp = b.isPending ? 0 : 1;
        if (ap != bp) return ap.compareTo(bp);
        return b.requestedAt.compareTo(a.requestedAt);
      });
    final pending = requests.where((r) => r.isPending).toList();
    final history = requests.where((r) => !r.isPending).toList();

    return Scaffold(
      backgroundColor: c.bg,
      appBar: AppBar(
        backgroundColor: c.bg,
        surfaceTintColor: Colors.transparent,
        title: Text(
          'طلباتي',
          style: TextStyle(color: c.t1, fontWeight: FontWeight.w800),
        ),
        actions: [
          IconButton(
            onPressed: _loading ? null : _refresh,
            icon: Icon(Icons.refresh_rounded, color: c.t2),
            tooltip: 'تحديث',
          ),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          color: c.accent,
          onRefresh: _refresh,
          child: _loading
              ? ListView(
                  padding: const EdgeInsets.all(24),
                  children: [
                    const SizedBox(height: 160),
                    Center(child: CircularProgressIndicator(color: c.accent)),
                  ],
                )
              : ListView(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
                  children: [
                    _SummaryCard(
                      pendingCount: pending.length,
                      historyCount: history.length,
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: 12),
                      _InfoCard(
                        icon: Icons.error_outline_rounded,
                        color: c.error,
                        title: 'تعذر التحديث',
                        body: _error!,
                      ),
                    ],
                    const SizedBox(height: 18),
                    if (pending.isNotEmpty) ...[
                      _SectionTitle(title: 'طلبات بانتظار الموافقة'),
                      const SizedBox(height: 10),
                      ...pending.map((r) => _RequestCard(request: r)),
                      const SizedBox(height: 20),
                    ],
                    _SectionTitle(title: 'سجل الطلبات'),
                    const SizedBox(height: 10),
                    if (history.isEmpty)
                      _InfoCard(
                        icon: Icons.history_rounded,
                        color: c.t3,
                        title: 'لا يوجد سجل بعد',
                        body:
                            'سيظهر هنا سجل طلبات الانضمام المقبولة أو غير المقبولة.',
                      )
                    else
                      ...history.map((r) => _RequestCard(request: r)),
                    const SizedBox(height: 22),
                    if (widget.autoRedirectWhenResolved)
                      SizedBox(
                        height: 50,
                        child: OutlinedButton.icon(
                          onPressed: () async {
                            await AuthService.signOutFromApi();
                            if (!context.mounted) return;
                            context.go(AppRoutes.auth);
                          },
                          icon: Icon(Icons.logout_rounded, color: c.error),
                          label: Text(Ar.signOut,
                              style: TextStyle(color: c.error)),
                        ),
                      )
                    else
                      SizedBox(
                        height: 50,
                        child: FilledButton.icon(
                          onPressed: () => Navigator.of(context).maybePop(),
                          icon: const Icon(Icons.arrow_back_rounded),
                          label: const Text('العودة'),
                        ),
                      ),
                  ],
                ),
        ),
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final int pendingCount;
  final int historyCount;

  const _SummaryCard({required this.pendingCount, required this.historyCount});

  @override
  Widget build(BuildContext context) {
    final c = context.cl;
    final title = pendingCount == 0
        ? 'لا توجد طلبات معلقة'
        : pendingCount == 1
            ? 'لديك طلب واحد بانتظار الموافقة'
            : 'لديك $pendingCount طلبات بانتظار الموافقة';
    final body = pendingCount == 0
        ? 'يمكنك متابعة سجل طلباتك السابقة أو الرجوع للرئيسية.'
        : 'تم إرسال الطلب، وبانتظار موافقة أحد مدراء الديوانية.';
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: c.card,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: c.border),
      ),
      child: Row(
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              color: c.accent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Icon(
              pendingCount == 0
                  ? Icons.task_alt_rounded
                  : Icons.hourglass_top_rounded,
              color: c.accent,
              size: 28,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: c.t1,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  body,
                  style: TextStyle(fontSize: 13, height: 1.55, color: c.t2),
                ),
                if (historyCount > 0) ...[
                  const SizedBox(height: 8),
                  Text(
                    'سجل الطلبات: $historyCount',
                    style: TextStyle(fontSize: 12, color: c.t3),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  const _SectionTitle({required this.title});

  @override
  Widget build(BuildContext context) {
    final c = context.cl;
    return Text(
      title,
      style: TextStyle(
        color: c.t1,
        fontSize: 16,
        fontWeight: FontWeight.w800,
      ),
    );
  }
}

class _RequestCard extends StatelessWidget {
  final JoinRequest request;
  const _RequestCard({required this.request});

  @override
  Widget build(BuildContext context) {
    final c = context.cl;
    final color = _statusColor(c);
    final name = request.diwaniyaName.trim().isEmpty
        ? 'ديوانية غير معروفة'
        : request.diwaniyaName.trim();
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: c.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withValues(alpha: 0.22)),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(_statusIcon(), color: color, size: 23),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: c.t1,
                    fontSize: 14.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  _statusText(),
                  style: TextStyle(
                    color: color,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _dateText(),
                  style: TextStyle(color: c.t3, fontSize: 11.5),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  IconData _statusIcon() {
    if (request.isApproved) return Icons.check_circle_rounded;
    if (request.isRejected) return Icons.cancel_rounded;
    return Icons.hourglass_top_rounded;
  }

  String _statusText() {
    if (request.isApproved) return 'تم قبول طلبك — حياك معنا';
    if (request.isRejected) return 'لم يتم قبول طلبك';
    return 'بانتظار موافقة المدير';
  }

  Color _statusColor(CL c) {
    if (request.isApproved) return c.success;
    if (request.isRejected) return c.error;
    return c.accent;
  }

  String _dateText() {
    final resolved = request.resolvedAt;
    if (resolved != null) return 'آخر تحديث: ${_formatDate(resolved)}';
    return 'تاريخ الطلب: ${_formatDate(request.requestedAt)}';
  }

  String _formatDate(DateTime d) {
    final mm = d.month.toString().padLeft(2, '0');
    final dd = d.day.toString().padLeft(2, '0');
    return '${d.year}/$mm/$dd';
  }
}

class _InfoCard extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String body;

  const _InfoCard({
    required this.icon,
    required this.color,
    required this.title,
    required this.body,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.cl;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: c.inputBg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: c.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: c.t1,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  body,
                  style: TextStyle(color: c.t2, fontSize: 12.5, height: 1.55),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
