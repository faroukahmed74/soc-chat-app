// =============================================================================
// BACKGROUND SYNC SERVICE - Periodic Message Sync
// =============================================================================
// This service runs periodic background tasks to sync messages
// when the app is in the background or closed
//
// PLATFORM: Android (WorkManager) and iOS (Background Fetch)

import 'dart:async';
import 'package:flutter/foundation.dart';
// import 'package:workmanager/workmanager.dart'; // Temporarily disabled
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../config/database_config.dart';
import 'logger_service.dart';
import 'enhanced_notification_service.dart';

class BackgroundSyncService {
  static final BackgroundSyncService _instance = BackgroundSyncService._internal();
  factory BackgroundSyncService() => _instance;
  BackgroundSyncService._internal();

  bool _initialized = false;

  /// Initialize background sync service
  Future<void> initialize() async {
    if (_initialized) return;
    if (kIsWeb) return; // Not supported on web

    try {
      // WorkManager temporarily disabled due to compatibility issues
      // Foreground service will handle real-time notifications
      Log.i('Background sync service skipped (WorkManager disabled)', 'BACKGROUND_SYNC');
      _initialized = true;
    } catch (e) {
      Log.e('Error initializing background sync', 'BACKGROUND_SYNC', e);
    }
  }

  /// Cancel all background tasks
  Future<void> cancelAll() async {
    // WorkManager disabled - nothing to cancel
    Log.i('Background sync service cleanup (WorkManager disabled)', 'BACKGROUND_SYNC');
  }
}

/// Background task callback (runs in isolate)
/// Temporarily disabled - WorkManager not available
@pragma('vm:entry-point')
void callbackDispatcher() {
  // WorkManager disabled - this callback won't be called
}

/// Sync messages from server
Future<void> _syncMessages() async {
  try {
    // Get auth token
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');
    
    if (token == null) {
      Log.w('No auth token for background sync', 'BACKGROUND_SYNC');
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
      
      Log.i('Synced ${chats.length} chats in background', 'BACKGROUND_SYNC');

      // Check for unread messages and show notifications
      for (var chat in chats) {
        final chatId = chat['_id'] ?? chat['id'];
        if (chatId == null) continue;

        // Get latest messages
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
            final unreadCount = chat['unreadCount'] ?? 0;
            
            if (unreadCount > 0) {
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
        }
      }
    } else {
      Log.w('Failed to sync chats: ${chatsResponse.statusCode}', 'BACKGROUND_SYNC');
    }
  } catch (e) {
    Log.e('Error syncing messages in background', 'BACKGROUND_SYNC', e);
  }
}

