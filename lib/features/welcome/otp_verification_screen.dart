import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../config/theme/app_colors.dart';
import '../../core/api/api_config.dart';
import '../../core/api/api_exception.dart';
import '../../core/services/auth_service.dart';
import '../../l10n/ar.dart';

class OtpVerificationScreen extends StatefulWidget {
  const OtpVerificationScreen({super.key});

  @override
  State<OtpVerificationScreen> createState() => _OtpVerificationScreenState();
}

class _OtpVerificationScreenState extends State<OtpVerificationScreen> {
  final TextEditingController _otp = TextEditingController();
  bool _loading = false;

  static const _verifyTimeout = Duration(seconds: 15);

  bool get _devFallbackEnabled =>
      kDebugMode && ApiConfig.devAuthFallback;

  @override
  void dispose() {
    _otp.dispose();
    super.dispose();
  }

  Future<void> _verify() async {
    final phone = AuthService.currentPhone;
    final code = _otp.text.trim();
    if (code.length != 6 || phone.isEmpty) {
      return;
    }

    setState(() => _loading = true);

    try {
      await AuthService.verifyOtpViaApi(phone: phone, otpCode: code)
          .timeout(_verifyTimeout);

      if (!mounted) return;
      // F2: Keep _loading = true through the navigation call so the
      // user sees continuous feedback (button spinner remains) instead
      // of a dead frame between loading-off and the next screen's
      // first build. The new screen replaces this one immediately.
      context.go(AuthService.nextRoute());
    } on TimeoutException {
      if (!mounted) return;
      if (_devFallbackEnabled) {
        await _runDevVerifyFallback(code);
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
      if (_devFallbackEnabled) {
        await _runDevVerifyFallback(code);
        return;
      }
      setState(() => _loading = false);
      final message = e.code == ApiErrorCode.unauthorized ||
              e.code == ApiErrorCode.validation
          ? Ar.invalidOtp
          : (e.isNetwork
              ? 'تحقق من الاتصال بالإنترنت وحاول مرة أخرى'
              : (e.message.isNotEmpty ? e.message : Ar.invalidOtp));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    } catch (_) {
      if (!mounted) return;
      if (_devFallbackEnabled) {
        await _runDevVerifyFallback(code);
        return;
      }
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('حدث خطأ غير متوقع، حاول مرة أخرى.')),
      );
    }
  }

  /// Dev-only verify fallback. Accepts exactly "000000"; anything else
  /// surfaces the standard invalid-OTP message so the developer knows
  /// what to type. Gated by `_devFallbackEnabled`.
  Future<void> _runDevVerifyFallback(String code) async {
    try {
      await AuthService.verifyOtpViaDevFallback(code: code);
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('الوضع التطويري — تم التحقق محليًا'),
        ),
      );
      context.go(AuthService.nextRoute());
    } on ApiException {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('رمز التطوير غير صحيح. استخدم 000000.'),
        ),
      );
    }
  }

  Future<void> _resend() async {
    // Resend uses the same API path as the initial request.
    final phone = AuthService.currentPhone;
    if (phone.isEmpty) return;

    try {
      await AuthService.requestOtpViaApi(
        firstName: AuthService.profile?.firstName ?? '',
        lastName: AuthService.profile?.lastName ?? '',
        phone: phone,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم إعادة إرسال الرمز')),
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            e.isNetwork
                ? 'تحقق من الاتصال بالإنترنت وحاول مرة أخرى'
                : (e.message.isNotEmpty
                    ? e.message
                    : 'تعذّر إعادة الإرسال'),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.cl;
    final profile = AuthService.profile;

    return Scaffold(
      backgroundColor: c.bg,
      appBar: AppBar(
        backgroundColor: c.bg,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/auth');
            }
          },
        ),
      ),
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) => AnimatedPadding(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOut,
            padding: EdgeInsets.fromLTRB(
              24,
              12,
              24,
              24 + MediaQuery.of(context).viewInsets.bottom,
            ),
            child: SingleChildScrollView(
              keyboardDismissBehavior:
                  ScrollViewKeyboardDismissBehavior.onDrag,
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight - 36),
                child: IntrinsicHeight(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
              Text(
                Ar.otpTitle,
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  color: c.t1,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                '${Ar.otpSubtitle} ${profile?.phone ?? ''}',
                style: TextStyle(
                  fontSize: 15,
                  height: 1.7,
                  color: c.t2,
                ),
              ),
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: c.card,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: c.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      Ar.otpCode,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: c.t2,
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _otp,
                      keyboardType: TextInputType.number,
                      maxLength: 6,
                      textAlign: TextAlign.center,
                      onChanged: (_) => setState(() {}),
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        color: c.t1,
                      ),
                      decoration: const InputDecoration(
                        counterText: '',
                        hintText: '123456',
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'أدخل رمز التحقق المرسل إلى جوالك.',
                      style: TextStyle(
                        color: c.t3,
                        fontSize: 12,
                      ),
                    ),
                    if (kDebugMode) ...[
                      const SizedBox(height: 6),
                      Text(
                        'ملاحظة للمطوّر: رمز التحقق هو الرمز المُرسَل إلى رقم الجوال. '
                        'في بيئة التطوير المحلية، إذا لم يكن إرسال SMS مفعّلًا، '
                        'فعادةً ما يُطبع الرمز في سجلات الخادم (backend logs). '
                        'وإذا كان الخادم مهيّأً برمز OTP ثابت للتطوير، فاستخدم تلك القيمة المهيّأة.',
                        style: TextStyle(
                          color: c.t3,
                          fontSize: 11,
                          height: 1.6,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  onPressed: (_loading || _otp.text.trim().length != 6)
                      ? null
                      : _verify,
                  child: Text(_loading ? Ar.loading : Ar.verifyOtp),
                ),
              ),
              TextButton(
                onPressed: _loading ? null : _resend,
                child: const Text(Ar.resendOtp),
              ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}