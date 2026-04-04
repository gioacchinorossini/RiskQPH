import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';
import '../models/user.dart';
import '../utils/connection_test.dart';
import '../widgets/connection_status_widget.dart';

class AuthProvider extends ChangeNotifier {
  User? _currentUser;
  bool _isLoading = false;
  String? _error;
  bool _isConnected = false;
  String _connectionStatus = 'Unknown';

  User? get currentUser => _currentUser;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get isAuthenticated => _currentUser != null;
  bool get isConnected => _isConnected;
  String get connectionStatus => _connectionStatus;

  void setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  void setError(String? error) {
    _error = error;
    notifyListeners();
  }

  Future<bool> login(String email, String password) async {
    setLoading(true);
    setError(null);

    try {
      final uri = Uri.parse(ApiConfig.baseUrl + '/api/login.php');
      final response = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': email,
          'password': password,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final userJson = data['user'] as Map<String, dynamic>;
        _currentUser = User.fromJson(userJson);
        await _saveUserToStorage();
        setLoading(false);
        return true;
      } else {
        String message = 'Login failed';
        try {
          final data = jsonDecode(response.body) as Map<String, dynamic>;
          if (data['message'] is String) message = data['message'];
        } catch (_) {}
        setError(message);
        setLoading(false);
        return false;
      }
    } catch (e) {
      setError('Login failed: $e');
      setLoading(false);
      return false;
    }
  }

  Future<bool> register(
    String name,
    String email,
    String password,
    String studentId,
    {
      required String yearLevel,
      required String department,
      required String course,
      required String gender,
      required String birthdate, // YYYY-MM-DD
      String role = 'student',
    }
  ) async {
    setLoading(true);
    setError(null);

    try {
      final uri = Uri.parse(ApiConfig.baseUrl + '/api/register.php');
      final response = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'name': name,
          'email': email,
          'password': password,
          'studentId': studentId,
          'yearLevel': yearLevel,
          'department': department,
          'course': course,
          'gender': gender,
          'birthdate': birthdate,
          // role is intentionally not sent; server defaults to 'student'
        }),
      );

      if (response.statusCode == 201) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final userJson = data['user'] as Map<String, dynamic>;
        _currentUser = User.fromJson(userJson);
        await _saveUserToStorage();
        setLoading(false);
        return true;
      } else {
        String message = 'Registration failed';
        try {
          final data = jsonDecode(response.body) as Map<String, dynamic>;
          if (data['message'] is String) message = data['message'];
        } catch (_) {}
        setError(message);
        setLoading(false);
        return false;
      }
    } catch (e) {
      setError('Registration failed: $e');
      setLoading(false);
      return false;
    }
  }

  // base URL centralized in ApiConfig

  Future<void> logout() async {
    _currentUser = null;
    await _clearUserFromStorage();
    notifyListeners();
  }

  Future<void> _saveUserToStorage() async {
    if (_currentUser != null) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('user', jsonEncode(_currentUser!.toJson()));
    }
  }

  Future<void> _clearUserFromStorage() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('user');
  }

  Future<void> loadUserFromStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userData = prefs.getString('user');
      if (userData != null) {
        final decoded = jsonDecode(userData) as Map<String, dynamic>;
        _currentUser = User.fromJson(decoded);
        notifyListeners();
      }
    } catch (e) {
      // Handle error
    }
  }

  Future<bool> testConnection() async {
    setLoading(true);
    _connectionStatus = 'Testing connection...';
    notifyListeners();

    try {
      final isConnected = await ConnectionTest.testConnection();
      _isConnected = isConnected;
      _connectionStatus = isConnected ? 'Connected' : 'Connection failed';
      setLoading(false);
      notifyListeners();
      return isConnected;
    } catch (e) {
      _isConnected = false;
      _connectionStatus = 'Connection error: $e';
      setLoading(false);
      notifyListeners();
      return false;
    }
  }

  Future<void> refreshConnection() async {
    await testConnection();
  }

  void clearConnectionCache() {
    _isConnected = false;
    _connectionStatus = 'Unknown';
    notifyListeners();
  }

  Future<bool> handleConnectionError(BuildContext context) async {
    if (!isConnected) {
      // Show connection error dialog
      await showDialog(
        context: context,
        builder: (context) => const ConnectionErrorDialog(),
      );
      return false;
    }
    return true;
  }
} 