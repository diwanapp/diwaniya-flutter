import 'api_client.dart';
import 'api_exception.dart';
import 'endpoints.dart';

/// Client for the diwaniya management endpoints introduced in Backend
/// Stage 3: promote, demote, leave, delete, regenerate invite.
///
/// Backend is the source of truth for every guard (last manager,
/// sole member, manager-only). Flutter local guards are UX hints
/// only; the backend response is authoritative.
class DiwaniyaManagementApi {
  DiwaniyaManagementApi._();


  static String _normalizedRequiredId(String value, String label) {
    final normalized = value.trim();
    if (normalized.isEmpty) {
      throw ApiException(
        code: ApiErrorCode.validation,
        message: '$label غير صالح',
      );
    }
    return normalized;
  }

  /// POST /diwaniyas/{id}/members/{userId}/promote
  /// Returns the updated membership map.
  static Future<Map<String, dynamic>> promote({
    required String diwaniyaId,
    required String userId,
  }) async {
    final response = await ApiClient.post(
      Endpoints.diwaniyaMemberPromote(_normalizedRequiredId(diwaniyaId, 'معرّف الديوانية'), _normalizedRequiredId(userId, 'معرّف المستخدم')),
    );
    return _expectMap(response, 'promote');
  }

  /// POST /diwaniyas/{id}/members/{userId}/demote
  /// Throws ApiException 409 last_manager if blocked.
  static Future<Map<String, dynamic>> demote({
    required String diwaniyaId,
    required String userId,
  }) async {
    final response = await ApiClient.post(
      Endpoints.diwaniyaMemberDemote(_normalizedRequiredId(diwaniyaId, 'معرّف الديوانية'), _normalizedRequiredId(userId, 'معرّف المستخدم')),
    );
    return _expectMap(response, 'demote');
  }

  /// POST /diwaniyas/{id}/leave
  /// Returns null on success (204). Throws ApiException 409 if
  /// last_manager or sole_member_must_delete.
  static Future<void> leave(String diwaniyaId) async {
    await ApiClient.post(Endpoints.diwaniyaLeave(_normalizedRequiredId(diwaniyaId, 'معرّف الديوانية')));
  }

  /// DELETE /diwaniyas/{id}
  /// Returns null on success (204). Only allowed when the actor is
  /// the sole remaining member AND a manager.
  static Future<void> deleteDiwaniya(String diwaniyaId) async {
    await ApiClient.delete(Endpoints.diwaniya(_normalizedRequiredId(diwaniyaId, 'معرّف الديوانية')));
  }

  /// POST /diwaniyas/{id}/regenerate-invite
  /// Returns {diwaniya_id, invitation_code}. Old code becomes
  /// invalid immediately. Manager-only.
  static Future<Map<String, dynamic>> regenerateInvite(
    String diwaniyaId,
  ) async {
    final response = await ApiClient.post(
      Endpoints.diwaniyaRegenerateInvite(_normalizedRequiredId(diwaniyaId, 'معرّف الديوانية')),
    );
    return _expectMap(response, 'regenerateInvite');
  }

  static Map<String, dynamic> _expectMap(dynamic response, String op) {
    if (response is! Map) {
      throw ApiException(
        code: ApiErrorCode.parse,
        message: 'Malformed $op response',
      );
    }
    return Map<String, dynamic>.from(response);
  }
}
