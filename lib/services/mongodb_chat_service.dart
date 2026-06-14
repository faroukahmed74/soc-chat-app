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
import 'local_message_storage.dart';

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

  /// Get user chats — caches locally; returns cache when offline.
  Future<List<Map<String, dynamic>>> getUserChats() async {
    String? userId;
    try {
      userId = await _getCurrentUserId();
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
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        List<Map<String, dynamic>> chats;
        if (data is Map && data['chats'] is List) {
          chats = List<Map<String, dynamic>>.from(data['chats']);
        } else if (data is List) {
          chats = List<Map<String, dynamic>>.from(data);
        } else {
          chats = [];
        }

        if (userId != null && chats.isNotEmpty) {
          await LocalMessageStorage.saveChatsList(userId, chats);
        }
        return chats;
      } else {
        throw Exception('Failed to load chats: ${response.statusCode}');
      }
    } catch (e) {
      Log.e('Error getting user chats (using cache if available)', 'MONGODB_CHAT_SERVICE', e);
      userId ??= await _getCurrentUserId();
      if (userId != null) {
        final cached = await LocalMessageStorage.getCachedChats(userId);
        if (cached.isNotEmpty) {
          Log.i('Returning ${cached.length} cached chats (offline)', 'MONGODB_CHAT_SERVICE');
          return cached;
        }
      }
      return [];
    }
  }

  /// Get chat messages — caches locally; returns cache when offline.
  Future<List<Map<String, dynamic>>> getChatMessages(String chatId, {int limit = 50, int offset = 0}) async {
    try {
      final token = await _getAuthToken();
      if (token == null) throw Exception('No auth token');

      final baseUrl = DatabaseConfig.physicalServerUrl;
      final int page = (offset ~/ limit) + 1;
      final response = await http.get(
        Uri.parse('$baseUrl/api/messages/$chatId?limit=$limit&page=$page'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
          'ngrok-skip-browser-warning': 'true',
        },
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final body = json.decode(response.body);
        final List<dynamic> messages = (body is Map && body['messages'] is List)
            ? body['messages']
            : (body is List ? body : []);
        final result = List<Map<String, dynamic>>.from(messages);

        if (result.isNotEmpty) {
          await LocalMessageStorage.saveChatMessagesList(chatId, result);
        }
        return result;
      } else {
        throw Exception('Failed to load messages: ${response.statusCode}');
      }
    } catch (e) {
      Log.e('Error getting chat messages (using cache if available)', 'MONGODB_CHAT_SERVICE', e);
      final cached = await LocalMessageStorage.getCachedChatMessages(chatId);
      if (cached.isNotEmpty) {
        Log.i('Returning ${cached.length} cached messages for $chatId (offline)', 'MONGODB_CHAT_SERVICE');
        return cached;
      }
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
        Map<String, dynamic>? message;
        if (body is Map && body['messageData'] is Map) {
          message = Map<String, dynamic>.from(body['messageData']);
        } else if (body is Map) {
          message = Map<String, dynamic>.from(body);
        }
        if (message != null) {
          await LocalMessageStorage.upsertChatMessage(chatId, message);
        }
        return message;
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
      print('[MONGODB_CHAT_SERVICE] sendMediaMessage called: chatId=$chatId, type=$messageType, mediaUrl=$mediaUrl');
      final token = await _getAuthToken();
      if (token == null) {
        print('[MONGODB_CHAT_SERVICE] ERROR: No auth token');
        throw Exception('No auth token');
      }

      final baseUrl = DatabaseConfig.physicalServerUrl;
      final url = '$baseUrl/api/messages';
      print('[MONGODB_CHAT_SERVICE] Sending POST to: $url');
      
      final requestBody = {
        'chatId': chatId,
        'content': (content != null && content.isNotEmpty) ? content : 'Media message',
        'type': messageType,
        'mediaUrl': mediaUrl,
      };
      print('[MONGODB_CHAT_SERVICE] Request body: $requestBody');
      
      final response = await http.post(
        Uri.parse(url),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
          'ngrok-skip-browser-warning': 'true',
        },
        body: json.encode(requestBody),
      );

      print('[MONGODB_CHAT_SERVICE] Response status: ${response.statusCode}');
      print('[MONGODB_CHAT_SERVICE] Response body: ${response.body}');

      if (response.statusCode == 201 || response.statusCode == 200) {
        final body = json.decode(response.body);
        print('[MONGODB_CHAT_SERVICE] Response decoded successfully');
        Map<String, dynamic>? message;
        if (body is Map && body['messageData'] is Map) {
          print('[MONGODB_CHAT_SERVICE] Returning messageData from response');
          message = Map<String, dynamic>.from(body['messageData']);
        } else if (body is Map) {
          print('[MONGODB_CHAT_SERVICE] Returning full body as message');
          message = Map<String, dynamic>.from(body);
        }
        if (message != null) {
          await LocalMessageStorage.upsertChatMessage(chatId, message);
        }
        return message;
      } else {
        print('[MONGODB_CHAT_SERVICE] ERROR: Failed with status ${response.statusCode}');
        throw Exception('Failed to send media message: ${response.statusCode}');
      }
    } catch (e, stackTrace) {
      Log.e('Error sending media message', 'MONGODB_CHAT_SERVICE', e);
      print('[MONGODB_CHAT_SERVICE] Exception: $e');
      print('[MONGODB_CHAT_SERVICE] Stack trace: $stackTrace');
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

  /// Delete or hide a message
  Future<bool> deleteMessage(String chatId, String messageId, {bool deleteForEveryone = false}) async {
    try {
      final token = await _getAuthToken();
      if (token == null) throw Exception('No auth token');

      final baseUrl = DatabaseConfig.physicalServerUrl;
      final response = await http.patch(
        Uri.parse('$baseUrl/api/messages/$messageId/delete'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
          'ngrok-skip-browser-warning': 'true',
        },
        body: json.encode({
          'scope': deleteForEveryone ? 'everyone' : 'self',
        }),
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

  /// Hide chat for current user
  Future<bool> hideChat(String chatId, {bool hide = true}) async {
    try {
      final token = await _getAuthToken();
      if (token == null) throw Exception('No auth token');

      final baseUrl = DatabaseConfig.physicalServerUrl;
      final response = await http.patch(
        Uri.parse('$baseUrl/api/chats/$chatId/hide'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
          'ngrok-skip-browser-warning': 'true',
        },
        body: json.encode({
          'action': hide ? 'hide' : 'unhide',
        }),
      );

      return response.statusCode == 200;
    } catch (e) {
      Log.e('Error hiding chat', 'MONGODB_CHAT_SERVICE', e);
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

  /// Reply to a message
  Future<Map<String, dynamic>?> replyToMessage(
    String messageId,
    String content, {
    String? messageType,
    String? mediaUrl,
  }) async {
    try {
      final token = await _getAuthToken();
      if (token == null) throw Exception('No auth token');

      final baseUrl = DatabaseConfig.physicalServerUrl;
      final response = await http.post(
        Uri.parse('$baseUrl/api/messages/$messageId/reply'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
          'ngrok-skip-browser-warning': 'true',
        },
        body: json.encode({
          'content': content,
          'messageType': messageType ?? 'text',
          'mediaUrl': mediaUrl,
        }),
      );

      if (response.statusCode == 201 || response.statusCode == 200) {
        final body = json.decode(response.body);
        return Map<String, dynamic>.from(body);
      } else {
        throw Exception('Failed to reply to message: ${response.statusCode}');
      }
    } catch (e) {
      Log.e('Error replying to message', 'MONGODB_CHAT_SERVICE', e);
      return null;
    }
  }

  /// React to a message (add or remove reaction)
  Future<Map<String, dynamic>?> reactToMessage(String messageId, String emoji) async {
    try {
      final token = await _getAuthToken();
      if (token == null) throw Exception('No auth token');

      final baseUrl = DatabaseConfig.physicalServerUrl;
      final response = await http.post(
        Uri.parse('$baseUrl/api/messages/$messageId/react'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
          'ngrok-skip-browser-warning': 'true',
        },
        body: json.encode({
          'emoji': emoji,
        }),
      );

      if (response.statusCode == 200) {
        final body = json.decode(response.body);
        return Map<String, dynamic>.from(body);
      } else {
        throw Exception('Failed to react to message: ${response.statusCode}');
      }
    } catch (e) {
      Log.e('Error reacting to message', 'MONGODB_CHAT_SERVICE', e);
      return null;
    }
  }

  /// Get replies for a message
  Future<List<Map<String, dynamic>>> getMessageReplies(String messageId) async {
    try {
      final token = await _getAuthToken();
      if (token == null) throw Exception('No auth token');

      final baseUrl = DatabaseConfig.physicalServerUrl;
      final response = await http.get(
        Uri.parse('$baseUrl/api/messages/$messageId/replies'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
          'ngrok-skip-browser-warning': 'true',
        },
      );

      if (response.statusCode == 200) {
        final body = json.decode(response.body);
        final replies = body['replies'] as List? ?? [];
        return List<Map<String, dynamic>>.from(replies);
      } else {
        throw Exception('Failed to get replies: ${response.statusCode}');
      }
    } catch (e) {
      Log.e('Error getting message replies', 'MONGODB_CHAT_SERVICE', e);
      return [];
    }
  }

  Future<List<MediaCategorySummary>> fetchMediaSummary(String chatId) async {
    try {
      final token = await _getAuthToken();
      if (token == null) throw Exception('No auth token');

      final baseUrl = DatabaseConfig.physicalServerUrl;
      final response = await http.get(
        Uri.parse('$baseUrl/api/messages/$chatId/media-summary'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
          'ngrok-skip-browser-warning': 'true',
        },
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final body = json.decode(response.body);
        final list = (body['mediaSummary'] as List?) ?? [];
        return list
            .map((item) => MediaCategorySummary.fromJson(Map<String, dynamic>.from(item)))
            .toList();
      }
      throw Exception('Failed to load media summary (${response.statusCode})');
    } catch (e) {
      Log.e('Error fetching media summary', 'MONGODB_CHAT_SERVICE', e);
      rethrow;
    }
  }

  Future<MediaPageResult> fetchMediaByType(
    String chatId, {
    required String type,
    int page = 1,
    int limit = 50,
  }) async {
    try {
      final token = await _getAuthToken();
      if (token == null) throw Exception('No auth token');

      final baseUrl = DatabaseConfig.physicalServerUrl;
      final uri = Uri.parse('$baseUrl/api/messages/$chatId').replace(
        queryParameters: {
          'type': type,
          'page': page.toString(),
          'limit': limit.toString(),
        },
      );

      final response = await http.get(
        uri,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
          'ngrok-skip-browser-warning': 'true',
        },
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final body = json.decode(response.body) as Map<String, dynamic>;
        final messages = (body['messages'] as List?) ?? [];
        final pagination = body['pagination'] as Map<String, dynamic>? ?? {};
        final hasMore = pagination['hasMore'] == true;

        final mapped = messages
            .map((item) => Map<String, dynamic>.from(item))
            .toList();
        return MediaPageResult(messages: mapped, hasMore: hasMore);
      }
      throw Exception('Failed to load media (${response.statusCode})');
    } catch (e) {
      Log.e('Error fetching media by type', 'MONGODB_CHAT_SERVICE', e);
      rethrow;
    }
  }
}

class MediaPageResult {
  final List<Map<String, dynamic>> messages;
  final bool hasMore;

  MediaPageResult({
    required this.messages,
    required this.hasMore,
  });
}

class MediaCategorySummary {
  final String type;
  final String label;
  final int count;
  final DateTime? latestMediaAt;
  final String sampleMediaUrl;
  final String sampleContent;

  MediaCategorySummary({
    required this.type,
    required this.label,
    required this.count,
    this.latestMediaAt,
    required this.sampleMediaUrl,
    required this.sampleContent,
  });

  factory MediaCategorySummary.fromJson(Map<String, dynamic> json) {
    final type = (json['type'] ?? '').toString().toLowerCase();
    return MediaCategorySummary(
      type: type,
      label: json['label']?.toString() ?? _labelForType(type),
      count: json['count'] is int ? json['count'] as int : 0,
      latestMediaAt: json['latestMediaAt'] != null
          ? DateTime.tryParse(json['latestMediaAt'].toString())
          : null,
      sampleMediaUrl: json['sampleMediaUrl']?.toString() ?? '',
      sampleContent: json['sampleContent']?.toString() ?? '',
    );
  }

  static String _labelForType(String type) {
    switch (type) {
      case 'image':
        return 'Images';
      case 'video':
        return 'Videos';
      case 'document':
        return 'Documents';
      case 'audio':
        return 'Audio';
      default:
        return type.isNotEmpty
            ? '${type[0].toUpperCase()}${type.substring(1)}'
            : 'Media';
    }
  }
}
