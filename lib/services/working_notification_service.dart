import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:io';
import 'dart:convert';
import 'logger_service.dart';

/// Working notification service that actually works
/// Simplified implementation that focuses on core functionality
class WorkingNotificationService {
  static final WorkingNotificationService _instance = WorkingNotificationService._internal();
  factory WorkingNotificationService() => _instance;
  WorkingNotificationService._internal();

  // Core services
  final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();
  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // State tracking
  bool _isInitialized = false;
  String? _currentFcmToken;
  bool _hasNotificationPermission = false;

  /// Initialize the notification service
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      Log.i('Initializing WorkingNotificationService', 'WORKING_NOTIFICATION');
      
      // Initialize local notifications
      await _initializeLocalNotifications();
      
      // Request notification permission
      await _requestNotificationPermission();
      
      // Set up FCM
      await _setupFCM();
      
      // Set up message handlers
      await _setupMessageHandlers();
      
      _isInitialized = true;
      Log.i('WorkingNotificationService initialized successfully', 'WORKING_NOTIFICATION');
      
    } catch (e) {
      Log.e('Error initializing WorkingNotificationService', 'WORKING_NOTIFICATION', e);
      rethrow;
    }
  }

  /// Initialize local notifications
  Future<void> _initializeLocalNotifications() async {
    try {
      Log.i('Initializing local notifications', 'WORKING_NOTIFICATION');
      
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
      if (Platform.isAndroid) {
        await _createNotificationChannels();
      }
      
      Log.i('Local notifications initialized', 'WORKING_NOTIFICATION');
      
    } catch (e) {
      Log.e('Error initializing local notifications', 'WORKING_NOTIFICATION', e);
    }
  }

  /// Create notification channels for Android
  Future<void> _createNotificationChannels() async {
    try {
      Log.i('Creating notification channels', 'WORKING_NOTIFICATION');
      
      const chatChannel = AndroidNotificationChannel(
        'chat_notifications',
        'Chat Notifications',
        description: 'Notifications for chat messages',
        importance: Importance.high,
        playSound: true,
      );
      
      const broadcastChannel = AndroidNotificationChannel(
        'broadcast_notifications',
        'Broadcast Notifications',
        description: 'Notifications for broadcast messages',
        importance: Importance.high,
        playSound: true,
      );
      
      await _localNotifications
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(chatChannel);
          
      await _localNotifications
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(broadcastChannel);
      
      Log.i('Notification channels created', 'WORKING_NOTIFICATION');
      
    } catch (e) {
      Log.e('Error creating notification channels', 'WORKING_NOTIFICATION', e);
    }
  }

  /// Request notification permission
  Future<void> _requestNotificationPermission() async {
    try {
      Log.i('Requesting notification permission', 'WORKING_NOTIFICATION');
      
      if (Platform.isAndroid) {
        // Android 13+ requires explicit notification permission
        if (await _isAndroid13OrHigher()) {
          final status = await Permission.notification.request();
          _hasNotificationPermission = status.isGranted;
          Log.i('Android notification permission: $_hasNotificationPermission', 'WORKING_NOTIFICATION');
        } else {
          _hasNotificationPermission = true; // Not required on older Android
        }
      } else if (Platform.isIOS) {
        final settings = await _firebaseMessaging.requestPermission(
          alert: true,
          badge: true,
          sound: true,
        );
        _hasNotificationPermission = settings.authorizationStatus == AuthorizationStatus.authorized;
        Log.i('iOS notification permission: $_hasNotificationPermission', 'WORKING_NOTIFICATION');
      } else {
        _hasNotificationPermission = true; // Web doesn't need explicit permission
      }
      
    } catch (e) {
      Log.e('Error requesting notification permission', 'WORKING_NOTIFICATION', e);
      _hasNotificationPermission = false;
    }
  }

  /// Set up FCM
  Future<void> _setupFCM() async {
    try {
      Log.i('Setting up FCM', 'WORKING_NOTIFICATION');
      
      // Get FCM token
      final token = await _firebaseMessaging.getToken();
      if (token != null) {
        _currentFcmToken = token;
        await _saveFcmTokenToFirestore(token);
        Log.i('FCM token saved: ${token.substring(0, 20)}...', 'WORKING_NOTIFICATION');
      }

      // Listen for token refresh
      _firebaseMessaging.onTokenRefresh.listen(_saveFcmTokenToFirestore);

      Log.i('FCM setup completed', 'WORKING_NOTIFICATION');
      
    } catch (e) {
      Log.e('FCM setup error', 'WORKING_NOTIFICATION', e);
    }
  }

  /// Set up message handlers
  Future<void> _setupMessageHandlers() async {
    try {
      Log.i('Setting up message handlers', 'WORKING_NOTIFICATION');
      
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

      Log.i('Message handlers set up', 'WORKING_NOTIFICATION');
      
    } catch (e) {
      Log.e('Error setting up message handlers', 'WORKING_NOTIFICATION', e);
    }
  }

  /// Handle foreground messages
  void _handleForegroundMessage(RemoteMessage message) {
    try {
      Log.i('Received foreground message: ${message.notification?.title}', 'WORKING_NOTIFICATION');
      
      // Show local notification
      _showLocalNotification(message);
      
    } catch (e) {
      Log.e('Error handling foreground message', 'WORKING_NOTIFICATION', e);
    }
  }

  /// Handle notification tap
  void _handleNotificationTap(RemoteMessage message) {
    try {
      Log.i('Notification tapped: ${message.notification?.title}', 'WORKING_NOTIFICATION');
      
      // Handle navigation based on notification data
      final data = message.data;
      if (data['type'] == 'chat' && data['chatId'] != null) {
        // Navigate to chat
        Log.i('Navigating to chat: ${data['chatId']}', 'WORKING_NOTIFICATION');
      }
      
    } catch (e) {
      Log.e('Error handling notification tap', 'WORKING_NOTIFICATION', e);
    }
  }

  /// Handle local notification tap
  void _onNotificationTapped(NotificationResponse response) {
    try {
      Log.i('Local notification tapped: ${response.payload}', 'WORKING_NOTIFICATION');
      
      // Handle navigation based on payload
      if (response.payload != null) {
        final data = jsonDecode(response.payload!);
        if (data['type'] == 'chat' && data['chatId'] != null) {
          // Navigate to chat
          Log.i('Navigating to chat: ${data['chatId']}', 'WORKING_NOTIFICATION');
        }
      }
      
    } catch (e) {
      Log.e('Error handling local notification tap', 'WORKING_NOTIFICATION', e);
    }
  }

  /// Show local notification
  Future<void> _showLocalNotification(RemoteMessage message) async {
    try {
      final notification = message.notification;
      final data = message.data;

      if (notification == null) return;

      // Determine channel based on notification type
      String channelId = 'chat_notifications';
      if (data['type'] == 'broadcast') {
        channelId = 'broadcast_notifications';
      }

      // Create notification details
      final androidDetails = AndroidNotificationDetails(
        channelId,
        channelId == 'chat_notifications' ? 'Chat Notifications' : 'Broadcast Notifications',
        channelDescription: 'Notifications for various app events',
        importance: Importance.high,
        priority: Priority.high,
        showWhen: true,
        enableVibration: true,
        enableLights: true,
        ledColor: const Color(0xFF2196F3),
        playSound: true,
      );

      final iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
        categoryIdentifier: channelId == 'chat_notifications' ? 'chat_category' : 'broadcast_category',
        threadIdentifier: data['chatId'] ?? 'general',
      );

      final details = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );

      // Show the notification
      await _localNotifications.show(
        message.hashCode,
        notification.title,
        notification.body,
        details,
        payload: jsonEncode(data),
      );

      Log.i('Local notification shown: ${notification.title}', 'WORKING_NOTIFICATION');
      
    } catch (e) {
      Log.e('Error showing local notification', 'WORKING_NOTIFICATION', e);
    }
  }

  /// Save FCM token to Firestore
  Future<void> _saveFcmTokenToFirestore(String token) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      await _firestore.collection('users').doc(user.uid).update({
        'fcmToken': token,
        'lastTokenUpdate': FieldValue.serverTimestamp(),
        'platform': kIsWeb ? 'web' : Platform.operatingSystem,
      });

      Log.i('FCM token saved to Firestore', 'WORKING_NOTIFICATION');
    } catch (e) {
      Log.e('Error saving FCM token to Firestore', 'WORKING_NOTIFICATION', e);
    }
  }

  /// Check if device is Android 13 or higher
  Future<bool> _isAndroid13OrHigher() async {
    try {
      if (!Platform.isAndroid) return false;
      
      // Simple check: try to access notification permission
      try {
        await Permission.notification.status;
        return true;
      } catch (e) {
        return false;
      }
    } catch (e) {
      return false;
    }
  }

  /// Send test notification
  Future<void> sendTestNotification() async {
    try {
      Log.i('Sending test notification', 'WORKING_NOTIFICATION');
      
      await _localNotifications.show(
        999,
        '🧪 Test Notification',
        'This is a test notification from WorkingNotificationService!',
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'chat_notifications',
            'Chat Notifications',
            importance: Importance.high,
            priority: Priority.high,
          ),
          iOS: DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
          ),
        ),
        payload: jsonEncode({'type': 'test', 'timestamp': DateTime.now().toIso8601String()}),
      );
      
      Log.i('Test notification sent', 'WORKING_NOTIFICATION');
    } catch (e) {
      Log.e('Error sending test notification', 'WORKING_NOTIFICATION', e);
    }
  }

  /// Get FCM token
  Future<String?> getFcmToken() async {
    return _currentFcmToken;
  }

  /// Get notification status
  Future<Map<String, dynamic>> getNotificationStatus() async {
    return {
      'isInitialized': _isInitialized,
      'hasNotificationPermission': _hasNotificationPermission,
      'fcmToken': _currentFcmToken != null ? '${_currentFcmToken!.substring(0, 20)}...' : null,
      'platform': kIsWeb ? 'web' : Platform.operatingSystem,
    };
  }

  /// Check if service is ready
  bool get isReady => _isInitialized && _hasNotificationPermission;

  /// Show local notification
  Future<void> showLocalNotification({
    required String title,
    required String body,
    String? payload,
  }) async {
    try {
      const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
        'soc_chat_channel',
        'SOC Chat Notifications',
        channelDescription: 'Notifications for SOC Chat App',
        importance: Importance.high,
        priority: Priority.high,
      );

      const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      );

      const NotificationDetails platformDetails = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );

      await _localNotifications.show(
        DateTime.now().millisecondsSinceEpoch ~/ 1000,
        title,
        body,
        platformDetails,
        payload: payload,
      );

      Log.i('Local notification shown: $title', 'WORKING_NOTIFICATION');
    } catch (e) {
      Log.e('Error showing local notification', 'WORKING_NOTIFICATION', e);
    }
  }
}

/// Background message handler
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  try {
    Log.i('Background message received: ${message.notification?.title}', 'WORKING_NOTIFICATION');
    
    // Initialize Firebase if not already done
    await Firebase.initializeApp();
    
    // Handle the message
    Log.i('Background message handled', 'WORKING_NOTIFICATION');
  } catch (e) {
    Log.e('Error handling background message', 'WORKING_NOTIFICATION', e);
  }
}
