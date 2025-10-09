// lib/config/database_config.dart
import '../services/database_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

/// Database configuration for switching between Firestore and MongoDB
class DatabaseConfig {
  // Always use physical server - no Firebase/Firestore
  static const bool usePhysicalServer = true;
  
  // Physical server configuration
  // Allow overriding via dart-define at build time
  // Mobile builds should use public tunnel URL; Web builds should use internal URL
  static const String mobileServerUrl = String.fromEnvironment(
    'API_BASE_URL_MOBILE',
    defaultValue: 'https://soc-chat-app.ngrok-free.app',
  );
  static const String webServerUrl = String.fromEnvironment(
    'API_BASE_URL_WEB',
    defaultValue: 'http://10.120.4.230:3003',
  );
  // Backwards compatibility: single define still supported
  static const String serverUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://soc-chat-app.ngrok-free.app',
  );
  static const String firestoreFallback = 'firestore';
  
  // Optional remote discovery URL for current API base
  static const String configDiscoveryUrl = String.fromEnvironment(
    'API_CONFIG_URL',
    defaultValue: '',
  );

  // Runtime override storage
  static const String _serverUrlOverrideKey = 'server_url_override';
  static String _cachedOverrideUrl = '';
  static bool _initialized = false;
  
  // JWT token storage key
  static const String _tokenKey = 'auth_token';

  /// Get the physical server database service
  static Future<DatabaseService> getDatabaseService() async {
    final token = await _getAuthToken();
    final baseUrl = _resolveServerUrl();
    return DatabaseFactory.createDatabaseService(
      usePhysicalServer: true,
      serverUrl: baseUrl,
      authToken: token,
    );
  }

  /// Get authentication token for physical server
  static Future<String> _getAuthToken() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_tokenKey) ?? '';
    } catch (e) {
      print('Error getting auth token: $e');
      return '';
    }
  }

  /// Store authentication token from server
  static Future<void> setAuthToken(String token) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_tokenKey, token);
    } catch (e) {
      print('Error setting auth token: $e');
    }
  }
  
  /// Get stored authentication token
  static Future<String> getStoredAuthToken() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_tokenKey) ?? '';
    } catch (e) {
      print('Error getting stored auth token: $e');
      return '';
    }
  }
  
  /// Clear authentication token (for logout)
  static Future<void> clearAuthToken() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
  }
  
  /// Check if physical server is enabled
  static bool get isPhysicalServerEnabled => usePhysicalServer;
  
  /// Get server URL for physical server
  static String get physicalServerUrl => _resolveServerUrl();
  
  /// Get fallback database type
  static String get fallbackDatabase => firestoreFallback;

  /// Initialize runtime override and optionally fetch remote config.
  static Future<void> initialize() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _cachedOverrideUrl = prefs.getString(_serverUrlOverrideKey) ?? '';
      if (_cachedOverrideUrl.isEmpty && configDiscoveryUrl.isNotEmpty) {
        try {
          final resp = await http
              .get(Uri.parse(configDiscoveryUrl))
              .timeout(const Duration(seconds: 5));
          if (resp.statusCode == 200) {
            final data = json.decode(resp.body);
            final discovered = (data is Map && data['api_base_url'] is String)
                ? (data['api_base_url'] as String).trim()
                : '';
            if (_isValidUrl(discovered)) {
              await prefs.setString(_serverUrlOverrideKey, discovered);
              _cachedOverrideUrl = discovered;
            }
          }
        } catch (e) {
          print('DatabaseConfig discovery failed: $e');
        }
      }
    } catch (e) {
      print('DatabaseConfig init error: $e');
    } finally {
      _initialized = true;
    }
  }

  /// Set server URL override at runtime and persist it.
  static Future<void> setServerUrlOverride(String url) async {
    try {
      if (_isValidUrl(url)) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_serverUrlOverrideKey, url);
        _cachedOverrideUrl = url;
      }
    } catch (e) {
      print('DatabaseConfig set override error: $e');
    }
  }

  /// Get current server URL override (cached).
  static Future<String> getServerUrlOverride() async {
    if (_cachedOverrideUrl.isNotEmpty) return _cachedOverrideUrl;
    try {
      final prefs = await SharedPreferences.getInstance();
      _cachedOverrideUrl = prefs.getString(_serverUrlOverrideKey) ?? '';
    } catch (_) {}
    return _cachedOverrideUrl;
  }
}

/// Internal helper to resolve correct server URL based on platform and defines
String _resolveServerUrl() {
  // Prefer runtime override if present
  if (DatabaseConfig._cachedOverrideUrl.isNotEmpty) {
    return DatabaseConfig._cachedOverrideUrl;
  }
  // Prefer platform-specific URL (mobile/web)
  final platformUrl = kIsWeb ? DatabaseConfig.webServerUrl : DatabaseConfig.mobileServerUrl;
  if (platformUrl.isNotEmpty) {
    return platformUrl;
  }
  // Fallback to unified API_BASE_URL only if platform-specific is empty
  if (DatabaseConfig.serverUrl.isNotEmpty) {
    return DatabaseConfig.serverUrl;
  }
  // Final fallback to local IP (should not happen due to defaults)
  return 'http://192.168.0.117:3003';
}

bool _isValidUrl(String url) {
  if (url.isEmpty) return false;
  try {
    final uri = Uri.parse(url);
    return (uri.isScheme('http') || uri.isScheme('https')) && uri.host.isNotEmpty;
  } catch (_) {
    return false;
  }
}

