import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'package:flutter/foundation.dart';
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

      _socket = IO.io(wsUrl, IO.OptionBuilder()
          .setTransports(['websocket'])
          .enableForceNew()
          .enableReconnection()
          .setReconnectionDelay(1000)
          .build());

      _socket!.on('connect', (_) {
        Log.i('Realtime connected', 'REALTIME');
      });
      _socket!.on('disconnect', (_) {
        Log.w('Realtime disconnected', 'REALTIME');
      });
      _socket!.on('connect_error', (e) {
        Log.e('Realtime connect error', 'REALTIME', e);
      });
    } catch (e) {
      Log.e('Realtime connect exception', 'REALTIME', e);
    } finally {
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

  void dispose() {
    try {
      _socket?.dispose();
      _socket = null;
    } catch (_) {}
  }
}


