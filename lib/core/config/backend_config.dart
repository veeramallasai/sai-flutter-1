import 'environment_config.dart';

import 'package:flutter/foundation.dart';

class BackendConfig {
  BackendConfig._();

  static const String _overrideBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: '',
  );

  static const String productionBaseUrl =
      'https://farm-to-home-backend.up.railway.app';

  static String get baseUrl {
    if (_overrideBaseUrl.trim().isNotEmpty) {
      return _withoutTrailingSlash(_overrideBaseUrl.trim());
    }
    switch (EnvironmentConfig.current) {
      case AppEnvironment.production:
        return productionBaseUrl;
      case AppEnvironment.staging:
        return productionBaseUrl;
      case AppEnvironment.development:
        if (kIsWeb) {
          final String host = Uri.base.host.toLowerCase();
          if (host != 'localhost' && host != '127.0.0.1' && host.isNotEmpty) {
            return productionBaseUrl;
          }
        }
        if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
          return 'http://10.0.2.2:8080';
        }
        return 'http://localhost:8080';
    }
  }

  static const Duration connectTimeout = Duration(seconds: 20);
  static const Duration receiveTimeout = Duration(seconds: 30);
  static const int maximumRetries = 2;
  static const Duration retryDelay = Duration(milliseconds: 600);

  static Uri uri(String path, {Map<String, dynamic>? queryParameters}) {
    final String normalizedPath = path.startsWith('/') ? path : '/$path';
    final Map<String, String> query = <String, String>{};
    queryParameters?.forEach((String key, dynamic value) {
      if (value != null) query[key] = value.toString();
    });
    return Uri.parse('$baseUrl$normalizedPath')
        .replace(queryParameters: query.isEmpty ? null : query);
  }

  static String _withoutTrailingSlash(String value) =>
      value.endsWith('/') ? value.substring(0, value.length - 1) : value;
}
