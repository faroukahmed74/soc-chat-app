// lib/services/database_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// Simple document snapshot class to replace Firestore DocumentSnapshot
class DocumentSnapshot {
  final String id;
  final Map<String, dynamic> _data;
  
  DocumentSnapshot({required this.id, required Map<String, dynamic> data}) : _data = data;
  
  Map<String, dynamic> data() => _data;
  dynamic get(String field) => _data[field];
  bool get exists => _data.isNotEmpty;
}

/// Simple document reference class to replace Firestore DocumentReference
class DocumentReference {
  final String id;
  final String collection;
  
  DocumentReference({required this.id, required this.collection});
}

/// Simple query snapshot class to replace Firestore QuerySnapshot
class QuerySnapshot {
  final List<DocumentSnapshot> docs;
  
  QuerySnapshot({required this.docs});
}

/// Abstract database service interface - Physical Server Only
abstract class DatabaseService {
  Future<List<DocumentSnapshot>> getUserChats(String userId);
  Future<List<DocumentSnapshot>> getChatMessages(String chatId, {int limit = 50, int offset = 0});
  Future<DocumentReference> sendMessage(String chatId, String content, {String? mediaUrl, String? messageType});
  Future<DocumentSnapshot?> getUser(String userId);
  Future<List<DocumentSnapshot>> getAllUsers();
  Future<void> updateUserStatus(String userId, String status);
  Stream<QuerySnapshot> watchChatMessages(String chatId);
  Future<DocumentReference> createChat(String type, String name, List<String> memberIds);
  Future<void> addUserToChat(String chatId, String userId);
  Future<void> removeUserFromChat(String chatId, String userId);
}

/// Physical Server implementation using MongoDB REST API
class MongoDBService implements DatabaseService {
  final String baseUrl;
  final String authToken;
  
  MongoDBService({required this.baseUrl, required this.authToken});
  
  @override
  Future<List<DocumentSnapshot>> getUserChats(String userId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/chats'),
        headers: {
          'Authorization': 'Bearer $authToken',
          'Content-Type': 'application/json',
          'ngrok-skip-browser-warning': 'true',
        },
      );
      
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data.map((json) => _createDocumentSnapshot(json)).toList();
      } else {
        throw Exception('Failed to load chats: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Network error: $e');
    }
  }
  
  @override
  Future<List<DocumentSnapshot>> getChatMessages(String chatId, {int limit = 50, int offset = 0}) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/chats/$chatId/messages?limit=$limit&offset=$offset'),
        headers: {
          'Authorization': 'Bearer $authToken',
          'Content-Type': 'application/json',
          'ngrok-skip-browser-warning': 'true',
        },
      );
      
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data.map((json) => _createDocumentSnapshot(json)).toList();
      } else {
        throw Exception('Failed to load messages: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Network error: $e');
    }
  }
  
  @override
  Future<DocumentReference> sendMessage(String chatId, String content, {String? mediaUrl, String? messageType}) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/chats/$chatId/messages'),
        headers: {
          'Authorization': 'Bearer $authToken',
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
        final data = json.decode(response.body);
        return _createDocumentReference(data['id'], 'messages');
      } else {
        throw Exception('Failed to send message: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Network error: $e');
    }
  }
  
  @override
  Future<DocumentSnapshot?> getUser(String userId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/users/$userId'),
        headers: {
          'Authorization': 'Bearer $authToken',
          'Content-Type': 'application/json',
          'ngrok-skip-browser-warning': 'true',
        },
      );
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return _createDocumentSnapshot(data);
      } else {
        return null;
      }
    } catch (e) {
      throw Exception('Network error: $e');
    }
  }

  @override
  Future<List<DocumentSnapshot>> getAllUsers() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/users'),
        headers: {
          'Authorization': 'Bearer $authToken',
          'Content-Type': 'application/json',
          'ngrok-skip-browser-warning': 'true',
        },
      );
      
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data.map((json) => _createDocumentSnapshot(json)).toList();
      } else {
        throw Exception('Failed to load users: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Network error: $e');
    }
  }
  
  @override
  Future<void> updateUserStatus(String userId, String status) async {
    try {
      final response = await http.patch(
        Uri.parse('$baseUrl/api/users/$userId'),
        headers: {
          'Authorization': 'Bearer $authToken',
          'Content-Type': 'application/json',
          'ngrok-skip-browser-warning': 'true',
        },
        body: json.encode({'status': status}),
      );
      
      if (response.statusCode != 200) {
        throw Exception('Failed to update user status: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Network error: $e');
    }
  }
  
  @override
  Stream<QuerySnapshot> watchChatMessages(String chatId) {
    // For now, return a simple stream that polls the API
    // In a real implementation, you might use WebSockets or Server-Sent Events
    return Stream.periodic(const Duration(seconds: 2), (_) async {
      final messages = await getChatMessages(chatId);
      return QuerySnapshot(docs: messages);
    }).asyncMap((future) => future);
  }
  
  @override
  Future<DocumentReference> createChat(String type, String name, List<String> memberIds) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/chats'),
        headers: {
          'Authorization': 'Bearer $authToken',
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
        final data = json.decode(response.body);
        return _createDocumentReference(data['id'], 'chats');
      } else {
        throw Exception('Failed to create chat: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Network error: $e');
    }
  }
  
  @override
  Future<void> addUserToChat(String chatId, String userId) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/chats/$chatId/members'),
        headers: {
          'Authorization': 'Bearer $authToken',
          'Content-Type': 'application/json',
          'ngrok-skip-browser-warning': 'true',
        },
        body: json.encode({'userId': userId}),
      );
      
      if (response.statusCode != 200) {
        throw Exception('Failed to add user to chat: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Network error: $e');
    }
  }
  
  @override
  Future<void> removeUserFromChat(String chatId, String userId) async {
    try {
      final response = await http.delete(
        Uri.parse('$baseUrl/api/chats/$chatId/members/$userId'),
        headers: {
          'Authorization': 'Bearer $authToken',
          'Content-Type': 'application/json',
          'ngrok-skip-browser-warning': 'true',
        },
      );
      
      if (response.statusCode != 200) {
        throw Exception('Failed to remove user from chat: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Network error: $e');
    }
  }
  
  // Helper methods to create document objects
  DocumentSnapshot _createDocumentSnapshot(Map<String, dynamic> data) {
    return DocumentSnapshot(
      id: data['_id'] ?? data['id'] ?? '',
      data: data,
    );
  }
  
  DocumentReference _createDocumentReference(String id, String collection) {
    return DocumentReference(id: id, collection: collection);
  }
  
  QuerySnapshot _createQuerySnapshot(List<DocumentSnapshot> docs) {
    return QuerySnapshot(docs: docs);
  }
}

/// Database factory - MongoDB Server Only
class DatabaseFactory {
  static DatabaseService createDatabaseService({
    required bool usePhysicalServer,
    required String serverUrl,
    required String authToken,
  }) {
    return MongoDBService(
      baseUrl: serverUrl,
      authToken: authToken,
    );
  }
}