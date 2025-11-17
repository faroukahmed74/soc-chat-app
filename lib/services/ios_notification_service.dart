// =============================================================================
// iOS NOTIFICATION SERVICE
// =============================================================================
// Handles iOS-specific notification and background connection management
// iOS doesn't support foreground services like Android, so we need different approach

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../config/database_config.dart';
import 'logger_service.dart';
import 'enhanced_notification_service.dart';
import 'local_auth_service.dart';

class IOSNotificationService {
  static final IOSNotificationService _instance = IOSNotificationService._internal();
  factory IOSNotificationService() => _instance;
  IOSNotificationService._internal();

  IO.Socket? _socket;
  bool _isConnected = false;
  Timer? _reconnectTimer;
  Timer? _heartbeatTimer;
  bool _isInBackground = false;

  bool get isConnected => _isConnected;

  /// Initialize iOS notification service
  Future<void> initialize() async {
    if (kIsWeb || !Platform.isIOS) return;
    
    Log.i('Initializing iOS notification service...', 'IOS_NOTIF');
    
    // Connect socket when app is active
    await _connectSocket();
    
    // Set up periodic reconnection check
    _reconnectTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (!_isConnected && !_isInBackground) {
        Log.i('Reconnecting socket (iOS)...', 'IOS_NOTIF');
        _connectSocket();
      }
    });
    
    // Set up heartbeat to keep connection alive
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      if (_isConnected && !_isInBackground) {
        _sendHeartbeat();
      }
    });
    
    Log.i('iOS notification service initialized', 'IOS_NOTIF');
  }

  /// Handle app going to background
  void onAppPaused() {
    _isInBackground = true;
    Log.i('App paused - socket will be suspended by iOS', 'IOS_NOTIF');
    // Don't disconnect - let iOS handle it
    // Socket will be suspended but we'll reconnect when app resumes
  }

  /// Handle app coming to foreground
  Future<void> onAppResumed() async {
    _isInBackground = false;
    Log.i('App resumed - reconnecting socket (iOS)...', 'IOS_NOTIF');
    
    // Reconnect socket when app comes to foreground
    await _connectSocket();
    
    // Sync any missed messages
    await _syncMissedMessages();
  }

  /// Connect socket for iOS
  Future<void> _connectSocket() async {
    if (_isConnected && _socket?.connected == true) {
      return;
    }

    try {
      // Get auth token
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');
      
      if (token == null || token.isEmpty) {
        Log.w('No auth token for iOS socket', 'IOS_NOTIF');
        return;
      }

      // Dispose existing socket
      _socket?.dispose();
      _socket = null;

      // Connect to socket
      final baseUrl = DatabaseConfig.physicalServerUrl;
      final uri = Uri.parse(baseUrl);
      final scheme = uri.scheme == 'https' ? 'wss' : 'ws';
      final wsUrl = Uri(
        scheme: scheme,
        host: uri.host,
        port: uri.hasPort ? uri.port : (uri.scheme == 'https' ? 443 : 80),
        path: '/',
      ).toString();

      Log.i('Connecting iOS socket to: $wsUrl', 'IOS_NOTIF');

      _socket = IO.io(wsUrl, IO.OptionBuilder()
          .setTransports(['websocket'])
          .enableForceNew()
          .enableReconnection()
          .setReconnectionDelay(1000)
          .setReconnectionDelayMax(5000)
          .setTimeout(20000)
          .setAuth({'token': token})
          .build());

      _registerTokenRefreshHandler();

      _socket!.on('connect', (_) {
        _isConnected = true;
        Log.i('✅ iOS socket connected', 'IOS_NOTIF');
        _joinUserRoom();
      });

      _socket!.on('disconnect', (reason) {
        _isConnected = false;
        Log.w('⚠️ iOS socket disconnected: $reason', 'IOS_NOTIF');
      });

      _socket!.on('connect_error', (error) {
        _isConnected = false;
        Log.e('❌ iOS socket connection error', 'IOS_NOTIF', error);
      });

      // Listen for notifications
      _socket!.on('chat_notification', (data) {
        Log.i('🔔 Received chat notification on iOS: $data', 'IOS_NOTIF');
        _handleChatNotification(data);
      });

      _socket!.on('new_message', (data) {
        Log.i('📨 Received new message on iOS: $data', 'IOS_NOTIF');
        _handleNewMessage(data);
      });

      _socket!.on('notification', (data) {
        Log.i('📢 Received notification on iOS: $data', 'IOS_NOTIF');
        _handleNotification(data);
      });

    } catch (e, stackTrace) {
      Log.e('❌ Error connecting iOS socket', 'IOS_NOTIF', e, stackTrace);
      _isConnected = false;
    }
  }

  /// Join user to notification room
  Future<void> _joinUserRoom() async {
    try {
      final currentUser = await LocalAuthService.getCurrentUser();
      final userId = currentUser?['id'];
      if (userId != null && _socket?.connected == true) {
        _socket!.emit('join_user', userId);
        Log.i('✅ Joined notification room for user: $userId (iOS)', 'IOS_NOTIF');
      }
    } catch (e) {
      Log.e('Error joining user room (iOS)', 'IOS_NOTIF', e);
    }
  }

  /// Send heartbeat to keep connection alive
  void _sendHeartbeat() {
    if (_socket?.connected == true) {
      _socket?.emit('ping', DateTime.now().millisecondsSinceEpoch);
    }
  }

  /// Handle chat notification
  Future<void> _handleChatNotification(dynamic data) async {
    try {
      if (data is Map<String, dynamic>) {
        final notificationService = EnhancedNotificationService();
        if (!notificationService.isInitialized) {
          await notificationService.initialize();
        }
        
        final title = data['title'] ?? 'New Chat Message';
        final body = data['body'] ?? '';
        final chatId = (data['chatId'] ?? data['chat_id'] ?? '').toString();
        
        await notificationService.sendLocalNotification(
          title: title,
          body: body,
          payload: chatId,
          channelId: 'chat_notifications',
        );
        
        Log.i('Notification sent for chat (iOS): $title', 'IOS_NOTIF');
      }
    } catch (e) {
      Log.e('Error handling chat notification (iOS)', 'IOS_NOTIF', e);
    }
  }

  /// Handle new message
  Future<void> _handleNewMessage(dynamic data) async {
    try {
      if (data is Map<String, dynamic>) {
        final notificationService = EnhancedNotificationService();
        if (!notificationService.isInitialized) {
          await notificationService.initialize();
        }
        
        final senderName = (data['senderName'] ?? data['sender_name'] ?? 'Someone').toString();
        final content = (data['content'] ?? '').toString();
        final chatId = (data['chatId'] ?? data['chat_id'] ?? '').toString();
        
        // Get current user to avoid self-notifications
        final currentUser = await LocalAuthService.getCurrentUser();
        final currentUserId = currentUser?['id'];
        final senderId = (data['senderId'] ?? data['sender_id'] ?? '').toString();
        
        if (senderId == currentUserId) {
          return; // Don't notify for own messages
        }
        
        await notificationService.sendLocalNotification(
          title: senderName,
          body: content.isNotEmpty ? content : 'New message',
          payload: chatId,
          channelId: 'chat_notifications',
        );
        
        Log.i('Notification sent for new message (iOS): $senderName', 'IOS_NOTIF');
      }
    } catch (e) {
      Log.e('Error handling new message (iOS)', 'IOS_NOTIF', e);
    }
  }

  /// Handle generic notification
  Future<void> _handleNotification(dynamic data) async {
    try {
      if (data is Map<String, dynamic>) {
        final notificationService = EnhancedNotificationService();
        if (!notificationService.isInitialized) {
          await notificationService.initialize();
        }
        
        final title = data['title'] ?? 'New Notification';
        final body = data['body'] ?? '';
        
        await notificationService.sendLocalNotification(
          title: title,
          body: body,
          payload: '',
          channelId: 'chat_notifications',
        );
      }
    } catch (e) {
      Log.e('Error handling notification (iOS)', 'IOS_NOTIF', e);
    }
  }

  /// Sync missed messages when app resumes
  Future<void> _syncMissedMessages() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');
      
      if (token == null) {
        return;
      }

      final baseUrl = DatabaseConfig.physicalServerUrl;
      
      // Get user's chats to check for unread messages
      final response = await http.get(
        Uri.parse('$baseUrl/api/chats'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final chats = (data['chats'] as List?) ?? [];
        
        final notificationService = EnhancedNotificationService();
        if (!notificationService.isInitialized) {
          await notificationService.initialize();
        }
        
        // Check for unread messages and show notifications
        for (var chat in chats) {
          final unreadCount = chat['unreadCount'] ?? 0;
          if (unreadCount > 0) {
            final chatName = chat['name'] ?? 'New Message';
            await notificationService.sendLocalNotification(
              title: chatName,
              body: 'You have $unreadCount unread message${unreadCount > 1 ? 's' : ''}',
              payload: (chat['_id'] ?? chat['id'] ?? '').toString(),
              channelId: 'chat_notifications',
            );
          }
        }
        
        Log.i('Synced missed messages on iOS resume', 'IOS_NOTIF');
      }
    } catch (e) {
      Log.e('Error syncing missed messages (iOS)', 'IOS_NOTIF', e);
    }
  }

  void _registerTokenRefreshHandler() {
    _socket?.off('auth:token_refreshed');
    _socket?.on('auth:token_refreshed', (payload) async {
      try {
        final token = _extractToken(payload);
        if (token == null || token.isEmpty) {
          return;
        }
        await DatabaseConfig.setAuthToken(token);
        Log.i('iOS socket stored refreshed auth token', 'IOS_NOTIF');
      } catch (e) {
        Log.e('Failed to persist refreshed auth token (iOS)', 'IOS_NOTIF', e);
      }
    });
  }

  String? _extractToken(dynamic payload) {
    if (payload is String && payload.isNotEmpty) {
      return payload;
    }
    if (payload is Map) {
      final token = payload['token'];
      if (token is String && token.isNotEmpty) {
        return token;
      }
    }
    return null;
  }

  /// Dispose service
  void dispose() {
    _reconnectTimer?.cancel();
    _heartbeatTimer?.cancel();
    _socket?.dispose();
    _socket = null;
    _isConnected = false;
  }
}

