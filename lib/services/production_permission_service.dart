import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:io';
import 'logger_service.dart';

/// Production-ready permission service for final release
/// Handles all permissions consistently across Android and iOS versions
class ProductionPermissionService {
  static final ProductionPermissionService _instance = ProductionPermissionService._internal();
  factory ProductionPermissionService() => _instance;
  ProductionPermissionService._internal();

  /// Request camera permission with proper handling
  static Future<bool> requestCameraPermission(BuildContext context) async {
    if (kIsWeb) return true;
    
    try {
      Log.i('Requesting camera permission', 'PRODUCTION_PERMISSION');
      
      // Check current status
      final status = await Permission.camera.status;
      Log.i('Camera permission status: $status', 'PRODUCTION_PERMISSION');
      
      if (status.isGranted) {
        Log.i('Camera permission already granted', 'PRODUCTION_PERMISSION');
        return true;
      }
      
      if (status.isPermanentlyDenied) {
        Log.w('Camera permission permanently denied', 'PRODUCTION_PERMISSION');
        _showSettingsDialog(context, 'Camera Permission', 
          'Camera access is needed to take photos and videos. Please enable it in device settings.');
        return false;
      }
      
      // Request permission directly without custom dialog
      Log.i('Requesting camera permission...', 'PRODUCTION_PERMISSION');
      final result = await Permission.camera.request();
      Log.i('Camera permission result: $result', 'PRODUCTION_PERMISSION');
      
      return result.isGranted;
      
    } catch (e) {
      Log.e('Error requesting camera permission', 'PRODUCTION_PERMISSION', e);
      return false;
    }
  }
  
  /// Request photos permission with proper Android version handling
  static Future<bool> requestPhotosPermission(BuildContext context) async {
    if (kIsWeb) return true;
    
    try {
      Log.i('Requesting photos permission', 'PRODUCTION_PERMISSION');
      
      if (Platform.isAndroid) {
        final result = await _requestAndroidPhotosPermission(context);
        if (!result) {
          Log.w('Android photos permission failed, trying fallback...', 'PRODUCTION_PERMISSION');
          // Try fallback to storage permission for older Android versions
          return await _requestLegacyStoragePermission(context);
        }
        return result;
      } else if (Platform.isIOS) {
        return await _requestIOSPhotosPermission(context);
      }
      return false;
    } catch (e) {
      Log.e('Error requesting photos permission', 'PRODUCTION_PERMISSION', e);
      // Try fallback approach
      try {
        Log.i('Trying fallback permission request...', 'PRODUCTION_PERMISSION');
        final result = await Permission.storage.request();
        return result.isGranted;
      } catch (fallbackError) {
        Log.e('Fallback permission also failed', 'PRODUCTION_PERMISSION', fallbackError);
        return false;
      }
    }
  }
  
  /// Request Android photos permission based on API level
  static Future<bool> _requestAndroidPhotosPermission(BuildContext context) async {
    try {
      // For Android 13+ (API 33+), use READ_MEDIA_IMAGES
      // For older versions, use READ_EXTERNAL_STORAGE
      final isAndroid13OrHigher = await _isAndroid13OrHigher();
      
      if (isAndroid13OrHigher) {
        Log.i('Android 13+ detected, using READ_MEDIA_IMAGES', 'PRODUCTION_PERMISSION');
        return await _requestModernMediaPermission(context);
      } else {
        Log.i('Android <13 detected, using READ_EXTERNAL_STORAGE', 'PRODUCTION_PERMISSION');
        return await _requestLegacyStoragePermission(context);
      }
    } catch (e) {
      Log.e('Error in Android photos permission', 'PRODUCTION_PERMISSION', e);
      return false;
    }
  }
  
  /// Request modern media permission (Android 13+)
  static Future<bool> _requestModernMediaPermission(BuildContext context) async {
    try {
      final status = await Permission.photos.status;
      Log.i('Modern media permission status: $status', 'PRODUCTION_PERMISSION');
      
      if (status.isGranted || status.isLimited) {
        Log.i('Modern media permission already granted/limited', 'PRODUCTION_PERMISSION');
        return true;
      }
      
      if (status.isPermanentlyDenied) {
        Log.w('Modern media permission permanently denied', 'PRODUCTION_PERMISSION');
        _showSettingsDialog(context, 'Photos Permission', 
          'Photo library access is needed to select and share images. Please enable it in device settings.');
        return false;
      }
      
      // Request permission directly without custom dialog
      Log.i('Requesting modern media permission...', 'PRODUCTION_PERMISSION');
      final result = await Permission.photos.request();
      Log.i('Modern media permission result: $result', 'PRODUCTION_PERMISSION');
      
      return result.isGranted || result.isLimited;
      
    } catch (e) {
      Log.e('Error requesting modern media permission', 'PRODUCTION_PERMISSION', e);
      return false;
    }
  }
  
  /// Request legacy storage permission (Android <13)
  static Future<bool> _requestLegacyStoragePermission(BuildContext context) async {
    try {
      final status = await Permission.storage.status;
      Log.i('Legacy storage permission status: $status', 'PRODUCTION_PERMISSION');
      
      if (status.isGranted) {
        Log.i('Legacy storage permission already granted', 'PRODUCTION_PERMISSION');
        return true;
      }
      
      if (status.isPermanentlyDenied) {
        Log.w('Legacy storage permission permanently denied', 'PRODUCTION_PERMISSION');
        _showSettingsDialog(context, 'Storage Permission', 
          'Storage access is needed to select and share images. Please enable it in device settings.');
        return false;
      }
      
      // Request permission directly without custom dialog
      Log.i('Requesting legacy storage permission...', 'PRODUCTION_PERMISSION');
      final result = await Permission.storage.request();
      Log.i('Legacy storage permission result: $result', 'PRODUCTION_PERMISSION');
      
      return result.isGranted;
      
    } catch (e) {
      Log.e('Error requesting legacy storage permission', 'PRODUCTION_PERMISSION', e);
      return false;
    }
  }
  
  /// Request iOS photos permission
  static Future<bool> _requestIOSPhotosPermission(BuildContext context) async {
    try {
      Log.i('Requesting iOS photos permission', 'PRODUCTION_PERMISSION');
      
      final status = await Permission.photos.status;
      Log.i('iOS photos permission status: $status', 'PRODUCTION_PERMISSION');
      
      if (status.isGranted || status.isLimited) {
        Log.i('iOS photos permission already granted/limited', 'PRODUCTION_PERMISSION');
        return true;
      }
      
      if (status.isPermanentlyDenied) {
        Log.w('iOS photos permission permanently denied', 'PRODUCTION_PERMISSION');
        _showSettingsDialog(context, 'Photos Permission', 
          'Photo library access is needed to select and share images. Please enable it in iOS Settings > Privacy & Security > Photos.');
        return false;
      }
      
      // Request permission directly without custom dialog
      Log.i('Requesting iOS photos permission...', 'PRODUCTION_PERMISSION');
      final result = await Permission.photos.request();
      Log.i('iOS photos permission result: $result', 'PRODUCTION_PERMISSION');
      
      return result.isGranted || result.isLimited;
      
    } catch (e) {
      Log.e('Error requesting iOS photos permission', 'PRODUCTION_PERMISSION', e);
      return false;
    }
  }
  
  /// Request microphone permission
  static Future<bool> requestMicrophonePermission(BuildContext context) async {
    if (kIsWeb) return true;
    
    try {
      Log.i('Requesting microphone permission', 'PRODUCTION_PERMISSION');
      
      final status = await Permission.microphone.status;
      Log.i('Microphone permission status: $status', 'PRODUCTION_PERMISSION');
      
      if (status.isGranted) {
        Log.i('Microphone permission already granted', 'PRODUCTION_PERMISSION');
        return true;
      }
      
      if (status.isPermanentlyDenied) {
        Log.w('Microphone permission permanently denied', 'PRODUCTION_PERMISSION');
        _showSettingsDialog(context, 'Microphone Permission', 
          'Microphone access is needed to record voice messages. Please enable it in device settings.');
        return false;
      }
      
      // Request permission directly without custom dialog
      Log.i('Requesting microphone permission...', 'PRODUCTION_PERMISSION');
      final result = await Permission.microphone.request();
      Log.i('Microphone permission result: $result', 'PRODUCTION_PERMISSION');
      
      return result.isGranted;
      
    } catch (e) {
      Log.e('Error requesting microphone permission', 'PRODUCTION_PERMISSION', e);
      return false;
    }
  }
  
  /// Request notification permission
  static Future<bool> requestNotificationPermission(BuildContext context) async {
    if (kIsWeb) return true;
    
    try {
      Log.i('Requesting notification permission', 'PRODUCTION_PERMISSION');
      
      final status = await Permission.notification.status;
      Log.i('Notification permission status: $status', 'PRODUCTION_PERMISSION');
      
      if (status.isGranted) {
        Log.i('Notification permission already granted', 'PRODUCTION_PERMISSION');
        return true;
      }
      
      if (status.isPermanentlyDenied) {
        Log.w('Notification permission permanently denied', 'PRODUCTION_PERMISSION');
        _showSettingsDialog(context, 'Notification Permission', 
          'Notification access is needed to receive alerts about new messages. Please enable it in device settings.');
        return false;
      }
      
      // Request permission directly without custom dialog
      Log.i('Requesting notification permission...', 'PRODUCTION_PERMISSION');
      final result = await Permission.notification.request();
      Log.i('Notification permission result: $result', 'PRODUCTION_PERMISSION');
      
      return result.isGranted;
      
    } catch (e) {
      Log.e('Error requesting notification permission', 'PRODUCTION_PERMISSION', e);
      return false;
    }
  }
  
  /// Request location permission
  static Future<bool> requestLocationPermission(BuildContext context) async {
    if (kIsWeb) return true;
    
    try {
      Log.i('Requesting location permission', 'PRODUCTION_PERMISSION');
      
      final status = await Permission.location.status;
      Log.i('Location permission status: $status', 'PRODUCTION_PERMISSION');
      
      if (status.isGranted) {
        Log.i('Location permission already granted', 'PRODUCTION_PERMISSION');
        return true;
      }
      
      if (status.isPermanentlyDenied) {
        Log.w('Location permission permanently denied', 'PRODUCTION_PERMISSION');
        _showSettingsDialog(context, 'Location Permission', 
          'Location access is needed to share your location in chat conversations. Please enable it in device settings.');
        return false;
      }
      
      // Request permission directly without custom dialog
      Log.i('Requesting location permission...', 'PRODUCTION_PERMISSION');
      final result = await Permission.location.request();
      Log.i('Location permission result: $result', 'PRODUCTION_PERMISSION');
      
      return result.isGranted;
      
    } catch (e) {
      Log.e('Error requesting location permission', 'PRODUCTION_PERMISSION', e);
      return false;
    }
  }
  
  /// Check if device is Android 13 or higher
  static Future<bool> _isAndroid13OrHigher() async {
    try {
      if (!Platform.isAndroid) return false;
      
      // Try to access photos permission - if it works, we're on Android 13+
      // If it throws an error, we're on older Android
      try {
        await Permission.photos.status;
        Log.i('Photos permission available - Android 13+ detected', 'PRODUCTION_PERMISSION');
        return true;
      } catch (e) {
        Log.i('Photos permission not available - Android <13 detected', 'PRODUCTION_PERMISSION');
        return false;
      }
    } catch (e) {
      Log.w('Could not determine Android version, defaulting to legacy permissions', 'PRODUCTION_PERMISSION');
      return false; // Default to legacy permissions if we can't determine version
    }
  }
  
  /// Debug method to check all permission statuses
  static Future<Map<String, dynamic>> debugAllPermissions() async {
    final Map<String, dynamic> results = {};
    
    try {
      if (Platform.isAndroid) {
        // Android permissions
        try {
          final photosStatus = await Permission.photos.status;
          results['photos'] = photosStatus.toString();
        } catch (e) {
          results['photos'] = 'ERROR: $e';
        }
        
        try {
          final storageStatus = await Permission.storage.status;
          results['storage'] = storageStatus.toString();
        } catch (e) {
          results['storage'] = 'ERROR: $e';
        }
        
        try {
          final cameraStatus = await Permission.camera.status;
          results['camera'] = cameraStatus.toString();
        } catch (e) {
          results['camera'] = 'ERROR: $e';
        }
        
        // Check Android version
        results['androidVersion'] = await _isAndroid13OrHigher() ? '13+' : '<13';
        
      } else if (Platform.isIOS) {
        // iOS permissions
        try {
          final photosStatus = await Permission.photos.status;
          results['photos'] = photosStatus.toString();
        } catch (e) {
          results['photos'] = 'ERROR: $e';
        }
        
        try {
          final cameraStatus = await Permission.camera.status;
          results['camera'] = cameraStatus.toString();
        } catch (e) {
          results['camera'] = 'ERROR: $e';
        }
        
        results['platform'] = 'iOS';
      }
      
      results['platform'] = Platform.operatingSystem;
      results['timestamp'] = DateTime.now().toIso8601String();
      
    } catch (e) {
      results['error'] = e.toString();
    }
    
    return results;
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
      };
    }
    
    try {
      final cameraStatus = await Permission.camera.status;
      final photosStatus = await Permission.photos.status;
      final microphoneStatus = await Permission.microphone.status;
      final storageStatus = await Permission.storage.status;
      final notificationStatus = await Permission.notification.status;
      
      return {
        'camera': _getStatusString(cameraStatus),
        'photos': _getStatusString(photosStatus),
        'microphone': _getStatusString(microphoneStatus),
        'storage': _getStatusString(storageStatus),
        'notification': _getStatusString(notificationStatus),
      };
    } catch (e) {
      Log.e('Error getting permission status', 'PRODUCTION_PERMISSION', e);
      return {
        'camera': 'error',
        'photos': 'error',
        'microphone': 'error',
        'storage': 'error',
        'notification': 'error',
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
}
