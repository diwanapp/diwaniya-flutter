import 'api_client.dart';
import 'api_exception.dart';
import 'endpoints.dart';

/// Diwaniya + invites + members endpoints per `API_CONTRACT_V1`.
///
/// Scope:
///   - POST   /diwaniyas
///   - GET    /diwaniyas/{id}
///   - PATCH  /diwaniyas/{id}
///   - POST   /diwaniyas/{id}/invites
///   - POST   /invites/{code}/accept
///   - GET    /diwaniyas/{id}/members
///
/// Thin wrapper over [ApiClient]. Returns raw decoded JSON — Step 4+ will
/// adapt these into the existing domain models.
class DiwaniyaApi {
  DiwaniyaApi._();

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

  static String _normalizedRequiredCode(String value) {
    final normalized = value.trim().toUpperCase();
    if (normalized.isEmpty) {
      throw const ApiException(
        code: ApiErrorCode.validation,
        message: 'رمز الدعوة غير صالح',
      );
    }
    return normalized;
  }

  static String? _normalizedOptional(String? value) {
    final normalized = value?.trim();
    if (normalized == null || normalized.isEmpty) return null;
    return normalized;
  }

  // ── Create ──

  /// Create a new diwaniya. Returns the created diwaniya map.
  static Future<Map<String, dynamic>> create({
    required String name,
    String? description,
    String? city,
    String? invitationCode,
    String? imageMediaId,
  }) async {
    final normalizedName = name.trim();
    if (normalizedName.isEmpty) {
      throw const ApiException(
        code: ApiErrorCode.validation,
        message: 'اسم الديوانية مطلوب',
      );
    }

    final body = <String, dynamic>{
      'name': normalizedName,
      if (_normalizedOptional(description) != null)
        'description': _normalizedOptional(description),
      if (_normalizedOptional(city) != null) 'city': _normalizedOptional(city),
      if (_normalizedOptional(invitationCode) != null)
        'invitation_code': _normalizedRequiredCode(invitationCode!),
      if (_normalizedOptional(imageMediaId) != null)
        'image_media_id': _normalizedOptional(imageMediaId),
    };
    final response = await ApiClient.post(Endpoints.diwaniyas, body: body);
    return _expectMap(response, 'DiwaniyaApi.create');
  }

  // ── Read ──

  /// Fetch a single diwaniya by id.
  static Future<Map<String, dynamic>> getById(String diwaniyaId) async {
    final response = await ApiClient.get(Endpoints.diwaniya(
        _normalizedRequiredId(diwaniyaId, 'معرّف الديوانية')));
    return _expectMap(response, 'DiwaniyaApi.getById');
  }

  // ── Update ──

  /// Patch editable diwaniya fields. Fields are optional for partial update.
  static Future<Map<String, dynamic>> update(
    String diwaniyaId, {
    String? name,
    String? description,
    String? imageMediaId,
  }) async {
    final normalizedId = _normalizedRequiredId(diwaniyaId, 'معرّف الديوانية');
    final body = <String, dynamic>{
      if (_normalizedOptional(name) != null) 'name': _normalizedOptional(name),
      if (_normalizedOptional(description) != null)
        'description': _normalizedOptional(description),
      if (_normalizedOptional(imageMediaId) != null)
        'image_media_id': _normalizedOptional(imageMediaId),
    };
    if (body.isEmpty) {
      throw const ApiException(
        code: ApiErrorCode.validation,
        message: 'لا توجد بيانات للتحديث',
      );
    }
    final response = await ApiClient.patch(
      Endpoints.diwaniya(normalizedId),
      body: body,
    );
    return _expectMap(response, 'DiwaniyaApi.update');
  }

  // ── Invites ──

  /// Generate a new invite code/link for an existing diwaniya.
  /// Authorization is enforced server-side.
  /// Returns a map with `invite_code`, optional `invite_url`, `expires_at`.
  static Future<Map<String, dynamic>> generateInvite(String diwaniyaId) async {
    final response = await ApiClient.post(
      Endpoints.diwaniyaInvites(
          _normalizedRequiredId(diwaniyaId, 'معرّف الديوانية')),
    );
    return _expectMap(response, 'DiwaniyaApi.generateInvite');
  }

  /// Accept an invite code and become a member of the target diwaniya.
  /// Returns a map with `diwaniya_id` and `membership_id`.
  static Future<Map<String, dynamic>> acceptInvite(String code) async {
    final response = await ApiClient.post(
        Endpoints.inviteAccept(_normalizedRequiredCode(code)));
    return _expectMap(response, 'DiwaniyaApi.acceptInvite');
  }

  // ── Members ──

  /// Fetch the members list for a diwaniya.
  /// Returns a list of membership maps. Each contains `id`,
  /// `user_id`, `display_name`, `role_types`, `status`.
  static Future<List<Map<String, dynamic>>> getMembers(
    String diwaniyaId,
  ) async {
    final response = await ApiClient.get(
      Endpoints.diwaniyaMembers(
          _normalizedRequiredId(diwaniyaId, 'معرّف الديوانية')),
    );
    final map = _expectMap(response, 'DiwaniyaApi.getMembers');
    final items = map['members'];
    if (items is! List) {
      return const <Map<String, dynamic>>[];
    }
    return items
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList(growable: false);
  }

  // ── Helpers ──

  static Map<String, dynamic> _expectMap(dynamic response, String endpoint) {
    if (response is Map<String, dynamic>) return response;
    throw ApiException(
      code: ApiErrorCode.parse,
      message: 'Unexpected response shape for $endpoint',
    );
  }
}
