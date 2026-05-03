import 'dart:async';

import 'package:flutter/material.dart';

import '../../config/theme/app_colors.dart';
import '../../core/services/app_lock_service.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/session_service.dart';

class SessionBiometricGate extends StatefulWidget {
  final Widget child;
  const SessionBiometricGate({super.key, required this.child});

  @override
  State<SessionBiometricGate> createState() => _SessionBiometricGateState();
}

class _SessionBiometricGateState extends State<SessionBiometricGate>
    with WidgetsBindingObserver {
  bool _checkingSupport = true;
  bool _lockingSupported = false;
  bool _unlockInProgress = false;
  bool _isUnlocked = false;
  String? _errorText;

  bool get _hasAuthenticatedSession =>
      SessionService.hasSession &&
      AuthService.profile != null &&
      AuthService.otpVerified;

  bool get _needsGate => _lockingSupported && _hasAuthenticatedSession;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    final supported = await AppLockService.isSupported();
    if (!mounted) return;

    setState(() {
      _checkingSupport = false;
      _lockingSupported = supported;
      _isUnlocked = !supported || !_hasAuthenticatedSession;
      _errorText = null;
    });

    if (_needsGate) {
      unawaited(_unlock(auto: true));
    }
  }

  @override
  void didUpdateWidget(covariant SessionBiometricGate oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (!_hasAuthenticatedSession) {
      if (!_isUnlocked || _errorText != null) {
        setState(() {
          _isUnlocked = true;
          _errorText = null;
        });
      }
      return;
    }

    if (_lockingSupported && !_isUnlocked && !_unlockInProgress) {
      unawaited(_unlock(auto: true));
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!_lockingSupported || !_hasAuthenticatedSession) return;

    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused) {
      if (mounted) {
        setState(() {
          _isUnlocked = false;
          _errorText = null;
        });
      }
    } else if (state == AppLifecycleState.resumed &&
        !_isUnlocked &&
        !_unlockInProgress) {
      unawaited(_unlock(auto: true));
    }
  }

  Future<void> _unlock({bool auto = false}) async {
    if (_unlockInProgress || !_needsGate) return;

    setState(() {
      _unlockInProgress = true;
      if (!auto) _errorText = null;
    });

    try {
      final result = await AppLockService.authenticateDetailed();
      if (!mounted) return;

      if (!result.supported) {
        setState(() {
          _lockingSupported = false;
          _unlockInProgress = false;
          _isUnlocked = true;
          _errorText = null;
        });
        return;
      }

      setState(() {
        _unlockInProgress = false;
        _isUnlocked = result.success;
        _errorText = result.success ? null : result.errorText;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _unlockInProgress = false;
        _isUnlocked = false;
        _errorText = 'تعذر التحقق من الهوية. حاول مرة أخرى.';
      });
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.cl;

    if (_checkingSupport || !_needsGate || _isUnlocked) {
      return widget.child;
    }

    return Scaffold(
      backgroundColor: c.bg,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: c.card,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: c.border),
                  boxShadow: [BoxShadow(color: c.shadow, blurRadius: 10)],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 68,
                      height: 68,
                      decoration: BoxDecoration(
                        color: c.accentMuted,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Icon(
                        Icons.fingerprint_rounded,
                        size: 34,
                        color: c.accent,
                      ),
                    ),
                    const SizedBox(height: 18),
                    Text(
                      'تأكيد الهوية',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: c.t1,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'للمحافظة على خصوصيتك، استخدم البصمة أو Face ID أو قفل الجهاز للمتابعة.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        height: 1.8,
                        color: c.t2,
                      ),
                    ),
                    if (_errorText != null) ...[
                      const SizedBox(height: 14),
                      Text(
                        _errorText!,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 12.5,
                          height: 1.7,
                          color: c.error,
                        ),
                      ),
                    ],
                    const SizedBox(height: 22),
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton.icon(
                        onPressed: _unlockInProgress
                            ? null
                            : () => _unlock(auto: false),
                        icon: Icon(
                          _unlockInProgress
                              ? Icons.hourglass_top_rounded
                              : Icons.lock_open_rounded,
                        ),
                        label: Text(
                          _unlockInProgress ? 'جارٍ التحقق...' : 'المتابعة',
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'سيظهر لك طلب التحقق تلقائيًا عند فتح التطبيق أو العودة إليه.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 11.5,
                        height: 1.6,
                        color: c.t3,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
