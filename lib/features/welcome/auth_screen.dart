import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../config/theme/app_colors.dart';
import '../../core/api/api_config.dart';
import '../../core/api/api_exception.dart';
import '../../core/api/auth_api.dart';
import '../../core/services/auth_service.dart';

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

  String _normalizedPhone(String value) =>
      value.replaceAll(RegExp(r'[^0-9]'), '');

  static const _otpRequestTimeout = Duration(seconds: 15);

  bool get _devFallbackEnabled => kDebugMode && ApiConfig.devAuthFallback;

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

      if (result.isNewUser == true && firstName.isEmpty) {
        setState(() => _loading = false);
        _showSnack('هذا الرقم غير مسجل. أدخل الاسم الأول لإكمال التسجيل.');
        return;
      }

      setState(() => _loading = false);
      context.push('/otp');
    } on TimeoutException {
      if (!mounted) return;

      if (_devFallbackEnabled) {
        await _runDevFallback(phone);
        return;
      }

      setState(() => _loading = false);
      _showSnack('تعذر الاتصال بخدمة التحقق. تأكد من الاتصال وحاول مرة أخرى.');
    } on ApiException catch (e) {
      if (!mounted) return;

      if (_devFallbackEnabled) {
        await _runDevFallback(phone);
        return;
      }

      setState(() => _loading = false);
      _showSnack(
        e.isNetwork
            ? 'تعذر الاتصال بالإنترنت. حاول مرة أخرى.'
            : (e.message.isNotEmpty
                ? e.message
                : 'تعذر إرسال رمز التحقق. حاول مرة أخرى.'),
      );
    } catch (_) {
      if (!mounted) return;

      if (_devFallbackEnabled) {
        await _runDevFallback(phone);
        return;
      }

      setState(() => _loading = false);
      _showSnack('حدث خطأ غير متوقع. حاول مرة أخرى.');
    }
  }

  Future<void> _runDevFallback(String phone) async {
    final firstName = _first.text.trim();

    if (firstName.isEmpty) {
      if (!mounted) return;
      setState(() => _loading = false);
      _showSnack('هذا الرقم غير مسجل. أدخل الاسم الأول لإكمال التسجيل.');
      return;
    }

    try {
      await AuthService.requestOtpViaDevFallback(
        firstName: _first.text,
        lastName: _last.text,
        phone: phone,
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
      return;
    }

    if (!mounted) return;
    setState(() => _loading = false);
    _showSnack('وضع التطوير مفعّل — رمز التحقق: 000000');
    context.push('/otp');
  }

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message, textAlign: TextAlign.right)),
    );
  }

  void _openTerms() {
    final c = context.cl;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: SafeArea(
            child: Container(
              margin: const EdgeInsets.all(14),
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
              decoration: BoxDecoration(
                color: c.card,
                borderRadius: BorderRadius.circular(28),
                border: Border.all(
                  color: const Color(0xFFC8AD83).withValues(alpha: 0.16),
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'شروط استخدام ديوانية',
                    textAlign: TextAlign.right,
                    style: TextStyle(
                      color: c.t1,
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'باستخدامك للتطبيق، فإنك توافق على استخدام ديوانية لإدارة الديوانيات، المصاريف، المقاضي، التصويتات، الدردشة، والألبوم وفق الضوابط المعتمدة داخل التطبيق. سيتم عرض النسخة القانونية الكاملة قبل الإطلاق الرسمي.',
                    textAlign: TextAlign.right,
                    style: TextStyle(
                      color: c.t2,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      height: 1.65,
                    ),
                  ),
                  const SizedBox(height: 18),
                  SizedBox(
                    height: 48,
                    child: ElevatedButton(
                      onPressed: () => Navigator.of(sheetContext).pop(),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFC8AD83),
                        foregroundColor: c.bg,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                        ),
                      ),
                      child: const Text(
                        'فهمت',
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 15,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.cl;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: c.bg,
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(22, 18, 22, 24),
            children: [
              const SizedBox(height: 18),
              const _AuthBrandHeader(),
              const SizedBox(height: 34),
              Text(
                'إنشاء حساب أو الدخول',
                textAlign: TextAlign.right,
                style: TextStyle(
                  color: c.t1,
                  fontSize: 31,
                  fontWeight: FontWeight.w900,
                  height: 1.12,
                  letterSpacing: -0.4,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'أدخل رقم جوالك، وراح نرسل لك رمز تحقق آمن.',
                textAlign: TextAlign.right,
                style: TextStyle(
                  color: c.t2,
                  fontSize: 15.5,
                  fontWeight: FontWeight.w600,
                  height: 1.65,
                ),
              ),
              const SizedBox(height: 26),
              _AuthCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _PremiumField(
                      controller: _phone,
                      label: 'رقم الجوال',
                      keyboardType: TextInputType.phone,
                      icon: Icons.phone_iphone_rounded,
                      autofocus: true,
                      onChanged: (_) => setState(() {}),
                    ),
                    const SizedBox(height: 18),
                    _FirstTimeSection(
                      first: _first,
                      last: _last,
                      onChanged: (_) => setState(() {}),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 22),
              _PrimaryAuthButton(
                enabled: _valid && !_loading,
                loading: _loading,
                onTap: _submit,
              ),
              const SizedBox(height: 14),
              RichText(
                textAlign: TextAlign.center,
                textDirection: TextDirection.rtl,
                text: TextSpan(
                  style: TextStyle(
                    color: c.t3,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w500,
                    height: 1.55,
                  ),
                  children: [
                    const TextSpan(text: 'بمتابعتك، أنت توافق على '),
                    TextSpan(
                      text: 'شروط استخدام ديوانية',
                      style: const TextStyle(
                        color: Color(0xFFC8AD83),
                        fontWeight: FontWeight.w900,
                        decoration: TextDecoration.underline,
                        decorationThickness: 1.4,
                      ),
                      recognizer: TapGestureRecognizer()..onTap = _openTerms,
                    ),
                    const TextSpan(text: '.'),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AuthBrandHeader extends StatelessWidget {
  const _AuthBrandHeader();

  @override
  Widget build(BuildContext context) {
    final c = context.cl;

    return Center(
      child: SizedBox(
        width: 148,
        height: 148,
        child: Image.asset(
          'assets/brand/logo_mark_splash_1024.png',
          fit: BoxFit.contain,
          errorBuilder: (_, __, ___) => Image.asset(
            'assets/brand/2-1024_Transparent.png',
            fit: BoxFit.contain,
            errorBuilder: (_, __, ___) => Icon(
              Icons.groups_rounded,
              color: c.accent,
              size: 54,
            ),
          ),
        ),
      ),
    );
  }
}

class _AuthCard extends StatelessWidget {
  final Widget child;

  const _AuthCard({required this.child});

  @override
  Widget build(BuildContext context) {
    final c = context.cl;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 17),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: [
            const Color(0xFF183B55).withValues(alpha: 0.46),
            c.card.withValues(alpha: 0.72),
            const Color(0xFF10263A).withValues(alpha: 0.40),
          ],
        ),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: const Color(0xFFC8AD83).withValues(alpha: 0.13),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.18),
            blurRadius: 28,
            offset: const Offset(0, 16),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _FirstTimeSection extends StatelessWidget {
  final TextEditingController first;
  final TextEditingController last;
  final ValueChanged<String>? onChanged;

  const _FirstTimeSection({
    required this.first,
    required this.last,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.cl;

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 13, 14, 14),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: const Color(0xFFC8AD83).withValues(alpha: 0.08),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: const Color(0xFFC8AD83).withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.person_add_alt_1_rounded,
                  color: Color(0xFFC8AD83),
                  size: 19,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'غير مسجل سابقًا؟',
                  textAlign: TextAlign.right,
                  style: TextStyle(
                    color: c.t1,
                    fontSize: 14.5,
                    fontWeight: FontWeight.w900,
                    height: 1.2,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'أدخل اسمك لإكمال إنشاء الحساب.',
            textAlign: TextAlign.right,
            style: TextStyle(
              color: c.t3,
              fontSize: 12.8,
              fontWeight: FontWeight.w600,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 14),
          _PremiumField(
            controller: first,
            label: 'الاسم الأول',
            icon: Icons.badge_rounded,
            onChanged: onChanged,
          ),
          const SizedBox(height: 12),
          _PremiumField(
            controller: last,
            label: 'الاسم الأخير',
            icon: Icons.person_outline_rounded,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}

class _PremiumField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final IconData icon;
  final TextInputType? keyboardType;
  final ValueChanged<String>? onChanged;
  final bool autofocus;

  const _PremiumField({
    required this.controller,
    required this.label,
    required this.icon,
    this.keyboardType,
    this.onChanged,
    this.autofocus = false,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.cl;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          label,
          textAlign: TextAlign.right,
          style: TextStyle(
            color: c.t2,
            fontSize: 13.2,
            fontWeight: FontWeight.w800,
            height: 1.2,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          autofocus: autofocus,
          onChanged: onChanged,
          keyboardType: keyboardType,
          textAlign: TextAlign.right,
          textDirection: TextDirection.rtl,
          style: TextStyle(
            color: c.t1,
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
          decoration: InputDecoration(
            hintText: '',
            prefixIcon: Icon(icon, color: const Color(0xFFC8AD83), size: 21),
            filled: true,
            fillColor: const Color(0xFF183B55).withValues(alpha: 0.46),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(19),
              borderSide: BorderSide(
                color: Colors.white.withValues(alpha: 0.045),
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(19),
              borderSide: const BorderSide(
                color: Color(0xFFC8AD83),
                width: 1.4,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _PrimaryAuthButton extends StatelessWidget {
  final bool enabled;
  final bool loading;
  final VoidCallback onTap;

  const _PrimaryAuthButton({
    required this.enabled,
    required this.loading,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.cl;

    return Opacity(
      opacity: enabled ? 1 : 0.48,
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(23),
        child: InkWell(
          borderRadius: BorderRadius.circular(23),
          onTap: enabled ? onTap : null,
          child: Ink(
            height: 58,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.centerRight,
                end: Alignment.centerLeft,
                colors: [
                  Color(0xFFF5EFE3),
                  Color(0xFFC8AD83),
                  Color(0xFFB79A72),
                ],
              ),
              borderRadius: BorderRadius.circular(23),
              boxShadow: enabled
                  ? [
                      BoxShadow(
                        color: const Color(0xFFC8AD83).withValues(alpha: 0.22),
                        blurRadius: 24,
                        offset: const Offset(0, 12),
                      ),
                    ]
                  : null,
            ),
            child: Center(
              child: loading
                  ? SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.4,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          c.bg,
                        ),
                      ),
                    )
                  : Text(
                      'إرسال رمز التحقق',
                      style: TextStyle(
                        color: c.bg,
                        fontSize: 16.5,
                        fontWeight: FontWeight.w900,
                        height: 1,
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}
