import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../config/database_config.dart';
import 'logger_service.dart';
import 'enhanced_notification_service.dart';

/// FCM Service for handling Firebase Cloud Messaging tokens and background messages
/// Supports iOS, Android (all versions), and Web
class FCMService {
  static final FCMService _instance = FCMService._internal();
  factory FCMService() => _instance;
  FCMService._internal();

  FirebaseMessaging? _firebaseMessaging;
  String? _currentToken;
  String? _currentUserId;
  bool _isInitialized = false;
  StreamSubscription<String>? _tokenSubscription;

  /// Initialize FCM service
  Future<void> initialize() async {
    if (_isInitialized) {
      Log.i('FCM service already initialized', 'FCM_SERVICE');
      return;
    }

    if (kIsWeb) {
      // Web FCM initialization
      await _initializeWeb();
    } else {
      // Mobile FCM initialization
      await _initializeMobile();
    }

    _isInitialized = true;
    Log.i('✅ FCM service initialized', 'FCM_SERVICE');
  }

  /// Initialize FCM for mobile platforms (iOS and Android)
  Future<void> _initializeMobile() async {
    try {
      _firebaseMessaging = FirebaseMessaging.instance;

      // Request notification permissions
      NotificationSettings settings = await _firebaseMessaging!.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );

      if (settings.authorizationStatus == AuthorizationStatus.authorized) {
        Log.i('✅ FCM notification permission granted', 'FCM_SERVICE');
      } else if (settings.authorizationStatus == AuthorizationStatus.provisional) {
        Log.i('⚠️ FCM notification permission granted provisionally', 'FCM_SERVICE');
      } else {
        Log.w('❌ FCM notification permission denied', 'FCM_SERVICE');
      }

      // Get initial token
      await _getToken();

      // Listen for token refresh
      _tokenSubscription = _firebaseMessaging!.onTokenRefresh.listen(
        (newToken) {
          Log.i('FCM token refreshed: $newToken', 'FCM_SERVICE');
          _currentToken = newToken;
          _sendTokenToServer(newToken);
        },
        onError: (error) {
          Log.e('Error in token refresh stream', 'FCM_SERVICE', error);
        },
      );

      // Set up background message handler
      FirebaseMessaging.onBackgroundMessage(_firebaseBackgroundMessageHandler);

      // Handle foreground messages
      FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

      // Handle notification taps (when app is in background/terminated)
      FirebaseMessaging.onMessageOpenedApp.listen(_handleMessageOpenedApp);

      // Check if app was opened from a notification
      RemoteMessage? initialMessage = await _firebaseMessaging!.getInitialMessage();
      if (initialMessage != null) {
        _handleMessageOpenedApp(initialMessage);
      }

      Log.i('✅ Mobile FCM initialized successfully', 'FCM_SERVICE');
    } catch (e) {
      Log.e('Error initializing mobile FCM', 'FCM_SERVICE', e);
    }
  }

  /// Initialize FCM for Web
  Future<void> _initializeWeb() async {
    try {
      _firebaseMessaging = FirebaseMessaging.instance;

      // Request notification permissions for web
      NotificationSettings settings = await _firebaseMessaging!.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );

      if (settings.authorizationStatus == AuthorizationStatus.authorized) {
        Log.i('✅ Web FCM notification permission granted', 'FCM_SERVICE');
      } else {
        Log.w('❌ Web FCM notification permission denied', 'FCM_SERVICE');
      }

      // Get VAPID key for web (should be configured in Firebase Console)
      // For now, we'll try to get token without VAPID key
      await _getToken();

      // Listen for token refresh
      _tokenSubscription = _firebaseMessaging!.onTokenRefresh.listen(
        (newToken) {
          Log.i('Web FCM token refreshed: $newToken', 'FCM_SERVICE');
          _currentToken = newToken;
          _sendTokenToServer(newToken);
        },
        onError: (error) {
          Log.e('Error in web token refresh stream', 'FCM_SERVICE', error);
        },
      );

      // Handle foreground messages
      FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

      // Handle notification taps
      FirebaseMessaging.onMessageOpenedApp.listen(_handleMessageOpenedApp);

      // Check if app was opened from a notification
      RemoteMessage? initialMessage = await _firebaseMessaging!.getInitialMessage();
      if (initialMessage != null) {
        _handleMessageOpenedApp(initialMessage);
      }

      Log.i('✅ Web FCM initialized successfully', 'FCM_SERVICE');
    } catch (e) {
      Log.e('Error initializing web FCM', 'FCM_SERVICE', e);
    }
  }

  /// Get current FCM token
  Future<String?> _getToken() async {
    try {
      if (_firebaseMessaging == null) {
        Log.w('FirebaseMessaging not initialized', 'FCM_SERVICE');
        return null;
      }

      String? token = await _firebaseMessaging!.getToken();
      if (token != null) {
        _currentToken = token;
        Log.i('FCM token obtained: ${token.substring(0, 20)}...', 'FCM_SERVICE');
        
        // Send token to server
        await _sendTokenToServer(token);
      } else {
        Log.w('FCM token is null', 'FCM_SERVICE');
      }
      return token;
    } catch (e) {
      Log.e('Error getting FCM token', 'FCM_SERVICE', e);
      return null;
    }
  }

  /// Get current FCM token (public method)
  Future<String?> getToken() async {
    if (_currentToken != null) {
      return _currentToken;
    }
    return await _getToken();
  }

  /// Send FCM token to MongoDB server
  Future<void> _sendTokenToServer(String token) async {
    try {
      // Get current user ID
      final userId = await _getCurrentUserId();
      if (userId == null) {
        Log.w('Cannot send FCM token: user not logged in', 'FCM_SERVICE');
        return;
      }

      // Get auth token
      final authToken = await _getAuthToken();
      if (authToken == null || authToken.isEmpty) {
        Log.w('Cannot send FCM token: no auth token', 'FCM_SERVICE');
        return;
      }

      // Determine platform
      String platform = 'unknown';
      if (kIsWeb) {
        platform = 'web';
      } else if (Platform.isIOS) {
        platform = 'ios';
      } else if (Platform.isAndroid) {
        platform = 'android';
      }

      // Get server URL
      final baseUrl = DatabaseConfig.physicalServerUrl;
      final url = Uri.parse('$baseUrl/api/users/fcm-token');

      // Prepare request body
      final body = jsonEncode({
        'userId': userId,
        'fcmToken': token,
        'platform': platform,
        'timestamp': DateTime.now().toIso8601String(),
      });

      Log.i('Sending FCM token to server for user: $userId, platform: $platform', 'FCM_SERVICE');

      // Send request
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $authToken',
        },
        body: body,
      ).timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          Log.e('Timeout sending FCM token to server', 'FCM_SERVICE', null);
          throw Exception('Request timeout');
        },
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        Log.i('✅ FCM token sent to server successfully', 'FCM_SERVICE');
      } else {
        Log.w('Failed to send FCM token: ${response.statusCode} - ${response.body}', 'FCM_SERVICE');
      }
    } catch (e) {
      Log.e('Error sending FCM token to server', 'FCM_SERVICE', e);
    }
  }

  /// Handle foreground messages
  void _handleForegroundMessage(RemoteMessage message) {
    Log.i('Received foreground FCM message: ${message.messageId}', 'FCM_SERVICE');
    
    // Show local notification for foreground messages
    _showLocalNotification(message);
  }

  /// Handle message when app is opened from notification
  void _handleMessageOpenedApp(RemoteMessage message) {
    Log.i('App opened from FCM notification: ${message.messageId}', 'FCM_SERVICE');
    
    // Handle navigation or action based on message data
    _processMessageData(message.data);
  }

  /// Show local notification for FCM message
  Future<void> _showLocalNotification(RemoteMessage message) async {
    try {
      final notificationService = EnhancedNotificationService();
      if (!notificationService.isInitialized) {
        await notificationService.initialize();
      }

      final title = message.notification?.title ?? 'New Message';
      final body = message.notification?.body ?? '';
      final data = message.data;

      await notificationService.sendLocalNotification(
        title: title,
        body: body,
        payload: jsonEncode(data),
        channelId: 'chat_notifications',
      );

      Log.i('Local notification shown for FCM message', 'FCM_SERVICE');
    } catch (e) {
      Log.e('Error showing local notification for FCM message', 'FCM_SERVICE', e);
    }
  }

  /// Process message data (for navigation, actions, etc.)
  void _processMessageData(Map<String, dynamic> data) {
    Log.i('Processing FCM message data: $data', 'FCM_SERVICE');
    
    // Extract relevant data
    final chatId = data['chatId'];

    // TODO: Implement navigation logic based on message type
    // This can be integrated with your app's navigation system
    if (chatId != null) {
      Log.i('Navigate to chat: $chatId', 'FCM_SERVICE');
    }
  }

  /// Get current user ID
  Future<String?> _getCurrentUserId() async {
    try {
      if (_currentUserId != null) {
        return _currentUserId;
      }

      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getString('user_id');
      _currentUserId = userId;
      return userId;
    } catch (e) {
      Log.e('Error getting current user ID', 'FCM_SERVICE', e);
      return null;
    }
  }

  /// Update current user ID (call when user logs in)
  Future<void> updateUserId(String? userId) async {
    _currentUserId = userId;
    if (userId != null) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('user_id', userId);
      
      // Resend token with new user ID
      if (_currentToken != null) {
        await _sendTokenToServer(_currentToken!);
      }
    }
  }

  /// Get auth token
  Future<String?> _getAuthToken() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString('auth_token');
    } catch (e) {
      Log.e('Error getting auth token', 'FCM_SERVICE', e);
      return null;
    }
  }

  /// Delete FCM token from server (call when user logs out)
  Future<void> deleteToken() async {
    try {
      final userId = await _getCurrentUserId();
      if (userId == null) {
        return;
      }

      final authToken = await _getAuthToken();
      if (authToken == null || authToken.isEmpty) {
        return;
      }

      final baseUrl = DatabaseConfig.physicalServerUrl;
      final url = Uri.parse('$baseUrl/api/users/fcm-token');

      final response = await http.delete(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $authToken',
        },
        body: jsonEncode({
          'userId': userId,
        }),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200 || response.statusCode == 204) {
        Log.i('✅ FCM token deleted from server', 'FCM_SERVICE');
      } else {
        Log.w('Failed to delete FCM token: ${response.statusCode}', 'FCM_SERVICE');
      }
    } catch (e) {
      Log.e('Error deleting FCM token', 'FCM_SERVICE', e);
    }
  }

  /// Cleanup
  void dispose() {
    _tokenSubscription?.cancel();
    _tokenSubscription = null;
    _isInitialized = false;
  }
}

/// Top-level function for background message handler (must be top-level)
@pragma('vm:entry-point')
Future<void> _firebaseBackgroundMessageHandler(RemoteMessage message) async {
  Log.i('Background FCM message received: ${message.messageId}', 'FCM_BACKGROUND');
  
  // Show local notification
  try {
    final notificationService = EnhancedNotificationService();
    if (!notificationService.isInitialized) {
      await notificationService.initialize();
    }

    final title = message.notification?.title ?? 'New Message';
    final body = message.notification?.body ?? '';
    final data = message.data;

    await notificationService.sendLocalNotification(
      title: title,
      body: body,
      payload: jsonEncode(data),
      channelId: 'chat_notifications',
    );

    Log.i('Background notification shown', 'FCM_BACKGROUND');
  } catch (e) {
    Log.e('Error showing background notification', 'FCM_BACKGROUND', e);
  }
}

