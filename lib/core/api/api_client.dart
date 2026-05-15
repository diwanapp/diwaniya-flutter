import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

import 'api_config.dart';
import 'api_exception.dart';
import 'token_storage.dart';

/// Minimal HTTP client for the Diwaniya backend.
///
/// Responsibilities:
/// - compose URLs from [ApiConfig.baseUrl] + path
/// - inject `Authorization: Bearer <token>` when a token exists
/// - encode JSON request bodies
/// - decode JSON response bodies
/// - map all failures into [ApiException]
///
/// Non-responsibilities (explicitly):
/// - no retry logic
/// - no automatic token refresh
/// - no response caching
/// - no domain model mapping
///
/// Uses `dart:io HttpClient` to avoid adding a new dependency.
class ApiClient {
  ApiClient._();

  static final HttpClient _httpClient = HttpClient()
    ..connectionTimeout = ApiConfig.connectTimeout;

  static int _requestSequence = 0;

  /// Network logs are disabled by default, even in debug, because request and
  /// response bodies may contain tokens, phone numbers, messages, filenames,
  /// or other user content. Enable intentionally during local troubleshooting:
  ///
  ///   --dart-define=ENABLE_NETWORK_LOGS=true
  ///
  /// Body previews remain disabled unless explicitly enabled with:
  ///
  ///   --dart-define=ENABLE_NETWORK_BODY_LOGS=true
  static const bool _networkLogsEnabled = bool.fromEnvironment(
    'ENABLE_NETWORK_LOGS',
    defaultValue: false,
  );

  static const bool _networkBodyLogsEnabled = bool.fromEnvironment(
    'ENABLE_NETWORK_BODY_LOGS',
    defaultValue: false,
  );

  static bool get _debugEnabled => kDebugMode && _networkLogsEnabled;

  static const Set<String> _sensitiveBodyKeys = <String>{
    'access_token',
    'refresh_token',
    'token',
    'authorization',
    'otp',
    'otp_code',
    'code',
    'password',
    'mobile_number',
    'phone',
  };

  static void _log(String message) {
    if (!_debugEnabled) return;
    debugPrint('[ApiClient] $message');
  }

  static Object? _redactForLog(Object? value) {
    if (value is Map) {
      return value.map((key, item) {
        final normalized = key.toString().trim().toLowerCase();
        if (_sensitiveBodyKeys.contains(normalized)) {
          return MapEntry(key, '<redacted>');
        }
        return MapEntry(key, _redactForLog(item));
      });
    }
    if (value is List) {
      return value.map(_redactForLog).toList(growable: false);
    }
    return value;
  }

  static String _previewBody(Object? value) {
    if (value == null) return '<empty>';
    if (!_networkBodyLogsEnabled) return '<body omitted>';
    try {
      final raw = jsonEncode(_redactForLog(value));
      return raw.length <= 600 ? raw : '${raw.substring(0, 600)}…';
    } catch (_) {
      return '<unavailable>';
    }
  }

  static String _previewText(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return '<empty>';
    if (!_networkBodyLogsEnabled) return '<body omitted>';
    return trimmed.length <= 600 ? trimmed : '${trimmed.substring(0, 600)}…';
  }

  static String _authStateForLog(bool authenticated) {
    if (!authenticated) return 'n/a';
    return TokenStorage.accessToken?.isNotEmpty == true ? 'present' : 'missing';
  }

  // ── Public API ──

  static Future<dynamic> get(
    String path, {
    Map<String, String>? query,
    bool authenticated = true,
  }) {
    return _send(
      method: 'GET',
      path: path,
      query: query,
      authenticated: authenticated,
    );
  }

  static Future<dynamic> post(
    String path, {
    Object? body,
    bool authenticated = true,
  }) {
    return _send(
      method: 'POST',
      path: path,
      body: body,
      authenticated: authenticated,
    );
  }

  static Future<dynamic> patch(
    String path, {
    Object? body,
    bool authenticated = true,
  }) {
    return _send(
      method: 'PATCH',
      path: path,
      body: body,
      authenticated: authenticated,
    );
  }

  static Future<dynamic> delete(
    String path, {
    bool authenticated = true,
  }) {
    return _send(
      method: 'DELETE',
      path: path,
      authenticated: authenticated,
    );
  }

  static Future<File> downloadToFile(
    String path, {
    required File targetFile,
    bool authenticated = true,
  }) async {
    final parsed = Uri.tryParse(path);
    final uri =
        parsed != null && parsed.hasScheme ? parsed : _buildUri(path, null);
    final requestId = ++_requestSequence;
    _log(
        '#$requestId → DOWNLOAD $uri auth=$authenticated token=${_authStateForLog(authenticated)}');

    HttpClientRequest request;
    try {
      request = await _httpClient
          .openUrl('GET', uri)
          .timeout(ApiConfig.connectTimeout);
    } on TimeoutException {
      _log('#$requestId download-connect-timeout');
      throw const ApiException(
        code: ApiErrorCode.timeout,
        message: 'تعذّر الاتصال بالخادم',
      );
    } on SocketException catch (e) {
      _log('#$requestId download-socket-open-error=${e.message}');
      throw ApiException(
        code: ApiErrorCode.network,
        message: 'لا يوجد اتصال بالشبكة',
        details: {'os_error': e.message},
      );
    } on HttpException catch (e) {
      _log('#$requestId download-http-open-error=${e.message}');
      throw ApiException(
        code: ApiErrorCode.network,
        message: 'تعذّر فتح الاتصال بالخادم',
        details: {'http_error': e.message},
      );
    }

    request.headers.set(HttpHeaders.acceptHeader, '*/*');
    if (authenticated) {
      final token = TokenStorage.accessToken?.trim();
      if (token == null || token.isEmpty) {
        _log('#$requestId unauthorized-before-download=no-token');
        throw const ApiException(
          code: ApiErrorCode.unauthorized,
          message: 'انتهت الجلسة. سجل الدخول من جديد.',
        );
      }
      request.headers.set(HttpHeaders.authorizationHeader, 'Bearer $token');
    }

    HttpClientResponse response;
    try {
      response = await request.close().timeout(ApiConfig.requestTimeout);
    } on TimeoutException {
      _log('#$requestId download-response-timeout');
      throw const ApiException(
        code: ApiErrorCode.timeout,
        message: 'انتهت مهلة تحميل الملف',
      );
    } on SocketException catch (e) {
      _log('#$requestId download-socket-close-error=${e.message}');
      throw ApiException(
        code: ApiErrorCode.network,
        message: 'انقطع الاتصال أثناء تحميل الملف',
        details: {'os_error': e.message},
      );
    } on HttpException catch (e) {
      _log('#$requestId download-http-close-error=${e.message}');
      throw ApiException(
        code: ApiErrorCode.network,
        message: 'تعذر استلام الملف من الخادم',
        details: {'http_error': e.message},
      );
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      final responseBody = await _readBody(response);
      _log(
          '#$requestId ← download-status=${response.statusCode} body=${_previewText(responseBody)}');
      _handleResponse(response.statusCode, responseBody);
      throw ApiException(
        code: ApiErrorCode.unknown,
        message: 'تعذر تحميل الملف',
        statusCode: response.statusCode,
      );
    }

    final parent = targetFile.parent;
    if (!await parent.exists()) {
      await parent.create(recursive: true);
    }

    var bytes = 0;
    final sink = targetFile.openWrite(mode: FileMode.write);
    try {
      await for (final chunk in response) {
        bytes += chunk.length;
        sink.add(chunk);
      }
    } finally {
      await sink.close();
    }

    _log('#$requestId ← download-status=${response.statusCode} bytes=$bytes');
    return targetFile;
  }

  static String _mimeTypeForFile(String filename) {
    final lower = filename.toLowerCase();
    if (lower.endsWith('.jpg') || lower.endsWith('.jpeg')) return 'image/jpeg';
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.gif')) return 'image/gif';
    if (lower.endsWith('.webp')) return 'image/webp';
    if (lower.endsWith('.heic')) return 'image/heic';
    if (lower.endsWith('.aac')) return 'audio/aac';
    if (lower.endsWith('.m4a')) return 'audio/mp4';
    if (lower.endsWith('.mp3')) return 'audio/mpeg';
    if (lower.endsWith('.wav')) return 'audio/wav';
    if (lower.endsWith('.ogg')) return 'audio/ogg';
    if (lower.endsWith('.pdf')) {
      return 'application/pdf';
    }
    if (lower.endsWith('.doc')) {
      return 'application/msword';
    }
    if (lower.endsWith('.docx')) {
      return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
    }
    if (lower.endsWith('.xls')) {
      return 'application/vnd.ms-excel';
    }
    if (lower.endsWith('.xlsx')) {
      return 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';
    }
    if (lower.endsWith('.ppt')) {
      return 'application/vnd.ms-powerpoint';
    }
    if (lower.endsWith('.pptx')) {
      return 'application/vnd.openxmlformats-officedocument.presentationml.presentation';
    }
    if (lower.endsWith('.txt')) return 'text/plain';
    if (lower.endsWith('.csv')) return 'text/csv';
    if (lower.endsWith('.zip')) return 'application/zip';
    return 'application/octet-stream';
  }

  static Future<dynamic> postMultipart(
    String path, {
    required File file,
    Map<String, String>? fields,
    bool authenticated = true,
  }) async {
    final uri = _buildUri(path, null);
    final requestId = ++_requestSequence;
    _log(
        '#$requestId → POST-MULTIPART $uri auth=$authenticated token=${_authStateForLog(authenticated)}');
    if (fields != null && fields.isNotEmpty) {
      _log('#$requestId fields=${fields.keys.join(',')}');
    }
    _log(
        '#$requestId file=${file.uri.pathSegments.isNotEmpty ? file.uri.pathSegments.last : '<unknown>'}');

    HttpClientRequest request;
    try {
      request = await _httpClient
          .openUrl('POST', uri)
          .timeout(ApiConfig.connectTimeout);
    } on TimeoutException {
      _log('#$requestId connect-timeout');
      throw const ApiException(
          code: ApiErrorCode.timeout, message: 'تعذّر الاتصال بالخادم');
    } on SocketException catch (e) {
      _log('#$requestId socket-open-error=${e.message}');
      throw ApiException(
          code: ApiErrorCode.network,
          message: 'لا يوجد اتصال بالشبكة',
          details: {'os_error': e.message});
    }
    request.headers.set(HttpHeaders.acceptHeader, 'application/json');
    if (authenticated) {
      final token = TokenStorage.accessToken?.trim();
      if (token == null || token.isEmpty) {
        throw const ApiException(
            code: ApiErrorCode.unauthorized,
            message: 'انتهت الجلسة. سجل الدخول من جديد.');
      }
      request.headers.set(HttpHeaders.authorizationHeader, 'Bearer $token');
    }
    final boundary = '----diwaniya-${DateTime.now().microsecondsSinceEpoch}';
    request.headers.set(HttpHeaders.contentTypeHeader,
        'multipart/form-data; boundary=$boundary');
    void writeField(String name, String value) {
      request.write('--$boundary\r\n');
      request.write('Content-Disposition: form-data; name="$name"\r\n\r\n');
      request.write(value);
      request.write('\r\n');
    }

    fields?.forEach((k, v) {
      if (v.trim().isNotEmpty) writeField(k, v);
    });
    final filename = file.uri.pathSegments.isNotEmpty
        ? file.uri.pathSegments.last
        : 'upload.jpg';
    final mime = _mimeTypeForFile(filename);
    request.write('--$boundary\r\n');
    request.write(
        'Content-Disposition: form-data; name="file"; filename="$filename"\r\n');
    request.write('Content-Type: $mime\r\n\r\n');
    await request.addStream(file.openRead());
    request.write('\r\n--$boundary--\r\n');

    HttpClientResponse response;
    try {
      response = await request.close().timeout(ApiConfig.requestTimeout);
    } on TimeoutException {
      _log('#$requestId response-timeout');
      throw const ApiException(
          code: ApiErrorCode.timeout, message: 'انتهت مهلة الاستجابة');
    } on SocketException catch (e) {
      _log('#$requestId socket-close-error=${e.message}');
      throw ApiException(
          code: ApiErrorCode.network,
          message: 'انقطع الاتصال بالشبكة',
          details: {'os_error': e.message});
    }
    final responseBody = await _readBody(response);
    _log(
        '#$requestId ← status=${response.statusCode} body=${_previewText(responseBody)}');
    return _handleResponse(response.statusCode, responseBody);
  }

  // ── Core request pipeline ──

  static Future<dynamic> _send({
    required String method,
    required String path,
    Map<String, String>? query,
    Object? body,
    required bool authenticated,
  }) async {
    final uri = _buildUri(path, query);
    final requestId = ++_requestSequence;

    _log(
        '#$requestId → $method $uri auth=$authenticated token=${_authStateForLog(authenticated)}');
    if (query != null && query.isNotEmpty) {
      _log('#$requestId query=${query.toString()}');
    }
    if (body != null) {
      _log('#$requestId body=${_previewBody(body)}');
    }

    HttpClientRequest request;
    try {
      request = await _httpClient
          .openUrl(method, uri)
          .timeout(ApiConfig.connectTimeout);
    } on TimeoutException {
      _log('#$requestId connect-timeout');
      throw const ApiException(
        code: ApiErrorCode.timeout,
        message: 'تعذّر الاتصال بالخادم',
      );
    } on SocketException catch (e) {
      _log('#$requestId socket-open-error=${e.message}');
      throw ApiException(
        code: ApiErrorCode.network,
        message: 'لا يوجد اتصال بالشبكة',
        details: {'os_error': e.message},
      );
    } on HttpException catch (e) {
      _log('#$requestId http-open-error=${e.message}');
      throw ApiException(
        code: ApiErrorCode.network,
        message: 'تعذّر فتح الاتصال بالخادم',
        details: {'http_error': e.message},
      );
    } catch (e) {
      _log('#$requestId unexpected-open-error=$e');
      throw ApiException(
        code: ApiErrorCode.unknown,
        message: 'حدث خطأ غير متوقع أثناء إنشاء الطلب',
        details: {'exception': e.toString()},
      );
    }

    request.headers.set(HttpHeaders.acceptHeader, 'application/json');

    if (authenticated) {
      final token = TokenStorage.accessToken?.trim();
      if (token == null || token.isEmpty) {
        _log('#$requestId unauthorized-before-send=no-token');
        throw const ApiException(
          code: ApiErrorCode.unauthorized,
          message: 'انتهت الجلسة. سجل الدخول من جديد.',
        );
      }
      request.headers.set(HttpHeaders.authorizationHeader, 'Bearer $token');
    }

    if (body != null) {
      final encoded = jsonEncode(body);
      request.headers.set(
        HttpHeaders.contentTypeHeader,
        'application/json; charset=utf-8',
      );
      request.add(utf8.encode(encoded));
    }

    HttpClientResponse response;
    try {
      response = await request.close().timeout(ApiConfig.requestTimeout);
    } on TimeoutException {
      _log('#$requestId response-timeout');
      throw const ApiException(
        code: ApiErrorCode.timeout,
        message: 'انتهت مهلة الاستجابة',
      );
    } on SocketException catch (e) {
      _log('#$requestId socket-close-error=${e.message}');
      throw ApiException(
        code: ApiErrorCode.network,
        message: 'انقطع الاتصال بالشبكة',
        details: {'os_error': e.message},
      );
    } on HttpException catch (e) {
      _log('#$requestId http-close-error=${e.message}');
      throw ApiException(
        code: ApiErrorCode.network,
        message: 'تعذر استلام استجابة من الخادم',
        details: {'http_error': e.message},
      );
    } catch (e) {
      _log('#$requestId unexpected-close-error=$e');
      throw ApiException(
        code: ApiErrorCode.unknown,
        message: 'حدث خطأ غير متوقع أثناء إرسال الطلب',
        details: {'exception': e.toString()},
      );
    }

    final responseBody = await _readBody(response);
    _log(
        '#$requestId ← status=${response.statusCode} body=${_previewText(responseBody)}');
    return _handleResponse(response.statusCode, responseBody);
  }

  // ── Helpers ──

  static Uri _buildUri(String path, Map<String, String>? query) {
    ApiConfig.assertProductionSafe();
    final base = ApiConfig.baseUrl.endsWith('/')
        ? ApiConfig.baseUrl.substring(0, ApiConfig.baseUrl.length - 1)
        : ApiConfig.baseUrl;
    final trimmedPath = path.trim();
    final cleanPath =
        trimmedPath.startsWith('/') ? trimmedPath : '/$trimmedPath';
    final uri = Uri.parse('$base$cleanPath');
    if (query == null || query.isEmpty) return uri;

    final sanitizedQuery = <String, String>{};
    for (final entry in query.entries) {
      final key = entry.key.trim();
      final value = entry.value.trim();
      if (key.isEmpty || value.isEmpty) continue;
      sanitizedQuery[key] = value;
    }
    if (sanitizedQuery.isEmpty) return uri;
    return uri.replace(queryParameters: sanitizedQuery);
  }

  static Future<String> _readBody(HttpClientResponse response) {
    return response.transform(utf8.decoder).join();
  }

  static dynamic _handleResponse(int statusCode, String body) {
    // 204 No Content
    if (statusCode == 204 || body.isEmpty) {
      if (statusCode >= 200 && statusCode < 300) return null;
      throw ApiException(
        code: ApiErrorCode.unknown,
        message: 'Empty response',
        statusCode: statusCode,
      );
    }

    dynamic decoded;
    try {
      decoded = jsonDecode(body);
    } catch (_) {
      throw ApiException(
        code: ApiErrorCode.parse,
        message: 'استجابة غير صالحة من الخادم',
        statusCode: statusCode,
      );
    }

    if (statusCode >= 200 && statusCode < 300) {
      return decoded;
    }

    if (decoded is Map<String, dynamic>) {
      throw ApiException.fromBackend(decoded, statusCode: statusCode);
    }
    throw ApiException(
      code: ApiErrorCode.unknown,
      message: 'حدث خطأ غير متوقع',
      statusCode: statusCode,
    );
  }
}
