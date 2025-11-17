import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:audioplayers/audioplayers.dart';
import '../config/database_config.dart';
import 'logger_service.dart';
import 'local_auth_service.dart';
import '../main.dart' show navigatorKey;
import 'notification_delivery_coordinator.dart';
import 'web_notification_adapter_stub.dart'
    if (dart.library.html) 'web_notification_adapter.dart' as web_notif;

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
  String _webSoundAsset = 'notification_sound.mp3';

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
      // Load web sound preference (if any)
      try {
        final prefs = await SharedPreferences.getInstance();
        _webSoundAsset = prefs.getString('web_notification_sound_asset') ?? _webSoundAsset;
        Log.i('Web sound asset: $_webSoundAsset', 'ENHANCED_NOTIF');
      } catch (_) {}
      
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
    final AndroidNotificationChannel chatChannel = AndroidNotificationChannel(
      chatChannelId,
      'Chat Notifications',
      description: 'Notifications for chat messages',
      importance: Importance.high,
      playSound: true,
      enableVibration: true,
      enableLights: true,
      // Use a single, consistent raw resource sound across all channels
      sound: RawResourceAndroidNotificationSound('notification_sound'),
    );

    final AndroidNotificationChannel groupChannel = AndroidNotificationChannel(
      groupChannelId,
      'Group Notifications',
      description: 'Notifications for group messages',
      importance: Importance.high,
      playSound: true,
      enableVibration: true,
      enableLights: true,
      // Use the same sound resource for consistency
      sound: RawResourceAndroidNotificationSound('notification_sound'),
    );

    final AndroidNotificationChannel broadcastChannel = AndroidNotificationChannel(
      broadcastChannelId,
      'Broadcast Notifications',
      description: 'Notifications for broadcast messages',
      importance: Importance.high,
      playSound: true,
      enableVibration: true,
      enableLights: true,
      // Keep consistent sound across all channels
      sound: RawResourceAndroidNotificationSound('notification_sound'),
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

      _registerTokenRefreshHandler();

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
        print('📢 [BROADCAST] Received broadcast_notification event');
        print('📢 [BROADCAST] Data type: ${data.runtimeType}');
        print('📢 [BROADCAST] Data: $data');
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
      if (await _shouldDeferToBackgroundService()) {
        Log.i('Skipping socket notification - background service delivering notifications', 'ENHANCED_NOTIF');
        return;
      }
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
      if (await _shouldDeferToBackgroundService()) {
        Log.i('Skipping chat notification - background service delivering notifications', 'ENHANCED_NOTIF');
        return;
      }
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
      if (await _shouldDeferToBackgroundService()) {
        Log.i('Skipping broadcast notification - background service delivering notifications', 'ENHANCED_NOTIF');
        return;
      }
      print('📢 [BROADCAST] _handleBroadcastNotification called with data: $data');
      if (data is Map<String, dynamic>) {
        final title = data['title'] ?? '📢 Broadcast';
        final body = data['body'] ?? '';
        final senderName = data['senderName'] ?? 'Admin';
        
        print('📢 [BROADCAST] Processing notification - Title: $title, Body: $body, Sender: $senderName');
        
        // Play notification sound
        try {
          await _playNotificationSound();
          print('📢 [BROADCAST] Sound played successfully');
        } catch (soundError) {
          print('⚠️ [BROADCAST] Error playing sound: $soundError');
        }
        
        // Show in-app dialog if app is in foreground
        if (navigatorKey.currentState != null) {
          try {
            showDialog(
              context: navigatorKey.currentContext!,
              barrierDismissible: true,
              builder: (context) => AlertDialog(
                title: Row(
                  children: [
                    const Icon(Icons.campaign, color: Colors.blue, size: 28),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        title,
                        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
                content: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (senderName.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Text(
                            'From: $senderName',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[600],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      Text(
                        body,
                        style: const TextStyle(fontSize: 16),
                      ),
                    ],
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Close'),
                  ),
                  ElevatedButton.icon(
                    onPressed: () {
                      Navigator.of(context).pop();
                      navigatorKey.currentState?.pushNamed('/broadcasts');
                    },
                    icon: const Icon(Icons.list, size: 18),
                    label: const Text('View All'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ],
              ),
            );
            print('📢 [BROADCAST] In-app dialog displayed');
          } catch (dialogError) {
            print('⚠️ [BROADCAST] Error showing dialog: $dialogError');
          }
        }
        
        // Display local notification (for when app is in background)
        try {
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
          print('📢 [BROADCAST] Local notification displayed successfully');
        } catch (notifError) {
          print('❌ [BROADCAST] Error displaying notification: $notifError');
        }
        
        Log.i('📢 ✅ COMPLETE: broadcast sound and notification - $title - $body', 'ENHANCED_NOTIF');
        print('📢 [BROADCAST] ✅ Successfully processed broadcast notification');
      } else {
        print('⚠️ [BROADCAST] Data is not a Map: ${data.runtimeType}');
        Log.w('Broadcast notification data is not a Map', 'ENHANCED_NOTIF');
      }
    } catch (e) {
      print('❌ [BROADCAST] Error in _handleBroadcastNotification: $e');
      Log.e('Error handling broadcast notification', 'ENHANCED_NOTIF', e);
    }
  }

  Future<void> _playNotificationSound() async {
    try {
      Log.i('🔊 Playing notification sound...', 'ENHANCED_NOTIF');
      
      // Play the noti_sound.wav file for all notifications (messages and broadcasts)
      // Note: Browsers require prior user interaction to allow audio.
      await _audioPlayer.stop();
      await _audioPlayer.setReleaseMode(ReleaseMode.stop);
      await _audioPlayer.setVolume(1.0);
      try {
        // Primary sound: noti_sound.wav
        await _audioPlayer.play(AssetSource('noti_sound.wav'));
        Log.i('✅ Notification sound played (noti_sound.wav)', 'ENHANCED_NOTIF');
      } catch (e) {
        Log.w('noti_sound.wav failed, trying fallback...', 'ENHANCED_NOTIF');
        try {
          // Fallback to notification_sound.mp3
          await _audioPlayer.play(AssetSource('notification_sound.mp3'));
          Log.i('✅ Notification sound played (notification_sound.mp3 fallback)', 'ENHANCED_NOTIF');
        } catch (e2) {
          Log.w('Fallback asset failed: $e2. Trying additional fallback.', 'ENHANCED_NOTIF');
          try {
            // Try notification_sounds folder
            await _audioPlayer.play(AssetSource('notification_sounds/chat_notification.mp3'));
            Log.i('✅ Notification sound played (chat_notification.mp3 fallback)', 'ENHANCED_NOTIF');
          } catch (e3) {
            Log.w('All sound assets failed: $e3. Using programmatic tone.', 'ENHANCED_NOTIF');
            await _playProgrammaticTone();
          }
        }
      }
    } catch (e) {
      Log.w('Notification sound setup failed: $e', 'ENHANCED_NOTIF');
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
        Log.i('✅ Programmatic tone played (Web data URI)', 'ENHANCED_NOTIF');
      } else {
        // To avoid dart:io imports in a web-compiled unit, skip file-based playback here.
        // Mobile should not normally reach this path since asset fallback exists.
        Log.w('Programmatic tone is not enabled for mobile in current config', 'ENHANCED_NOTIF');
      }
    } catch (e) {
      Log.e('Failed to play programmatic tone', 'ENHANCED_NOTIF', e);
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

  Future<void> _handleNotificationTap(String payload) async {
    try {
      final data = json.decode(payload);
      final type = data['type'];
      
      Log.i('Handling notification tap - Type: $type', 'ENHANCED_NOTIF');
      
      // Handle navigation based on notification type
      switch (type) {
        case 'chat_message':
          // Navigate to chat screen
          final chatId = data['chatId'];
          if (chatId != null && navigatorKey.currentState != null) {
            navigatorKey.currentState!.pushNamed('/chats');
            // TODO: Navigate to specific chat if needed
          }
          break;
        case 'group_message':
          // Navigate to group chat screen
          final chatId = data['chatId'];
          if (chatId != null && navigatorKey.currentState != null) {
            navigatorKey.currentState!.pushNamed('/chats');
            // TODO: Navigate to specific group chat if needed
          }
          break;
        case 'broadcast_message':
          // Navigate to broadcast screen
          if (navigatorKey.currentState != null) {
            navigatorKey.currentState!.pushNamed('/broadcasts');
          }
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
        // iOS/macOS: Request permission through flutter_local_notifications
        try {
          final ios = _fln.resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin>();
          if (ios != null) {
            // Request permissions explicitly
            final result = await ios.requestPermissions(
              alert: true,
              badge: true,
              sound: true,
            );
            if (result == true) {
              Log.i('✅ iOS notification permission granted', 'ENHANCED_NOTIF');
              return true;
            } else {
              Log.w('❌ iOS notification permission denied', 'ENHANCED_NOTIF');
              return false;
            }
          }
          // Fallback: check if already granted
          final settings = await _fln.getNotificationAppLaunchDetails();
          return settings?.didNotificationLaunchApp ?? false;
        } catch (e) {
          Log.e('Error requesting iOS notification permission', 'ENHANCED_NOTIF', e);
          // Try to check current permission status
          try {
            final ios = _fln.resolvePlatformSpecificImplementation<
                IOSFlutterLocalNotificationsPlugin>();
            if (ios != null) {
              final settings = await ios.requestPermissions(
                alert: true,
                badge: true,
                sound: true,
              );
              return settings ?? false;
            }
          } catch (_) {}
          return false;
        }
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
      // On web, use the browser Notification API via adapter
      if (kIsWeb) {
        // Play unified sound and show a banner
        await _playNotificationSound();
        await web_notif.showNotification(title, body, payload);
        // Also show an in-app banner as fallback and visual cue
        await web_notif.showInAppBanner(title, body);
        Log.i('Local notification sent (web adapter): $title', 'ENHANCED_NOTIF');
        return;
      }

      // Always play the unified sound before showing system notification
      await _playNotificationSound();

      final details = NotificationDetails(
        android: AndroidNotificationDetails(
          channelId,
          channelId == groupChannelId ? 'Group Notifications' : 
          channelId == broadcastChannelId ? 'Broadcast Notifications' : 'Chat Notifications',
          importance: Importance.high,
          priority: Priority.high,
          // Disable system sound to avoid duplicate audio; we play our own asset
          playSound: false,
          enableVibration: true,
          enableLights: true,
          // Use channel sound configured in _ensureChannels
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

  /// Configure which bundled asset to use for web notification sound.
  Future<void> setWebSoundAsset(String assetPath) async {
    _webSoundAsset = assetPath;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('web_notification_sound_asset', assetPath);
      Log.i('Web sound asset updated: $assetPath', 'ENHANCED_NOTIF');
    } catch (_) {}
  }

  /// Get current web sound asset path.
  String get webSoundAsset => _webSoundAsset;

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

  Future<bool> _shouldDeferToBackgroundService() async {
    try {
      return await NotificationDeliveryCoordinator.isBackgroundAuthorityActive();
    } catch (_) {
      return false;
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
        _authToken = token;
        Log.i('Notification socket stored refreshed auth token', 'ENHANCED_NOTIF');
      } catch (e) {
        Log.e('Failed to persist refreshed auth token (notification service)', 'ENHANCED_NOTIF', e);
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
}
