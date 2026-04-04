import 'package:flutter/foundation.dart' show kIsWeb, defaultTargetPlatform, TargetPlatform;

class ApiConfig {
  // Optional override via --dart-define=API_BASE_URL=http://host/path
  static const String _definedBaseUrl = String.fromEnvironment('API_BASE_URL');

  static String get baseUrl {
    if (_definedBaseUrl.isNotEmpty) {
      return _definedBaseUrl;
    }

    if (kIsWeb) {
      return 'http://192.168.254.102/qrattendancebyxiansqlstepbasefunctions/backend';
    }

    if (defaultTargetPlatform == TargetPlatform.android) {
      // Android emulator host loopback
      return 'http://20.0.0.16/qrattendancebyxiansqlstepbasefunctions/backend';
    }

    // iOS simulator, Windows, macOS, Linux
    return 'http://localhost/qrattendancebyxiansqlstep/backend';
  }
}

