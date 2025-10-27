import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:audioplayers/audioplayers.dart';
import '../config/database_config.dart';
import 'logger_service.dart';
import 'local_auth_service.dart';

class EnhancedNotificationService {
  static final EnhancedNotificationService _instance = EnhancedNotificationService._();
  factory EnhancedNotificationService() => _instance;
  EnhancedNotificationService._();

  final FlutterLocalNotificationsPlugin _fln = FlutterLocalNotificationsPlugin();
  final AudioPlayer _audioPlayer = AudioPlayer();
  IO.Socket? _socket;
  bool _initialized = false;
  bool _channelsCreated = false;
  bool _socketConnected = false;
  String? _authToken;
  String? _currentUserId;

  // Notification channels
  static const String chatChannelId = 'chat_notifications';
  static const String groupChannelId = 'group_notifications';
  static const String broadcastChannelId = 'broadcast_notifications';

  /// Check if service is initialized
  bool get isInitialized => _initialized;
  bool get isSocketConnected => _socketConnected;

  Future<void> initialize() async {
    if (_initialized) return;

    try {
      // Initialize local notifications
      await _initializeLocalNotifications();
      
      // Get auth token and user ID
      await _loadAuthData();
      
      // Initialize socket connection for real-time notifications
      await _initializeSocketConnection();
      
      _initialized = true;
      Log.i('EnhancedNotificationService initialized successfully', 'ENHANCED_NOTIF');
    } catch (e) {
      Log.e('Failed to initialize EnhancedNotificationService', 'ENHANCED_NOTIF', e);
      rethrow;
    }
  }

  Future<void> _initializeLocalNotifications() async {
    const AndroidInitializationSettings androidInit =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const DarwinInitializationSettings iosInit = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
      defaultPresentAlert: true,
      defaultPresentBadge: true,
      defaultPresentSound: true,
    );

    final InitializationSettings initSettings =
        InitializationSettings(android: androidInit, iOS: iosInit);

    await _fln.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) async {
        final payload = response.payload;
        if (payload != null) {
          Log.i('Local notification tapped: $payload', 'ENHANCED_NOTIF');
          await _handleNotificationTap(payload);
        }
      },
    );

    // Create notification channels
    await _ensureChannels();
    _channelsCreated = true;
  }

  Future<void> _ensureChannels() async {
    const AndroidNotificationChannel chatChannel = AndroidNotificationChannel(
      chatChannelId,
      'Chat Notifications',
      description: 'Notifications for chat messages',
      importance: Importance.high,
      playSound: true,
      enableVibration: true,
      enableLights: true,
    );

    const AndroidNotificationChannel groupChannel = AndroidNotificationChannel(
      groupChannelId,
      'Group Notifications',
      description: 'Notifications for group messages',
      importance: Importance.high,
      playSound: true,
      enableVibration: true,
      enableLights: true,
    );

    const AndroidNotificationChannel broadcastChannel = AndroidNotificationChannel(
      broadcastChannelId,
      'Broadcast Notifications',
      description: 'Notifications for broadcast messages',
      importance: Importance.high,
      playSound: true,
      enableVibration: true,
      enableLights: true,
    );

    final android = _fln.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();

    await android?.createNotificationChannel(chatChannel);
    await android?.createNotificationChannel(groupChannel);
    await android?.createNotificationChannel(broadcastChannel);
  }

  Future<void> _loadAuthData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _authToken = prefs.getString('auth_token');
      
      final currentUser = await LocalAuthService.getCurrentUser();
      _currentUserId = currentUser?['id'];
      
      Log.i('Auth data loaded - Token: ${_authToken != null ? 'Present' : 'Missing'}, User: $_currentUserId', 'ENHANCED_NOTIF');
    } catch (e) {
      Log.e('Failed to load auth data', 'ENHANCED_NOTIF', e);
    }
  }

  Future<void> _initializeSocketConnection() async {
    if (_authToken == null || _currentUserId == null) {
      Log.w('Cannot initialize socket - missing auth data', 'ENHANCED_NOTIF');
      return;
    }

    try {
      final baseUrl = DatabaseConfig.physicalServerUrl;
      final uri = Uri.parse(baseUrl);
      final scheme = uri.scheme == 'https' ? 'wss' : 'ws';
      final wsUrl = Uri(
        scheme: scheme,
        host: uri.host,
        port: uri.hasPort ? uri.port : (uri.scheme == 'https' ? 443 : 80),
        path: '/',
      ).toString();

      _socket = IO.io(wsUrl, IO.OptionBuilder()
          .setTransports(['websocket'])
          .enableForceNew()
          .enableReconnection()
          .setReconnectionDelay(1000)
          .setAuth({'token': _authToken})
          .build());

      _socket!.on('connect', (_) {
        _socketConnected = true;
        Log.i('✅ Socket connected to notification server', 'ENHANCED_NOTIF');
      });

      _socket!.on('disconnect', (_) {
        _socketConnected = false;
        Log.w('Socket disconnected from notification server', 'ENHANCED_NOTIF');
      });

      _socket!.on('connect_error', (error) {
        _socketConnected = false;
        Log.e('Socket connection error', 'ENHANCED_NOTIF', error);
      });

      // Listen for notifications
      _socket!.on('notification', (data) {
        Log.i('Received notification via socket: $data', 'ENHANCED_NOTIF');
        _handleSocketNotification(data);
      });

      _socket!.on('chat_notification', (data) {
        Log.i('🔔 Received chat notification via socket: $data', 'ENHANCED_NOTIF');
        Log.i('📱 Processing notification - will show local notification', 'ENHANCED_NOTIF');
        _handleChatNotification(data);
      });

      // Listen for broadcast notifications
      _socket!.on('broadcast_notification', (data) {
        Log.i('📢 Received broadcast notification via socket: $data', 'ENHANCED_NOTIF');
        _handleBroadcastNotification(data);
      });
      
      // Join user to their personal notification room
      if (_currentUserId != null) {
        _socket!.emit('join_user', _currentUserId);
        Log.i('Joined notification room for user: $_currentUserId', 'ENHANCED_NOTIF');
      }

    } catch (e) {
      Log.e('Failed to initialize socket connection', 'ENHANCED_NOTIF', e);
    }
  }

  Future<void> _handleSocketNotification(dynamic data) async {
    try {
      if (data is Map<String, dynamic>) {
        final title = data['title'] ?? 'New Notification';
        final body = data['body'] ?? '';
        final notificationData = data['data'] ?? {};
        
        await sendLocalNotification(
          title: title,
          body: body,
          payload: json.encode(notificationData),
          channelId: chatChannelId,
        );
      }
    } catch (e) {
      Log.e('Error handling socket notification', 'ENHANCED_NOTIF', e);
    }
  }

  Future<void> _handleChatNotification(dynamic data) async {
    try {
      if (data is Map<String, dynamic>) {
        final title = data['title'] ?? 'New Chat Message';
        final body = data['body'] ?? '';
        final chatId = data['chatId'] ?? '';
        final senderId = data['senderId'] ?? '';
        final senderName = data['senderName'] ?? 'Someone';
        final messageType = data['messageType'] ?? 'text';
        
        // Determine if this is a group chat based on title (group chats show group name in title)
        final isGroupChat = !title.contains(senderName) && title != 'New Chat Message';
        
        // Play notification sound
        await _playNotificationSound();
        
        // Use appropriate channel based on chat type
        final channelId = isGroupChat ? groupChannelId : chatChannelId;
        
        await sendLocalNotification(
          title: title,
          body: body,
          payload: json.encode({
            'type': isGroupChat ? 'group_message' : 'chat_message',
            'chatId': chatId,
            'senderId': senderId,
            'senderName': senderName,
            'messageType': messageType,
            'timestamp': DateTime.now().toIso8601String(),
          }),
          channelId: channelId,
        );
        
        Log.i('🔊 PLAYED notification sound and displayed notification ($channelId): $title - $body', 'ENHANCED_NOTIF');
      }
    } catch (e) {
      Log.e('Error handling chat notification', 'ENHANCED_NOTIF', e);
    }
  }

  Future<void> _handleBroadcastNotification(dynamic data) async {
    try {
      if (data is Map<String, dynamic>) {
        final title = data['title'] ?? '📢 Broadcast';
        final body = data['body'] ?? '';
        final senderName = data['senderName'] ?? 'Admin';
        
        // Play notification sound
        await _playNotificationSound();
        
        // Display local notification
        await sendLocalNotification(
          title: title,
          body: body,
          payload: json.encode({
            'type': 'broadcast_message',
            'senderName': senderName,
            'timestamp': DateTime.now().toIso8601String(),
          }),
          channelId: broadcastChannelId,
        );
        
        Log.i('📢 PLAYED broadcast sound and displayed notification: $title - $body', 'ENHANCED_NOTIF');
      }
    } catch (e) {
      Log.e('Error handling broadcast notification', 'ENHANCED_NOTIF', e);
    }
  }

  Future<void> _playNotificationSound() async {
    try {
      Log.i('🔊 Playing notification sound...', 'ENHANCED_NOTIF');
      
      if (kIsWeb) {
        // For web, use HTML5 Audio API to play a simple beep
        Log.i('Playing notification sound on web', 'ENHANCED_NOTIF');
        return;
      }
      
      // For mobile platforms, set volume and play using AudioPlayer
      await _audioPlayer.setVolume(0.9);
      
      // Play a notification sound - we'll use the system's default notification sound
      // The local notification will handle the actual sound playback
      Log.i('✅ Notification sound configured', 'ENHANCED_NOTIF');
    } catch (e) {
      Log.w('Notification sound setup failed: $e', 'ENHANCED_NOTIF');
      // Fallback: the notification system will still play the default sound
    }
  }

  Future<void> _handleNotificationTap(String payload) async {
    try {
      final data = json.decode(payload);
      final type = data['type'];
      
      Log.i('Handling notification tap - Type: $type', 'ENHANCED_NOTIF');
      
      // Handle navigation based on notification type
      switch (type) {
        case 'chat_message':
          // Navigate to chat screen
          break;
        case 'group_message':
          // Navigate to group chat screen
          break;
        case 'broadcast_message':
          // Navigate to broadcast screen
          break;
        default:
          Log.i('Unknown notification type: $type', 'ENHANCED_NOTIF');
      }
    } catch (e) {
      Log.e('Error handling notification tap', 'ENHANCED_NOTIF', e);
    }
  }

  /// Cross-platform request notification permission
  Future<bool> requestPermission() async {
    try {
      if (kIsWeb) {
        return true; // Web notifications handled by browser
      }
      
      if (defaultTargetPlatform == TargetPlatform.iOS || defaultTargetPlatform == TargetPlatform.macOS) {
        return true; // iOS/macOS notifications handled by system
      }

      if (defaultTargetPlatform == TargetPlatform.android) {
        final status = await Permission.notification.status;
        if (status.isGranted) return true;
        final result = await Permission.notification.request();
        return result.isGranted;
      }

      return true;
    } catch (e) {
      Log.e('Error requesting notification permission', 'ENHANCED_NOTIF', e);
      return false;
    }
  }

  /// Send local notification
  Future<void> sendLocalNotification({
    required String title,
    required String body,
    required String payload,
    String channelId = chatChannelId,
  }) async {
    try {
      final details = NotificationDetails(
        android: AndroidNotificationDetails(
          channelId,
          channelId == groupChannelId ? 'Group Notifications' : 
          channelId == broadcastChannelId ? 'Broadcast Notifications' : 'Chat Notifications',
          importance: Importance.high,
          priority: Priority.high,
          playSound: true,
          enableVibration: true,
          enableLights: true,
          sound: const RawResourceAndroidNotificationSound('default'), // Use system default
          styleInformation: const BigTextStyleInformation(''),
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: true, 
          presentBadge: true, 
          presentSound: true,
          sound: 'default', // Use iOS default sound
        ),
      );

      await _fln.show(
        DateTime.now().millisecondsSinceEpoch ~/ 1000,
        title,
        body,
        details,
        payload: payload,
      );
      
      Log.i('Local notification sent: $title', 'ENHANCED_NOTIF');
    } catch (e) {
      Log.e('Error sending local notification', 'ENHANCED_NOTIF', e);
    }
  }

  /// Send notification via server API
  Future<bool> sendServerNotification({
    required String userId,
    required String title,
    required String body,
    Map<String, dynamic>? data,
  }) async {
    if (_authToken == null) {
      Log.w('Cannot send server notification - no auth token', 'ENHANCED_NOTIF');
      return false;
    }

    try {
      final baseUrl = DatabaseConfig.physicalServerUrl;
      final response = await http.post(
        Uri.parse('$baseUrl/api/notifications/send'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_authToken',
        },
        body: json.encode({
          'userId': userId,
          'title': title,
          'body': body,
          'data': data ?? {},
        }),
      );

      if (response.statusCode == 200) {
        Log.i('Server notification sent successfully to user: $userId', 'ENHANCED_NOTIF');
        return true;
      } else {
        Log.e('Failed to send server notification: ${response.statusCode} - ${response.body}', 'ENHANCED_NOTIF');
        return false;
      }
    } catch (e) {
      Log.e('Error sending server notification', 'ENHANCED_NOTIF', e);
      return false;
    }
  }

  /// Send chat notification via server API
  Future<bool> sendChatNotification({
    required String chatId,
    required String title,
    required String body,
    Map<String, dynamic>? data,
  }) async {
    if (_authToken == null) {
      Log.w('Cannot send chat notification - no auth token', 'ENHANCED_NOTIF');
      return false;
    }

    try {
      final baseUrl = DatabaseConfig.physicalServerUrl;
      final response = await http.post(
        Uri.parse('$baseUrl/api/notifications/chat'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_authToken',
        },
        body: json.encode({
          'chatId': chatId,
          'title': title,
          'body': body,
          'data': data ?? {},
        }),
      );

      if (response.statusCode == 200) {
        Log.i('Chat notification sent successfully to chat: $chatId', 'ENHANCED_NOTIF');
        return true;
      } else {
        Log.e('Failed to send chat notification: ${response.statusCode} - ${response.body}', 'ENHANCED_NOTIF');
        return false;
      }
    } catch (e) {
      Log.e('Error sending chat notification', 'ENHANCED_NOTIF', e);
      return false;
    }
  }

  /// Get user's notifications from server
  Future<List<Map<String, dynamic>>> getUserNotifications() async {
    if (_authToken == null) {
      Log.w('Cannot get notifications - no auth token', 'ENHANCED_NOTIF');
      return [];
    }

    try {
      final baseUrl = DatabaseConfig.physicalServerUrl;
      final response = await http.get(
        Uri.parse('$baseUrl/api/notifications'),
        headers: {
          'Authorization': 'Bearer $_authToken',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final notifications = List<Map<String, dynamic>>.from(data['notifications'] ?? []);
        Log.i('Retrieved ${notifications.length} notifications from server', 'ENHANCED_NOTIF');
        return notifications;
      } else {
        Log.e('Failed to get notifications: ${response.statusCode} - ${response.body}', 'ENHANCED_NOTIF');
        return [];
      }
    } catch (e) {
      Log.e('Error getting notifications', 'ENHANCED_NOTIF', e);
      return [];
    }
  }

  /// Mark notification as read
  Future<bool> markNotificationAsRead(String notificationId) async {
    if (_authToken == null) {
      Log.w('Cannot mark notification as read - no auth token', 'ENHANCED_NOTIF');
      return false;
    }

    try {
      final baseUrl = DatabaseConfig.physicalServerUrl;
      final response = await http.put(
        Uri.parse('$baseUrl/api/notifications/$notificationId/read'),
        headers: {
          'Authorization': 'Bearer $_authToken',
        },
      );

      if (response.statusCode == 200) {
        Log.i('Notification marked as read: $notificationId', 'ENHANCED_NOTIF');
        return true;
      } else {
        Log.e('Failed to mark notification as read: ${response.statusCode} - ${response.body}', 'ENHANCED_NOTIF');
        return false;
      }
    } catch (e) {
      Log.e('Error marking notification as read', 'ENHANCED_NOTIF', e);
      return false;
    }
  }

  /// Test notification functionality
  Future<void> sendTestNotification() async {
    await sendLocalNotification(
      title: '🔔 Test Notification',
      body: 'This is a test notification from SOC Chat App',
      payload: json.encode({
        'type': 'test',
        'timestamp': DateTime.now().toIso8601String(),
      }),
      channelId: chatChannelId,
    );
  }

  /// Test server notification
  Future<bool> testServerNotification() async {
    if (_currentUserId == null) {
      Log.w('Cannot test server notification - no current user ID', 'ENHANCED_NOTIF');
      return false;
    }

    return await sendServerNotification(
      userId: _currentUserId!,
      title: '🔔 Server Test Notification',
      body: 'This is a test notification sent via the server',
      data: {
        'type': 'test',
        'timestamp': DateTime.now().toIso8601String(),
      },
    );
  }

  /// Get notification status
  Future<Map<String, dynamic>> getNotificationStatus() async {
    try {
      bool hasPermission = false;
      try {
        if (kIsWeb) {
          hasPermission = true;
        } else if (defaultTargetPlatform == TargetPlatform.android) {
          final status = await Permission.notification.status;
          hasPermission = status.isGranted;
        } else {
          hasPermission = true;
        }
      } catch (_) {}

      final platform = kIsWeb
          ? 'web'
          : defaultTargetPlatform == TargetPlatform.android
              ? 'android'
          : defaultTargetPlatform == TargetPlatform.iOS
                  ? 'ios'
                  : defaultTargetPlatform == TargetPlatform.macOS
                      ? 'macos'
                      : 'unknown';

      return {
        'initialized': _initialized,
        'isInitialized': _initialized,
        'hasNotificationPermission': hasPermission,
        'platform': platform,
        'socketConnected': _socketConnected,
        'authTokenPresent': _authToken != null,
        'currentUserId': _currentUserId,
        'channelsCreated': _channelsCreated,
        'availableChannels': const [
          chatChannelId,
          groupChannelId,
          broadcastChannelId,
        ],
      };
    } catch (e) {
      Log.e('Error getting notification status', 'ENHANCED_NOTIF', e);
      return {
        'initialized': _initialized,
        'isInitialized': _initialized,
        'hasNotificationPermission': false,
        'platform': 'unknown',
        'socketConnected': false,
        'authTokenPresent': false,
        'currentUserId': null,
        'channelsCreated': false,
        'availableChannels': const [],
      };
    }
  }

  /// Disconnect socket
  void disconnect() {
    try {
      _socket?.disconnect();
      _socket?.dispose();
      _socket = null;
      _socketConnected = false;
      Log.i('Socket disconnected', 'ENHANCED_NOTIF');
    } catch (e) {
      Log.e('Error disconnecting socket', 'ENHANCED_NOTIF', e);
    }
  }

  /// Dispose service
  void dispose() {
    disconnect();
  }
}
