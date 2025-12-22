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
  Future<List<Map<String, dynamic>>> getAllUsers({String? search, int page = 1, int limit = 50}) async {
    try {
      final token = await _getAuthToken();
      if (token == null) throw Exception('No auth token');

      final baseUrl = DatabaseConfig.physicalServerUrl;
      final queryParams = {
        'page': page.toString(),
        'limit': limit.toString(),
        if (search != null && search.isNotEmpty) 'search': search,
      };
      final uri = Uri.parse('$baseUrl/api/admin/users').replace(queryParameters: queryParams);
      final response = await http.get(
        uri,
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
  Future<List<Map<String, dynamic>>> getAllMessages({String? chatId, int page = 1, int limit = 100}) async {
    try {
      final token = await _getAuthToken();
      if (token == null) throw Exception('No auth token');

      final baseUrl = DatabaseConfig.physicalServerUrl;
      final queryParams = {
        'page': page.toString(),
        'limit': limit.toString(),
        if (chatId != null && chatId.isNotEmpty) 'chatId': chatId,
      };
      final uri = Uri.parse('$baseUrl/api/admin/messages').replace(queryParameters: queryParams);
      final response = await http.get(
        uri,
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

  /// Clear all chats and messages (admin only)
  Future<Map<String, dynamic>?> clearAllChats() async {
    try {
      final token = await _getAuthToken();
      if (token == null) throw Exception('No auth token');

      final baseUrl = DatabaseConfig.physicalServerUrl;
      final response = await http.post(
        Uri.parse('$baseUrl/api/admin/chats/clear'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
          'ngrok-skip-browser-warning': 'true',
        },
      );

      if (response.statusCode == 200) {
        return json.decode(response.body) as Map<String, dynamic>;
      }
      return null;
    } catch (e) {
      Log.e('Error clearing all chats', 'MONGODB_ADMIN_SERVICE', e);
      return null;
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
      final response = await http.put(
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

  /// Update user password (admin only)
  Future<bool> updateUserPassword(String userId, String newPassword) async {
    try {
      final token = await _getAuthToken();
      if (token == null) return false;

      final baseUrl = DatabaseConfig.physicalServerUrl;
      final response = await http.put(
        Uri.parse('$baseUrl/api/admin/users/$userId/password'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
          'ngrok-skip-browser-warning': 'true',
        },
        body: json.encode({'password': newPassword}),
      );

      return response.statusCode == 200;
    } catch (e) {
      Log.e('Error updating user password', 'MONGODB_ADMIN_SERVICE', e);
      return false;
    }
  }

  /// Update user display name (admin only)
  Future<bool> updateUserDisplayName(String userId, String displayName) async {
    try {
      final token = await _getAuthToken();
      if (token == null) return false;

      final baseUrl = DatabaseConfig.physicalServerUrl;
      final response = await http.put(
        Uri.parse('$baseUrl/api/admin/users/$userId'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
          'ngrok-skip-browser-warning': 'true',
        },
        body: json.encode({'displayName': displayName}),
      );

      return response.statusCode == 200;
    } catch (e) {
      Log.e('Error updating user display name', 'MONGODB_ADMIN_SERVICE', e);
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

  /// Create a new admin user (admin only)
  Future<Map<String, dynamic>?> createAdminUser({required String email, required String password, required String displayName}) async {
    try {
      final token = await _getAuthToken();
      if (token == null) throw Exception('No auth token');

      final baseUrl = DatabaseConfig.physicalServerUrl;
      final response = await http.post(
        Uri.parse('$baseUrl/api/admin/users/admin'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
          'ngrok-skip-browser-warning': 'true',
        },
        body: json.encode({
          'email': email,
          'password': password,
          'displayName': displayName,
        }),
      );

      if (response.statusCode == 200) {
        return json.decode(response.body) as Map<String, dynamic>;
      }
      return null;
    } catch (e) {
      Log.e('Error creating admin user', 'MONGODB_ADMIN_SERVICE', e);
      return null;
    }
  }

  /// Get system health (admin only)
  Future<Map<String, dynamic>?> getSystemHealth() async {
    try {
      final token = await _getAuthToken();
      if (token == null) throw Exception('No auth token');

      final baseUrl = DatabaseConfig.physicalServerUrl;
      final response = await http.get(
        Uri.parse('$baseUrl/api/admin/health'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
          'ngrok-skip-browser-warning': 'true',
        },
      );

      if (response.statusCode == 200) {
        return json.decode(response.body) as Map<String, dynamic>;
      }
      return null;
    } catch (e) {
      Log.e('Error getting system health', 'MONGODB_ADMIN_SERVICE', e);
      return null;
    }
  }

  /// Get general API health (unprotected)
  Future<Map<String, dynamic>?> getApiHealth() async {
    try {
      final baseUrl = DatabaseConfig.physicalServerUrl;
      final response = await http.get(
        Uri.parse('$baseUrl/api/health'),
        headers: {
          'Content-Type': 'application/json',
          'ngrok-skip-browser-warning': 'true',
        },
      );

      if (response.statusCode == 200 || response.statusCode == 503) {
        return json.decode(response.body) as Map<String, dynamic>;
      }
      return null;
    } catch (e) {
      Log.e('Error getting API health', 'MONGODB_ADMIN_SERVICE', e);
      return null;
    }
  }

  /// Get MongoDB status (unprotected)
  Future<Map<String, dynamic>?> getMongoDbStatus() async {
    try {
      final baseUrl = DatabaseConfig.physicalServerUrl;
      final response = await http.get(
        Uri.parse('$baseUrl/api/status/mongodb'),
        headers: {
          'Content-Type': 'application/json',
          'ngrok-skip-browser-warning': 'true',
        },
      );

      if (response.statusCode == 200 || response.statusCode == 503) {
        return json.decode(response.body) as Map<String, dynamic>;
      }
      return null;
    } catch (e) {
      Log.e('Error getting MongoDB status', 'MONGODB_ADMIN_SERVICE', e);
      return null;
    }
  }

  /// Get ngrok-exposed API health (mobile base URL)
  Future<Map<String, dynamic>?> getNgrokHealth() async {
    try {
      final ngrokUrl = DatabaseConfig.mobileServerUrl;
      if (ngrokUrl.isEmpty) return null;

      final response = await http.get(
        Uri.parse('$ngrokUrl/api/health'),
        headers: {
          'Content-Type': 'application/json',
          'ngrok-skip-browser-warning': 'true',
        },
      );

      if (response.statusCode == 200 || response.statusCode == 503) {
        return json.decode(response.body) as Map<String, dynamic>;
      }
      return null;
    } catch (e) {
      Log.e('Error getting ngrok health', 'MONGODB_ADMIN_SERVICE', e);
      return null;
    }
  }

  /// Get system analytics
  Future<Map<String, dynamic>> getAnalytics() async {
    try {
      final token = await _getAuthToken();
      if (token == null) throw Exception('No auth token');

      final baseUrl = DatabaseConfig.physicalServerUrl;
      final uri = Uri.parse('$baseUrl/api/admin/analytics');
      final response = await http.get(
        uri,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
          'ngrok-skip-browser-warning': 'true',
        },
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        throw Exception('Failed to get analytics: ${response.statusCode}');
      }
    } catch (e) {
      Log.e('Error getting analytics', 'MONGODB_ADMIN_SERVICE', e);
      rethrow;
    }
  }

  /// Get advanced analytics with detailed metrics
  /// Supports date range filtering and period selection
  Future<Map<String, dynamic>> getAdvancedAnalytics({
    DateTime? startDate,
    DateTime? endDate,
    int period = 30,
  }) async {
    try {
      final token = await _getAuthToken();
      if (token == null) throw Exception('No auth token');

      final baseUrl = DatabaseConfig.physicalServerUrl;
      final queryParams = <String, String>{
        'period': period.toString(),
        if (startDate != null) 'startDate': startDate.toIso8601String(),
        if (endDate != null) 'endDate': endDate.toIso8601String(),
      };
      final uri = Uri.parse('$baseUrl/api/admin/analytics/advanced').replace(queryParameters: queryParams);
      final response = await http.get(
        uri,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
          'ngrok-skip-browser-warning': 'true',
        },
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        throw Exception('Failed to get advanced analytics: ${response.statusCode}');
      }
    } catch (e) {
      Log.e('Error getting advanced analytics', 'MONGODB_ADMIN_SERVICE', e);
      rethrow;
    }
  }

  /// Get enhanced system health status
  Future<Map<String, dynamic>> getEnhancedSystemHealth() async {
    try {
      final token = await _getAuthToken();
      if (token == null) throw Exception('No auth token');

      final baseUrl = DatabaseConfig.physicalServerUrl;
      final uri = Uri.parse('$baseUrl/api/admin/health');
      final response = await http.get(
        uri,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
          'ngrok-skip-browser-warning': 'true',
        },
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        throw Exception('Failed to get system health: ${response.statusCode}');
      }
    } catch (e) {
      Log.e('Error getting system health', 'MONGODB_ADMIN_SERVICE', e);
      rethrow;
    }
  }

  /// Broadcast message to all users
  Future<void> broadcastMessage(String message, String title) async {
    try {
      final token = await _getAuthToken();
      if (token == null) throw Exception('No auth token');

      final baseUrl = DatabaseConfig.physicalServerUrl;
      final uri = Uri.parse('$baseUrl/api/admin/broadcast');
      final response = await http.post(
        uri,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
          'ngrok-skip-browser-warning': 'true',
        },
        body: json.encode({
          'message': message,
          'title': title,
          'timestamp': DateTime.now().toIso8601String(),
        }),
      );

      if (response.statusCode != 200) {
        throw Exception('Failed to broadcast message: ${response.statusCode}');
      }
    } catch (e) {
      Log.e('Error broadcasting message', 'MONGODB_ADMIN_SERVICE', e);
      rethrow;
    }
  }

  /// Lock user account
  Future<void> lockUser(String userId, String reason) async {
    try {
      final token = await _getAuthToken();
      if (token == null) throw Exception('No auth token');

      final baseUrl = DatabaseConfig.physicalServerUrl;
      final uri = Uri.parse('$baseUrl/api/admin/users/$userId/lock');
      final response = await http.post(
        uri,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
          'ngrok-skip-browser-warning': 'true',
        },
        body: json.encode({
          'reason': reason,
          'lockedAt': DateTime.now().toIso8601String(),
        }),
      );

      if (response.statusCode != 200) {
        throw Exception('Failed to lock user: ${response.statusCode}');
      }
    } catch (e) {
      Log.e('Error locking user', 'MONGODB_ADMIN_SERVICE', e);
      rethrow;
    }
  }

  /// Unlock user account
  Future<void> unlockUser(String userId) async {
    try {
      final token = await _getAuthToken();
      if (token == null) throw Exception('No auth token');

      final baseUrl = DatabaseConfig.physicalServerUrl;
      final uri = Uri.parse('$baseUrl/api/admin/users/$userId/unlock');
      final response = await http.post(
        uri,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
          'ngrok-skip-browser-warning': 'true',
        },
      );

      if (response.statusCode != 200) {
        throw Exception('Failed to unlock user: ${response.statusCode}');
      }
    } catch (e) {
      Log.e('Error unlocking user', 'MONGODB_ADMIN_SERVICE', e);
      rethrow;
    }
  }

  /// Enhanced delete user account
  Future<void> deleteUserEnhanced(String userId) async {
    try {
      final token = await _getAuthToken();
      if (token == null) throw Exception('No auth token');

      final baseUrl = DatabaseConfig.physicalServerUrl;
      final uri = Uri.parse('$baseUrl/api/admin/users/$userId');
      final response = await http.delete(
        uri,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
          'ngrok-skip-browser-warning': 'true',
        },
      );

      if (response.statusCode != 200) {
        throw Exception('Failed to delete user: ${response.statusCode}');
      }
    } catch (e) {
      Log.e('Error deleting user', 'MONGODB_ADMIN_SERVICE', e);
      rethrow;
    }
  }

  /// Get all reports
  Future<List<Map<String, dynamic>>> getAllReports() async {
    try {
      final token = await _getAuthToken();
      if (token == null) throw Exception('No auth token');

      final baseUrl = DatabaseConfig.physicalServerUrl;
      final uri = Uri.parse('$baseUrl/api/admin/reports');
      final response = await http.get(
        uri,
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
        throw Exception('Failed to get reports: ${response.statusCode}');
      }
    } catch (e) {
      Log.e('Error getting reports', 'MONGODB_ADMIN_SERVICE', e);
      rethrow;
    }
  }

  /// Enhanced export system data
  Future<Map<String, dynamic>> exportDataEnhanced() async {
    try {
      final token = await _getAuthToken();
      if (token == null) throw Exception('No auth token');

      final baseUrl = DatabaseConfig.physicalServerUrl;
      final uri = Uri.parse('$baseUrl/api/admin/export');
      final response = await http.get(
        uri,
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
      rethrow;
    }
  }

  /// Get user logs (admin only)
  Future<List<Map<String, dynamic>>> getUserLogs({int page = 1, int limit = 100, String? userId}) async {
    try {
      final token = await _getAuthToken();
      if (token == null) throw Exception('No auth token');

      final baseUrl = DatabaseConfig.physicalServerUrl;
      final queryParams = {
        'page': page.toString(),
        'limit': limit.toString(),
        if (userId != null && userId.isNotEmpty) 'userId': userId,
      };
      final uri = Uri.parse('$baseUrl/api/admin/logs/users').replace(queryParameters: queryParams);
      final response = await http.get(
        uri,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
          'ngrok-skip-browser-warning': 'true',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return List<Map<String, dynamic>>.from(data['logs'] ?? data);
      } else {
        throw Exception('Failed to load user logs: ${response.statusCode}');
      }
    } catch (e) {
      Log.e('Error getting user logs', 'MONGODB_ADMIN_SERVICE', e);
      return [];
    }
  }

  /// Get admin logs (admin only)
  Future<List<Map<String, dynamic>>> getAdminLogs({int page = 1, int limit = 100, String? adminId}) async {
    try {
      final token = await _getAuthToken();
      if (token == null) throw Exception('No auth token');

      final baseUrl = DatabaseConfig.physicalServerUrl;
      final queryParams = {
        'page': page.toString(),
        'limit': limit.toString(),
        if (adminId != null && adminId.isNotEmpty) 'adminId': adminId,
      };
      final uri = Uri.parse('$baseUrl/api/admin/logs/admin').replace(queryParameters: queryParams);
      final response = await http.get(
        uri,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
          'ngrok-skip-browser-warning': 'true',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return List<Map<String, dynamic>>.from(data['logs'] ?? data);
      } else {
        throw Exception('Failed to load admin logs: ${response.statusCode}');
      }
    } catch (e) {
      Log.e('Error getting admin logs', 'MONGODB_ADMIN_SERVICE', e);
      return [];
    }
  }

  /// Log user activity
  Future<bool> logUserActivity(String userId, String action, Map<String, dynamic>? details) async {
    try {
      final token = await _getAuthToken();
      if (token == null) return false;

      final baseUrl = DatabaseConfig.physicalServerUrl;
      final response = await http.post(
        Uri.parse('$baseUrl/api/admin/logs/users'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
          'ngrok-skip-browser-warning': 'true',
        },
        body: json.encode({
          'userId': userId,
          'action': action,
          'details': details ?? {},
          'timestamp': DateTime.now().toIso8601String(),
        }),
      );

      return response.statusCode == 200;
    } catch (e) {
      Log.e('Error logging user activity', 'MONGODB_ADMIN_SERVICE', e);
      return false;
    }
  }

  /// Log admin activity
  Future<bool> logAdminActivity(String adminId, String action, Map<String, dynamic>? details) async {
    try {
      final token = await _getAuthToken();
      if (token == null) return false;

      final baseUrl = DatabaseConfig.physicalServerUrl;
      final response = await http.post(
        Uri.parse('$baseUrl/api/admin/logs/admin'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
          'ngrok-skip-browser-warning': 'true',
        },
        body: json.encode({
          'adminId': adminId,
          'action': action,
          'details': details ?? {},
          'timestamp': DateTime.now().toIso8601String(),
        }),
      );

      return response.statusCode == 200;
    } catch (e) {
      Log.e('Error logging admin activity', 'MONGODB_ADMIN_SERVICE', e);
      return false;
    }
  }

  /// Get all groups (admin only)
  Future<List<Map<String, dynamic>>> getAllGroups({String? search, int page = 1, int limit = 100}) async {
    try {
      final token = await _getAuthToken();
      if (token == null) throw Exception('No auth token');

      final baseUrl = DatabaseConfig.physicalServerUrl;
      final queryParams = {
        'page': page.toString(),
        'limit': limit.toString(),
        'type': 'group',
        if (search != null && search.isNotEmpty) 'search': search,
      };
      final uri = Uri.parse('$baseUrl/api/admin/chats').replace(queryParameters: queryParams);
      final response = await http.get(
        uri,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
          'ngrok-skip-browser-warning': 'true',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final chats = (data is Map && data['chats'] is List)
            ? List<Map<String, dynamic>>.from(data['chats'])
            : <Map<String, dynamic>>[];
        // Filter only groups
        return chats.where((chat) => (chat['type'] ?? '') == 'group').toList();
      } else {
        throw Exception('Failed to load groups: ${response.statusCode}');
      }
    } catch (e) {
      Log.e('Error getting all groups', 'MONGODB_ADMIN_SERVICE', e);
      return [];
    }
  }

  /// Get group details (admin only)
  Future<Map<String, dynamic>?> getGroupDetails(String groupId) async {
    try {
      final token = await _getAuthToken();
      if (token == null) throw Exception('No auth token');

      final baseUrl = DatabaseConfig.physicalServerUrl;
      final response = await http.get(
        Uri.parse('$baseUrl/api/admin/chats/$groupId'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
          'ngrok-skip-browser-warning': 'true',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return Map<String, dynamic>.from(data['chat'] ?? data);
      } else {
        throw Exception('Failed to load group details: ${response.statusCode}');
      }
    } catch (e) {
      Log.e('Error getting group details', 'MONGODB_ADMIN_SERVICE', e);
      return null;
    }
  }

  /// Delete group (admin only)
  Future<bool> deleteGroup(String groupId) async {
    try {
      final token = await _getAuthToken();
      if (token == null) return false;

      final baseUrl = DatabaseConfig.physicalServerUrl;
      final response = await http.delete(
        Uri.parse('$baseUrl/api/admin/chats/$groupId'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
          'ngrok-skip-browser-warning': 'true',
        },
      );

      return response.statusCode == 200;
    } catch (e) {
      Log.e('Error deleting group', 'MONGODB_ADMIN_SERVICE', e);
      return false;
    }
  }

  /// Update group (admin only)
  Future<bool> updateGroup(String groupId, Map<String, dynamic> updates) async {
    try {
      final token = await _getAuthToken();
      if (token == null) return false;

      final baseUrl = DatabaseConfig.physicalServerUrl;
      final response = await http.put(
        Uri.parse('$baseUrl/api/admin/chats/$groupId'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
          'ngrok-skip-browser-warning': 'true',
        },
        body: json.encode(updates),
      );

      return response.statusCode == 200;
    } catch (e) {
      Log.e('Error updating group', 'MONGODB_ADMIN_SERVICE', e);
      return false;
    }
  }

  /// Add member to group (admin only)
  Future<bool> addMemberToGroup(String groupId, String userId) async {
    try {
      final token = await _getAuthToken();
      if (token == null) return false;

      final baseUrl = DatabaseConfig.physicalServerUrl;
      final response = await http.post(
        Uri.parse('$baseUrl/api/admin/chats/$groupId/members'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
          'ngrok-skip-browser-warning': 'true',
        },
        body: json.encode({'userId': userId}),
      );

      return response.statusCode == 200;
    } catch (e) {
      Log.e('Error adding member to group', 'MONGODB_ADMIN_SERVICE', e);
      return false;
    }
  }

  /// Remove member from group (admin only)
  Future<bool> removeMemberFromGroup(String groupId, String userId) async {
    try {
      final token = await _getAuthToken();
      if (token == null) return false;

      final baseUrl = DatabaseConfig.physicalServerUrl;
      final response = await http.delete(
        Uri.parse('$baseUrl/api/admin/chats/$groupId/members/$userId'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
          'ngrok-skip-browser-warning': 'true',
        },
      );

      return response.statusCode == 200;
    } catch (e) {
      Log.e('Error removing member from group', 'MONGODB_ADMIN_SERVICE', e);
      return false;
    }
  }

  /// Get group statistics (admin only)
  Future<Map<String, dynamic>?> getGroupStatistics(String groupId) async {
    try {
      final token = await _getAuthToken();
      if (token == null) throw Exception('No auth token');

      final baseUrl = DatabaseConfig.physicalServerUrl;
      final response = await http.get(
        Uri.parse('$baseUrl/api/admin/chats/$groupId/statistics'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
          'ngrok-skip-browser-warning': 'true',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return Map<String, dynamic>.from(data);
      } else {
        throw Exception('Failed to load group statistics: ${response.statusCode}');
      }
    } catch (e) {
      Log.e('Error getting group statistics', 'MONGODB_ADMIN_SERVICE', e);
      return null;
    }
  }

  /// Archive/Unarchive group (admin only)
  Future<bool> archiveGroup(String groupId, bool archive) async {
    try {
      final token = await _getAuthToken();
      if (token == null) return false;

      final baseUrl = DatabaseConfig.physicalServerUrl;
      final response = await http.put(
        Uri.parse('$baseUrl/api/admin/chats/$groupId'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
          'ngrok-skip-browser-warning': 'true',
        },
        body: json.encode({'archived': archive}),
      );

      return response.statusCode == 200;
    } catch (e) {
      Log.e('Error archiving/unarchiving group', 'MONGODB_ADMIN_SERVICE', e);
      return false;
    }
  }

  /// Get all devices (admin only)
  Future<Map<String, dynamic>> getDevices({
    String? search,
    String? platform,
    String? userId,
    int page = 1,
    int limit = 50,
  }) async {
    try {
      final token = await _getAuthToken();
      if (token == null) throw Exception('No auth token');

      final baseUrl = DatabaseConfig.physicalServerUrl;
      final queryParams = <String, String>{
        'page': page.toString(),
        'limit': limit.toString(),
        if (search != null && search.isNotEmpty) 'search': search,
        if (platform != null && platform.isNotEmpty) 'platform': platform,
        if (userId != null && userId.isNotEmpty) 'userId': userId,
      };
      final uri = Uri.parse('$baseUrl/api/admin/devices').replace(queryParameters: queryParams);
      final response = await http.get(
        uri,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
          'ngrok-skip-browser-warning': 'true',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return Map<String, dynamic>.from(data);
      } else {
        throw Exception('Failed to load devices: ${response.statusCode}');
      }
    } catch (e) {
      Log.e('Error getting devices', 'MONGODB_ADMIN_SERVICE', e);
      return {
        'devices': <Map<String, dynamic>>[],
        'pagination': {'page': 1, 'limit': 50, 'total': 0, 'pages': 0},
        'fcmStats': {'enabled': 0, 'disabled': 0, 'total': 0}
      };
    }
  }

  /// Get FCM notification system status (admin only)
  Future<Map<String, dynamic>?> getFcmStatus() async {
    try {
      final token = await _getAuthToken();
      if (token == null) throw Exception('No auth token');

      final baseUrl = DatabaseConfig.physicalServerUrl;
      final response = await http.get(
        Uri.parse('$baseUrl/api/admin/devices/fcm-status'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
          'ngrok-skip-browser-warning': 'true',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return Map<String, dynamic>.from(data);
      } else {
        throw Exception('Failed to load FCM status: ${response.statusCode}');
      }
    } catch (e) {
      Log.e('Error getting FCM status', 'MONGODB_ADMIN_SERVICE', e);
      return null;
    }
  }

  // =============================================================================
  // SCHEDULED BROADCASTS METHODS
  // =============================================================================

  /// Schedule a broadcast
  Future<Map<String, dynamic>> scheduleBroadcast({
    required String message,
    required DateTime scheduledAt,
    String recurrence = 'none',
    Map<String, dynamic>? userSegment,
    String type = 'text',
  }) async {
    try {
      final token = await _getAuthToken();
      if (token == null) throw Exception('No auth token');

      final baseUrl = DatabaseConfig.physicalServerUrl;
      final uri = Uri.parse('$baseUrl/api/admin/broadcasts/schedule');
      final response = await http.post(
        uri,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
          'ngrok-skip-browser-warning': 'true',
        },
        body: json.encode({
          'message': message,
          'scheduledAt': scheduledAt.toIso8601String(),
          'recurrence': recurrence,
          'userSegment': userSegment,
          'type': type,
        }),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return Map<String, dynamic>.from(data);
      } else {
        final errorData = json.decode(response.body);
        throw Exception(errorData['error']?['message'] ?? 'Failed to schedule broadcast: ${response.statusCode}');
      }
    } catch (e) {
      Log.e('Error scheduling broadcast', 'MONGODB_ADMIN_SERVICE', e);
      rethrow;
    }
  }

  /// Get all scheduled broadcasts
  Future<List<Map<String, dynamic>>> getScheduledBroadcasts({String? status, int limit = 50}) async {
    try {
      final token = await _getAuthToken();
      if (token == null) throw Exception('No auth token');

      final baseUrl = DatabaseConfig.physicalServerUrl;
      final queryParams = <String, String>{
        'limit': limit.toString(),
        if (status != null) 'status': status,
      };
      final uri = Uri.parse('$baseUrl/api/admin/broadcasts/scheduled').replace(queryParameters: queryParams);
      final response = await http.get(
        uri,
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
        throw Exception('Failed to get scheduled broadcasts: ${response.statusCode}');
      }
    } catch (e) {
      Log.e('Error getting scheduled broadcasts', 'MONGODB_ADMIN_SERVICE', e);
      rethrow;
    }
  }

  /// Cancel a scheduled broadcast
  Future<void> cancelScheduledBroadcast(String broadcastId) async {
    try {
      final token = await _getAuthToken();
      if (token == null) throw Exception('No auth token');

      final baseUrl = DatabaseConfig.physicalServerUrl;
      final uri = Uri.parse('$baseUrl/api/admin/broadcasts/scheduled/$broadcastId');
      final response = await http.delete(
        uri,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
          'ngrok-skip-browser-warning': 'true',
        },
      );

      if (response.statusCode != 200) {
        final errorData = json.decode(response.body);
        throw Exception(errorData['error']?['message'] ?? 'Failed to cancel broadcast: ${response.statusCode}');
      }
    } catch (e) {
      Log.e('Error cancelling scheduled broadcast', 'MONGODB_ADMIN_SERVICE', e);
      rethrow;
    }
  }

  /// Update a scheduled broadcast
  Future<void> updateScheduledBroadcast(
    String broadcastId, {
    String? message,
    DateTime? scheduledAt,
    String? recurrence,
    Map<String, dynamic>? userSegment,
    String? type,
  }) async {
    try {
      final token = await _getAuthToken();
      if (token == null) throw Exception('No auth token');

      final baseUrl = DatabaseConfig.physicalServerUrl;
      final uri = Uri.parse('$baseUrl/api/admin/broadcasts/scheduled/$broadcastId');
      final body = <String, dynamic>{};
      if (message != null) body['message'] = message;
      if (scheduledAt != null) body['scheduledAt'] = scheduledAt.toIso8601String();
      if (recurrence != null) body['recurrence'] = recurrence;
      if (userSegment != null) body['userSegment'] = userSegment;
      if (type != null) body['type'] = type;

      final response = await http.put(
        uri,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
          'ngrok-skip-browser-warning': 'true',
        },
        body: json.encode(body),
      );

      if (response.statusCode != 200) {
        final errorData = json.decode(response.body);
        throw Exception(errorData['error']?['message'] ?? 'Failed to update broadcast: ${response.statusCode}');
      }
    } catch (e) {
      Log.e('Error updating scheduled broadcast', 'MONGODB_ADMIN_SERVICE', e);
      rethrow;
    }
  }

  /// Get recent activity (admin only)
  /// Combines user logs, admin logs, and system events (user registrations, chat creations, reports)
  Future<List<Map<String, dynamic>>> getRecentActivity({int limit = 10, String? type}) async {
    try {
      final token = await _getAuthToken();
      if (token == null) throw Exception('No auth token');

      final baseUrl = DatabaseConfig.physicalServerUrl;
      final queryParams = {
        'limit': limit.toString(),
        if (type != null && type.isNotEmpty) 'type': type,
      };
      final uri = Uri.parse('$baseUrl/api/admin/activity').replace(queryParameters: queryParams);
      final response = await http.get(
        uri,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
          'ngrok-skip-browser-warning': 'true',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final activities = (data['activities'] as List?) ?? data['activities'] ?? [];
        return List<Map<String, dynamic>>.from(activities);
      } else {
        throw Exception('Failed to load recent activity: ${response.statusCode}');
      }
    } catch (e) {
      Log.e('Error getting recent activity', 'MONGODB_ADMIN_SERVICE', e);
      return [];
    }
  }

  /// Get user details with complete information (admin only)
  /// Returns user profile, statistics, devices, and recent activity
  Future<Map<String, dynamic>?> getUserDetails(String userId) async {
    try {
      final token = await _getAuthToken();
      if (token == null) throw Exception('No auth token');

      final baseUrl = DatabaseConfig.physicalServerUrl;
      final uri = Uri.parse('$baseUrl/api/admin/users/$userId');
      final response = await http.get(
        uri,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
          'ngrok-skip-browser-warning': 'true',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return Map<String, dynamic>.from(data);
      } else {
        throw Exception('Failed to load user details: ${response.statusCode}');
      }
    } catch (e) {
      Log.e('Error getting user details', 'MONGODB_ADMIN_SERVICE', e);
      return null;
    }
  }

  // =============================================================================
  // MODERATION METHODS
  // =============================================================================

  /// Get all moderation rules
  Future<List<Map<String, dynamic>>> getModerationRules() async {
    try {
      final token = await _getAuthToken();
      if (token == null) throw Exception('No auth token');

      final baseUrl = DatabaseConfig.physicalServerUrl;
      final uri = Uri.parse('$baseUrl/api/admin/moderation/rules');
      final response = await http.get(
        uri,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
          'ngrok-skip-browser-warning': 'true',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return List<Map<String, dynamic>>.from(data['rules'] ?? []);
      } else {
        throw Exception('Failed to get moderation rules: ${response.statusCode}');
      }
    } catch (e) {
      Log.e('Error getting moderation rules', 'MONGODB_ADMIN_SERVICE', e);
      rethrow;
    }
  }

  /// Create a moderation rule
  Future<Map<String, dynamic>> createModerationRule({
    required String name,
    required String type,
    required String action,
    List<String>? keywords,
    bool enabled = true,
    String severity = 'medium',
  }) async {
    try {
      final token = await _getAuthToken();
      if (token == null) throw Exception('No auth token');

      final baseUrl = DatabaseConfig.physicalServerUrl;
      final uri = Uri.parse('$baseUrl/api/admin/moderation/rules');
      final response = await http.post(
        uri,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
          'ngrok-skip-browser-warning': 'true',
        },
        body: json.encode({
          'name': name,
          'type': type,
          'action': action,
          'keywords': keywords ?? [],
          'enabled': enabled,
          'severity': severity,
        }),
      );

      if (response.statusCode == 201) {
        return json.decode(response.body);
      } else {
        throw Exception('Failed to create moderation rule: ${response.statusCode}');
      }
    } catch (e) {
      Log.e('Error creating moderation rule', 'MONGODB_ADMIN_SERVICE', e);
      rethrow;
    }
  }

  /// Update a moderation rule
  Future<void> updateModerationRule(String ruleId, Map<String, dynamic> updates) async {
    try {
      final token = await _getAuthToken();
      if (token == null) throw Exception('No auth token');

      final baseUrl = DatabaseConfig.physicalServerUrl;
      final uri = Uri.parse('$baseUrl/api/admin/moderation/rules/$ruleId');
      final response = await http.put(
        uri,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
          'ngrok-skip-browser-warning': 'true',
        },
        body: json.encode(updates),
      );

      if (response.statusCode != 200) {
        throw Exception('Failed to update moderation rule: ${response.statusCode}');
      }
    } catch (e) {
      Log.e('Error updating moderation rule', 'MONGODB_ADMIN_SERVICE', e);
      rethrow;
    }
  }

  /// Delete a moderation rule
  Future<void> deleteModerationRule(String ruleId) async {
    try {
      final token = await _getAuthToken();
      if (token == null) throw Exception('No auth token');

      final baseUrl = DatabaseConfig.physicalServerUrl;
      final uri = Uri.parse('$baseUrl/api/admin/moderation/rules/$ruleId');
      final response = await http.delete(
        uri,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
          'ngrok-skip-browser-warning': 'true',
        },
      );

      if (response.statusCode != 200) {
        throw Exception('Failed to delete moderation rule: ${response.statusCode}');
      }
    } catch (e) {
      Log.e('Error deleting moderation rule', 'MONGODB_ADMIN_SERVICE', e);
      rethrow;
    }
  }

  /// Get moderation queue (flagged messages)
  Future<Map<String, dynamic>> getModerationQueue({
    String status = 'pending',
    int limit = 50,
    int skip = 0,
  }) async {
    try {
      final token = await _getAuthToken();
      if (token == null) throw Exception('No auth token');

      final baseUrl = DatabaseConfig.physicalServerUrl;
      final uri = Uri.parse('$baseUrl/api/admin/moderation/queue').replace(queryParameters: {
        'status': status,
        'limit': limit.toString(),
        'skip': skip.toString(),
      });
      final response = await http.get(
        uri,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
          'ngrok-skip-browser-warning': 'true',
        },
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        throw Exception('Failed to get moderation queue: ${response.statusCode}');
      }
    } catch (e) {
      Log.e('Error getting moderation queue', 'MONGODB_ADMIN_SERVICE', e);
      rethrow;
    }
  }

  /// Process a moderation queue item
  Future<void> processModerationQueueItem(String itemId, String action, {String? reason}) async {
    try {
      final token = await _getAuthToken();
      if (token == null) throw Exception('No auth token');

      final baseUrl = DatabaseConfig.physicalServerUrl;
      final uri = Uri.parse('$baseUrl/api/admin/moderation/queue/$itemId/process');
      final response = await http.post(
        uri,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
          'ngrok-skip-browser-warning': 'true',
        },
        body: json.encode({
          'action': action,
          'reason': reason,
        }),
      );

      if (response.statusCode != 200) {
        throw Exception('Failed to process moderation queue item: ${response.statusCode}');
      }
    } catch (e) {
      Log.e('Error processing moderation queue item', 'MONGODB_ADMIN_SERVICE', e);
      rethrow;
    }
  }

  /// Get user violations
  Future<List<Map<String, dynamic>>> getUserViolations(String userId) async {
    try {
      final token = await _getAuthToken();
      if (token == null) throw Exception('No auth token');

      final baseUrl = DatabaseConfig.physicalServerUrl;
      final uri = Uri.parse('$baseUrl/api/admin/moderation/violations/$userId');
      final response = await http.get(
        uri,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
          'ngrok-skip-browser-warning': 'true',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return List<Map<String, dynamic>>.from(data['violations'] ?? []);
      } else {
        throw Exception('Failed to get user violations: ${response.statusCode}');
      }
    } catch (e) {
      Log.e('Error getting user violations', 'MONGODB_ADMIN_SERVICE', e);
      rethrow;
    }
  }

  /// Perform moderation action on user (warn, mute, ban)
  Future<void> performModerationAction(String userId, String action, String reason, {int? duration}) async {
    try {
      final token = await _getAuthToken();
      if (token == null) throw Exception('No auth token');

      final baseUrl = DatabaseConfig.physicalServerUrl;
      final uri = Uri.parse('$baseUrl/api/admin/moderation/users/$userId/action');
      final response = await http.post(
        uri,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
          'ngrok-skip-browser-warning': 'true',
        },
        body: json.encode({
          'action': action,
          'reason': reason,
          if (duration != null) 'duration': duration,
        }),
      );

      if (response.statusCode != 200) {
        throw Exception('Failed to perform moderation action: ${response.statusCode}');
      }
    } catch (e) {
      Log.e('Error performing moderation action', 'MONGODB_ADMIN_SERVICE', e);
      rethrow;
    }
  }

  /// Perform bulk operations on users (admin only)
  /// Actions: 'lock', 'unlock', 'delete', 'role-change'
  Future<Map<String, dynamic>> bulkUserOperation({
    required List<String> userIds,
    required String action,
    String? reason,
    String? role,
  }) async {
    try {
      final token = await _getAuthToken();
      if (token == null) throw Exception('No auth token');

      final baseUrl = DatabaseConfig.physicalServerUrl;
      final uri = Uri.parse('$baseUrl/api/admin/users/bulk-operations');
      final response = await http.post(
        uri,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
          'ngrok-skip-browser-warning': 'true',
        },
        body: json.encode({
          'userIds': userIds,
          'action': action,
          if (reason != null) 'reason': reason,
          if (role != null) 'role': role,
        }),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return Map<String, dynamic>.from(data);
      } else {
        final errorData = json.decode(response.body);
        throw Exception(errorData['error'] ?? 'Failed to perform bulk operation: ${response.statusCode}');
      }
    } catch (e) {
      Log.e('Error performing bulk operation', 'MONGODB_ADMIN_SERVICE', e);
      rethrow;
    }
  }

  // =============================================================================
  // Advanced Search & Filtering
  // =============================================================================

  /// Perform unified search across users, chats, and messages
  Future<Map<String, dynamic>> unifiedSearch({
    required String query,
    List<String> types = const ['users', 'chats', 'messages'],
    Map<String, dynamic>? filters,
    int page = 1,
    int limit = 20,
    String sortBy = 'relevance',
    String sortOrder = 'desc',
  }) async {
    try {
      final token = await _getAuthToken();
      if (token == null) throw Exception('No auth token');

      final baseUrl = DatabaseConfig.physicalServerUrl;
      final uri = Uri.parse('$baseUrl/api/admin/search/unified');
      final response = await http.post(
        uri,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
          'ngrok-skip-browser-warning': 'true',
        },
        body: json.encode({
          'query': query,
          'types': types,
          'filters': filters ?? {},
          'page': page,
          'limit': limit,
          'sortBy': sortBy,
          'sortOrder': sortOrder,
        }),
      );

      if (response.statusCode == 200) {
        return Map<String, dynamic>.from(json.decode(response.body));
      } else {
        final errorData = json.decode(response.body);
        throw Exception(errorData['error']?['message'] ?? 'Search failed: ${response.statusCode}');
      }
    } catch (e) {
      Log.e('Error performing unified search', 'MONGODB_ADMIN_SERVICE', e);
      rethrow;
    }
  }

  /// Get search history
  Future<Map<String, dynamic>> getSearchHistory({int page = 1, int limit = 20}) async {
    try {
      final token = await _getAuthToken();
      if (token == null) throw Exception('No auth token');

      final baseUrl = DatabaseConfig.physicalServerUrl;
      final uri = Uri.parse('$baseUrl/api/admin/search/history')
          .replace(queryParameters: {
        'page': page.toString(),
        'limit': limit.toString(),
      });
      final response = await http.get(
        uri,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
          'ngrok-skip-browser-warning': 'true',
        },
      );

      if (response.statusCode == 200) {
        return Map<String, dynamic>.from(json.decode(response.body));
      } else {
        final errorData = json.decode(response.body);
        throw Exception(errorData['error']?['message'] ?? 'Failed to get search history: ${response.statusCode}');
      }
    } catch (e) {
      Log.e('Error getting search history', 'MONGODB_ADMIN_SERVICE', e);
      rethrow;
    }
  }

  /// Save a search query
  Future<Map<String, dynamic>> saveSearchQuery({
    required String name,
    required String query,
    Map<String, dynamic>? filters,
    List<String>? types,
  }) async {
    try {
      final token = await _getAuthToken();
      if (token == null) throw Exception('No auth token');

      final baseUrl = DatabaseConfig.physicalServerUrl;
      final uri = Uri.parse('$baseUrl/api/admin/search/saved');
      final response = await http.post(
        uri,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
          'ngrok-skip-browser-warning': 'true',
        },
        body: json.encode({
          'name': name,
          'query': query,
          'filters': filters ?? {},
          'types': types ?? ['users', 'chats', 'messages'],
        }),
      );

      if (response.statusCode == 200) {
        return Map<String, dynamic>.from(json.decode(response.body));
      } else {
        final errorData = json.decode(response.body);
        throw Exception(errorData['error']?['message'] ?? 'Failed to save search: ${response.statusCode}');
      }
    } catch (e) {
      Log.e('Error saving search query', 'MONGODB_ADMIN_SERVICE', e);
      rethrow;
    }
  }

  /// Get saved searches
  Future<List<Map<String, dynamic>>> getSavedSearches() async {
    try {
      final token = await _getAuthToken();
      if (token == null) throw Exception('No auth token');

      final baseUrl = DatabaseConfig.physicalServerUrl;
      final uri = Uri.parse('$baseUrl/api/admin/search/saved');
      final response = await http.get(
        uri,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
          'ngrok-skip-browser-warning': 'true',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return List<Map<String, dynamic>>.from(data['searches'] ?? []);
      } else {
        final errorData = json.decode(response.body);
        throw Exception(errorData['error']?['message'] ?? 'Failed to get saved searches: ${response.statusCode}');
      }
    } catch (e) {
      Log.e('Error getting saved searches', 'MONGODB_ADMIN_SERVICE', e);
      rethrow;
    }
  }

  /// Delete a saved search
  Future<void> deleteSavedSearch(String searchId) async {
    try {
      final token = await _getAuthToken();
      if (token == null) throw Exception('No auth token');

      final baseUrl = DatabaseConfig.physicalServerUrl;
      final uri = Uri.parse('$baseUrl/api/admin/search/saved/$searchId');
      final response = await http.delete(
        uri,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
          'ngrok-skip-browser-warning': 'true',
        },
      );

      if (response.statusCode != 200) {
        final errorData = json.decode(response.body);
        throw Exception(errorData['error']?['message'] ?? 'Failed to delete saved search: ${response.statusCode}');
      }
    } catch (e) {
      Log.e('Error deleting saved search', 'MONGODB_ADMIN_SERVICE', e);
      rethrow;
    }
  }

  // =============================================================================
  // Security & Compliance
  // =============================================================================

  /// Get security settings
  Future<Map<String, dynamic>> getSecuritySettings() async {
    try {
      final token = await _getAuthToken();
      if (token == null) throw Exception('No auth token');

      final baseUrl = DatabaseConfig.physicalServerUrl;
      final uri = Uri.parse('$baseUrl/api/admin/security/settings');
      final response = await http.get(
        uri,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
          'ngrok-skip-browser-warning': 'true',
        },
      );

      if (response.statusCode == 200) {
        return Map<String, dynamic>.from(json.decode(response.body));
      } else {
        final errorData = json.decode(response.body);
        throw Exception(errorData['error']?['message'] ?? 'Failed to get security settings: ${response.statusCode}');
      }
    } catch (e) {
      Log.e('Error getting security settings', 'MONGODB_ADMIN_SERVICE', e);
      rethrow;
    }
  }

  /// Update security settings
  Future<void> updateSecuritySettings(Map<String, dynamic> settings) async {
    try {
      final token = await _getAuthToken();
      if (token == null) throw Exception('No auth token');

      final baseUrl = DatabaseConfig.physicalServerUrl;
      final uri = Uri.parse('$baseUrl/api/admin/security/settings');
      final response = await http.put(
        uri,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
          'ngrok-skip-browser-warning': 'true',
        },
        body: json.encode(settings),
      );

      if (response.statusCode != 200) {
        final errorData = json.decode(response.body);
        throw Exception(errorData['error']?['message'] ?? 'Failed to update security settings: ${response.statusCode}');
      }
    } catch (e) {
      Log.e('Error updating security settings', 'MONGODB_ADMIN_SERVICE', e);
      rethrow;
    }
  }

  /// Add IP to whitelist
  Future<void> addIpToWhitelist(String ip, {String? description}) async {
    try {
      final token = await _getAuthToken();
      if (token == null) throw Exception('No auth token');

      final baseUrl = DatabaseConfig.physicalServerUrl;
      final uri = Uri.parse('$baseUrl/api/admin/security/ip/whitelist');
      final response = await http.post(
        uri,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
          'ngrok-skip-browser-warning': 'true',
        },
        body: json.encode({
          'ip': ip,
          if (description != null) 'description': description,
        }),
      );

      if (response.statusCode != 200) {
        final errorData = json.decode(response.body);
        throw Exception(errorData['error']?['message'] ?? 'Failed to add IP to whitelist: ${response.statusCode}');
      }
    } catch (e) {
      Log.e('Error adding IP to whitelist', 'MONGODB_ADMIN_SERVICE', e);
      rethrow;
    }
  }

  /// Remove IP from whitelist
  Future<void> removeIpFromWhitelist(String ip) async {
    try {
      final token = await _getAuthToken();
      if (token == null) throw Exception('No auth token');

      final baseUrl = DatabaseConfig.physicalServerUrl;
      final uri = Uri.parse('$baseUrl/api/admin/security/ip/whitelist/$ip');
      final response = await http.delete(
        uri,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
          'ngrok-skip-browser-warning': 'true',
        },
      );

      if (response.statusCode != 200) {
        final errorData = json.decode(response.body);
        throw Exception(errorData['error']?['message'] ?? 'Failed to remove IP from whitelist: ${response.statusCode}');
      }
    } catch (e) {
      Log.e('Error removing IP from whitelist', 'MONGODB_ADMIN_SERVICE', e);
      rethrow;
    }
  }

  /// Add IP to blacklist
  Future<void> addIpToBlacklist(String ip, {String? reason}) async {
    try {
      final token = await _getAuthToken();
      if (token == null) throw Exception('No auth token');

      final baseUrl = DatabaseConfig.physicalServerUrl;
      final uri = Uri.parse('$baseUrl/api/admin/security/ip/blacklist');
      final response = await http.post(
        uri,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
          'ngrok-skip-browser-warning': 'true',
        },
        body: json.encode({
          'ip': ip,
          if (reason != null) 'reason': reason,
        }),
      );

      if (response.statusCode != 200) {
        final errorData = json.decode(response.body);
        throw Exception(errorData['error']?['message'] ?? 'Failed to add IP to blacklist: ${response.statusCode}');
      }
    } catch (e) {
      Log.e('Error adding IP to blacklist', 'MONGODB_ADMIN_SERVICE', e);
      rethrow;
    }
  }

  /// Remove IP from blacklist
  Future<void> removeIpFromBlacklist(String ip) async {
    try {
      final token = await _getAuthToken();
      if (token == null) throw Exception('No auth token');

      final baseUrl = DatabaseConfig.physicalServerUrl;
      final uri = Uri.parse('$baseUrl/api/admin/security/ip/blacklist/$ip');
      final response = await http.delete(
        uri,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
          'ngrok-skip-browser-warning': 'true',
        },
      );

      if (response.statusCode != 200) {
        final errorData = json.decode(response.body);
        throw Exception(errorData['error']?['message'] ?? 'Failed to remove IP from blacklist: ${response.statusCode}');
      }
    } catch (e) {
      Log.e('Error removing IP from blacklist', 'MONGODB_ADMIN_SERVICE', e);
      rethrow;
    }
  }

  /// Get failed login attempts
  Future<Map<String, dynamic>> getFailedLoginAttempts({int page = 1, int limit = 50, String? ip, String? userId}) async {
    try {
      final token = await _getAuthToken();
      if (token == null) throw Exception('No auth token');

      final baseUrl = DatabaseConfig.physicalServerUrl;
      final queryParams = {
        'page': page.toString(),
        'limit': limit.toString(),
        if (ip != null) 'ip': ip,
        if (userId != null) 'userId': userId,
      };
      final uri = Uri.parse('$baseUrl/api/admin/security/failed-logins').replace(queryParameters: queryParams);
      final response = await http.get(
        uri,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
          'ngrok-skip-browser-warning': 'true',
        },
      );

      if (response.statusCode == 200) {
        return Map<String, dynamic>.from(json.decode(response.body));
      } else {
        final errorData = json.decode(response.body);
        throw Exception(errorData['error']?['message'] ?? 'Failed to get failed login attempts: ${response.statusCode}');
      }
    } catch (e) {
      Log.e('Error getting failed login attempts', 'MONGODB_ADMIN_SERVICE', e);
      rethrow;
    }
  }

  /// Get suspicious activity
  Future<Map<String, dynamic>> getSuspiciousActivity({int page = 1, int limit = 50}) async {
    try {
      final token = await _getAuthToken();
      if (token == null) throw Exception('No auth token');

      final baseUrl = DatabaseConfig.physicalServerUrl;
      final uri = Uri.parse('$baseUrl/api/admin/security/suspicious-activity')
          .replace(queryParameters: {
        'page': page.toString(),
        'limit': limit.toString(),
      });
      final response = await http.get(
        uri,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
          'ngrok-skip-browser-warning': 'true',
        },
      );

      if (response.statusCode == 200) {
        return Map<String, dynamic>.from(json.decode(response.body));
      } else {
        final errorData = json.decode(response.body);
        throw Exception(errorData['error']?['message'] ?? 'Failed to get suspicious activity: ${response.statusCode}');
      }
    } catch (e) {
      Log.e('Error getting suspicious activity', 'MONGODB_ADMIN_SERVICE', e);
      rethrow;
    }
  }

  /// Export GDPR data for a user
  Future<Map<String, dynamic>> exportGdprData(String userId) async {
    try {
      final token = await _getAuthToken();
      if (token == null) throw Exception('No auth token');

      final baseUrl = DatabaseConfig.physicalServerUrl;
      final uri = Uri.parse('$baseUrl/api/admin/compliance/gdpr/export/$userId');
      final response = await http.post(
        uri,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
          'ngrok-skip-browser-warning': 'true',
        },
      );

      if (response.statusCode == 200) {
        return Map<String, dynamic>.from(json.decode(response.body));
      } else {
        final errorData = json.decode(response.body);
        throw Exception(errorData['error']?['message'] ?? 'Failed to export GDPR data: ${response.statusCode}');
      }
    } catch (e) {
      Log.e('Error exporting GDPR data', 'MONGODB_ADMIN_SERVICE', e);
      rethrow;
    }
  }

  /// Delete GDPR data for a user
  Future<void> deleteGdprData(String userId, String reason) async {
    try {
      final token = await _getAuthToken();
      if (token == null) throw Exception('No auth token');

      final baseUrl = DatabaseConfig.physicalServerUrl;
      final uri = Uri.parse('$baseUrl/api/admin/compliance/gdpr/delete/$userId');
      final response = await http.delete(
        uri,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
          'ngrok-skip-browser-warning': 'true',
        },
        body: json.encode({'reason': reason}),
      );

      if (response.statusCode != 200) {
        final errorData = json.decode(response.body);
        throw Exception(errorData['error']?['message'] ?? 'Failed to delete GDPR data: ${response.statusCode}');
      }
    } catch (e) {
      Log.e('Error deleting GDPR data', 'MONGODB_ADMIN_SERVICE', e);
      rethrow;
    }
  }

  /// Get data retention policies
  Future<Map<String, dynamic>> getDataRetentionPolicies() async {
    try {
      final token = await _getAuthToken();
      if (token == null) throw Exception('No auth token');

      final baseUrl = DatabaseConfig.physicalServerUrl;
      final uri = Uri.parse('$baseUrl/api/admin/compliance/data-retention');
      final response = await http.get(
        uri,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
          'ngrok-skip-browser-warning': 'true',
        },
      );

      if (response.statusCode == 200) {
        return Map<String, dynamic>.from(json.decode(response.body));
      } else {
        final errorData = json.decode(response.body);
        throw Exception(errorData['error']?['message'] ?? 'Failed to get data retention policies: ${response.statusCode}');
      }
    } catch (e) {
      Log.e('Error getting data retention policies', 'MONGODB_ADMIN_SERVICE', e);
      rethrow;
    }
  }

  /// Update data retention policies
  Future<void> updateDataRetentionPolicies({
    required bool enabled,
    int? userDataDays,
    int? messageDataDays,
    int? logDataDays,
  }) async {
    try {
      final token = await _getAuthToken();
      if (token == null) throw Exception('No auth token');

      final baseUrl = DatabaseConfig.physicalServerUrl;
      final uri = Uri.parse('$baseUrl/api/admin/compliance/data-retention');
      final response = await http.put(
        uri,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
          'ngrok-skip-browser-warning': 'true',
        },
        body: json.encode({
          'enabled': enabled,
          if (userDataDays != null) 'userDataDays': userDataDays,
          if (messageDataDays != null) 'messageDataDays': messageDataDays,
          if (logDataDays != null) 'logDataDays': logDataDays,
        }),
      );

      if (response.statusCode != 200) {
        final errorData = json.decode(response.body);
        throw Exception(errorData['error']?['message'] ?? 'Failed to update data retention policies: ${response.statusCode}');
      }
    } catch (e) {
      Log.e('Error updating data retention policies', 'MONGODB_ADMIN_SERVICE', e);
      rethrow;
    }
  }

  /// Get consent tracking for a user
  Future<Map<String, dynamic>> getUserConsent(String userId) async {
    try {
      final token = await _getAuthToken();
      if (token == null) throw Exception('No auth token');

      final baseUrl = DatabaseConfig.physicalServerUrl;
      final uri = Uri.parse('$baseUrl/api/admin/compliance/consent/$userId');
      final response = await http.get(
        uri,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
          'ngrok-skip-browser-warning': 'true',
        },
      );

      if (response.statusCode == 200) {
        return Map<String, dynamic>.from(json.decode(response.body));
      } else {
        final errorData = json.decode(response.body);
        throw Exception(errorData['error']?['message'] ?? 'Failed to get user consent: ${response.statusCode}');
      }
    } catch (e) {
      Log.e('Error getting user consent', 'MONGODB_ADMIN_SERVICE', e);
      rethrow;
    }
  }

  // =============================================================================
  // Performance Monitoring
  // =============================================================================

  /// Get performance metrics
  Future<Map<String, dynamic>> getPerformanceMetrics({String period = '1h', String? endpoint}) async {
    try {
      final token = await _getAuthToken();
      if (token == null) throw Exception('No auth token');

      final baseUrl = DatabaseConfig.physicalServerUrl;
      final queryParams = {
        'period': period,
        if (endpoint != null) 'endpoint': endpoint,
      };
      final uri = Uri.parse('$baseUrl/api/admin/performance/metrics').replace(queryParameters: queryParams);
      final response = await http.get(
        uri,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
          'ngrok-skip-browser-warning': 'true',
        },
      );

      if (response.statusCode == 200) {
        return Map<String, dynamic>.from(json.decode(response.body));
      } else {
        final errorData = json.decode(response.body);
        throw Exception(errorData['error']?['message'] ?? 'Failed to get performance metrics: ${response.statusCode}');
      }
    } catch (e) {
      Log.e('Error getting performance metrics', 'MONGODB_ADMIN_SERVICE', e);
      rethrow;
    }
  }

  /// Get performance alerts
  Future<Map<String, dynamic>> getPerformanceAlerts({int page = 1, int limit = 50, String? severity}) async {
    try {
      final token = await _getAuthToken();
      if (token == null) throw Exception('No auth token');

      final baseUrl = DatabaseConfig.physicalServerUrl;
      final queryParams = {
        'page': page.toString(),
        'limit': limit.toString(),
        if (severity != null) 'severity': severity,
      };
      final uri = Uri.parse('$baseUrl/api/admin/performance/alerts').replace(queryParameters: queryParams);
      final response = await http.get(
        uri,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
          'ngrok-skip-browser-warning': 'true',
        },
      );

      if (response.statusCode == 200) {
        return Map<String, dynamic>.from(json.decode(response.body));
      } else {
        final errorData = json.decode(response.body);
        throw Exception(errorData['error']?['message'] ?? 'Failed to get performance alerts: ${response.statusCode}');
      }
    } catch (e) {
      Log.e('Error getting performance alerts', 'MONGODB_ADMIN_SERVICE', e);
      rethrow;
    }
  }

  /// Resolve a performance alert
  Future<void> resolvePerformanceAlert(String alertId) async {
    try {
      final token = await _getAuthToken();
      if (token == null) throw Exception('No auth token');

      final baseUrl = DatabaseConfig.physicalServerUrl;
      final uri = Uri.parse('$baseUrl/api/admin/performance/alerts/$alertId/resolve');
      final response = await http.post(
        uri,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
          'ngrok-skip-browser-warning': 'true',
        },
      );

      if (response.statusCode != 200) {
        final errorData = json.decode(response.body);
        throw Exception(errorData['error']?['message'] ?? 'Failed to resolve alert: ${response.statusCode}');
      }
    } catch (e) {
      Log.e('Error resolving performance alert', 'MONGODB_ADMIN_SERVICE', e);
      rethrow;
    }
  }

  // =============================================================================
  // Notification Management
  // =============================================================================

  /// Get all notification templates
  Future<List<Map<String, dynamic>>> getNotificationTemplates() async {
    try {
      final token = await _getAuthToken();
      if (token == null) throw Exception('No auth token');

      final baseUrl = DatabaseConfig.physicalServerUrl;
      final uri = Uri.parse('$baseUrl/api/admin/notifications/templates');
      final response = await http.get(
        uri,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
          'ngrok-skip-browser-warning': 'true',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return List<Map<String, dynamic>>.from(data['templates'] ?? []);
      } else {
        final errorData = json.decode(response.body);
        throw Exception(errorData['error']?['message'] ?? 'Failed to get templates: ${response.statusCode}');
      }
    } catch (e) {
      Log.e('Error getting notification templates', 'MONGODB_ADMIN_SERVICE', e);
      rethrow;
    }
  }

  /// Create notification template
  Future<Map<String, dynamic>> createNotificationTemplate({
    required String name,
    required String title,
    required String body,
    Map<String, dynamic>? data,
    String? category,
  }) async {
    try {
      final token = await _getAuthToken();
      if (token == null) throw Exception('No auth token');

      final baseUrl = DatabaseConfig.physicalServerUrl;
      final uri = Uri.parse('$baseUrl/api/admin/notifications/templates');
      final response = await http.post(
        uri,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
          'ngrok-skip-browser-warning': 'true',
        },
        body: json.encode({
          'name': name,
          'title': title,
          'body': body,
          if (data != null) 'data': data,
          if (category != null) 'category': category,
        }),
      );

      if (response.statusCode == 200) {
        return Map<String, dynamic>.from(json.decode(response.body));
      } else {
        final errorData = json.decode(response.body);
        throw Exception(errorData['error']?['message'] ?? 'Failed to create template: ${response.statusCode}');
      }
    } catch (e) {
      Log.e('Error creating notification template', 'MONGODB_ADMIN_SERVICE', e);
      rethrow;
    }
  }

  /// Update notification template
  Future<void> updateNotificationTemplate(
    String templateId, {
    String? name,
    String? title,
    String? body,
    Map<String, dynamic>? data,
    String? category,
  }) async {
    try {
      final token = await _getAuthToken();
      if (token == null) throw Exception('No auth token');

      final baseUrl = DatabaseConfig.physicalServerUrl;
      final uri = Uri.parse('$baseUrl/api/admin/notifications/templates/$templateId');
      final response = await http.put(
        uri,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
          'ngrok-skip-browser-warning': 'true',
        },
        body: json.encode({
          if (name != null) 'name': name,
          if (title != null) 'title': title,
          if (body != null) 'body': body,
          if (data != null) 'data': data,
          if (category != null) 'category': category,
        }),
      );

      if (response.statusCode != 200) {
        final errorData = json.decode(response.body);
        throw Exception(errorData['error']?['message'] ?? 'Failed to update template: ${response.statusCode}');
      }
    } catch (e) {
      Log.e('Error updating notification template', 'MONGODB_ADMIN_SERVICE', e);
      rethrow;
    }
  }

  /// Delete notification template
  Future<void> deleteNotificationTemplate(String templateId) async {
    try {
      final token = await _getAuthToken();
      if (token == null) throw Exception('No auth token');

      final baseUrl = DatabaseConfig.physicalServerUrl;
      final uri = Uri.parse('$baseUrl/api/admin/notifications/templates/$templateId');
      final response = await http.delete(
        uri,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
          'ngrok-skip-browser-warning': 'true',
        },
      );

      if (response.statusCode != 200) {
        final errorData = json.decode(response.body);
        throw Exception(errorData['error']?['message'] ?? 'Failed to delete template: ${response.statusCode}');
      }
    } catch (e) {
      Log.e('Error deleting notification template', 'MONGODB_ADMIN_SERVICE', e);
      rethrow;
    }
  }

  /// Send test notification
  Future<void> sendTestNotification({
    required String userId,
    String? title,
    String? body,
    Map<String, dynamic>? data,
    String? templateId,
  }) async {
    try {
      final token = await _getAuthToken();
      if (token == null) throw Exception('No auth token');

      final baseUrl = DatabaseConfig.physicalServerUrl;
      final uri = Uri.parse('$baseUrl/api/admin/notifications/test');
      final response = await http.post(
        uri,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
          'ngrok-skip-browser-warning': 'true',
        },
        body: json.encode({
          'userId': userId,
          if (title != null) 'title': title,
          if (body != null) 'body': body,
          if (data != null) 'data': data,
          if (templateId != null) 'templateId': templateId,
        }),
      );

      if (response.statusCode != 200) {
        final errorData = json.decode(response.body);
        throw Exception(errorData['error']?['message'] ?? 'Failed to send test notification: ${response.statusCode}');
      }
    } catch (e) {
      Log.e('Error sending test notification', 'MONGODB_ADMIN_SERVICE', e);
      rethrow;
    }
  }

  /// Get notification history
  Future<Map<String, dynamic>> getNotificationHistory({
    int page = 1,
    int limit = 50,
    String? userId,
    String? status,
    String? startDate,
    String? endDate,
  }) async {
    try {
      final token = await _getAuthToken();
      if (token == null) throw Exception('No auth token');

      final baseUrl = DatabaseConfig.physicalServerUrl;
      final queryParams = {
        'page': page.toString(),
        'limit': limit.toString(),
        if (userId != null) 'userId': userId,
        if (status != null) 'status': status,
        if (startDate != null) 'startDate': startDate,
        if (endDate != null) 'endDate': endDate,
      };
      final uri = Uri.parse('$baseUrl/api/admin/notifications/history').replace(queryParameters: queryParams);
      final response = await http.get(
        uri,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
          'ngrok-skip-browser-warning': 'true',
        },
      );

      if (response.statusCode == 200) {
        return Map<String, dynamic>.from(json.decode(response.body));
      } else {
        final errorData = json.decode(response.body);
        throw Exception(errorData['error']?['message'] ?? 'Failed to get notification history: ${response.statusCode}');
      }
    } catch (e) {
      Log.e('Error getting notification history', 'MONGODB_ADMIN_SERVICE', e);
      rethrow;
    }
  }

  /// Retry failed notification
  Future<void> retryNotification(String notificationId) async {
    try {
      final token = await _getAuthToken();
      if (token == null) throw Exception('No auth token');

      final baseUrl = DatabaseConfig.physicalServerUrl;
      final uri = Uri.parse('$baseUrl/api/admin/notifications/history/$notificationId/retry');
      final response = await http.post(
        uri,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
          'ngrok-skip-browser-warning': 'true',
        },
      );

      if (response.statusCode != 200) {
        final errorData = json.decode(response.body);
        throw Exception(errorData['error']?['message'] ?? 'Failed to retry notification: ${response.statusCode}');
      }
    } catch (e) {
      Log.e('Error retrying notification', 'MONGODB_ADMIN_SERVICE', e);
      rethrow;
    }
  }

  /// Get notification analytics
  Future<Map<String, dynamic>> getNotificationAnalytics({String period = '24h'}) async {
    try {
      final token = await _getAuthToken();
      if (token == null) throw Exception('No auth token');

      final baseUrl = DatabaseConfig.physicalServerUrl;
      final uri = Uri.parse('$baseUrl/api/admin/notifications/analytics')
          .replace(queryParameters: {'period': period});
      final response = await http.get(
        uri,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
          'ngrok-skip-browser-warning': 'true',
        },
      );

      if (response.statusCode == 200) {
        return Map<String, dynamic>.from(json.decode(response.body));
      } else {
        final errorData = json.decode(response.body);
        throw Exception(errorData['error']?['message'] ?? 'Failed to get notification analytics: ${response.statusCode}');
      }
    } catch (e) {
      Log.e('Error getting notification analytics', 'MONGODB_ADMIN_SERVICE', e);
      rethrow;
    }
  }

  /// Send targeted notifications to multiple users
  Future<Map<String, dynamic>> sendTargetedNotifications({
    required List<String> userIds,
    String? title,
    String? body,
    Map<String, dynamic>? data,
    String? templateId,
  }) async {
    try {
      final token = await _getAuthToken();
      if (token == null) throw Exception('No auth token');

      final baseUrl = DatabaseConfig.physicalServerUrl;
      final uri = Uri.parse('$baseUrl/api/admin/notifications/send');
      final response = await http.post(
        uri,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
          'ngrok-skip-browser-warning': 'true',
        },
        body: json.encode({
          'userIds': userIds,
          if (title != null) 'title': title,
          if (body != null) 'body': body,
          if (data != null) 'data': data,
          if (templateId != null) 'templateId': templateId,
        }),
      );

      if (response.statusCode == 200) {
        return Map<String, dynamic>.from(json.decode(response.body));
      } else {
        final errorData = json.decode(response.body);
        throw Exception(errorData['error']?['message'] ?? 'Failed to send notifications: ${response.statusCode}');
      }
    } catch (e) {
      Log.e('Error sending targeted notifications', 'MONGODB_ADMIN_SERVICE', e);
      rethrow;
    }
  }

  // =============================================================================
  // Chat Moderation Tools
  // =============================================================================

  /// Get chat details with optional messages
  Future<Map<String, dynamic>> getChatDetails(String chatId, {bool includeMessages = false, int page = 1, int limit = 50}) async {
    try {
      final token = await _getAuthToken();
      if (token == null) throw Exception('No auth token');

      final baseUrl = DatabaseConfig.physicalServerUrl;
      final queryParams = {
        if (includeMessages) 'includeMessages': 'true',
        if (includeMessages) 'page': page.toString(),
        if (includeMessages) 'limit': limit.toString(),
      };
      final uri = Uri.parse('$baseUrl/api/admin/chats/$chatId').replace(queryParameters: queryParams);
      final response = await http.get(
        uri,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
          'ngrok-skip-browser-warning': 'true',
        },
      );

      if (response.statusCode == 200) {
        return Map<String, dynamic>.from(json.decode(response.body));
      } else {
        final errorData = json.decode(response.body);
        throw Exception(errorData['error']?['message'] ?? 'Failed to get chat details: ${response.statusCode}');
      }
    } catch (e) {
      Log.e('Error getting chat details', 'MONGODB_ADMIN_SERVICE', e);
      rethrow;
    }
  }

  /// Get chat messages
  Future<Map<String, dynamic>> getChatMessages(String chatId, {int page = 1, int limit = 50}) async {
    try {
      final token = await _getAuthToken();
      if (token == null) throw Exception('No auth token');

      final baseUrl = DatabaseConfig.physicalServerUrl;
      final uri = Uri.parse('$baseUrl/api/admin/chats/$chatId/messages')
          .replace(queryParameters: {
        'page': page.toString(),
        'limit': limit.toString(),
      });
      final response = await http.get(
        uri,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
          'ngrok-skip-browser-warning': 'true',
        },
      );

      if (response.statusCode == 200) {
        return Map<String, dynamic>.from(json.decode(response.body));
      } else {
        final errorData = json.decode(response.body);
        throw Exception(errorData['error']?['message'] ?? 'Failed to get chat messages: ${response.statusCode}');
      }
    } catch (e) {
      Log.e('Error getting chat messages', 'MONGODB_ADMIN_SERVICE', e);
      rethrow;
    }
  }

  /// Delete message from chat
  Future<void> deleteChatMessage(String chatId, String messageId) async {
    try {
      final token = await _getAuthToken();
      if (token == null) throw Exception('No auth token');

      final baseUrl = DatabaseConfig.physicalServerUrl;
      final uri = Uri.parse('$baseUrl/api/admin/chats/$chatId/messages/$messageId');
      final response = await http.delete(
        uri,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
          'ngrok-skip-browser-warning': 'true',
        },
      );

      if (response.statusCode != 200) {
        final errorData = json.decode(response.body);
        throw Exception(errorData['error']?['message'] ?? 'Failed to delete message: ${response.statusCode}');
      }
    } catch (e) {
      Log.e('Error deleting chat message', 'MONGODB_ADMIN_SERVICE', e);
      rethrow;
    }
  }

  /// Mute chat
  Future<void> muteChat(String chatId, {int? durationHours, String? reason}) async {
    try {
      final token = await _getAuthToken();
      if (token == null) throw Exception('No auth token');

      final baseUrl = DatabaseConfig.physicalServerUrl;
      final uri = Uri.parse('$baseUrl/api/admin/chats/$chatId/mute');
      final response = await http.post(
        uri,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
          'ngrok-skip-browser-warning': 'true',
        },
        body: json.encode({
          if (durationHours != null) 'duration': durationHours,
          if (reason != null) 'reason': reason,
        }),
      );

      if (response.statusCode != 200) {
        final errorData = json.decode(response.body);
        throw Exception(errorData['error']?['message'] ?? 'Failed to mute chat: ${response.statusCode}');
      }
    } catch (e) {
      Log.e('Error muting chat', 'MONGODB_ADMIN_SERVICE', e);
      rethrow;
    }
  }

  /// Unmute chat
  Future<void> unmuteChat(String chatId) async {
    try {
      final token = await _getAuthToken();
      if (token == null) throw Exception('No auth token');

      final baseUrl = DatabaseConfig.physicalServerUrl;
      final uri = Uri.parse('$baseUrl/api/admin/chats/$chatId/unmute');
      final response = await http.post(
        uri,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
          'ngrok-skip-browser-warning': 'true',
        },
      );

      if (response.statusCode != 200) {
        final errorData = json.decode(response.body);
        throw Exception(errorData['error']?['message'] ?? 'Failed to unmute chat: ${response.statusCode}');
      }
    } catch (e) {
      Log.e('Error unmuting chat', 'MONGODB_ADMIN_SERVICE', e);
      rethrow;
    }
  }

  /// Archive chat
  Future<void> archiveChat(String chatId) async {
    try {
      final token = await _getAuthToken();
      if (token == null) throw Exception('No auth token');

      final baseUrl = DatabaseConfig.physicalServerUrl;
      final uri = Uri.parse('$baseUrl/api/admin/chats/$chatId/archive');
      final response = await http.post(
        uri,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
          'ngrok-skip-browser-warning': 'true',
        },
      );

      if (response.statusCode != 200) {
        final errorData = json.decode(response.body);
        throw Exception(errorData['error']?['message'] ?? 'Failed to archive chat: ${response.statusCode}');
      }
    } catch (e) {
      Log.e('Error archiving chat', 'MONGODB_ADMIN_SERVICE', e);
      rethrow;
    }
  }

  /// Unarchive chat
  Future<void> unarchiveChat(String chatId) async {
    try {
      final token = await _getAuthToken();
      if (token == null) throw Exception('No auth token');

      final baseUrl = DatabaseConfig.physicalServerUrl;
      final uri = Uri.parse('$baseUrl/api/admin/chats/$chatId/unarchive');
      final response = await http.post(
        uri,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
          'ngrok-skip-browser-warning': 'true',
        },
      );

      if (response.statusCode != 200) {
        final errorData = json.decode(response.body);
        throw Exception(errorData['error']?['message'] ?? 'Failed to unarchive chat: ${response.statusCode}');
      }
    } catch (e) {
      Log.e('Error unarchiving chat', 'MONGODB_ADMIN_SERVICE', e);
      rethrow;
    }
  }

  /// Transfer group ownership
  Future<void> transferGroupOwnership(String chatId, String newOwnerId) async {
    try {
      final token = await _getAuthToken();
      if (token == null) throw Exception('No auth token');

      final baseUrl = DatabaseConfig.physicalServerUrl;
      final uri = Uri.parse('$baseUrl/api/admin/chats/$chatId/transfer-ownership');
      final response = await http.post(
        uri,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
          'ngrok-skip-browser-warning': 'true',
        },
        body: json.encode({
          'newOwnerId': newOwnerId,
        }),
      );

      if (response.statusCode != 200) {
        final errorData = json.decode(response.body);
        throw Exception(errorData['error']?['message'] ?? 'Failed to transfer ownership: ${response.statusCode}');
      }
    } catch (e) {
      Log.e('Error transferring ownership', 'MONGODB_ADMIN_SERVICE', e);
      rethrow;
    }
  }

  /// Assign or remove group moderators
  Future<void> manageGroupModerators(String chatId, List<String> userIds, {required String action}) async {
    try {
      final token = await _getAuthToken();
      if (token == null) throw Exception('No auth token');

      final baseUrl = DatabaseConfig.physicalServerUrl;
      final uri = Uri.parse('$baseUrl/api/admin/chats/$chatId/moderators');
      final response = await http.post(
        uri,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
          'ngrok-skip-browser-warning': 'true',
        },
        body: json.encode({
          'userIds': userIds,
          'action': action, // 'add' or 'remove'
        }),
      );

      if (response.statusCode != 200) {
        final errorData = json.decode(response.body);
        throw Exception(errorData['error']?['message'] ?? 'Failed to manage moderators: ${response.statusCode}');
      }
    } catch (e) {
      Log.e('Error managing moderators', 'MONGODB_ADMIN_SERVICE', e);
      rethrow;
    }
  }

  /// Update group permissions
  Future<void> updateGroupPermissions(String chatId, Map<String, bool> permissions) async {
    try {
      final token = await _getAuthToken();
      if (token == null) throw Exception('No auth token');

      final baseUrl = DatabaseConfig.physicalServerUrl;
      final uri = Uri.parse('$baseUrl/api/admin/chats/$chatId/permissions');
      final response = await http.put(
        uri,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
          'ngrok-skip-browser-warning': 'true',
        },
        body: json.encode({
          'permissions': permissions,
        }),
      );

      if (response.statusCode != 200) {
        final errorData = json.decode(response.body);
        throw Exception(errorData['error']?['message'] ?? 'Failed to update permissions: ${response.statusCode}');
      }
    } catch (e) {
      Log.e('Error updating permissions', 'MONGODB_ADMIN_SERVICE', e);
      rethrow;
    }
  }

  // =============================================================================
  // Phase 3: Feature Flags & A/B Testing
  // =============================================================================

  /// Get all feature flags
  Future<List<Map<String, dynamic>>> getFeatureFlags() async {
    try {
      final token = await _getAuthToken();
      if (token == null) throw Exception('No auth token');

      final baseUrl = DatabaseConfig.physicalServerUrl;
      final uri = Uri.parse('$baseUrl/api/admin/feature-flags');
      final response = await http.get(
        uri,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
          'ngrok-skip-browser-warning': 'true',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return List<Map<String, dynamic>>.from(data['flags'] ?? []);
      } else {
        final errorData = json.decode(response.body);
        throw Exception(errorData['error']?['message'] ?? 'Failed to get feature flags: ${response.statusCode}');
      }
    } catch (e) {
      Log.e('Error getting feature flags', 'MONGODB_ADMIN_SERVICE', e);
      rethrow;
    }
  }

  /// Get single feature flag
  Future<Map<String, dynamic>> getFeatureFlag(String flagId) async {
    try {
      final token = await _getAuthToken();
      if (token == null) throw Exception('No auth token');

      final baseUrl = DatabaseConfig.physicalServerUrl;
      final uri = Uri.parse('$baseUrl/api/admin/feature-flags/$flagId');
      final response = await http.get(
        uri,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
          'ngrok-skip-browser-warning': 'true',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return Map<String, dynamic>.from(data['flag'] ?? {});
      } else {
        final errorData = json.decode(response.body);
        throw Exception(errorData['error']?['message'] ?? 'Failed to get feature flag: ${response.statusCode}');
      }
    } catch (e) {
      Log.e('Error getting feature flag', 'MONGODB_ADMIN_SERVICE', e);
      rethrow;
    }
  }

  /// Create feature flag
  Future<Map<String, dynamic>> createFeatureFlag({
    required String name,
    String? description,
    bool enabled = false,
    int rolloutPercentage = 0,
    bool abTestEnabled = false,
    List<Map<String, dynamic>>? abTestVariants,
    List<String>? targetUsers,
    List<String>? targetSegments,
  }) async {
    try {
      final token = await _getAuthToken();
      if (token == null) throw Exception('No auth token');

      final baseUrl = DatabaseConfig.physicalServerUrl;
      final uri = Uri.parse('$baseUrl/api/admin/feature-flags');
      final response = await http.post(
        uri,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
          'ngrok-skip-browser-warning': 'true',
        },
        body: json.encode({
          'name': name,
          if (description != null) 'description': description,
          'enabled': enabled,
          'rolloutPercentage': rolloutPercentage,
          'abTestEnabled': abTestEnabled,
          if (abTestVariants != null) 'abTestVariants': abTestVariants,
          if (targetUsers != null) 'targetUsers': targetUsers,
          if (targetSegments != null) 'targetSegments': targetSegments,
        }),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = json.decode(response.body);
        return Map<String, dynamic>.from(data['flag'] ?? data);
      } else {
        final errorData = json.decode(response.body);
        throw Exception(errorData['error']?['message'] ?? 'Failed to create feature flag: ${response.statusCode}');
      }
    } catch (e) {
      Log.e('Error creating feature flag', 'MONGODB_ADMIN_SERVICE', e);
      rethrow;
    }
  }

  /// Update feature flag
  Future<void> updateFeatureFlag(
    String flagId, {
    String? name,
    String? description,
    bool? enabled,
    int? rolloutPercentage,
    bool? abTestEnabled,
    List<Map<String, dynamic>>? abTestVariants,
    List<String>? targetUsers,
    List<String>? targetSegments,
  }) async {
    try {
      final token = await _getAuthToken();
      if (token == null) throw Exception('No auth token');

      final baseUrl = DatabaseConfig.physicalServerUrl;
      final uri = Uri.parse('$baseUrl/api/admin/feature-flags/$flagId');
      final response = await http.put(
        uri,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
          'ngrok-skip-browser-warning': 'true',
        },
        body: json.encode({
          if (name != null) 'name': name,
          if (description != null) 'description': description,
          if (enabled != null) 'enabled': enabled,
          if (rolloutPercentage != null) 'rolloutPercentage': rolloutPercentage,
          if (abTestEnabled != null) 'abTestEnabled': abTestEnabled,
          if (abTestVariants != null) 'abTestVariants': abTestVariants,
          if (targetUsers != null) 'targetUsers': targetUsers,
          if (targetSegments != null) 'targetSegments': targetSegments,
        }),
      );

      if (response.statusCode != 200) {
        final errorData = json.decode(response.body);
        throw Exception(errorData['error']?['message'] ?? 'Failed to update feature flag: ${response.statusCode}');
      }
    } catch (e) {
      Log.e('Error updating feature flag', 'MONGODB_ADMIN_SERVICE', e);
      rethrow;
    }
  }

  /// Delete feature flag
  Future<void> deleteFeatureFlag(String flagId) async {
    try {
      final token = await _getAuthToken();
      if (token == null) throw Exception('No auth token');

      final baseUrl = DatabaseConfig.physicalServerUrl;
      final uri = Uri.parse('$baseUrl/api/admin/feature-flags/$flagId');
      final response = await http.delete(
        uri,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
          'ngrok-skip-browser-warning': 'true',
        },
      );

      if (response.statusCode != 200) {
        final errorData = json.decode(response.body);
        throw Exception(errorData['error']?['message'] ?? 'Failed to delete feature flag: ${response.statusCode}');
      }
    } catch (e) {
      Log.e('Error deleting feature flag', 'MONGODB_ADMIN_SERVICE', e);
      rethrow;
    }
  }

  /// Check feature flag (for client apps)
  Future<Map<String, dynamic>> checkFeatureFlag(String flagName, {String? userId}) async {
    try {
      final baseUrl = DatabaseConfig.physicalServerUrl;
      final queryParams = {
        if (userId != null) 'userId': userId,
      };
      final uri = Uri.parse('$baseUrl/api/admin/feature-flags/check/$flagName').replace(queryParameters: queryParams);
      final response = await http.get(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'ngrok-skip-browser-warning': 'true',
        },
      );

      if (response.statusCode == 200) {
        return Map<String, dynamic>.from(json.decode(response.body));
      } else {
        return {'enabled': false, 'reason': 'error'};
      }
    } catch (e) {
      Log.e('Error checking feature flag', 'MONGODB_ADMIN_SERVICE', e);
      return {'enabled': false, 'reason': 'error'};
    }
  }

  /// Get feature flag analytics
  Future<Map<String, dynamic>> getFeatureFlagAnalytics(String flagId, {String period = '7d'}) async {
    try {
      final token = await _getAuthToken();
      if (token == null) throw Exception('No auth token');

      final baseUrl = DatabaseConfig.physicalServerUrl;
      final uri = Uri.parse('$baseUrl/api/admin/feature-flags/$flagId/analytics')
          .replace(queryParameters: {'period': period});
      final response = await http.get(
        uri,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
          'ngrok-skip-browser-warning': 'true',
        },
      );

      if (response.statusCode == 200) {
        return Map<String, dynamic>.from(json.decode(response.body));
      } else {
        final errorData = json.decode(response.body);
        throw Exception(errorData['error']?['message'] ?? 'Failed to get feature flag analytics: ${response.statusCode}');
      }
    } catch (e) {
      Log.e('Error getting feature flag analytics', 'MONGODB_ADMIN_SERVICE', e);
      rethrow;
    }
  }

  // =============================================================================
  // Phase 3: API Management
  // =============================================================================

  /// Get all API keys
  Future<List<Map<String, dynamic>>> getApiKeys() async {
    try {
      final token = await _getAuthToken();
      if (token == null) throw Exception('No auth token');

      final baseUrl = DatabaseConfig.physicalServerUrl;
      final uri = Uri.parse('$baseUrl/api/admin/api/keys');
      final response = await http.get(
        uri,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
          'ngrok-skip-browser-warning': 'true',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return List<Map<String, dynamic>>.from(data['keys'] ?? []);
      } else {
        final errorData = json.decode(response.body);
        throw Exception(errorData['error']?['message'] ?? 'Failed to get API keys: ${response.statusCode}');
      }
    } catch (e) {
      Log.e('Error getting API keys', 'MONGODB_ADMIN_SERVICE', e);
      rethrow;
    }
  }

  /// Get single API key
  Future<Map<String, dynamic>> getApiKey(String keyId) async {
    try {
      final token = await _getAuthToken();
      if (token == null) throw Exception('No auth token');

      final baseUrl = DatabaseConfig.physicalServerUrl;
      final uri = Uri.parse('$baseUrl/api/admin/api/keys/$keyId');
      final response = await http.get(
        uri,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
          'ngrok-skip-browser-warning': 'true',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return Map<String, dynamic>.from(data['key'] ?? {});
      } else {
        final errorData = json.decode(response.body);
        throw Exception(errorData['error']?['message'] ?? 'Failed to get API key: ${response.statusCode}');
      }
    } catch (e) {
      Log.e('Error getting API key', 'MONGODB_ADMIN_SERVICE', e);
      rethrow;
    }
  }

  /// Create API key
  Future<Map<String, dynamic>> createApiKey({
    required String name,
    List<String>? permissions,
    Map<String, dynamic>? rateLimit,
  }) async {
    try {
      final token = await _getAuthToken();
      if (token == null) throw Exception('No auth token');

      final baseUrl = DatabaseConfig.physicalServerUrl;
      final uri = Uri.parse('$baseUrl/api/admin/api/keys');
      final response = await http.post(
        uri,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
          'ngrok-skip-browser-warning': 'true',
        },
        body: json.encode({
          'name': name,
          if (permissions != null) 'permissions': permissions,
          if (rateLimit != null) 'rateLimit': rateLimit,
        }),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = json.decode(response.body);
        return Map<String, dynamic>.from(data['key'] ?? data);
      } else {
        final errorData = json.decode(response.body);
        throw Exception(errorData['error']?['message'] ?? 'Failed to create API key: ${response.statusCode}');
      }
    } catch (e) {
      Log.e('Error creating API key', 'MONGODB_ADMIN_SERVICE', e);
      rethrow;
    }
  }

  /// Update API key
  Future<void> updateApiKey(
    String keyId, {
    String? name,
    List<String>? permissions,
    Map<String, dynamic>? rateLimit,
    bool? isActive,
  }) async {
    try {
      final token = await _getAuthToken();
      if (token == null) throw Exception('No auth token');

      final baseUrl = DatabaseConfig.physicalServerUrl;
      final uri = Uri.parse('$baseUrl/api/admin/api/keys/$keyId');
      final response = await http.put(
        uri,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
          'ngrok-skip-browser-warning': 'true',
        },
        body: json.encode({
          if (name != null) 'name': name,
          if (permissions != null) 'permissions': permissions,
          if (rateLimit != null) 'rateLimit': rateLimit,
          if (isActive != null) 'isActive': isActive,
        }),
      );

      if (response.statusCode != 200) {
        final errorData = json.decode(response.body);
        throw Exception(errorData['error']?['message'] ?? 'Failed to update API key: ${response.statusCode}');
      }
    } catch (e) {
      Log.e('Error updating API key', 'MONGODB_ADMIN_SERVICE', e);
      rethrow;
    }
  }

  /// Delete API key
  Future<void> deleteApiKey(String keyId) async {
    try {
      final token = await _getAuthToken();
      if (token == null) throw Exception('No auth token');

      final baseUrl = DatabaseConfig.physicalServerUrl;
      final uri = Uri.parse('$baseUrl/api/admin/api/keys/$keyId');
      final response = await http.delete(
        uri,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
          'ngrok-skip-browser-warning': 'true',
        },
      );

      if (response.statusCode != 200) {
        final errorData = json.decode(response.body);
        throw Exception(errorData['error']?['message'] ?? 'Failed to delete API key: ${response.statusCode}');
      }
    } catch (e) {
      Log.e('Error deleting API key', 'MONGODB_ADMIN_SERVICE', e);
      rethrow;
    }
  }

  /// Get API usage analytics
  Future<Map<String, dynamic>> getApiUsageAnalytics({String period = '24h', String? keyId}) async {
    try {
      final token = await _getAuthToken();
      if (token == null) throw Exception('No auth token');

      final baseUrl = DatabaseConfig.physicalServerUrl;
      final queryParams = {
        'period': period,
        if (keyId != null) 'keyId': keyId,
      };
      final uri = Uri.parse('$baseUrl/api/admin/api/usage').replace(queryParameters: queryParams);
      final response = await http.get(
        uri,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
          'ngrok-skip-browser-warning': 'true',
        },
      );

      if (response.statusCode == 200) {
        return Map<String, dynamic>.from(json.decode(response.body));
      } else {
        final errorData = json.decode(response.body);
        throw Exception(errorData['error']?['message'] ?? 'Failed to get API usage analytics: ${response.statusCode}');
      }
    } catch (e) {
      Log.e('Error getting API usage analytics', 'MONGODB_ADMIN_SERVICE', e);
      rethrow;
    }
  }

  /// Get endpoint monitoring
  Future<Map<String, dynamic>> getEndpointMonitoring({String period = '24h'}) async {
    try {
      final token = await _getAuthToken();
      if (token == null) throw Exception('No auth token');

      final baseUrl = DatabaseConfig.physicalServerUrl;
      final uri = Uri.parse('$baseUrl/api/admin/api/endpoints').replace(queryParameters: {'period': period});
      final response = await http.get(
        uri,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
          'ngrok-skip-browser-warning': 'true',
        },
      );

      if (response.statusCode == 200) {
        return Map<String, dynamic>.from(json.decode(response.body));
      } else {
        final errorData = json.decode(response.body);
        throw Exception(errorData['error']?['message'] ?? 'Failed to get endpoint monitoring: ${response.statusCode}');
      }
    } catch (e) {
      Log.e('Error getting endpoint monitoring', 'MONGODB_ADMIN_SERVICE', e);
      rethrow;
    }
  }

  // =============================================================================
  // Phase 3: Integration Management
  // =============================================================================

  /// Get all integrations
  Future<List<Map<String, dynamic>>> getIntegrations() async {
    try {
      final token = await _getAuthToken();
      if (token == null) throw Exception('No auth token');

      final baseUrl = DatabaseConfig.physicalServerUrl;
      final uri = Uri.parse('$baseUrl/api/admin/integrations');
      final response = await http.get(
        uri,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
          'ngrok-skip-browser-warning': 'true',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return List<Map<String, dynamic>>.from(data['integrations'] ?? []);
      } else {
        final errorData = json.decode(response.body);
        throw Exception(errorData['error']?['message'] ?? 'Failed to get integrations: ${response.statusCode}');
      }
    } catch (e) {
      Log.e('Error getting integrations', 'MONGODB_ADMIN_SERVICE', e);
      rethrow;
    }
  }

  /// Get single integration
  Future<Map<String, dynamic>> getIntegration(String integrationId) async {
    try {
      final token = await _getAuthToken();
      if (token == null) throw Exception('No auth token');

      final baseUrl = DatabaseConfig.physicalServerUrl;
      final uri = Uri.parse('$baseUrl/api/admin/integrations/$integrationId');
      final response = await http.get(
        uri,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
          'ngrok-skip-browser-warning': 'true',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return Map<String, dynamic>.from(data['integration'] ?? {});
      } else {
        final errorData = json.decode(response.body);
        throw Exception(errorData['error']?['message'] ?? 'Failed to get integration: ${response.statusCode}');
      }
    } catch (e) {
      Log.e('Error getting integration', 'MONGODB_ADMIN_SERVICE', e);
      rethrow;
    }
  }

  /// Create integration
  Future<Map<String, dynamic>> createIntegration({
    required String name,
    required String type,
    Map<String, dynamic>? config,
    List<Map<String, dynamic>>? webhooks,
  }) async {
    try {
      final token = await _getAuthToken();
      if (token == null) throw Exception('No auth token');

      final baseUrl = DatabaseConfig.physicalServerUrl;
      final uri = Uri.parse('$baseUrl/api/admin/integrations');
      final response = await http.post(
        uri,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
          'ngrok-skip-browser-warning': 'true',
        },
        body: json.encode({
          'name': name,
          'type': type,
          if (config != null) 'config': config,
          if (webhooks != null) 'webhooks': webhooks,
        }),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = json.decode(response.body);
        return Map<String, dynamic>.from(data['integration'] ?? data);
      } else {
        final errorData = json.decode(response.body);
        throw Exception(errorData['error']?['message'] ?? 'Failed to create integration: ${response.statusCode}');
      }
    } catch (e) {
      Log.e('Error creating integration', 'MONGODB_ADMIN_SERVICE', e);
      rethrow;
    }
  }

  /// Update integration
  Future<void> updateIntegration(
    String integrationId, {
    String? name,
    Map<String, dynamic>? config,
    List<Map<String, dynamic>>? webhooks,
    bool? isActive,
  }) async {
    try {
      final token = await _getAuthToken();
      if (token == null) throw Exception('No auth token');

      final baseUrl = DatabaseConfig.physicalServerUrl;
      final uri = Uri.parse('$baseUrl/api/admin/integrations/$integrationId');
      final response = await http.put(
        uri,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
          'ngrok-skip-browser-warning': 'true',
        },
        body: json.encode({
          if (name != null) 'name': name,
          if (config != null) 'config': config,
          if (webhooks != null) 'webhooks': webhooks,
          if (isActive != null) 'isActive': isActive,
        }),
      );

      if (response.statusCode != 200) {
        final errorData = json.decode(response.body);
        throw Exception(errorData['error']?['message'] ?? 'Failed to update integration: ${response.statusCode}');
      }
    } catch (e) {
      Log.e('Error updating integration', 'MONGODB_ADMIN_SERVICE', e);
      rethrow;
    }
  }

  /// Delete integration
  Future<void> deleteIntegration(String integrationId) async {
    try {
      final token = await _getAuthToken();
      if (token == null) throw Exception('No auth token');

      final baseUrl = DatabaseConfig.physicalServerUrl;
      final uri = Uri.parse('$baseUrl/api/admin/integrations/$integrationId');
      final response = await http.delete(
        uri,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
          'ngrok-skip-browser-warning': 'true',
        },
      );

      if (response.statusCode != 200) {
        final errorData = json.decode(response.body);
        throw Exception(errorData['error']?['message'] ?? 'Failed to delete integration: ${response.statusCode}');
      }
    } catch (e) {
      Log.e('Error deleting integration', 'MONGODB_ADMIN_SERVICE', e);
      rethrow;
    }
  }

  /// Check integration health
  Future<Map<String, dynamic>> checkIntegrationHealth(String integrationId) async {
    try {
      final token = await _getAuthToken();
      if (token == null) throw Exception('No auth token');

      final baseUrl = DatabaseConfig.physicalServerUrl;
      final uri = Uri.parse('$baseUrl/api/admin/integrations/$integrationId/health-check');
      final response = await http.post(
        uri,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
          'ngrok-skip-browser-warning': 'true',
        },
      );

      if (response.statusCode == 200) {
        return Map<String, dynamic>.from(json.decode(response.body));
      } else {
        final errorData = json.decode(response.body);
        throw Exception(errorData['error']?['message'] ?? 'Failed to check integration health: ${response.statusCode}');
      }
    } catch (e) {
      Log.e('Error checking integration health', 'MONGODB_ADMIN_SERVICE', e);
      rethrow;
    }
  }

  /// Get webhook delivery history
  Future<List<Map<String, dynamic>>> getWebhookHistory(String integrationId, {int limit = 100}) async {
    try {
      final token = await _getAuthToken();
      if (token == null) throw Exception('No auth token');

      final baseUrl = DatabaseConfig.physicalServerUrl;
      final uri = Uri.parse('$baseUrl/api/admin/integrations/$integrationId/webhooks/history')
          .replace(queryParameters: {'limit': limit.toString()});
      final response = await http.get(
        uri,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
          'ngrok-skip-browser-warning': 'true',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return List<Map<String, dynamic>>.from(data['history'] ?? []);
      } else {
        final errorData = json.decode(response.body);
        throw Exception(errorData['error']?['message'] ?? 'Failed to get webhook history: ${response.statusCode}');
      }
    } catch (e) {
      Log.e('Error getting webhook history', 'MONGODB_ADMIN_SERVICE', e);
      rethrow;
    }
  }

  /// Test webhook
  Future<Map<String, dynamic>> testWebhook(
    String integrationId, {
    required String url,
    String method = 'POST',
    Map<String, dynamic>? payload,
  }) async {
    try {
      final token = await _getAuthToken();
      if (token == null) throw Exception('No auth token');

      final baseUrl = DatabaseConfig.physicalServerUrl;
      final uri = Uri.parse('$baseUrl/api/admin/integrations/$integrationId/webhooks/test');
      final response = await http.post(
        uri,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
          'ngrok-skip-browser-warning': 'true',
        },
        body: json.encode({
          'url': url,
          'method': method,
          if (payload != null) 'payload': payload,
        }),
      );

      if (response.statusCode == 200) {
        return Map<String, dynamic>.from(json.decode(response.body));
      } else {
        final errorData = json.decode(response.body);
        throw Exception(errorData['error']?['message'] ?? 'Failed to test webhook: ${response.statusCode}');
      }
    } catch (e) {
      Log.e('Error testing webhook', 'MONGODB_ADMIN_SERVICE', e);
      rethrow;
    }
  }

  // =============================================================================
  // Phase 3: Backup & Restore
  // =============================================================================

  /// Get all backups
  Future<List<Map<String, dynamic>>> getBackups() async {
    try {
      final token = await _getAuthToken();
      if (token == null) throw Exception('No auth token');

      final baseUrl = DatabaseConfig.physicalServerUrl;
      final uri = Uri.parse('$baseUrl/api/admin/backups');
      final response = await http.get(
        uri,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
          'ngrok-skip-browser-warning': 'true',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return List<Map<String, dynamic>>.from(data['backups'] ?? []);
      } else {
        final errorData = json.decode(response.body);
        throw Exception(errorData['error']?['message'] ?? 'Failed to get backups: ${response.statusCode}');
      }
    } catch (e) {
      Log.e('Error getting backups', 'MONGODB_ADMIN_SERVICE', e);
      rethrow;
    }
  }

  /// Create backup
  Future<Map<String, dynamic>> createBackup({String? name, String type = 'full'}) async {
    try {
      final token = await _getAuthToken();
      if (token == null) throw Exception('No auth token');

      final baseUrl = DatabaseConfig.physicalServerUrl;
      final uri = Uri.parse('$baseUrl/api/admin/backups');
      final response = await http.post(
        uri,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
          'ngrok-skip-browser-warning': 'true',
        },
        body: json.encode({
          if (name != null) 'name': name,
          'type': type,
        }),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = json.decode(response.body);
        return Map<String, dynamic>.from(data['backup'] ?? data);
      } else {
        final errorData = json.decode(response.body);
        throw Exception(errorData['error']?['message'] ?? 'Failed to create backup: ${response.statusCode}');
      }
    } catch (e) {
      Log.e('Error creating backup', 'MONGODB_ADMIN_SERVICE', e);
      rethrow;
    }
  }

  /// Restore backup
  Future<void> restoreBackup(String backupId, {bool confirm = true}) async {
    try {
      final token = await _getAuthToken();
      if (token == null) throw Exception('No auth token');

      final baseUrl = DatabaseConfig.physicalServerUrl;
      final uri = Uri.parse('$baseUrl/api/admin/backups/$backupId/restore');
      final response = await http.post(
        uri,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
          'ngrok-skip-browser-warning': 'true',
        },
        body: json.encode({'confirm': confirm}),
      );

      if (response.statusCode != 200) {
        final errorData = json.decode(response.body);
        throw Exception(errorData['error']?['message'] ?? 'Failed to restore backup: ${response.statusCode}');
      }
    } catch (e) {
      Log.e('Error restoring backup', 'MONGODB_ADMIN_SERVICE', e);
      rethrow;
    }
  }

  /// Cancel running backup
  Future<void> cancelBackup(String backupId) async {
    try {
      final token = await _getAuthToken();
      if (token == null) throw Exception('No auth token');

      final baseUrl = DatabaseConfig.physicalServerUrl;
      final uri = Uri.parse('$baseUrl/api/admin/backups/$backupId/cancel');
      final response = await http.post(
        uri,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
          'ngrok-skip-browser-warning': 'true',
        },
      );

      if (response.statusCode != 200) {
        final errorData = json.decode(response.body);
        throw Exception(errorData['error']?['message'] ?? 'Failed to cancel backup: ${response.statusCode}');
      }
    } catch (e) {
      Log.e('Error cancelling backup', 'MONGODB_ADMIN_SERVICE', e);
      rethrow;
    }
  }

  /// Delete backup
  Future<void> deleteBackup(String backupId) async {
    try {
      final token = await _getAuthToken();
      if (token == null) throw Exception('No auth token');

      final baseUrl = DatabaseConfig.physicalServerUrl;
      final uri = Uri.parse('$baseUrl/api/admin/backups/$backupId');
      final response = await http.delete(
        uri,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
          'ngrok-skip-browser-warning': 'true',
        },
      );

      if (response.statusCode != 200) {
        final errorData = json.decode(response.body);
        throw Exception(errorData['error']?['message'] ?? 'Failed to delete backup: ${response.statusCode}');
      }
    } catch (e) {
      Log.e('Error deleting backup', 'MONGODB_ADMIN_SERVICE', e);
      rethrow;
    }
  }

  /// Get backup schedules
  Future<List<Map<String, dynamic>>> getBackupSchedules() async {
    try {
      final token = await _getAuthToken();
      if (token == null) throw Exception('No auth token');

      final baseUrl = DatabaseConfig.physicalServerUrl;
      final uri = Uri.parse('$baseUrl/api/admin/backups/schedules');
      final response = await http.get(
        uri,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
          'ngrok-skip-browser-warning': 'true',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return List<Map<String, dynamic>>.from(data['schedules'] ?? []);
      } else {
        final errorData = json.decode(response.body);
        throw Exception(errorData['error']?['message'] ?? 'Failed to get backup schedules: ${response.statusCode}');
      }
    } catch (e) {
      Log.e('Error getting backup schedules', 'MONGODB_ADMIN_SERVICE', e);
      rethrow;
    }
  }

  /// Create backup schedule
  Future<Map<String, dynamic>> createBackupSchedule({
    required String name,
    required String frequency,
    String? time,
    String type = 'full',
  }) async {
    try {
      final token = await _getAuthToken();
      if (token == null) throw Exception('No auth token');

      final baseUrl = DatabaseConfig.physicalServerUrl;
      final uri = Uri.parse('$baseUrl/api/admin/backups/schedules');
      final response = await http.post(
        uri,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
          'ngrok-skip-browser-warning': 'true',
        },
        body: json.encode({
          'name': name,
          'frequency': frequency,
          if (time != null) 'time': time,
          'type': type,
        }),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = json.decode(response.body);
        return Map<String, dynamic>.from(data['schedule'] ?? data);
      } else {
        final errorData = json.decode(response.body);
        throw Exception(errorData['error']?['message'] ?? 'Failed to create backup schedule: ${response.statusCode}');
      }
    } catch (e) {
      Log.e('Error creating backup schedule', 'MONGODB_ADMIN_SERVICE', e);
      rethrow;
    }
  }

  /// Update backup schedule
  Future<void> updateBackupSchedule(
    String scheduleId, {
    String? name,
    String? frequency,
    String? time,
    String? type,
    bool? isActive,
  }) async {
    try {
      final token = await _getAuthToken();
      if (token == null) throw Exception('No auth token');

      final baseUrl = DatabaseConfig.physicalServerUrl;
      final uri = Uri.parse('$baseUrl/api/admin/backups/schedules/$scheduleId');
      final response = await http.put(
        uri,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
          'ngrok-skip-browser-warning': 'true',
        },
        body: json.encode({
          if (name != null) 'name': name,
          if (frequency != null) 'frequency': frequency,
          if (time != null) 'time': time,
          if (type != null) 'type': type,
          if (isActive != null) 'isActive': isActive,
        }),
      );

      if (response.statusCode != 200) {
        final errorData = json.decode(response.body);
        throw Exception(errorData['error']?['message'] ?? 'Failed to update backup schedule: ${response.statusCode}');
      }
    } catch (e) {
      Log.e('Error updating backup schedule', 'MONGODB_ADMIN_SERVICE', e);
      rethrow;
    }
  }

  /// Delete backup schedule
  Future<void> deleteBackupSchedule(String scheduleId) async {
    try {
      final token = await _getAuthToken();
      if (token == null) throw Exception('No auth token');

      final baseUrl = DatabaseConfig.physicalServerUrl;
      final uri = Uri.parse('$baseUrl/api/admin/backups/schedules/$scheduleId');
      final response = await http.delete(
        uri,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
          'ngrok-skip-browser-warning': 'true',
        },
      );

      if (response.statusCode != 200) {
        final errorData = json.decode(response.body);
        throw Exception(errorData['error']?['message'] ?? 'Failed to delete backup schedule: ${response.statusCode}');
      }
    } catch (e) {
      Log.e('Error deleting backup schedule', 'MONGODB_ADMIN_SERVICE', e);
      rethrow;
    }
  }

  // =============================================================================
  // Phase 3: Custom Reports
  // =============================================================================

  Future<List<Map<String, dynamic>>> getReportTemplates() async {
    try {
      final token = await _getAuthToken();
      if (token == null) throw Exception('No auth token');
      final baseUrl = DatabaseConfig.physicalServerUrl;
      final uri = Uri.parse('$baseUrl/api/admin/reports/templates');
      final response = await http.get(uri, headers: {'Authorization': 'Bearer $token', 'Content-Type': 'application/json', 'ngrok-skip-browser-warning': 'true'});
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return List<Map<String, dynamic>>.from(data['templates'] ?? []);
      } else {
        final errorData = json.decode(response.body);
        throw Exception(errorData['error']?['message'] ?? 'Failed to get templates: ${response.statusCode}');
      }
    } catch (e) {
      Log.e('Error getting report templates', 'MONGODB_ADMIN_SERVICE', e);
      rethrow;
    }
  }

  Future<Map<String, dynamic>> createReportTemplate({required String name, String? description, List<String>? fields, String format = 'csv'}) async {
    try {
      final token = await _getAuthToken();
      if (token == null) throw Exception('No auth token');
      final baseUrl = DatabaseConfig.physicalServerUrl;
      final uri = Uri.parse('$baseUrl/api/admin/reports/templates');
      final response = await http.post(uri, headers: {'Authorization': 'Bearer $token', 'Content-Type': 'application/json', 'ngrok-skip-browser-warning': 'true'}, body: json.encode({'name': name, if (description != null) 'description': description, if (fields != null) 'fields': fields, 'format': format}));
      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = json.decode(response.body);
        return Map<String, dynamic>.from(data['template'] ?? data);
      } else {
        final errorData = json.decode(response.body);
        throw Exception(errorData['error']?['message'] ?? 'Failed to create template: ${response.statusCode}');
      }
    } catch (e) {
      Log.e('Error creating report template', 'MONGODB_ADMIN_SERVICE', e);
      rethrow;
    }
  }

  Future<String> generateReport({String? templateId, String format = 'csv', Map<String, dynamic>? filters}) async {
    try {
      final token = await _getAuthToken();
      if (token == null) throw Exception('No auth token');
      final baseUrl = DatabaseConfig.physicalServerUrl;
      final uri = Uri.parse('$baseUrl/api/admin/reports/generate');
      final response = await http.post(uri, headers: {'Authorization': 'Bearer $token', 'Content-Type': 'application/json', 'ngrok-skip-browser-warning': 'true'}, body: json.encode({'templateId': templateId, 'format': format, if (filters != null) 'filters': filters}));
      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = json.decode(response.body);
        return data['reportId'] ?? '';
      } else {
        final errorData = json.decode(response.body);
        throw Exception(errorData['error']?['message'] ?? 'Failed to generate report: ${response.statusCode}');
      }
    } catch (e) {
      Log.e('Error generating report', 'MONGODB_ADMIN_SERVICE', e);
      rethrow;
    }
  }

  // =============================================================================
  // Phase 3: User Segmentation
  // =============================================================================

  Future<List<Map<String, dynamic>>> getSegments() async {
    try {
      final token = await _getAuthToken();
      if (token == null) throw Exception('No auth token');
      final baseUrl = DatabaseConfig.physicalServerUrl;
      final uri = Uri.parse('$baseUrl/api/admin/segments');
      final response = await http.get(uri, headers: {'Authorization': 'Bearer $token', 'Content-Type': 'application/json', 'ngrok-skip-browser-warning': 'true'});
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return List<Map<String, dynamic>>.from(data['segments'] ?? []);
      } else {
        final errorData = json.decode(response.body);
        throw Exception(errorData['error']?['message'] ?? 'Failed to get segments: ${response.statusCode}');
      }
    } catch (e) {
      Log.e('Error getting segments', 'MONGODB_ADMIN_SERVICE', e);
      rethrow;
    }
  }

  Future<Map<String, dynamic>> createSegment({required String name, List<Map<String, dynamic>>? rules}) async {
    try {
      final token = await _getAuthToken();
      if (token == null) throw Exception('No auth token');
      final baseUrl = DatabaseConfig.physicalServerUrl;
      final uri = Uri.parse('$baseUrl/api/admin/segments');
      final response = await http.post(uri, headers: {'Authorization': 'Bearer $token', 'Content-Type': 'application/json', 'ngrok-skip-browser-warning': 'true'}, body: json.encode({'name': name, if (rules != null) 'rules': rules}));
      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = json.decode(response.body);
        return Map<String, dynamic>.from(data['segment'] ?? data);
      } else {
        final errorData = json.decode(response.body);
        throw Exception(errorData['error']?['message'] ?? 'Failed to create segment: ${response.statusCode}');
      }
    } catch (e) {
      Log.e('Error creating segment', 'MONGODB_ADMIN_SERVICE', e);
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> getSegmentMembers(String segmentId, {int limit = 100}) async {
    try {
      final token = await _getAuthToken();
      if (token == null) throw Exception('No auth token');
      final baseUrl = DatabaseConfig.physicalServerUrl;
      final uri = Uri.parse('$baseUrl/api/admin/segments/$segmentId/members').replace(queryParameters: {'limit': limit.toString()});
      final response = await http.get(uri, headers: {'Authorization': 'Bearer $token', 'Content-Type': 'application/json', 'ngrok-skip-browser-warning': 'true'});
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return List<Map<String, dynamic>>.from(data['members'] ?? []);
      } else {
        final errorData = json.decode(response.body);
        throw Exception(errorData['error']?['message'] ?? 'Failed to get segment members: ${response.statusCode}');
      }
    } catch (e) {
      Log.e('Error getting segment members', 'MONGODB_ADMIN_SERVICE', e);
      rethrow;
    }
  }

  // =============================================================================
  // Phase 3: Announcement System
  // =============================================================================

  Future<List<Map<String, dynamic>>> getAnnouncements() async {
    try {
      final token = await _getAuthToken();
      if (token == null) throw Exception('No auth token');
      final baseUrl = DatabaseConfig.physicalServerUrl;
      final uri = Uri.parse('$baseUrl/api/admin/announcements');
      final response = await http.get(uri, headers: {'Authorization': 'Bearer $token', 'Content-Type': 'application/json', 'ngrok-skip-browser-warning': 'true'});
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return List<Map<String, dynamic>>.from(data['announcements'] ?? []);
      } else {
        final errorData = json.decode(response.body);
        throw Exception(errorData['error']?['message'] ?? 'Failed to get announcements: ${response.statusCode}');
      }
    } catch (e) {
      Log.e('Error getting announcements', 'MONGODB_ADMIN_SERVICE', e);
      rethrow;
    }
  }

  Future<Map<String, dynamic>> createAnnouncement({required String title, required String message, String type = 'info', List<String>? targetSegments, DateTime? scheduledAt}) async {
    try {
      final token = await _getAuthToken();
      if (token == null) throw Exception('No auth token');
      final baseUrl = DatabaseConfig.physicalServerUrl;
      final uri = Uri.parse('$baseUrl/api/admin/announcements');
      final response = await http.post(uri, headers: {'Authorization': 'Bearer $token', 'Content-Type': 'application/json', 'ngrok-skip-browser-warning': 'true'}, body: json.encode({'title': title, 'message': message, 'type': type, if (targetSegments != null) 'targetSegments': targetSegments, if (scheduledAt != null) 'scheduledAt': scheduledAt.toIso8601String()}));
      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = json.decode(response.body);
        return Map<String, dynamic>.from(data['announcement'] ?? data);
      } else {
        final errorData = json.decode(response.body);
        throw Exception(errorData['error']?['message'] ?? 'Failed to create announcement: ${response.statusCode}');
      }
    } catch (e) {
      Log.e('Error creating announcement', 'MONGODB_ADMIN_SERVICE', e);
      rethrow;
    }
  }

  // =============================================================================
  // Phase 3: System Configuration
  // =============================================================================

  Future<Map<String, dynamic>> getSystemConfig() async {
    try {
      final token = await _getAuthToken();
      if (token == null) throw Exception('No auth token');
      final baseUrl = DatabaseConfig.physicalServerUrl;
      final uri = Uri.parse('$baseUrl/api/admin/system/config');
      final response = await http.get(uri, headers: {'Authorization': 'Bearer $token', 'Content-Type': 'application/json', 'ngrok-skip-browser-warning': 'true'});
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return Map<String, dynamic>.from(data['config'] ?? {});
      } else {
        final errorData = json.decode(response.body);
        throw Exception(errorData['error']?['message'] ?? 'Failed to get system config: ${response.statusCode}');
      }
    } catch (e) {
      Log.e('Error getting system config', 'MONGODB_ADMIN_SERVICE', e);
      rethrow;
    }
  }

  Future<void> updateSystemConfig({bool? maintenanceMode, Map<String, dynamic>? settings}) async {
    try {
      final token = await _getAuthToken();
      if (token == null) throw Exception('No auth token');
      final baseUrl = DatabaseConfig.physicalServerUrl;
      final uri = Uri.parse('$baseUrl/api/admin/system/config');
      final response = await http.put(uri, headers: {'Authorization': 'Bearer $token', 'Content-Type': 'application/json', 'ngrok-skip-browser-warning': 'true'}, body: json.encode({if (maintenanceMode != null) 'maintenanceMode': maintenanceMode, if (settings != null) 'settings': settings}));
      if (response.statusCode != 200) {
        final errorData = json.decode(response.body);
        throw Exception(errorData['error']?['message'] ?? 'Failed to update system config: ${response.statusCode}');
      }
    } catch (e) {
      Log.e('Error updating system config', 'MONGODB_ADMIN_SERVICE', e);
      rethrow;
    }
  }
}
