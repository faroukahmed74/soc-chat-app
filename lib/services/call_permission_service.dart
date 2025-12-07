import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:io';
import 'package:device_info_plus/device_info_plus.dart';
import 'logger_service.dart';

/// Unified permission service for call-related permissions
/// Handles Android 13+ (API 33+) granular permissions correctly
/// Supports Android, iOS, and Web platforms
class CallPermissionService {
  static final CallPermissionService _instance = CallPermissionService._internal();
  factory CallPermissionService() => _instance;
  CallPermissionService._internal();

  /// Request microphone permission (required for all calls)
  static Future<bool> requestMicrophonePermission(BuildContext? context) async {
    if (kIsWeb) {
      Log.i('Web platform: Microphone permission handled by browser', 'CALL_PERMISSION');
      return true;
    }

    try {
      Log.i('Requesting microphone permission', 'CALL_PERMISSION');
      final status = await Permission.microphone.status;
      Log.i('Microphone permission status: $status', 'CALL_PERMISSION');
      
      if (status.isGranted) {
        Log.i('Microphone permission already granted', 'CALL_PERMISSION');
        return true;
      }
      
      if (status.isPermanentlyDenied) {
        Log.w('Microphone permission permanently denied', 'CALL_PERMISSION');
        if (context != null) {
          _showSettingsDialog(
            context,
            'Microphone Permission Required',
            Platform.isAndroid
                ? 'Microphone access is needed for voice and video calls. Please enable it in Android Settings > Apps > SOC Chat App > Permissions > Microphone.'
                : 'Microphone access is needed for voice and video calls. Please enable it in iOS Settings > Privacy & Security > Microphone.',
          );
        }
        return false;
      }
      
      Log.i('Requesting microphone permission...', 'CALL_PERMISSION');
      final result = await Permission.microphone.request();
      Log.i('Microphone permission result: $result', 'CALL_PERMISSION');
      
      if (result.isGranted) {
        Log.i(' Microphone permission granted', 'CALL_PERMISSION');
        return true;
      }
      
      if (result.isDenied) {
        Log.w(' Microphone permission denied', 'CALL_PERMISSION');
        return false;
      }
      
      return false;
    } catch (e, stackTrace) {
      Log.e('Error requesting microphone permission', 'CALL_PERMISSION', e, stackTrace);
      return false;
    }
  }

  /// Request camera permission (required for video calls)
  static Future<bool> requestCameraPermission(BuildContext? context) async {
    if (kIsWeb) {
      Log.i('Web platform: Camera permission handled by browser', 'CALL_PERMISSION');
      return true;
    }

    try {
      Log.i('Requesting camera permission', 'CALL_PERMISSION');
      final status = await Permission.camera.status;
      Log.i('Camera permission status: $status', 'CALL_PERMISSION');
      
      if (status.isGranted) {
        Log.i('Camera permission already granted', 'CALL_PERMISSION');
        return true;
      }
      
      if (status.isPermanentlyDenied) {
        Log.w('Camera permission permanently denied', 'CALL_PERMISSION');
        if (context != null) {
          _showSettingsDialog(
            context,
            'Camera Permission Required',
            Platform.isAndroid
                ? 'Camera access is needed for video calls. Please enable it in Android Settings > Apps > SOC Chat App > Permissions > Camera.'
                : 'Camera access is needed for video calls. Please enable it in iOS Settings > Privacy & Security > Camera.',
          );
        }
        return false;
      }
      
      Log.i('Requesting camera permission...', 'CALL_PERMISSION');
      final result = await Permission.camera.request();
      Log.i('Camera permission result: $result', 'CALL_PERMISSION');
      
      if (result.isGranted) {
        Log.i(' Camera permission granted', 'CALL_PERMISSION');
        return true;
      }
      
      if (result.isDenied) {
        Log.w(' Camera permission denied', 'CALL_PERMISSION');
        return false;
      }
      
      return false;
    } catch (e, stackTrace) {
      Log.e('Error requesting camera permission', 'CALL_PERMISSION', e, stackTrace);
      return false;
    }
  }

  /// Request both microphone and camera permissions (for video calls)
  static Future<bool> requestCallPermissions({
    required BuildContext? context,
    required bool includeVideo,
  }) async {
    if (kIsWeb) {
      Log.i('Web platform: Call permissions handled by browser', 'CALL_PERMISSION');
      return true;
    }

    try {
      Log.i('Requesting call permissions (includeVideo: $includeVideo)', 'CALL_PERMISSION');
      final micGranted = await requestMicrophonePermission(context);
      if (!micGranted) {
        Log.w(' Microphone permission denied - cannot proceed with call', 'CALL_PERMISSION');
        return false;
      }
      
      if (includeVideo) {
        final cameraGranted = await requestCameraPermission(context);
        if (!cameraGranted) {
          Log.w(' Camera permission denied - cannot proceed with video call', 'CALL_PERMISSION');
          return false;
        }
      }
      
      Log.i(' All required call permissions granted', 'CALL_PERMISSION');
      return true;
    } catch (e, stackTrace) {
      Log.e('Error requesting call permissions', 'CALL_PERMISSION', e, stackTrace);
      return false;
    }
  }

  static Future<bool> hasMicrophonePermission() async {
    if (kIsWeb) return true;
    try {
      final status = await Permission.microphone.status;
      return status.isGranted;
    } catch (e) {
      Log.e('Error checking microphone permission', 'CALL_PERMISSION', e);
      return false;
    }
  }

  static Future<bool> hasCameraPermission() async {
    if (kIsWeb) return true;
    try {
      final status = await Permission.camera.status;
      return status.isGranted;
    } catch (e) {
      Log.e('Error checking camera permission', 'CALL_PERMISSION', e);
      return false;
    }
  }

  static Future<bool> isAndroid13Plus() async {
    if (kIsWeb || !Platform.isAndroid) return false;
    try {
      final deviceInfo = DeviceInfoPlugin();
      final androidInfo = await deviceInfo.androidInfo;
      return androidInfo.version.sdkInt >= 33;
    } catch (e) {
      Log.e('Error checking Android version', 'CALL_PERMISSION', e);
      return false;
    }
  }

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
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                openAppSettings();
              },
              child: const Text('Open Settings'),
            ),
          ],
        );
      },
    );
  }
}
