import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../config/theme/app_colors.dart';
import '../../core/api/api_config.dart';
import '../../core/api/api_exception.dart';
import '../../core/api/auth_api.dart';
import '../../core/services/auth_service.dart';
import '../../l10n/ar.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _first = TextEditingController();
  final _last = TextEditingController();
  final _phone = TextEditingController();
  bool _loading = false;

  bool get _valid => _normalizedPhone(_phone.text).length >= 9;

  @override
  void dispose() {
    _first.dispose();
    _last.dispose();
    _phone.dispose();
    super.dispose();
  }

  String _normalizedPhone(String value) => value.replaceAll(RegExp(r'[^0-9]'), '');

  // UI-level hard timeout for the OTP request. The API client has its
  // own connect/read timeouts, but this backstop guarantees the button
  // can never hang indefinitely regardless of transport-level state.
  static const _otpRequestTimeout = Duration(seconds: 15);

  bool get _devFallbackEnabled =>
      kDebugMode && ApiConfig.devAuthFallback;

  Future<void> _submit() async {
    if (!_valid || _loading) return;
    setState(() => _loading = true);
    final phone = _normalizedPhone(_phone.text);
    final firstName = _first.text.trim();

    try {
      final OtpRequestResult result = await AuthService.requestOtpViaApi(
        firstName: _first.text,
        lastName: _last.text,
        phone: phone,
      ).timeout(_otpRequestTimeout);
      if (!mounted) return;

      // New-user gate: if the backend flagged this phone as new and
      // the user didn't type a first name, block navigation to OTP
      // and show the message. The OTP was already sent — if the user
      // adds a name and retries, a fresh OTP will be requested.
      //
      // When isNewUser is null (backend didn't signal), we fall open
      // and allow the user to proceed, preserving prior behavior.
      if (result.isNewUser == true && firstName.isEmpty) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'هذا الرقم غير مسجل بعد. يرجى إدخال الاسم أولًا لإكمال التسجيل.',
            ),
          ),
        );
        return;
      }

      setState(() => _loading = false);
      context.push('/otp');
    } on TimeoutException {
      if (!mounted) return;
      // Dev fallback: backend unreachable, degrade to mock OTP path.
      if (_devFallbackEnabled) {
        await _runDevFallback(phone);
        return;
      }
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'تعذر الاتصال بخدمة التحقق. تأكد من تشغيل الخادم أو تحقق من الاتصال ثم حاول مرة أخرى.',
          ),
        ),
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      // Dev fallback: on any API error while dev mode is enabled,
      // skip the real backend path entirely so the developer can
      // keep iterating on downstream screens.
      if (_devFallbackEnabled) {
        await _runDevFallback(phone);
        return;
      }
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            e.isNetwork
                ? 'تحقق من الاتصال بالإنترنت وحاول مرة أخرى'
                : (e.message.isNotEmpty
                    ? e.message
                    : 'تعذّر إرسال رمز التحقق'),
          ),
        ),
      );
    } catch (_) {
      // Final safety net: any unexpected error must not leave the
      // button in loading state.
      if (!mounted) return;
      if (_devFallbackEnabled) {
        await _runDevFallback(phone);
        return;
      }
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('حدث خطأ غير متوقع، حاول مرة أخرى.'),
        ),
      );
    }
  }

  /// Dev-only fallback path. Saves the local profile draft through
  /// the dev-fallback method (which sets otpRequestedInSession) and
  /// navigates to the OTP screen. A subtle snackbar makes the mode
  /// impossible to miss. Only called when `_devFallbackEnabled` is
  /// true, which in turn requires both `kDebugMode` AND the build-time
  /// `--dart-define=DIWANIYA_DEV_AUTH_FALLBACK=true`.
  ///
  /// Dev mode has no backend to distinguish existing vs new users, so
  /// every dev-mode submission is treated as potentially new: first
  /// name is REQUIRED before we navigate to OTP. This mirrors the
  /// real-backend new-user gate and prevents accounts from being
  /// created with an empty identity in dev builds.
  Future<void> _runDevFallback(String phone) async {
    final firstName = _first.text.trim();
    if (firstName.isEmpty) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'هذا الرقم غير مسجل بعد. يرجى إدخال الاسم أولًا لإكمال التسجيل.',
          ),
        ),
      );
      return;
    }
    try {
      await AuthService.requestOtpViaDevFallback(
        firstName: _first.text,
        lastName: _last.text,
        phone: phone,
      );
    } catch (_) {
      // Dev fallback should never fail, but be defensive.
      if (!mounted) return;
      setState(() => _loading = false);
      return;
    }
    if (!mounted) return;
    setState(() => _loading = false);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'الوضع التطويري — تم تخطي خدمة OTP (رمز التحقق: 000000)',
        ),
      ),
    );
    context.push('/otp');
  }

  @override
  Widget build(BuildContext context) {
    final c = context.cl;
    return Scaffold(
      backgroundColor: c.bg,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 22, 24, 24),
          children: [
            const SizedBox(height: 8),
            Text(Ar.authTitle,
                style: TextStyle(fontSize: 30, fontWeight: FontWeight.w900, color: c.t1)),
            const SizedBox(height: 10),
            Text(Ar.authSubtitle,
                style: TextStyle(fontSize: 15, height: 1.7, color: c.t2)),
            const SizedBox(height: 24),
            _Field(
              controller: _first,
              label: Ar.firstName,
              hint: Ar.firstNameHint,
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 6),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Text(
                'مطلوب للمستخدمين الجدد فقط. إذا سبق وسجلت برقمك، اتركه فارغًا وسجّل دخول مباشرة.',
                style: TextStyle(
                  fontSize: 12,
                  height: 1.6,
                  color: c.t3,
                ),
              ),
            ),
            const SizedBox(height: 14),
            _Field(
              controller: _last,
              label: Ar.lastNameOptional,
              hint: Ar.lastNameHint,
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 14),
            _Field(
              controller: _phone,
              label: Ar.phoneNumber,
              hint: Ar.phoneHint,
              keyboardType: TextInputType.phone,
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: c.card,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: c.border),
              ),
              child: Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: c.accentMuted,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(Icons.lock_outline_rounded, color: c.accent),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      Ar.otpExplainer,
                      style: TextStyle(fontSize: 13.5, height: 1.7, color: c.t2),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              height: 54,
              child: ElevatedButton(
                onPressed: _valid ? _submit : null,
                child: Text(_loading ? Ar.loading : Ar.sendOtp),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              Ar.authFooter,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: c.t3),
            ),
          ],
        ),
      ),
    );
  }
}

class _Field extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String hint;
  final TextInputType? keyboardType;
  final ValueChanged<String>? onChanged;
  const _Field({
    required this.controller,
    required this.label,
    required this.hint,
    this.keyboardType,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.cl;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: c.t2)),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          onChanged: onChanged,
          keyboardType: keyboardType,
          decoration: InputDecoration(hintText: hint),
        ),
      ],
    );
  }
}
