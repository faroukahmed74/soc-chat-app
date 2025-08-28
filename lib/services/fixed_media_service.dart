import 'dart:typed_data';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'logger_service.dart';

/// Fixed media service that properly handles permissions and media picking
/// This service ensures media permissions work correctly on both Android and iOS
class FixedMediaService {
  static final ImagePicker _picker = ImagePicker();

  /// Pick image from camera with proper permission handling
  static Future<Uint8List?> pickImageFromCamera(BuildContext context) async {
    if (kIsWeb) {
      // Web implementation would go here
      return null;
    }

    try {
      Log.i('Requesting camera permission for image capture', 'FIXED_MEDIA');
      
      // Request camera permission
      final hasPermission = await _requestCameraPermission(context);
      if (!hasPermission) {
        Log.w('Camera permission denied', 'FIXED_MEDIA');
        _showPermissionDeniedDialog(context, 'Camera', 'camera access is needed to take photos');
        return null;
      }

      Log.i('Camera permission granted, opening camera', 'FIXED_MEDIA');
      
      // Pick image from camera
      final XFile? image = await _picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 85,
      );

      if (image != null) {
        final bytes = await image.readAsBytes();
        Log.i('Image captured successfully: ${bytes.length} bytes', 'FIXED_MEDIA');
        return bytes;
      } else {
        Log.i('No image captured (user cancelled)', 'FIXED_MEDIA');
        return null;
      }
    } catch (e) {
      Log.e('Error picking image from camera', 'FIXED_MEDIA', e);
      _showErrorDialog(context, 'Camera Error', 'Failed to capture image: $e');
      return null;
    }
  }

  /// Pick image from gallery with proper permission handling
  static Future<Uint8List?> pickImageFromGallery(BuildContext context) async {
    if (kIsWeb) {
      // Web implementation would go here
      return null;
    }

    try {
      Log.i('Requesting photos permission for gallery access', 'FIXED_MEDIA');
      
      // Request photos permission
      final hasPermission = await _requestPhotosPermission(context);
      if (!hasPermission) {
        Log.w('Photos permission denied', 'FIXED_MEDIA');
        _showPermissionDeniedDialog(context, 'Photos', 'photo library access is needed to select images');
        return null;
      }

      Log.i('Photos permission granted, opening gallery', 'FIXED_MEDIA');
      
      // Pick image from gallery
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 85,
      );

      if (image != null) {
        final bytes = await image.readAsBytes();
        Log.i('Image selected successfully: ${bytes.length} bytes', 'FIXED_MEDIA');
        return bytes;
      } else {
        Log.i('No image selected (user cancelled)', 'FIXED_MEDIA');
        return null;
      }
    } catch (e) {
      Log.e('Error picking image from gallery', 'FIXED_MEDIA', e);
      _showErrorDialog(context, 'Gallery Error', 'Failed to select image: $e');
      return null;
    }
  }

  /// Pick video from camera with proper permission handling
  static Future<Uint8List?> pickVideoFromCamera(BuildContext context) async {
    if (kIsWeb) {
      // Web implementation would go here
      return null;
    }

    try {
      Log.i('Requesting camera permission for video recording', 'FIXED_MEDIA');
      
      // Request camera permission
      final hasPermission = await _requestCameraPermission(context);
      if (!hasPermission) {
        Log.w('Camera permission denied', 'FIXED_MEDIA');
        _showPermissionDeniedDialog(context, 'Camera', 'camera access is needed to record videos');
        return null;
      }

      Log.i('Camera permission granted, opening camera for video', 'FIXED_MEDIA');
      
      // Pick video from camera
      final XFile? video = await _picker.pickVideo(
        source: ImageSource.camera,
        maxDuration: const Duration(minutes: 5),
      );

      if (video != null) {
        final bytes = await video.readAsBytes();
        Log.i('Video recorded successfully: ${bytes.length} bytes', 'FIXED_MEDIA');
        return bytes;
      } else {
        Log.i('No video recorded (user cancelled)', 'FIXED_MEDIA');
        return null;
      }
    } catch (e) {
      Log.e('Error recording video from camera', 'FIXED_MEDIA', e);
      _showErrorDialog(context, 'Camera Error', 'Failed to record video: $e');
      return null;
    }
  }

  /// Pick video from gallery with proper permission handling
  static Future<Uint8List?> pickVideoFromGallery(BuildContext context) async {
    if (kIsWeb) {
      // Web implementation would go here
      return null;
    }

    try {
      Log.i('Requesting photos permission for video gallery access', 'FIXED_MEDIA');
      
      // Request photos permission
      final hasPermission = await _requestPhotosPermission(context);
      if (!hasPermission) {
        Log.w('Photos permission denied', 'FIXED_MEDIA');
        _showPermissionDeniedDialog(context, 'Photos', 'photo library access is needed to select videos');
        return null;
      }

      Log.i('Photos permission granted, opening gallery for video', 'FIXED_MEDIA');
      
      // Pick video from gallery
      final XFile? video = await _picker.pickVideo(
        source: ImageSource.gallery,
        maxDuration: const Duration(minutes: 10),
      );

      if (video != null) {
        final bytes = await video.readAsBytes();
        Log.i('Video selected successfully: ${bytes.length} bytes', 'FIXED_MEDIA');
        return bytes;
      } else {
        Log.i('No video selected (user cancelled)', 'FIXED_MEDIA');
        return null;
      }
    } catch (e) {
      Log.e('Error selecting video from gallery', 'FIXED_MEDIA', e);
      _showErrorDialog(context, 'Gallery Error', 'Failed to select video: $e');
      return null;
    }
  }

  /// Request camera permission with proper handling
  static Future<bool> _requestCameraPermission(BuildContext context) async {
    try {
      Log.i('Checking camera permission status', 'FIXED_MEDIA');
      
      final status = await Permission.camera.status;
      Log.i('Camera permission status: $status', 'FIXED_MEDIA');
      
      if (status.isGranted) {
        Log.i('Camera permission already granted', 'FIXED_MEDIA');
        return true;
      }
      
      if (status.isPermanentlyDenied) {
        Log.w('Camera permission permanently denied', 'FIXED_MEDIA');
        _showSettingsDialog(context, 'Camera Permission', 
          'Camera access is needed to take photos and videos. Please enable it in device settings.');
        return false;
      }
      
      if (status.isRestricted) {
        Log.w('Camera permission restricted', 'FIXED_MEDIA');
        _showErrorDialog(context, 'Camera Restricted', 
          'Camera access is restricted by parental controls or device policies.');
        return false;
      }
      
      Log.i('Requesting camera permission', 'FIXED_MEDIA');
      final result = await Permission.camera.request();
      Log.i('Camera permission request result: $result', 'FIXED_MEDIA');
      
      return result.isGranted;
    } catch (e) {
      Log.e('Error requesting camera permission', 'FIXED_MEDIA', e);
      return false;
    }
  }

  /// Request photos permission with proper handling
  static Future<bool> _requestPhotosPermission(BuildContext context) async {
    try {
      Log.i('Checking photos permission status', 'FIXED_MEDIA');
      
      final status = await Permission.photos.status;
      Log.i('Photos permission status: $status', 'FIXED_MEDIA');
      
      if (status.isGranted || status.isLimited) {
        Log.i('Photos permission already granted/limited', 'FIXED_MEDIA');
        return true;
      }
      
      if (status.isPermanentlyDenied) {
        Log.w('Photos permission permanently denied', 'FIXED_MEDIA');
        _showSettingsDialog(context, 'Photos Permission', 
          'Photo library access is needed to select images and videos. Please enable it in device settings.');
        return false;
      }
      
      if (status.isRestricted) {
        Log.w('Photos permission restricted', 'FIXED_MEDIA');
        _showErrorDialog(context, 'Photos Restricted', 
          'Photo library access is restricted by parental controls or device policies.');
        return false;
      }
      
      Log.i('Requesting photos permission', 'FIXED_MEDIA');
      final result = await Permission.photos.request();
      Log.i('Photos permission request result: $result', 'FIXED_MEDIA');
      
      return result.isGranted || result.isLimited;
    } catch (e) {
      Log.e('Error requesting photos permission', 'FIXED_MEDIA', e);
      return false;
    }
  }

  /// Show permission denied dialog
  static void _showPermissionDeniedDialog(BuildContext context, String permission, String reason) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('$permission Permission Required'),
          content: Text('$permission $reason. Please grant permission to continue.'),
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

  /// Show settings dialog
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

  /// Show error dialog
  static void _showErrorDialog(BuildContext context, String title, String message) {
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
