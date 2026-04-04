import 'package:http/http.dart' as http;
import 'dart:convert';
import '../config/api_config.dart';

class ConnectionTest {
  static Future<bool> testConnection() async {
    try {
      final uri = Uri.parse('${ApiConfig.baseUrl}/api/connection_test.php');
      final response = await http.get(uri).timeout(
        const Duration(seconds: 3),
        onTimeout: () {
          throw Exception('Connection timeout');
        },
      );
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return data['status'] == 'success' && data['database_connected'] == true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  static Future<Map<String, dynamic>> getConnectionInfo() async {
    final isConnected = await testConnection();
    return {
      'isConnected': isConnected,
      'baseUrl': ApiConfig.baseUrl,
      'timestamp': DateTime.now().toIso8601String(),
    };
  }
} 