// =============================================================================
// DEVICE TRACKING SERVICE
// =============================================================================
// Tracks device information for admin monitoring
// Collects device type, model, IP, platform, and FCM status

import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../config/database_config.dart';
import 'logger_service.dart';
import 'physical_auth_service.dart';
import 'fcm_service.dart';

class DeviceTrackingService {
  static final DeviceTrackingService instance = DeviceTrackingService._internal();
  factory DeviceTrackingService() => instance;
  DeviceTrackingService._internal();

  final PhysicalAuthService _authService = PhysicalAuthService();

  /// Register or update device information
  Future<void> registerDevice() async {
    try {
      final user = await _authService.getCurrentUser();
      if (user == null) {
        Log.w('Cannot register device: User not authenticated', 'DEVICE_TRACKING');
        return;
      }

      final token = await _authService.getAuthToken();
      if (token == null) {
        Log.w('Cannot register device: No auth token', 'DEVICE_TRACKING');
        return;
      }

      // Get device information
      final deviceInfo = await _getDeviceInfo();
      
      // Get FCM token if available
      String? fcmToken;
      try {
        final fcmService = FCMService();
        fcmToken = await fcmService.getToken();
      } catch (e) {
        Log.w('FCM token not available', 'DEVICE_TRACKING');
      }

      // Get IP address
      final ipAddress = await _getIpAddress();

      final baseUrl = DatabaseConfig.physicalServerUrl;
      final response = await http.post(
        Uri.parse('$baseUrl/api/admin/devices/register'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
          'ngrok-skip-browser-warning': 'true',
        },
        body: json.encode({
          'deviceId': deviceInfo['deviceId'],
          'deviceType': deviceInfo['deviceType'],
          'deviceModel': deviceInfo['deviceModel'],
          'platform': deviceInfo['platform'],
          'platformVersion': deviceInfo['platformVersion'],
          'appVersion': deviceInfo['appVersion'],
          'ipAddress': ipAddress,
          'fcmToken': fcmToken,
          'lastSeen': DateTime.now().toIso8601String(),
        }),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        Log.i('Device registered successfully', 'DEVICE_TRACKING');
      } else {
        Log.w('Device registration failed: ${response.statusCode}', 'DEVICE_TRACKING');
      }
    } catch (e) {
      Log.e('Error registering device', 'DEVICE_TRACKING', e);
    }
  }

  /// Update device last seen timestamp
  Future<void> updateLastSeen() async {
    try {
      final token = await _authService.getAuthToken();
      if (token == null) return;

      final deviceInfo = await _getDeviceInfo();
      final baseUrl = DatabaseConfig.physicalServerUrl;
      
      await http.patch(
        Uri.parse('$baseUrl/api/admin/devices/update-last-seen'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
          'ngrok-skip-browser-warning': 'true',
        },
        body: json.encode({
          'deviceId': deviceInfo['deviceId'],
          'lastSeen': DateTime.now().toIso8601String(),
        }),
      );
    } catch (e) {
      // Silently fail - this is a background operation
    }
  }

  /// Get device information
  Future<Map<String, dynamic>> _getDeviceInfo() async {
    final prefs = await SharedPreferences.getInstance();
    String deviceId = prefs.getString('device_id') ?? '';
    
    if (deviceId.isEmpty) {
      deviceId = _generateDeviceId();
      await prefs.setString('device_id', deviceId);
    }

    String deviceType = 'unknown';
    String deviceModel = 'unknown';
    String platform = 'unknown';
    String platformVersion = 'unknown';
    String appVersion = '1.0.0';

    if (kIsWeb) {
      platform = 'web';
      deviceType = 'web';
      deviceModel = 'Browser';
      try {
        // Try to get browser info from user agent if available
        platformVersion = 'Web Browser';
      } catch (_) {}
    } else if (Platform.isAndroid) {
      platform = 'android';
      deviceType = 'mobile';
      deviceModel = 'Android Device';
      try {
        // You can use device_info_plus package for more details
        platformVersion = Platform.version;
      } catch (_) {}
    } else if (Platform.isIOS) {
      platform = 'ios';
      deviceType = 'mobile';
      deviceModel = 'iOS Device';
      try {
        platformVersion = Platform.version;
      } catch (_) {}
    } else if (Platform.isWindows) {
      platform = 'windows';
      deviceType = 'desktop';
      deviceModel = 'Windows PC';
    } else if (Platform.isMacOS) {
      platform = 'macos';
      deviceType = 'desktop';
      deviceModel = 'Mac';
    } else if (Platform.isLinux) {
      platform = 'linux';
      deviceType = 'desktop';
      deviceModel = 'Linux';
    }

    return {
      'deviceId': deviceId,
      'deviceType': deviceType,
      'deviceModel': deviceModel,
      'platform': platform,
      'platformVersion': platformVersion,
      'appVersion': appVersion,
    };
  }

  /// Generate a unique device ID
  String _generateDeviceId() {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final random = (timestamp % 1000000).toString();
    return 'device_${timestamp}_$random';
  }

  /// Get IP address (client-side approximation)
  Future<String?> _getIpAddress() async {
    try {
      // For web, we can't get the actual client IP from the client side
      // The server should extract it from the request headers
      if (kIsWeb) {
        return 'web_client'; // Placeholder - server will get real IP
      }
      
      // For mobile, try to get local IP
      // This is a simplified version - you might want to use a package like network_info_plus
      return 'mobile_client'; // Placeholder
    } catch (e) {
      return null;
    }
  }
}

