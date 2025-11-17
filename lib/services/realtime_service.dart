import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../config/database_config.dart';
import 'local_auth_service.dart';
import 'logger_service.dart';

typedef MessageCallback = void Function(Map<String, dynamic> message);

class RealtimeService {
  static final RealtimeService instance = RealtimeService._internal();
  RealtimeService._internal();

  IO.Socket? _socket;
  bool _connecting = false;
  bool _handlingTokenExpiry = false;

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

      _registerTokenRefreshHandler();

      _socket!.on('connect', (_) {
        Log.i('Realtime connected', 'REALTIME');
        _connecting = false;
      });
      _socket!.on('disconnect', (_) {
        Log.w('Realtime disconnected', 'REALTIME');
        _connecting = false;
      });
      _socket!.on('connect_error', (e) async {
        Log.e('Realtime connect error', 'REALTIME', e);
        if (_isTokenExpiredError(e)) {
          await _handleTokenExpired();
        }
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

  void onMessageUpdated(MessageCallback handler) {
    _socket?.off('message_updated');
    _socket?.on('message_updated', (data) {
      try {
        if (data is Map) {
          handler(Map<String, dynamic>.from(data));
        } else if (data is Map<dynamic, dynamic>) {
          handler(Map<String, dynamic>.from(data));
        }
      } catch (e) {
        Log.e('Realtime message update parse error', 'REALTIME', e);
      }
    });
  }

  void onMessageDeleted(MessageCallback handler) {
    _socket?.off('message_deleted');
    _socket?.on('message_deleted', (data) {
      try {
        if (data is Map) {
          handler(Map<String, dynamic>.from(data));
        } else if (data is Map<dynamic, dynamic>) {
          handler(Map<String, dynamic>.from(data));
        }
      } catch (e) {
        Log.e('Realtime message delete parse error', 'REALTIME', e);
      }
    });
  }

  void dispose() {
    try {
      _socket?.dispose();
      _socket = null;
    } catch (_) {}
  }

  bool _isTokenExpiredError(dynamic error) {
    try {
      final message = error?.toString().toLowerCase();
      if (message == null || message.isEmpty) return false;
      return message.contains('token expired') || message.contains('jwt expired');
    } catch (_) {
      return false;
    }
  }

  Future<void> _handleTokenExpired() async {
    if (_handlingTokenExpiry) return;
    _handlingTokenExpiry = true;
    try {
      Log.w('Auth token expired - clearing stored credentials to force re-login', 'REALTIME');
      await LocalAuthService.logout();
    } catch (e) {
      Log.e('Failed to clear credentials after token expiry', 'REALTIME', e);
    } finally {
      _handlingTokenExpiry = false;
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
        Log.i('Realtime received refreshed auth token from server', 'REALTIME');
      } catch (e) {
        Log.e('Failed to persist refreshed auth token', 'REALTIME', e);
      }
    });
  }

  String? _extractToken(dynamic payload) {
    if (payload is String) {
      return payload;
    }
    if (payload is Map) {
      final token = payload['token'];
      if (token is String) {
        return token;
      }
    }
    return null;
  }
}


