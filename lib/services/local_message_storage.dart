import 'package:hive/hive.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';
import 'dart:convert';


class LocalMessageStorage {
  static const String _messagesBoxName = 'local_messages';
  static const String _chatsBoxName = 'local_chats';
  
  static Box<dynamic>? _messagesBox;
  static Box<dynamic>? _chatsBox;
  static bool _isInitialized = false;
  static bool _isInitializing = false;
  static bool _usePrefsFallback = false;

  static const String _prefsChatsPrefix = 'offline_chats_';
  static const String _prefsMessagesPrefix = 'offline_messages_';
  
  /// Initialize local storage
  /// For web, this is non-blocking with timeout to prevent page unresponsive errors
  static Future<void> initialize() async {
    if (_isInitialized || _isInitializing) {
      return;
    }
    
    _isInitializing = true;
    
    try {
      // For web, add timeout to prevent blocking
      if (kIsWeb) {
        await Future.any([
          _initializeHive(),
          Future.delayed(const Duration(seconds: 3)).then((_) {
            throw TimeoutException('Hive initialization timeout');
          }),
        ]);
      } else {
        await _initializeHive();
      }
      
      _isInitialized = true;
      print('[LocalStorage] Initialized successfully');
    } catch (e) {
      print('[LocalStorage] Initialization error (non-blocking): $e');
      // Fall back to SharedPreferences when Hive is unavailable (common on web)
      _usePrefsFallback = true;
      _isInitialized = true;
    } finally {
      _isInitializing = false;
    }
  }
  
  /// Internal Hive initialization
  static Future<void> _initializeHive() async {
    // Ensure Hive is initialized for Flutter platforms
    try {
      await Hive.initFlutter();
    } catch (_) {
      // If already initialized, ignore
    }
    
    _messagesBox = await Hive.openBox(_messagesBoxName);
    _chatsBox = await Hive.openBox(_chatsBoxName);
  }
  
  /// Ensure boxes are initialized before use
  static Future<void> _ensureInitialized() async {
    if (!_isInitialized && !_isInitializing) {
      await initialize();
    }
    // Wait for initialization to complete
    while (_isInitializing) {
      await Future.delayed(const Duration(milliseconds: 100));
    }
  }

  /// Store message locally before deletion from Firestore
  static Future<void> storeMessageLocally({
    required String messageId,
    required String chatId,
    required Map<String, dynamic> messageData,
    required String userId,
  }) async {
    try {
      await _ensureInitialized();
      if (_messagesBox == null) return;
      
      // Create local message key
      final localKey = '${chatId}_${messageId}_$userId';
      
      // Add local metadata
      final localMessageData = {
        ...messageData,
        'localKey': localKey,
        'storedAt': DateTime.now().toIso8601String(),
        'userId': userId,
        'isLocal': true,
      };

      // Store in local database
      await _messagesBox!.put(localKey, localMessageData);
      
      // Also store in chat-specific collection for easy retrieval
      final chatMessagesKey = '${chatId}_messages';
      List<Map<String, dynamic>> chatMessages = [];
      
      if (_messagesBox!.containsKey(chatMessagesKey)) {
        final existing = _messagesBox!.get(chatMessagesKey) as List;
        chatMessages = existing.cast<Map<String, dynamic>>();
      }
      
      // Add new message to chat
      chatMessages.add(localMessageData);
      
      // Sort by timestamp
      chatMessages.sort((a, b) {
        final aTime = DateTime.tryParse(a['timestamp'] ?? '') ?? DateTime.now();
        final bTime = DateTime.tryParse(b['timestamp'] ?? '') ?? DateTime.now();
        return aTime.compareTo(bTime);
      });
      
      await _messagesBox!.put(chatMessagesKey, chatMessages);
      
      print('[LocalStorage] Message stored locally: $localKey');
    } catch (e) {
      print('[LocalStorage] Error storing message locally: $e');
    }
  }

  /// Retrieve all local messages for a chat
  static List<Map<String, dynamic>> getLocalMessages(String chatId) {
    try {
      if (_messagesBox == null) return [];
      
      final chatMessagesKey = '${chatId}_messages';
      
      if (!_messagesBox!.containsKey(chatMessagesKey)) {
        return [];
      }
      
      final messages = _messagesBox!.get(chatMessagesKey) as List;
      return messages
          .map((m) => Map<String, dynamic>.from(m as Map))
          .toList();
    } catch (e) {
      print('[LocalStorage] Error retrieving local messages: $e');
      return [];
    }
  }

  /// Async version — ensures storage is ready before reading.
  static Future<List<Map<String, dynamic>>> getCachedChatMessages(String chatId) async {
    await _ensureInitialized();
    if (_messagesBox != null && !_usePrefsFallback) {
      return getLocalMessages(chatId);
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('$_prefsMessagesPrefix$chatId');
      if (raw == null) return [];
      final list = json.decode(raw) as List;
      return list.map((m) => Map<String, dynamic>.from(m as Map)).toList();
    } catch (e) {
      print('[LocalStorage] Error reading cached messages from prefs: $e');
      return [];
    }
  }

  /// Save the full message list for a chat (used after successful API fetch).
  static Future<void> saveChatMessagesList(
    String chatId,
    List<Map<String, dynamic>> messages,
  ) async {
    try {
      await _ensureInitialized();

      final serialized = messages
          .map((m) => Map<String, dynamic>.from(m))
          .toList();

      serialized.sort((a, b) {
        final aTime = _messageTimestamp(a);
        final bTime = _messageTimestamp(b);
        return aTime.compareTo(bTime);
      });

      if (_messagesBox != null && !_usePrefsFallback) {
        await _messagesBox!.put('${chatId}_messages', serialized);
      } else {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(
          '$_prefsMessagesPrefix$chatId',
          json.encode(serialized),
        );
      }
      print('[LocalStorage] Saved ${serialized.length} messages for chat $chatId');
    } catch (e) {
      print('[LocalStorage] Error saving chat messages list: $e');
    }
  }

  /// Add or update a single message in the cached chat list.
  static Future<void> upsertChatMessage(
    String chatId,
    Map<String, dynamic> message,
  ) async {
    try {
      await _ensureInitialized();
      if (_messagesBox == null || chatId.isEmpty) return;

      final messages = getLocalMessages(chatId);
      final messageId = _extractMessageId(message);
      if (messageId == null) return;

      final index = messages.indexWhere(
        (m) => _extractMessageId(m) == messageId,
      );

      final normalized = Map<String, dynamic>.from(message);
      if (index >= 0) {
        messages[index] = {...messages[index], ...normalized};
      } else {
        messages.add(normalized);
      }

      await saveChatMessagesList(chatId, messages);
    } catch (e) {
      print('[LocalStorage] Error upserting chat message: $e');
    }
  }

  /// Save all chats for a user (used after successful API fetch).
  static Future<void> saveChatsList(
    String userId,
    List<Map<String, dynamic>> chats,
  ) async {
    try {
      await _ensureInitialized();
      if (userId.isEmpty) return;

      final serialized = chats
          .map((c) => Map<String, dynamic>.from(c))
          .toList();

      if (_chatsBox != null && !_usePrefsFallback) {
        await _chatsBox!.put('chats_$userId', serialized);
        for (final chat in serialized) {
          final chatId = (chat['_id'] ?? chat['id'])?.toString();
          if (chatId != null && chatId.isNotEmpty) {
            await storeChatLocally(
              chatId: chatId,
              chatData: chat,
              userId: userId,
            );
          }
        }
      } else {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(
          '$_prefsChatsPrefix$userId',
          json.encode(serialized),
        );
      }

      print('[LocalStorage] Saved ${serialized.length} chats for user $userId');
    } catch (e) {
      print('[LocalStorage] Error saving chats list: $e');
    }
  }

  /// Get cached chats for a user.
  static Future<List<Map<String, dynamic>>> getCachedChats(String userId) async {
    try {
      await _ensureInitialized();
      if (userId.isEmpty) return [];

      if (_chatsBox != null && !_usePrefsFallback) {
        final data = _chatsBox!.get('chats_$userId');
        if (data is List) {
          return data
              .map((c) => Map<String, dynamic>.from(c as Map))
              .toList();
        }
        return [];
      }

      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('$_prefsChatsPrefix$userId');
      if (raw == null) return [];
      final list = json.decode(raw) as List;
      return list.map((c) => Map<String, dynamic>.from(c as Map)).toList();
    } catch (e) {
      print('[LocalStorage] Error retrieving cached chats: $e');
      return [];
    }
  }

  /// Update a single chat in the cached list (e.g. after realtime update).
  static Future<void> upsertChatInList(
    String userId,
    Map<String, dynamic> chat,
  ) async {
    try {
      final chatId = (chat['_id'] ?? chat['id'])?.toString();
      if (userId.isEmpty || chatId == null || chatId.isEmpty) return;

      final chats = await getCachedChats(userId);
      final index = chats.indexWhere(
        (c) => (c['_id'] ?? c['id'])?.toString() == chatId,
      );

      if (index >= 0) {
        chats[index] = {...chats[index], ...Map<String, dynamic>.from(chat)};
      } else {
        chats.add(Map<String, dynamic>.from(chat));
      }

      await saveChatsList(userId, chats);
    } catch (e) {
      print('[LocalStorage] Error upserting chat in list: $e');
    }
  }

  static String? _extractMessageId(Map<String, dynamic> message) {
    final id = message['id'] ?? message['_id'] ?? message['messageId'];
    if (id == null) return null;
    final s = id.toString();
    return s.isEmpty ? null : s;
  }

  static DateTime _messageTimestamp(Map<String, dynamic> message) {
    final raw = message['createdAt'] ??
        message['timestamp'] ??
        message['created_at'] ??
        message['time'];
    return DateTime.tryParse(raw?.toString() ?? '') ?? DateTime.fromMillisecondsSinceEpoch(0);
  }

  /// Get a specific local message
  static Map<String, dynamic>? getLocalMessage(String messageId, String chatId, String userId) {
    try {
      if (_messagesBox == null) return null;
      
      final localKey = '${chatId}_${messageId}_$userId';
      return _messagesBox!.get(localKey) as Map<String, dynamic>?;
    } catch (e) {
      print('[LocalStorage] Error retrieving local message: $e');
      return null;
    }
  }

  /// Mark message as delivered locally
  static Future<void> markMessageAsDeliveredLocally({
    required String messageId,
    required String chatId,
    required String userId,
  }) async {
    try {
      await _ensureInitialized();
      if (_messagesBox == null) return;
      
      final localKey = '${chatId}_${messageId}_$userId';
      
      if (_messagesBox!.containsKey(localKey)) {
        final messageData = _messagesBox!.get(localKey) as Map<String, dynamic>;
        messageData['deliveredAt'] = DateTime.now().toIso8601String();
        messageData['isDelivered'] = true;
        
        await _messagesBox!.put(localKey, messageData);
        
        // Update in chat messages list
        _updateMessageInChatList(chatId, messageId, messageData);
        
        print('[LocalStorage] Message marked as delivered locally: $localKey');
      }
    } catch (e) {
      print('[LocalStorage] Error marking message as delivered locally: $e');
    }
  }

  /// Mark message as read locally
  static Future<void> markMessageAsReadLocally({
    required String messageId,
    required String chatId,
    required String userId,
  }) async {
    try {
      await _ensureInitialized();
      if (_messagesBox == null) return;
      
      final localKey = '${chatId}_${messageId}_$userId';
      
      if (_messagesBox!.containsKey(localKey)) {
        final messageData = _messagesBox!.get(localKey) as Map<String, dynamic>;
        messageData['readAt'] = DateTime.now().toIso8601String();
        messageData['isRead'] = true;
        
        await _messagesBox!.put(localKey, messageData);
        
        // Update in chat messages list
        _updateMessageInChatList(chatId, messageId, messageData);
        
        print('[LocalStorage] Message marked as read locally: $localKey');
      }
    } catch (e) {
      print('[LocalStorage] Error marking message as read locally: $e');
    }
  }

  /// Update message in chat messages list
  static void _updateMessageInChatList(String chatId, String messageId, Map<String, dynamic> updatedMessage) {
    try {
      if (_messagesBox == null) return;
      
      final chatMessagesKey = '${chatId}_messages';
      
      if (_messagesBox!.containsKey(chatMessagesKey)) {
        final messages = _messagesBox!.get(chatMessagesKey) as List;
        final messageIndex = messages.indexWhere((msg) => 
          msg['messageId'] == messageId || msg['localKey']?.contains(messageId) == true
        );
        
        if (messageIndex != -1) {
          messages[messageIndex] = updatedMessage;
          _messagesBox!.put(chatMessagesKey, messages);
        }
      }
    } catch (e) {
      print('[LocalStorage] Error updating message in chat list: $e');
    }
  }

  /// Store chat metadata locally
  static Future<void> storeChatLocally({
    required String chatId,
    required Map<String, dynamic> chatData,
    required String userId,
  }) async {
    try {
      await _ensureInitialized();
      if (_chatsBox == null) return;
      
      final chatKey = '${chatId}_$userId';
      await _chatsBox!.put(chatKey, {
        ...chatData,
        'storedAt': DateTime.now().toIso8601String(),
        'userId': userId,
      });
      
      print('[LocalStorage] Chat stored locally: $chatKey');
    } catch (e) {
      print('[LocalStorage] Error storing chat locally: $e');
    }
  }

  /// Get local chat data
  static Map<String, dynamic>? getLocalChat(String chatId, String userId) {
    try {
      if (_chatsBox == null) return null;
      
      final chatKey = '${chatId}_$userId';
      return _chatsBox!.get(chatKey) as Map<String, dynamic>?;
    } catch (e) {
      print('[LocalStorage] Error retrieving local chat: $e');
      return null;
    }
  }

  /// Clean up old local messages (older than 30 days)
  static Future<void> cleanupOldLocalMessages() async {
    try {
      await _ensureInitialized();
      if (_messagesBox == null) return;
      
      final thirtyDaysAgo = DateTime.now().subtract(const Duration(days: 30));
      int cleanedCount = 0;
      
      // Clean up individual messages
      final keysToRemove = <String>[];
      
      for (final key in _messagesBox!.keys) {
        if (key is String && key.contains('_')) {
          try {
            final messageData = _messagesBox!.get(key) as Map<String, dynamic>?;
            if (messageData != null) {
              final storedAt = DateTime.tryParse(messageData['storedAt'] ?? '');
              if (storedAt != null && storedAt.isBefore(thirtyDaysAgo)) {
                keysToRemove.add(key);
              }
            }
          } catch (e) {
            // Skip corrupted entries
            keysToRemove.add(key);
          }
        }
      }
      
      for (final key in keysToRemove) {
        await _messagesBox!.delete(key);
        cleanedCount++;
      }
      
      print('[LocalStorage] Cleaned up $cleanedCount old local messages');
    } catch (e) {
      print('[LocalStorage] Error during cleanup: $e');
    }
  }

  /// Get storage statistics
  static Map<String, dynamic> getStorageStats() {
    try {
      if (_messagesBox == null || _chatsBox == null) {
        return {
          'totalMessages': 0,
          'totalChats': 0,
          'messagesBoxSize': 0,
          'chatsBoxSize': 0,
        };
      }
      
      return {
        'totalMessages': _messagesBox!.length,
        'totalChats': _chatsBox!.length,
        'messagesBoxSize': _messagesBox!.length,
        'chatsBoxSize': _chatsBox!.length,
      };
    } catch (e) {
      print('[LocalStorage] Error getting storage stats: $e');
      return {};
    }
  }

  /// Clear all local data (for testing or reset)
  static Future<void> clearAllData() async {
    try {
      await _ensureInitialized();
      if (_messagesBox != null) await _messagesBox!.clear();
      if (_chatsBox != null) await _chatsBox!.clear();
      print('[LocalStorage] All local data cleared');
    } catch (e) {
      print('[LocalStorage] Error clearing data: $e');
    }
  }

  /// Dispose resources
  static Future<void> dispose() async {
    try {
      if (_messagesBox != null) await _messagesBox!.close();
      if (_chatsBox != null) await _chatsBox!.close();
      print('[LocalStorage] Disposed');
    } catch (e) {
      print('[LocalStorage] Error disposing: $e');
    }
  }
}
