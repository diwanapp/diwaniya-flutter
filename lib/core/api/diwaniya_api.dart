import 'api_client.dart';
import 'api_exception.dart';
import 'endpoints.dart';
import '../models/geo_models.dart';

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

  static Future<Map<String, dynamic>> removeMember({
    required String diwaniyaId,
    required String userId,
  }) async {
    final d = _normalizedRequiredId(diwaniyaId, 'معرّف الديوانية');
    final u = _normalizedRequiredId(userId, 'معرّف العضو');
    final response = await ApiClient.post('/diwaniyas/$d/members/$u/remove');
    return _expectMap(response, 'DiwaniyaApi.removeMember');
  }

  static Future<Map<String, dynamic>> promoteMember({
    required String diwaniyaId,
    required String userId,
  }) async {
    final d = _normalizedRequiredId(diwaniyaId, 'معرّف الديوانية');
    final u = _normalizedRequiredId(userId, 'معرّف العضو');
    final response = await ApiClient.post('/diwaniyas/$d/members/$u/promote');
    return _expectMap(response, 'DiwaniyaApi.promoteMember');
  }

  static Future<Map<String, dynamic>> demoteMember({
    required String diwaniyaId,
    required String userId,
  }) async {
    final d = _normalizedRequiredId(diwaniyaId, 'معرّف الديوانية');
    final u = _normalizedRequiredId(userId, 'معرّف العضو');
    final response = await ApiClient.post('/diwaniyas/$d/members/$u/demote');
    return _expectMap(response, 'DiwaniyaApi.demoteMember');
  }

  static Future<Map<String, dynamic>> getFeed(String diwaniyaId) async {
    final d = _normalizedRequiredId(diwaniyaId, 'معرّف الديوانية');
    final response = await ApiClient.get('/diwaniyas/$d/feed');
    return _expectMap(response, 'DiwaniyaApi.getFeed');
  }

  static Future<List<Map<String, dynamic>>> getMyNotifications() async {
    final response = await ApiClient.get('/diwaniyas/user/notifications');
    if (response is List) {
      return response
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList(growable: false);
    }
    if (response is Map<String, dynamic>) {
      final items =
          response['notifications'] ?? response['items'] ?? response['data'];
      if (items is List) {
        return items
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList(growable: false);
      }
    }
    return const <Map<String, dynamic>>[];
  }

  // ── Helpers ──


  // Geo / Location

  static Future<List<GeoCity>> listGeoCities() async {
    final response = await ApiClient.get(Endpoints.geoCities);
    final map = _expectMap(response, 'DiwaniyaApi.listGeoCities');
    final items = map['cities'];
    if (items is! List) return const <GeoCity>[];
    return items
        .whereType<Map>()
        .map((e) => GeoCity.fromJson(Map<String, dynamic>.from(e)))
        .where((c) => c.id.trim().isNotEmpty && c.nameAr.trim().isNotEmpty)
        .toList(growable: false);
  }

  static Future<List<GeoDistrict>> listGeoDistricts(String cityId) async {
    final city = _normalizedRequiredId(cityId, 'معرّف المدينة');
    final response = await ApiClient.get(Endpoints.geoDistricts(city));
    final map = _expectMap(response, 'DiwaniyaApi.listGeoDistricts');
    final items = map['districts'];
    if (items is! List) return const <GeoDistrict>[];
    return items
        .whereType<Map>()
        .map((e) => GeoDistrict.fromJson(Map<String, dynamic>.from(e)))
        .where((d) => d.id.trim().isNotEmpty && d.nameAr.trim().isNotEmpty)
        .toList(growable: false);
  }

  static Future<DiwaniyaLocation> updateLocation(
    String diwaniyaId, {
    required String cityId,
    required String districtId,
  }) async {
    final d = _normalizedRequiredId(diwaniyaId, 'معرّف الديوانية');
    final c = _normalizedRequiredId(cityId, 'معرّف المدينة');
    final district = _normalizedRequiredId(districtId, 'معرّف الحي');

    final response = await ApiClient.patch(
      Endpoints.diwaniyaLocation(d),
      body: {
        'city_id': c,
        'district_id': district,
      },
    );
    final map = _expectMap(response, 'DiwaniyaApi.updateLocation');
    return DiwaniyaLocation.fromJson(map);
  }

  static Future<Map<String, dynamic>> searchMarketplacePlaces({
    required String diwaniyaId,
    String? category,
    String? cityId,
    String? districtId,
    double? radiusKm,
  }) async {
    final d = _normalizedRequiredId(
      diwaniyaId,
      'معرّف الديوانية',
    );
    final response = await ApiClient.get(
      Endpoints.marketplacePlaces(
        diwaniyaId: d,
        category: category,
        cityId: cityId,
        districtId: districtId,
        radiusKm: radiusKm,
      ),
    );
    return _expectMap(response, 'DiwaniyaApi.searchMarketplacePlaces');
  }

  static Future<Map<String, dynamic>> loadMarketplaceDiscovery({
    required String diwaniyaId,
    String? category,
    String? queryText,
    String? cityId,
    String? districtId,
    double? radiusKm,
    int limit = 20,
  }) async {
    final d = _normalizedRequiredId(
      diwaniyaId,
      'معرّف الديوانية',
    );
    final response = await ApiClient.get(
      Endpoints.marketplaceDiscovery(
        diwaniyaId: d,
        category: category,
        queryText: queryText,
        cityId: cityId,
        districtId: districtId,
        radiusKm: radiusKm,
        limit: limit,
      ),
    );
    return _expectMap(response, 'DiwaniyaApi.loadMarketplaceDiscovery');
  }

  static Future<Map<String, dynamic>> recordMarketplaceEvents(
    List<Map<String, dynamic>> events,
  ) async {
    final response = await ApiClient.post(
      Endpoints.marketplaceEventsBatch(),
      body: {'events': events},
    );
    return _expectMap(response, 'DiwaniyaApi.recordMarketplaceEvents');
  }

  static Future<Map<String, dynamic>> loadMarketplaceStoreDetails({
    required String diwaniyaId,
    required String storeId,
    String? category,
    String? cityId,
    String? districtId,
    double? radiusKm,
  }) async {
    final d = _normalizedRequiredId(
      diwaniyaId,
      'معرّف الديوانية',
    );
    final response = await ApiClient.get(
      Endpoints.marketplaceStoreDetails(
        storeId: storeId,
        diwaniyaId: d,
        category: category,
        cityId: cityId,
        districtId: districtId,
        radiusKm: radiusKm,
      ),
    );
    return _expectMap(response, 'DiwaniyaApi.loadMarketplaceStoreDetails');
  }


  static Future<Map<String, dynamic>> loadMarketplaceAds({
    required String diwaniyaId,
    required String placementScreen,
    int limit = 5,
  }) async {
    final response = await ApiClient.get(
      Endpoints.marketplaceAds(
        diwaniyaId: diwaniyaId,
        placementScreen: placementScreen,
        limit: limit,
      ),
    );
    return _expectMap(response, 'DiwaniyaApi.loadMarketplaceAds');
  }

  static Map<String, dynamic> _expectMap(dynamic response, String endpoint) {
    if (response is Map<String, dynamic>) return response;
    throw ApiException(
      code: ApiErrorCode.parse,
      message: 'Unexpected response shape for $endpoint',
    );
  }
}
