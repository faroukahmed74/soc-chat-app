// =============================================================================
// DEVICE TRACKING SERVICE
// =============================================================================
// This service tracks device information for mobile platforms (Android & iOS)
// It collects device details and sends them to the server for admin analytics

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'dart:io' if (dart.library.html) 'dart:html';
import 'dart:html' if (dart.library.io) '../widgets/html_stub.dart' as html;
import '../config/database_config.dart';
import 'logger_service.dart';
import 'physical_auth_service.dart';

class DeviceTrackingService {
  static final DeviceTrackingService _instance = DeviceTrackingService._internal();
  factory DeviceTrackingService() => _instance;
  DeviceTrackingService._internal();

  DeviceInfoPlugin _deviceInfo = DeviceInfoPlugin();
  String? _cachedDeviceId;
  static const String _webDeviceIdKey = 'web_device_id';

  /// Get unique device identifier
  Future<String> getDeviceId() async {
    if (_cachedDeviceId != null) return _cachedDeviceId!;
    
    try {
      if (kIsWeb) {
        // Use SharedPreferences to store a persistent device ID for web
        final prefs = await SharedPreferences.getInstance();
        String? storedDeviceId = prefs.getString(_webDeviceIdKey);
        
        if (storedDeviceId == null || storedDeviceId.isEmpty) {
          // Generate a new device ID and store it
          storedDeviceId = 'web_${DateTime.now().millisecondsSinceEpoch}_${_generateRandomString(8)}';
          await prefs.setString(_webDeviceIdKey, storedDeviceId);
        }
        
        _cachedDeviceId = storedDeviceId;
        return _cachedDeviceId!;
      } else if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
        final androidInfo = await _deviceInfo.androidInfo;
        // Use Android ID as device identifier
        _cachedDeviceId = androidInfo.id;
        return _cachedDeviceId!;
      } else if (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS) {
        final iosInfo = await _deviceInfo.iosInfo;
        // Use identifierForVendor as device identifier
        _cachedDeviceId = iosInfo.identifierForVendor ?? 'ios_unknown';
        return _cachedDeviceId!;
      }
    } catch (e) {
      Log.e('Error getting device ID', 'DEVICE_TRACKING', e);
    }
    
    // Fallback
    _cachedDeviceId = 'unknown_${DateTime.now().millisecondsSinceEpoch}';
    return _cachedDeviceId!;
  }

  /// Generate a random string for device ID
  String _generateRandomString(int length) {
    const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
    final random = DateTime.now().millisecondsSinceEpoch;
    final buffer = StringBuffer();
    for (int i = 0; i < length; i++) {
      buffer.write(chars[(random + i) % chars.length]);
    }
    return buffer.toString();
  }

  /// Get comprehensive device information
  Future<Map<String, dynamic>> getDeviceInfo() async {
    try {
      if (kIsWeb) {
        // Get browser information from window.navigator
        String userAgent = 'Unknown';
        String browserName = 'Unknown';
        String browserVersion = 'Unknown';
        String platform = 'Unknown';
        String language = 'Unknown';
        
        try {
          if (html.window.navigator != null) {
            userAgent = html.window.navigator?.userAgent ?? 'Unknown';
            platform = html.window.navigator?.platform ?? 'Unknown';
            language = html.window.navigator?.language ?? 'Unknown';
            
            // Parse browser name and version from user agent
            if (userAgent.contains('Chrome') && !userAgent.contains('Edg')) {
              browserName = 'Chrome';
              final match = RegExp(r'Chrome/(\d+\.\d+)').firstMatch(userAgent);
              browserVersion = match?.group(1) ?? 'Unknown';
            } else if (userAgent.contains('Firefox')) {
              browserName = 'Firefox';
              final match = RegExp(r'Firefox/(\d+\.\d+)').firstMatch(userAgent);
              browserVersion = match?.group(1) ?? 'Unknown';
            } else if (userAgent.contains('Safari') && !userAgent.contains('Chrome')) {
              browserName = 'Safari';
              final match = RegExp(r'Version/(\d+\.\d+)').firstMatch(userAgent);
              browserVersion = match?.group(1) ?? 'Unknown';
            } else if (userAgent.contains('Edg')) {
              browserName = 'Edge';
              final match = RegExp(r'Edg/(\d+\.\d+)').firstMatch(userAgent);
              browserVersion = match?.group(1) ?? 'Unknown';
            } else if (userAgent.contains('Opera') || userAgent.contains('OPR')) {
              browserName = 'Opera';
              final match = RegExp(r'(?:Opera|OPR)/(\d+\.\d+)').firstMatch(userAgent);
              browserVersion = match?.group(1) ?? 'Unknown';
            }
          }
        } catch (e) {
          Log.w('Error getting web browser info: $e', 'DEVICE_TRACKING');
        }
        
        return {
          'platform': 'web',
          'deviceId': await getDeviceId(),
          'deviceModel': '$browserName $browserVersion',
          'deviceName': 'Web Browser',
          'browserName': browserName,
          'browserVersion': browserVersion,
          'userAgent': userAgent,
          'osVersion': platform,
          'language': language,
          'appVersion': '1.0.16',
          'timestamp': DateTime.now().toIso8601String(),
        };
      } else if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
        final androidInfo = await _deviceInfo.androidInfo;
        return {
          'platform': 'android',
          'deviceId': await getDeviceId(),
          'deviceModel': androidInfo.model,
          'deviceName': androidInfo.device,
          'manufacturer': androidInfo.manufacturer,
          'brand': androidInfo.brand,
          'osVersion': 'Android ${androidInfo.version.release} (SDK ${androidInfo.version.sdkInt})',
          'androidVersion': androidInfo.version.release,
          'sdkInt': androidInfo.version.sdkInt,
          'appVersion': '1.0.16',
          'timestamp': DateTime.now().toIso8601String(),
        };
      } else if (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS) {
        final iosInfo = await _deviceInfo.iosInfo;
        return {
          'platform': 'ios',
          'deviceId': await getDeviceId(),
          'deviceModel': iosInfo.model,
          'deviceName': iosInfo.name,
          'systemName': iosInfo.systemName,
          'osVersion': '${iosInfo.systemName} ${iosInfo.systemVersion}',
          'iosVersion': iosInfo.systemVersion,
          'appVersion': '1.0.16',
          'timestamp': DateTime.now().toIso8601String(),
        };
      }
    } catch (e) {
      Log.e('Error getting device info', 'DEVICE_TRACKING', e);
    }
    
    return {
      'platform': 'unknown',
      'deviceId': await getDeviceId(),
      'deviceModel': 'Unknown',
      'deviceName': 'Unknown',
      'osVersion': 'Unknown',
      'appVersion': '1.0.16',
      'timestamp': DateTime.now().toIso8601String(),
    };
  }

  /// Track device login/usage
  Future<bool> trackDeviceLogin(String userId) async {
    try {
      // Track devices for all platforms including web
      final deviceInfo = await getDeviceInfo();
      final authService = PhysicalAuthService();
      final token = await authService.getAuthToken();
      
      if (token == null || token.isEmpty) {
        Log.w('Cannot track device: no auth token', 'DEVICE_TRACKING');
        return false;
      }

      final baseUrl = DatabaseConfig.physicalServerUrl;
      final response = await http.post(
        Uri.parse('$baseUrl/api/devices/track'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
          'ngrok-skip-browser-warning': 'true',
        },
        body: json.encode({
          'userId': userId,
          'deviceInfo': deviceInfo,
        }),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        Log.i('Device tracked successfully', 'DEVICE_TRACKING');
        return true;
      } else {
        Log.w('Failed to track device: ${response.statusCode}', 'DEVICE_TRACKING');
        return false;
      }
    } catch (e) {
      Log.e('Error tracking device', 'DEVICE_TRACKING', e);
      return false;
    }
  }

  /// Get device display name for UI
  String getDeviceDisplayName(Map<String, dynamic> deviceInfo) {
    final platform = deviceInfo['platform'] ?? 'unknown';
    final model = deviceInfo['deviceModel'] ?? 'Unknown Device';
    final osVersion = deviceInfo['osVersion'] ?? '';
    
    if (platform == 'android') {
      final manufacturer = deviceInfo['manufacturer'] ?? '';
      final brand = deviceInfo['brand'] ?? '';
      final deviceName = deviceInfo['deviceName'] ?? '';
      return '${manufacturer.isNotEmpty ? "$manufacturer " : ""}${brand.isNotEmpty ? "$brand " : ""}$model${osVersion.isNotEmpty ? " ($osVersion)" : ""}';
    } else if (platform == 'ios') {
      return '$model${osVersion.isNotEmpty ? " ($osVersion)" : ""}';
    } else if (platform == 'web') {
      final browserName = deviceInfo['browserName'] ?? 'Unknown';
      final browserVersion = deviceInfo['browserVersion'] ?? '';
      if (browserVersion != 'Unknown' && browserVersion.isNotEmpty) {
        return '$browserName $browserVersion';
      }
      return browserName != 'Unknown' ? browserName : 'Web Browser';
    }
    
    return model;
  }
}

