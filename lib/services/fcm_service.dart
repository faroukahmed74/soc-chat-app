import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'dart:convert';
import 'logger_service.dart';

/// FCM Service for handling Firebase Cloud Messaging
class FCMService {
  static final FCMService _instance = FCMService._internal();
  factory FCMService() => _instance;
  FCMService._internal();

  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();
  
  String? _fcmToken;
  bool _isInitialized = false;

  /// Initialize FCM service
  Future<void> initialize() async {
    if (_isInitialized) return;
    
    try {
      Log.i('Initializing FCM Service...', 'FCM_SERVICE');
      
      // Request notification permissions
      await _requestNotificationPermissions();
      
      // Initialize local notifications
      await _initializeLocalNotifications();
      
      // Get FCM token
      await _getFCMToken();
      
      // Set up message handlers
      _setupMessageHandlers();
      
      // Set up token refresh listener
      _setupTokenRefreshListener();
      
      _isInitialized = true;
      Log.i('FCM Service initialized successfully', 'FCM_SERVICE');
    } catch (e) {
      Log.e('Error initializing FCM Service', 'FCM_SERVICE', e);
      rethrow;
    }
  }

  /// Request notification permissions
  Future<void> _requestNotificationPermissions() async {
    try {
      // Request permission for iOS
      if (defaultTargetPlatform == TargetPlatform.iOS) {
        NotificationSettings settings = await _firebaseMessaging.requestPermission(
          alert: true,
          announcement: false,
          badge: true,
          carPlay: false,
          criticalAlert: false,
          provisional: false,
          sound: true,
        );
        
        Log.i('iOS Notification permission status: ${settings.authorizationStatus}', 'FCM_SERVICE');
      }
      
      // Request permission for Android
      if (defaultTargetPlatform == TargetPlatform.android) {
        // Android permissions are handled in AndroidManifest.xml
        Log.i('Android notification permissions configured in manifest', 'FCM_SERVICE');
      }
    } catch (e) {
      Log.e('Error requesting notification permissions', 'FCM_SERVICE', e);
    }
  }

  /// Initialize local notifications
  Future<void> _initializeLocalNotifications() async {
    try {
      const AndroidInitializationSettings initializationSettingsAndroid =
          AndroidInitializationSettings('@mipmap/ic_launcher');
      
      const DarwinInitializationSettings initializationSettingsIOS =
          DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
      );
      
      const InitializationSettings initializationSettings = InitializationSettings(
        android: initializationSettingsAndroid,
        iOS: initializationSettingsIOS,
      );
      
      await _localNotifications.initialize(
        initializationSettings,
        onDidReceiveNotificationResponse: _onNotificationTapped,
      );
      
      Log.i('Local notifications initialized', 'FCM_SERVICE');
    } catch (e) {
      Log.e('Error initializing local notifications', 'FCM_SERVICE', e);
    }
  }

  /// Get FCM token
  Future<void> _getFCMToken() async {
    try {
      _fcmToken = await _firebaseMessaging.getToken();
      Log.i('FCM Token: $_fcmToken', 'FCM_SERVICE');
      
      // Save token to your backend/database
      await _saveTokenToBackend(_fcmToken);
    } catch (e) {
      Log.e('Error getting FCM token', 'FCM_SERVICE', e);
    }
  }

  /// Set up message handlers
  void _setupMessageHandlers() {
    // Handle messages when app is in foreground
    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);
    
    // Handle messages when app is opened from notification
    FirebaseMessaging.onMessageOpenedApp.listen(_handleMessageOpenedApp);
    
    // Handle background messages
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
    
    Log.i('Message handlers set up', 'FCM_SERVICE');
  }

  /// Set up token refresh listener
  void _setupTokenRefreshListener() {
    _firebaseMessaging.onTokenRefresh.listen((newToken) async {
      Log.i('FCM Token refreshed: $newToken', 'FCM_SERVICE');
      _fcmToken = newToken;
      await _saveTokenToBackend(newToken);
    });
  }

  /// Handle foreground messages
  Future<void> _handleForegroundMessage(RemoteMessage message) async {
    try {
      Log.i('Received foreground message: ${message.messageId}', 'FCM_SERVICE');
      
      // Show local notification
      await _showLocalNotification(message);
      
      // Handle message data
      await _handleMessageData(message.data);
    } catch (e) {
      Log.e('Error handling foreground message', 'FCM_SERVICE', e);
    }
  }

  /// Handle messages when app is opened from notification
  void _handleMessageOpenedApp(RemoteMessage message) {
    try {
      Log.i('App opened from notification: ${message.messageId}', 'FCM_SERVICE');
      
      // Handle message data and navigate if needed
      _handleMessageData(message.data);
    } catch (e) {
      Log.e('Error handling message opened app', 'FCM_SERVICE', e);
    }
  }

  /// Show local notification
  Future<void> _showLocalNotification(RemoteMessage message) async {
    try {
      const AndroidNotificationDetails androidPlatformChannelSpecifics =
          AndroidNotificationDetails(
        'chat_notifications',
        'Chat Notifications',
        channelDescription: 'Notifications for chat messages',
        importance: Importance.max,
        priority: Priority.high,
        showWhen: true,
        enableVibration: true,
        enableLights: true,
        color: Color(0xFF2196F3),
      );
      
      const DarwinNotificationDetails iOSPlatformChannelSpecifics =
          DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      );
      
      const NotificationDetails platformChannelSpecifics = NotificationDetails(
        android: androidPlatformChannelSpecifics,
        iOS: iOSPlatformChannelSpecifics,
      );
      
      await _localNotifications.show(
        message.hashCode,
        message.notification?.title ?? 'New Message',
        message.notification?.body ?? 'You have a new message',
        platformChannelSpecifics,
        payload: json.encode(message.data),
      );
    } catch (e) {
      Log.e('Error showing local notification', 'FCM_SERVICE', e);
    }
  }

  /// Handle notification tap
  void _onNotificationTapped(NotificationResponse response) {
    try {
      Log.i('Notification tapped: ${response.payload}', 'FCM_SERVICE');
      
      if (response.payload != null) {
        final data = json.decode(response.payload!);
        _handleMessageData(data);
      }
    } catch (e) {
      Log.e('Error handling notification tap', 'FCM_SERVICE', e);
    }
  }

  /// Handle message data
  Future<void> _handleMessageData(Map<String, dynamic> data) async {
    try {
      Log.i('Handling message data: $data', 'FCM_SERVICE');
      
      // Handle different types of messages
      final messageType = data['type'] ?? 'chat';
      
      switch (messageType) {
        case 'chat':
          await _handleChatMessage(data);
          break;
        case 'group_invite':
          await _handleGroupInvite(data);
          break;
        case 'friend_request':
          await _handleFriendRequest(data);
          break;
        default:
          Log.i('Unknown message type: $messageType', 'FCM_SERVICE');
      }
    } catch (e) {
      Log.e('Error handling message data', 'FCM_SERVICE', e);
    }
  }

  /// Handle chat message
  Future<void> _handleChatMessage(Map<String, dynamic> data) async {
    try {
      final chatId = data['chatId'];
      final senderName = data['senderName'] ?? 'Unknown';
      final message = data['message'] ?? '';
      
      Log.i('Chat message from $senderName: $message', 'FCM_SERVICE');
      
      // Navigate to chat screen or update UI
      // This will be implemented based on your app's navigation structure
    } catch (e) {
      Log.e('Error handling chat message', 'FCM_SERVICE', e);
    }
  }

  /// Handle group invite
  Future<void> _handleGroupInvite(Map<String, dynamic> data) async {
    try {
      final groupId = data['groupId'];
      final groupName = data['groupName'] ?? 'Unknown Group';
      final inviterName = data['inviterName'] ?? 'Unknown';
      
      Log.i('Group invite to $groupName from $inviterName', 'FCM_SERVICE');
      
      // Handle group invite logic
    } catch (e) {
      Log.e('Error handling group invite', 'FCM_SERVICE', e);
    }
  }

  /// Handle friend request
  Future<void> _handleFriendRequest(Map<String, dynamic> data) async {
    try {
      final requesterId = data['requesterId'];
      final requesterName = data['requesterName'] ?? 'Unknown';
      
      Log.i('Friend request from $requesterName', 'FCM_SERVICE');
      
      // Handle friend request logic
    } catch (e) {
      Log.e('Error handling friend request', 'FCM_SERVICE', e);
    }
  }

  /// Save token to backend
  Future<void> _saveTokenToBackend(String? token) async {
    try {
      if (token == null) return;
      
      Log.i('Saving FCM token to backend: $token', 'FCM_SERVICE');
      
      // TODO: Implement saving token to your backend
      // Example:
      // await http.post(
      //   Uri.parse('https://your-api.com/fcm-tokens'),
      //   headers: {'Content-Type': 'application/json'},
      //   body: json.encode({
      //     'userId': currentUserId,
      //     'fcmToken': token,
      //     'platform': defaultTargetPlatform.toString(),
      //   }),
      // );
      
    } catch (e) {
      Log.e('Error saving FCM token to backend', 'FCM_SERVICE', e);
    }
  }

  /// Subscribe to topic
  Future<void> subscribeToTopic(String topic) async {
    try {
      await _firebaseMessaging.subscribeToTopic(topic);
      Log.i('Subscribed to topic: $topic', 'FCM_SERVICE');
    } catch (e) {
      Log.e('Error subscribing to topic: $topic', 'FCM_SERVICE', e);
    }
  }

  /// Unsubscribe from topic
  Future<void> unsubscribeFromTopic(String topic) async {
    try {
      await _firebaseMessaging.unsubscribeFromTopic(topic);
      Log.i('Unsubscribed from topic: $topic', 'FCM_SERVICE');
    } catch (e) {
      Log.e('Error unsubscribing from topic: $topic', 'FCM_SERVICE', e);
    }
  }

  /// Get current FCM token
  String? get fcmToken => _fcmToken;

  /// Check if service is initialized
  bool get isInitialized => _isInitialized;

  /// Dispose resources
  void dispose() {
    _isInitialized = false;
    Log.i('FCM Service disposed', 'FCM_SERVICE');
  }
}

/// Background message handler
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  try {
    Log.i('Handling background message: ${message.messageId}', 'FCM_SERVICE');
    
    // Handle background message logic here
    // Note: This function must be top-level and cannot be a class method
    
  } catch (e) {
    Log.e('Error handling background message', 'FCM_SERVICE', e);
  }
}
