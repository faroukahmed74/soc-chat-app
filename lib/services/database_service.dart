// lib/services/database_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Abstract database service interface
/// This allows us to switch between different database implementations
abstract class DatabaseService {
  Future<List<DocumentSnapshot>> getUserChats(String userId);
  Future<List<DocumentSnapshot>> getChatMessages(String chatId, {int limit = 50, int offset = 0});
  Future<DocumentReference> sendMessage(String chatId, String content, {String? mediaUrl, String? messageType});
  Future<DocumentSnapshot?> getUser(String userId);
  Future<void> updateUserStatus(String userId, String status);
  Stream<QuerySnapshot> watchChatMessages(String chatId);
  Future<DocumentReference> createChat(String type, String name, List<String> memberIds);
  Future<void> addUserToChat(String chatId, String userId);
  Future<void> removeUserFromChat(String chatId, String userId);
}

/// PostgreSQL implementation using REST API
class PostgreSQLService implements DatabaseService {
  final String baseUrl;
  final String authToken;
  
  PostgreSQLService({required this.baseUrl, required this.authToken});
  
  @override
  Future<List<DocumentSnapshot>> getUserChats(String userId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/chats'),
        headers: {
          'Authorization': 'Bearer $authToken',
          'Content-Type': 'application/json',
        },
      );
      
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        // Convert to DocumentSnapshot-like objects
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
  Future<void> updateUserStatus(String userId, String status) async {
    try {
      final response = await http.patch(
        Uri.parse('$baseUrl/api/users/$userId'),
        headers: {
          'Authorization': 'Bearer $authToken',
          'Content-Type': 'application/json',
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
    // For now, implement polling. In production, use WebSocket
    return Stream.periodic(Duration(seconds: 3), (_) async {
      final messages = await getChatMessages(chatId);
      return _createQuerySnapshot(messages);
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
        },
        body: json.encode({
          'type': type,
          'name': name,
          'memberIds': memberIds,
        }),
      );
      
      if (response.statusCode == 201) {
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
        },
      );
      
      if (response.statusCode != 200) {
        throw Exception('Failed to remove user from chat: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Network error: $e');
    }
  }
  
  // Helper methods to create Firestore-like objects
  DocumentSnapshot _createDocumentSnapshot(Map<String, dynamic> data) {
    // This is a simplified implementation
    // In a real implementation, you'd need to create proper DocumentSnapshot objects
    return _MockDocumentSnapshot(data);
  }
  
  DocumentReference _createDocumentReference(String id, String collection) {
    return _MockDocumentReference(id, collection);
  }
  
  QuerySnapshot _createQuerySnapshot(List<DocumentSnapshot> docs) {
    return _MockQuerySnapshot(docs);
  }
}

/// Firestore implementation (for fallback)
class FirestoreService implements DatabaseService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  @override
  Future<List<DocumentSnapshot>> getUserChats(String userId) async {
    try {
      final snapshot = await _firestore
          .collection('chats')
          .where('members', arrayContains: userId)
          .orderBy('lastMessageTime', descending: true)
          .get();
      
      return snapshot.docs;
    } catch (e) {
      throw Exception('Firestore error: $e');
    }
  }
  
  @override
  Future<List<DocumentSnapshot>> getChatMessages(String chatId, {int limit = 50, int offset = 0}) async {
    try {
      final snapshot = await _firestore
          .collection('messages')
          .where('chatId', isEqualTo: chatId)
          .orderBy('timestamp', descending: true)
          .limit(limit)
          .get();
      
      return snapshot.docs;
    } catch (e) {
      throw Exception('Firestore error: $e');
    }
  }
  
  @override
  Future<DocumentReference> sendMessage(String chatId, String content, {String? mediaUrl, String? messageType}) async {
    try {
      final messageData = {
        'chatId': chatId,
        'content': content,
        'messageType': messageType ?? 'text',
        'mediaUrl': mediaUrl,
        'timestamp': FieldValue.serverTimestamp(),
        'senderId': getCurrentUserId(),
      };
      
      final docRef = await _firestore.collection('messages').add(messageData);
      return docRef;
    } catch (e) {
      throw Exception('Firestore error: $e');
    }
  }
  
  @override
  Future<DocumentSnapshot?> getUser(String userId) async {
    try {
      final doc = await _firestore.collection('users').doc(userId).get();
      return doc.exists ? doc : null;
    } catch (e) {
      throw Exception('Firestore error: $e');
    }
  }
  
  @override
  Future<void> updateUserStatus(String userId, String status) async {
    try {
      await _firestore.collection('users').doc(userId).update({
        'status': status,
        'lastSeen': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw Exception('Firestore error: $e');
    }
  }
  
  @override
  Stream<QuerySnapshot> watchChatMessages(String chatId) {
    return _firestore
        .collection('messages')
        .where('chatId', isEqualTo: chatId)
        .orderBy('timestamp', descending: true)
        .limit(50)
        .snapshots();
  }
  
  @override
  Future<DocumentReference> createChat(String type, String name, List<String> memberIds) async {
    try {
      final docRef = await _firestore.collection('chats').add({
        'type': type,
        'name': name,
        'members': memberIds,
        'createdAt': FieldValue.serverTimestamp(),
        'lastMessageTime': FieldValue.serverTimestamp(),
      });
      return docRef;
    } catch (e) {
      throw Exception('Firestore error: $e');
    }
  }
  
  @override
  Future<void> addUserToChat(String chatId, String userId) async {
    try {
      await _firestore.collection('chats').doc(chatId).update({
        'members': FieldValue.arrayUnion([userId]),
      });
    } catch (e) {
      throw Exception('Firestore error: $e');
    }
  }
  
  @override
  Future<void> removeUserFromChat(String chatId, String userId) async {
    try {
      await _firestore.collection('chats').doc(chatId).update({
        'members': FieldValue.arrayRemove([userId]),
      });
    } catch (e) {
      throw Exception('Firestore error: $e');
    }
  }
  
  // Helper method to get current user ID
  String getCurrentUserId() {
    return FirebaseAuth.instance.currentUser?.uid ?? '';
  }
}

/// Database factory for easy switching
class DatabaseFactory {
  static DatabaseService createDatabaseService({
    required bool usePhysicalServer,
    String? serverUrl,
    String? authToken,
  }) {
    if (usePhysicalServer && serverUrl != null && authToken != null) {
      return PostgreSQLService(
        baseUrl: serverUrl,
        authToken: authToken,
      );
    } else {
      return FirestoreService();
    }
  }
}

/// Mock classes for PostgreSQL implementation
class _MockDocumentSnapshot implements DocumentSnapshot<Object?> {
  final Map<String, dynamic> _data;
  
  _MockDocumentSnapshot(this._data);
  
  @override
  Map<String, dynamic> data() => _data;
  
  @override
  dynamic get(Object field) => _data[field.toString()];
  
  @override
  bool get exists => _data.isNotEmpty;
  
  @override
  String get id => _data['id'] ?? '';
  
  @override
  DocumentReference<Object?> get reference => _MockDocumentReference(id, 'collection');
  
  @override
  SnapshotMetadata get metadata => _MockSnapshotMetadata();
  
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _MockDocumentReference implements DocumentReference<Object?> {
  final String _id;
  final String _collection;
  
  _MockDocumentReference(this._id, this._collection);
  
  @override
  String get id => _id;
  
  @override
  CollectionReference<Object?> get parent => _MockCollectionReference(_collection);
  
  @override
  String get path => '$_collection/$_id';
  
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _MockCollectionReference implements CollectionReference<Object?> {
  final String _collection;
  
  _MockCollectionReference(this._collection);
  
  @override
  String get id => _collection;
  
  @override
  String get path => _collection;
  
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _MockQuerySnapshot implements QuerySnapshot<Object?> {
  final List<QueryDocumentSnapshot<Object?>> _docs;
  
  _MockQuerySnapshot(List<DocumentSnapshot> docs) 
      : _docs = docs.map((doc) => _MockQueryDocumentSnapshot(doc.data() as Map<String, dynamic>)).toList();
  
  @override
  List<QueryDocumentSnapshot<Object?>> get docs => _docs;
  
  @override
  List<DocumentChange<Object?>> get docChanges => [];
  
  @override
  SnapshotMetadata get metadata => _MockSnapshotMetadata();
  
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _MockQueryDocumentSnapshot implements QueryDocumentSnapshot<Object?> {
  final Map<String, dynamic> _data;
  
  _MockQueryDocumentSnapshot(this._data);
  
  @override
  Map<String, dynamic> data() => _data;
  
  @override
  dynamic get(Object field) => _data[field.toString()];
  
  @override
  bool get exists => _data.isNotEmpty;
  
  @override
  String get id => _data['id'] ?? '';
  
  @override
  DocumentReference<Object?> get reference => _MockDocumentReference(id, 'collection');
  
  @override
  SnapshotMetadata get metadata => _MockSnapshotMetadata();
  
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _MockSnapshotMetadata implements SnapshotMetadata {
  @override
  bool get hasPendingWrites => false;
  
  @override
  bool get isFromCache => false;
}
