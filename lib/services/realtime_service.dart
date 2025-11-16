import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../config/database_config.dart';
import 'logger_service.dart';

typedef MessageCallback = void Function(Map<String, dynamic> message);

class RealtimeService {
  static final RealtimeService instance = RealtimeService._internal();
  RealtimeService._internal();

  IO.Socket? _socket;
  bool _connecting = false;

  bool get isConnected => _socket?.connected == true;

  Future<void> connect() async {
    if (_connecting || isConnected) return;
    _connecting = true;
    try {
      // Get auth token from SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');
      
      if (token == null) {
        Log.w('No auth token available for Socket.IO - cannot connect', 'REALTIME');
        _connecting = false;
        return;
      }
      
      final base = DatabaseConfig.physicalServerUrl;
      // Derive ws base from http(s) base
      final uri = Uri.parse(base);
      final scheme = uri.scheme == 'https' ? 'wss' : 'ws';
      final wsUrl = Uri(
        scheme: scheme,
        host: uri.host,
        port: uri.hasPort ? uri.port : (uri.scheme == 'https' ? 443 : 80),
        path: '/',
      ).toString();

      // For web, add connection timeout to avoid blocking
      if (kIsWeb) {
        // On web, use a shorter timeout and don't block
        _socket = IO.io(wsUrl, IO.OptionBuilder()
            .setTransports(['websocket'])
            .enableForceNew()
            .enableReconnection()
            .setReconnectionDelay(1000)
            .setReconnectionAttempts(5)
            .setTimeout(3000) // 3 second timeout for web
            .setAuth({'token': token})  // Add authentication token
            .build());
      } else {
        // On mobile, use longer timeout
        _socket = IO.io(wsUrl, IO.OptionBuilder()
            .setTransports(['websocket'])
            .enableForceNew()
            .enableReconnection()
            .setReconnectionDelay(1000)
            .setAuth({'token': token})  // Add authentication token
            .build());
      }

      _socket!.on('connect', (_) {
        Log.i('Realtime connected', 'REALTIME');
        _connecting = false;
      });
      _socket!.on('disconnect', (_) {
        Log.w('Realtime disconnected', 'REALTIME');
        _connecting = false;
      });
      _socket!.on('connect_error', (e) {
        Log.e('Realtime connect error', 'REALTIME', e);
        _connecting = false;
      });
      
      // For web, set a timeout to prevent indefinite blocking
      if (kIsWeb) {
        Future.delayed(const Duration(seconds: 5), () {
          if (_connecting && !isConnected) {
            Log.w('Realtime connection timeout (web)', 'REALTIME');
            _connecting = false;
          }
        });
      }
    } catch (e) {
      Log.e('Realtime connect exception', 'REALTIME', e);
      _connecting = false;
    }
  }

  void joinChat(String chatId) {
    try {
      _socket?.emit('join_chat', chatId);
    } catch (e) {
      Log.e('Join chat error', 'REALTIME', e);
    }
  }

  void leaveChat(String chatId) {
    try {
      _socket?.emit('leave_chat', chatId);
    } catch (e) {
      Log.e('Leave chat error', 'REALTIME', e);
    }
  }

  void onNewMessage(MessageCallback handler) {
    _socket?.off('new_message');
    _socket?.on('new_message', (data) {
      try {
        if (data is Map) {
          handler(Map<String, dynamic>.from(data));
        } else if (data is Map<dynamic, dynamic>) {
          handler(Map<String, dynamic>.from(data));
        }
      } catch (e) {
        Log.e('Realtime message parse error', 'REALTIME', e);
      }
    });
  }

  void onMessageReaction(MessageCallback handler) {
    _socket?.off('message_reaction');
    _socket?.on('message_reaction', (data) {
      try {
        if (data is Map) {
          handler(Map<String, dynamic>.from(data));
        } else if (data is Map<dynamic, dynamic>) {
          handler(Map<String, dynamic>.from(data));
        }
      } catch (e) {
        Log.e('Realtime reaction parse error', 'REALTIME', e);
      }
    });
  }

  void dispose() {
    try {
      _socket?.dispose();
      _socket = null;
    } catch (_) {}
  }
}


