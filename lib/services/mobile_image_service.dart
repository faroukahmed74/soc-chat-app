import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:url_launcher/url_launcher.dart';

import 'logger_service.dart';
import 'production_permission_service.dart';

class MobileImageService {
  static final ImagePicker _picker = ImagePicker();

  // Pick image from camera
  static Future<XFile?> pickImageFromCamera() async {
    if (kIsWeb) return null;
    
    try {
      // Note: This method now requires BuildContext for proper permission handling
      // Use SimplePermissionService.requestCameraPermission(context) before calling this method
      final status = await Permission.camera.status;
      if (!status.isGranted) {
        Log.w('Camera permission not granted. Use SimplePermissionService.requestCameraPermission(context) first.', 'MOBILE_IMAGE');
        return null;
      }
      
      final XFile? image = await _picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 85,
      );
      
      return image;
    } catch (e) {
      Log.e('Error picking image from camera', 'MOBILE_IMAGE', e);
      return null;
    }
  }

  // Pick image from gallery
  static Future<XFile?> pickImageFromGallery() async {
    if (kIsWeb) return null;
    
    try {
      // Note: This method now requires BuildContext for proper permission handling
      // Use SimplePermissionService.requestPhotosPermission(context) before calling this method
      final status = await Permission.photos.status;
      if (!status.isGranted && !status.isLimited) {
        Log.w('Photos permission not granted. Use SimplePermissionService.requestPhotosPermission(context) first.', 'MOBILE_IMAGE');
        return null;
      }
      
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 85,
      );
      
      return image;
    } catch (e) {
      Log.e('Error picking image from gallery', 'MOBILE_IMAGE', e);
      return null;
    }
  }

  // Pick multiple images from gallery
  static Future<List<XFile>> pickMultipleImagesFromGallery() async {
    if (kIsWeb) return [];
    
    try {
      final status = await Permission.photos.status;
      
      if (status.isDenied) {
        final result = await Permission.photos.request();
        if (!result.isGranted) {
          Log.w('Photos permission denied', 'MOBILE_IMAGE');
          return [];
        }
      } else if (status.isPermanentlyDenied) {
        Log.w('Photos permission permanently denied', 'MOBILE_IMAGE');
        await _openAppSettings();
        return [];
      }
      
      final List<XFile> images = await _picker.pickMultiImage(
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 85,
      );
      
      return images;
    } catch (e) {
      Log.e('Error picking multiple images', 'MOBILE_IMAGE', e);
      return [];
    }
  }

  // Pick document
  static Future<XFile?> pickDocument() async {
    if (kIsWeb) return null;
    
    try {
      // Use pickMedia for better iOS compatibility
      final XFile? document = await _picker.pickMedia();
      if (document != null) {
        Log.i('Document selected: ${document.name}', 'MOBILE_IMAGE');
      }
      return document;
    } catch (e) {
      Log.e('Error picking document', 'MOBILE_IMAGE', e);
      return null;
    }
  }

  // Pick video from camera
  static Future<XFile?> pickVideoFromCamera() async {
    if (kIsWeb) return null;
    
    try {
      // For iOS, use the iOS-specific permission service
      if (defaultTargetPlatform == TargetPlatform.iOS) {
        // We need a BuildContext for iOS permission dialogs
        // This will be handled by the calling screen
        final status = await Permission.camera.status;
        if (!status.isGranted) {
          Log.w('Camera permission not granted on iOS. Use IOSPermissionService.requestCameraPermission() first.', 'MOBILE_IMAGE');
          return null;
        }
      } else {
        // Android permission handling
        final status = await Permission.camera.status;
        
        if (status.isDenied) {
          final result = await Permission.camera.request();
          if (!result.isGranted) {
            Log.w('Camera permission denied', 'MOBILE_IMAGE');
            return null;
          }
        } else if (status.isPermanentlyDenied) {
          Log.w('Camera permission permanently denied', 'MOBILE_IMAGE');
          await _openAppSettings();
          return null;
        }
      }
      
      final XFile? video = await _picker.pickVideo(
        source: ImageSource.camera,
        maxDuration: const Duration(minutes: 5), // Limit to 5 minutes
      );
      
      return video;
    } catch (e) {
      Log.e('Error picking video from camera', 'MOBILE_IMAGE', e);
      return null;
    }
  }

  // Pick video from gallery
  static Future<XFile?> pickVideoFromGallery() async {
    if (kIsWeb) return null;
    
    try {
      // For iOS, use the iOS-specific permission service
      if (defaultTargetPlatform == TargetPlatform.iOS) {
        // We need a BuildContext for iOS permission dialogs
        // This will be handled by the calling screen
        final status = await Permission.photos.status;
        if (!status.isGranted && !status.isLimited) {
          Log.w('Photos permission not granted on iOS. Use IOSPermissionService.requestPhotosPermission() first.', 'MOBILE_IMAGE');
          return null;
        }
      } else {
        // Android permission handling
        final status = await Permission.photos.status;
        
        if (status.isDenied) {
          final result = await Permission.photos.request();
          if (!result.isGranted) {
            Log.w('Photos permission denied', 'MOBILE_IMAGE');
            return null;
          }
        } else if (status.isPermanentlyDenied) {
          Log.w('Photos permission permanently denied', 'MOBILE_IMAGE');
          await _openAppSettings();
          return null;
        }
      }
      
      final XFile? video = await _picker.pickVideo(
        source: ImageSource.gallery,
        maxDuration: const Duration(minutes: 10), // Limit to 10 minutes
      );
      
      return video;
    } catch (e) {
      Log.e('Error picking video from gallery', 'MOBILE_IMAGE', e);
      return null;
    }
  }

  // Check camera permission
  static Future<bool> checkCameraPermission() async {
    if (kIsWeb) return true;
    
    try {
      final status = await Permission.camera.status;
      return status.isGranted;
    } catch (e) {
      Log.e('Error checking camera permission', 'MOBILE_IMAGE', e);
      return false;
    }
  }

  // Check photos permission
  static Future<bool> checkPhotosPermission() async {
    if (kIsWeb) return true;
    
    try {
      final status = await Permission.photos.status;
      return status.isGranted || status.isLimited;
    } catch (e) {
      Log.e('Error checking photos permission', 'MOBILE_IMAGE', e);
      return false;
    }
  }

  // Request camera permission
  static Future<bool> requestCameraPermission() async {
    if (kIsWeb) return true;
    
    try {
      final status = await Permission.camera.status;
      
      if (status.isDenied) {
        final result = await Permission.camera.request();
        return result.isGranted;
      } else if (status.isPermanentlyDenied) {
        Log.w('Camera permission permanently denied', 'MOBILE_IMAGE');
        await _openAppSettings();
        return false;
      }
      
      return status.isGranted;
    } catch (e) {
      Log.e('Error requesting camera permission', 'MOBILE_IMAGE', e);
      return false;
    }
  }

  // Request photos permission
  static Future<bool> requestPhotosPermission() async {
    if (kIsWeb) return true;
    
    try {
      final status = await Permission.photos.status;
      
      if (status.isDenied) {
        final result = await Permission.photos.request();
        return result.isGranted || result.isLimited;
      } else if (status.isPermanentlyDenied) {
        Log.w('Photos permission permanently denied', 'MOBILE_IMAGE');
        await _openAppSettings();
        return false;
      }
      
      return status.isGranted || status.isLimited;
    } catch (e) {
      Log.e('Error requesting photos permission', 'MOBILE_IMAGE', e);
      return false;
    }
  }

  // Force refresh permissions by opening app settings
  static Future<bool> forceRefreshPermissions() async {
    if (kIsWeb) return false;
    
    try {
      Log.i('Force refreshing permissions...', 'MOBILE_IMAGE');
      
      // Open app settings using permission_handler
      await _openAppSettings();
      Log.i('App settings opened successfully', 'MOBILE_IMAGE');
      
      // Wait for user to potentially change settings
      await Future.delayed(const Duration(seconds: 3));
      
      // Check new permission status
      final cameraStatus = await Permission.camera.status;
      final photosStatus = await Permission.photos.status;
      
      Log.i('New camera status: $cameraStatus', 'MOBILE_IMAGE');
      Log.i('New photos status: $photosStatus', 'MOBILE_IMAGE');
      
      return cameraStatus.isGranted && (photosStatus.isGranted || photosStatus.isLimited);
    } catch (e) {
      Log.e('Error force refreshing permissions', 'MOBILE_IMAGE', e);
      return false;
    }
  }

  // Open iOS Settings for permanently denied permissions
  static Future<void> openIOSSettings() async {
    if (kIsWeb || !Platform.isIOS) return;
    
    try {
      Log.i('Opening iOS Settings for permission reset...', 'MOBILE_IMAGE');
      
      // Try to open app settings using permission_handler first
      try {
        await _openAppSettings();
        Log.i('iOS Settings opened successfully using permission_handler', 'MOBILE_IMAGE');
      } catch (e) {
        Log.w('permission_handler failed, trying alternative method: $e', 'MOBILE_IMAGE');
        
        // Fallback: try to open iOS Settings app directly
        final url = 'App-Prefs:Privacy&path=CAMERA';
        if (await canLaunchUrl(Uri.parse(url))) {
          await launchUrl(Uri.parse(url));
          Log.i('iOS Settings opened using URL launcher', 'MOBILE_IMAGE');
        } else {
          // Final fallback: show instructions
          Log.w('Could not open iOS Settings automatically', 'MOBILE_IMAGE');
          Log.i('Please manually go to Settings > Privacy & Security > Camera', 'MOBILE_IMAGE');
        }
      }
      
      Log.i('User can now reset permissions in iOS Settings', 'MOBILE_IMAGE');
      Log.i('After changing permissions, return to app and try again', 'MOBILE_IMAGE');
    } catch (e) {
      Log.e('Error opening iOS Settings', 'MOBILE_IMAGE', e);
    }
  }

  // Open Android Settings for permanently denied permissions
  static Future<void> openAndroidSettings() async {
    if (kIsWeb || !Platform.isAndroid) return;
    
    try {
      Log.i('Opening Android Settings for permission reset...', 'MOBILE_IMAGE');
      
      // Try to open app settings using permission_handler first
      try {
        await _openAppSettings();
        Log.i('Android Settings opened successfully using permission_handler', 'MOBILE_IMAGE');
      } catch (e) {
        Log.w('permission_handler failed, trying alternative method: $e', 'MOBILE_IMAGE');
        
        // Fallback: try to open Android app settings directly
        final url = 'package:com.faroukahmed74.socchatapp';
        if (await canLaunchUrl(Uri.parse(url))) {
          await launchUrl(Uri.parse(url));
          Log.i('Android Settings opened using URL launcher', 'MOBILE_IMAGE');
        } else {
          // Final fallback: show instructions
          Log.w('Could not open Android Settings automatically', 'MOBILE_IMAGE');
          Log.i('Please manually go to Settings > Apps > Soc Chat App > Permissions', 'MOBILE_IMAGE');
        }
      }
      
      Log.i('User can now reset permissions in Android Settings', 'MOBILE_IMAGE');
      Log.i('After changing permissions, return to app and try again', 'MOBILE_IMAGE');
    } catch (e) {
      Log.e('Error opening Android Settings', 'MOBILE_IMAGE', e);
    }
  }

  // Check if permissions need iOS Settings reset
  static Future<bool> needsIOSSettingsReset() async {
    if (kIsWeb || !Platform.isIOS) return false;
    
    try {
      final cameraStatus = await Permission.camera.status;
      final photosStatus = await Permission.photos.status;
      final microphoneStatus = await Permission.microphone.status;
      
      final needsReset = cameraStatus == PermissionStatus.permanentlyDenied ||
                        photosStatus == PermissionStatus.permanentlyDenied ||
                        microphoneStatus == PermissionStatus.permanentlyDenied;
      
      Log.i('iOS permissions need Settings reset: $needsReset', 'MOBILE_IMAGE');
      Log.i('Camera: $cameraStatus, Photos: $photosStatus, Microphone: $microphoneStatus', 'MOBILE_IMAGE');
      
      return needsReset;
    } catch (e) {
      Log.e('Error checking iOS Settings reset need', 'MOBILE_IMAGE', e);
      return false;
    }
  }

  // Check if permissions need Android Settings reset
  static Future<bool> needsAndroidSettingsReset() async {
    if (kIsWeb || !Platform.isAndroid) return false;
    
    try {
      final status = await Permission.camera.status;
      final photosStatus = await Permission.photos.status;
      final microphoneStatus = await Permission.microphone.status;
      
      final needsReset = status == PermissionStatus.permanentlyDenied ||
                        photosStatus == PermissionStatus.permanentlyDenied ||
                        microphoneStatus == PermissionStatus.permanentlyDenied;
      
      Log.i('Android permissions need Settings reset: $needsReset', 'MOBILE_IMAGE');
      Log.i('Camera: $status, Photos: $photosStatus, Microphone: $microphoneStatus', 'MOBILE_IMAGE');
      
      return needsReset;
    } catch (e) {
      Log.e('Error checking Android Settings reset need', 'MOBILE_IMAGE', e);
      return false;
    }
  }

  // Get overall permission status
  static Future<Map<String, dynamic>> getOverallPermissionStatus() async {
    if (kIsWeb) {
      return {
        'camera': 'granted',
        'photos': 'granted',
        'microphone': 'granted',
        'overallWorking': true,
      };
    }
    
    try {
      final cameraStatus = await Permission.camera.status;
      final photosStatus = await Permission.photos.status;
      final microphoneStatus = await Permission.microphone.status;
      
      final overallWorking = cameraStatus.isGranted && 
                           (photosStatus.isGranted || photosStatus.isLimited) && 
                           microphoneStatus.isGranted;
      
      return {
        'camera': _getPermissionStatusString(cameraStatus),
        'photos': _getPermissionStatusString(photosStatus),
        'microphone': _getPermissionStatusString(microphoneStatus),
        'overallWorking': overallWorking,
      };
    } catch (e) {
      Log.e('Error getting overall permission status', 'MOBILE_IMAGE', e);
      return {
        'camera': 'error',
        'photos': 'error',
        'microphone': 'error',
        'overallWorking': false,
      };
    }
  }

  // Get detailed permission status (for compatibility)
  static Future<Map<String, dynamic>> getDetailedPermissionStatus() async {
    if (kIsWeb) {
      return {
        'camera': {'status': 'granted', 'working': true},
        'photos': {'status': 'granted', 'working': true},
        'microphone': {'status': 'granted', 'working': true},
        'overallWorking': true,
      };
    }
    
    try {
      final cameraStatus = await Permission.camera.status;
      final photosStatus = await Permission.photos.status;
      final microphoneStatus = await Permission.microphone.status;
      
      final cameraWorking = cameraStatus.isGranted;
      final photosWorking = photosStatus.isGranted || photosStatus.isLimited;
      final microphoneWorking = microphoneStatus.isGranted;
      
      return {
        'camera': {
          'status': _getPermissionStatusString(cameraStatus),
          'working': cameraWorking,
        },
        'photos': {
          'status': _getPermissionStatusString(photosStatus),
          'working': photosWorking,
        },
        'microphone': {
          'status': _getPermissionStatusString(microphoneStatus),
          'working': microphoneWorking,
        },
        'overallWorking': cameraWorking && photosWorking && microphoneWorking,
      };
    } catch (e) {
      Log.e('Error getting detailed permission status', 'MOBILE_IMAGE', e);
      return {
        'camera': {'status': 'error', 'working': false},
        'photos': {'status': 'error', 'working': false},
        'microphone': {'status': 'error', 'working': false},
        'overallWorking': false,
      };
    }
  }

  // Open app settings (for compatibility) - FIXED: No more recursive call
  static Future<void> openAppSettings() async {
    if (kIsWeb) return;
    await _openAppSettings();
  }

  // Private method to actually open app settings
  static Future<void> _openAppSettings() async {
    if (kIsWeb) return;
    
    try {
      Log.i('Opening app settings...', 'MOBILE_IMAGE');
      // Use the top-level openAppSettings from permission_handler package
      await openAppSettings();
      Log.i('App settings opened successfully', 'MOBILE_IMAGE');
    } catch (e) {
      Log.e('Error opening app settings', 'MOBILE_IMAGE', e);
    }
  }

  // Helper method to convert PermissionStatus to string
  static String _getPermissionStatusString(PermissionStatus status) {
    if (status.isGranted) return 'granted';
    if (status.isLimited) return 'limited';
    if (status.isDenied) return 'denied';
    if (status.isPermanentlyDenied) return 'permanently_denied';
    if (status.isRestricted) return 'restricted';
    return 'unknown';
  }
  

} 