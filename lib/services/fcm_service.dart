import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../config/database_config.dart';
import 'logger_service.dart';
import 'enhanced_notification_service.dart';
import '../main.dart';
import '../screens/chat_screen_mongodb.dart';
import 'mongodb_chat_service.dart';

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
      // If already initialized but no token, try to get it
      if (_currentToken == null) {
        Log.i('FCM service initialized but no token, attempting to get token...', 'FCM_SERVICE');
        await getToken();
      }
      return;
    }

    try {
      if (kIsWeb) {
        // Web FCM initialization
        await _initializeWeb();
      } else {
        // Mobile FCM initialization
        await _initializeMobile();
      }

      _isInitialized = true;
      Log.i('✅ FCM service initialized', 'FCM_SERVICE');
      
      // If user is already logged in, send token to server
      final userId = await _getCurrentUserId();
      if (userId != null && _currentToken != null) {
        Log.i('User already logged in, sending FCM token to server', 'FCM_SERVICE');
        await _sendTokenToServer(_currentToken!);
      }
    } catch (e) {
      Log.e('FCM service initialization failed', 'FCM_SERVICE', e);
      _isInitialized = false;
      rethrow;
    }
  }

  /// Initialize FCM for mobile platforms (iOS and Android)
  Future<void> _initializeMobile() async {
    try {
      _firebaseMessaging = FirebaseMessaging.instance;

      // Request notification permissions
      NotificationSettings settings = await _firebaseMessaging!
          .requestPermission(
            alert: true,
            badge: true,
            sound: true,
            provisional: false,
          );

      if (settings.authorizationStatus == AuthorizationStatus.authorized) {
        Log.i('✅ FCM notification permission granted', 'FCM_SERVICE');
      } else if (settings.authorizationStatus ==
          AuthorizationStatus.provisional) {
        Log.i(
          '⚠️ FCM notification permission granted provisionally',
          'FCM_SERVICE',
        );
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
      RemoteMessage? initialMessage = await _firebaseMessaging!
          .getInitialMessage();
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
      NotificationSettings settings = await _firebaseMessaging!
          .requestPermission(
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
      RemoteMessage? initialMessage = await _firebaseMessaging!
          .getInitialMessage();
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
        Log.i(
          'FCM token obtained: ${token.substring(0, 20)}...',
          'FCM_SERVICE',
        );

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

      Log.i(
        'Sending FCM token to server for user: $userId, platform: $platform',
        'FCM_SERVICE',
      );

      // Send request with retry logic
      int retries = 3;
      while (retries > 0) {
        try {
          final response = await http
              .post(
                url,
                headers: {
                  'Content-Type': 'application/json',
                  'Authorization': 'Bearer $authToken',
                  'ngrok-skip-browser-warning': 'true',
                },
                body: body,
              )
              .timeout(
                const Duration(seconds: 10),
                onTimeout: () {
                  throw Exception('Request timeout');
                },
              );

          if (response.statusCode == 200 || response.statusCode == 201) {
            Log.i('✅ FCM token sent to server successfully', 'FCM_SERVICE');
            return; // Success, exit retry loop
          } else if (response.statusCode == 401 || response.statusCode == 403) {
            Log.w(
              'Authentication failed, cannot retry: ${response.statusCode}',
              'FCM_SERVICE',
            );
            return; // Don't retry auth errors
          } else {
            Log.w(
              'Failed to send FCM token: ${response.statusCode} - ${response.body}',
              'FCM_SERVICE',
            );
            retries--;
            if (retries > 0) {
              await Future.delayed(
                Duration(seconds: 3 - retries),
              ); // Exponential backoff
            }
          }
        } catch (e) {
          retries--;
          if (retries > 0) {
            Log.w(
              'Error sending FCM token, retrying... ($retries attempts left)',
              'FCM_SERVICE',
            );
            await Future.delayed(Duration(seconds: 3 - retries));
          } else {
            Log.e(
              'Error sending FCM token to server after retries',
              'FCM_SERVICE',
              e,
            );
          }
        }
      }
    } catch (e) {
      Log.e('Error sending FCM token to server', 'FCM_SERVICE', e);
    }
  }

  /// Handle foreground messages
  void _handleForegroundMessage(RemoteMessage message) {
    Log.i(
      'Received foreground FCM message: ${message.messageId}',
      'FCM_SERVICE',
    );

    // Show local notification for foreground messages
    _showLocalNotification(message);
  }

  /// Handle message when app is opened from notification
  Future<void> _handleMessageOpenedApp(RemoteMessage message) async {
    Log.i(
      'App opened from FCM notification: ${message.messageId}',
      'FCM_SERVICE',
    );

    // Add small delay to ensure app is fully initialized
    await Future.delayed(const Duration(milliseconds: 500));

    // Handle navigation or action based on message data
    await _processMessageData(message.data);
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
      Log.e(
        'Error showing local notification for FCM message',
        'FCM_SERVICE',
        e,
      );
    }
  }

  /// Process message data (for navigation, actions, etc.)
  Future<void> _processMessageData(Map<String, dynamic> data) async {
    Log.i('Processing FCM message data: $data', 'FCM_SERVICE');

    try {
      // Extract relevant data
      final chatId = data['chatId']?.toString();
      final senderId = data['senderId']?.toString();
      final senderName = data['senderName']?.toString() ?? 'Unknown';
      final messageType = data['type']?.toString() ?? 'chat_message';

      if (chatId == null || chatId.isEmpty) {
        Log.w('No chatId in FCM message data, cannot navigate', 'FCM_SERVICE');
        return;
      }

      Log.i('Navigating to chat: $chatId', 'FCM_SERVICE');

      // Use navigatorKey to navigate even when app is in background
      final navigator = navigatorKey.currentState;
      if (navigator == null) {
        Log.w(
          'Navigator not available, storing chatId for later navigation',
          'FCM_SERVICE',
        );
        // Store chatId to navigate when app becomes active
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('pending_chat_navigation', chatId);
        return;
      }

      // Get chat details to determine if it's a group chat
      try {
        final chatService = MongoDBChatService();
        final chatDetails = await chatService.getChatDetails(chatId);

        if (chatDetails == null) {
          Log.w('Chat not found: $chatId', 'FCM_SERVICE');
          return;
        }

        final chat = chatDetails['chat'] ?? chatDetails;
        final chatName = chat['name']?.toString() ?? senderName;
        final isGroupChat =
            chat['type']?.toString() == 'group' ||
            ((chat['members'] as List?)?.length ?? 0) > 2;
        final members = chat['members'] as List?;

        // Navigate to chat screen
        navigator.push(
          MaterialPageRoute(
            builder: (context) => ChatScreenMongoDB(
              chatId: chatId,
              chatName: chatName,
              isGroupChat: isGroupChat,
              userIds: members != null
                  ? members.map((m) => m.toString()).toList()
                  : null,
            ),
          ),
        );

        Log.i('✅ Successfully navigated to chat: $chatId', 'FCM_SERVICE');
      } catch (e) {
        Log.e('Error navigating to chat', 'FCM_SERVICE', e);
        // Fallback: try to navigate with minimal info
        try {
          navigator.push(
            MaterialPageRoute(
              builder: (context) => ChatScreenMongoDB(
                chatId: chatId,
                chatName: senderName,
                isGroupChat: false,
              ),
            ),
          );
        } catch (fallbackError) {
          Log.e(
            'Fallback navigation also failed',
            'FCM_SERVICE',
            fallbackError,
          );
        }
      }
    } catch (e) {
      Log.e('Error processing FCM message data', 'FCM_SERVICE', e);
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

      // Get FCM token if not already available, then send to server
      try {
        String? token = _currentToken;
        if (token == null) {
          // Token not available yet, try to get it
          Log.i('FCM token not available, attempting to get token...', 'FCM_SERVICE');
          token = await getToken();
        }
        
        if (token != null && token.isNotEmpty) {
          Log.i('Sending FCM token to server after login for user: $userId', 'FCM_SERVICE');
          await _sendTokenToServer(token);
        } else {
          Log.w('FCM token is null or empty, cannot send to server', 'FCM_SERVICE');
          // Try again after a short delay in case Firebase is still initializing
          Future.delayed(const Duration(seconds: 2), () async {
            try {
              final retryToken = await getToken();
              if (retryToken != null && retryToken.isNotEmpty) {
                Log.i('Retrying FCM token send after delay', 'FCM_SERVICE');
                await _sendTokenToServer(retryToken);
              }
            } catch (e) {
              Log.e('Failed to get FCM token on retry', 'FCM_SERVICE', e);
            }
          });
        }
      } catch (e) {
        Log.e('Error getting/sending FCM token after login', 'FCM_SERVICE', e);
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

      final response = await http
          .delete(
            url,
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $authToken',
            },
            body: jsonEncode({'userId': userId}),
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200 || response.statusCode == 204) {
        Log.i('✅ FCM token deleted from server', 'FCM_SERVICE');
      } else {
        Log.w(
          'Failed to delete FCM token: ${response.statusCode}',
          'FCM_SERVICE',
        );
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
  Log.i(
    'Background FCM message received: ${message.messageId}',
    'FCM_BACKGROUND',
  );

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
