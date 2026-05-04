import 'package:flutter/material.dart';

import '../../config/theme/app_colors.dart';
import '../../core/api/api_exception.dart';
import '../../core/api/join_request_api.dart';
import '../../core/services/auth_service.dart';
import '../../l10n/ar.dart';

/// Manager-only screen for reviewing pending join requests for a
/// specific diwaniya. Backend is the source of truth: every approve
/// or reject re-fetches the list so the UI matches server state
/// without local optimistic mutation.
///
/// Pull-to-refresh is supported. No polling — fresh on open + after
/// every action + manual refresh.
class ManagerJoinRequestsScreen extends StatefulWidget {
  final String diwaniyaId;
  const ManagerJoinRequestsScreen({super.key, required this.diwaniyaId});

  @override
  State<ManagerJoinRequestsScreen> createState() =>
      _ManagerJoinRequestsScreenState();
}

class _ManagerJoinRequestsScreenState extends State<ManagerJoinRequestsScreen> {
  bool _loading = true;
  String? _errorMessage;
  List<Map<String, dynamic>> _requests = const [];
  // Tracks per-request in-flight state so we can disable buttons.
  final Set<String> _inFlight = {};

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch() async {
    setState(() {
      _loading = true;
      _errorMessage = null;
    });
    try {
      final result = await JoinRequestApi.listPendingForDiwaniya(
        widget.diwaniyaId,
      );
      if (!mounted) return;
      setState(() {
        _requests = result;
        _loading = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      final code = e.code.toString();
      final msg = e.message.toLowerCase();
      final shouldShowEmpty = code.contains('not_found') ||
          code.contains('404') ||
          msg.contains('not found') ||
          msg.contains('404');
      setState(() {
        _loading = false;
        _requests = shouldShowEmpty ? const [] : _requests;
        _errorMessage = shouldShowEmpty ? null : _arabicForError(e);
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _errorMessage = Ar.errGeneric;
      });
    }
  }

  Future<void> _approve(String requestId) async {
    if (_inFlight.contains(requestId)) return;
    setState(() => _inFlight.add(requestId));
    try {
      await JoinRequestApi.approve(requestId);
      await AuthService.refreshMembershipsFromServer(
        preferredDiwaniyaId: widget.diwaniyaId,
      );
      if (!mounted) return;
      _snack(Ar.joinRequestApproved);
      await _fetch();
      if (!mounted) return;
      setState(() => _inFlight.remove(requestId));
    } on ApiException catch (e) {
      if (!mounted) return;
      _snack(_arabicForError(e));
      setState(() => _inFlight.remove(requestId));
    } catch (_) {
      if (!mounted) return;
      _snack(Ar.errGeneric);
      setState(() => _inFlight.remove(requestId));
    }
  }

  Future<void> _reject(String requestId) async {
    if (_inFlight.contains(requestId)) return;
    final ok = await _confirm(Ar.joinRequestRejectConfirm);
    if (!ok || !mounted) return;
    setState(() => _inFlight.add(requestId));
    try {
      await JoinRequestApi.reject(requestId);
      if (!mounted) return;
      _snack(Ar.joinRequestRejected);
      await _fetch();
      if (!mounted) return;
      setState(() => _inFlight.remove(requestId));
    } on ApiException catch (e) {
      if (!mounted) return;
      _snack(_arabicForError(e));
      setState(() => _inFlight.remove(requestId));
    } catch (_) {
      if (!mounted) return;
      _snack(Ar.errGeneric);
      setState(() => _inFlight.remove(requestId));
    }
  }

  Future<bool> _confirm(String message) async {
    final c = context.cl;
    final res = await showDialog<bool>(
      context: context,
      builder: (d) => AlertDialog(
        backgroundColor: c.card,
        title: Text(Ar.confirmAction,
            style: TextStyle(color: c.t1, fontWeight: FontWeight.w700)),
        content: Text(message, style: TextStyle(color: c.t2, height: 1.7)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(d).pop(false),
            child: Text(Ar.cancel, style: TextStyle(color: c.t3)),
          ),
          TextButton(
            onPressed: () => Navigator.of(d).pop(true),
            child: Text(Ar.confirm,
                style: TextStyle(color: c.error, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
    return res ?? false;
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  String _arabicForError(ApiException e) {
    switch (e.code) {
      case 'not_a_manager':
        return Ar.errNotAManager;
      case 'request_not_found':
        return Ar.errJoinRequestNotFound;
      case 'already_resolved':
        return Ar.errJoinRequestAlreadyResolved;
      default:
        return Ar.errGeneric;
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
        title: Text(Ar.joinRequestsTitle,
            style: TextStyle(
                fontSize: 18, fontWeight: FontWeight.w700, color: c.t1)),
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _fetch,
          color: c.accent,
          child: _buildBody(c),
        ),
      ),
    );
  }

  Widget _buildBody(CL c) {
    if (_loading) {
      return ListView(
        children: [
          const SizedBox(height: 120),
          Center(child: CircularProgressIndicator(color: c.accent)),
        ],
      );
    }
    if (_errorMessage != null) {
      return ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const SizedBox(height: 80),
          Icon(Icons.error_outline_rounded, size: 56, color: c.error),
          const SizedBox(height: 14),
          Text(_errorMessage!,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, height: 1.7, color: c.t2)),
          const SizedBox(height: 18),
          Center(
            child: TextButton.icon(
              onPressed: _fetch,
              icon: Icon(Icons.refresh_rounded, color: c.accent),
              label: Text(Ar.retry, style: TextStyle(color: c.accent)),
            ),
          ),
        ],
      );
    }
    if (_requests.isEmpty) {
      return ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const SizedBox(height: 80),
          Icon(Icons.inbox_rounded, size: 64, color: c.t3),
          const SizedBox(height: 14),
          Text(Ar.joinRequestsEmpty,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14.5, height: 1.7, color: c.t2)),
        ],
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
      itemCount: _requests.length,
      itemBuilder: (context, i) => _buildRequestTile(c, _requests[i]),
    );
  }

  Widget _buildRequestTile(CL c, Map<String, dynamic> req) {
    final id = (req['id'] as String?) ?? '';
    final name = (req['applicant_display_name'] as String?) ?? '';
    final phone = (req['applicant_mobile_number'] as String?) ?? '';
    final initials = name.isNotEmpty ? name.substring(0, 1) : '?';
    final busy = _inFlight.contains(id);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: c.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: c.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(children: [
            CircleAvatar(
              radius: 22,
              backgroundColor: c.accentMuted,
              child: Text(initials,
                  style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: c.accent)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name.isEmpty ? Ar.unknownName : name,
                      style: TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w700,
                          color: c.t1)),
                  if (phone.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(phone,
                        style:
                            TextStyle(fontSize: 12, height: 1.5, color: c.t3)),
                  ],
                ],
              ),
            ),
          ]),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(
              child: SizedBox(
                height: 42,
                child: OutlinedButton.icon(
                  onPressed: busy ? null : () => _reject(id),
                  icon: Icon(Icons.close_rounded, size: 16, color: c.error),
                  label: Text(Ar.reject, style: TextStyle(color: c.error)),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: c.error.withValues(alpha: 0.3)),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: SizedBox(
                height: 42,
                child: ElevatedButton.icon(
                  onPressed: busy ? null : () => _approve(id),
                  icon: const Icon(Icons.check_rounded, size: 16),
                  label: const Text(Ar.approve),
                ),
              ),
            ),
          ]),
        ],
      ),
    );
  }
}
