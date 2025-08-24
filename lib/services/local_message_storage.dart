import 'package:hive/hive.dart';


class LocalMessageStorage {
  static const String _messagesBoxName = 'local_messages';
  static const String _chatsBoxName = 'local_chats';
  
  static late Box<dynamic> _messagesBox;
  static late Box<dynamic> _chatsBox;
  
  /// Initialize local storage
  static Future<void> initialize() async {
    _messagesBox = await Hive.openBox(_messagesBoxName);
    _chatsBox = await Hive.openBox(_chatsBoxName);
    print('[LocalStorage] Initialized successfully');
  }

  /// Store message locally before deletion from Firestore
  static Future<void> storeMessageLocally({
    required String messageId,
    required String chatId,
    required Map<String, dynamic> messageData,
    required String userId,
  }) async {
    try {
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
      await _messagesBox.put(localKey, localMessageData);
      
      // Also store in chat-specific collection for easy retrieval
      final chatMessagesKey = '${chatId}_messages';
      List<Map<String, dynamic>> chatMessages = [];
      
      if (_messagesBox.containsKey(chatMessagesKey)) {
        final existing = _messagesBox.get(chatMessagesKey) as List;
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
      
      await _messagesBox.put(chatMessagesKey, chatMessages);
      
      print('[LocalStorage] Message stored locally: $localKey');
    } catch (e) {
      print('[LocalStorage] Error storing message locally: $e');
    }
  }

  /// Retrieve all local messages for a chat
  static List<Map<String, dynamic>> getLocalMessages(String chatId) {
    try {
      final chatMessagesKey = '${chatId}_messages';
      
      if (!_messagesBox.containsKey(chatMessagesKey)) {
        return [];
      }
      
      final messages = _messagesBox.get(chatMessagesKey) as List;
      return messages.cast<Map<String, dynamic>>();
    } catch (e) {
      print('[LocalStorage] Error retrieving local messages: $e');
      return [];
    }
  }

  /// Get a specific local message
  static Map<String, dynamic>? getLocalMessage(String messageId, String chatId, String userId) {
    try {
      final localKey = '${chatId}_${messageId}_$userId';
      return _messagesBox.get(localKey) as Map<String, dynamic>?;
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
      final localKey = '${chatId}_${messageId}_$userId';
      
      if (_messagesBox.containsKey(localKey)) {
        final messageData = _messagesBox.get(localKey) as Map<String, dynamic>;
        messageData['deliveredAt'] = DateTime.now().toIso8601String();
        messageData['isDelivered'] = true;
        
        await _messagesBox.put(localKey, messageData);
        
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
      final localKey = '${chatId}_${messageId}_$userId';
      
      if (_messagesBox.containsKey(localKey)) {
        final messageData = _messagesBox.get(localKey) as Map<String, dynamic>;
        messageData['readAt'] = DateTime.now().toIso8601String();
        messageData['isRead'] = true;
        
        await _messagesBox.put(localKey, messageData);
        
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
      final chatMessagesKey = '${chatId}_messages';
      
      if (_messagesBox.containsKey(chatMessagesKey)) {
        final messages = _messagesBox.get(chatMessagesKey) as List;
        final messageIndex = messages.indexWhere((msg) => 
          msg['messageId'] == messageId || msg['localKey']?.contains(messageId) == true
        );
        
        if (messageIndex != -1) {
          messages[messageIndex] = updatedMessage;
          _messagesBox.put(chatMessagesKey, messages);
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
      final chatKey = '${chatId}_$userId';
      await _chatsBox.put(chatKey, {
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
      final chatKey = '${chatId}_$userId';
      return _chatsBox.get(chatKey) as Map<String, dynamic>?;
    } catch (e) {
      print('[LocalStorage] Error retrieving local chat: $e');
      return null;
    }
  }

  /// Clean up old local messages (older than 30 days)
  static Future<void> cleanupOldLocalMessages() async {
    try {
      final thirtyDaysAgo = DateTime.now().subtract(const Duration(days: 30));
      int cleanedCount = 0;
      
      // Clean up individual messages
      final keysToRemove = <String>[];
      
      for (final key in _messagesBox.keys) {
        if (key is String && key.contains('_')) {
          try {
            final messageData = _messagesBox.get(key) as Map<String, dynamic>?;
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
        await _messagesBox.delete(key);
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
      return {
        'totalMessages': _messagesBox.length,
        'totalChats': _chatsBox.length,
        'messagesBoxSize': _messagesBox.length,
        'chatsBoxSize': _chatsBox.length,
      };
    } catch (e) {
      print('[LocalStorage] Error getting storage stats: $e');
      return {};
    }
  }

  /// Clear all local data (for testing or reset)
  static Future<void> clearAllData() async {
    try {
      await _messagesBox.clear();
      await _chatsBox.clear();
      print('[LocalStorage] All local data cleared');
    } catch (e) {
      print('[LocalStorage] Error clearing data: $e');
    }
  }

  /// Dispose resources
  static Future<void> dispose() async {
    await _messagesBox.close();
    await _chatsBox.close();
    print('[LocalStorage] Disposed');
  }
}
