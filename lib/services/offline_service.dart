// =============================================================================
// OFFLINE SERVICE
// =============================================================================
// This service provides comprehensive offline functionality for the SOC Chat App.
// It handles offline messaging, media storage, user caching, and sync management.
//
// KEY FEATURES:
// - Offline message composition and storage
// - Local media file management
// - User profile caching
// - Chat history offline access
// - Smart sync when connection returns
// - Conflict resolution for data conflicts
//
// ARCHITECTURE:
// - Uses Hive for local database storage
// - Implements queue system for offline actions
// - Provides real-time connectivity monitoring
// - Handles data synchronization efficiently

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:firebase_storage/firebase_storage.dart';
import 'logger_service.dart';

class OfflineService {
  static final OfflineService _instance = OfflineService._internal();
  factory OfflineService() => _instance;
  OfflineService._internal();

  // Hive boxes for different data types
  late Box<String> _messagesBox;
  late Box<String> _usersBox;
  late Box<String> _chatsBox;
  late Box<String> _mediaBox;
  late Box<String> _syncQueueBox;
  late Box<String> _settingsBox;
  
  // Offline status
  bool _isOnline = true;
  bool _isInitialized = false;
  
  // Sync management
  List<Map<String, dynamic>> _syncQueue = [];
  bool _isSyncing = false;
  
  // Callbacks for connectivity changes
  final List<Function(bool)> _connectivityListeners = [];
  
  /// Initialize the offline service
  Future<void> initialize() async {
    if (_isInitialized) return;
    
    try {
      // Initialize Hive
      await Hive.initFlutter();
      
      // Open Hive boxes
      _messagesBox = await Hive.openBox<String>('offline_messages');
      _usersBox = await Hive.openBox<String>('offline_users');
      _chatsBox = await Hive.openBox<String>('offline_chats');
      _mediaBox = await Hive.openBox<String>('offline_media');
      _syncQueueBox = await Hive.openBox<String>('sync_queue');
      _settingsBox = await Hive.openBox<String>('offline_settings');
      
      // Load sync queue from storage
      await _loadSyncQueue();
      
      // Start connectivity monitoring
      _startConnectivityMonitoring();
      
      _isInitialized = true;
      Log.i('Initialized successfully', 'OFFLINE_SERVICE');
    } catch (e) {
      Log.e('Initialization error', 'OFFLINE_SERVICE', e);
    }
  }
  
  /// Check if the service is initialized
  bool get isInitialized => _isInitialized;
  
  /// Get current online status
  bool get isOnline => _isOnline;
  
  /// Add connectivity listener
  void addConnectivityListener(Function(bool) listener) {
    _connectivityListeners.add(listener);
  }
  
  /// Remove connectivity listener
  void removeConnectivityListener(Function(bool) listener) {
    _connectivityListeners.remove(listener);
  }
  
  /// Start monitoring connectivity
  void _startConnectivityMonitoring() {
    // Check connectivity every 5 seconds
    Timer.periodic(const Duration(seconds: 5), (timer) async {
      final wasOnline = _isOnline;
      _isOnline = await _checkConnectivity();
      
      if (wasOnline != _isOnline) {
        _notifyConnectivityListeners(_isOnline);
        
        if (_isOnline && _syncQueue.isNotEmpty) {
          // Connection restored, start syncing
          _startSync();
        }
      }
    });
  }
  
  /// Check internet connectivity
  Future<bool> _checkConnectivity() async {
    try {
      final result = await InternetAddress.lookup('google.com');
      return result.isNotEmpty && result[0].rawAddress.isNotEmpty;
    } catch (e) {
      return false;
    }
  }
  
  /// Notify connectivity listeners
  void _notifyConnectivityListeners(bool isOnline) {
    for (final listener in _connectivityListeners) {
      try {
        listener(isOnline);
      } catch (e) {
        Log.e('Error notifying listener', 'OFFLINE_SERVICE', e);
      }
    }
  }
  
  // =============================================================================
  // OFFLINE MESSAGING
  // =============================================================================
  
  /// Save message offline
  Future<void> saveMessageOffline(Map<String, dynamic> messageData) async {
    if (!_isInitialized) return;
    
    try {
      final messageId = messageData['messageId'] ?? DateTime.now().millisecondsSinceEpoch.toString();
      final chatId = messageData['chatId'];
      
      // Save message to local storage
      await _messagesBox.put('${chatId}_$messageId', jsonEncode(messageData));
      
      // Add to sync queue
      await _addToSyncQueue('message', messageData);
      
      Log.i('Message saved offline: $messageId', 'OFFLINE_SERVICE');
    } catch (e) {
      Log.e('Error saving message offline', 'OFFLINE_SERVICE', e);
    }
  }
  
  /// Get offline messages for a chat
  List<Map<String, dynamic>> getOfflineMessages(String chatId) {
    if (!_isInitialized) return [];
    
    try {
      final messages = <Map<String, dynamic>>[];
      
      for (final key in _messagesBox.keys) {
        if (key.toString().startsWith('${chatId}_')) {
          final messageData = jsonDecode(_messagesBox.get(key)!);
          messages.add(messageData);
        }
      }
      
      // Sort by timestamp
      messages.sort((a, b) {
        final aTime = a['timestamp'] ?? 0;
        final bTime = b['timestamp'] ?? 0;
        return aTime.compareTo(bTime);
      });
      
      return messages;
    } catch (e) {
      Log.e('Error getting offline messages', 'OFFLINE_SERVICE', e);
      return [];
    }
  }
  
  /// Delete offline message
  Future<void> deleteOfflineMessage(String chatId, String messageId) async {
    if (!_isInitialized) return;
    
    try {
      await _messagesBox.delete('${chatId}_$messageId');
      Log.i('Offline message deleted: $messageId', 'OFFLINE_SERVICE');
    } catch (e) {
      Log.e('Error deleting offline message', 'OFFLINE_SERVICE', e);
    }
  }
  
  // =============================================================================
  // OFFLINE USER MANAGEMENT
  // =============================================================================
  
  /// Cache user profile offline
  Future<void> cacheUserOffline(Map<String, dynamic> userData) async {
    if (!_isInitialized) return;
    
    try {
      final userId = userData['userId'];
      await _usersBox.put(userId, jsonEncode(userData));
      Log.i('User cached offline: $userId', 'OFFLINE_SERVICE');
    } catch (e) {
      Log.e('Error caching user offline', 'OFFLINE_SERVICE', e);
    }
  }
  
  /// Get cached user profile
  Map<String, dynamic>? getCachedUser(String userId) {
    if (!_isInitialized) return null;
    
    try {
      final userData = _usersBox.get(userId);
      if (userData != null) {
        return jsonDecode(userData);
      }
    } catch (e) {
      Log.e('Error getting cached user', 'OFFLINE_SERVICE', e);
    }
    return null;
  }
  
  /// Get all cached users
  List<Map<String, dynamic>> getAllCachedUsers() {
    if (!_isInitialized) return [];
    
    try {
      final users = <Map<String, dynamic>>[];
      
      for (final key in _usersBox.keys) {
        final userData = jsonDecode(_usersBox.get(key)!);
        users.add(userData);
      }
      
      return users;
    } catch (e) {
      Log.e('Error getting cached users', 'OFFLINE_SERVICE', e);
      return [];
    }
  }
  
  /// Search cached users
  List<Map<String, dynamic>> searchCachedUsers(String query) {
    if (!_isInitialized) return [];
    
    try {
      final users = getAllCachedUsers();
      final queryLower = query.toLowerCase();
      
      return users.where((user) {
        final name = (user['displayName'] ?? '').toString().toLowerCase();
        final email = (user['email'] ?? '').toString().toLowerCase();
        return name.contains(queryLower) || email.contains(queryLower);
      }).toList();
    } catch (e) {
      Log.e('Error searching cached users', 'OFFLINE_SERVICE', e);
      return [];
    }
  }
  
  // =============================================================================
  // OFFLINE CHAT MANAGEMENT
  // =============================================================================
  
  /// Cache chat data offline
  Future<void> cacheChatOffline(Map<String, dynamic> chatData) async {
    if (!_isInitialized) return;
    
    try {
      final chatId = chatData['chatId'];
      await _chatsBox.put(chatId, jsonEncode(chatData));
      Log.i('Chat cached offline: $chatId', 'OFFLINE_SERVICE');
    } catch (e) {
      Log.e('Error caching chat offline', 'OFFLINE_SERVICE', e);
    }
  }
  
  /// Get cached chat data
  Map<String, dynamic>? getCachedChat(String chatId) {
    if (!_isInitialized) return null;
    
    try {
      final chatData = _chatsBox.get(chatId);
      if (chatData != null) {
        return jsonDecode(chatData);
      }
    } catch (e) {
      Log.e('Error getting cached chat', 'OFFLINE_SERVICE', e);
    }
    return null;
  }
  
  /// Get all cached chats
  List<Map<String, dynamic>> getAllCachedChats() {
    if (!_isInitialized) return [];
    
    try {
      final chats = <Map<String, dynamic>>[];
      
      for (final key in _chatsBox.keys) {
        final chatData = jsonDecode(_chatsBox.get(key)!);
        chats.add(chatData);
      }
      
      return chats;
    } catch (e) {
      Log.e('Error getting cached chats', 'OFFLINE_SERVICE', e);
      return [];
    }
  }
  
  // =============================================================================
  // OFFLINE MEDIA MANAGEMENT
  // =============================================================================
  
  /// Save media file offline
  Future<String?> saveMediaOffline(Uint8List fileBytes, String fileName, String fileType) async {
    if (!_isInitialized) return null;
    
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final offlineDir = Directory('${appDir.path}/offline_media');
      
      if (!await offlineDir.exists()) {
        await offlineDir.create(recursive: true);
      }
      
      final filePath = '${offlineDir.path}/$fileName';
      final file = File(filePath);
      await file.writeAsBytes(fileBytes);
      
      // Save metadata
      final metadata = {
        'fileName': fileName,
        'filePath': filePath,
        'fileType': fileType,
        'fileSize': fileBytes.length,
        'savedAt': DateTime.now().toIso8601String(),
      };
      
      await _mediaBox.put(fileName, jsonEncode(metadata));
      
      Log.i('Media saved offline: $fileName', 'OFFLINE_SERVICE');
      return filePath;
    } catch (e) {
      Log.e('Error saving media offline', 'OFFLINE_SERVICE', e);
      return null;
    }
  }
  
  /// Get offline media file
  Future<File?> getOfflineMedia(String fileName) async {
    if (!_isInitialized) return null;
    
    try {
      final metadata = _mediaBox.get(fileName);
      if (metadata != null) {
        final data = jsonDecode(metadata);
        final filePath = data['filePath'];
        final file = File(filePath);
        
        if (await file.exists()) {
          return file;
        }
      }
    } catch (e) {
      Log.e('Error getting offline media', 'OFFLINE_SERVICE', e);
    }
    return null;
  }
  
  /// Get all offline media
  List<Map<String, dynamic>> getAllOfflineMedia() {
    if (!_isInitialized) return [];
    
    try {
      final media = <Map<String, dynamic>>[];
      
      for (final key in _mediaBox.keys) {
        final metadata = jsonDecode(_mediaBox.get(key)!);
        media.add(metadata);
      }
      
      return media;
    } catch (e) {
      Log.e('Error getting offline media', 'OFFLINE_SERVICE', e);
      return [];
    }
  }
  
  /// Delete offline media
  Future<void> deleteOfflineMedia(String fileName) async {
    if (!_isInitialized) return;
    
    try {
      final metadata = _mediaBox.get(fileName);
      if (metadata != null) {
        final data = jsonDecode(metadata);
        final filePath = data['filePath'];
        
        // Delete file
        final file = File(filePath);
        if (await file.exists()) {
          await file.delete();
        }
        
        // Delete metadata
        await _mediaBox.delete(fileName);
        
        Log.i('Offline media deleted: $fileName', 'OFFLINE_SERVICE');
      }
    } catch (e) {
      Log.e('Error deleting offline media', 'OFFLINE_SERVICE', e);
    }
  }
  
  // =============================================================================
  // SYNC MANAGEMENT
  // =============================================================================
  
  /// Add action to sync queue
  Future<void> _addToSyncQueue(String actionType, Map<String, dynamic> data) async {
    if (!_isInitialized) return;
    
    try {
      final queueItem = {
        'id': DateTime.now().millisecondsSinceEpoch.toString(),
        'actionType': actionType,
        'data': data,
        'timestamp': DateTime.now().toIso8601String(),
        'retryCount': 0,
        'maxRetries': 3,
      };
      
      _syncQueue.add(queueItem);
      await _saveSyncQueue();
      
      Log.i('Added to sync queue: $actionType', 'OFFLINE_SERVICE');
    } catch (e) {
      Log.e('Error adding to sync queue', 'OFFLINE_SERVICE', e);
    }
  }
  
  /// Load sync queue from storage
  Future<void> _loadSyncQueue() async {
    try {
      final queueData = _syncQueueBox.get('sync_queue');
      if (queueData != null) {
        _syncQueue = List<Map<String, dynamic>>.from(jsonDecode(queueData));
      }
    } catch (e) {
      Log.e('Error loading sync queue', 'OFFLINE_SERVICE', e);
    }
  }
  
  /// Save sync queue to storage
  Future<void> _saveSyncQueue() async {
    try {
      await _syncQueueBox.put('sync_queue', jsonEncode(_syncQueue));
    } catch (e) {
      Log.e('Error saving sync queue', 'OFFLINE_SERVICE', e);
    }
  }
  
  /// Start syncing when online
  Future<void> _startSync() async {
    if (_isSyncing || _syncQueue.isEmpty) return;
    
    _isSyncing = true;
    Log.i('Starting sync process...', 'OFFLINE_SERVICE');
    
    try {
      final itemsToSync = List<Map<String, dynamic>>.from(_syncQueue);
      
      for (final item in itemsToSync) {
        try {
          await _processSyncItem(item);
          
          // Remove successful item from queue
          _syncQueue.removeWhere((element) => element['id'] == item['id']);
        } catch (e) {
          // Increment retry count
          final index = _syncQueue.indexWhere((element) => element['id'] == item['id']);
          if (index != -1) {
            _syncQueue[index]['retryCount'] = (_syncQueue[index]['retryCount'] ?? 0) + 1;
            
            // Remove item if max retries reached
            if (_syncQueue[index]['retryCount'] >= _syncQueue[index]['maxRetries']) {
              _syncQueue.removeAt(index);
              Log.w('Max retries reached for sync item: ${item['id']}', 'OFFLINE_SERVICE');
            }
          }
        }
      }
      
      await _saveSyncQueue();
      Log.i('Sync process completed', 'OFFLINE_SERVICE');
    } catch (e) {
      Log.e('Error during sync', 'OFFLINE_SERVICE', e);
    } finally {
      _isSyncing = false;
    }
  }
  
  /// Process individual sync item
  Future<void> _processSyncItem(Map<String, dynamic> item) async {
    final actionType = item['actionType'];
    final data = item['data'];
    
    switch (actionType) {
      case 'message':
        await _syncMessage(data);
        break;
      case 'user_update':
        await _syncUserUpdate(data);
        break;
      case 'chat_update':
        await _syncChatUpdate(data);
        break;
      case 'media_upload':
        await _syncMediaUpload(data);
        break;
      default:
        Log.w('Unknown sync action: $actionType', 'OFFLINE_SERVICE');
    }
  }
  
  /// Sync offline message
  Future<void> _syncMessage(Map<String, dynamic> messageData) async {
    try {
      final chatId = messageData['chatId'];
      final messageId = messageData['messageId'];
      
      // Upload to Firestore
      await FirebaseFirestore.instance
          .collection('chats')
          .doc(chatId)
          .collection('messages')
          .doc(messageId)
          .set(messageData);
      
      Log.i('Message synced: $messageId', 'OFFLINE_SERVICE');
    } catch (e) {
      Log.e('Error syncing message', 'OFFLINE_SERVICE', e);
      throw e;
    }
  }
  
  /// Sync user update
  Future<void> _syncUserUpdate(Map<String, dynamic> userData) async {
    try {
      final userId = userData['userId'];
      
      // Update user in Firestore
      await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .update(userData);
      
      Log.i('User update synced: $userId', 'OFFLINE_SERVICE');
    } catch (e) {
      Log.e('Error syncing user update', 'OFFLINE_SERVICE', e);
      throw e;
    }
  }
  
  /// Sync chat update
  Future<void> _syncChatUpdate(Map<String, dynamic> chatData) async {
    try {
      final chatId = chatData['chatId'];
      
      // Update chat in Firestore
      await FirebaseFirestore.instance
          .collection('chats')
          .doc(chatId)
          .update(chatData);
      
      Log.i('Chat update synced: $chatId', 'OFFLINE_SERVICE');
    } catch (e) {
      Log.e('Error syncing chat update', 'OFFLINE_SERVICE', e);
      throw e;
    }
  }
  
  /// Sync media upload
  Future<void> _syncMediaUpload(Map<String, dynamic> mediaData) async {
    try {
      final fileName = mediaData['fileName'];
      final filePath = mediaData['filePath'];
      final fileType = mediaData['fileType'];
      
      // Upload to Firebase Storage
      final file = File(filePath);
      if (await file.exists()) {
        final storageRef = FirebaseStorage.instance.ref().child('chat_media/$fileName');
        await storageRef.putFile(file);
        
        // Get download URL
        final downloadUrl = await storageRef.getDownloadURL();
        
        // Update message with media URL
        final messageId = mediaData['messageId'];
        final chatId = mediaData['chatId'];
        
        await FirebaseFirestore.instance
            .collection('chats')
            .doc(chatId)
            .collection('messages')
            .doc(messageId)
            .update({
          'mediaUrl': downloadUrl,
          'mediaType': fileType,
          'synced': true,
        });
        
        Log.i('Media synced: $fileName', 'OFFLINE_SERVICE');
      }
    } catch (e) {
      Log.e('Error syncing media', 'OFFLINE_SERVICE', e);
      throw e;
    }
  }
  
  // =============================================================================
  // OFFLINE SETTINGS
  // =============================================================================
  
  /// Save setting offline
  Future<void> saveSettingOffline(String key, dynamic value) async {
    if (!_isInitialized) return;
    
    try {
      await _settingsBox.put(key, jsonEncode(value));
      Log.i('Setting saved offline: $key', 'OFFLINE_SERVICE');
    } catch (e) {
      Log.e('Error saving setting offline', 'OFFLINE_SERVICE', e);
    }
  }
  
  /// Get offline setting
  dynamic getOfflineSetting(String key) {
    if (!_isInitialized) return null;
    
    try {
      final value = _settingsBox.get(key);
      if (value != null) {
        return jsonDecode(value);
      }
    } catch (e) {
      Log.e('Error getting offline setting', 'OFFLINE_SERVICE', e);
    }
    return null;
  }
  
  // =============================================================================
  // UTILITY METHODS
  // =============================================================================
  
  /// Get offline storage statistics
  Map<String, dynamic> getOfflineStats() {
    if (!_isInitialized) return {};
    
    try {
      return {
        'messages': _messagesBox.length,
        'users': _usersBox.length,
        'chats': _chatsBox.length,
        'media': _mediaBox.length,
        'syncQueue': _syncQueue.length,
        'settings': _settingsBox.length,
        'isOnline': _isOnline,
        'isSyncing': _isSyncing,
      };
    } catch (e) {
      Log.e('Error getting offline stats', 'OFFLINE_SERVICE', e);
      return {};
    }
  }
  
  /// Clear all offline data
  Future<void> clearAllOfflineData() async {
    if (!_isInitialized) return;
    
    try {
      await _messagesBox.clear();
      await _usersBox.clear();
      await _chatsBox.clear();
      await _mediaBox.clear();
      await _syncQueueBox.clear();
      await _settingsBox.clear();
      
      _syncQueue.clear();
      
      Log.i('All offline data cleared', 'OFFLINE_SERVICE');
    } catch (e) {
      Log.e('Error clearing offline data', 'OFFLINE_SERVICE', e);
    }
  }
  
  /// Dispose the service
  Future<void> dispose() async {
    try {
      await _messagesBox.close();
      await _usersBox.close();
      await _chatsBox.close();
      await _mediaBox.close();
      await _syncQueueBox.close();
      await _settingsBox.close();
      
      _isInitialized = false;
      Log.i('Disposed successfully', 'OFFLINE_SERVICE');
    } catch (e) {
      Log.e('Error disposing', 'OFFLINE_SERVICE', e);
    }
  }
}
