import 'api_client.dart';
import 'api_exception.dart';
import 'endpoints.dart';

/// Client for the backend `/join-requests` and `/me/join-requests`
/// endpoints introduced in Backend Stages 1 + 2. Mirrors the static
/// pattern used by DiwaniyaApi, AuthApi, MeApi.
///
/// Coexists with the legacy `DiwaniyaApi.acceptInvite` for now —
/// Flutter will migrate the join screen incrementally in Stage 5.
class JoinRequestApi {
  JoinRequestApi._();

  /// POST /join-requests — create a pending join request from an
  /// invite code. Returns the request map. Throws ApiException on
  /// 404 (invalid code), 409 (already member / duplicate), 429
  /// (rejection cooldown).
  static Future<Map<String, dynamic>> requestJoin({
    required String invitationCode,
  }) async {
    final normalizedCode = invitationCode.trim().toUpperCase();
    if (normalizedCode.isEmpty) {
      throw const ApiException(
        code: ApiErrorCode.validation,
        message: 'رمز الدعوة مطلوب',
      );
    }

    final response = await ApiClient.post(
      Endpoints.joinRequests,
      body: {'invitation_code': normalizedCode},
    );
    if (response is! Map) {
      throw const ApiException(
        code: ApiErrorCode.parse,
        message: 'Malformed /join-requests response',
      );
    }
    return Map<String, dynamic>.from(response);
  }

  /// GET /me/join-requests — list current user's pending and
  /// resolved join requests. Used by post-login hydration so the
  /// home screen can show "waiting for approval" / "rejected" UX
  /// without polluting the approved-membership list.
  static Future<List<Map<String, dynamic>>> getMyJoinRequests() async {
    final response = await ApiClient.get(Endpoints.meJoinRequests);
    if (response is! Map) return const [];
    final raw = response['requests'];
    if (raw is! List) return const [];
    return raw
        .whereType<Map>()
        .map((m) => Map<String, dynamic>.from(m))
        .toList();
  }

  /// GET /diwaniyas/{id}/join-requests — manager-only listing of
  /// pending requests for a diwaniya. Used by the manager review UI.
  static Future<List<Map<String, dynamic>>> listPendingForDiwaniya(
    String diwaniyaId,
  ) async {
    final normalizedId = diwaniyaId.trim();
    if (normalizedId.isEmpty) {
      throw const ApiException(
        code: ApiErrorCode.validation,
        message: 'معرّف الديوانية غير صالح',
      );
    }

    final response = await ApiClient.get(
      Endpoints.diwaniyaJoinRequests(normalizedId),
    );
    if (response is! Map) return const [];
    final raw = response['requests'];
    if (raw is! List) return const [];
    return raw
        .whereType<Map>()
        .map((m) => Map<String, dynamic>.from(m))
        .toList();
  }

  /// POST /join-requests/{id}/approve — manager approves a pending
  /// request. Returns the resolved request map (includes membership_id).
  static Future<Map<String, dynamic>> approve(String requestId) async {
    final normalizedId = requestId.trim();
    if (normalizedId.isEmpty) {
      throw const ApiException(
        code: ApiErrorCode.validation,
        message: 'معرّف الطلب غير صالح',
      );
    }

    final response = await ApiClient.post(
      Endpoints.joinRequestApprove(normalizedId),
    );
    if (response is! Map) {
      throw const ApiException(
        code: ApiErrorCode.parse,
        message: 'Malformed approve response',
      );
    }
    return Map<String, dynamic>.from(response);
  }

  /// POST /join-requests/{id}/reject — manager rejects a pending
  /// request. Returns the resolved request map. Starts the 24h
  /// cooldown clock for the requester.
  static Future<Map<String, dynamic>> reject(String requestId) async {
    final normalizedId = requestId.trim();
    if (normalizedId.isEmpty) {
      throw const ApiException(
        code: ApiErrorCode.validation,
        message: 'معرّف الطلب غير صالح',
      );
    }

    final response = await ApiClient.post(
      Endpoints.joinRequestReject(normalizedId),
    );
    if (response is! Map) {
      throw const ApiException(
        code: ApiErrorCode.parse,
        message: 'Malformed reject response',
      );
    }
    return Map<String, dynamic>.from(response);
  }
}
