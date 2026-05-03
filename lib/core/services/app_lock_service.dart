import 'package:local_auth/local_auth.dart';

class AppLockServiceResult {
  final bool success;
  final bool supported;
  final bool enrolled;
  final String? errorCode;
  final String? errorText;

  const AppLockServiceResult({
    required this.success,
    required this.supported,
    required this.enrolled,
    this.errorCode,
    this.errorText,
  });
}

class AppLockService {
  AppLockService._();

  static const String _reason =
      'استخدم البصمة أو Face ID أو قفل الجهاز للمتابعة إلى التطبيق';

  static final LocalAuthentication _auth = LocalAuthentication();

  static Future<bool> isSupported() async {
    try {
      final canCheckBiometrics = await _auth.canCheckBiometrics;
      final isDeviceSupported = await _auth.isDeviceSupported();
      return canCheckBiometrics || isDeviceSupported;
    } catch (_) {
      return false;
    }
  }

  static Future<AppLockServiceResult> authenticateDetailed() async {
    try {
      final canCheckBiometrics = await _auth.canCheckBiometrics;
      final isDeviceSupported = await _auth.isDeviceSupported();

      if (!canCheckBiometrics && !isDeviceSupported) {
        return const AppLockServiceResult(
          success: false,
          supported: false,
          enrolled: false,
          errorCode: 'unsupported',
          errorText: 'هذا الجهاز لا يدعم التحقق بالبصمة أو Face ID.',
        );
      }

      final available = await _auth.getAvailableBiometrics();
      final hasEnrolledBiometric = available.isNotEmpty;

      final ok = await _auth.authenticate(
        localizedReason: _reason,
        biometricOnly: false,
        persistAcrossBackgrounding: true,
      );

      return AppLockServiceResult(
        success: ok,
        supported: true,
        enrolled: hasEnrolledBiometric || isDeviceSupported,
        errorCode: ok ? null : 'cancelled',
        errorText: ok ? null : 'تم إلغاء التحقق أو لم يكتمل.',
      );
    } on LocalAuthException catch (e) {
      final code = e.code.name;
      return AppLockServiceResult(
        success: false,
        supported: true,
        enrolled: true,
        errorCode: code,
        errorText: _messageForCode(code),
      );
    } catch (_) {
      return const AppLockServiceResult(
        success: false,
        supported: true,
        enrolled: true,
        errorCode: 'unknown',
        errorText: 'تعذر التحقق من الهوية. حاول مرة أخرى.',
      );
    }
  }

  static Future<bool> authenticate() async {
    final result = await authenticateDetailed();
    return result.success;
  }

  static String _messageForCode(String code) {
    switch (code) {
      case 'noBiometricHardware':
        return 'هذا الجهاز لا يدعم البصمة أو Face ID.';
      case 'temporaryLockout':
        return 'تم إيقاف التحقق الحيوي مؤقتًا. استخدم قفل الجهاز ثم حاول مرة أخرى.';
      case 'biometricLockout':
        return 'تم قفل التحقق الحيوي. افتح الجهاز أولًا ثم حاول مرة أخرى.';
      case 'notAvailable':
        return 'المصادقة الحيوية غير متاحة حاليًا على هذا الجهاز.';
      case 'passcodeNotSet':
        return 'يجب تفعيل قفل الشاشة على الجهاز أولًا.';
      case 'otherOperatingSystem':
        return 'نظام التشغيل الحالي لا يدعم هذه العملية.';
      case 'userCanceled':
      case 'systemCanceled':
        return 'تم إلغاء التحقق قبل اكتماله.';
      default:
        return 'تعذر التحقق من الهوية. حاول مرة أخرى.';
    }
  }
}
