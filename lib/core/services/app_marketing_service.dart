import 'dart:convert';
import 'dart:io';

import '../models/home_marketing_config.dart';

class AppMarketingService {
  AppMarketingService._();

  static const String _apiBase = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://10.0.2.2:8010',
  );

  static Future<HomeMarketingConfig?> fetchHomeMarketingConfig() async {
    final base = _apiBase.replaceAll(RegExp(r'/$'), '');
    final uri = Uri.parse('$base/api/app-marketing/home');
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 6);

    try {
      final request = await client.getUrl(uri);
      request.headers.set(HttpHeaders.acceptHeader, 'application/json');

      final response = await request.close();

      if (response.statusCode < 200 || response.statusCode >= 300) {
        return null;
      }

      final body = await utf8.decoder.bind(response).join();
      final decoded = jsonDecode(body);

      if (decoded is! Map<String, dynamic>) {
        return null;
      }

      return HomeMarketingConfig.fromJson(decoded);
    } catch (_) {
      return null;
    } finally {
      client.close(force: true);
    }
  }
}
