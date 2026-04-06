import 'package:flutter/foundation.dart'
    show kIsWeb, defaultTargetPlatform, TargetPlatform;

class ApiConfig {
  static const String _definedBaseUrl = String.fromEnvironment('API_BASE_URL');

  static String get baseUrl {
    if (_definedBaseUrl.isNotEmpty) {
      return _definedBaseUrl;
    }

    // Different base URL for web vs mobile
    if (kIsWeb) {
      // Use your ngrok domain for web
      return 'localhost:3000';
    } else {
      // Use local IP for mobile/emulator
      return 'http://192.168.254.102:3000';
    }
  }
}

