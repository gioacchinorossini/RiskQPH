import 'package:flutter/foundation.dart'
    show kIsWeb, defaultTargetPlatform, TargetPlatform;

class ApiConfig {
  static const String _definedBaseUrl = String.fromEnvironment('API_BASE_URL');

  static String get baseUrl {
    if (_definedBaseUrl.isNotEmpty) {
      return _definedBaseUrl;
    }

    if (kIsWeb) {
      // Next.js dev server for web
      return 'http://10.242.107.183:3000';
    }

    if (defaultTargetPlatform == TargetPlatform.android) {
      // Android emulator loopback to host machine
      return 'http://192.168.254.102:3000';
    }

    // iOS simulator, Windows, macOS, Linux
    return 'http://localhost:3000';
  }
}
