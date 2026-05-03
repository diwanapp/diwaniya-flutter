/// Runtime configuration for the API layer.
///
/// [baseUrl] points at the active backend environment. For local dev this
/// typically points at a FastAPI dev server. Override at build time via
/// `--dart-define`:
///
///   flutter run --dart-define=API_BASE_URL=https://staging.example.com
///
/// Keep this file free of hard-coded secrets.
abstract final class ApiConfig {
  ApiConfig._();

  /// Base URL for all API calls. Must not contain a trailing slash.
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://localhost:8000',
  );

  /// Default timeout applied to every request.
  static const Duration requestTimeout = Duration(seconds: 20);

  /// Default connection timeout.
  static const Duration connectTimeout = Duration(seconds: 10);

  /// Development-only auth fallback. When true AND the app is running
  /// in debug mode, the auth/OTP flow degrades gracefully to a local
  /// mock path if the backend is unreachable. Production and release
  /// builds always behave as if this were false.
  ///
  /// Enable with:
  ///   flutter run --dart-define=DIWANIYA_DEV_AUTH_FALLBACK=true
  ///
  /// The dev OTP code is hardcoded to "000000" (six zeros). Any other
  /// code will fail verification in the fallback path.
  static const bool devAuthFallback = bool.fromEnvironment(
    'DIWANIYA_DEV_AUTH_FALLBACK',
    defaultValue: false,
  );
}
