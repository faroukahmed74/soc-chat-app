import 'package:permission_handler/permission_handler.dart';
import 'package:flutter/foundation.dart' show kIsWeb, defaultTargetPlatform, TargetPlatform;
import 'package:url_launcher/url_launcher.dart';
import 'logger_service.dart';

/// Permission request result callback
typedef PermissionResultCallback = void Function(bool granted, String? message);

/// Permission explanation callback
typedef PermissionExplanationCallback = Future<bool> Function(String title, String message, String settingsMessage);

/// iOS-specific permission service using callback-based approach
/// This eliminates BuildContext dependencies and fixes all BuildContext issues
class IOSPermissionService {
  /// Request permission with iOS-specific handling
  static Future<bool> requestPermissionWithExplanation(
    Permission permission,
    String title,
    String message,
    String settingsMessage, {
    required PermissionExplanationCallback showExplanation,
    required PermissionResultCallback showResult,
  }) async {
    if (kIsWeb) return true;
    
    try {
      // Check current status first
      final currentStatus = await permission.status;
      Log.i('Permission status: $currentStatus', 'IOS_PERMISSION');
      
      // If already granted or limited, return true
      if (currentStatus.isGranted || currentStatus == PermissionStatus.limited) {
        return true;
      }

      // If permanently denied, show settings dialog
      if (currentStatus == PermissionStatus.permanentlyDenied) {
        return await _showSettingsDialog(showExplanation, title, settingsMessage);
      }

      // If restricted (parental controls, etc.), show explanation
      if (currentStatus == PermissionStatus.restricted) {
        return await _showRestrictedDialog(showExplanation, title, message);
      }

      // Show explanation dialog before requesting permission
      final shouldRequest = await showExplanation(title, message, settingsMessage);
      if (!shouldRequest) {
        return false;
      }

      // Request permission
      final result = await permission.request();
      
      if (result.isGranted || result.isLimited) {
        return true;
      }

      // If denied after request, show settings option
      if (result.isDenied) {
        return await _showSettingsDialog(showExplanation, title, settingsMessage);
      }

      return false;
    } catch (e) {
      Log.e('Error requesting permission', 'IOS_PERMISSION', e);
      return false;
    }
  }

  /// Request camera permission with iOS-specific handling
  static Future<bool> requestCameraPermission({
    required PermissionExplanationCallback showExplanation,
    required PermissionResultCallback showResult,
  }) async {
    return await requestPermissionWithExplanation(
      Permission.camera,
      'Camera Permission Required',
      'Camera access is needed to take photos and videos for sharing in chat conversations.',
      'Camera access is needed to take photos and videos. Please enable it in iOS Settings > Privacy & Security > Camera.',
      showExplanation: showExplanation,
      showResult: showResult,
    );
  }

  /// Request photos permission with iOS-specific handling
  static Future<bool> requestPhotosPermission({
    required PermissionExplanationCallback showExplanation,
    required PermissionResultCallback showResult,
  }) async {
    return await requestPermissionWithExplanation(
      Permission.photos,
      'Photos Permission Required',
      'Photo library access is needed to select and share images from your gallery.',
      'Photo library access is needed to select and share images. Please enable it in iOS Settings > Privacy & Security > Photos.',
      showExplanation: showExplanation,
      showResult: showResult,
    );
  }

  /// Request microphone permission with iOS-specific handling
  static Future<bool> requestMicrophonePermission({
    required PermissionExplanationCallback showExplanation,
    required PermissionResultCallback showResult,
  }) async {
    return await requestPermissionWithExplanation(
      Permission.microphone,
      'Microphone Permission Required',
      'Microphone access is needed to record voice messages and participate in voice calls.',
      'Microphone access is needed for voice messages and calls. Please enable it in iOS Settings > Privacy & Security > Microphone.',
      showExplanation: showExplanation,
      showResult: showResult,
    );
  }

  /// Request notification permission with iOS-specific handling
  static Future<bool> requestNotificationPermission({
    required PermissionResultCallback showResult,
  }) async {
    return await requestPermissionWithExplanation(
      Permission.notification,
      'Notification Permission Required',
      'Notification access is needed to receive alerts about new messages and important updates.',
      'Notification access is needed for message alerts. Please enable it in iOS Settings > Privacy & Security > Notifications.',
      showExplanation: (title, message, settingsMessage) async => true, // Always allow for notifications
      showResult: showResult,
    );
  }

  /// Request location permission with iOS-specific handling
  static Future<bool> requestLocationPermission({
    required PermissionExplanationCallback showExplanation,
    required PermissionResultCallback showResult,
  }) async {
    return await requestPermissionWithExplanation(
      Permission.location,
      'Location Permission Required',
      'Location access is needed to share your location in chat conversations.',
      'Location access is needed to share location. Please enable it in iOS Settings > Privacy & Security > Location Services.',
      showExplanation: showExplanation,
      showResult: showResult,
    );
  }

  /// Show restricted permission dialog
  static Future<bool> _showRestrictedDialog(
    PermissionExplanationCallback showExplanation,
    String title,
    String message,
  ) async {
    return await showExplanation(
      title,
      '$message\n\nThis permission is restricted by your device settings, parental controls, or other security features.',
      'This permission is restricted by your device settings, parental controls, or other security features.'
    );
  }

  /// Show settings dialog for permanently denied permissions
  static Future<bool> _showSettingsDialog(
    PermissionExplanationCallback showExplanation,
    String title,
    String settingsMessage,
  ) async {
    return await showExplanation(
      title,
      '$settingsMessage\n\nYou can change this in your device settings.',
      'You can change this in your device settings.'
    );
  }

  /// Open iOS Settings
  static Future<void> openIOSSettings() async {
    try {
      // Try to open app settings using permission_handler
      await openAppSettings();
    } catch (e) {
      Log.e('Error opening iOS Settings', 'IOS_PERMISSION', e);
      
      // Fallback: try to open iOS Settings app directly
      try {
        final url = 'App-Prefs:Privacy&path=CAMERA';
        if (await canLaunchUrl(Uri.parse(url))) {
          await launchUrl(Uri.parse(url));
        }
      } catch (e2) {
        Log.e('Error with fallback iOS Settings URL', 'IOS_PERMISSION', e2);
      }
    }
  }
}
