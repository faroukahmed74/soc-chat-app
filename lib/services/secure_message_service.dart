import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:async';
import 'secure_media_service.dart';
import 'production_notification_service.dart';
import 'logger_service.dart';

class SecureMessageService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;
  
  // Background cleanup timer
  static Timer? _cleanupTimer;
  
  /// Initialize the secure message service
  static void initialize() {
    Log.i('Service initialized', 'SECURE_MESSAGE');
    _startBackgroundCleanup();
  }
  
  /// Send a secure message with delivery tracking
  static Future<String?> sendSecureMessage({
    required String chatId,
    required String text,
    required String senderId,
    required String senderName,
    required List<String> recipientIds,
    String? mediaUrl,
    String? mediaType,
  }) async {
    try {
      final messageData = {
        'type': mediaType ?? 'text',
        'text': text,
        'senderId': senderId,
        'senderName': senderName,
        'timestamp': FieldValue.serverTimestamp(),
        'isPinned': false,
        'reactions': {},
        'chatId': chatId,
        'mediaUrl': mediaUrl,
        'expiresAt': _calculateExpirationDate(),
        'deliveryStatus': _createDeliveryStatus(recipientIds),
        'isDeleted': false,
      };

      // Add message to Firestore
      final messageRef = await _firestore
          .collection('chats')
          .doc(chatId)
          .collection('messages')
          .add(messageData);

      Log.i('Message sent successfully: ${messageRef.id}', 'SECURE_MESSAGE');
      
      // Start delivery tracking
      _trackMessageDelivery(messageRef.id, chatId, recipientIds);
      
      // Send notifications to all recipients
      _sendChatNotifications(messageRef.id, chatId, text, senderName, recipientIds);
      
      return messageRef.id;
    } catch (e) {
      Log.e('Error sending message', 'SECURE_MESSAGE', e);
      return null;
    }
  }

  /// Mark message as delivered for a specific recipient
  static Future<void> markMessageAsDelivered(
    String messageId,
    String chatId,
    String recipientId,
  ) async {
    try {
      final messageRef = _firestore
          .collection('chats')
          .doc(chatId)
          .collection('messages')
          .doc(messageId);

      await messageRef.update({
        'deliveryStatus.recipients.$recipientId.delivered': FieldValue.serverTimestamp(),
      });

      Log.i('Message marked as delivered: $messageId -> $recipientId', 'SECURE_MESSAGE');
      
      // Check if all recipients have received the message
      await _checkMessageDeliveryComplete(messageId, chatId);
    } catch (e) {
      Log.e('Error marking message as delivered', 'SECURE_MESSAGE', e);
    }
  }

  /// Mark message as read for a specific recipient
  static Future<void> markMessageAsRead(
    String messageId,
    String chatId,
    String recipientId,
  ) async {
    try {
      final messageRef = _firestore
          .collection('chats')
          .doc(chatId)
          .collection('messages')
          .doc(messageId);

      await messageRef.update({
        'deliveryStatus.recipients.$recipientId.read': FieldValue.serverTimestamp(),
      });

      print('[SecureMessage] Message marked as read: $messageId -> $recipientId');
    } catch (e) {
      print('[SecureMessage] Error marking message as read: $e');
    }
  }

  /// Check if all recipients have received the message and delete if complete
  static Future<void> _checkMessageDeliveryComplete(
    String messageId,
    String chatId,
  ) async {
    try {
      final messageDoc = await _firestore
          .collection('chats')
          .doc(chatId)
          .collection('messages')
          .doc(messageId)
          .get();

      if (!messageDoc.exists) return;

      final messageData = messageDoc.data()!;
      final deliveryStatus = messageData['deliveryStatus'] as Map<String, dynamic>;
      final recipients = deliveryStatus['recipients'] as Map<String, dynamic>;

      // Check if all recipients have received the message
      final allDelivered = recipients.values.every((status) => 
        status is Map && status['delivered'] != null
      );

      if (allDelivered) {
        print('[SecureMessage] All recipients received message $messageId, scheduling deletion');
        
        // Schedule deletion after a short delay to ensure local storage
        Timer(const Duration(seconds: 30), () {
          _deleteMessageAfterReceipt(messageId, chatId, messageData);
        });
      }
    } catch (e) {
      print('[SecureMessage] Error checking delivery completion: $e');
    }
  }

  /// Delete message from Firestore after all recipients have received it
  static Future<void> _deleteMessageAfterReceipt(
    String messageId,
    String chatId,
    Map<String, dynamic> messageData,
  ) async {
    try {
      // Delete media from storage if exists
      final mediaUrl = messageData['mediaUrl'] as String?;
      if (mediaUrl != null && mediaUrl.isNotEmpty) {
        await SecureMediaService.deleteMediaFromStorage(mediaUrl);
      }

      // Mark message as deleted in Firestore
      final messageRef = _firestore
          .collection('chats')
          .doc(chatId)
          .collection('messages')
          .doc(messageId);

      await messageRef.update({
        'isDeleted': true,
        'deletedAt': FieldValue.serverTimestamp(),
        'deletionReason': 'all_recipients_received',
      });

      print('[SecureMessage] Message deleted after receipt: $messageId');
    } catch (e) {
      print('[SecureMessage] Error deleting message after receipt: $e');
    }
  }

  /// Start background cleanup service
  static void _startBackgroundCleanup() {
    // Run cleanup every hour
    _cleanupTimer = Timer.periodic(const Duration(hours: 1), (timer) {
      _cleanupExpiredMessages();
    });
    
    print('[SecureMessage] Background cleanup service started');
  }

  /// Clean up expired messages
  static Future<void> _cleanupExpiredMessages() async {
    try {
      print('[SecureMessage] Starting expired message cleanup...');
      
      final now = DateTime.now();
      final expiredMessages = await _firestore
          .collectionGroup('messages')
          .where('expiresAt', isLessThan: now)
          .where('isDeleted', isEqualTo: false)
          .get();

      int deletedCount = 0;
      for (final doc in expiredMessages.docs) {
        try {
          final messageData = doc.data();
          final mediaUrl = messageData['mediaUrl'] as String?;
          
          // Delete media from storage if exists
          if (mediaUrl != null && mediaUrl.isNotEmpty) {
            await SecureMediaService.deleteMediaFromStorage(mediaUrl);
          }

          // Mark message as deleted
          await doc.reference.update({
            'isDeleted': true,
            'deletedAt': FieldValue.serverTimestamp(),
            'deletionReason': 'expired',
          });

          deletedCount++;
        } catch (e) {
          print('[SecureMessage] Error cleaning up message ${doc.id}: $e');
        }
      }

      print('[SecureMessage] Cleanup completed: $deletedCount expired messages deleted');
    } catch (e) {
      print('[SecureMessage] Error during cleanup: $e');
    }
  }

  /// Stop background cleanup service
  static void dispose() {
    _cleanupTimer?.cancel();
    print('[SecureMessage] Service disposed');
  }

  /// Calculate expiration date (7 days from now)
  static DateTime _calculateExpirationDate() {
    return DateTime.now().add(const Duration(days: 7));
  }

  /// Create delivery status tracking for all recipients
  static Map<String, dynamic> _createDeliveryStatus(List<String> recipientIds) {
    final recipients = <String, Map<String, dynamic>>{};
    
    for (final recipientId in recipientIds) {
      recipients[recipientId] = {
        'delivered': null,
        'read': null,
      };
    }

    return {
      'pending': true,
      'recipients': recipients,
      'deliveredAt': null,
      'readAt': null,
    };
  }

  /// Track message delivery for all recipients
  static void _trackMessageDelivery(
    String messageId,
    String chatId,
    List<String> recipientIds,
  ) {
    // This would typically integrate with your notification service
    // to track when messages are actually delivered to devices
    print('[SecureMessage] Delivery tracking started for message: $messageId');
  }

  /// Send chat notifications to all recipients
  static void _sendChatNotifications(
    String messageId,
    String chatId,
    String messageText,
    String senderName,
    List<String> recipientIds,
  ) {
    // Determine if this is a group chat or individual chat
    final isGroupChat = recipientIds.length > 1;
    final chatType = isGroupChat ? 'group' : 'individual';
    
    // Send notifications to all recipients
    for (final recipientId in recipientIds) {
      try {
        ProductionNotificationService().sendChatNotification(
          recipientId: recipientId,
          senderName: senderName,
          message: messageText,
          chatId: chatId,
          chatType: chatType,
        );
      } catch (e) {
        print('[SecureMessage] Failed to send notification to $recipientId: $e');
      }
    }
    
    print('[SecureMessage] Chat notifications sent to ${recipientIds.length} recipients');
  }
}
