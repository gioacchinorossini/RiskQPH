import 'package:flutter/foundation.dart'
    show kIsWeb, defaultTargetPlatform, TargetPlatform;

class ApiConfig {
  static const String _definedBaseUrl = String.fromEnvironment('API_BASE_URL');

  static String get baseUrl {
    if (_definedBaseUrl.isNotEmpty) {
      return _definedBaseUrl;
    }

    // Unified ngrok URL for mobile and web
    return 'https://pleasurably-endurant-maris.ngrok-free.dev';
  }
}
