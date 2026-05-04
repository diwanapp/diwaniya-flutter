import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../config/theme/app_colors.dart';
import '../../core/api/api_exception.dart';
import '../../core/api/join_request_api.dart';
import '../../core/models/mock_data.dart';
import '../../core/services/auth_service.dart';
import '../../l10n/ar.dart';

class JoinDiwaniyaScreen extends StatefulWidget {
  const JoinDiwaniyaScreen({super.key});

  @override
  State<JoinDiwaniyaScreen> createState() => _JoinDiwaniyaScreenState();
}

class _JoinDiwaniyaScreenState extends State<JoinDiwaniyaScreen> {
  final _code = TextEditingController();
  bool _loading = false;

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  Future<void> _join() async {
    final code = _code.text.trim();
    if (code.length < 5 || _loading) return;

    setState(() => _loading = true);

    try {
      await JoinRequestApi.requestJoin(invitationCode: code);
      await AuthService.refreshMembershipsFromServer(
        preferredDiwaniyaId: currentDiwaniyaId,
      );

      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم إرسال طلب الانضمام للمدراء')),
      );
      context.go(AuthService.nextRoute());
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_arabicForJoinError(e))),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تعذر إرسال طلب الانضمام، حاول مرة أخرى')),
      );
    }
  }

  String _arabicForJoinError(ApiException e) {
    final status = e.statusCode;
    final haystack = '${e.code} ${e.message} ${e.toString()}'.toLowerCase();

    if (haystack.contains('invite_not_found') ||
        haystack.contains('not_found') ||
        status == 404) {
      return 'رمز الديوانية غير صحيح';
    }

    if (haystack.contains('already_member') ||
        haystack.contains('already a member') ||
        haystack.contains('you are already') ||
        (status == 409 && haystack.contains('member'))) {
      return 'أنت مسجل في هذه الديوانية';
    }

    if (haystack.contains('duplicate_pending') ||
        haystack.contains('pending request')) {
      return 'لديك طلب انضمام قيد المراجعة لهذه الديوانية';
    }

    if (haystack.contains('cooldown') || status == 429) {
      return 'يرجى الانتظار قبل إرسال طلب جديد';
    }

    return 'تعذر إرسال طلب الانضمام، حاول مرة أخرى';
  }

  @override
  Widget build(BuildContext context) {
    final c = context.cl;
    final samples = AuthService.getLocalDiwaniyaDirectory();

    return Scaffold(
      backgroundColor: c.bg,
      appBar: AppBar(backgroundColor: c.bg),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          children: [
            const _JoinHeroCard(),
            const SizedBox(height: 16),
            _JoinCodeCard(
              controller: _code,
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 16),
            _DirectoryCard(samples: samples),
            const SizedBox(height: 24),
            SizedBox(
              height: 54,
              child: ElevatedButton(
                onPressed: _code.text.trim().length < 5 ? null : _join,
                child: Text(_loading ? Ar.loading : Ar.joinNow),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _JoinHeroCard extends StatelessWidget {
  const _JoinHeroCard();

  @override
  Widget build(BuildContext context) {
    final c = context.cl;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            c.accent.withValues(alpha: 0.14),
            c.accent.withValues(alpha: 0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: c.accent.withValues(alpha: 0.14)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: c.accent.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(
              Icons.login_rounded,
              color: c.accent,
              size: 22,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            'الانضمام إلى ديوانية',
            style: TextStyle(
              fontSize: 25,
              fontWeight: FontWeight.w800,
              color: c.t1,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'أدخل رمز الدعوة للانضمام إلى ديوانية قائمة، وسيتم التحقق من الرمز قبل إتمام الدخول.',
            style: TextStyle(
              fontSize: 14.5,
              height: 1.8,
              color: c.t2,
            ),
          ),
        ],
      ),
    );
  }
}

class _JoinCodeCard extends StatelessWidget {
  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  const _JoinCodeCard({
    required this.controller,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.cl;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: c.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: c.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'رمز الدعوة',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: c.t2,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'اكتب الرمز كما وصلك من مدير الديوانية.',
            style: TextStyle(
              fontSize: 12.5,
              height: 1.7,
              color: c.t3,
            ),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: controller,
            textAlign: TextAlign.center,
            onChanged: onChanged,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              letterSpacing: 3,
              color: c.t1,
            ),
            decoration: const InputDecoration(
              hintText: 'أدخل الرمز',
            ),
          ),
        ],
      ),
    );
  }
}

class _DirectoryCard extends StatelessWidget {
  final List<dynamic> samples;

  const _DirectoryCard({required this.samples});

  @override
  Widget build(BuildContext context) {
    final c = context.cl;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: c.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: c.border),
      ),
      child: samples.isNotEmpty
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'رموز محلية متاحة',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: c.t1,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'يمكن استخدام أحد الرموز التالية لأغراض التجربة المحلية.',
                  style: TextStyle(
                    fontSize: 12.5,
                    height: 1.7,
                    color: c.t3,
                  ),
                ),
                const SizedBox(height: 12),
                for (final d in samples.take(3))
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: c.cardElevated,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 14,
                            backgroundColor: d.color.withValues(alpha: 0.18),
                            child: Text(
                              d.name.substring(0, 1),
                              style: TextStyle(
                                color: d.color,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              d.name,
                              style: TextStyle(color: c.t1),
                            ),
                          ),
                          Text(
                            d.invitationCode ?? '—',
                            style: TextStyle(
                              color: c.t2,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            )
          : Text(
              Ar.joinLocalNote,
              style: TextStyle(
                fontSize: 13.5,
                height: 1.7,
                color: c.t2,
              ),
            ),
    );
  }
}
