import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:io';
import 'logger_service.dart';

/// Simple, reliable permission service for Android and iOS
/// Handles permissions without complex fallback logic
class SimplePermissionService {
  static final SimplePermissionService _instance = SimplePermissionService._internal();
  factory SimplePermissionService() => _instance;
  SimplePermissionService._internal();

  /// Request camera permission
  static Future<bool> requestCameraPermission(BuildContext context) async {
    if (kIsWeb) return true;
    
    try {
      Log.i('Requesting camera permission', 'SIMPLE_PERMISSION');
      
      // Check current status
      final status = await Permission.camera.status;
      Log.i('Camera permission status: $status', 'SIMPLE_PERMISSION');
      
      if (status.isGranted) {
        Log.i('Camera permission already granted', 'SIMPLE_PERMISSION');
        return true;
      }
      
      if (status.isPermanentlyDenied) {
        Log.w('Camera permission permanently denied', 'SIMPLE_PERMISSION');
        _showSettingsDialog(context, 'Camera Permission', 
          'Camera access is needed to take photos and videos. Please enable it in device settings.');
        return false;
      }
      
      // Request permission
      Log.i('Requesting camera permission...', 'SIMPLE_PERMISSION');
      final result = await Permission.camera.request();
      Log.i('Camera permission result: $result', 'SIMPLE_PERMISSION');
      
      return result.isGranted;
      
    } catch (e) {
      Log.e('Error requesting camera permission', 'SIMPLE_PERMISSION', e);
      return false;
    }
  }
  
  /// Request photos permission (handles both Android and iOS)
  static Future<bool> requestPhotosPermission(BuildContext context) async {
    if (kIsWeb) return true;
    
    try {
      Log.i('Requesting photos permission', 'SIMPLE_PERMISSION');
      
      if (Platform.isAndroid) {
        return await _requestAndroidPhotosPermission(context);
      } else if (Platform.isIOS) {
        return await _requestIOSPhotosPermission(context);
      }
      return false;
    } catch (e) {
      Log.e('Error requesting photos permission', 'SIMPLE_PERMISSION', e);
      return false;
    }
  }
  
  /// Request Android photos permission
  static Future<bool> _requestAndroidPhotosPermission(BuildContext context) async {
    try {
      // For Android 13+ (API 33+), use READ_MEDIA_IMAGES
      // For older versions, use READ_EXTERNAL_STORAGE
      if (await _isAndroid13OrHigher()) {
        Log.i('Android 13+ detected, using READ_MEDIA_IMAGES', 'SIMPLE_PERMISSION');
        return await _requestModernMediaPermission(context);
      } else {
        Log.i('Android <13 detected, using READ_EXTERNAL_STORAGE', 'SIMPLE_PERMISSION');
        return await _requestLegacyStoragePermission(context);
      }
    } catch (e) {
      Log.e('Error in Android photos permission', 'SIMPLE_PERMISSION', e);
      return false;
    }
  }
  
  /// Request modern media permission (Android 13+)
  static Future<bool> _requestModernMediaPermission(BuildContext context) async {
    try {
      final status = await Permission.photos.status;
      Log.i('Modern media permission status: $status', 'SIMPLE_PERMISSION');
      
      if (status.isGranted || status.isLimited) {
        Log.i('Modern media permission already granted/limited', 'SIMPLE_PERMISSION');
        return true;
      }
      
      if (status.isPermanentlyDenied) {
        Log.w('Modern media permission permanently denied', 'SIMPLE_PERMISSION');
        _showSettingsDialog(context, 'Photos Permission', 
          'Photo library access is needed to select and share images. Please enable it in device settings.');
        return false;
      }
      
      // Request permission
      Log.i('Requesting modern media permission...', 'SIMPLE_PERMISSION');
      final result = await Permission.photos.request();
      Log.i('Modern media permission result: $result', 'SIMPLE_PERMISSION');
      
      return result.isGranted || result.isLimited;
      
    } catch (e) {
      Log.e('Error requesting modern media permission', 'SIMPLE_PERMISSION', e);
      return false;
    }
  }
  
  /// Request legacy storage permission (Android <13)
  static Future<bool> _requestLegacyStoragePermission(BuildContext context) async {
    try {
      final status = await Permission.storage.status;
      Log.i('Legacy storage permission status: $status', 'SIMPLE_PERMISSION');
      
      if (status.isGranted) {
        Log.i('Legacy storage permission already granted', 'SIMPLE_PERMISSION');
        return true;
      }
      
      if (status.isPermanentlyDenied) {
        Log.w('Legacy storage permission permanently denied', 'SIMPLE_PERMISSION');
        _showSettingsDialog(context, 'Storage Permission', 
          'Storage access is needed to select and share images. Please enable it in device settings.');
        return false;
      }
      
      // Request permission
      Log.i('Requesting legacy storage permission...', 'SIMPLE_PERMISSION');
      final result = await Permission.storage.request();
      Log.i('Legacy storage permission result: $result', 'SIMPLE_PERMISSION');
      
      return result.isGranted;
      
    } catch (e) {
      Log.e('Error requesting legacy storage permission', 'SIMPLE_PERMISSION', e);
      return false;
    }
  }
  
  /// Request iOS photos permission
  static Future<bool> _requestIOSPhotosPermission(BuildContext context) async {
    try {
      Log.i('Requesting iOS photos permission', 'SIMPLE_PERMISSION');
      
      final status = await Permission.photos.status;
      Log.i('iOS photos permission status: $status', 'SIMPLE_PERMISSION');
      
      if (status.isGranted || status.isLimited) {
        Log.i('iOS photos permission already granted/limited', 'SIMPLE_PERMISSION');
        return true;
      }
      
      if (status.isPermanentlyDenied) {
        Log.w('iOS photos permission permanently denied', 'SIMPLE_PERMISSION');
        _showSettingsDialog(context, 'Photos Permission', 
          'Photo library access is needed to select and share images. Please enable it in iOS Settings > Privacy & Security > Photos.');
        return false;
      }
      
      // Request permission
      Log.i('Requesting iOS photos permission...', 'SIMPLE_PERMISSION');
      final result = await Permission.photos.request();
      Log.i('iOS photos permission result: $result', 'SIMPLE_PERMISSION');
      
      return result.isGranted || result.isLimited;
      
    } catch (e) {
      Log.e('Error requesting iOS photos permission', 'SIMPLE_PERMISSION', e);
      return false;
    }
  }
  
  /// Request microphone permission
  static Future<bool> requestMicrophonePermission(BuildContext context) async {
    if (kIsWeb) return true;
    
    try {
      Log.i('Requesting microphone permission', 'SIMPLE_PERMISSION');
      
      final status = await Permission.microphone.status;
      Log.i('Microphone permission status: $status', 'SIMPLE_PERMISSION');
      
      if (status.isGranted) {
        Log.i('Microphone permission already granted', 'SIMPLE_PERMISSION');
        return true;
      }
      
      if (status.isPermanentlyDenied) {
        Log.w('Microphone permission permanently denied', 'SIMPLE_PERMISSION');
        _showSettingsDialog(context, 'Microphone Permission', 
          'Microphone access is needed to record voice messages. Please enable it in device settings.');
        return false;
      }
      
      // Request permission
      Log.i('Requesting microphone permission...', 'SIMPLE_PERMISSION');
      final result = await Permission.microphone.request();
      Log.i('Microphone permission result: $result', 'SIMPLE_PERMISSION');
      
      return result.isGranted;
      
    } catch (e) {
      Log.e('Error requesting microphone permission', 'SIMPLE_PERMISSION', e);
      return false;
    }
  }
  
  /// Request notification permission
  static Future<bool> requestNotificationPermission(BuildContext context) async {
    if (kIsWeb) return true;
    
    try {
      Log.i('Requesting notification permission', 'SIMPLE_PERMISSION');
      
      final status = await Permission.notification.status;
      Log.i('Notification permission status: $status', 'SIMPLE_PERMISSION');
      
      if (status.isGranted) {
        Log.i('Notification permission already granted', 'SIMPLE_PERMISSION');
        return true;
      }
      
      if (status.isPermanentlyDenied) {
        Log.w('Notification permission permanently denied', 'SIMPLE_PERMISSION');
        _showSettingsDialog(context, 'Notification Permission', 
          'Notification access is needed to receive alerts about new messages. Please enable it in device settings.');
        return false;
      }
      
      // Request permission
      Log.i('Requesting notification permission...', 'SIMPLE_PERMISSION');
      final result = await Permission.notification.request();
      Log.i('Notification permission result: $result', 'SIMPLE_PERMISSION');
      
      return result.isGranted;
      
    } catch (e) {
      Log.e('Error requesting notification permission', 'SIMPLE_PERMISSION', e);
      return false;
    }
  }
  
  /// Request location permission
  static Future<bool> requestLocationPermission(BuildContext context) async {
    if (kIsWeb) return true;
    
    try {
      Log.i('Requesting location permission', 'SIMPLE_PERMISSION');
      
      final status = await Permission.location.status;
      Log.i('Location permission status: $status', 'SIMPLE_PERMISSION');
      
      if (status.isGranted) {
        Log.i('Location permission already granted', 'SIMPLE_PERMISSION');
        return true;
      }
      
      if (status.isPermanentlyDenied) {
        Log.w('Location permission permanently denied', 'SIMPLE_PERMISSION');
        _showSettingsDialog(context, 'Location Permission', 
          'Location access is needed to share your location in chat conversations. Please enable it in device settings.');
        return false;
      }
      
      // Request permission
      Log.i('Requesting location permission...', 'SIMPLE_PERMISSION');
      final result = await Permission.location.request();
      Log.i('Location permission result: $result', 'SIMPLE_PERMISSION');
      
      return result.isGranted;
      
    } catch (e) {
      Log.e('Error requesting location permission', 'SIMPLE_PERMISSION', e);
      return false;
    }
  }
  
  /// Check if device is Android 13 or higher
  static Future<bool> _isAndroid13OrHigher() async {
    try {
      if (!Platform.isAndroid) return false;
      
      // Simple check: try to access photos permission
      // If it works, we're on Android 13+
      try {
        await Permission.photos.status;
        Log.i('Photos permission available - Android 13+ detected', 'SIMPLE_PERMISSION');
        return true;
      } catch (e) {
        Log.i('Photos permission not available - Android <13 detected', 'SIMPLE_PERMISSION');
        return false;
      }
    } catch (e) {
      Log.w('Could not determine Android version, defaulting to legacy permissions', 'SIMPLE_PERMISSION');
      return false; // Default to legacy permissions if we can't determine version
    }
  }
  
  /// Get comprehensive permission status
  static Future<Map<String, dynamic>> getPermissionStatus() async {
    if (kIsWeb) {
      return {
        'camera': 'granted',
        'photos': 'granted',
        'microphone': 'granted',
        'storage': 'granted',
        'notification': 'granted',
        'location': 'granted',
      };
    }
    
    try {
      final cameraStatus = await Permission.camera.status;
      final photosStatus = await Permission.photos.status;
      final microphoneStatus = await Permission.microphone.status;
      final storageStatus = await Permission.storage.status;
      final notificationStatus = await Permission.notification.status;
      final locationStatus = await Permission.location.status;
      
      return {
        'camera': _getStatusString(cameraStatus),
        'photos': _getStatusString(photosStatus),
        'microphone': _getStatusString(microphoneStatus),
        'storage': _getStatusString(storageStatus),
        'notification': _getStatusString(notificationStatus),
        'location': _getStatusString(locationStatus),
        'platform': Platform.operatingSystem,
        'androidVersion': Platform.isAndroid ? (await _isAndroid13OrHigher() ? '13+' : '<13') : 'N/A',
        'timestamp': DateTime.now().toIso8601String(),
      };
    } catch (e) {
      Log.e('Error getting permission status', 'SIMPLE_PERMISSION', e);
      return {
        'camera': 'error',
        'photos': 'error',
        'microphone': 'error',
        'storage': 'error',
        'notification': 'error',
        'location': 'error',
        'platform': Platform.operatingSystem,
        'error': e.toString(),
      };
    }
  }
  
  /// Convert PermissionStatus to string
  static String _getStatusString(PermissionStatus status) {
    if (status.isGranted) return 'granted';
    if (status.isLimited) return 'limited';
    if (status.isDenied) return 'denied';
    if (status.isPermanentlyDenied) return 'permanently_denied';
    if (status.isRestricted) return 'restricted';
    return 'unknown';
  }
  
  /// Show settings dialog
  static void _showSettingsDialog(BuildContext context, String title, String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              openAppSettings();
            },
            child: const Text('Open Settings'),
          ),
        ],
      ),
    );
  }
  
  /// Request all permissions at once (for testing)
  static Future<Map<String, bool>> requestAllPermissions(BuildContext context) async {
    if (kIsWeb) {
      return {
        'camera': true,
        'photos': true,
        'microphone': true,
        'notification': true,
        'location': true,
      };
    }
    
    final results = <String, bool>{};
    
    try {
      results['camera'] = await requestCameraPermission(context);
      results['photos'] = await requestPhotosPermission(context);
      results['microphone'] = await requestMicrophonePermission(context);
      results['notification'] = await requestNotificationPermission(context);
      results['location'] = await requestLocationPermission(context);
    } catch (e) {
      Log.e('Error requesting all permissions', 'SIMPLE_PERMISSION', e);
    }
    
    return results;
  }
}
