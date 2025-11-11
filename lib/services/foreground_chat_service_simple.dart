// =============================================================================
// FOREGROUND CHAT SERVICE - Simplified Version
// =============================================================================
// Simplified version that works with current flutter_foreground_task API
// WorkManager is temporarily disabled due to compatibility issues

import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import '../config/database_config.dart';
import 'logger_service.dart';
import 'enhanced_notification_service.dart';
import 'local_auth_service.dart';

class ForegroundChatService {
  static final ForegroundChatService _instance = ForegroundChatService._internal();
  factory ForegroundChatService() => _instance;
  ForegroundChatService._internal();

  bool _isRunning = false;

  bool get isRunning => _isRunning;

  /// Start the foreground service (Android only)
  Future<bool> start() async {
    if (kIsWeb) {
      Log.w('Cannot start foreground service on web', 'FOREGROUND_SERVICE');
      return false;
    }
    
    if (_isRunning) {
      Log.i('Foreground service already running', 'FOREGROUND_SERVICE');
      return true;
    }

    try {
      Log.i('Starting foreground chat service...', 'FOREGROUND_SERVICE');
      
      // Step 1: Ensure notification service is initialized
      final notificationService = EnhancedNotificationService();
      if (!notificationService.isInitialized) {
        Log.i('Initializing notification service...', 'FOREGROUND_SERVICE');
        await notificationService.initialize();
      }
      
      // Step 2: Request notification permission explicitly
      Log.i('Checking notification permission...', 'FOREGROUND_SERVICE');
      final hasPermission = await notificationService.requestPermission();
      if (!hasPermission) {
        Log.e('❌ Notification permission not granted - service cannot start', 'FOREGROUND_SERVICE');
        return false;
      }
      Log.i('✅ Notification permission granted', 'FOREGROUND_SERVICE');
      
      // Ensure notification channels are created (important for Android 13+)
      // The enhanced notification service should have created channels, but we ensure it here
      if (!notificationService.isInitialized) {
        await notificationService.initialize();
      }

      // Step 3: Initialize foreground task
      Log.i('Initializing foreground task...', 'FOREGROUND_SERVICE');
      FlutterForegroundTask.init(
        androidNotificationOptions: AndroidNotificationOptions(
          channelId: 'foreground_chat_service',
          channelName: 'Chat Service',
          channelDescription: 'Keeps chat connection active to receive messages',
          // Use DEFAULT importance to ensure notification is visible on Android 13+
          // LOW importance notifications may be hidden on Android 13+
          channelImportance: NotificationChannelImportance.DEFAULT,
          priority: NotificationPriority.DEFAULT,
        ),
        iosNotificationOptions: const IOSNotificationOptions(
          showNotification: false, // iOS doesn't use foreground services, uses background fetch instead
        ),
        foregroundTaskOptions: ForegroundTaskOptions(
          eventAction: ForegroundTaskEventAction.repeat(5000), // 5 seconds
          autoRunOnBoot: true,
          allowWakeLock: true,
          allowWifiLock: true,
        ),
      );
      Log.i('Foreground task initialized', 'FOREGROUND_SERVICE');

      // Step 4: Start the service
      Log.i('Starting foreground service...', 'FOREGROUND_SERVICE');
      final result = await FlutterForegroundTask.startService(
        notificationTitle: 'SOC Chat',
        notificationText: 'Connected and receiving messages',
        callback: startCallback,
      );

      // Check if service started successfully
      if (result == true) {
        _isRunning = true;
        Log.i('✅ Foreground chat service started successfully', 'FOREGROUND_SERVICE');
        
        // Update notification after a short delay to confirm it's running
        Future.delayed(const Duration(seconds: 2), () {
          updateNotification('Connected and receiving messages');
        });
        
        return true;
      } else {
        Log.e('❌ Failed to start foreground service - result: $result', 'FOREGROUND_SERVICE');
        return false;
      }
    } catch (e, stackTrace) {
      Log.e('❌ Error starting foreground service', 'FOREGROUND_SERVICE', e, stackTrace);
      return false;
    }
  }

  /// Stop the foreground service
  Future<void> stop() async {
    if (!_isRunning) return;

    try {
      await FlutterForegroundTask.stopService();
      _isRunning = false;
      Log.i('Foreground chat service stopped', 'FOREGROUND_SERVICE');
    } catch (e) {
      Log.e('Error stopping foreground service', 'FOREGROUND_SERVICE', e);
    }
  }

  /// Update notification text
  void updateNotification(String text) {
    if (!_isRunning) return;
    try {
      FlutterForegroundTask.updateService(
        notificationTitle: 'SOC Chat',
        notificationText: text,
      );
    } catch (e) {
      Log.e('Error updating notification', 'FOREGROUND_SERVICE', e);
    }
  }
}

/// Background task handler (runs in isolate)
@pragma('vm:entry-point')
void startCallback() {
  FlutterForegroundTask.setTaskHandler(FirstTaskHandler());
}

class FirstTaskHandler extends TaskHandler {
  Timer? _timer;
  IO.Socket? _socket;
  bool _isConnected = false;

  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {
    Log.i('Foreground task handler started', 'FOREGROUND_TASK');
    
    // Connect to socket in background
    await _connectSocket();
    
    // Set up periodic heartbeat
    _timer = Timer.periodic(const Duration(seconds: 30), (timer) {
      _sendHeartbeat();
    });
  }

  @override
  void onRepeatEvent(DateTime timestamp) {
    // Check socket connection status
    if (!_isConnected) {
      _connectSocket();
    }
    
    // Send status update
    FlutterForegroundTask.updateService(
      notificationTitle: 'SOC Chat',
      notificationText: _isConnected 
          ? 'Connected and receiving messages'
          : 'Connecting...',
    );
  }

  @override
  Future<void> onDestroy(DateTime timestamp) async {
    _timer?.cancel();
    _socket?.dispose();
    _isConnected = false;
    Log.i('Foreground task handler destroyed', 'FOREGROUND_TASK');
  }

  @override
  void onNotificationButtonPressed(String id) {
    if (id == 'btn_stop') {
      FlutterForegroundTask.stopService();
    }
  }

  Future<void> _connectSocket() async {
    try {
      if (_socket?.connected == true) {
        _isConnected = true;
        Log.i('Socket already connected', 'FOREGROUND_TASK');
        return;
      }

      Log.i('Connecting to socket server...', 'FOREGROUND_TASK');
      
      // Get auth token
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');
      
      if (token == null || token.isEmpty) {
        Log.e('❌ No auth token for background socket', 'FOREGROUND_TASK');
        _isConnected = false;
        return;
      }
      Log.i('Auth token found', 'FOREGROUND_TASK');

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
      
      Log.i('Connecting to: $wsUrl', 'FOREGROUND_TASK');

      // Dispose existing socket if any
      _socket?.dispose();
      _socket = null;

      _socket = IO.io(wsUrl, IO.OptionBuilder()
          .setTransports(['websocket'])
          .enableForceNew()
          .enableReconnection()
          .setReconnectionDelay(1000)
          .setReconnectionDelayMax(5000)
          .setTimeout(20000)
          .setAuth({'token': token})
          .build());

      _socket!.on('connect', (_) {
        _isConnected = true;
        Log.i('✅ Background socket connected successfully', 'FOREGROUND_TASK');
        
        // Join user to their personal notification room immediately after connection
        _joinUserRoom();
      });

      _socket!.on('disconnect', (reason) {
        _isConnected = false;
        Log.w('⚠️ Background socket disconnected: $reason', 'FOREGROUND_TASK');
      });

      _socket!.on('connect_error', (error) {
        _isConnected = false;
        Log.e('❌ Background socket connection error', 'FOREGROUND_TASK', error);
      });

      // Listen for new messages and trigger notifications
      _socket!.on('new_message', (data) {
        Log.i('📨 Received new_message in background: $data', 'FOREGROUND_TASK');
        _handleNewMessage(data);
      });

      _socket!.on('chat_notification', (data) {
        Log.i('🔔 Received chat_notification in background: $data', 'FOREGROUND_TASK');
        _handleChatNotification(data);
      });

      _socket!.on('notification', (data) {
        Log.i('📢 Received notification in background: $data', 'FOREGROUND_TASK');
        _handleNotification(data);
      });
      
      // Wait a bit for connection, then join room
      Future.delayed(const Duration(seconds: 2), () {
        if (_socket?.connected == true) {
          _joinUserRoom();
        }
      });

    } catch (e, stackTrace) {
      Log.e('❌ Error connecting background socket', 'FOREGROUND_TASK', e, stackTrace);
      _isConnected = false;
    }
  }
  
  Future<void> _joinUserRoom() async {
    try {
      final currentUser = await LocalAuthService.getCurrentUser();
      final userId = currentUser?['id'];
      if (userId != null && _socket?.connected == true) {
        _socket!.emit('join_user', userId);
        Log.i('✅ Joined notification room for user: $userId', 'FOREGROUND_TASK');
      } else {
        Log.w('Cannot join user room - userId: $userId, socket connected: ${_socket?.connected}', 'FOREGROUND_TASK');
      }
    } catch (e) {
      Log.e('Error joining user room', 'FOREGROUND_TASK', e);
    }
  }

  void _sendHeartbeat() {
    if (_socket?.connected == true) {
      _socket?.emit('ping', DateTime.now().millisecondsSinceEpoch);
    }
  }

  /// Handle new message event
  Future<void> _handleNewMessage(dynamic data) async {
    try {
      if (data is Map<String, dynamic>) {
        final chatId = (data['chatId'] ?? data['chat_id'] ?? '').toString();
        final senderId = (data['senderId'] ?? data['sender_id'] ?? '').toString();
        final senderName = (data['senderName'] ?? data['sender_name'] ?? 'Someone').toString();
        final content = (data['content'] ?? '').toString();
        
        // Get current user ID to avoid self-notifications
        final currentUser = await LocalAuthService.getCurrentUser();
        final currentUserId = currentUser?['id'];
        
        if (senderId == currentUserId) {
          return; // Don't notify for own messages
        }
        
        // Initialize notification service in isolate
        final notificationService = EnhancedNotificationService();
        if (!notificationService.isInitialized) {
          await notificationService.initialize();
        }
        
        // Send notification
        await notificationService.sendLocalNotification(
          title: senderName,
          body: content.isNotEmpty ? content : 'New message',
          payload: json.encode({
            'type': 'chat_message',
            'chatId': chatId,
            'senderId': senderId,
            'senderName': senderName,
            'timestamp': DateTime.now().toIso8601String(),
          }),
          channelId: 'chat_notifications',
        );
        
        Log.i('Notification sent for new message from $senderName', 'FOREGROUND_TASK');
      }
    } catch (e) {
      Log.e('Error handling new message in background', 'FOREGROUND_TASK', e);
    }
  }

  /// Handle chat notification event
  Future<void> _handleChatNotification(dynamic data) async {
    try {
      if (data is Map<String, dynamic>) {
        final title = data['title'] ?? 'New Chat Message';
        final body = data['body'] ?? '';
        final chatId = (data['chatId'] ?? data['chat_id'] ?? '').toString();
        final senderId = (data['senderId'] ?? data['sender_id'] ?? '').toString();
        final senderName = data['senderName'] ?? data['sender_name'] ?? 'Someone';
        
        // Initialize notification service in isolate
        final notificationService = EnhancedNotificationService();
        if (!notificationService.isInitialized) {
          await notificationService.initialize();
        }
        
        // Determine if this is a group chat
        final isGroupChat = !title.contains(senderName) && title != 'New Chat Message';
        final channelId = isGroupChat ? 'group_notifications' : 'chat_notifications';
        
        // Send notification
        await notificationService.sendLocalNotification(
          title: title,
          body: body,
          payload: json.encode({
            'type': isGroupChat ? 'group_message' : 'chat_message',
            'chatId': chatId,
            'senderId': senderId,
            'senderName': senderName,
            'timestamp': DateTime.now().toIso8601String(),
          }),
          channelId: channelId,
        );
        
        Log.i('Notification sent for chat notification: $title', 'FOREGROUND_TASK');
      }
    } catch (e) {
      Log.e('Error handling chat notification in background', 'FOREGROUND_TASK', e);
    }
  }

  /// Handle generic notification event
  Future<void> _handleNotification(dynamic data) async {
    try {
      if (data is Map<String, dynamic>) {
        final title = data['title'] ?? 'New Notification';
        final body = data['body'] ?? '';
        final notificationData = data['data'] ?? {};
        
        // Initialize notification service in isolate
        final notificationService = EnhancedNotificationService();
        if (!notificationService.isInitialized) {
          await notificationService.initialize();
        }
        
        // Send notification
        await notificationService.sendLocalNotification(
          title: title,
          body: body,
          payload: json.encode(notificationData),
          channelId: 'chat_notifications',
        );
        
        Log.i('Notification sent: $title', 'FOREGROUND_TASK');
      }
    } catch (e) {
      Log.e('Error handling notification in background', 'FOREGROUND_TASK', e);
    }
  }
}

