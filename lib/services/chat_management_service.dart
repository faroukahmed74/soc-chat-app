import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'unified_notification_service.dart';
import 'logger_service.dart';

/// Service for managing chat operations and migrations
class ChatManagementService {
  static final ChatManagementService _instance = ChatManagementService._internal();
  factory ChatManagementService() => _instance;
  ChatManagementService._internal();

  /// Fixes existing chats with missing user names
  /// This migration updates old chat documents to include otherUserName field
  static Future<void> fixMissingUserNames() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;
    
    print('[ChatManagement] Starting migration to fix missing user names...');
    
    try {
      final chatsSnap = await FirebaseFirestore.instance.collection('chats')
        .where('isGroup', isEqualTo: false)
        .where('members', arrayContains: currentUser.uid)
        .get();
      
      int updatedCount = 0;
      for (final chatDoc in chatsSnap.docs) {
        final data = chatDoc.data();
        final members = List<String>.from(data['members'] ?? []);
        
        // Skip if already has otherUserName
        if (data['otherUserName'] != null) continue;
        
        // Get the other user's ID
        final otherUserId = members.firstWhere((id) => id != currentUser.uid);
        
        try {
          // Fetch the other user's data
          final userDoc = await FirebaseFirestore.instance.collection('users').doc(otherUserId).get();
          if (userDoc.exists) {
            final userData = userDoc.data()!;
            final otherUserName = userData['username'] ?? userData['email'] ?? 'Unknown User';
            
            // Update the chat document
            await FirebaseFirestore.instance.collection('chats').doc(chatDoc.id).update({
              'otherUserName': otherUserName,
              'otherUserId': otherUserId,
            });
            
            updatedCount++;
            print('[ChatManagement] Updated chat ${chatDoc.id} with user name: $otherUserName');
          }
        } catch (e) {
          print('[ChatManagement] Error updating chat ${chatDoc.id}: $e');
        }
      }
      
      print('[ChatManagement] Migration complete: updated $updatedCount chats with user names.');
    } catch (e) {
      print('[ChatManagement] Error during migration: $e');
      rethrow;
    }
  }

  /// Gets the display name for a chat
  /// This handles both group chats and private chats
  static String getChatDisplayName(Map<String, dynamic> chatData, String currentUserId) {
    final isGroup = chatData['isGroup'] ?? false;
    
    if (isGroup) {
      return chatData['groupName'] ?? 'Group Chat';
    } else {
      // For private chats, return the other user's name
      return chatData['otherUserName'] ?? 'Unknown User';
    }
  }

  /// Updates chat metadata when a new message is sent
  static Future<void> updateChatMetadata(String chatId, String message, String senderName) async {
    try {
      await FirebaseFirestore.instance.collection('chats').doc(chatId).update({
        'lastMessage': message,
        'lastMessageTime': FieldValue.serverTimestamp(),
        'lastMessageSender': senderName,
      });
    } catch (e) {
      print('[ChatManagement] Error updating chat metadata: $e');
    }
  }

  /// Sends a message to a chat
  static Future<String?> sendMessage({
    required String chatId,
    required String text,
    required String senderId,
    required String senderName,
    String type = 'text',
    Map<String, dynamic>? additionalData,
  }) async {
    try {
      // Create message data
      final messageData = {
        'text': text,
        'senderId': senderId,
        'senderName': senderName,
        'timestamp': FieldValue.serverTimestamp(),
        'type': type,
        'isPinned': false,
        'reactions': {},
        ...?additionalData,
      };

      // Add message to Firestore
      final messageRef = await FirebaseFirestore.instance
          .collection('chats')
          .doc(chatId)
          .collection('messages')
          .add(messageData);

      // Update chat metadata
      await updateChatMetadata(chatId, text, senderName);

      // Send FCM notification to chat participants
      await _sendChatNotification(chatId, text, senderName, type);

      Log.i('Message sent successfully: ${messageRef.id}', 'CHAT_MANAGEMENT');
      return messageRef.id;
    } catch (e) {
      Log.e('Error sending message', 'CHAT_MANAGEMENT', e);
      return null;
    }
  }

  /// Sends FCM notification to chat participants
  static Future<void> _sendChatNotification(
    String chatId,
    String message,
    String senderName,
    String messageType,
  ) async {
    try {
      // Get chat data to determine if it's a group or private chat
      final chatDoc = await FirebaseFirestore.instance.collection('chats').doc(chatId).get();
      if (!chatDoc.exists) return;

      final chatData = chatDoc.data()!;
      final isGroup = chatData['isGroup'] ?? false;
      final members = List<String>.from(chatData['members'] ?? []);
      final currentUser = FirebaseAuth.instance.currentUser;

      if (currentUser == null) return;

      // Remove current user from notification recipients
      final recipients = members.where((id) => id != currentUser.uid).toList();
      if (recipients.isEmpty) return;

      // Prepare notification data
      final notificationData = {
        'chatId': chatId,
        'chatType': isGroup ? 'group' : 'private',
        'senderId': currentUser.uid,
        'senderName': senderName,
        'messageType': messageType,
        'timestamp': DateTime.now().toIso8601String(),
      };

      if (isGroup) {
        // For group chats, send to topic
        final topic = 'chat_$chatId';
        await UnifiedNotificationService().sendBroadcastNotification(
          title: '💬 $senderName in ${chatData['groupName'] ?? 'Group'}',
          body: _truncateMessage(message),
          senderId: currentUser.uid,
          senderName: senderName,
          messageType: messageType,
        );
        Log.i('Group notification sent to topic: $topic', 'CHAT_MANAGEMENT');
      } else {
        // For private chats, send to individual users
        await _sendPrivateChatNotifications(recipients, senderName, message, notificationData);
      }
    } catch (e) {
      Log.e('Error sending chat notification', 'CHAT_MANAGEMENT', e);
    }
  }

  /// Sends notifications to individual users in private chats
  static Future<void> _sendPrivateChatNotifications(
    List<String> recipientIds,
    String senderName,
    String message,
    Map<String, dynamic> notificationData,
  ) async {
    try {
      // Get FCM tokens for recipients
      final tokens = <String>[];
      for (final userId in recipientIds) {
        final userDoc = await FirebaseFirestore.instance.collection('users').doc(userId).get();
        if (userDoc.exists) {
          final userData = userDoc.data()!;
          final fcmToken = userData['fcmToken'];
          if (fcmToken != null && fcmToken.isNotEmpty) {
            tokens.add(fcmToken);
          }
        }
      }

      if (tokens.isEmpty) {
        Log.w('No FCM tokens found for recipients', 'CHAT_MANAGEMENT');
        return;
      }

      // Send individual notifications
      for (final token in tokens) {
        await UnifiedNotificationService().sendFcmNotification(
          title: senderName,
          body: _truncateMessage(message),
          tokens: [token],
          data: notificationData,
        );
      }

      Log.i('Private chat notifications sent to ${tokens.length} recipients', 'CHAT_MANAGEMENT');
    } catch (e) {
      Log.e('Error sending private chat notifications', 'CHAT_MANAGEMENT', e);
    }
  }

  /// Truncates message for notification display
  static String _truncateMessage(String message) {
    if (message.length <= 50) return message;
    return '${message.substring(0, 47)}...';
  }
}
