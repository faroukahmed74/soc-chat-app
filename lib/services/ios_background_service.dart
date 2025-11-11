// =============================================================================
// iOS BACKGROUND SERVICE - Background Fetch
// =============================================================================
// This service handles background tasks on iOS using Background Fetch
//
// PLATFORM: iOS only

import 'dart:async';
import 'package:flutter/foundation.dart';
// import 'package:background_fetch/background_fetch.dart'; // Temporarily disabled due to CocoaPods issue
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:io';
import '../config/database_config.dart';
import 'logger_service.dart';
import 'enhanced_notification_service.dart';

class IOSBackgroundService {
  static final IOSBackgroundService _instance = IOSBackgroundService._internal();
  factory IOSBackgroundService() => _instance;
  IOSBackgroundService._internal();

  bool _initialized = false;

  /// Initialize iOS background fetch
  Future<void> initialize() async {
    if (_initialized) return;
    if (kIsWeb) return; // Not supported on web
    if (!Platform.isIOS) return; // iOS only

    // Temporarily disabled due to CocoaPods issue with background_fetch
    Log.w('iOS background service disabled (background_fetch package disabled)', 'IOS_BACKGROUND');
    _initialized = true;
    return;

    /* DISABLED - background_fetch package disabled
    try {
      // Configure background fetch
      await BackgroundFetch.configure(
        BackgroundFetchConfig(
          minimumFetchInterval: 15, // minutes (minimum is 15)
          stopOnTerminate: false,
          startOnBoot: true,
          enableHeadless: true,
          requiresBatteryNotLow: false,
          requiresCharging: false,
          requiresStorageNotLow: false,
          requiresDeviceIdle: false,
        ),
        _onBackgroundFetch,
        _onBackgroundFetchTimeout,
      );

      _initialized = true;
      Log.i('iOS background service initialized', 'IOS_BACKGROUND');
    } catch (e) {
      Log.e('Error initializing iOS background service', 'IOS_BACKGROUND', e);
    }
    */
  }

  /// Start background fetch
  Future<void> start() async {
    if (!_initialized) await initialize();
    
    // Temporarily disabled
    Log.w('iOS background fetch disabled', 'IOS_BACKGROUND');
    return;

    /* DISABLED
    try {
      await BackgroundFetch.start();
      Log.i('iOS background fetch started', 'IOS_BACKGROUND');
    } catch (e) {
      Log.e('Error starting iOS background fetch', 'IOS_BACKGROUND', e);
    }
    */
  }

  /// Stop background fetch
  Future<void> stop() async {
    // Temporarily disabled
    Log.w('iOS background fetch stop disabled', 'IOS_BACKGROUND');
    return;

    /* DISABLED
    try {
      await BackgroundFetch.stop();
      Log.i('iOS background fetch stopped', 'IOS_BACKGROUND');
    } catch (e) {
      Log.e('Error stopping iOS background fetch', 'IOS_BACKGROUND', e);
    }
    */
  }

  /// Background fetch callback
  static Future<void> _onBackgroundFetch(String taskId) async {
    // DISABLED
    return;

    /* DISABLED
    try {
      Log.i('iOS background fetch triggered: $taskId', 'IOS_BACKGROUND');
      
      // Sync messages
      await _syncMessages();
      
      // Mark task as complete
      BackgroundFetch.finish(taskId);
    } catch (e) {
      Log.e('Error in iOS background fetch', 'IOS_BACKGROUND', e);
      BackgroundFetch.finish(taskId);
    }
    */
  }

  /// Background fetch timeout callback
  static void _onBackgroundFetchTimeout(String taskId) {
    // DISABLED
    return;

    /* DISABLED
    Log.w('iOS background fetch timeout: $taskId', 'IOS_BACKGROUND');
    BackgroundFetch.finish(taskId);
    */
  }

  /// Sync messages from server
  static Future<void> _syncMessages() async {
    try {
      // Get auth token
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');
      
      if (token == null) {
        Log.w('No auth token for iOS background sync', 'IOS_BACKGROUND');
        return;
      }

      final baseUrl = DatabaseConfig.physicalServerUrl;
      
      // Get user's chats
      final chatsResponse = await http.get(
        Uri.parse('$baseUrl/api/chats'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
          'ngrok-skip-browser-warning': 'true',
        },
      ).timeout(const Duration(seconds: 30));

      if (chatsResponse.statusCode == 200) {
        final data = json.decode(chatsResponse.body);
        final chats = (data['chats'] as List?) ?? [];
        
        Log.i('Synced ${chats.length} chats on iOS background', 'IOS_BACKGROUND');

        // Check for unread messages and show notifications
        for (var chat in chats) {
          final chatId = chat['_id'] ?? chat['id'];
          if (chatId == null) continue;

          final unreadCount = chat['unreadCount'] ?? 0;
          
          if (unreadCount > 0) {
            // Get latest message
            try {
              final messagesResponse = await http.get(
                Uri.parse('$baseUrl/api/messages/$chatId?limit=1'),
                headers: {
                  'Authorization': 'Bearer $token',
                  'Content-Type': 'application/json',
                  'ngrok-skip-browser-warning': 'true',
                },
              ).timeout(const Duration(seconds: 10));

              if (messagesResponse.statusCode == 200) {
                final messagesData = json.decode(messagesResponse.body);
                final messages = (messagesData['messages'] as List?) ?? [];
                
                if (messages.isNotEmpty) {
                  final lastMessage = messages[0];
                  
                  // Show notification for unread messages
                  final notificationService = EnhancedNotificationService();
                  if (notificationService.isInitialized) {
                    await notificationService.sendLocalNotification(
                      title: chat['name'] ?? 'New Message',
                      body: lastMessage['content'] ?? 'You have unread messages',
                      payload: chatId.toString(),
                      channelId: 'chat_notifications',
                    );
                  }
                }
              }
            } catch (e) {
              Log.e('Error fetching messages for chat $chatId', 'IOS_BACKGROUND', e);
            }
          }
        }
      } else {
        Log.w('Failed to sync chats: ${chatsResponse.statusCode}', 'IOS_BACKGROUND');
      }
    } catch (e) {
      Log.e('Error syncing messages on iOS background', 'IOS_BACKGROUND', e);
    }
  }
}

