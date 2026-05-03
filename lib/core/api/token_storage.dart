import 'package:hive/hive.dart';

import '../storage/hive_storage.dart';

/// Persistent storage for authentication tokens.
///
/// Uses a dedicated Hive box (`auth`) opened at startup by `initStorage()`.
/// Keep this layer thin — no business logic, no network, no refresh
/// orchestration. That belongs in a higher-level auth service.
class TokenStorage {
  TokenStorage._();

  static const _kAccessToken = 'access_token';
  static const _kRefreshToken = 'refresh_token';
  static const _kTokenSavedAt = 'token_saved_at';

  static Box get _box => Hive.box(HiveBoxes.auth);

  // ── Read ──

  /// Current access token, or `null` if not logged in.
  static String? get accessToken {
    final v = _box.get(_kAccessToken);
    if (v is String && v.isNotEmpty) return v;
    return null;
  }

  /// Current refresh token, or `null` if not available.
  static String? get refreshToken {
    final v = _box.get(_kRefreshToken);
    if (v is String && v.isNotEmpty) return v;
    return null;
  }

  /// Whether an access token is currently stored.
  static bool get hasAccessToken => accessToken != null;

  /// Timestamp when the current token pair was saved, or `null`.
  static DateTime? get savedAt {
    final raw = _box.get(_kTokenSavedAt);
    if (raw is String && raw.isNotEmpty) {
      return DateTime.tryParse(raw);
    }
    return null;
  }

  // ── Write ──

  /// Persist a new access + refresh token pair.
  static Future<void> save({
    required String accessToken,
    required String refreshToken,
  }) async {
    await _box.put(_kAccessToken, accessToken);
    await _box.put(_kRefreshToken, refreshToken);
    await _box.put(_kTokenSavedAt, DateTime.now().toIso8601String());
  }

  /// Replace only the access token, leaving the refresh token intact.
  /// Used after a successful refresh call.
  static Future<void> updateAccessToken(String accessToken) async {
    await _box.put(_kAccessToken, accessToken);
    await _box.put(_kTokenSavedAt, DateTime.now().toIso8601String());
  }

  // ── Clear ──

  /// Remove all stored tokens. Called on sign-out.
  static Future<void> clear() async {
    await _box.delete(_kAccessToken);
    await _box.delete(_kRefreshToken);
    await _box.delete(_kTokenSavedAt);
  }
}
