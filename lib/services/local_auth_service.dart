// lib/services/local_auth_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../services/logger_service.dart';
import '../config/database_config.dart';

class LocalAuthService {
  static const String _userIdKey = 'user_id';
  static const String _userEmailKey = 'user_email';
  static const String _userNameKey = 'user_name';

  /// Register a new user with the local API server
  static Future<Map<String, dynamic>> register({
    required String name,
    required String email,
    required String password,
  }) async {
    try {
      final endpoint = '${DatabaseConfig.physicalServerUrl}/auth/register';
      Log.i('Attempting register at: ' + endpoint, 'AUTH');
      
      // Add timeout and better error handling
      final response = await http.post(
        Uri.parse(endpoint),
        headers: {
          'Content-Type': 'application/json',
          'ngrok-skip-browser-warning': 'true',
        },
        body: json.encode({
          'name': name,
          'email': email,
          'password': password,
        }),
      ).timeout(const Duration(seconds: 30));

      LoggerService.logApiCall(endpoint, 'POST', response.statusCode, response.body);
      final data = json.decode(response.body);

      if (response.statusCode == 201) {
        // Store authentication data
        await _storeAuthData(data['token'], data['user']);
        return {'success': true, 'user': data['user'], 'token': data['token']};
      } else {
        return {'success': false, 'error': data['message'] ?? 'Registration failed'};
      }
    } catch (e) {
      Log.e('Register network error', 'AUTH', e);
      return {'success': false, 'error': 'Network error: $e'};
    }
  }

  /// Login with the local API server
  static Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  }) async {
    try {
      final endpoint = '${DatabaseConfig.physicalServerUrl}/auth/login';
      Log.i('Attempting login at: ' + endpoint, 'AUTH');
      
      // Add timeout and better error handling
      final response = await http.post(
        Uri.parse(endpoint),
        headers: {
          'Content-Type': 'application/json',
          'ngrok-skip-browser-warning': 'true',
        },
        body: json.encode({
          'email': email,
          'password': password,
        }),
      ).timeout(const Duration(seconds: 30));

      LoggerService.logApiCall(endpoint, 'POST', response.statusCode, response.body);
      final data = json.decode(response.body);

      if (response.statusCode == 200) {
        // Store authentication data
        print('LocalAuthService: Login successful, storing auth data');
        await _storeAuthData(data['token'], data['user']);
        print('LocalAuthService: Auth data stored successfully');
        return {'success': true, 'user': data['user'], 'token': data['token']};
      } else {
        print('LocalAuthService: Login failed with status: ${response.statusCode}');
        return {'success': false, 'error': data['message'] ?? 'Login failed'};
      }
    } catch (e) {
      Log.e('Login network error', 'AUTH', e);
      return {'success': false, 'error': 'Network error: $e'};
    }
  }

  /// Logout and clear stored data
  static Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await DatabaseConfig.clearAuthToken();
    await prefs.remove(_userIdKey);
    await prefs.remove(_userEmailKey);
    await prefs.remove(_userNameKey);
  }

  /// Check if user is logged in
  static Future<bool> isLoggedIn() async {
    try {
      final token = await DatabaseConfig.getStoredAuthToken();
      print('LocalAuthService: isLoggedIn check - token length: ${token.length}');
      return token.isNotEmpty;
    } catch (e) {
      print('LocalAuthService: isLoggedIn error: $e');
      return false;
    }
  }

  /// Get current user data
  static Future<Map<String, dynamic>?> getCurrentUser() async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getString(_userIdKey);
    final email = prefs.getString(_userEmailKey);
    final name = prefs.getString(_userNameKey);

    if (userId != null && email != null && name != null) {
      return {
        'id': userId,
        'email': email,
        'name': name,
      };
    }
    return null;
  }

  /// Get current user ID
  static Future<String?> getCurrentUserId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_userIdKey);
  }

  /// Store authentication data locally
  static Future<void> _storeAuthData(String token, Map<String, dynamic> user) async {
    print('LocalAuthService: _storeAuthData - storing token length: ${token.length}');
    final prefs = await SharedPreferences.getInstance();
    await DatabaseConfig.setAuthToken(token);
    await prefs.setString(_userIdKey, user['id'] ?? user['_id'] ?? '');
    await prefs.setString(_userEmailKey, user['email'] ?? '');
    await prefs.setString(_userNameKey, user['name'] ?? user['displayName'] ?? '');
    print('LocalAuthService: _storeAuthData - data stored successfully');
  }

  /// Verify token with server
  static Future<bool> verifyToken() async {
    try {
      final token = await DatabaseConfig.getStoredAuthToken();
      print('LocalAuthService: verifyToken - token length: ${token.length}');
      
      if (token.isEmpty) {
        print('LocalAuthService: verifyToken - no token found');
        return false;
      }

      final endpoint = '${DatabaseConfig.physicalServerUrl}/auth/verify';
      print('LocalAuthService: verifyToken - endpoint: $endpoint');
      Log.i('Attempting token verify at: ' + endpoint, 'AUTH');
      
      final response = await http.get(
        Uri.parse(endpoint),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
          'ngrok-skip-browser-warning': 'true',
        },
      ).timeout(const Duration(seconds: 30));
      
      print('LocalAuthService: verifyToken - response status: ${response.statusCode}');
      LoggerService.logApiCall(endpoint, 'GET', response.statusCode, response.body);
      return response.statusCode == 200;
    } catch (e) {
      print('LocalAuthService: verifyToken - error: $e');
      Log.e('Verify token network error', 'AUTH', e);
      return false;
    }
  }
}