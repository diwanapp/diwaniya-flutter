import 'package:flutter/foundation.dart';

import 'api_client.dart';
import 'api_exception.dart';
import 'endpoints.dart';

/// Auth endpoints per `API_CONTRACT_V1`.
///
/// Scope:
///   - POST /auth/otp/request
///   - POST /auth/otp/verify
///   - GET  /me
///   - PATCH /me/profile
///
/// Thin wrapper over [ApiClient]. Returns raw decoded JSON maps — Step 3
/// (auth integration) will map these into the existing domain models.
/// This keeps the API layer free of model coupling.
/// Structured result of an OTP request, used by the auth screen to
/// decide whether to require a name (new user) or allow phone-only
/// (returning user) before navigating to the OTP screen.
///
/// [isNewUser] is `null` when the backend did not provide any signal
/// the client could parse. Callers should treat `null` as "unknown"
/// and apply a safe default (typically: allow submit to proceed).
class OtpRequestResult {
  final bool? isNewUser;
  const OtpRequestResult({this.isNewUser});
}

class AuthApi {
  AuthApi._();

  static const bool _authLogsEnabled = bool.fromEnvironment(
    'ENABLE_AUTH_LOGS',
    defaultValue: false,
  );

  static void _log(String message) {
    if (!kDebugMode || !_authLogsEnabled) return;
    debugPrint('[AuthApi] $message');
  }

  /// Request an OTP code to be sent to the given mobile number.
  ///
  /// Returns an [OtpRequestResult]. On any non-2xx the underlying
  /// [ApiClient] throws [ApiException], so reaching a normal return
  /// means the backend accepted the request.
  ///
  /// The client tolerates several plausible backend response shapes
  /// for the "is this a new user" signal and falls back to `null`
  /// (unknown) if none are present:
  ///   - `is_new_user` (snake_case bool)
  ///   - `isNewUser`   (camelCase bool)
  ///   - `new_user`    (shorter snake_case bool)
  ///   - `user_exists` / `userExists` (inverted)
  ///   - `existing`    (inverted bool)
  static Future<OtpRequestResult> requestOtp({
    required String mobileNumber,
  }) async {
    _log(
      'requestOtp mobile=***${mobileNumber.length >= 4 ? mobileNumber.substring(mobileNumber.length - 4) : mobileNumber}',
    );
    final response = await ApiClient.post(
      Endpoints.otpRequest,
      body: {'mobile_number': mobileNumber},
      authenticated: false,
    );

    if (response is Map<String, dynamic>) {
      final isNew = _readIsNewUser(response);
      _log('requestOtp success isNewUser=$isNew');
      return OtpRequestResult(isNewUser: isNew);
    }
    _log('requestOtp success response-shape=${response.runtimeType}');
    return const OtpRequestResult(isNewUser: null);
  }

  static bool? _readIsNewUser(Map<String, dynamic> body) {
    // Direct "new user" flags
    final isNew = body['is_new_user'] ?? body['isNewUser'] ?? body['new_user'];
    if (isNew is bool) return isNew;

    // Inverted "user exists" flags
    final exists =
        body['user_exists'] ?? body['userExists'] ?? body['existing'];
    if (exists is bool) return !exists;

    // Nested under common wrappers
    final data = body['data'];
    if (data is Map) {
      return _readIsNewUser(Map<String, dynamic>.from(data));
    }
    return null;
  }

  /// Verify an OTP code and exchange it for access + refresh tokens.
  ///
  /// Returns a map containing:
  ///   - `access_token` (String)
  ///   - `refresh_token` (String)
  ///   - `user` (Map with `id`, `mobile_number`, `display_name`, `avatar_url`)
  ///
  /// The caller is responsible for persisting tokens via [TokenStorage]
  /// and mapping the user payload into the domain model.
  static Future<Map<String, dynamic>> verifyOtp({
    required String mobileNumber,
    required String otpCode,
  }) async {
    _log(
      'verifyOtp mobile=***${mobileNumber.length >= 4 ? mobileNumber.substring(mobileNumber.length - 4) : mobileNumber} codeLength=${otpCode.length}',
    );
    final response = await ApiClient.post(
      Endpoints.otpVerify,
      body: {
        'mobile_number': mobileNumber,
        'otp_code': otpCode,
      },
      authenticated: false,
    );
    final map = _expectMap(response, 'verifyOtp');
    _log('verifyOtp success keys=${map.keys.join(',')}');
    return map;
  }

  /// Fetch the currently authenticated user profile.
  /// Returns the raw user map.
  static Future<Map<String, dynamic>> getMe() async {
    final response = await ApiClient.get(Endpoints.me);
    return _expectMap(response, 'getMe');
  }

  /// Update the current user's profile fields.
  /// Fields are optional to allow partial updates per the PATCH contract.
  static Future<Map<String, dynamic>> updateProfile({
    String? displayName,
    String? avatarMediaId,
  }) async {
    final body = <String, dynamic>{
      if (displayName != null) 'display_name': displayName,
      if (avatarMediaId != null) 'avatar_media_id': avatarMediaId,
    };
    final response = await ApiClient.patch(
      Endpoints.meProfile,
      body: body,
    );
    return _expectMap(response, 'updateProfile');
  }

  static Map<String, dynamic> _expectMap(dynamic response, String endpoint) {
    if (response is Map<String, dynamic>) return response;
    throw ApiException(
      code: ApiErrorCode.parse,
      message: 'Unexpected response shape for $endpoint',
    );
  }
}
