import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'unified_notification_service.dart';
import 'logger_service.dart';

class FCMNotificationService {
  static final FCMNotificationService _instance = FCMNotificationService._();
  factory FCMNotificationService() => _instance;
  FCMNotificationService._();

  StreamSubscription<RemoteMessage>? _onMessageSub;
  StreamSubscription<RemoteMessage>? _onMessageOpenedAppSub;
  final FirebaseFunctions _functions = FirebaseFunctions.instance;

  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;

    // Foreground messages
    _onMessageSub = FirebaseMessaging.onMessage.listen(handleForegroundMessage);

    // Notification tap when app in background
    _onMessageOpenedAppSub = FirebaseMessaging.onMessageOpenedApp.listen(handleNotificationTap);

    // App opened from terminated via notification
    final initial = await FirebaseMessaging.instance.getInitialMessage();
    if (initial != null) {
      await handleNotificationTap(initial);
    }

    Log.i('FCMNotificationService initialized', 'FCM');
  }

  Future<void> dispose() async {
    await _onMessageSub?.cancel();
    await _onMessageOpenedAppSub?.cancel();
    _initialized = false;
  }

  // Called from top-level BG handler
  Future<void> handleBackgroundMessage(RemoteMessage message) async {
    Log.i('BG message received: ${message.messageId}', 'FCM');
    await _display(message, isBackground: true);
  }

  Future<void> handleForegroundMessage(RemoteMessage message) async {
    Log.i('FG message received: ${message.messageId}', 'FCM');
    await _display(message, isBackground: false);
  }

  Future<void> handleNotificationTap(RemoteMessage message) async {
    try {
      Log.i('Notification tapped: ${message.messageId}', 'FCM');
      // Navigate using navigatorKey if needed, based on message.data
      // navigatorKey.currentState?.pushNamed('/chats', arguments: ...);
    } catch (e) {
      Log.e('Tap handling error', 'FCM', e);
    }
  }

  Future<void> _display(RemoteMessage message, {required bool isBackground}) async {
    final unified = UnifiedNotificationService();

    final title = message.notification?.title ?? message.data['title'] ?? 'New message';
    final body  = message.notification?.body  ?? message.data['body']  ?? '';
    final payload = json.encode(message.data);
    
    // Determine channel based on message type
    String channelId = 'chat_notifications';
    if (message.data['type'] == 'group_message') {
      channelId = 'group_notifications';
    } else if (message.data['type'] == 'broadcast_message') {
      channelId = 'broadcast_notifications';
    }

    await unified.sendLocalNotification(
      title: title,
      body: body,
      payload: payload,
      channelId: channelId,
    );
  }

  // Stubbed health check (extend to call your server, or ping FCM)
  Future<bool> checkFCMServerHealth() async {
    try {
      final token = await FirebaseMessaging.instance.getToken();
      return token != null && token.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  /// Handle new chat message - Send remote FCM notification to receiver
  Future<void> handleNewMessage({
    required String senderId,
    required String senderName,
    required String message,
    required String receiverId,
    String? messageType,
  }) async {
    try {
      // Get receiver's FCM token from Firestore
      final receiverDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(receiverId)
          .get();
      
      if (!receiverDoc.exists) {
        Log.w('Receiver not found: $receiverId', 'FCM');
        return;
      }

      final receiverData = receiverDoc.data()!;
      final fcmToken = receiverData['fcmToken'];
      
      if (fcmToken == null || fcmToken.isEmpty) {
        Log.w('No FCM token found for receiver: $receiverId', 'FCM');
        return;
      }

      // Send remote FCM notification to receiver
      final title = 'New message from $senderName';
      final body = message.length > 50 ? '${message.substring(0, 50)}...' : message;
      
      final notificationData = {
        'type': 'chat_message',
        'senderId': senderId,
        'senderName': senderName,
        'message': message,
        'receiverId': receiverId,
        'messageType': messageType ?? 'text',
        'timestamp': DateTime.now().toIso8601String(),
      };

      // Use Cloud Function to send FCM notification
      await _functions.httpsCallable('sendFCMNotification').call({
        'token': fcmToken,
        'title': title,
        'body': body,
        'data': notificationData,
      });
      
      Log.i('Remote FCM notification sent to receiver: $receiverId', 'FCM');
    } catch (e) {
      Log.e('Error sending remote FCM notification', 'FCM', e);
    }
  }

  /// Handle group message - Send remote FCM notifications to all group members except sender
  Future<void> handleGroupMessage({
    required String senderId,
    required String senderName,
    required String message,
    required String groupId,
    required String groupName,
    String? messageType,
  }) async {
    try {
      // Get group members from Firestore
      final groupDoc = await FirebaseFirestore.instance
          .collection('chats')
          .doc(groupId)
          .get();
      
      if (!groupDoc.exists) {
        Log.w('Group not found: $groupId', 'FCM');
        return;
      }

      final groupData = groupDoc.data()!;
      final memberIds = List<String>.from(groupData['members'] ?? []);
      
      // Remove sender from notification recipients
      final recipientIds = memberIds.where((id) => id != senderId).toList();
      
      if (recipientIds.isEmpty) {
        Log.w('No recipients found for group: $groupId', 'FCM');
        return;
      }

      // Send notifications to all recipients using Cloud Function
      final title = '$senderName in $groupName';
      final body = message.length > 50 ? '${message.substring(0, 50)}...' : message;
      
      final notificationData = {
        'type': 'group_message',
        'senderId': senderId,
        'senderName': senderName,
        'message': message,
        'groupId': groupId,
        'groupName': groupName,
        'messageType': messageType ?? 'text',
        'timestamp': DateTime.now().toIso8601String(),
      };

      // Use Cloud Function to send notifications to multiple users
      await _functions.httpsCallable('sendNotificationToUsers').call({
        'userIds': recipientIds,
        'title': title,
        'body': body,
        'data': notificationData,
      });
      
      Log.i('Remote FCM notifications sent to ${recipientIds.length} group members', 'FCM');
    } catch (e) {
      Log.e('Error sending group FCM notifications', 'FCM', e);
    }
  }

  /// Handle broadcast message
  Future<void> handleBroadcastMessage({
    required String senderId,
    required String senderName,
    required String message,
    String? messageType,
  }) async {
    try {
      final title = 'Broadcast from $senderName';
      final body = message.length > 50 ? '${message.substring(0, 50)}...' : message;
      
      // Send local notification with sound
      final unified = UnifiedNotificationService();
      await unified.sendLocalNotification(
        title: title,
        body: body,
        payload: json.encode({
          'type': 'broadcast_message',
          'senderId': senderId,
          'senderName': senderName,
          'message': message,
          'messageType': messageType ?? 'text',
          'timestamp': DateTime.now().toIso8601String(),
        }),
        channelId: 'broadcast_notifications',
      );
      
      Log.i('Broadcast message notification sent', 'FCM');
    } catch (e) {
      Log.e('Error handling broadcast message', 'FCM', e);
    }
  }
}
