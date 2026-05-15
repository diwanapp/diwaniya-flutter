import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:hive/hive.dart';

/// Persistent storage for authentication tokens.
///
/// Security model:
/// - access_token / refresh_token / token_saved_at are stored in the
///   platform secure store.
/// - a small in-memory cache preserves the existing synchronous API used by
///   ApiClient and AuthService.
/// - old Hive-stored tokens are migrated once during app storage startup, then
///   removed from Hive.
///
/// Keep this layer thin — no business logic, no network, no refresh
/// orchestration. That belongs in a higher-level auth service.
class TokenStorage {
  TokenStorage._();

  static const _kAccessToken = 'access_token';
  static const _kRefreshToken = 'refresh_token';
  static const _kTokenSavedAt = 'token_saved_at';
  static const _legacyAuthBoxName = 'auth';

  static const FlutterSecureStorage _secureStorage = FlutterSecureStorage();

  static String? _accessTokenCache;
  static String? _refreshTokenCache;
  static DateTime? _savedAtCache;
  static bool _initialized = false;

  static Box get _legacyBox => Hive.box(_legacyAuthBoxName);

  /// Load tokens from secure storage and migrate any legacy Hive tokens.
  ///
  /// Must be called once during app startup after Hive boxes are opened.
  static Future<void> init() async {
    if (_initialized) return;

    final secureAccess = await _secureStorage.read(key: _kAccessToken);
    final secureRefresh = await _secureStorage.read(key: _kRefreshToken);
    final secureSavedAt = await _secureStorage.read(key: _kTokenSavedAt);

    final legacyAccess = _legacyString(_kAccessToken);
    final legacyRefresh = _legacyString(_kRefreshToken);
    final legacySavedAt = _legacyString(_kTokenSavedAt);

    final access = _nonEmpty(secureAccess) ?? _nonEmpty(legacyAccess);
    final refresh = _nonEmpty(secureRefresh) ?? _nonEmpty(legacyRefresh);
    final savedAtRaw = _nonEmpty(secureSavedAt) ?? _nonEmpty(legacySavedAt);

    _accessTokenCache = access;
    _refreshTokenCache = refresh;
    _savedAtCache = savedAtRaw == null ? null : DateTime.tryParse(savedAtRaw);

    // If secure storage was empty but legacy Hive had tokens, migrate them.
    if (_nonEmpty(secureAccess) == null && access != null) {
      await _secureStorage.write(key: _kAccessToken, value: access);
    }
    if (_nonEmpty(secureRefresh) == null && refresh != null) {
      await _secureStorage.write(key: _kRefreshToken, value: refresh);
    }
    if (_nonEmpty(secureSavedAt) == null && savedAtRaw != null) {
      await _secureStorage.write(key: _kTokenSavedAt, value: savedAtRaw);
    }

    // Remove sensitive legacy tokens from Hive after migration/load.
    await _clearLegacyHiveTokens();

    _initialized = true;
  }

  static String? _nonEmpty(String? value) {
    final trimmed = value?.trim();
    if (trimmed == null || trimmed.isEmpty) return null;
    return trimmed;
  }

  static String? _legacyString(String key) {
    if (!Hive.isBoxOpen(_legacyAuthBoxName)) return null;
    final v = _legacyBox.get(key);
    if (v is String && v.trim().isNotEmpty) return v;
    return null;
  }

  static Future<void> _clearLegacyHiveTokens() async {
    if (!Hive.isBoxOpen(_legacyAuthBoxName)) return;
    await _legacyBox.delete(_kAccessToken);
    await _legacyBox.delete(_kRefreshToken);
    await _legacyBox.delete(_kTokenSavedAt);
  }

  // ── Read ──

  /// Current access token, or `null` if not logged in.
  static String? get accessToken {
    return _nonEmpty(_accessTokenCache) ?? _legacyString(_kAccessToken);
  }

  /// Current refresh token, or `null` if not available.
  static String? get refreshToken {
    return _nonEmpty(_refreshTokenCache) ?? _legacyString(_kRefreshToken);
  }

  /// Whether an access token is currently stored.
  static bool get hasAccessToken => accessToken != null;

  /// Timestamp when the current token pair was saved, or `null`.
  static DateTime? get savedAt {
    return _savedAtCache;
  }

  // ── Write ──

  /// Persist a new access + refresh token pair.
  static Future<void> save({
    required String accessToken,
    required String refreshToken,
  }) async {
    final savedAt = DateTime.now();

    _accessTokenCache = accessToken;
    _refreshTokenCache = refreshToken;
    _savedAtCache = savedAt;

    await _secureStorage.write(key: _kAccessToken, value: accessToken);
    await _secureStorage.write(key: _kRefreshToken, value: refreshToken);
    await _secureStorage.write(
      key: _kTokenSavedAt,
      value: savedAt.toIso8601String(),
    );

    await _clearLegacyHiveTokens();
    _initialized = true;
  }

  /// Replace only the access token, leaving the refresh token intact.
  /// Used after a successful refresh call.
  static Future<void> updateAccessToken(String accessToken) async {
    final savedAt = DateTime.now();

    _accessTokenCache = accessToken;
    _savedAtCache = savedAt;

    await _secureStorage.write(key: _kAccessToken, value: accessToken);
    await _secureStorage.write(
      key: _kTokenSavedAt,
      value: savedAt.toIso8601String(),
    );

    await _clearLegacyHiveTokens();
    _initialized = true;
  }

  // ── Clear ──

  /// Remove all stored tokens. Called on sign-out.
  static Future<void> clear() async {
    _accessTokenCache = null;
    _refreshTokenCache = null;
    _savedAtCache = null;

    await _secureStorage.delete(key: _kAccessToken);
    await _secureStorage.delete(key: _kRefreshToken);
    await _secureStorage.delete(key: _kTokenSavedAt);

    await _clearLegacyHiveTokens();
    _initialized = true;
  }
}
