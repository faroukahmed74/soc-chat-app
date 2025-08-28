import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:image_picker/image_picker.dart';
import 'logger_service.dart';

/// iOS-specific media permission service that properly handles permission dialogs
/// This service ensures permissions are requested with proper user dialogs on iOS
class IOSMediaPermissionFix {
  static final ImagePicker _picker = ImagePicker();

  /// Request camera permission with proper iOS dialog handling
  static Future<bool> requestCameraPermission(BuildContext context) async {
    if (kIsWeb || !Platform.isIOS) return true;
    
    try {
      Log.i('Requesting camera permission on iOS', 'IOS_MEDIA_PERMISSION');
      
      // Check current status
      final status = await Permission.camera.status;
      Log.i('Camera permission status: $status', 'IOS_MEDIA_PERMISSION');
      
      if (status.isGranted) {
        Log.i('Camera permission already granted', 'IOS_MEDIA_PERMISSION');
        return true;
      }
      
      if (status.isPermanentlyDenied) {
        Log.w('Camera permission permanently denied', 'IOS_MEDIA_PERMISSION');
        _showSettingsDialog(
          context, 
          'Camera Permission Required',
          'Camera access is needed to take photos and videos. Please enable it in iOS Settings > Privacy & Security > Camera.'
        );
        return false;
      }
      
      if (status.isRestricted) {
        Log.w('Camera permission restricted', 'IOS_MEDIA_PERMISSION');
        _showRestrictedDialog(
          context,
          'Camera Permission Restricted',
          'Camera access is restricted by parental controls or device policies.'
        );
        return false;
      }
      
      // Show explanation dialog first
      final shouldRequest = await _showPermissionExplanationDialog(
        context,
        'Camera Permission Required',
        'Camera access is needed to take photos and videos for sharing in chat conversations.',
        'Camera access is needed to take photos and videos. Please enable it in iOS Settings > Privacy & Security > Camera.'
      );
      
      if (!shouldRequest) {
        Log.i('User declined camera permission request', 'IOS_MEDIA_PERMISSION');
        return false;
      }
      
      // Request permission
      Log.i('Requesting camera permission...', 'IOS_MEDIA_PERMISSION');
      final result = await Permission.camera.request();
      Log.i('Camera permission result: $result', 'IOS_MEDIA_PERMISSION');
      
      if (result.isGranted) {
        Log.i('Camera permission granted', 'IOS_MEDIA_PERMISSION');
        return true;
      }
      
      if (result.isDenied) {
        Log.w('Camera permission denied', 'IOS_MEDIA_PERMISSION');
        _showSettingsDialog(
          context,
          'Camera Permission Required',
          'Camera access is needed to take photos and videos. Please enable it in iOS Settings > Privacy & Security > Camera.'
        );
        return false;
      }
      
      return false;
    } catch (e) {
      Log.e('Error requesting camera permission', 'IOS_MEDIA_PERMISSION', e);
      return false;
    }
  }

  /// Request photos permission with proper iOS dialog handling
  static Future<bool> requestPhotosPermission(BuildContext context) async {
    if (kIsWeb || !Platform.isIOS) return true;
    
    try {
      Log.i('Requesting photos permission on iOS', 'IOS_MEDIA_PERMISSION');
      
      // Check current status
      final status = await Permission.photos.status;
      Log.i('Photos permission status: $status', 'IOS_MEDIA_PERMISSION');
      
      if (status.isGranted || status.isLimited) {
        Log.i('Photos permission already granted/limited', 'IOS_MEDIA_PERMISSION');
        return true;
      }
      
      if (status.isPermanentlyDenied) {
        Log.w('Photos permission permanently denied', 'IOS_MEDIA_PERMISSION');
        _showSettingsDialog(
          context,
          'Photos Permission Required',
          'Photo library access is needed to select and share images. Please enable it in iOS Settings > Privacy & Security > Photos.'
        );
        return false;
      }
      
      if (status.isRestricted) {
        Log.w('Photos permission restricted', 'IOS_MEDIA_PERMISSION');
        _showRestrictedDialog(
          context,
          'Photos Permission Restricted',
          'Photo library access is restricted by parental controls or device policies.'
        );
        return false;
      }
      
      // Show explanation dialog first
      final shouldRequest = await _showPermissionExplanationDialog(
        context,
        'Photos Permission Required',
        'Photo library access is needed to select and share images from your gallery.',
        'Photo library access is needed to select and share images. Please enable it in iOS Settings > Privacy & Security > Photos.'
      );
      
      if (!shouldRequest) {
        Log.i('User declined photos permission request', 'IOS_MEDIA_PERMISSION');
        return false;
      }
      
      // Request permission
      Log.i('Requesting photos permission...', 'IOS_MEDIA_PERMISSION');
      final result = await Permission.photos.request();
      Log.i('Photos permission result: $result', 'IOS_MEDIA_PERMISSION');
      
      if (result.isGranted || result.isLimited) {
        Log.i('Photos permission granted/limited', 'IOS_MEDIA_PERMISSION');
        return true;
      }
      
      if (result.isDenied) {
        Log.w('Photos permission denied', 'IOS_MEDIA_PERMISSION');
        _showSettingsDialog(
          context,
          'Photos Permission Required',
          'Photo library access is needed to select and share images. Please enable it in iOS Settings > Privacy & Security > Photos.'
        );
        return false;
      }
      
      return false;
    } catch (e) {
      Log.e('Error requesting photos permission', 'IOS_MEDIA_PERMISSION', e);
      return false;
    }
  }

  /// Request microphone permission with proper iOS dialog handling
  static Future<bool> requestMicrophonePermission(BuildContext context) async {
    if (kIsWeb || !Platform.isIOS) return true;
    
    try {
      Log.i('Requesting microphone permission on iOS', 'IOS_MEDIA_PERMISSION');
      
      // Check current status
      final status = await Permission.microphone.status;
      Log.i('Microphone permission status: $status', 'IOS_MEDIA_PERMISSION');
      
      if (status.isGranted) {
        Log.i('Microphone permission already granted', 'IOS_MEDIA_PERMISSION');
        return true;
      }
      
      if (status.isPermanentlyDenied) {
        Log.w('Microphone permission permanently denied', 'IOS_MEDIA_PERMISSION');
        _showSettingsDialog(
          context,
          'Microphone Permission Required',
          'Microphone access is needed for voice messages and calls. Please enable it in iOS Settings > Privacy & Security > Microphone.'
        );
        return false;
      }
      
      if (status.isRestricted) {
        Log.w('Microphone permission restricted', 'IOS_MEDIA_PERMISSION');
        _showRestrictedDialog(
          context,
          'Microphone Permission Restricted',
          'Microphone access is restricted by parental controls or device policies.'
        );
        return false;
      }
      
      // Show explanation dialog first
      final shouldRequest = await _showPermissionExplanationDialog(
        context,
        'Microphone Permission Required',
        'Microphone access is needed to record voice messages and participate in voice calls.',
        'Microphone access is needed for voice messages and calls. Please enable it in iOS Settings > Privacy & Security > Microphone.'
      );
      
      if (!shouldRequest) {
        Log.i('User declined microphone permission request', 'IOS_MEDIA_PERMISSION');
        return false;
      }
      
      // Request permission
      Log.i('Requesting microphone permission...', 'IOS_MEDIA_PERMISSION');
      final result = await Permission.microphone.request();
      Log.i('Microphone permission result: $result', 'IOS_MEDIA_PERMISSION');
      
      if (result.isGranted) {
        Log.i('Microphone permission granted', 'IOS_MEDIA_PERMISSION');
        return true;
      }
      
      if (result.isDenied) {
        Log.w('Microphone permission denied', 'IOS_MEDIA_PERMISSION');
        _showSettingsDialog(
          context,
          'Microphone Permission Required',
          'Microphone access is needed for voice messages and calls. Please enable it in iOS Settings > Privacy & Security > Microphone.'
        );
        return false;
      }
      
      return false;
    } catch (e) {
      Log.e('Error requesting microphone permission', 'IOS_MEDIA_PERMISSION', e);
      return false;
    }
  }

  /// Pick image from camera with proper iOS permission handling
  static Future<XFile?> pickImageFromCamera(BuildContext context) async {
    if (kIsWeb) return null;
    
    try {
      // Request permission first
      final hasPermission = await requestCameraPermission(context);
      if (!hasPermission) {
        Log.w('Camera permission denied, cannot pick image', 'IOS_MEDIA_PERMISSION');
        return null;
      }
      
      // Pick image
      final XFile? image = await _picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 85,
      );
      
      if (image != null) {
        Log.i('Image picked from camera: ${image.name}', 'IOS_MEDIA_PERMISSION');
      }
      
      return image;
    } catch (e) {
      Log.e('Error picking image from camera', 'IOS_MEDIA_PERMISSION', e);
      return null;
    }
  }

  /// Pick image from gallery with proper iOS permission handling
  static Future<XFile?> pickImageFromGallery(BuildContext context) async {
    if (kIsWeb) return null;
    
    try {
      // Request permission first
      final hasPermission = await requestPhotosPermission(context);
      if (!hasPermission) {
        Log.w('Photos permission denied, cannot pick image', 'IOS_MEDIA_PERMISSION');
        return null;
      }
      
      // Pick image
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 85,
      );
      
      if (image != null) {
        Log.i('Image picked from gallery: ${image.name}', 'IOS_MEDIA_PERMISSION');
      }
      
      return image;
    } catch (e) {
      Log.e('Error picking image from gallery', 'IOS_MEDIA_PERMISSION', e);
      return null;
    }
  }

  /// Pick video from camera with proper iOS permission handling
  static Future<XFile?> pickVideoFromCamera(BuildContext context) async {
    if (kIsWeb) return null;
    
    try {
      // Request permission first
      final hasPermission = await requestCameraPermission(context);
      if (!hasPermission) {
        Log.w('Camera permission denied, cannot pick video', 'IOS_MEDIA_PERMISSION');
        return null;
      }
      
      // Pick video
      final XFile? video = await _picker.pickVideo(
        source: ImageSource.camera,
        maxDuration: const Duration(minutes: 5),
      );
      
      if (video != null) {
        Log.i('Video picked from camera: ${video.name}', 'IOS_MEDIA_PERMISSION');
      }
      
      return video;
    } catch (e) {
      Log.e('Error picking video from camera', 'IOS_MEDIA_PERMISSION', e);
      return null;
    }
  }

  /// Pick video from gallery with proper iOS permission handling
  static Future<XFile?> pickVideoFromGallery(BuildContext context) async {
    if (kIsWeb) return null;
    
    try {
      // Request permission first
      final hasPermission = await requestPhotosPermission(context);
      if (!hasPermission) {
        Log.w('Photos permission denied, cannot pick video', 'IOS_MEDIA_PERMISSION');
        return null;
      }
      
      // Pick video
      final XFile? video = await _picker.pickVideo(
        source: ImageSource.gallery,
        maxDuration: const Duration(minutes: 10),
      );
      
      if (video != null) {
        Log.i('Video picked from gallery: ${video.name}', 'IOS_MEDIA_PERMISSION');
      }
      
      return video;
    } catch (e) {
      Log.e('Error picking video from gallery', 'IOS_MEDIA_PERMISSION', e);
      return null;
    }
  }

  /// Show permission explanation dialog
  static Future<bool> _showPermissionExplanationDialog(
    BuildContext context,
    String title,
    String message,
    String settingsMessage,
  ) async {
    return await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(title),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(message),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.blue, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        settingsMessage,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.blue[700],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text('Allow'),
            ),
          ],
        );
      },
    ) ?? false;
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

  /// Show restricted permission dialog
  static void _showRestrictedDialog(BuildContext context, String title, String message) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(title),
          content: Text(message),
          actions: [
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('OK'),
            ),
          ],
        );
      },
    );
  }
}
