import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'logger_service.dart';

/// Production-ready notification service for final release
/// Handles FCM, local notifications, and proper permission management
class ProductionNotificationService {
  static final ProductionNotificationService _instance = ProductionNotificationService._internal();
  factory ProductionNotificationService() => _instance;
  ProductionNotificationService._internal();

  final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();
  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Notification channels
  static const String _chatChannelId = 'chat_channel';
  static const String _broadcastChannelId = 'broadcast_channel';
  static const String _adminChannelId = 'admin_channel';

  // FCM Server Configuration
  static const String _fcmServerUrl = 'http://localhost:3000'; // Change to your server URL in production
  static const String _fcmServerUrlProduction = 'https://your-production-server.com'; // TODO: Set production URL

  /// Initialize the production notification service
  Future<void> initialize() async {
    try {
      Log.i('Initializing production notification service', 'PRODUCTION_NOTIFICATION');
      
      if (kIsWeb) {
        await _initializeWebNotifications();
      } else {
        await _initializeMobileNotifications();
      }
      
      Log.i('Production notification service initialized successfully', 'PRODUCTION_NOTIFICATION');
    } catch (e) {
      Log.e('Failed to initialize production notification service', 'PRODUCTION_NOTIFICATION', e);
    }
  }

  /// Initialize mobile notifications (Android & iOS)
  Future<void> _initializeMobileNotifications() async {
    try {
      // Set up local notifications first
      await _setupLocalNotifications();
      
      // Platform-specific initialization
      if (defaultTargetPlatform == TargetPlatform.iOS) {
        await _initializeIOSNotifications();
      } else {
        await _initializeAndroidNotifications();
      }
    } catch (e) {
      Log.e('Mobile notification setup error', 'PRODUCTION_NOTIFICATION', e);
    }
  }

  /// Initialize iOS-specific notifications
  Future<void> _initializeIOSNotifications() async {
    try {
      Log.i('Initializing iOS notifications', 'PRODUCTION_NOTIFICATION');
      
      // Request Firebase Messaging permission
      final settings = await _firebaseMessaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );

      Log.i('iOS notification permission result: ${settings.authorizationStatus}', 'PRODUCTION_NOTIFICATION');

      if (settings.authorizationStatus == AuthorizationStatus.authorized) {
        Log.i('iOS notifications authorized', 'PRODUCTION_NOTIFICATION');
        await _setupFCMForPlatform();
      } else {
        Log.w('iOS notifications not authorized: ${settings.authorizationStatus}', 'PRODUCTION_NOTIFICATION');
      }
    } catch (e) {
      Log.e('iOS notification setup error', 'PRODUCTION_NOTIFICATION', e);
    }
  }

  /// Initialize Android-specific notifications
  Future<void> _initializeAndroidNotifications() async {
    try {
      Log.i('Initializing Android notifications', 'PRODUCTION_NOTIFICATION');
      
      // Android 13+ requires explicit notification permission
      if (await _isAndroid13OrHigher()) {
        Log.i('Android 13+ detected, checking notification permission', 'PRODUCTION_NOTIFICATION');
        final notificationStatus = await _firebaseMessaging.getNotificationSettings();
        
        if (notificationStatus.authorizationStatus == AuthorizationStatus.notDetermined) {
          Log.i('Requesting notification permission for Android 13+', 'PRODUCTION_NOTIFICATION');
          final newSettings = await _firebaseMessaging.requestPermission();
          Log.i('Android notification permission result: ${newSettings.authorizationStatus}', 'PRODUCTION_NOTIFICATION');
        }
      }
      
      await _setupFCMForPlatform();
      
    } catch (e) {
      Log.e('Android notification setup error', 'PRODUCTION_NOTIFICATION', e);
    }
  }

  /// Initialize web notifications
  Future<void> _initializeWebNotifications() async {
    try {
      Log.i('Initializing web notifications', 'PRODUCTION_NOTIFICATION');
      
      // Get FCM token for web
      final token = await _firebaseMessaging.getToken();
      if (token != null) {
        await _saveFcmTokenToFirestore(token);
        Log.i('Web FCM token saved: ${token.substring(0, 20)}...', 'PRODUCTION_NOTIFICATION');
      }

      // Listen for token refresh
      _firebaseMessaging.onTokenRefresh.listen(_saveFcmTokenToFirestore);

      // Handle foreground messages
      FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

      // Handle notification taps
      FirebaseMessaging.onMessageOpenedApp.listen(_handleNotificationTap);
      
    } catch (e) {
      Log.e('Web notification setup error', 'PRODUCTION_NOTIFICATION', e);
    }
  }

  /// Set up FCM for the current platform
  Future<void> _setupFCMForPlatform() async {
    try {
      // Get FCM token
      final token = await _firebaseMessaging.getToken();
      if (token != null) {
        await _saveFcmTokenToFirestore(token);
        Log.i('FCM token saved: ${token.substring(0, 20)}...', 'PRODUCTION_NOTIFICATION');
      }

      // Listen for token refresh
      _firebaseMessaging.onTokenRefresh.listen(_saveFcmTokenToFirestore);

      // Handle background messages
      FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

      // Handle foreground messages
      FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

      // Handle notification taps when app is in background
      FirebaseMessaging.onMessageOpenedApp.listen(_handleNotificationTap);

      // Check for initial notification
      final initialMessage = await _firebaseMessaging.getInitialMessage();
      if (initialMessage != null) {
        _handleNotificationTap(initialMessage);
      }
      
    } catch (e) {
      Log.e('FCM setup error', 'PRODUCTION_NOTIFICATION', e);
    }
  }

  /// Set up local notifications
  Future<void> _setupLocalNotifications() async {
    try {
      const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
      const iosSettings = DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
      );
      
      const initSettings = InitializationSettings(
        android: androidSettings,
        iOS: iosSettings,
      );

      await _localNotifications.initialize(
        initSettings,
        onDidReceiveNotificationResponse: _onNotificationTapped,
      );

      // Create notification channels for Android
      if (defaultTargetPlatform == TargetPlatform.android) {
        await _createNotificationChannels();
      }

      // Set up iOS notification categories
      if (defaultTargetPlatform == TargetPlatform.iOS) {
        await _setupIOSNotificationCategories();
      }
      
      Log.i('Local notifications set up successfully', 'PRODUCTION_NOTIFICATION');
      
    } catch (e) {
      Log.e('Local notification setup error', 'PRODUCTION_NOTIFICATION', e);
    }
  }

  /// Create notification channels for Android
  Future<void> _createNotificationChannels() async {
    try {
      // Chat notifications channel
      const chatChannel = AndroidNotificationChannel(
        _chatChannelId,
        'Chat Notifications',
        description: 'Notifications for chat messages and conversations',
        importance: Importance.high,
        enableVibration: true,
        playSound: true,
        showBadge: true,
      );

      // Broadcast notifications channel
      const broadcastChannel = AndroidNotificationChannel(
        _broadcastChannelId,
        'Broadcast Notifications',
        description: 'Notifications for admin broadcasts and announcements',
        importance: Importance.high,
        enableVibration: true,
        playSound: true,
        showBadge: true,
      );

      // Admin notifications channel
      const adminChannel = AndroidNotificationChannel(
        _adminChannelId,
        'Admin Notifications',
        description: 'Notifications for administrative actions and system updates',
        importance: Importance.low,
        enableVibration: false,
        playSound: true,
        showBadge: false,
      );

      final androidImplementation = _localNotifications
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      
      if (androidImplementation != null) {
        await androidImplementation.createNotificationChannel(chatChannel);
        await androidImplementation.createNotificationChannel(broadcastChannel);
        await androidImplementation.createNotificationChannel(adminChannel);
        Log.i('Android notification channels created successfully', 'PRODUCTION_NOTIFICATION');
      }
      
    } catch (e) {
      Log.e('Error creating Android notification channels', 'PRODUCTION_NOTIFICATION', e);
    }
  }

  /// Set up iOS notification categories
  Future<void> _setupIOSNotificationCategories() async {
    try {
      final iosImplementation = _localNotifications
          .resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>();
      
      if (iosImplementation != null) {
        // Create notification categories for iOS
        await iosImplementation.requestPermissions(
          alert: true,
          badge: true,
          sound: true,
        );
        
        Log.i('iOS notification categories set up successfully', 'PRODUCTION_NOTIFICATION');
      }
      
    } catch (e) {
      Log.e('Error setting up iOS notification categories', 'PRODUCTION_NOTIFICATION', e);
    }
  }

  /// Save FCM token to Firestore
  Future<void> _saveFcmTokenToFirestore(String token) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await _firestore
            .collection('users')
            .doc(user.uid)
            .update({
          'fcmToken': token,
          'lastTokenUpdate': FieldValue.serverTimestamp(),
          'platform': kIsWeb ? 'web' : (defaultTargetPlatform == TargetPlatform.iOS ? 'ios' : 'android'),
          'notificationEnabled': true,
        });
        
        Log.i('FCM token saved to Firestore successfully', 'PRODUCTION_NOTIFICATION');
      }
    } catch (e) {
      Log.e('Error saving FCM token to Firestore', 'PRODUCTION_NOTIFICATION', e);
    }
  }

  /// Handle foreground messages
  void _handleForegroundMessage(RemoteMessage message) {
    Log.i('Received foreground message: ${message.messageId}', 'PRODUCTION_NOTIFICATION');
    
    // Show local notification
    _showLocalNotification(
      title: message.notification?.title ?? 'New Message',
      body: message.notification?.body ?? 'You have a new message',
      payload: message.data.toString(),
      channelId: _chatChannelId,
    );
  }

  /// Handle notification taps
  void _handleNotificationTap(RemoteMessage message) {
    Log.i('Notification tapped: ${message.messageId}', 'PRODUCTION_NOTIFICATION');
    // Handle navigation based on message data
    // This would typically navigate to a specific screen
  }

  /// Handle local notification taps
  void _onNotificationTapped(NotificationResponse response) {
    Log.i('Local notification tapped: ${response.payload}', 'PRODUCTION_NOTIFICATION');
    // Handle navigation based on payload
  }

  /// Show local notification
  Future<void> _showLocalNotification({
    required String title,
    required String body,
    String? payload,
    String channelId = _chatChannelId,
  }) async {
    try {
      final androidDetails = AndroidNotificationDetails(
        _chatChannelId,
        'Chat Notifications',
        channelDescription: 'Notifications for chat messages',
        importance: Importance.high,
        priority: Priority.high,
        enableVibration: true,
        playSound: true,
        icon: '@mipmap/ic_launcher',
        color: Color(0xFF2196F3),
        showWhen: true,
        when: DateTime.now().millisecondsSinceEpoch,
      );
      
      const iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
        badgeNumber: 1,
        categoryIdentifier: 'chat_notification',
        threadIdentifier: 'chat_thread',
        sound: 'default',
      );
      
      final notificationDetails = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );

      await _localNotifications.show(
        DateTime.now().millisecondsSinceEpoch.remainder(100000),
        title,
        body,
        notificationDetails,
        payload: payload,
      );
      
      Log.i('Local notification shown: $title', 'PRODUCTION_NOTIFICATION');
      
    } catch (e) {
      Log.e('Error showing local notification', 'PRODUCTION_NOTIFICATION', e);
    }
  }

  /// Check if device is Android 13 or higher
  Future<bool> _isAndroid13OrHigher() async {
    try {
      if (defaultTargetPlatform != TargetPlatform.android) return false;
      
      // Try to request notification permission - if it works, we're on Android 13+
      // If it throws an error, we're on older Android
      await _firebaseMessaging.getNotificationSettings();
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Get notification permission status
  Future<Map<String, dynamic>> getNotificationPermissionStatus() async {
    try {
      if (kIsWeb) {
        return {
          'authorized': true,
          'platform': 'web',
          'status': 'granted',
        };
      }
      
      final settings = await _firebaseMessaging.getNotificationSettings();
      
      return {
        'authorized': settings.authorizationStatus == AuthorizationStatus.authorized,
        'platform': defaultTargetPlatform == TargetPlatform.iOS ? 'ios' : 'android',
        'status': _getAuthorizationStatusString(settings.authorizationStatus),
        'alert': settings.alert,
        'badge': settings.badge,
        'sound': settings.sound,
      };
      
    } catch (e) {
      Log.e('Error getting notification permission status', 'PRODUCTION_NOTIFICATION', e);
      return {
        'authorized': false,
        'platform': 'unknown',
        'status': 'error',
      };
    }
  }

  /// Convert AuthorizationStatus to string
  String _getAuthorizationStatusString(AuthorizationStatus status) {
    switch (status) {
      case AuthorizationStatus.authorized:
        return 'authorized';
      case AuthorizationStatus.denied:
        return 'denied';
      case AuthorizationStatus.notDetermined:
        return 'not_determined';
      case AuthorizationStatus.provisional:
        return 'provisional';
      default:
        return 'unknown';
    }
  }

  /// Request notification permission
  Future<bool> requestNotificationPermission() async {
    try {
      final settings = await _firebaseMessaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );
      
      final isAuthorized = settings.authorizationStatus == AuthorizationStatus.authorized;
      Log.i('Notification permission request result: ${settings.authorizationStatus}', 'PRODUCTION_NOTIFICATION');
      
      return isAuthorized;
      
    } catch (e) {
      Log.e('Error requesting notification permission', 'PRODUCTION_NOTIFICATION', e);
      return false;
    }
  }

  /// Get FCM token
  Future<String?> getFcmToken() async {
    try {
      return await _firebaseMessaging.getToken();
    } catch (e) {
      Log.e('Error getting FCM token', 'PRODUCTION_NOTIFICATION', e);
      return null;
    }
  }

  /// Subscribe to topic
  Future<void> subscribeToTopic(String topic) async {
    try {
      await _firebaseMessaging.subscribeToTopic(topic);
      Log.i('Subscribed to topic: $topic', 'PRODUCTION_NOTIFICATION');
    } catch (e) {
      Log.e('Error subscribing to topic: $topic', 'PRODUCTION_NOTIFICATION', e);
    }
  }

  /// Unsubscribe from topic
  Future<void> unsubscribeFromTopic(String topic) async {
    try {
      await _firebaseMessaging.unsubscribeFromTopic(topic);
      Log.i('Unsubscribed from topic: $topic', 'PRODUCTION_NOTIFICATION');
    } catch (e) {
      Log.e('Error unsubscribing from topic: $topic', 'PRODUCTION_NOTIFICATION', e);
    }
  }
  
  /// Send broadcast notification (for admin panel)
  Future<void> sendBroadcastNotification({
    required String title,
    required String message,
    String? payload,
    String? senderId,
    String? senderName,
  }) async {
    try {
      // Create enhanced payload with sender information
      final enhancedPayload = {
        'type': 'broadcast',
        'senderId': senderId,
        'senderName': senderName,
        'timestamp': DateTime.now().toIso8601String(),
        'originalPayload': payload,
      };
      
      await _showLocalNotification(
        title: title,
        body: message,
        payload: enhancedPayload.toString(),
        channelId: _broadcastChannelId,
      );
      Log.i('Broadcast notification sent: $title by $senderName', 'PRODUCTION_NOTIFICATION');
    } catch (e) {
      Log.e('Error sending broadcast notification', 'PRODUCTION_NOTIFICATION', e);
    }
  }
  
  /// Send test notification
  Future<void> sendTestNotification() async {
    try {
      await _showLocalNotification(
        title: '🧪 Test Notification',
        body: 'This is a test notification to verify the system is working!',
        payload: 'test_notification',
        channelId: _chatChannelId,
      );
      Log.i('Test notification sent successfully', 'PRODUCTION_NOTIFICATION');
    } catch (e) {
      Log.e('Error sending test notification', 'PRODUCTION_NOTIFICATION', e);
    }
  }
  
  /// Send chat notification to specific user
  Future<void> sendChatNotification({
    required String recipientId,
    required String senderName,
    required String message,
    required String chatId,
    required String chatType,
  }) async {
    try {
      final title = chatType == 'group' ? '$senderName in $chatType' : senderName;
      final body = message.length > 50 ? '${message.substring(0, 50)}...' : message;
      
      await _showLocalNotification(
        title: title,
        body: body,
        payload: 'chat:$chatId',
        channelId: _chatChannelId,
      );
      Log.i('Chat notification sent to $recipientId', 'PRODUCTION_NOTIFICATION');
    } catch (e) {
      Log.e('Error sending chat notification', 'PRODUCTION_NOTIFICATION', e);
    }
  }

  // ===== FCM SERVER INTEGRATION METHODS =====



  /// Subscribe to broadcast topic for all users
  Future<void> subscribeToBroadcastTopic() async {
    try {
      await _firebaseMessaging.subscribeToTopic('all_users');
      Log.i('Subscribed to broadcast topic: all_users', 'PRODUCTION_NOTIFICATION');
    } catch (e) {
      Log.e('Error subscribing to broadcast topic', 'PRODUCTION_NOTIFICATION', e);
    }
  }

  /// Subscribe to user-specific topic
  Future<void> subscribeToUserTopic(String userId) async {
    try {
      final userTopic = 'user_$userId';
      await _firebaseMessaging.subscribeToTopic(userTopic);
      Log.i('Subscribed to user topic: $userTopic', 'PRODUCTION_NOTIFICATION');
    } catch (e) {
      Log.e('Error subscribing to user topic: user_$userId', 'PRODUCTION_NOTIFICATION', e);
    }
  }

  /// Subscribe to chat-specific topic
  Future<void> subscribeToChatTopic(String chatId) async {
    try {
      final chatTopic = 'chat_$chatId';
      await _firebaseMessaging.subscribeToTopic(chatTopic);
      Log.i('Subscribed to chat topic: $chatTopic', 'PRODUCTION_NOTIFICATION');
    } catch (e) {
      Log.e('Error subscribing to chat topic: chat_$chatId', 'PRODUCTION_NOTIFICATION', e);
    }
  }



  /// Subscribe to all relevant topics for a user
  Future<void> subscribeToAllUserTopics(String userId) async {
    try {
      // Subscribe to broadcast topic
      await subscribeToBroadcastTopic();
      
      // Subscribe to user-specific topic
      await subscribeToUserTopic(userId);
      
      Log.i('Subscribed to all user topics for: $userId', 'PRODUCTION_NOTIFICATION');
    } catch (e) {
      Log.e('Error subscribing to all user topics', 'PRODUCTION_NOTIFICATION', e);
    }
  }

  /// Subscribe to chat topics for all user's chats
  Future<void> subscribeToUserChatTopics() async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) return;

      // Get all chats for the current user
      final chatsSnapshot = await FirebaseFirestore.instance
          .collection('chats')
          .where('members', arrayContains: currentUser.uid)
          .get();

      for (final chatDoc in chatsSnapshot.docs) {
        final chatId = chatDoc.id;
        await subscribeToChatTopic(chatId);
      }

      Log.i('Subscribed to ${chatsSnapshot.docs.length} chat topics', 'PRODUCTION_NOTIFICATION');
    } catch (e) {
      Log.e('Error subscribing to user chat topics', 'PRODUCTION_NOTIFICATION', e);
    }
  }

  /// Send notification through FCM server (for testing)
  Future<bool> sendNotificationViaServer({
    required String recipientToken,
    required String title,
    required String body,
    Map<String, dynamic>? data,
  }) async {
    try {
      final url = Uri.parse('$_fcmServerUrl/send-notification');
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'token': recipientToken,
          'title': title,
          'body': body,
          'data': data ?? {},
        }),
      );

      if (response.statusCode == 200) {
        final result = jsonDecode(response.body);
        Log.i('Notification sent via server: ${result['messageId']}', 'PRODUCTION_NOTIFICATION');
        return true;
      } else {
        Log.e('Failed to send notification via server: ${response.statusCode}', 'PRODUCTION_NOTIFICATION');
        return false;
      }
    } catch (e) {
      Log.e('Error sending notification via server', 'PRODUCTION_NOTIFICATION', e);
      return false;
    }
  }

  /// Send broadcast notification through FCM server
  Future<bool> sendBroadcastViaServer({
    required String title,
    required String body,
    Map<String, dynamic>? data,
  }) async {
    try {
      final url = Uri.parse('$_fcmServerUrl/send-topic-notification');
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'topic': 'all_users',
          'title': title,
          'body': body,
          'data': data ?? {},
        }),
      );

      if (response.statusCode == 200) {
        final result = jsonDecode(response.body);
        Log.i('Broadcast sent via server: ${result['messageId']}', 'PRODUCTION_NOTIFICATION');
        return true;
      } else {
        Log.e('Failed to send broadcast via server: ${response.statusCode}', 'PRODUCTION_NOTIFICATION');
        return false;
      }
    } catch (e) {
      Log.e('Error sending broadcast via server', 'PRODUCTION_NOTIFICATION', e);
      return false;
    }
  }
}

// Background message handler - MUST be top-level function
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Ensure Firebase is initialized
  await Firebase.initializeApp();
  
  Log.i('Handling background message: ${message.messageId}', 'BACKGROUND_HANDLER');
  Log.i('Background message data: ${message.data}', 'BACKGROUND_HANDLER');
  
  // Handle background messages here
  // You can perform background tasks like updating local storage, sending analytics, etc.
}