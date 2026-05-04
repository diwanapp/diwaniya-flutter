import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../config/theme/app_colors.dart';
import '../../core/api/join_request_api.dart';
import '../../core/models/join_request.dart';
import '../../core/navigation/app_routes.dart';
import '../../core/services/auth_service.dart';

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
    _requests = [...AuthService.pendingJoinRequests]
      ..sort((a, b) => b.requestedAt.compareTo(a.requestedAt));
    WidgetsBinding.instance.addPostFrameCallback((_) => _refresh());
  }

  Future<void> _refresh() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _errorMessage = null;
    });
    try {
      final raw = await JoinRequestApi.getMyJoinRequests();
      final loaded = raw.map(JoinRequest.fromJson).toList()
        ..sort((a, b) => b.requestedAt.compareTo(a.requestedAt));
      if (!mounted) return;
      setState(() {
        _requests = loaded;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _errorMessage = 'تعذّر تحديث طلبات الانضمام. اسحب للأسفل للمحاولة مرة أخرى.';
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

  int get _pendingCount => _requests.where((r) => r.isPending).length;
  int get _resolvedCount => _requests.where((r) => !r.isPending).length;

  @override
  Widget build(BuildContext context) {
    final c = context.cl;
    final visible = _visibleRequests;

    return Scaffold(
      backgroundColor: c.bg,
      appBar: AppBar(
        backgroundColor: c.bg,
        surfaceTintColor: Colors.transparent,
        title: Text(
          'طلباتي للانضمام',
          style: TextStyle(color: c.t1, fontWeight: FontWeight.w800),
        ),
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _refresh,
          color: c.accent,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
            children: [
              _IntroCard(c: c),
              const SizedBox(height: 12),
              _FilterRow(
                c: c,
                selected: _filter,
                pendingCount: _pendingCount,
                resolvedCount: _resolvedCount,
                onChanged: (value) => setState(() => _filter = value),
              ),
              if (_loading) ...[
                const SizedBox(height: 24),
                Center(child: CircularProgressIndicator(color: c.accent)),
              ] else if (_errorMessage != null) ...[
                const SizedBox(height: 14),
                _InlineMessage(c: c, message: _errorMessage!, isError: true),
              ] else if (visible.isEmpty) ...[
                const SizedBox(height: 36),
                _EmptyState(c: c, filter: _filter),
              ] else ...[
                const SizedBox(height: 12),
                ...visible.map(
                  (r) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _JoinRequestTile(request: r),
                  ),
                ),
                const SizedBox(height: 4),
                _HistoryNote(c: c),
              ],
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () => context.push(AppRoutes.joinDiwaniya),
                icon: const Icon(Icons.login_rounded),
                label: const Text('إرسال طلب انضمام جديد'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _IntroCard extends StatelessWidget {
  final dynamic c;

  const _IntroCard({required this.c});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: c.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: c.border),
      ),
      child: Row(
        children: [
          Icon(Icons.fact_check_rounded, color: c.accent),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'هنا تظهر جميع طلبات الانضمام السابقة والحالية بدون إرباك الشاشة الرئيسية.',
              style: TextStyle(fontSize: 13.5, height: 1.6, color: c.t2),
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterRow extends StatelessWidget {
  final dynamic c;
  final _JoinRequestFilter selected;
  final int pendingCount;
  final int resolvedCount;
  final ValueChanged<_JoinRequestFilter> onChanged;

  const _FilterRow({
    required this.c,
    required this.selected,
    required this.pendingCount,
    required this.resolvedCount,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _chip('الكل', _JoinRequestFilter.all),
        _chip('قيد المراجعة ($pendingCount)', _JoinRequestFilter.pending),
        _chip('المنتهية ($resolvedCount)', _JoinRequestFilter.resolved),
      ],
    );
  }

  Widget _chip(String label, _JoinRequestFilter value) {
    final active = selected == value;
    return ChoiceChip(
      selected: active,
      label: Text(label),
      onSelected: (_) => onChanged(value),
      selectedColor: c.accentMuted,
      backgroundColor: c.card,
      labelStyle: TextStyle(
        color: active ? c.accent : c.t2,
        fontWeight: active ? FontWeight.w800 : FontWeight.w600,
      ),
      shape: StadiumBorder(side: BorderSide(color: active ? c.accent : c.border)),
    );
  }
}

class _InlineMessage extends StatelessWidget {
  final dynamic c;
  final String message;
  final bool isError;

  const _InlineMessage({
    required this.c,
    required this.message,
    required this.isError,
  });

  @override
  Widget build(BuildContext context) {
    final color = isError ? c.error : c.accent;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Text(
        message,
        style: TextStyle(color: c.t2, fontSize: 13.5, height: 1.6),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final dynamic c;
  final _JoinRequestFilter filter;

  const _EmptyState({required this.c, required this.filter});

  @override
  Widget build(BuildContext context) {
    final title = switch (filter) {
      _JoinRequestFilter.pending => 'لا توجد طلبات قيد المراجعة',
      _JoinRequestFilter.resolved => 'لا توجد طلبات منتهية',
      _JoinRequestFilter.all => 'لا توجد طلبات انضمام',
    };
    final subtitle = switch (filter) {
      _JoinRequestFilter.pending => 'أي طلب جديد تنتظر موافقته سيظهر هنا.',
      _JoinRequestFilter.resolved => 'الطلبات المقبولة أو المرفوضة ستظهر هنا كسجل.',
      _JoinRequestFilter.all => 'أي طلب ترسله للانضمام إلى ديوانية سيظهر هنا بحالته الحالية.',
    };

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          Icon(Icons.mark_email_unread_outlined, size: 62, color: c.t3),
          const SizedBox(height: 16),
          Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: c.t1,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, height: 1.7, color: c.t2),
          ),
        ],
      ),
    );
  }
}

class _JoinRequestTile extends StatelessWidget {
  final JoinRequest request;

  const _JoinRequestTile({required this.request});

  @override
  Widget build(BuildContext context) {
    final c = context.cl;
    final state = _state(context, request);
    final name = request.diwaniyaName.trim().isEmpty
        ? 'الديوانية'
        : request.diwaniyaName.trim();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: c.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: state.color.withValues(alpha: 0.22)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: state.color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(state.icon, color: state.color, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  state.title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: c.t1,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  '$name${request.diwaniyaCity.trim().isNotEmpty ? ' • ${request.diwaniyaCity.trim()}' : ''}',
                  style: TextStyle(fontSize: 13, color: c.t2, height: 1.5),
                ),
                const SizedBox(height: 7),
                Text(
                  state.subtitle,
                  style: TextStyle(fontSize: 12.5, color: c.t3, height: 1.6),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  _JoinRequestUiState _state(BuildContext context, JoinRequest r) {
    final c = context.cl;
    if (r.isApproved) {
      return _JoinRequestUiState(
        title: 'تم قبول طلب الانضمام',
        subtitle: 'يمكنك الآن الدخول إلى الديوانية من قائمة ديوانياتك.',
        icon: Icons.check_circle_rounded,
        color: c.success,
      );
    }
    if (r.isRejected) {
      return _JoinRequestUiState(
        title: 'تم رفض طلب الانضمام',
        subtitle: 'لم تتم إضافتك إلى الديوانية. يمكنك إرسال طلب جديد عند الحاجة.',
        icon: Icons.cancel_rounded,
        color: c.error,
      );
    }
    return _JoinRequestUiState(
      title: 'بانتظار موافقة المدير',
      subtitle: 'طلبك قيد مراجعة مدراء الديوانية.',
      icon: Icons.hourglass_top_rounded,
      color: c.accent,
    );
  }
}

class _HistoryNote extends StatelessWidget {
  final dynamic c;

  const _HistoryNote({required this.c});

  @override
  Widget build(BuildContext context) {
    return Text(
      'سيبقى هذا السجل مرجعًا لحالات طلباتك السابقة. لاحقًا يمكن أرشفته أو تصفيته حسب المدة عند الحاجة.',
      style: TextStyle(fontSize: 12, height: 1.6, color: c.t3),
      textAlign: TextAlign.center,
    );
  }
}

class _JoinRequestUiState {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;

  const _JoinRequestUiState({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
  });
}
