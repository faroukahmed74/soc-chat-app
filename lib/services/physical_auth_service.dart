// =============================================================================
// PHYSICAL AUTH SERVICE
// =============================================================================
// This service handles authentication with the physical server (MongoDB)
// It replaces Firebase Auth with JWT token-based authentication

import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../config/database_config.dart';
import 'logger_service.dart';

class PhysicalAuthService {
  static final PhysicalAuthService _instance = PhysicalAuthService._internal();
  factory PhysicalAuthService() => _instance;
  PhysicalAuthService._internal();

  // Token storage key
  static const String _tokenKey = 'auth_token';
  static const String _userKey = 'user_data';

  /// Login with email and password
  Future<Map<String, dynamic>> login(String email, String password) async {
    try {
      final baseUrl = DatabaseConfig.physicalServerUrl;
      final response = await http.post(
        Uri.parse('$baseUrl/api/auth/login'),
        headers: {
          'Content-Type': 'application/json',
          'ngrok-skip-browser-warning': 'true',
        },
        body: json.encode({
          'email': email,
          'password': password,
        }),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final token = data['token'];
        final user = data['user'];

        // Store token and user data
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_tokenKey, token);
        await prefs.setString(_userKey, json.encode(user));

        Log.i('Login successful', 'PHYSICAL_AUTH');
        return {
          'success': true,
          'token': token,
          'user': user,
        };
      } else {
        final error = json.decode(response.body);
        Log.e('Login failed', 'PHYSICAL_AUTH', error['message']);
        return {
          'success': false,
          'error': error['message'] ?? 'Login failed',
        };
      }
    } catch (e) {
      Log.e('Login error', 'PHYSICAL_AUTH', e);
      return {
        'success': false,
        'error': 'Network error: $e',
      };
    }
  }

  /// Register new user
  Future<Map<String, dynamic>> register(String email, String password, String name) async {
    try {
      final baseUrl = DatabaseConfig.physicalServerUrl;
      Log.i('Registering user at: $baseUrl/api/auth/register', 'PHYSICAL_AUTH');
      Log.i('Full registration URL: $baseUrl/api/auth/register', 'PHYSICAL_AUTH');
      
      final response = await http.post(
        Uri.parse('$baseUrl/api/auth/register'),
        headers: {
          'Content-Type': 'application/json',
          'ngrok-skip-browser-warning': 'true',
        },
        body: json.encode({
          'email': email,
          'password': password,
          'name': name,
        }),
      );

      Log.i('Registration response status: ${response.statusCode}', 'PHYSICAL_AUTH');
      Log.i('Registration response body: ${response.body}', 'PHYSICAL_AUTH');

      if (response.statusCode == 201) {
        final data = json.decode(response.body);
        final token = data['token'];
        final user = data['user'];

        // Store token and user data
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_tokenKey, token);
        await prefs.setString(_userKey, json.encode(user));

        Log.i('Registration successful', 'PHYSICAL_AUTH');
        return {
          'success': true,
          'token': token,
          'user': user,
        };
      } else {
        // Try to parse error response, but handle cases where it's not JSON
        try {
          final error = json.decode(response.body);
          Log.e('Registration failed', 'PHYSICAL_AUTH', error['message']);
          return {
            'success': false,
            'error': error['message'] ?? 'Registration failed',
          };
        } catch (parseError) {
          Log.e('Registration failed - non-JSON response', 'PHYSICAL_AUTH', response.body);
          return {
            'success': false,
            'error': 'Server error: ${response.statusCode} - ${response.body}',
          };
        }
      }
    } catch (e) {
      Log.e('Registration error', 'PHYSICAL_AUTH', e);
      return {
        'success': false,
        'error': 'Network error: $e',
      };
    }
  }

  /// Get current user data
  Future<Map<String, dynamic>?> getCurrentUser() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userData = prefs.getString(_userKey);
      if (userData != null) {
        return json.decode(userData);
      }
      return null;
    } catch (e) {
      Log.e('Error getting current user', 'PHYSICAL_AUTH', e);
      return null;
    }
  }

  /// Get current auth token
  Future<String?> getAuthToken() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_tokenKey);
    } catch (e) {
      Log.e('Error getting auth token', 'PHYSICAL_AUTH', e);
      return null;
    }
  }

  /// Check if user is logged in
  Future<bool> isLoggedIn() async {
    final token = await getAuthToken();
    return token != null && token.isNotEmpty;
  }

  /// Logout user
  Future<void> logout() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_tokenKey);
      await prefs.remove(_userKey);
      Log.i('Logout successful', 'PHYSICAL_AUTH');
    } catch (e) {
      Log.e('Error during logout', 'PHYSICAL_AUTH', e);
    }
  }

  /// Get user ID from stored data
  Future<String?> getCurrentUserId() async {
    final user = await getCurrentUser();
    return user?['id'];
  }

  /// Get user email from stored data
  Future<String?> getCurrentUserEmail() async {
    final user = await getCurrentUser();
    return user?['email'];
  }

  /// Get user role from stored data
  Future<String?> getCurrentUserRole() async {
    final user = await getCurrentUser();
    return user?['role'];
  }
}
