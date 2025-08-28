import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'logger_service.dart';

/// Android-specific permission service that handles all Android permission scenarios
/// This service ensures proper permission handling across all Android versions
class AndroidPermissionFix {
  
  /// Request camera permission with proper Android handling
  static Future<bool> requestCameraPermission(BuildContext context) async {
    if (kIsWeb || !Platform.isAndroid) return true;
    
    try {
      Log.i('Requesting camera permission on Android', 'ANDROID_PERMISSION_FIX');
      
      // Check current status
      final status = await Permission.camera.status;
      Log.i('Camera permission status: $status', 'ANDROID_PERMISSION_FIX');
      
      if (status.isGranted) {
        Log.i('Camera permission already granted', 'ANDROID_PERMISSION_FIX');
        return true;
      }
      
      if (status.isPermanentlyDenied) {
        Log.w('Camera permission permanently denied', 'ANDROID_PERMISSION_FIX');
        _showSettingsDialog(
          context,
          'Camera Permission Required',
          'Camera access is needed to take photos and videos. Please enable it in Android Settings > Apps > Soc Chat App > Permissions > Camera.'
        );
        return false;
      }
      
      // Request permission
      Log.i('Requesting camera permission...', 'ANDROID_PERMISSION_FIX');
      final result = await Permission.camera.request();
      Log.i('Camera permission result: $result', 'ANDROID_PERMISSION_FIX');
      
      if (result.isGranted) {
        Log.i('Camera permission granted', 'ANDROID_PERMISSION_FIX');
        return true;
      }
      
      if (result.isDenied) {
        Log.w('Camera permission denied', 'ANDROID_PERMISSION_FIX');
        _showSettingsDialog(
          context,
          'Camera Permission Required',
          'Camera access is needed to take photos and videos. Please enable it in Android Settings > Apps > Soc Chat App > Permissions > Camera.'
        );
        return false;
      }
      
      return false;
    } catch (e) {
      Log.e('Error requesting camera permission', 'ANDROID_PERMISSION_FIX', e);
      return false;
    }
  }

  /// Request photos permission with proper Android version handling
  static Future<bool> requestPhotosPermission(BuildContext context) async {
    if (kIsWeb || !Platform.isAndroid) return true;
    
    try {
      Log.i('Requesting photos permission on Android', 'ANDROID_PERMISSION_FIX');
      
      // Check if we're on Android 13+ (API 33+)
      final isAndroid13OrHigher = await _isAndroid13OrHigher();
      Log.i('Android version check: ${isAndroid13OrHigher ? "13+" : "<13"}', 'ANDROID_PERMISSION_FIX');
      
      if (isAndroid13OrHigher) {
        return await _requestModernMediaPermission(context);
      } else {
        return await _requestLegacyStoragePermission(context);
      }
    } catch (e) {
      Log.e('Error requesting photos permission', 'ANDROID_PERMISSION_FIX', e);
      return false;
    }
  }

  /// Request modern media permission (Android 13+)
  static Future<bool> _requestModernMediaPermission(BuildContext context) async {
    try {
      Log.i('Requesting modern media permission (Android 13+)', 'ANDROID_PERMISSION_FIX');
      
      final status = await Permission.photos.status;
      Log.i('Modern media permission status: $status', 'ANDROID_PERMISSION_FIX');
      
      if (status.isGranted || status.isLimited) {
        Log.i('Modern media permission already granted/limited', 'ANDROID_PERMISSION_FIX');
        return true;
      }
      
      if (status.isPermanentlyDenied) {
        Log.w('Modern media permission permanently denied', 'ANDROID_PERMISSION_FIX');
        _showSettingsDialog(
          context,
          'Photos Permission Required',
          'Photo library access is needed to select and share images. Please enable it in Android Settings > Apps > Soc Chat App > Permissions > Photos and videos.'
        );
        return false;
      }
      
      // Request permission
      Log.i('Requesting modern media permission...', 'ANDROID_PERMISSION_FIX');
      final result = await Permission.photos.request();
      Log.i('Modern media permission result: $result', 'ANDROID_PERMISSION_FIX');
      
      if (result.isGranted || result.isLimited) {
        Log.i('Modern media permission granted/limited', 'ANDROID_PERMISSION_FIX');
        return true;
      }
      
      if (result.isDenied) {
        Log.w('Modern media permission denied', 'ANDROID_PERMISSION_FIX');
        _showSettingsDialog(
          context,
          'Photos Permission Required',
          'Photo library access is needed to select and share images. Please enable it in Android Settings > Apps > Soc Chat App > Permissions > Photos and videos.'
        );
        return false;
      }
      
      return false;
    } catch (e) {
      Log.e('Error requesting modern media permission', 'ANDROID_PERMISSION_FIX', e);
      return false;
    }
  }

  /// Request legacy storage permission (Android <13)
  static Future<bool> _requestLegacyStoragePermission(BuildContext context) async {
    try {
      Log.i('Requesting legacy storage permission (Android <13)', 'ANDROID_PERMISSION_FIX');
      
      final status = await Permission.storage.status;
      Log.i('Legacy storage permission status: $status', 'ANDROID_PERMISSION_FIX');
      
      if (status.isGranted) {
        Log.i('Legacy storage permission already granted', 'ANDROID_PERMISSION_FIX');
        return true;
      }
      
      if (status.isPermanentlyDenied) {
        Log.w('Legacy storage permission permanently denied', 'ANDROID_PERMISSION_FIX');
        _showSettingsDialog(
          context,
          'Storage Permission Required',
          'Storage access is needed to select and share images. Please enable it in Android Settings > Apps > Soc Chat App > Permissions > Storage.'
        );
        return false;
      }
      
      // Request permission
      Log.i('Requesting legacy storage permission...', 'ANDROID_PERMISSION_FIX');
      final result = await Permission.storage.request();
      Log.i('Legacy storage permission result: $result', 'ANDROID_PERMISSION_FIX');
      
      if (result.isGranted) {
        Log.i('Legacy storage permission granted', 'ANDROID_PERMISSION_FIX');
        return true;
      }
      
      if (result.isDenied) {
        Log.w('Legacy storage permission denied', 'ANDROID_PERMISSION_FIX');
        _showSettingsDialog(
          context,
          'Storage Permission Required',
          'Storage access is needed to select and share images. Please enable it in Android Settings > Apps > Soc Chat App > Permissions > Storage.'
        );
        return false;
      }
      
      return false;
    } catch (e) {
      Log.e('Error requesting legacy storage permission', 'ANDROID_PERMISSION_FIX', e);
      return false;
    }
  }

  /// Request microphone permission with proper Android handling
  static Future<bool> requestMicrophonePermission(BuildContext context) async {
    if (kIsWeb || !Platform.isAndroid) return true;
    
    try {
      Log.i('Requesting microphone permission on Android', 'ANDROID_PERMISSION_FIX');
      
      // Check current status
      final status = await Permission.microphone.status;
      Log.i('Microphone permission status: $status', 'ANDROID_PERMISSION_FIX');
      
      if (status.isGranted) {
        Log.i('Microphone permission already granted', 'ANDROID_PERMISSION_FIX');
        return true;
      }
      
      if (status.isPermanentlyDenied) {
        Log.w('Microphone permission permanently denied', 'ANDROID_PERMISSION_FIX');
        _showSettingsDialog(
          context,
          'Microphone Permission Required',
          'Microphone access is needed for voice messages and calls. Please enable it in Android Settings > Apps > Soc Chat App > Permissions > Microphone.'
        );
        return false;
      }
      
      // Request permission
      Log.i('Requesting microphone permission...', 'ANDROID_PERMISSION_FIX');
      final result = await Permission.microphone.request();
      Log.i('Microphone permission result: $result', 'ANDROID_PERMISSION_FIX');
      
      if (result.isGranted) {
        Log.i('Microphone permission granted', 'ANDROID_PERMISSION_FIX');
        return true;
      }
      
      if (result.isDenied) {
        Log.w('Microphone permission denied', 'ANDROID_PERMISSION_FIX');
        _showSettingsDialog(
          context,
          'Microphone Permission Required',
          'Microphone access is needed for voice messages and calls. Please enable it in Android Settings > Apps > Soc Chat App > Permissions > Microphone.'
        );
        return false;
      }
      
      return false;
    } catch (e) {
      Log.e('Error requesting microphone permission', 'ANDROID_PERMISSION_FIX', e);
      return false;
    }
  }

  /// Request location permission with proper Android handling
  static Future<bool> requestLocationPermission(BuildContext context) async {
    if (kIsWeb || !Platform.isAndroid) return true;
    
    try {
      Log.i('Requesting location permission on Android', 'ANDROID_PERMISSION_FIX');
      
      // Check current status
      final status = await Permission.location.status;
      Log.i('Location permission status: $status', 'ANDROID_PERMISSION_FIX');
      
      if (status.isGranted) {
        Log.i('Location permission already granted', 'ANDROID_PERMISSION_FIX');
        return true;
      }
      
      if (status.isPermanentlyDenied) {
        Log.w('Location permission permanently denied', 'ANDROID_PERMISSION_FIX');
        _showSettingsDialog(
          context,
          'Location Permission Required',
          'Location access is needed to share your location in chat conversations. Please enable it in Android Settings > Apps > Soc Chat App > Permissions > Location.'
        );
        return false;
      }
      
      // Request permission
      Log.i('Requesting location permission...', 'ANDROID_PERMISSION_FIX');
      final result = await Permission.location.request();
      Log.i('Location permission result: $result', 'ANDROID_PERMISSION_FIX');
      
      if (result.isGranted) {
        Log.i('Location permission granted', 'ANDROID_PERMISSION_FIX');
        return true;
      }
      
      if (result.isDenied) {
        Log.w('Location permission denied', 'ANDROID_PERMISSION_FIX');
        _showSettingsDialog(
          context,
          'Location Permission Required',
          'Location access is needed to share your location in chat conversations. Please enable it in Android Settings > Apps > Soc Chat App > Permissions > Location.'
        );
        return false;
      }
      
      return false;
    } catch (e) {
      Log.e('Error requesting location permission', 'ANDROID_PERMISSION_FIX', e);
      return false;
    }
  }

  /// Request notification permission with proper Android handling
  static Future<bool> requestNotificationPermission(BuildContext context) async {
    if (kIsWeb || !Platform.isAndroid) return true;
    
    try {
      Log.i('Requesting notification permission on Android', 'ANDROID_PERMISSION_FIX');
      
      // Check if we're on Android 13+ (API 33+) where notification permission is required
      final isAndroid13OrHigher = await _isAndroid13OrHigher();
      
      if (!isAndroid13OrHigher) {
        Log.i('Android <13 detected, notification permission not required', 'ANDROID_PERMISSION_FIX');
        return true; // Notification permission not required on older Android versions
      }
      
      // Check current status
      final status = await Permission.notification.status;
      Log.i('Notification permission status: $status', 'ANDROID_PERMISSION_FIX');
      
      if (status.isGranted) {
        Log.i('Notification permission already granted', 'ANDROID_PERMISSION_FIX');
        return true;
      }
      
      if (status.isPermanentlyDenied) {
        Log.w('Notification permission permanently denied', 'ANDROID_PERMISSION_FIX');
        _showSettingsDialog(
          context,
          'Notification Permission Required',
          'Notification access is needed to receive message alerts. Please enable it in Android Settings > Apps > Soc Chat App > Permissions > Notifications.'
        );
        return false;
      }
      
      // Request permission
      Log.i('Requesting notification permission...', 'ANDROID_PERMISSION_FIX');
      final result = await Permission.notification.request();
      Log.i('Notification permission result: $result', 'ANDROID_PERMISSION_FIX');
      
      if (result.isGranted) {
        Log.i('Notification permission granted', 'ANDROID_PERMISSION_FIX');
        return true;
      }
      
      if (result.isDenied) {
        Log.w('Notification permission denied', 'ANDROID_PERMISSION_FIX');
        _showSettingsDialog(
          context,
          'Notification Permission Required',
          'Notification access is needed to receive message alerts. Please enable it in Android Settings > Apps > Soc Chat App > Permissions > Notifications.'
        );
        return false;
      }
      
      return false;
    } catch (e) {
      Log.e('Error requesting notification permission', 'ANDROID_PERMISSION_FIX', e);
      return false;
    }
  }

  /// Check if device is Android 13 or higher (API 33+)
  static Future<bool> _isAndroid13OrHigher() async {
    try {
      if (!Platform.isAndroid) return false;
      
      // Try to access photos permission - if it works, we're on Android 13+
      try {
        await Permission.photos.status;
        Log.i('Photos permission available - Android 13+ detected', 'ANDROID_PERMISSION_FIX');
        return true;
      } catch (e) {
        Log.i('Photos permission not available - Android <13 detected', 'ANDROID_PERMISSION_FIX');
        return false;
      }
    } catch (e) {
      Log.w('Could not determine Android version, defaulting to legacy permissions', 'ANDROID_PERMISSION_FIX');
      return false; // Default to legacy permissions if we can't determine version
    }
  }

  /// Get comprehensive permission status for all Android permissions
  static Future<Map<Permission, PermissionStatus>> getAllPermissionStatuses() async {
    final Map<Permission, PermissionStatus> statuses = {};
    
    if (kIsWeb || !Platform.isAndroid) return statuses;
    
    try {
      final permissions = [
        Permission.camera,
        Permission.microphone,
        Permission.location,
      ];
      
      // Add version-specific permissions
      final isAndroid13OrHigher = await _isAndroid13OrHigher();
      if (isAndroid13OrHigher) {
        permissions.addAll([
          Permission.photos,
          Permission.notification,
        ]);
      } else {
        permissions.add(Permission.storage);
      }
      
      for (final permission in permissions) {
        try {
          final status = await permission.status;
          statuses[permission] = status;
        } catch (e) {
          Log.e('Error checking permission status for $permission', 'ANDROID_PERMISSION_FIX', e);
        }
      }
    } catch (e) {
      Log.e('Error getting permission statuses', 'ANDROID_PERMISSION_FIX', e);
    }
    
    return statuses;
  }

  /// Show settings dialog for permanently denied permissions
  static void _showSettingsDialog(BuildContext context, String title, String message) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(title),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                openAppSettings();
              },
              child: Text('Open Settings'),
            ),
          ],
        );
      },
    );
  }
}
