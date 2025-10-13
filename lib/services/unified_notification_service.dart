import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';
import 'logger_service.dart';

class UnifiedNotificationService {
  static final UnifiedNotificationService _instance = UnifiedNotificationService._();
  factory UnifiedNotificationService() => _instance;
  UnifiedNotificationService._();

  final FlutterLocalNotificationsPlugin _fln = FlutterLocalNotificationsPlugin();
  bool _initialized = false;
  bool _channelsCreated = false;

  // Default system channel used by test screens
  static const String systemChannelId = 'chat_notifications';

  /// Check if service is initialized
  bool get isInitialized => _initialized;

  Future<void> initialize() async {
    if (_initialized) return;

    const AndroidInitializationSettings androidInit =
        AndroidInitializationSettings('@mipmap/ic_launcher'); // Use your small icon

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
          Log.i('Local notif tapped payload: $payload', 'UNIFIED');
          // Handle navigation based on payload if needed
        }
      },
    );

    // Create commonly used channels (MUST match IDs used by pushes)
    await _ensureChannels();
    _channelsCreated = true;

    _initialized = true;
    Log.i('UnifiedNotificationService initialized (physical server mode)', 'UNIFIED');
  }

  Future<void> _ensureChannels() async {
    const AndroidNotificationChannel chatChannel = AndroidNotificationChannel(
      'chat_notifications',
        'Chat Notifications',
        description: 'Notifications for chat messages',
        importance: Importance.high,
        playSound: true,
      sound: RawResourceAndroidNotificationSound('chat_notification'),
    );

    const AndroidNotificationChannel groupChannel = AndroidNotificationChannel(
      'group_notifications',
      'Group Notifications',
      description: 'Notifications for group messages',
      importance: Importance.high,
        playSound: true,
      sound: RawResourceAndroidNotificationSound('group_notification'),
    );

    const AndroidNotificationChannel broadcastChannel = AndroidNotificationChannel(
      'broadcast_notifications',
      'Broadcast Notifications',
      description: 'Notifications for broadcast messages',
      importance: Importance.high,
        playSound: true,
        sound: RawResourceAndroidNotificationSound('notification_sound'),
      );

    final android = _fln.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();

    await android?.createNotificationChannel(chatChannel);
    await android?.createNotificationChannel(groupChannel);
    await android?.createNotificationChannel(broadcastChannel);
  }

  /// Cross-platform request notification permission
  Future<bool> requestPermission() async {
    try {
      // Web / iOS / macOS - simplified permission handling
      if (kIsWeb) {
        // Web notifications handled by browser
        return true;
      }
      
      if (defaultTargetPlatform == TargetPlatform.iOS || defaultTargetPlatform == TargetPlatform.macOS) {
        // iOS/macOS notifications handled by system
        return true;
      }

      // Android notification runtime permission via permission_handler
      if (defaultTargetPlatform == TargetPlatform.android) {
        final status = await Permission.notification.status;
        if (status.isGranted) return true;
        final result = await Permission.notification.request();
        return result.isGranted;
      }

      // Other platforms: assume granted
      return true;
    } catch (e) {
      Log.e('Error requesting notification permission', 'UNIFIED', e);
      return false;
    }
  }

  Future<void> sendLocalNotification({
    required String title,
    required String body,
    required String payload,
    String channelId = 'chat_notifications',
  }) async {
    final details = NotificationDetails(
      android: AndroidNotificationDetails(
        channelId,
        channelId == 'group_notifications' ? 'Group Notifications' : 
        channelId == 'broadcast_notifications' ? 'Broadcast Notifications' : 'Chat Notifications',
        importance: Importance.high,
        priority: Priority.high,
        playSound: true,
        sound: channelId == 'group_notifications'
            ? const RawResourceAndroidNotificationSound('group_notification')
            : channelId == 'broadcast_notifications'
                ? const RawResourceAndroidNotificationSound('notification_sound')
                : const RawResourceAndroidNotificationSound('chat_notification'),
        styleInformation: const BigTextStyleInformation(''),
      ),
      iOS: const DarwinNotificationDetails(presentAlert: true, presentBadge: true, presentSound: true),
    );

    await _fln.show(
        DateTime.now().millisecondsSinceEpoch ~/ 1000,
        title,
        body,
        details,
        payload: payload,
      );
  }

  /// Convenience: Send local notification for 1:1 chat message with sound
  Future<void> sendChatMessageNotification({
    required String title,
    required String body,
    required String chatId,
    required String senderId,
    required String senderName,
    String? messageType,
  }) async {
    await sendLocalNotification(
      title: title,
      body: body,
      payload: json.encode({
        'type': 'chat_message',
        'chatId': chatId,
        'senderId': senderId,
        'senderName': senderName,
        'messageType': messageType ?? 'text',
        'timestamp': DateTime.now().toIso8601String(),
      }),
      channelId: 'chat_notifications',
    );
  }

  /// Convenience: Send local notification for group message with sound
  Future<void> sendGroupMessageNotification({
    required String title,
    required String body,
    required String groupId,
    required String groupName,
    required String senderId,
    required String senderName,
    String? messageType,
  }) async {
    await sendLocalNotification(
      title: title,
      body: body,
      payload: json.encode({
        'type': 'group_message',
        'groupId': groupId,
        'groupName': groupName,
        'senderId': senderId,
        'senderName': senderName,
        'messageType': messageType ?? 'text',
        'timestamp': DateTime.now().toIso8601String(),
      }),
      channelId: 'group_notifications',
    );
  }

  /// Send broadcast notification
  Future<bool> sendBroadcastNotification({
    required String title,
    required String body,
    String? senderId,
    String? senderName,
    String? messageType,
    String? topic,
    Map<String, dynamic>? data,
  }) async {
    try {
      await sendLocalNotification(
        title: title,
        body: body,
        payload: json.encode({
          'type': 'broadcast_message',
          'senderId': senderId,
          'senderName': senderName,
          'messageType': messageType ?? 'text',
          'timestamp': DateTime.now().toIso8601String(),
        }),
        channelId: 'broadcast_notifications',
      );
        return true;
    } catch (e) {
      Log.e('Error sending broadcast notification', 'UNIFIED', e);
      return false;
    }
  }

  /// Send notification (placeholder - physical server mode)
  Future<bool> sendNotification({
    required String title,
    required String body,
    String? token,
    List<String>? tokens,
    Map<String, dynamic>? data,
  }) async {
    try {
      // Physical server mode - notifications handled by server
      Log.i('Notification requested (physical server mode)', 'UNIFIED');
      return true;
    } catch (e) {
      Log.e('Error sending notification', 'UNIFIED', e);
      return false;
    }
  }

  /// Request iOS notification permission
  Future<bool> requestIOSNotificationPermission() async {
    try {
      // Physical server mode - iOS notifications handled by system
      Log.i('iOS notification permission requested (physical server mode)', 'UNIFIED');
      return true;
    } catch (e) {
      Log.e('Error requesting iOS notification permission', 'UNIFIED', e);
      return false;
    }
  }

  /// Get a snapshot of notification status for diagnostics
  Future<Map<String, dynamic>> getNotificationStatus() async {
    try {
      // Physical server mode - simplified status
      Log.i('Getting notification status (physical server mode)', 'UNIFIED');

      // Compute permission flag across platforms
      bool hasPermission = false;
      try {
        if (kIsWeb) {
          hasPermission = true; // Web notifications handled by browser
        } else if (defaultTargetPlatform == TargetPlatform.android) {
          final status = await Permission.notification.status;
          hasPermission = status.isGranted;
        } else {
          hasPermission = true; // iOS/macOS notifications handled by system
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
        'authorizationStatus': 'physical_server_mode',
        'tokenPresent': false, // No FCM tokens in physical server mode
        'channelsCreated': _channelsCreated,
        'availableChannels': const [
          'chat_notifications',
          'group_notifications',
          'broadcast_notifications',
        ],
        'systemChannelId': systemChannelId,
      };
    } catch (e) {
      Log.e('Error getting notification status', 'UNIFIED', e);
      return {
        'initialized': _initialized,
        'isInitialized': _initialized,
        'hasNotificationPermission': false,
        'platform': 'unknown',
        'authorizationStatus': 'unknown',
        'fcmToken': null, // No FCM tokens in physical server mode
        'tokenPresent': false, // No FCM tokens in physical server mode
        'channelsCreated': _channelsCreated,
        'availableChannels': const [
          'chat_notifications',
          'group_notifications',
          'broadcast_notifications',
        ],
        'systemChannelId': systemChannelId,
      };
    }
  }

  /// Send test notification
  Future<void> sendTestNotification() async {
    await sendLocalNotification(
      title: '🔔 Test Notification',
      body: 'This is a test notification from SOC Chat App',
      payload: json.encode({
        'type': 'test',
        'timestamp': DateTime.now().toIso8601String(),
      }),
      channelId: 'chat_notifications',
    );
  }
}
