import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:audioplayers/audioplayers.dart';
import 'dart:math' as math;
import 'dart:typed_data';
import 'package:permission_handler/permission_handler.dart';
import 'logger_service.dart';

class UnifiedNotificationService {
  static final UnifiedNotificationService _instance = UnifiedNotificationService._();
  factory UnifiedNotificationService() => _instance;
  UnifiedNotificationService._();

  final FlutterLocalNotificationsPlugin _fln = FlutterLocalNotificationsPlugin();
  bool _initialized = false;
  bool _channelsCreated = false;
  final AudioPlayer _audioPlayer = AudioPlayer();

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
    final AndroidNotificationChannel chatChannel = AndroidNotificationChannel(
      'chat_notifications',
        'Chat Notifications',
        description: 'Notifications for chat messages',
        importance: Importance.high,
        playSound: true,
        sound: RawResourceAndroidNotificationSound('notification_sound'),
    );

    final AndroidNotificationChannel groupChannel = AndroidNotificationChannel(
      'group_notifications',
      'Group Notifications',
      description: 'Notifications for group messages',
      importance: Importance.high,
        playSound: true,
        sound: RawResourceAndroidNotificationSound('notification_sound'),
    );

    final AndroidNotificationChannel broadcastChannel = AndroidNotificationChannel(
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

  Future<void> _playNotificationSound() async {
    // Skip sound on mobile - use device notification sound only
    if (!kIsWeb) {
      Log.i('🔇 Unified notification sound skipped on Mobile (using device notification sound)', 'UNIFIED');
      return;
    }
    
    try {
      await _audioPlayer.stop();
      await _audioPlayer.setReleaseMode(ReleaseMode.stop);
      await _audioPlayer.setVolume(1.0);
      try {
        // Primary sound: noti_sound.wav (WEB ONLY)
        await _audioPlayer.play(AssetSource('noti_sound.wav'));
        Log.i('✅ Unified notification sound played (noti_sound.wav) on Web', 'UNIFIED');
      } catch (e) {
        Log.w('noti_sound.wav failed on Web, trying fallback...', 'UNIFIED');
        try {
          // Fallback to notification_sound.mp3
          await _audioPlayer.play(AssetSource('notification_sound.mp3'));
          Log.i('✅ Unified notification sound played (notification_sound.mp3 fallback) on Web', 'UNIFIED');
        } catch (e2) {
          Log.w('Fallback asset failed on Web: $e2. Trying additional fallback.', 'UNIFIED');
          try {
            // Try notification_sounds folder
            await _audioPlayer.play(AssetSource('notification_sounds/chat_notification.mp3'));
            Log.i('✅ Unified notification sound played (chat_notification.mp3 fallback) on Web', 'UNIFIED');
          } catch (e3) {
            Log.w('All sound assets failed on Web: $e3. Using programmatic tone.', 'UNIFIED');
            await _playProgrammaticTone();
          }
        }
      }
    } catch (e) {
      Log.w('Notification sound play failed: $e', 'UNIFIED');
    }
  }

  /// Last-resort programmatic tone (440Hz sine, ~500ms)
  Future<void> _playProgrammaticTone({
    int sampleRate = 44100,
    int durationMs = 500,
    double frequency = 440.0,
    double volume = 0.3,
  }) async {
    try {
      final bytes = _generateWavToneBytes(
        sampleRate: sampleRate,
        durationMs: durationMs,
        frequency: frequency,
        volume: volume,
      );
      await _audioPlayer.stop();
      await _audioPlayer.setReleaseMode(ReleaseMode.stop);
      await _audioPlayer.setVolume(1.0);
      if (kIsWeb) {
        final dataUri = 'data:audio/wav;base64,' + base64Encode(bytes);
        await _audioPlayer.play(UrlSource(dataUri));
        Log.i('✅ Programmatic tone played (Web data URI)', 'UNIFIED');
      } else {
        Log.w('Programmatic tone is not enabled for mobile in current config', 'UNIFIED');
      }
    } catch (e) {
      Log.e('Failed to play programmatic tone', 'UNIFIED', e);
    }
  }

  Uint8List _generateWavToneBytes({
    required int sampleRate,
    required int durationMs,
    required double frequency,
    required double volume,
  }) {
    final numSamples = ((sampleRate * durationMs) / 1000).round();
    final bytesPerSample = 2; // 16-bit PCM
    final dataSize = numSamples * bytesPerSample;

    final buffer = BytesBuilder();

    // RIFF header
    void writeString(String s) => buffer.add(s.codeUnits);
    void writeInt32LE(int value) => buffer.add(Uint8List(4)
      ..[0] = value & 0xFF
      ..[1] = (value >> 8) & 0xFF
      ..[2] = (value >> 16) & 0xFF
      ..[3] = (value >> 24) & 0xFF);
    void writeInt16LE(int value) => buffer.add(Uint8List(2)
      ..[0] = value & 0xFF
      ..[1] = (value >> 8) & 0xFF);

    writeString('RIFF');
    writeInt32LE(36 + dataSize); // Chunk size
    writeString('WAVE');

    // fmt chunk
    writeString('fmt ');
    writeInt32LE(16); // Subchunk1Size
    writeInt16LE(1);  // AudioFormat (PCM)
    writeInt16LE(1);  // NumChannels
    writeInt32LE(sampleRate);
    writeInt32LE(sampleRate * bytesPerSample); // ByteRate
    writeInt16LE(bytesPerSample); // BlockAlign
    writeInt16LE(16); // BitsPerSample

    // data chunk
    writeString('data');
    writeInt32LE(dataSize);

    // Generate sine wave with simple fade in/out to avoid clicks
    final twoPiF = 2 * math.pi * frequency;
    for (int i = 0; i < numSamples; i++) {
      final t = i / sampleRate;
      double sample = math.sin(twoPiF * t);
      // Apply 5ms fade in/out
      final fadeSamples = (0.005 * sampleRate).round();
      double gain = 1.0;
      if (i < fadeSamples) {
        gain = i / fadeSamples;
      } else if (i > numSamples - fadeSamples) {
        gain = (numSamples - i) / fadeSamples;
      }
      final intSample = (sample * gain * volume * 32767).round().clamp(-32768, 32767);
      writeInt16LE(intSample & 0xFFFF);
    }

    return Uint8List.fromList(buffer.toBytes());
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
    // Play unified asset sound before showing system notification
    await _playNotificationSound();

    final details = NotificationDetails(
      android: AndroidNotificationDetails(
        channelId,
        channelId == 'group_notifications' ? 'Group Notifications' : 
        channelId == 'broadcast_notifications' ? 'Broadcast Notifications' : 'Chat Notifications',
        importance: Importance.high,
        priority: Priority.high,
        // Disable system sound to avoid duplicate; we play our own asset
        playSound: false,
        styleInformation: BigTextStyleInformation(''),
      ),
      iOS: DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        // Disable system sound; we play our own asset for consistency
        presentSound: false,
      ),
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
