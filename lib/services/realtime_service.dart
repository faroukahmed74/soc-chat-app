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
  List<MessageCallback> _callInvitationHandlers = [];

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
        Log.i('Realtime connected (Socket ID: ${_socket!.id})', 'REALTIME');
        _connecting = false;
        // Re-register call invitation listener after connection
        // This ensures the listener is active when the socket is connected
        if (_callInvitationHandlers.isNotEmpty) {
          _registerCallInvitationListener();
        }
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

  void onCallInvitation(MessageCallback handler) {
    // Add handler to list so multiple listeners can coexist
    if (!_callInvitationHandlers.contains(handler)) {
      _callInvitationHandlers.add(handler);
      Log.i('📞 Added call invitation handler (total: ${_callInvitationHandlers.length})', 'REALTIME');
    }
    
    // Register the listener if socket is already connected
    if (_socket != null && isConnected) {
      _registerCallInvitationListener();
    } else if (_socket != null) {
      Log.i('📞 Socket exists but not connected yet - listener will be registered on connect', 'REALTIME');
    } else {
      Log.w('Cannot register call invitation listener: Socket is null', 'REALTIME');
    }
  }

  void _registerCallInvitationListener() {
    if (_socket == null || _callInvitationHandlers.isEmpty) return;
    
    Log.i('📞 Registering call invitation listener on Socket.IO (socket ID: ${_socket!.id}, connected: ${isConnected}, handlers: ${_callInvitationHandlers.length})', 'REALTIME');
    // Remove old listener and add new one that calls all handlers
    _socket!.off('call_invitation');
    _socket!.on('call_invitation', (data) {
      try {
        Log.i('📞 Socket.IO received call_invitation event: $data', 'REALTIME');
        Log.i('📞 Event data type: ${data.runtimeType}', 'REALTIME');
        
        Map<String, dynamic>? callData;
        if (data is Map) {
          callData = Map<String, dynamic>.from(data);
        } else if (data is Map<dynamic, dynamic>) {
          callData = Map<String, dynamic>.from(data);
        } else {
          Log.w('Call invitation data is not a Map: ${data.runtimeType}', 'REALTIME');
          return;
        }
        
        Log.i('📞 Parsed call data: callId=${callData['callId']}, chatId=${callData['chatId']}, callerId=${callData['callerId']}', 'REALTIME');
        
        // Call all registered handlers
        for (final handler in _callInvitationHandlers) {
          try {
            handler(callData);
          } catch (e, stackTrace) {
            Log.e('Error in call invitation handler', 'REALTIME', e);
            Log.e('Stack trace', 'REALTIME', stackTrace);
          }
        }
      } catch (e, stackTrace) {
        Log.e('Realtime call invitation parse error', 'REALTIME', e);
        Log.e('Stack trace', 'REALTIME', stackTrace);
      }
    });
    Log.i('✅ Call invitation listener registered on Socket.IO', 'REALTIME');
  }

  /// Generic method to listen to any Socket.IO event
  void on(String event, void Function(dynamic) handler) {
    _socket?.off(event);
    _socket?.on(event, handler);
  }

  /// Generic method to emit Socket.IO events
  void emit(String event, dynamic data) {
    _socket?.emit(event, data);
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


