import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'logger_service.dart';

class UnifiedNotificationService {
  static final UnifiedNotificationService _instance = UnifiedNotificationService._();
  factory UnifiedNotificationService() => _instance;
  UnifiedNotificationService._();

  final FlutterLocalNotificationsPlugin _fln = FlutterLocalNotificationsPlugin();
  bool _initialized = false;
  bool _channelsCreated = false;
  String? _currentFcmToken;

  // Default system channel used by test screens
  static const String systemChannelId = 'chat_notifications';

  /// Exposes the current FCM token (cached during initialize or status fetch)
  String? get currentFcmToken => _currentFcmToken;
  bool get isInitialized => _initialized;

  Future<void> initialize() async {
    if (_initialized) return;

    const AndroidInitializationSettings androidInit =
        AndroidInitializationSettings('@mipmap/ic_launcher'); // Use your small icon

    final DarwinInitializationSettings iosInit = DarwinInitializationSettings(
      onDidReceiveLocalNotification: (id, title, body, payload) async {},
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
    Log.i('UnifiedNotificationService initialized', 'UNIFIED');

    // Cache FCM token for quick access in test screens
    try {
      _currentFcmToken = await FirebaseMessaging.instance.getToken();
      if (_currentFcmToken != null && _currentFcmToken!.isNotEmpty) {
        Log.i('FCM token cached', 'UNIFIED');
      }
    } catch (e) {
      Log.w('Unable to fetch FCM token during initialize', 'UNIFIED');
    }
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
      // Web / iOS / macOS via FirebaseMessaging
      if (kIsWeb || defaultTargetPlatform == TargetPlatform.iOS || defaultTargetPlatform == TargetPlatform.macOS) {
        final settings = await FirebaseMessaging.instance.requestPermission(
          alert: true,
          badge: true,
          sound: true,
          provisional: false,
        );
        return settings.authorizationStatus == AuthorizationStatus.authorized ||
               settings.authorizationStatus == AuthorizationStatus.provisional;
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

  /// Send FCM notification (placeholder - use FCMNotificationService for actual FCM)
  Future<bool> sendFcmNotification({
    required String title,
    required String body,
    String? fcmToken,
    List<String>? tokens,
    Map<String, dynamic>? data,
  }) async {
    try {
      // This is a placeholder - actual FCM sending should be done via FCMNotificationService
      Log.i('FCM notification requested (placeholder)', 'UNIFIED');
      return true;
    } catch (e) {
      Log.e('Error sending FCM notification', 'UNIFIED', e);
      return false;
    }
  }

  /// Subscribe to FCM topic
  Future<void> subscribeToTopic(String topic) async {
    try {
      await FirebaseMessaging.instance.subscribeToTopic(topic);
      Log.i('Subscribed to topic: $topic', 'UNIFIED');
    } catch (e) {
      Log.e('Error subscribing to topic: $topic', 'UNIFIED', e);
    }
  }

  /// Unsubscribe from FCM topic
  Future<void> unsubscribeFromTopic(String topic) async {
    try {
      await FirebaseMessaging.instance.unsubscribeFromTopic(topic);
      Log.i('Unsubscribed from topic: $topic', 'UNIFIED');
    } catch (e) {
      Log.e('Error unsubscribing from topic: $topic', 'UNIFIED', e);
    }
  }

  /// Request iOS notification permission
  Future<bool> requestIOSNotificationPermission() async {
    try {
      final settings = await FirebaseMessaging.instance.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );
      return settings.authorizationStatus == AuthorizationStatus.authorized;
    } catch (e) {
      Log.e('Error requesting iOS notification permission', 'UNIFIED', e);
      return false;
    }
  }

  /// Get a snapshot of notification status for diagnostics
  Future<Map<String, dynamic>> getNotificationStatus() async {
    try {
      // Fetch latest token
      try {
        _currentFcmToken ??= await FirebaseMessaging.instance.getToken();
      } catch (_) {}

      // Fetch notification settings if supported
      NotificationSettings? settings;
      try {
        settings = await FirebaseMessaging.instance.getNotificationSettings();
      } catch (_) {}

      // Compute permission flag across platforms
      bool hasPermission = false;
      try {
        if (kIsWeb || defaultTargetPlatform == TargetPlatform.iOS || defaultTargetPlatform == TargetPlatform.macOS) {
          if (settings != null) {
            hasPermission = settings.authorizationStatus == AuthorizationStatus.authorized ||
                            settings.authorizationStatus == AuthorizationStatus.provisional;
          }
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
        'authorizationStatus': settings != null
            ? describeEnum(settings.authorizationStatus)
            : 'unknown',
        'fcmToken': _currentFcmToken,
        'tokenPresent': (_currentFcmToken != null && _currentFcmToken!.isNotEmpty),
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
        'fcmToken': _currentFcmToken,
        'tokenPresent': (_currentFcmToken != null && _currentFcmToken!.isNotEmpty),
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
