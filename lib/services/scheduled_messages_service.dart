// =============================================================================
// SCHEDULED MESSAGES SERVICE
// =============================================================================
// This service provides comprehensive scheduled messaging functionality
// for both one-to-one and group chats.
//
// KEY FEATURES:
// - Schedule messages for future delivery
// - Support for text, media, and voice messages
// - Recurring message schedules
// - Message templates
// - Delivery confirmation
// - Schedule management and editing
//
// ARCHITECTURE:
// - Uses Firestore for persistent storage
// - Implements background processing for delivery
// - Provides real-time schedule updates
// - Handles timezone conversions

import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';

class ScheduledMessagesService {
  static final ScheduledMessagesService _instance = ScheduledMessagesService._internal();
  factory ScheduledMessagesService() => _instance;
  ScheduledMessagesService._internal();

  // Firestore collections
  final CollectionReference _scheduledMessagesCollection = 
      FirebaseFirestore.instance.collection('scheduled_messages');
  
  // Background processing
  Timer? _processingTimer;
  bool _isProcessing = false;
  
  // Callbacks for schedule updates
  final List<Function(List<Map<String, dynamic>>)> _scheduleListeners = [];
  
  /// Initialize the service
  Future<void> initialize() async {
    try {
      // Start background processing
      _startBackgroundProcessing();
      print('[ScheduledMessages] Service initialized successfully');
    } catch (e) {
      print('[ScheduledMessages] Initialization error: $e');
    }
  }
  
  /// Start background processing for scheduled messages
  void _startBackgroundProcessing() {
    // Check for scheduled messages every minute
    _processingTimer = Timer.periodic(const Duration(minutes: 1), (timer) {
      _processScheduledMessages();
    });
  }
  
  /// Add schedule listener
  void addScheduleListener(Function(List<Map<String, dynamic>>) listener) {
    _scheduleListeners.add(listener);
  }
  
  /// Remove schedule listener
  void removeScheduleListener(Function(List<Map<String, dynamic>>) listener) {
    _scheduleListeners.remove(listener);
  }
  
  /// Notify listeners of schedule updates
  void _notifyListeners(List<Map<String, dynamic>> schedules) {
    for (final listener in _scheduleListeners) {
      try {
        listener(schedules);
      } catch (e) {
        print('[ScheduledMessages] Error notifying listener: $e');
      }
    }
  }
  
  // =============================================================================
  // SCHEDULE MESSAGE
  // =============================================================================
  
  /// Schedule a message for future delivery
  Future<String> scheduleMessage({
    required String chatId,
    required bool isGroupChat,
    required String messageText,
    required DateTime scheduledTime,
    String? mediaUrl,
    String? mediaType,
    Uint8List? mediaBytes,
    String? fileName,
    String? recurringPattern, // 'daily', 'weekly', 'monthly', 'yearly'
    Map<String, dynamic>? additionalData,
  }) async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        throw Exception('User not authenticated');
      }
      
      // Generate unique schedule ID
      final scheduleId = 'schedule_${DateTime.now().millisecondsSinceEpoch}_${currentUser.uid}';
      
      // Prepare schedule data
      final scheduleData = {
        'scheduleId': scheduleId,
        'chatId': chatId,
        'isGroupChat': isGroupChat,
        'senderId': currentUser.uid,
        'senderName': currentUser.displayName ?? 'Unknown User',
        'messageText': messageText,
        'scheduledTime': Timestamp.fromDate(scheduledTime),
        'createdAt': FieldValue.serverTimestamp(),
        'status': 'scheduled', // 'scheduled', 'delivered', 'failed', 'cancelled'
        'recurringPattern': recurringPattern,
        'nextDeliveryTime': Timestamp.fromDate(scheduledTime),
        'deliveryAttempts': 0,
        'maxDeliveryAttempts': 3,
        'additionalData': additionalData ?? {},
      };
      
      // Handle media if provided
      if (mediaBytes != null && fileName != null) {
        final mediaUrl = await _uploadMedia(mediaBytes, fileName, mediaType);
        scheduleData['mediaUrl'] = mediaUrl;
        scheduleData['mediaType'] = mediaType;
        scheduleData['fileName'] = fileName;
      } else if (mediaUrl != null) {
        scheduleData['mediaUrl'] = mediaUrl;
        scheduleData['mediaType'] = mediaType;
      }
      
      // Save to Firestore
      await _scheduledMessagesCollection.doc(scheduleId).set(scheduleData);
      
      print('[ScheduledMessages] Message scheduled: $scheduleId for ${scheduledTime.toString()}');
      return scheduleId;
    } catch (e) {
      print('[ScheduledMessages] Error scheduling message: $e');
      throw Exception('Failed to schedule message: $e');
    }
  }
  
  /// Upload media for scheduled message
  Future<String> _uploadMedia(Uint8List mediaBytes, String fileName, String? mediaType) async {
    try {
      final storageRef = FirebaseStorage.instance
          .ref()
          .child('scheduled_media')
          .child('${DateTime.now().millisecondsSinceEpoch}_$fileName');
      
      final metadata = SettableMetadata(
        contentType: mediaType ?? 'application/octet-stream',
      );
      
      await storageRef.putData(mediaBytes, metadata);
      final downloadUrl = await storageRef.getDownloadURL();
      
      return downloadUrl;
    } catch (e) {
      print('[ScheduledMessages] Error uploading media: $e');
      throw Exception('Failed to upload media: $e');
    }
  }
  
  // =============================================================================
  // PROCESS SCHEDULED MESSAGES
  // =============================================================================
  
  /// Process scheduled messages for delivery
  Future<void> _processScheduledMessages() async {
    if (_isProcessing) return;
    
    _isProcessing = true;
    try {
      final now = DateTime.now();
      final currentTimestamp = Timestamp.fromDate(now);
      
      // Get messages ready for delivery
      final readyMessages = await _scheduledMessagesCollection
          .where('status', isEqualTo: 'scheduled')
          .where('nextDeliveryTime', isLessThanOrEqualTo: currentTimestamp)
          .get();
      
      for (final doc in readyMessages.docs) {
        try {
          await _deliverScheduledMessage(doc);
        } catch (e) {
          print('[ScheduledMessages] Error delivering message ${doc.id}: $e');
          await _handleDeliveryFailure(doc.id, e.toString());
        }
      }
    } catch (e) {
      print('[ScheduledMessages] Error processing scheduled messages: $e');
    } finally {
      _isProcessing = false;
    }
  }
  
  /// Deliver a scheduled message
  Future<void> _deliverScheduledMessage(DocumentSnapshot doc) async {
          final data = doc.data() as Map<String, dynamic>?;
      if (data == null) return;
      
      final scheduleId = data['scheduleId'] as String?;
      final chatId = data['chatId'] as String?;
      final messageText = data['messageText'] as String?;
      final senderId = data['senderId'] as String?;
      final senderName = data['senderName'] as String?;
      final mediaUrl = data['mediaUrl'] as String?;
      final mediaType = data['mediaType'] as String?;
      final recurringPattern = data['recurringPattern'] as String?;
      
      if (scheduleId == null || chatId == null || messageText == null || 
          senderId == null || senderName == null) {
        print('[ScheduledMessages] Invalid message data');
        return;
      }
    
    try {
      // Create message data
      final messageData = {
        'text': messageText,
        'senderId': senderId,
        'senderName': senderName,
        'timestamp': FieldValue.serverTimestamp(),
        'type': mediaUrl != null ? (mediaType ?? 'document') : 'text',
        'mediaUrl': mediaUrl,
        'mediaType': mediaType,
        'scheduledMessageId': scheduleId,
        'isScheduled': true,
      };
      
      // Add message to chat
      await FirebaseFirestore.instance
          .collection('chats')
          .doc(chatId)
          .collection('messages')
          .add(messageData);
      
      // Update schedule status
      if (recurringPattern != null) {
        // Handle recurring message
        await _updateRecurringSchedule(scheduleId, data);
      } else {
        // Mark as delivered
        await _scheduledMessagesCollection.doc(scheduleId).update({
          'status': 'delivered',
          'deliveredAt': FieldValue.serverTimestamp(),
        });
      }
      
      print('[ScheduledMessages] Message delivered: $scheduleId');
    } catch (e) {
      print('[ScheduledMessages] Error delivering message: $e');
      throw e;
    }
  }
  
  /// Update recurring schedule for next delivery
  Future<void> _updateRecurringSchedule(String scheduleId, Map<String, dynamic> data) async {
    try {
      final recurringPattern = data['recurringPattern'] as String?;
      final lastDeliveryTime = data['nextDeliveryTime'] as Timestamp?;
      
      if (recurringPattern == null || lastDeliveryTime == null) {
        print('[ScheduledMessages] Invalid recurring schedule data');
        return;
      }
      
      final nextDeliveryTime = _calculateNextDeliveryTime(lastDeliveryTime.toDate(), recurringPattern);
      
      await _scheduledMessagesCollection.doc(scheduleId).update({
        'nextDeliveryTime': Timestamp.fromDate(nextDeliveryTime),
        'lastDeliveredAt': FieldValue.serverTimestamp(),
        'deliveryAttempts': 0,
      });
      
      print('[ScheduledMessages] Recurring schedule updated: $scheduleId');
    } catch (e) {
      print('[ScheduledMessages] Error updating recurring schedule: $e');
    }
  }
  
  /// Calculate next delivery time for recurring messages
  DateTime _calculateNextDeliveryTime(DateTime lastDelivery, String pattern) {
    switch (pattern) {
      case 'daily':
        return lastDelivery.add(const Duration(days: 1));
      case 'weekly':
        return lastDelivery.add(const Duration(days: 7));
      case 'monthly':
        return DateTime(lastDelivery.year, lastDelivery.month + 1, lastDelivery.day);
      case 'yearly':
        return DateTime(lastDelivery.year + 1, lastDelivery.month, lastDelivery.day);
      default:
        return lastDelivery.add(const Duration(days: 1));
    }
  }
  
  /// Handle delivery failure
  Future<void> _handleDeliveryFailure(String scheduleId, String error) async {
    try {
      final doc = await _scheduledMessagesCollection.doc(scheduleId).get();
      final data = doc.data() as Map<String, dynamic>?;
      if (data == null) return;
      
      final attempts = (data['deliveryAttempts'] ?? 0) + 1;
      final maxAttempts = data['maxDeliveryAttempts'] ?? 3;
      
      if (attempts >= maxAttempts) {
        // Mark as failed after max attempts
        await _scheduledMessagesCollection.doc(scheduleId).update({
          'status': 'failed',
          'lastError': error,
          'failedAt': FieldValue.serverTimestamp(),
        });
      } else {
        // Retry with exponential backoff
        final retryDelay = Duration(minutes: attempts * 5);
        final nextRetry = DateTime.now().add(retryDelay);
        
        await _scheduledMessagesCollection.doc(scheduleId).update({
          'deliveryAttempts': attempts,
          'nextDeliveryTime': Timestamp.fromDate(nextRetry),
          'lastError': error,
        });
      }
    } catch (e) {
      print('[ScheduledMessages] Error handling delivery failure: $e');
    }
  }
  
  // =============================================================================
  // SCHEDULE MANAGEMENT
  // =============================================================================
  
  /// Get scheduled messages for a chat
  Stream<List<Map<String, dynamic>>> getScheduledMessages(String chatId) {
    return _scheduledMessagesCollection
        .where('chatId', isEqualTo: chatId)
        .where('status', isEqualTo: 'scheduled')
        .orderBy('scheduledTime')
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => {
                  'scheduleId': doc.id,
                  ...doc.data() as Map<String, dynamic>,
                })
            .toList());
  }
  
  /// Get all scheduled messages for current user
  Stream<List<Map<String, dynamic>>> getUserScheduledMessages() {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      return Stream.value([]);
    }
    
    return _scheduledMessagesCollection
        .where('senderId', isEqualTo: currentUser.uid)
        .orderBy('scheduledTime')
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => {
                  'scheduleId': doc.id,
                  ...doc.data() as Map<String, dynamic>,
                })
            .toList());
  }
  
  /// Update scheduled message
  Future<void> updateScheduledMessage({
    required String scheduleId,
    String? messageText,
    DateTime? scheduledTime,
    String? recurringPattern,
    Map<String, dynamic>? additionalData,
  }) async {
    try {
      final updateData = <String, dynamic>{};
      
      if (messageText != null) updateData['messageText'] = messageText;
      if (scheduledTime != null) updateData['scheduledTime'] = Timestamp.fromDate(scheduledTime);
      if (recurringPattern != null) updateData['recurringPattern'] = recurringPattern;
      if (additionalData != null) updateData['additionalData'] = additionalData;
      
      updateData['updatedAt'] = FieldValue.serverTimestamp();
      
      await _scheduledMessagesCollection.doc(scheduleId).update(updateData);
      
      print('[ScheduledMessages] Message updated: $scheduleId');
    } catch (e) {
      print('[ScheduledMessages] Error updating message: $e');
      throw Exception('Failed to update scheduled message: $e');
    }
  }
  
  /// Cancel scheduled message
  Future<void> cancelScheduledMessage(String scheduleId) async {
    try {
      await _scheduledMessagesCollection.doc(scheduleId).update({
        'status': 'cancelled',
        'cancelledAt': FieldValue.serverTimestamp(),
      });
      
      print('[ScheduledMessages] Message cancelled: $scheduleId');
    } catch (e) {
      print('[ScheduledMessages] Error cancelling message: $e');
      throw Exception('Failed to cancel scheduled message: $e');
    }
  }
  
  /// Delete scheduled message
  Future<void> deleteScheduledMessage(String scheduleId) async {
    try {
      await _scheduledMessagesCollection.doc(scheduleId).delete();
      
      print('[ScheduledMessages] Message deleted: $scheduleId');
    } catch (e) {
      print('[ScheduledMessages] Error deleting message: $e');
      throw Exception('Failed to delete scheduled message: $e');
    }
  }
  
  // =============================================================================
  // MESSAGE TEMPLATES
  // =============================================================================
  
  /// Save message template
  Future<String> saveMessageTemplate({
    required String name,
    required String messageText,
    String? mediaUrl,
    String? mediaType,
    Map<String, dynamic>? additionalData,
  }) async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        throw Exception('User not authenticated');
      }
      
      final templateId = 'template_${DateTime.now().millisecondsSinceEpoch}_${currentUser.uid}';
      
      final templateData = {
        'templateId': templateId,
        'name': name,
        'messageText': messageText,
        'mediaUrl': mediaUrl,
        'mediaType': mediaType,
        'createdBy': currentUser.uid,
        'createdAt': FieldValue.serverTimestamp(),
        'additionalData': additionalData ?? {},
      };
      
      await FirebaseFirestore.instance
          .collection('message_templates')
          .doc(templateId)
          .set(templateData);
      
      print('[ScheduledMessages] Template saved: $templateId');
      return templateId;
    } catch (e) {
      print('[ScheduledMessages] Error saving template: $e');
      throw Exception('Failed to save template: $e');
    }
  }
  
  /// Get user's message templates
  Stream<List<Map<String, dynamic>>> getUserTemplates() {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      return Stream.value([]);
    }
    
    return FirebaseFirestore.instance
        .collection('message_templates')
        .where('createdBy', isEqualTo: currentUser.uid)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => {
                  'templateId': doc.id,
                  ...doc.data() as Map<String, dynamic>,
                })
            .toList());
  }
  
  // =============================================================================
  // UTILITY METHODS
  // =============================================================================
  
  /// Get schedule statistics
  Future<Map<String, dynamic>> getScheduleStats() async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        return {};
      }
      
      final userSchedules = await _scheduledMessagesCollection
          .where('senderId', isEqualTo: currentUser.uid)
          .get();
      
      int scheduled = 0;
      int delivered = 0;
      int failed = 0;
      int cancelled = 0;
      
      for (final doc in userSchedules.docs) {
        final data = doc.data() as Map<String, dynamic>?;
        if (data != null) {
          final status = data['status'] as String?;
          switch (status) {
            case 'scheduled':
              scheduled++;
              break;
            case 'delivered':
              delivered++;
              break;
            case 'failed':
              failed++;
              break;
            case 'cancelled':
              cancelled++;
              break;
          }
        }
      }
      
      return {
        'total': userSchedules.docs.length,
        'scheduled': scheduled,
        'delivered': delivered,
        'failed': failed,
        'cancelled': cancelled,
      };
    } catch (e) {
      print('[ScheduledMessages] Error getting stats: $e');
      return {};
    }
  }
  
  /// Dispose the service
  void dispose() {
    _processingTimer?.cancel();
    _scheduleListeners.clear();
    print('[ScheduledMessages] Service disposed');
  }
}
