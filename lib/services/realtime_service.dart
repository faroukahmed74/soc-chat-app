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
  bool _authFailed = false; // Track if authentication failed to prevent reconnection loops

  bool get isConnected => _socket?.connected == true;

  Future<void> connect() async {
    if (_connecting || isConnected || _authFailed) {
      if (_authFailed) {
        Log.w('Socket connection blocked - authentication previously failed. Please refresh token.', 'REALTIME');
      }
      return;
    }
    _connecting = true;
    _authFailed = false; // Reset auth failure flag on new connection attempt
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

      // Build socket options - conditionally enable reconnection
      final optionBuilder = IO.OptionBuilder()
          .setTransports(['websocket'])
          .enableForceNew();
      
      // Only enable reconnection if auth hasn't failed
      if (!_authFailed) {
        optionBuilder.enableReconnection().setReconnectionDelay(1000);
      }
      
      _socket = IO.io(wsUrl, optionBuilder
          .setAuth({'token': token})  // Add authentication token
          .build());

      _socket!.on('connect', (_) {
        Log.i('Realtime connected', 'REALTIME');
        _authFailed = false; // Reset on successful connection
      });
      _socket!.on('disconnect', (reason) {
        Log.w('Realtime disconnected: $reason', 'REALTIME');
        // If disconnected due to auth error, don't reconnect
        if (reason.toString().contains('Authentication error') || 
            reason.toString().contains('Token expired')) {
          _authFailed = true;
          Log.w('Authentication failed - reconnection disabled. Please refresh token.', 'REALTIME');
        }
      });
      _socket!.on('connect_error', (e) {
        // Handle different error formats (Error object, Map, or String)
        String errorStr = '';
        if (e is Map) {
          errorStr = e.toString().toLowerCase();
        } else if (e is String) {
          errorStr = e.toLowerCase();
        } else {
          errorStr = e.toString().toLowerCase();
        }
        
        if (errorStr.contains('authentication') || 
            errorStr.contains('token expired') ||
            errorStr.contains('invalid token') ||
            errorStr.contains('refresh your session')) {
          _authFailed = true;
          Log.w('Socket authentication failed - token may be expired. Please refresh token.', 'REALTIME');
          // Disable reconnection to prevent spam
          _socket?.disconnect();
          _socket = null;
        } else {
          Log.e('Realtime connect error', 'REALTIME', e);
        }
      });
      
      // Handle authentication errors from Socket.IO middleware (if emitted as 'error' event)
      _socket!.on('error', (error) {
        String errorStr = '';
        if (error is Map) {
          errorStr = error.toString().toLowerCase();
        } else if (error is String) {
          errorStr = error.toLowerCase();
        } else {
          errorStr = error.toString().toLowerCase();
        }
        
        if (errorStr.contains('authentication') || 
            errorStr.contains('token expired') ||
            errorStr.contains('invalid token') ||
            errorStr.contains('refresh your session')) {
          _authFailed = true;
          Log.w('Socket authentication error received - token may be expired. Please refresh token.', 'REALTIME');
          _socket?.disconnect();
          _socket = null;
        }
      });
    } catch (e) {
      Log.e('Realtime connect exception', 'REALTIME', e);
    } finally {
      _connecting = false;
    }
  }
  
  /// Reset authentication failure flag and attempt to reconnect
  /// Call this after refreshing the token
  Future<void> reconnectAfterTokenRefresh() async {
    _authFailed = false;
    dispose();
    await connect();
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


