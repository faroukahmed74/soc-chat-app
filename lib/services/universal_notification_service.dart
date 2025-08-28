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

/// Universal notification service for Android, iOS, and Web
/// Handles FCM, local notifications, and proper permission management
class UniversalNotificationService {
  static final UniversalNotificationService _instance = UniversalNotificationService._internal();
  factory UniversalNotificationService() => _instance;
  UniversalNotificationService._internal();

  // Core services
  final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();
  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Notification channels for Android
  static const String chatChannelId = 'chat_notifications';
  static const String broadcastChannelId = 'broadcast_notifications';
  static const String adminChannelId = 'admin_notifications';
  static const String systemChannelId = 'system_notifications';

  // FCM Server Configuration
  static const String _fcmServerUrl = 'http://localhost:3000';
  static const String _fcmServerUrlProduction = 'https://your-production-server.com';

  // State tracking
  bool _isInitialized = false;
  String? _currentFcmToken;
  bool _hasNotificationPermission = false;

  /// Initialize the universal notification service
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      Log.i('Initializing universal notification service', 'UNIVERSAL_NOTIFICATION');
      
      if (kIsWeb) {
        await _initializeWebNotifications();
      } else {
        await _initializeMobileNotifications();
      }
      
      _isInitialized = true;
      Log.i('Universal notification service initialized successfully', 'UNIVERSAL_NOTIFICATION');
    } catch (e) {
      Log.e('Failed to initialize universal notification service', 'UNIVERSAL_NOTIFICATION', e);
      rethrow;
    }
  }

  /// Initialize mobile notifications (Android & iOS)
  Future<void> _initializeMobileNotifications() async {
    try {
      // Step 1: Set up local notifications
      await _setupLocalNotifications();
      
      // Step 2: Request notification permissions
      await _requestNotificationPermissions();
      
      // Step 3: Set up FCM
      await _setupFCM();
      
      // Step 4: Set up notification handlers
      await _setupNotificationHandlers();
      
    } catch (e) {
      Log.e('Mobile notification setup error', 'UNIVERSAL_NOTIFICATION', e);
      rethrow;
    }
  }

  /// Initialize web notifications
  Future<void> _initializeWebNotifications() async {
    try {
      Log.i('Initializing web notifications', 'UNIVERSAL_NOTIFICATION');
      
      // Step 1: Request web notification permission
      await _requestWebNotificationPermission();
      
      // Step 2: Set up FCM for web
      await _setupFCM();
      
      // Step 3: Set up web notification handlers
      await _setupWebNotificationHandlers();
      
    } catch (e) {
      Log.e('Web notification setup error', 'UNIVERSAL_NOTIFICATION', e);
      rethrow;
    }
  }

  /// Request notification permissions for mobile platforms
  Future<void> _requestNotificationPermissions() async {
    try {
      if (Platform.isIOS) {
        await _requestIOSNotificationPermission();
      } else if (Platform.isAndroid) {
        await _requestAndroidNotificationPermission();
      }
    } catch (e) {
      Log.e('Error requesting notification permissions', 'UNIVERSAL_NOTIFICATION', e);
    }
  }

  /// Request iOS notification permission
  Future<void> _requestIOSNotificationPermission() async {
    try {
      Log.i('Requesting iOS notification permission', 'UNIVERSAL_NOTIFICATION');
      
      // Request Firebase Messaging permission
      final settings = await _firebaseMessaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
        criticalAlert: false,
        announcement: false,
      );

      Log.i('iOS notification permission result: ${settings.authorizationStatus}', 'UNIVERSAL_NOTIFICATION');

      if (settings.authorizationStatus == AuthorizationStatus.authorized) {
        _hasNotificationPermission = true;
        Log.i('iOS notifications authorized', 'UNIVERSAL_NOTIFICATION');
      } else {
        _hasNotificationPermission = false;
        Log.w('iOS notifications not authorized: ${settings.authorizationStatus}', 'UNIVERSAL_NOTIFICATION');
      }
    } catch (e) {
      Log.e('iOS notification permission error', 'UNIVERSAL_NOTIFICATION', e);
      _hasNotificationPermission = false;
    }
  }

  /// Request Android notification permission
  Future<void> _requestAndroidNotificationPermission() async {
    try {
      Log.i('Requesting Android notification permission', 'UNIVERSAL_NOTIFICATION');
      
      // Check if we're on Android 13+ (API 33+)
      if (await _isAndroid13OrHigher()) {
        Log.i('Android 13+ detected, requesting notification permission', 'UNIVERSAL_NOTIFICATION');
        
        // Request notification permission using permission_handler
        final status = await Permission.notification.request();
        _hasNotificationPermission = status.isGranted;
        
        Log.i('Android notification permission result: $status', 'UNIVERSAL_NOTIFICATION');
        
        if (!_hasNotificationPermission) {
          Log.w('Android notification permission denied', 'UNIVERSAL_NOTIFICATION');
        }
      } else {
        // For Android <13, notification permission is granted by default
        _hasNotificationPermission = true;
        Log.i('Android <13 detected, notification permission granted by default', 'UNIVERSAL_NOTIFICATION');
      }
    } catch (e) {
      Log.e('Android notification permission error', 'UNIVERSAL_NOTIFICATION', e);
      _hasNotificationPermission = false;
    }
  }

  /// Request web notification permission
  Future<void> _requestWebNotificationPermission() async {
    try {
      Log.i('Requesting web notification permission', 'UNIVERSAL_NOTIFICATION');
      
      // Check if Notification API is supported
      if (!kIsWeb) return;
      
      // Request permission using Firebase Messaging
      final settings = await _firebaseMessaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );

      _hasNotificationPermission = settings.authorizationStatus == AuthorizationStatus.authorized;
      
      Log.i('Web notification permission result: ${settings.authorizationStatus}', 'UNIVERSAL_NOTIFICATION');
      
    } catch (e) {
      Log.e('Web notification permission error', 'UNIVERSAL_NOTIFICATION', e);
      _hasNotificationPermission = false;
    }
  }

  /// Set up local notifications
  Future<void> _setupLocalNotifications() async {
    try {
      Log.i('Setting up local notifications', 'UNIVERSAL_NOTIFICATION');
      
      // Android initialization settings
      const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
      
      // iOS initialization settings
      const iosSettings = DarwinInitializationSettings(
        requestAlertPermission: false, // We handle this separately
        requestBadgePermission: false, // We handle this separately
        requestSoundPermission: false, // We handle this separately
      );
      
      // Combined initialization settings
      final initSettings = InitializationSettings(
        android: androidSettings,
        iOS: iosSettings,
        macOS: iosSettings, // Use iOS settings for macOS
      );

      // Initialize local notifications
      await _localNotifications.initialize(
        initSettings,
        onDidReceiveNotificationResponse: _onNotificationTapped,
      );

      // Create notification channels for Android
      if (Platform.isAndroid) {
        await _createNotificationChannels();
      }

      // Set up iOS notification categories
      if (Platform.isIOS) {
        await _setupIOSNotificationCategories();
      }

      Log.i('Local notifications set up successfully', 'UNIVERSAL_NOTIFICATION');
      
    } catch (e) {
      Log.e('Local notification setup error', 'UNIVERSAL_NOTIFICATION', e);
      rethrow;
    }
  }

  /// Create notification channels for Android
  Future<void> _createNotificationChannels() async {
    try {
      Log.i('Creating Android notification channels', 'UNIVERSAL_NOTIFICATION');
      
      // Chat notifications channel
      const chatChannel = AndroidNotificationChannel(
        chatChannelId,
        'Chat Notifications',
        description: 'Notifications for chat messages and conversations',
        importance: Importance.high,
        playSound: true,
        enableVibration: true,
        enableLights: true,
        ledColor: Color(0xFF2196F3),
      );

      // Broadcast notifications channel
      const broadcastChannel = AndroidNotificationChannel(
        broadcastChannelId,
        'Broadcast Notifications',
        description: 'Notifications for admin broadcasts and announcements',
        importance: Importance.defaultImportance,
        playSound: true,
        enableVibration: true,
      );

      // Admin notifications channel
      const adminChannel = AndroidNotificationChannel(
        adminChannelId,
        'Admin Notifications',
        description: 'Notifications for administrative actions and system updates',
        importance: Importance.high,
        playSound: true,
        enableVibration: true,
      );

      // System notifications channel
      const systemChannel = AndroidNotificationChannel(
        systemChannelId,
        'System Notifications',
        description: 'System notifications and updates',
        importance: Importance.low,
        playSound: false,
        enableVibration: false,
      );

      // Create all channels
      await _localNotifications
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(chatChannel);
          
      await _localNotifications
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(broadcastChannel);
          
      await _localNotifications
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(adminChannel);
          
      await _localNotifications
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(systemChannel);

      Log.i('Android notification channels created successfully', 'UNIVERSAL_NOTIFICATION');
      
    } catch (e) {
      Log.e('Error creating Android notification channels', 'UNIVERSAL_NOTIFICATION', e);
    }
  }

  /// Set up iOS notification categories
  Future<void> _setupIOSNotificationCategories() async {
    try {
      Log.i('Setting up iOS notification categories', 'UNIVERSAL_NOTIFICATION');
      
      // Chat notification category
      final chatCategory = DarwinNotificationCategory(
        'chat_category',
        actions: [
          DarwinNotificationAction.plain('reply', 'Reply'),
          DarwinNotificationAction.plain('mark_read', 'Mark as Read'),
        ],
        options: <DarwinNotificationCategoryOption>{
          DarwinNotificationCategoryOption.allowAnnouncement,
        },
      );

      // Broadcast notification category
      final broadcastCategory = DarwinNotificationCategory(
        'broadcast_category',
        actions: [
          DarwinNotificationAction.plain('view', 'View'),
          DarwinNotificationAction.plain('dismiss', 'Dismiss'),
        ],
        options: <DarwinNotificationCategoryOption>{
          DarwinNotificationCategoryOption.allowAnnouncement,
        },
      );

      // Set the categories
      await _localNotifications
          .resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>()
          ?.requestPermissions(
            alert: true,
            badge: true,
            sound: true,
          );

      Log.i('iOS notification categories set up successfully', 'UNIVERSAL_NOTIFICATION');
      
    } catch (e) {
      Log.e('Error setting up iOS notification categories', 'UNIVERSAL_NOTIFICATION', e);
    }
  }

  /// Set up FCM
  Future<void> _setupFCM() async {
    try {
      Log.i('Setting up FCM', 'UNIVERSAL_NOTIFICATION');
      
      // Get FCM token
      final token = await _firebaseMessaging.getToken();
      if (token != null) {
        _currentFcmToken = token;
        await _saveFcmTokenToFirestore(token);
        Log.i('FCM token saved: ${token.substring(0, 20)}...', 'UNIVERSAL_NOTIFICATION');
      }

      // Listen for token refresh
      _firebaseMessaging.onTokenRefresh.listen(_saveFcmTokenToFirestore);

      Log.i('FCM set up successfully', 'UNIVERSAL_NOTIFICATION');
      
    } catch (e) {
      Log.e('FCM setup error', 'UNIVERSAL_NOTIFICATION', e);
      rethrow;
    }
  }

  /// Set up notification handlers
  Future<void> _setupNotificationHandlers() async {
    try {
      Log.i('Setting up notification handlers', 'UNIVERSAL_NOTIFICATION');
      
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

      Log.i('Notification handlers set up successfully', 'UNIVERSAL_NOTIFICATION');
      
    } catch (e) {
      Log.e('Error setting up notification handlers', 'UNIVERSAL_NOTIFICATION', e);
    }
  }

  /// Set up web notification handlers
  Future<void> _setupWebNotificationHandlers() async {
    try {
      Log.i('Setting up web notification handlers', 'UNIVERSAL_NOTIFICATION');
      
      // Handle foreground messages
      FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

      // Handle notification taps
      FirebaseMessaging.onMessageOpenedApp.listen(_handleNotificationTap);

      Log.i('Web notification handlers set up successfully', 'UNIVERSAL_NOTIFICATION');
      
    } catch (e) {
      Log.e('Error setting up web notification handlers', 'UNIVERSAL_NOTIFICATION', e);
    }
  }

  /// Check if device is Android 13 or higher
  Future<bool> _isAndroid13OrHigher() async {
    try {
      if (!Platform.isAndroid) return false;
      
      // Simple check: try to access notification permission
      // If it works, we're on Android 13+
      try {
        await Permission.notification.status;
        Log.i('Notification permission available - Android 13+ detected', 'UNIVERSAL_NOTIFICATION');
        return true;
      } catch (e) {
        Log.i('Notification permission not available - Android <13 detected', 'UNIVERSAL_NOTIFICATION');
        return false;
      }
    } catch (e) {
      Log.w('Could not determine Android version, defaulting to legacy permissions', 'UNIVERSAL_NOTIFICATION');
      return false;
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

      Log.i('FCM token saved to Firestore', 'UNIVERSAL_NOTIFICATION');
    } catch (e) {
      Log.e('Error saving FCM token to Firestore', 'UNIVERSAL_NOTIFICATION', e);
    }
  }

  /// Handle foreground messages
  void _handleForegroundMessage(RemoteMessage message) {
    try {
      Log.i('Received foreground message: ${message.messageId}', 'UNIVERSAL_NOTIFICATION');
      
      // Show local notification for foreground messages
      _showLocalNotification(message);
      
    } catch (e) {
      Log.e('Error handling foreground message', 'UNIVERSAL_NOTIFICATION', e);
    }
  }

  /// Handle notification taps
  void _handleNotificationTap(RemoteMessage message) {
    try {
      Log.i('Notification tapped: ${message.messageId}', 'UNIVERSAL_NOTIFICATION');
      
      // Handle navigation based on notification data
      _handleNotificationNavigation(message);
      
    } catch (e) {
      Log.e('Error handling notification tap', 'UNIVERSAL_NOTIFICATION', e);
    }
  }

  /// Handle local notification taps
  void _onNotificationTapped(NotificationResponse response) {
    try {
      Log.i('Local notification tapped: ${response.id}', 'UNIVERSAL_NOTIFICATION');
      
      // Handle navigation based on notification payload
      _handleLocalNotificationNavigation(response);
      
    } catch (e) {
      Log.e('Error handling local notification tap', 'UNIVERSAL_NOTIFICATION', e);
    }
  }

  /// Show local notification
  Future<void> _showLocalNotification(RemoteMessage message) async {
    try {
      final notification = message.notification;
      final android = message.notification?.android;
      final data = message.data;

      if (notification == null) return;

      // Determine channel based on notification type
      String channelId = systemChannelId;
      if (data['type'] == 'chat') {
        channelId = chatChannelId;
      } else if (data['type'] == 'broadcast') {
        channelId = broadcastChannelId;
      } else if (data['type'] == 'admin') {
        channelId = adminChannelId;
      }

      // Create notification details
      final androidDetails = AndroidNotificationDetails(
        channelId,
        channelId == chatChannelId ? 'Chat Notifications' : 
        channelId == broadcastChannelId ? 'Broadcast Notifications' :
        channelId == adminChannelId ? 'Admin Notifications' : 'System Notifications',
        channelDescription: 'Notifications for various app events',
        importance: Importance.high,
        priority: Priority.high,
        showWhen: true,
        enableVibration: true,
        enableLights: true,
        ledColor: const Color(0xFF2196F3),
        playSound: true,
        sound: const RawResourceAndroidNotificationSound('notification_sound'),
        largeIcon: const DrawableResourceAndroidBitmap('@mipmap/ic_launcher'),
        styleInformation: const BigTextStyleInformation(''),
      );

      final iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
        categoryIdentifier: channelId == chatChannelId ? 'chat_category' : 
                           channelId == broadcastChannelId ? 'broadcast_category' : 'default',
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

      Log.i('Local notification shown: ${notification.title}', 'UNIVERSAL_NOTIFICATION');
      
    } catch (e) {
      Log.e('Error showing local notification', 'UNIVERSAL_NOTIFICATION', e);
    }
  }

  /// Handle notification navigation
  void _handleNotificationNavigation(RemoteMessage message) {
    try {
      final data = message.data;
      final type = data['type'];
      final chatId = data['chatId'];
      final userId = data['userId'];

      // Navigate based on notification type
      switch (type) {
        case 'chat':
          if (chatId != null) {
            // Navigate to chat
            Log.i('Navigating to chat: $chatId', 'UNIVERSAL_NOTIFICATION');
          }
          break;
        case 'broadcast':
          // Navigate to broadcast
          Log.i('Navigating to broadcast', 'UNIVERSAL_NOTIFICATION');
          break;
        case 'admin':
          // Navigate to admin panel
          Log.i('Navigating to admin panel', 'UNIVERSAL_NOTIFICATION');
          break;
        default:
          Log.i('Unknown notification type: $type', 'UNIVERSAL_NOTIFICATION');
      }
    } catch (e) {
      Log.e('Error handling notification navigation', 'UNIVERSAL_NOTIFICATION', e);
    }
  }

  /// Handle local notification navigation
  void _handleLocalNotificationNavigation(NotificationResponse response) {
    try {
      final payload = response.payload;
      if (payload == null) return;

      final data = jsonDecode(payload) as Map<String, dynamic>;
      final type = data['type'];
      final chatId = data['chatId'];

      // Navigate based on notification type
      switch (type) {
        case 'chat':
          if (chatId != null) {
            // Navigate to chat
            Log.i('Navigating to chat from local notification: $chatId', 'UNIVERSAL_NOTIFICATION');
          }
          break;
        default:
          Log.i('Unknown local notification type: $type', 'UNIVERSAL_NOTIFICATION');
      }
    } catch (e) {
      Log.e('Error handling local notification navigation', 'UNIVERSAL_NOTIFICATION', e);
    }
  }

  /// Send local notification
  Future<void> sendLocalNotification({
    required String title,
    required String body,
    String? payload,
    String channelId = systemChannelId,
    String? imageUrl,
  }) async {
    try {
      if (!_isInitialized) {
        Log.w('Notification service not initialized', 'UNIVERSAL_NOTIFICATION');
        return;
      }

      final androidDetails = AndroidNotificationDetails(
        channelId,
        channelId == chatChannelId ? 'Chat Notifications' : 
        channelId == broadcastChannelId ? 'Broadcast Notifications' :
        channelId == adminChannelId ? 'Admin Notifications' : 'System Notifications',
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
        categoryIdentifier: channelId == chatChannelId ? 'chat_category' : 
                           channelId == broadcastChannelId ? 'broadcast_category' : 'default',
      );

      final details = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );

      await _localNotifications.show(
        DateTime.now().millisecondsSinceEpoch ~/ 1000,
        title,
        body,
        details,
        payload: payload,
      );

      Log.i('Local notification sent: $title', 'UNIVERSAL_NOTIFICATION');
      
    } catch (e) {
      Log.e('Error sending local notification', 'UNIVERSAL_NOTIFICATION', e);
    }
  }

  /// Get current FCM token
  String? get currentFcmToken => _currentFcmToken;

  /// Check if notification permission is granted
  bool get hasNotificationPermission => _hasNotificationPermission;

  /// Check if service is initialized
  bool get isInitialized => _isInitialized;

  /// Request notification permission manually
  Future<bool> requestPermission() async {
    try {
      if (kIsWeb) {
        await _requestWebNotificationPermission();
      } else if (Platform.isIOS) {
        await _requestIOSNotificationPermission();
      } else if (Platform.isAndroid) {
        await _requestAndroidNotificationPermission();
      }
      
      return _hasNotificationPermission;
    } catch (e) {
      Log.e('Error requesting notification permission', 'UNIVERSAL_NOTIFICATION', e);
      return false;
    }
  }

  /// Get FCM token
  Future<String?> getFcmToken() async {
    try {
      if (_currentFcmToken == null) {
        _currentFcmToken = await _firebaseMessaging.getToken();
      }
      return _currentFcmToken;
    } catch (e) {
      Log.e('Error getting FCM token', 'UNIVERSAL_NOTIFICATION', e);
      return null;
    }
  }

  /// Request notification permission
  Future<bool> requestNotificationPermission() async {
    try {
      if (kIsWeb) {
        // Web notifications are handled by browser
        return true;
      }

      final settings = await _firebaseMessaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );

      _hasNotificationPermission = settings.authorizationStatus == AuthorizationStatus.authorized;
      Log.i('Notification permission result: ${settings.authorizationStatus}', 'UNIVERSAL_NOTIFICATION');
      
      return _hasNotificationPermission;
    } catch (e) {
      Log.e('Error requesting notification permission', 'UNIVERSAL_NOTIFICATION', e);
      return false;
    }
  }

  /// Get notification status
  Future<Map<String, dynamic>> getNotificationStatus() async {
    try {
      final status = <String, dynamic>{
        'isInitialized': _isInitialized,
        'hasPermission': _hasNotificationPermission,
        'platform': kIsWeb ? 'web' : Platform.operatingSystem,
        'fcmToken': _currentFcmToken != null ? '${_currentFcmToken!.substring(0, 20)}...' : null,
        'timestamp': DateTime.now().toIso8601String(),
      };

      if (Platform.isAndroid) {
        status['androidVersion'] = await _isAndroid13OrHigher() ? '13+' : '<13';
      }

      return status;
    } catch (e) {
      Log.e('Error getting notification status', 'UNIVERSAL_NOTIFICATION', e);
      return {
        'error': e.toString(),
        'timestamp': DateTime.now().toIso8601String(),
      };
    }
  }
}

/// Background message handler for FCM
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  try {
    // Initialize Firebase if needed
    await Firebase.initializeApp();
    
    Log.i('Handling background message: ${message.messageId}', 'BACKGROUND_NOTIFICATION');
    
    // You can perform background tasks here
    // For example, updating local storage, syncing data, etc.
    
  } catch (e) {
    Log.e('Error handling background message', 'BACKGROUND_NOTIFICATION', e);
  }
}
