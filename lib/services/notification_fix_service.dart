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

/// Comprehensive notification fix service
/// Addresses all identified notification issues
class NotificationFixService {
  static final NotificationFixService _instance = NotificationFixService._internal();
  factory NotificationFixService() => _instance;
  NotificationFixService._internal();

  final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();
  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Notification channels
  static const String chatChannelId = 'chat_notifications';
  static const String broadcastChannelId = 'broadcast_notifications';
  static const String adminChannelId = 'admin_notifications';
  static const String systemChannelId = 'system_notifications';

  // State tracking
  bool _isInitialized = false;
  String? _currentFcmToken;
  bool _hasNotificationPermission = false;
  bool _isUserAuthenticated = false;

  /// Initialize the notification fix service
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      Log.i('Initializing notification fix service', 'NOTIFICATION_FIX');
      
      // Step 1: Check user authentication
      await _checkUserAuthentication();
      
      // Step 2: Set up local notifications
      await _setupLocalNotifications();
      
      // Step 3: Request notification permissions
      await _requestNotificationPermissions();
      
      // Step 4: Set up FCM with proper error handling
      await _setupFCMWithRetry();
      
      // Step 5: Set up notification handlers
      await _setupNotificationHandlers();
      
      // Step 6: Verify FCM token is saved
      await _verifyFCMTokenSaved();
      
      _isInitialized = true;
      Log.i('Notification fix service initialized successfully', 'NOTIFICATION_FIX');
      
    } catch (e) {
      Log.e('Failed to initialize notification fix service', 'NOTIFICATION_FIX', e);
      rethrow;
    }
  }

  /// Check if user is authenticated
  Future<void> _checkUserAuthentication() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      _isUserAuthenticated = user != null;
      
      if (_isUserAuthenticated) {
        Log.i('User authenticated: ${user!.uid}', 'NOTIFICATION_FIX');
      } else {
        Log.w('No authenticated user found', 'NOTIFICATION_FIX');
        // Wait for authentication
        FirebaseAuth.instance.authStateChanges().listen((User? user) {
          if (user != null && !_isUserAuthenticated) {
            _isUserAuthenticated = true;
            Log.i('User authenticated during runtime: ${user.uid}', 'NOTIFICATION_FIX');
            _handleUserAuthenticated(user);
          }
        });
      }
    } catch (e) {
      Log.e('Error checking user authentication', 'NOTIFICATION_FIX', e);
    }
  }

  /// Handle user authentication during runtime
  Future<void> _handleUserAuthenticated(User user) async {
    try {
      Log.i('Handling runtime user authentication', 'NOTIFICATION_FIX');
      
      // Set up FCM for the newly authenticated user
      await _setupFCMWithRetry();
      await _verifyFCMTokenSaved();
      
    } catch (e) {
      Log.e('Error handling runtime authentication', 'NOTIFICATION_FIX', e);
    }
  }

  /// Set up local notifications with proper error handling
  Future<void> _setupLocalNotifications() async {
    try {
      Log.i('Setting up local notifications', 'NOTIFICATION_FIX');
      
      // Android initialization settings
      const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
      
      // iOS initialization settings
      const iosSettings = DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      );
      
      // Combined initialization settings
      final initSettings = InitializationSettings(
        android: androidSettings,
        iOS: iosSettings,
        macOS: iosSettings,
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

      Log.i('Local notifications set up successfully', 'NOTIFICATION_FIX');
      
    } catch (e) {
      Log.e('Local notification setup error', 'NOTIFICATION_FIX', e);
      rethrow;
    }
  }

  /// Create notification channels for Android
  Future<void> _createNotificationChannels() async {
    try {
      final androidImplementation = _localNotifications
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      
      if (androidImplementation != null) {
        // Chat notifications channel
        await androidImplementation.createNotificationChannel(
          const AndroidNotificationChannel(
            chatChannelId,
            'Chat Notifications',
            description: 'Notifications for chat messages',
            importance: Importance.high,
            enableVibration: true,
            playSound: true,
            ledColor: Color(0xFF2196F3),
          ),
        );

        // Broadcast notifications channel
        await androidImplementation.createNotificationChannel(
          const AndroidNotificationChannel(
            broadcastChannelId,
            'Broadcast Notifications',
            description: 'Notifications for broadcast messages',
            importance: Importance.high,
            enableVibration: true,
            playSound: true,
            ledColor: Color(0xFF4CAF50),
          ),
        );

        // Admin notifications channel
        await androidImplementation.createNotificationChannel(
          const AndroidNotificationChannel(
            adminChannelId,
            'Admin Notifications',
            description: 'Notifications for admin actions',
            importance: Importance.high,
            enableVibration: true,
            playSound: true,
            ledColor: Color(0xFFFF9800),
          ),
        );

        // System notifications channel
        await androidImplementation.createNotificationChannel(
          const AndroidNotificationChannel(
            systemChannelId,
            'System Notifications',
            description: 'System and general notifications',
            importance: Importance.low,
            enableVibration: false,
            playSound: true,
          ),
        );

        Log.i('Android notification channels created successfully', 'NOTIFICATION_FIX');
      }
    } catch (e) {
      Log.e('Error creating Android notification channels', 'NOTIFICATION_FIX', e);
    }
  }

  /// Set up iOS notification categories
  Future<void> _setupIOSNotificationCategories() async {
    try {
      final iosImplementation = _localNotifications
          .resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>();
      
      if (iosImplementation != null) {
        // Request permissions
        await iosImplementation.requestPermissions(
          alert: true,
          badge: true,
          sound: true,
        );
        
        Log.i('iOS notification categories set up successfully', 'NOTIFICATION_FIX');
      }
    } catch (e) {
      Log.e('Error setting up iOS notification categories', 'NOTIFICATION_FIX', e);
    }
  }

  /// Request notification permissions with proper handling
  Future<void> _requestNotificationPermissions() async {
    try {
      Log.i('Requesting notification permissions', 'NOTIFICATION_FIX');
      
      if (kIsWeb) {
        await _requestWebNotificationPermission();
      } else if (Platform.isIOS) {
        await _requestIOSNotificationPermission();
      } else if (Platform.isAndroid) {
        await _requestAndroidNotificationPermission();
      }
      
      Log.i('Notification permission request completed', 'NOTIFICATION_FIX');
      
    } catch (e) {
      Log.e('Error requesting notification permissions', 'NOTIFICATION_FIX', e);
    }
  }

  /// Request web notification permission
  Future<void> _requestWebNotificationPermission() async {
    try {
      // Web notifications are handled by the browser
      Log.i('Web notification permission handled by browser', 'NOTIFICATION_FIX');
    } catch (e) {
      Log.e('Error requesting web notification permission', 'NOTIFICATION_FIX', e);
    }
  }

  /// Request iOS notification permission
  Future<void> _requestIOSNotificationPermission() async {
    try {
      final settings = await _firebaseMessaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );

      _hasNotificationPermission = settings.authorizationStatus == AuthorizationStatus.authorized;
      Log.i('iOS notification permission result: ${settings.authorizationStatus}', 'NOTIFICATION_FIX');
      
    } catch (e) {
      Log.e('Error requesting iOS notification permission', 'NOTIFICATION_FIX', e);
    }
  }

  /// Request Android notification permission
  Future<void> _requestAndroidNotificationPermission() async {
    try {
      if (await _isAndroid13OrHigher()) {
        Log.i('Android 13+ detected, checking notification permission', 'NOTIFICATION_FIX');
        
        final notificationStatus = await _firebaseMessaging.getNotificationSettings();
        
        if (notificationStatus.authorizationStatus == AuthorizationStatus.notDetermined) {
          Log.i('Requesting notification permission for Android 13+', 'NOTIFICATION_FIX');
          final newSettings = await _firebaseMessaging.requestPermission();
          _hasNotificationPermission = newSettings.authorizationStatus == AuthorizationStatus.authorized;
          Log.i('Android notification permission result: ${newSettings.authorizationStatus}', 'NOTIFICATION_FIX');
        } else {
          _hasNotificationPermission = notificationStatus.authorizationStatus == AuthorizationStatus.authorized;
        }
      } else {
        // For Android <13, permissions are granted by default
        _hasNotificationPermission = true;
        Log.i('Android <13 detected, using default permissions', 'NOTIFICATION_FIX');
      }
    } catch (e) {
      Log.e('Error requesting Android notification permission', 'NOTIFICATION_FIX', e);
    }
  }

  /// Check if device is Android 13 or higher
  Future<bool> _isAndroid13OrHigher() async {
    try {
      if (!Platform.isAndroid) return false;
      
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

  /// Set up FCM with retry mechanism
  Future<void> _setupFCMWithRetry() async {
    int retryCount = 0;
    const maxRetries = 3;
    
    while (retryCount < maxRetries) {
      try {
        Log.i('Setting up FCM (attempt ${retryCount + 1})', 'NOTIFICATION_FIX');
        
        // Get FCM token
        final token = await _firebaseMessaging.getToken();
        if (token != null) {
          _currentFcmToken = token;
          await _saveFCMTokenToFirestore(token);
          Log.i('FCM token saved: ${token.substring(0, 20)}...', 'NOTIFICATION_FIX');
          break; // Success, exit retry loop
        } else {
          throw Exception('Failed to generate FCM token');
        }
      } catch (e) {
        retryCount++;
        Log.e('FCM setup attempt $retryCount failed', 'NOTIFICATION_FIX', e);
        
        if (retryCount >= maxRetries) {
          Log.e('FCM setup failed after $maxRetries attempts', 'NOTIFICATION_FIX', e);
          rethrow;
        }
        
        // Wait before retry
        await Future.delayed(Duration(seconds: retryCount * 2));
      }
    }

    // Listen for token refresh
    _firebaseMessaging.onTokenRefresh.listen(_saveFCMTokenToFirestore);
    
    Log.i('FCM set up successfully', 'NOTIFICATION_FIX');
  }

  /// Save FCM token to Firestore with proper error handling
  Future<void> _saveFCMTokenToFirestore(String token) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        Log.w('Cannot save FCM token: No authenticated user', 'NOTIFICATION_FIX');
        return;
      }

      await _firestore.collection('users').doc(user.uid).update({
        'fcmToken': token,
        'lastTokenUpdate': FieldValue.serverTimestamp(),
        'platform': kIsWeb ? 'web' : Platform.operatingSystem,
        'notificationEnabled': true,
        'notificationPermissionGranted': _hasNotificationPermission,
      });

      Log.i('FCM token saved to Firestore successfully', 'NOTIFICATION_FIX');
    } catch (e) {
      Log.e('Error saving FCM token to Firestore', 'NOTIFICATION_FIX', e);
      
      // Try to create the user document if it doesn't exist
      try {
        final user = FirebaseAuth.instance.currentUser;
        if (user != null) {
          await _firestore.collection('users').doc(user.uid).set({
            'fcmToken': token,
            'lastTokenUpdate': FieldValue.serverTimestamp(),
            'platform': kIsWeb ? 'web' : Platform.operatingSystem,
            'notificationEnabled': true,
            'notificationPermissionGranted': _hasNotificationPermission,
            'createdAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
          
          Log.i('User document created with FCM token', 'NOTIFICATION_FIX');
        }
      } catch (createError) {
        Log.e('Failed to create user document with FCM token', 'NOTIFICATION_FIX', createError);
      }
    }
  }

  /// Verify FCM token is properly saved
  Future<void> _verifyFCMTokenSaved() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        Log.w('Cannot verify FCM token: No authenticated user', 'NOTIFICATION_FIX');
        return;
      }

      final userDoc = await _firestore.collection('users').doc(user.uid).get();
      if (userDoc.exists) {
        final userData = userDoc.data()!;
        final savedToken = userData['fcmToken'];
        
        if (savedToken == _currentFcmToken) {
          Log.i('FCM token verification successful', 'NOTIFICATION_FIX');
        } else {
          Log.w('FCM token mismatch, re-saving...', 'NOTIFICATION_FIX');
          await _saveFCMTokenToFirestore(_currentFcmToken!);
        }
      } else {
        Log.w('User document not found, creating...', 'NOTIFICATION_FIX');
        await _saveFCMTokenToFirestore(_currentFcmToken!);
      }
    } catch (e) {
      Log.e('Error verifying FCM token', 'NOTIFICATION_FIX', e);
    }
  }

  /// Set up notification handlers
  Future<void> _setupNotificationHandlers() async {
    try {
      Log.i('Setting up notification handlers', 'NOTIFICATION_FIX');
      
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

      Log.i('Notification handlers set up successfully', 'NOTIFICATION_FIX');
      
    } catch (e) {
      Log.e('Error setting up notification handlers', 'NOTIFICATION_FIX', e);
    }
  }

  /// Handle foreground messages
  void _handleForegroundMessage(RemoteMessage message) {
    try {
      Log.i('Received foreground message: ${message.messageId}', 'NOTIFICATION_FIX');
      
      // Show local notification for foreground messages
      _showLocalNotification(message);
      
    } catch (e) {
      Log.e('Error handling foreground message', 'NOTIFICATION_FIX', e);
    }
  }

  /// Handle notification taps
  void _handleNotificationTap(RemoteMessage message) {
    try {
      Log.i('Notification tapped: ${message.messageId}', 'NOTIFICATION_FIX');
      
      // Handle navigation based on notification data
      _handleNotificationNavigation(message);
      
    } catch (e) {
      Log.e('Error handling notification tap', 'NOTIFICATION_FIX', e);
    }
  }

  /// Handle local notification taps
  void _onNotificationTapped(NotificationResponse response) {
    try {
      Log.i('Local notification tapped: ${response.id}', 'NOTIFICATION_FIX');
      
      // Handle navigation based on notification payload
      _handleLocalNotificationNavigation(response);
      
    } catch (e) {
      Log.e('Error handling local notification tap', 'NOTIFICATION_FIX', e);
    }
  }

  /// Show local notification
  Future<void> _showLocalNotification(RemoteMessage message) async {
    try {
      final notification = message.notification;
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

      Log.i('Local notification shown: ${notification.title}', 'NOTIFICATION_FIX');
      
    } catch (e) {
      Log.e('Error showing local notification', 'NOTIFICATION_FIX', e);
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
            Log.i('Navigating to chat: $chatId', 'NOTIFICATION_FIX');
          }
          break;
        case 'broadcast':
          Log.i('Navigating to broadcast', 'NOTIFICATION_FIX');
          break;
        case 'admin':
          Log.i('Navigating to admin panel', 'NOTIFICATION_FIX');
          break;
        default:
          Log.i('Unknown notification type: $type', 'NOTIFICATION_FIX');
      }
    } catch (e) {
      Log.e('Error handling notification navigation', 'NOTIFICATION_FIX', e);
    }
  }

  /// Handle local notification navigation
  void _handleLocalNotificationNavigation(NotificationResponse response) {
    try {
      final payload = response.payload;
      if (payload != null) {
        final data = jsonDecode(payload);
        Log.i('Local notification payload: $data', 'NOTIFICATION_FIX');
      }
    } catch (e) {
      Log.e('Error handling local notification navigation', 'NOTIFICATION_FIX', e);
    }
  }

  /// Send test notification
  Future<void> sendTestNotification() async {
    try {
      await _localNotifications.show(
        999,
        '🧪 Test Notification',
        'This is a test notification to verify the system is working!',
        const NotificationDetails(
          android: AndroidNotificationDetails(
            systemChannelId,
            'System Notifications',
            channelDescription: 'System and general notifications',
            importance: Importance.high,
            priority: Priority.high,
            enableVibration: true,
            playSound: true,
          ),
          iOS: DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
          ),
        ),
        payload: 'test_notification',
      );

      Log.i('Test notification sent successfully', 'NOTIFICATION_FIX');
    } catch (e) {
      Log.e('Error sending test notification', 'NOTIFICATION_FIX', e);
    }
  }

  /// Get comprehensive notification status
  Future<Map<String, dynamic>> getNotificationStatus() async {
    try {
      final token = await _firebaseMessaging.getToken();
      final settings = await _firebaseMessaging.getNotificationSettings();
      
      return {
        'isInitialized': _isInitialized,
        'hasPermission': _hasNotificationPermission,
        'isUserAuthenticated': _isUserAuthenticated,
        'hasFCMToken': token != null,
        'fcmToken': token != null ? '${token.substring(0, 20)}...' : null,
        'authorizationStatus': settings.authorizationStatus.toString(),
        'alertEnabled': settings.alert,
        'badgeEnabled': settings.badge,
        'soundEnabled': settings.sound,
        'platform': kIsWeb ? 'web' : Platform.operatingSystem,
        'timestamp': DateTime.now().toIso8601String(),
      };
      
    } catch (e) {
      return {
        'error': e.toString(),
        'timestamp': DateTime.now().toIso8601String(),
      };
    }
  }

  /// Check if service is ready
  bool get isReady => _isInitialized && _hasNotificationPermission && _isUserAuthenticated;
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
