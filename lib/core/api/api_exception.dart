/// Canonical error codes returned by the backend or mapped from transport
/// failures. These codes are stable — UI layers may switch on them to
/// decide between a generic snackbar, a field-level error, or a session
/// expired redirect.
abstract final class ApiErrorCode {
  ApiErrorCode._();

  static const String network = 'network';
  static const String timeout = 'timeout';
  static const String unauthorized = 'unauthorized';
  static const String forbidden = 'forbidden';
  static const String notFound = 'not_found';
  static const String conflict = 'conflict';
  static const String validation = 'validation';
  static const String server = 'server';
  static const String parse = 'parse';
  static const String unknown = 'unknown';
}

/// Unified exception for all API failures.
///
/// - [code] — one of [ApiErrorCode], stable for UI branching
/// - [message] — human-readable message, may come from backend
/// - [statusCode] — HTTP status if applicable, null for transport errors
/// - [details] — optional backend payload for validation errors
class ApiException implements Exception {
  final String code;
  final String message;
  final int? statusCode;
  final Map<String, dynamic>? details;

  const ApiException({
    required this.code,
    required this.message,
    this.statusCode,
    this.details,
  });

  /// Build an [ApiException] from a decoded backend error envelope.
  /// Backend contract (per API_CONTRACT_V1):
  /// ```json
  /// { "error": { "code": "forbidden", "message": "..." } }
  /// ```
  factory ApiException.fromBackend(
    Map<String, dynamic> body, {
    required int statusCode,
  }) {
    final error = body['error'];
    if (error is Map) {
      return ApiException(
        code: (error['code'] as String?) ?? _codeForStatus(statusCode),
        message: (error['message'] as String?) ?? 'Unknown error',
        statusCode: statusCode,
        details: error['details'] is Map
            ? Map<String, dynamic>.from(error['details'] as Map)
            : null,
      );
    }
    return ApiException(
      code: _codeForStatus(statusCode),
      message: 'Unexpected response',
      statusCode: statusCode,
    );
  }

  static String _codeForStatus(int status) {
    if (status == 401) return ApiErrorCode.unauthorized;
    if (status == 403) return ApiErrorCode.forbidden;
    if (status == 404) return ApiErrorCode.notFound;
    if (status == 409) return ApiErrorCode.conflict;
    if (status == 422) return ApiErrorCode.validation;
    if (status >= 500) return ApiErrorCode.server;
    return ApiErrorCode.unknown;
  }

  bool get isUnauthorized => code == ApiErrorCode.unauthorized;
  bool get isNetwork =>
      code == ApiErrorCode.network || code == ApiErrorCode.timeout;

  @override
  String toString() => 'ApiException($code, $statusCode): $message';
}
