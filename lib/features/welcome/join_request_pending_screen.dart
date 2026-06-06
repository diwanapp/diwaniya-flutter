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
                      const _SectionTitle(title: 'طلبات بانتظار الموافقة'),
                      const SizedBox(height: 10),
                      ...pending.map((r) => _RequestCard(request: r)),
                      const SizedBox(height: 20),
                    ],
                    const _SectionTitle(title: 'سجل الطلبات'),
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

  const _SummaryCard({
    required this.pendingCount,
    required this.historyCount,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.cl;
    final hasPending = pendingCount > 0;

    final title = hasPending
        ? pendingCount == 1
            ? 'لديك طلب بانتظار الموافقة'
            : 'لديك $pendingCount طلبات بانتظار الموافقة'
        : 'لا توجد طلبات معلقة';

    final body = hasPending
        ? 'سيتم إشعارك عند قبول الطلب أو رفضه.'
        : 'كل طلباتك الحالية مكتملة. يمكنك متابعة السجل أو الرجوع للرئيسية.';

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 13),
      decoration: BoxDecoration(
        color: c.card.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: c.border.withValues(alpha: 0.10)),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: (hasPending ? c.accent : c.success).withValues(alpha: 0.11),
              borderRadius: BorderRadius.circular(15),
            ),
            child: Icon(
              hasPending ? Icons.hourglass_top_rounded : Icons.task_alt_rounded,
              color: hasPending ? c.accent : c.success,
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 15.2,
                    fontWeight: FontWeight.w900,
                    color: c.t1,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  body,
                  style: TextStyle(
                    fontSize: 12.2,
                    height: 1.45,
                    color: c.t2,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (historyCount > 0) ...[
                  const SizedBox(height: 7),
                  Text(
                    'سجل الطلبات: $historyCount',
                    style: TextStyle(
                      fontSize: 11.2,
                      color: c.t3,
                      fontWeight: FontWeight.w700,
                    ),
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
    return Padding(
      padding: const EdgeInsetsDirectional.only(start: 2),
      child: Text(
        title,
        style: TextStyle(
          color: c.t1,
          fontSize: 16.2,
          fontWeight: FontWeight.w900,
          height: 1.2,
        ),
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
      margin: const EdgeInsets.only(bottom: 7),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: c.card.withValues(alpha: 0.86),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.10)),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.11),
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(_statusIcon(), color: color, size: 21),
          ),
          const SizedBox(width: 11),
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
                    fontSize: 14.2,
                    fontWeight: FontWeight.w900,
                    height: 1.15,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _statusText(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: color,
                    fontSize: 12.3,
                    fontWeight: FontWeight.w800,
                    height: 1.2,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            _dateText(),
            textAlign: TextAlign.end,
            style: TextStyle(
              color: c.t3,
              fontSize: 10.8,
              fontWeight: FontWeight.w700,
              height: 1.2,
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
    final d = resolved ?? request.requestedAt;
    return _formatDate(d);
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
      padding: const EdgeInsets.fromLTRB(13, 12, 13, 12),
      decoration: BoxDecoration(
        color: c.card.withValues(alpha: 0.86),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.10)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _clean(title),
                  style: TextStyle(
                    color: c.t1,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _clean(body),
                  style: TextStyle(
                    color: c.t2,
                    fontSize: 12,
                    height: 1.42,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _clean(String value) {
    if (value.trim().isEmpty) return '';
    if (value.contains('O') || value.contains('U,')) {
      return 'لا توجد بيانات للعرض حالياً.';
    }
    return value;
  }
}


