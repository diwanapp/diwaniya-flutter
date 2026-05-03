import 'session_service.dart';

class OtpService {
  OtpService._();

  static const _codeKey = 'pendingOtpCode';
  static const _phoneKey = 'pendingOtpPhone';

  static Future<String> sendOtp(String phone) async {
    const code = '1111';
    await SessionService.put(_phoneKey, phone);
    await SessionService.put(_codeKey, code);
    return code;
  }

  static String? get debugCode => SessionService.get<String>(_codeKey);

  static bool verify(String phone, String code) {
    final savedPhone = SessionService.get<String>(_phoneKey);
    final savedCode = SessionService.get<String>(_codeKey);
    return savedPhone == phone && savedCode == code.trim();
  }

  static Future<void> clear() async {
    await SessionService.put(_phoneKey, null);
    await SessionService.put(_codeKey, null);
  }
}
