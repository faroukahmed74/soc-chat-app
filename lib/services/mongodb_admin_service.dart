// =============================================================================
// MONGODB ADMIN SERVICE
// =============================================================================
// This service handles all admin-related operations with the MongoDB server
// It replaces Firebase Firestore with REST API calls for admin functions

import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../config/database_config.dart';
import 'logger_service.dart';

class MongoDBAdminService {
  static final MongoDBAdminService _instance = MongoDBAdminService._internal();
  factory MongoDBAdminService() => _instance;
  MongoDBAdminService._internal();

  // Token storage key
  static const String _tokenKey = 'auth_token';

  /// Get authentication token
  Future<String?> _getAuthToken() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_tokenKey);
    } catch (e) {
      Log.e('Error getting auth token', 'MONGODB_ADMIN_SERVICE', e);
      return null;
    }
  }

  /// Get all users (admin only)
  Future<List<Map<String, dynamic>>> getAllUsers() async {
    try {
      final token = await _getAuthToken();
      if (token == null) throw Exception('No auth token');

      final baseUrl = DatabaseConfig.physicalServerUrl;
      final response = await http.get(
        Uri.parse('$baseUrl/api/admin/users'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
          'ngrok-skip-browser-warning': 'true',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        // Admin /users returns { users: [...], pagination: {...} }
        final users = (data is Map && data['users'] is List)
            ? List<Map<String, dynamic>>.from(data['users'])
            : <Map<String, dynamic>>[];
        return users;
      } else {
        throw Exception('Failed to load users: ${response.statusCode}');
      }
    } catch (e) {
      Log.e('Error getting all users', 'MONGODB_ADMIN_SERVICE', e);
      return [];
    }
  }

  /// Get all chats (admin only)
  Future<List<Map<String, dynamic>>> getAllChats() async {
    try {
      final token = await _getAuthToken();
      if (token == null) throw Exception('No auth token');

      final baseUrl = DatabaseConfig.physicalServerUrl;
      final response = await http.get(
        Uri.parse('$baseUrl/api/admin/chats'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
          'ngrok-skip-browser-warning': 'true',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        // Admin /chats returns { chats: [...], pagination: {...} }
        final chats = (data is Map && data['chats'] is List)
            ? List<Map<String, dynamic>>.from(data['chats'])
            : <Map<String, dynamic>>[];
        return chats;
      } else {
        throw Exception('Failed to load chats: ${response.statusCode}');
      }
    } catch (e) {
      Log.e('Error getting all chats', 'MONGODB_ADMIN_SERVICE', e);
      return [];
    }
  }

  /// Get all messages (admin only)
  Future<List<Map<String, dynamic>>> getAllMessages({int limit = 100}) async {
    try {
      final token = await _getAuthToken();
      if (token == null) throw Exception('No auth token');

      final baseUrl = DatabaseConfig.physicalServerUrl;
      final response = await http.get(
        Uri.parse('$baseUrl/api/admin/messages?limit=$limit'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
          'ngrok-skip-browser-warning': 'true',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        // Admin /messages returns { messages: [...], pagination: {...} }
        final messages = (data is Map && data['messages'] is List)
            ? List<Map<String, dynamic>>.from(data['messages'])
            : <Map<String, dynamic>>[];
        return messages;
      } else {
        throw Exception('Failed to load messages: ${response.statusCode}');
      }
    } catch (e) {
      Log.e('Error getting all messages', 'MONGODB_ADMIN_SERVICE', e);
      return [];
    }
  }

  /// Delete a user (admin only)
  Future<bool> deleteUser(String userId) async {
    try {
      final token = await _getAuthToken();
      if (token == null) throw Exception('No auth token');

      final baseUrl = DatabaseConfig.physicalServerUrl;
      final response = await http.delete(
        Uri.parse('$baseUrl/api/admin/users/$userId'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
          'ngrok-skip-browser-warning': 'true',
        },
      );

      return response.statusCode == 200;
    } catch (e) {
      Log.e('Error deleting user', 'MONGODB_ADMIN_SERVICE', e);
      return false;
    }
  }

  /// Delete a chat (admin only)
  Future<bool> deleteChat(String chatId) async {
    try {
      final token = await _getAuthToken();
      if (token == null) throw Exception('No auth token');

      final baseUrl = DatabaseConfig.physicalServerUrl;
      final response = await http.delete(
        Uri.parse('$baseUrl/api/admin/chats/$chatId'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
          'ngrok-skip-browser-warning': 'true',
        },
      );

      return response.statusCode == 200;
    } catch (e) {
      Log.e('Error deleting chat', 'MONGODB_ADMIN_SERVICE', e);
      return false;
    }
  }

  /// Delete a message (admin only)
  Future<bool> deleteMessage(String messageId) async {
    try {
      final token = await _getAuthToken();
      if (token == null) throw Exception('No auth token');

      final baseUrl = DatabaseConfig.physicalServerUrl;
      final response = await http.delete(
        Uri.parse('$baseUrl/api/admin/messages/$messageId'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
          'ngrok-skip-browser-warning': 'true',
        },
      );

      return response.statusCode == 200;
    } catch (e) {
      Log.e('Error deleting message', 'MONGODB_ADMIN_SERVICE', e);
      return false;
    }
  }

  /// Update user role (admin only)
  Future<bool> updateUserRole(String userId, String role) async {
    try {
      final token = await _getAuthToken();
      if (token == null) throw Exception('No auth token');

      final baseUrl = DatabaseConfig.physicalServerUrl;
      final response = await http.patch(
        Uri.parse('$baseUrl/api/admin/users/$userId/role'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
          'ngrok-skip-browser-warning': 'true',
        },
        body: json.encode({
          'role': role,
        }),
      );

      return response.statusCode == 200;
    } catch (e) {
      Log.e('Error updating user role', 'MONGODB_ADMIN_SERVICE', e);
      return false;
    }
  }

  /// Disable/Enable user (admin only)
  Future<bool> toggleUserStatus(String userId, bool disabled) async {
    try {
      final token = await _getAuthToken();
      if (token == null) throw Exception('No auth token');

      final baseUrl = DatabaseConfig.physicalServerUrl;
      final response = await http.patch(
        Uri.parse('$baseUrl/api/admin/users/$userId/status'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
          'ngrok-skip-browser-warning': 'true',
        },
        body: json.encode({
          'disabled': disabled,
        }),
      );

      return response.statusCode == 200;
    } catch (e) {
      Log.e('Error toggling user status', 'MONGODB_ADMIN_SERVICE', e);
      return false;
    }
  }

  /// Send broadcast message (admin only)
  Future<bool> sendBroadcastMessage(String message) async {
    try {
      final token = await _getAuthToken();
      if (token == null) throw Exception('No auth token');

      final baseUrl = DatabaseConfig.physicalServerUrl;
      final response = await http.post(
        Uri.parse('$baseUrl/api/admin/broadcast'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
          'ngrok-skip-browser-warning': 'true',
        },
        body: json.encode({
          'message': message,
        }),
      );

      return response.statusCode == 200;
    } catch (e) {
      Log.e('Error sending broadcast message', 'MONGODB_ADMIN_SERVICE', e);
      return false;
    }
  }

  /// Get system statistics (admin only)
  Future<Map<String, dynamic>?> getSystemStats() async {
    try {
      final token = await _getAuthToken();
      if (token == null) throw Exception('No auth token');

      final baseUrl = DatabaseConfig.physicalServerUrl;
      final response = await http.get(
        Uri.parse('$baseUrl/api/admin/stats'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
          'ngrok-skip-browser-warning': 'true',
        },
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        throw Exception('Failed to load system stats: ${response.statusCode}');
      }
    } catch (e) {
      Log.e('Error getting system stats', 'MONGODB_ADMIN_SERVICE', e);
      return null;
    }
  }

  /// Get reports (admin only)
  Future<List<Map<String, dynamic>>> getReports() async {
    try {
      final token = await _getAuthToken();
      if (token == null) throw Exception('No auth token');

      final baseUrl = DatabaseConfig.physicalServerUrl;
      final response = await http.get(
        Uri.parse('$baseUrl/api/admin/reports'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
          'ngrok-skip-browser-warning': 'true',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return List<Map<String, dynamic>>.from(data);
      } else {
        throw Exception('Failed to load reports: ${response.statusCode}');
      }
    } catch (e) {
      Log.e('Error getting reports', 'MONGODB_ADMIN_SERVICE', e);
      return [];
    }
  }

  /// Resolve report (admin only)
  Future<bool> resolveReport(String reportId, String action) async {
    try {
      final token = await _getAuthToken();
      if (token == null) throw Exception('No auth token');

      final baseUrl = DatabaseConfig.physicalServerUrl;
      final response = await http.patch(
        Uri.parse('$baseUrl/api/admin/reports/$reportId'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
          'ngrok-skip-browser-warning': 'true',
        },
        body: json.encode({
          'action': action,
          'resolved': true,
        }),
      );

      return response.statusCode == 200;
    } catch (e) {
      Log.e('Error resolving report', 'MONGODB_ADMIN_SERVICE', e);
      return false;
    }
  }

  /// Export data (admin only)
  Future<Map<String, dynamic>?> exportData(String dataType) async {
    try {
      final token = await _getAuthToken();
      if (token == null) throw Exception('No auth token');

      final baseUrl = DatabaseConfig.physicalServerUrl;
      final response = await http.get(
        Uri.parse('$baseUrl/api/admin/export/$dataType'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
          'ngrok-skip-browser-warning': 'true',
        },
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        throw Exception('Failed to export data: ${response.statusCode}');
      }
    } catch (e) {
      Log.e('Error exporting data', 'MONGODB_ADMIN_SERVICE', e);
      return null;
    }
  }

  /// Clean up old data (admin only)
  Future<bool> cleanupOldData(int daysOld) async {
    try {
      final token = await _getAuthToken();
      if (token == null) throw Exception('No auth token');

      final baseUrl = DatabaseConfig.physicalServerUrl;
      final response = await http.post(
        Uri.parse('$baseUrl/api/admin/cleanup'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
          'ngrok-skip-browser-warning': 'true',
        },
        body: json.encode({
          'daysOld': daysOld,
        }),
      );

      return response.statusCode == 200;
    } catch (e) {
      Log.e('Error cleaning up old data', 'MONGODB_ADMIN_SERVICE', e);
      return false;
    }
  }
}
