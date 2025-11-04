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
        // Support both router response { chats: [...] } and legacy raw array
        if (data is Map && data['chats'] is List) {
          return List<Map<String, dynamic>>.from(data['chats']);
        }
        if (data is List) {
          return List<Map<String, dynamic>>.from(data);
        }
        return [];
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
      // API uses page/limit at /api/messages/:chatId
      final int page = (offset ~/ limit) + 1;
      final response = await http.get(
        Uri.parse('$baseUrl/api/messages/$chatId?limit=$limit&page=$page'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
          'ngrok-skip-browser-warning': 'true',
        },
      );

      if (response.statusCode == 200) {
        final body = json.decode(response.body);
        // Router returns { messages: [...], pagination: {...} }
        final List<dynamic> messages = (body is Map && body['messages'] is List)
            ? body['messages']
            : (body is List ? body : []);
        return List<Map<String, dynamic>>.from(messages);
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
        Uri.parse('$baseUrl/api/messages'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
          'ngrok-skip-browser-warning': 'true',
        },
        body: json.encode({
          'chatId': chatId,
          'content': content,
          'type': 'text',
        }),
      );

      if (response.statusCode == 201 || response.statusCode == 200) {
        final body = json.decode(response.body);
        // Prefer standardized { messageData: {...} }
        if (body is Map && body['messageData'] is Map) {
          return Map<String, dynamic>.from(body['messageData']);
        }
        return Map<String, dynamic>.from(body);
      } else {
        throw Exception('Failed to send message: ${response.statusCode}');
      }
    } catch (e) {
      Log.e('Error sending text message', 'MONGODB_CHAT_SERVICE', e);
      return null;
    }
  }

  /// Send a media message (supports optional caption/content)
  Future<Map<String, dynamic>?> sendMediaMessage(
    String chatId,
    String mediaUrl,
    String messageType,
    {String? content}
  ) async {
    try {
      final token = await _getAuthToken();
      if (token == null) throw Exception('No auth token');

      final baseUrl = DatabaseConfig.physicalServerUrl;
      final response = await http.post(
        Uri.parse('$baseUrl/api/messages'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
          'ngrok-skip-browser-warning': 'true',
        },
        body: json.encode({
          'chatId': chatId,
          'content': (content != null && content.isNotEmpty) ? content : 'Media message',
          'type': messageType,
          'mediaUrl': mediaUrl,
        }),
      );

      if (response.statusCode == 201 || response.statusCode == 200) {
        final body = json.decode(response.body);
        if (body is Map && body['messageData'] is Map) {
          return Map<String, dynamic>.from(body['messageData']);
        }
        return Map<String, dynamic>.from(body);
      } else {
        throw Exception('Failed to send media message: ${response.statusCode}');
      }
    } catch (e) {
      Log.e('Error sending media message', 'MONGODB_CHAT_SERVICE', e);
      return null;
    }
  }

  /// Find existing chat between two users
  Future<Map<String, dynamic>?> findExistingChat(String userId1, String userId2) async {
    try {
      Log.i('findExistingChat called for users: $userId1 and $userId2', 'MONGODB_CHAT_SERVICE');
      
      final token = await _getAuthToken();
      if (token == null) {
        Log.e('No auth token available', 'MONGODB_CHAT_SERVICE');
        throw Exception('No auth token');
      }

      final baseUrl = DatabaseConfig.physicalServerUrl;
      final response = await http.post(
        Uri.parse('$baseUrl/api/chats/find-existing'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
          'ngrok-skip-browser-warning': 'true',
        },
        body: json.encode({
          'userId1': userId1,
          'userId2': userId2,
        }),
      );

      Log.i('findExistingChat response status: ${response.statusCode}', 'MONGODB_CHAT_SERVICE');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        Log.i('Found existing chat: ${data['chat']?['_id']}', 'MONGODB_CHAT_SERVICE');
        return data['chat'];
      } else if (response.statusCode == 404) {
        // No existing chat found
        Log.i('No existing chat found between users', 'MONGODB_CHAT_SERVICE');
        return null;
      } else {
        Log.e('Failed to find existing chat: ${response.statusCode} - ${response.body}', 'MONGODB_CHAT_SERVICE');
        throw Exception('Failed to find existing chat: ${response.statusCode}');
      }
    } catch (e) {
      Log.e('Error finding existing chat', 'MONGODB_CHAT_SERVICE', e);
      return null;
    }
  }

  /// Create a new chat
  Future<Map<String, dynamic>?> createChat(String type, String name, List<String> memberIds) async {
    try {
      Log.i('createChat called with type: $type, name: $name, members: $memberIds', 'MONGODB_CHAT_SERVICE');
      
      final token = await _getAuthToken();
      if (token == null) {
        Log.e('No auth token available for chat creation', 'MONGODB_CHAT_SERVICE');
        throw Exception('No auth token');
      }

      final baseUrl = DatabaseConfig.physicalServerUrl;
      final requestBody = {
        'type': type,
        'name': name,
        'members': memberIds,
      };
      
      Log.i('createChat request: type=$type, name=$name, members=$memberIds', 'MONGODB_CHAT_SERVICE');
      Log.i('createChat request body JSON: ${json.encode(requestBody)}', 'MONGODB_CHAT_SERVICE');
      
      final response = await http.post(
        Uri.parse('$baseUrl/api/chats'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
          'ngrok-skip-browser-warning': 'true',
        },
        body: json.encode(requestBody),
      );

      Log.i('createChat response status: ${response.statusCode}', 'MONGODB_CHAT_SERVICE');

      if (response.statusCode == 201 || response.statusCode == 200) {
        final data = json.decode(response.body);
        Log.i('Successfully created chat: ${data['_id'] ?? data['id']}', 'MONGODB_CHAT_SERVICE');
        
        // Return the chat data directly if it's in the root, or extract from 'chat' field
        return data['chat'] ?? data;
      } else {
        Log.e('❌❌❌ CHAT CREATION FAILED ❌❌❌', 'MONGODB_CHAT_SERVICE');
        Log.e('Response status: ${response.statusCode}', 'MONGODB_CHAT_SERVICE');
        Log.e('Response body (raw): ${response.body}', 'MONGODB_CHAT_SERVICE');
        Log.e('Response body length: ${response.body.length} bytes', 'MONGODB_CHAT_SERVICE');
        
        String errorMessage = 'Unknown error';
        Map<String, dynamic>? errorDetails;
        try {
          final errorData = json.decode(response.body);
          Log.e('Parsed error data: $errorData', 'MONGODB_CHAT_SERVICE');
          errorMessage = errorData['error'] ?? errorData['message'] ?? response.body;
          // Include details if available
          if (errorData['details'] != null) {
            errorDetails = errorData['details'];
            Log.e('Error details found: $errorDetails', 'MONGODB_CHAT_SERVICE');
          }
          if (errorData['received'] != null) {
            errorDetails ??= {};
            errorDetails!['received'] = errorData['received'];
            Log.e('Error received data: ${errorData['received']}', 'MONGODB_CHAT_SERVICE');
          }
        } catch (e) {
          Log.e('Failed to parse error response: $e', 'MONGODB_CHAT_SERVICE');
          errorMessage = response.body;
        }
        
        String fullError = errorMessage;
        if (errorDetails != null) {
          fullError += '\nDetails: ${json.encode(errorDetails)}';
        }
        
        Log.e('Full error message: $fullError', 'MONGODB_CHAT_SERVICE');
        Log.e('Request was: type=$type, name=$name, members=$memberIds', 'MONGODB_CHAT_SERVICE');
        throw Exception('Failed to create chat: ${response.statusCode} - $fullError');
      }
    } catch (e) {
      Log.e('Error creating chat', 'MONGODB_CHAT_SERVICE', e);
      // Re-throw the exception so the caller can see the error
      rethrow;
    }
  }

  /// Find or create chat between two users
  Future<Map<String, dynamic>?> findOrCreateChat(String type, String name, List<String> memberIds) async {
    try {
      Log.i('findOrCreateChat called with type: $type, name: $name, members: $memberIds', 'MONGODB_CHAT_SERVICE');
      
      // The server now handles duplicate detection, so we can just call createChat
      // The server will return existing chat if found, or create new one
      Log.i('Creating/finding chat between: ${memberIds.join(', ')}', 'MONGODB_CHAT_SERVICE');
      final chat = await createChat(type, name, memberIds);
      if (chat != null) {
        Log.i('Successfully created/found chat: ${chat['_id']}', 'MONGODB_CHAT_SERVICE');
        return chat;
      } else {
        Log.e('Failed to create/find chat - createChat returned null', 'MONGODB_CHAT_SERVICE');
        return null;
      }
    } catch (e) {
      Log.e('Error in findOrCreateChat', 'MONGODB_CHAT_SERVICE', e);
      // Re-throw the error so the caller can see the actual error message
      rethrow;
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
        Uri.parse('$baseUrl/api/messages/$chatId/read'),
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
        Uri.parse('$baseUrl/api/messages/$messageId'),
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
      final response = await http.put(
        Uri.parse('$baseUrl/api/messages/$messageId'),
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
