// =============================================================================
// MONGODB CHAT SERVICE
// =============================================================================
// This service handles all chat-related operations with the MongoDB server
// It replaces Firebase Firestore with REST API calls to the physical server

import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import '../config/database_config.dart';
import '../services/database_service.dart';
import 'logger_service.dart';

class MongoDBChatService {
  static final MongoDBChatService _instance = MongoDBChatService._internal();
  factory MongoDBChatService() => _instance;
  MongoDBChatService._internal();

  // Token storage key
  static const String _tokenKey = 'auth_token';

  /// Get authentication token
  Future<String?> _getAuthToken() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_tokenKey);
    } catch (e) {
      Log.e('Error getting auth token', 'MONGODB_CHAT_SERVICE', e);
      return null;
    }
  }

  /// Get current user ID
  Future<String?> _getCurrentUserId() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userData = prefs.getString('user_data');
      if (userData != null) {
        final user = json.decode(userData);
        return user['id'];
      }
      return null;
    } catch (e) {
      Log.e('Error getting current user ID', 'MONGODB_CHAT_SERVICE', e);
      return null;
    }
  }

  /// Get user chats
  Future<List<Map<String, dynamic>>> getUserChats() async {
    try {
      final token = await _getAuthToken();
      if (token == null) throw Exception('No auth token');

      final baseUrl = DatabaseConfig.physicalServerUrl;
      final response = await http.get(
        Uri.parse('$baseUrl/api/chats'),
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
        throw Exception('Failed to load chats: ${response.statusCode}');
      }
    } catch (e) {
      Log.e('Error getting user chats', 'MONGODB_CHAT_SERVICE', e);
      return [];
    }
  }

  /// Get chat messages
  Future<List<Map<String, dynamic>>> getChatMessages(String chatId, {int limit = 50, int offset = 0}) async {
    try {
      final token = await _getAuthToken();
      if (token == null) throw Exception('No auth token');

      final baseUrl = DatabaseConfig.physicalServerUrl;
      final response = await http.get(
        Uri.parse('$baseUrl/api/chats/$chatId/messages?limit=$limit&offset=$offset'),
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
        throw Exception('Failed to load messages: ${response.statusCode}');
      }
    } catch (e) {
      Log.e('Error getting chat messages', 'MONGODB_CHAT_SERVICE', e);
      return [];
    }
  }

  /// Send a text message
  Future<Map<String, dynamic>?> sendTextMessage(String chatId, String content) async {
    try {
      final token = await _getAuthToken();
      if (token == null) throw Exception('No auth token');

      final baseUrl = DatabaseConfig.physicalServerUrl;
      final response = await http.post(
        Uri.parse('$baseUrl/api/chats/$chatId/messages'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
          'ngrok-skip-browser-warning': 'true',
        },
        body: json.encode({
          'content': content,
          'messageType': 'text',
        }),
      );

      if (response.statusCode == 201 || response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        throw Exception('Failed to send message: ${response.statusCode}');
      }
    } catch (e) {
      Log.e('Error sending text message', 'MONGODB_CHAT_SERVICE', e);
      return null;
    }
  }

  /// Send a media message
  Future<Map<String, dynamic>?> sendMediaMessage(String chatId, String mediaUrl, String messageType) async {
    try {
      final token = await _getAuthToken();
      if (token == null) throw Exception('No auth token');

      final baseUrl = DatabaseConfig.physicalServerUrl;
      final response = await http.post(
        Uri.parse('$baseUrl/api/chats/$chatId/messages'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
          'ngrok-skip-browser-warning': 'true',
        },
        body: json.encode({
          'content': 'Media message',
          'messageType': messageType,
          'mediaUrl': mediaUrl,
        }),
      );

      if (response.statusCode == 201 || response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        throw Exception('Failed to send media message: ${response.statusCode}');
      }
    } catch (e) {
      Log.e('Error sending media message', 'MONGODB_CHAT_SERVICE', e);
      return null;
    }
  }

  /// Create a new chat
  Future<Map<String, dynamic>?> createChat(String type, String name, List<String> memberIds) async {
    try {
      final token = await _getAuthToken();
      if (token == null) throw Exception('No auth token');

      final baseUrl = DatabaseConfig.physicalServerUrl;
      final response = await http.post(
        Uri.parse('$baseUrl/api/chats'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
          'ngrok-skip-browser-warning': 'true',
        },
        body: json.encode({
          'type': type,
          'name': name,
          'members': memberIds,
        }),
      );

      if (response.statusCode == 201 || response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        throw Exception('Failed to create chat: ${response.statusCode}');
      }
    } catch (e) {
      Log.e('Error creating chat', 'MONGODB_CHAT_SERVICE', e);
      return null;
    }
  }

  /// Get chat details
  Future<Map<String, dynamic>?> getChatDetails(String chatId) async {
    try {
      final token = await _getAuthToken();
      if (token == null) throw Exception('No auth token');

      final baseUrl = DatabaseConfig.physicalServerUrl;
      final response = await http.get(
        Uri.parse('$baseUrl/api/chats/$chatId'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
          'ngrok-skip-browser-warning': 'true',
        },
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        throw Exception('Failed to get chat details: ${response.statusCode}');
      }
    } catch (e) {
      Log.e('Error getting chat details', 'MONGODB_CHAT_SERVICE', e);
      return null;
    }
  }

  /// Get user details
  Future<Map<String, dynamic>?> getUserDetails(String userId) async {
    try {
      final token = await _getAuthToken();
      if (token == null) throw Exception('No auth token');

      final baseUrl = DatabaseConfig.physicalServerUrl;
      final response = await http.get(
        Uri.parse('$baseUrl/api/users/$userId'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
          'ngrok-skip-browser-warning': 'true',
        },
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        throw Exception('Failed to get user details: ${response.statusCode}');
      }
    } catch (e) {
      Log.e('Error getting user details', 'MONGODB_CHAT_SERVICE', e);
      return null;
    }
  }

  /// Mark messages as read
  Future<bool> markMessagesAsRead(String chatId, List<String> messageIds) async {
    try {
      final token = await _getAuthToken();
      if (token == null) throw Exception('No auth token');

      final baseUrl = DatabaseConfig.physicalServerUrl;
      final response = await http.patch(
        Uri.parse('$baseUrl/api/chats/$chatId/messages/read'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
          'ngrok-skip-browser-warning': 'true',
        },
        body: json.encode({
          'messageIds': messageIds,
        }),
      );

      return response.statusCode == 200;
    } catch (e) {
      Log.e('Error marking messages as read', 'MONGODB_CHAT_SERVICE', e);
      return false;
    }
  }

  /// Upload media file
  Future<String?> uploadMedia(List<int> fileBytes, String fileName, String contentType) async {
    try {
      final token = await _getAuthToken();
      if (token == null) throw Exception('No auth token');

      final baseUrl = DatabaseConfig.physicalServerUrl;
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('$baseUrl/api/media/upload'),
      );

      request.headers.addAll({
        'Authorization': 'Bearer $token',
        'ngrok-skip-browser-warning': 'true',
      });

      request.files.add(
        http.MultipartFile.fromBytes(
          'file',
          fileBytes,
          filename: fileName,
          contentType: null,
        ),
      );

      final response = await request.send();
      if (response.statusCode == 200) {
        final responseBody = await response.stream.bytesToString();
        final data = json.decode(responseBody);
        // Server returns { mediaUrl, type, caption, fileName, size, mimeType }
        return data['mediaUrl'] ?? data['url'];
      } else {
        throw Exception('Failed to upload media: ${response.statusCode}');
      }
    } catch (e) {
      Log.e('Error uploading media', 'MONGODB_CHAT_SERVICE', e);
      return null;
    }
  }

  /// Create a stream for real-time messages (polling-based for now)
  Stream<List<Map<String, dynamic>>> watchChatMessages(String chatId) {
    return Stream.periodic(const Duration(seconds: 2), (_) async {
      return await getChatMessages(chatId);
    }).asyncMap((future) => future);
  }

  /// Create a stream for real-time chats (polling-based for now)
  Stream<List<Map<String, dynamic>>> watchUserChats() {
    return Stream.periodic(const Duration(seconds: 3), (_) async {
      return await getUserChats();
    }).asyncMap((future) => future);
  }

  /// Delete a message
  Future<bool> deleteMessage(String chatId, String messageId) async {
    try {
      final token = await _getAuthToken();
      if (token == null) throw Exception('No auth token');

      final baseUrl = DatabaseConfig.physicalServerUrl;
      final response = await http.delete(
        Uri.parse('$baseUrl/api/chats/$chatId/messages/$messageId'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
          'ngrok-skip-browser-warning': 'true',
        },
      );

      return response.statusCode == 200;
    } catch (e) {
      Log.e('Error deleting message', 'MONGODB_CHAT_SERVICE', e);
      return false;
    }
  }

  /// Update message
  Future<bool> updateMessage(String chatId, String messageId, String newContent) async {
    try {
      final token = await _getAuthToken();
      if (token == null) throw Exception('No auth token');

      final baseUrl = DatabaseConfig.physicalServerUrl;
      final response = await http.patch(
        Uri.parse('$baseUrl/api/chats/$chatId/messages/$messageId'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
          'ngrok-skip-browser-warning': 'true',
        },
        body: json.encode({
          'content': newContent,
        }),
      );

      return response.statusCode == 200;
    } catch (e) {
      Log.e('Error updating message', 'MONGODB_CHAT_SERVICE', e);
      return false;
    }
  }

  /// Add user to chat
  Future<bool> addUserToChat(String chatId, String userId) async {
    try {
      final token = await _getAuthToken();
      if (token == null) throw Exception('No auth token');

      final baseUrl = DatabaseConfig.physicalServerUrl;
      final response = await http.post(
        Uri.parse('$baseUrl/api/chats/$chatId/members'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
          'ngrok-skip-browser-warning': 'true',
        },
        body: json.encode({
          'userId': userId,
        }),
      );

      return response.statusCode == 200;
    } catch (e) {
      Log.e('Error adding user to chat', 'MONGODB_CHAT_SERVICE', e);
      return false;
    }
  }

  /// Remove user from chat
  Future<bool> removeUserFromChat(String chatId, String userId) async {
    try {
      final token = await _getAuthToken();
      if (token == null) throw Exception('No auth token');

      final baseUrl = DatabaseConfig.physicalServerUrl;
      final response = await http.delete(
        Uri.parse('$baseUrl/api/chats/$chatId/members/$userId'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
          'ngrok-skip-browser-warning': 'true',
        },
      );

      return response.statusCode == 200;
    } catch (e) {
      Log.e('Error removing user from chat', 'MONGODB_CHAT_SERVICE', e);
      return false;
    }
  }
}
