import 'api_client.dart';
import 'api_exception.dart';
import 'endpoints.dart';

/// Thin client for the backend `/me/*` endpoints. Mirrors the static
/// pattern used by `DiwaniyaApi` and `AuthApi` so the project's
/// existing call conventions stay consistent.
class MeApi {
  MeApi._();

  /// GET /me/diwaniyas — returns the list of diwaniyas the current
  /// authenticated user belongs to. Used by post-login hydration to
  /// route returning users directly into their existing context
  /// instead of the create/join screen.
  ///
  /// Returns an empty list (never null, never throws) on any
  /// malformed response shape so callers can wrap the call in a
  /// single try/catch and treat empty as "no diwaniyas".
  static Future<List<Map<String, dynamic>>> getMyDiwaniyas() async {
    final response = await ApiClient.get(Endpoints.meDiwaniyas);
    if (response is! Map) return const [];
    final raw = response['diwaniyas'];
    if (raw is! List) return const [];
    return raw
        .whereType<Map>()
        .map((m) => Map<String, dynamic>.from(m))
        .toList();
  }

  /// PATCH /me/profile — updates the current user's display_name.
  /// Returns the updated user map: {id, mobile_number, display_name}.
  /// Throws ApiException on failure (caller maps to UI feedback).
  static Future<Map<String, dynamic>> updateProfile({
    required String displayName,
  }) async {
    final response = await ApiClient.patch(
      Endpoints.meProfile,
      body: {'display_name': displayName},
    );
    if (response is! Map) {
      throw const ApiException(
        code: ApiErrorCode.parse,
        message: 'Malformed /me/profile response',
      );
    }
    return Map<String, dynamic>.from(response);
  }
}
