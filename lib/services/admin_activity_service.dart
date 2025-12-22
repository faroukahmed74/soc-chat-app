// =============================================================================
// ADMIN ACTIVITY SERVICE
// =============================================================================
// This service provides real-time activity feed for admin panel
// It subscribes to Socket.IO events and provides activity filtering/search

import 'dart:async';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'package:shared_preferences/shared_preferences.dart';
import '../config/database_config.dart';
import 'logger_service.dart';
import 'mongodb_admin_service.dart';

typedef ActivityCallback = void Function(Map<String, dynamic> activity);

class AdminActivityService {
  static final AdminActivityService _instance = AdminActivityService._internal();
  factory AdminActivityService() => _instance;
  AdminActivityService._internal();

  IO.Socket? _socket;
  bool _isConnected = false;
  bool _isConnecting = false;
  final List<ActivityCallback> _activityCallbacks = [];
  final MongoDBAdminService _adminService = MongoDBAdminService();
  
  // Activity cache
  final List<Map<String, dynamic>> _activityCache = [];
  static const int maxCacheSize = 500;

  bool get isConnected => _isConnected;

  /// Initialize and connect to Socket.IO for admin activity feed
  Future<void> connect() async {
    if (_isConnecting || _isConnected) return;
    _isConnecting = true;

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');

      if (token == null) {
        Log.w('No auth token available for admin activity feed', 'ADMIN_ACTIVITY');
        _isConnecting = false;
        return;
      }

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
          .setReconnectionAttempts(5)
          .setAuth({'token': token})
          .build());

      _socket!.on('connect', (_) {
        _isConnected = true;
        _isConnecting = false;
        Log.i('Admin activity service connected', 'ADMIN_ACTIVITY');
        
        // Join admin room
        _socket!.emit('join', 'admin_room');
      });

      _socket!.on('disconnect', (_) {
        _isConnected = false;
        _isConnecting = false;
        Log.w('Admin activity service disconnected', 'ADMIN_ACTIVITY');
      });

      _socket!.on('connect_error', (error) {
        _isConnected = false;
        _isConnecting = false;
        Log.e('Admin activity service connection error', 'ADMIN_ACTIVITY', error);
      });

      // Listen for admin activity events
      _socket!.on('admin_activity', (data) {
        try {
          final activity = Map<String, dynamic>.from(data);
          _handleActivity(activity);
        } catch (e) {
          Log.e('Error handling admin activity', 'ADMIN_ACTIVITY', e);
        }
      });

    } catch (e) {
      Log.e('Failed to connect admin activity service', 'ADMIN_ACTIVITY', e);
      _isConnecting = false;
    }
  }

  /// Handle incoming activity
  void _handleActivity(Map<String, dynamic> activity) {
    // Add to cache (most recent first)
    _activityCache.insert(0, activity);
    
    // Limit cache size
    if (_activityCache.length > maxCacheSize) {
      _activityCache.removeRange(maxCacheSize, _activityCache.length);
    }

    // Notify all callbacks
    for (final callback in _activityCallbacks) {
      try {
        callback(activity);
      } catch (e) {
        Log.e('Error in activity callback', 'ADMIN_ACTIVITY', e);
      }
    }
  }

  /// Subscribe to activity updates
  void subscribe(ActivityCallback callback) {
    if (!_activityCallbacks.contains(callback)) {
      _activityCallbacks.add(callback);
    }
  }

  /// Unsubscribe from activity updates
  void unsubscribe(ActivityCallback callback) {
    _activityCallbacks.remove(callback);
  }

  /// Get cached activities
  List<Map<String, dynamic>> getCachedActivities() {
    return List.from(_activityCache);
  }

  /// Fetch recent activities from server
  Future<List<Map<String, dynamic>>> fetchRecentActivities({
    int limit = 50,
    String? type,
  }) async {
    try {
      final activities = await _adminService.getRecentActivity(
        limit: limit,
        type: type,
      );
      
      // Update cache
      _activityCache.clear();
      _activityCache.addAll(activities);
      
      return activities;
    } catch (e) {
      Log.e('Error fetching recent activities', 'ADMIN_ACTIVITY', e);
      // Return cached activities if available
      return List.from(_activityCache);
    }
  }

  /// Disconnect from Socket.IO
  void disconnect() {
    try {
      _socket?.disconnect();
      _socket?.dispose();
      _socket = null;
      _isConnected = false;
      _isConnecting = false;
      Log.i('Admin activity service disconnected', 'ADMIN_ACTIVITY');
    } catch (e) {
      Log.e('Error disconnecting admin activity service', 'ADMIN_ACTIVITY', e);
    }
  }

  /// Dispose service
  void dispose() {
    disconnect();
    _activityCallbacks.clear();
    _activityCache.clear();
  }
}

