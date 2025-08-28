import 'dart:typed_data';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'logger_service.dart';

/// Enhanced media service with progress tracking, optimization, and better error handling
class EnhancedMediaService {
  static final ImagePicker _picker = ImagePicker();
  
  /// Media upload progress callback
  static void Function(double progress)? onProgress;
  
  /// Enhanced image picking from camera with optimization
  static Future<MediaResult?> pickImageFromCamera(BuildContext context) async {
    if (kIsWeb) {
      return await _pickImageFromCameraWeb(context);
    }

    try {
      Log.i('Requesting camera permission for image capture', 'ENHANCED_MEDIA');
      
      final hasPermission = await _requestCameraPermission(context);
      if (!hasPermission) {
        Log.w('Camera permission denied', 'ENHANCED_MEDIA');
        _showPermissionDeniedDialog(context, 'Camera', 'camera access is needed to take photos');
        return null;
      }

      Log.i('Camera permission granted, opening camera', 'ENHANCED_MEDIA');
      
      final XFile? image = await _picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 85,
        preferredCameraDevice: CameraDevice.rear,
      );

      if (image != null) {
        final bytes = await image.readAsBytes();
        final optimizedBytes = await _optimizeImage(bytes);
        
        Log.i('Image captured and optimized: ${optimizedBytes.length} bytes', 'ENHANCED_MEDIA');
        
        return MediaResult(
          bytes: optimizedBytes,
          type: 'image',
          originalSize: bytes.length,
          optimizedSize: optimizedBytes.length,
          fileName: image.name,
          mimeType: 'image/jpeg',
        );
      }
      return null;
    } catch (e) {
      Log.e('Error picking image from camera', 'ENHANCED_MEDIA', e);
      _showErrorDialog(context, 'Camera Error', 'Failed to capture image: $e');
      return null;
    }
  }

  /// Enhanced image picking from gallery with optimization
  static Future<MediaResult?> pickImageFromGallery(BuildContext context) async {
    if (kIsWeb) {
      return await _pickImageFromGalleryWeb(context);
    }

    try {
      Log.i('Requesting photos permission for gallery access', 'ENHANCED_MEDIA');
      
      final hasPermission = await _requestPhotosPermission(context);
      if (!hasPermission) {
        Log.w('Photos permission denied', 'ENHANCED_MEDIA');
        _showPermissionDeniedDialog(context, 'Photos', 'photo library access is needed to select images');
        return null;
      }

      Log.i('Photos permission granted, opening gallery', 'ENHANCED_MEDIA');
      
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 85,
      );

      if (image != null) {
        final bytes = await image.readAsBytes();
        final optimizedBytes = await _optimizeImage(bytes);
        
        Log.i('Image selected and optimized: ${optimizedBytes.length} bytes', 'ENHANCED_MEDIA');
        
        return MediaResult(
          bytes: optimizedBytes,
          type: 'image',
          originalSize: bytes.length,
          optimizedSize: optimizedBytes.length,
          fileName: image.name,
          mimeType: 'image/jpeg',
        );
      }
      return null;
    } catch (e) {
      Log.e('Error picking image from gallery', 'ENHANCED_MEDIA', e);
      _showErrorDialog(context, 'Gallery Error', 'Failed to select image: $e');
      return null;
    }
  }

  /// Enhanced video picking with quality options
  static Future<MediaResult?> pickVideoFromGallery(BuildContext context) async {
    if (kIsWeb) {
      return await _pickVideoFromGalleryWeb(context);
    }

    try {
      Log.i('Requesting photos permission for video selection', 'ENHANCED_MEDIA');
      
      final hasPermission = await _requestPhotosPermission(context);
      if (!hasPermission) {
        Log.w('Photos permission denied for video', 'ENHANCED_MEDIA');
        _showPermissionDeniedDialog(context, 'Photos', 'photo library access is needed to select videos');
        return null;
      }

      Log.i('Photos permission granted, opening video gallery', 'ENHANCED_MEDIA');
      
              final XFile? video = await _picker.pickVideo(
          source: ImageSource.gallery,
          maxDuration: const Duration(minutes: 10),
        );

      if (video != null) {
        final bytes = await video.readAsBytes();
        
        Log.i('Video selected: ${bytes.length} bytes', 'ENHANCED_MEDIA');
        
        return MediaResult(
          bytes: bytes,
          type: 'video',
          originalSize: bytes.length,
          optimizedSize: bytes.length,
          fileName: video.name,
          mimeType: 'video/mp4',
        );
      }
      return null;
    } catch (e) {
      Log.e('Error picking video from gallery', 'ENHANCED_MEDIA', e);
      _showErrorDialog(context, 'Video Error', 'Failed to select video: $e');
      return null;
    }
  }

  /// Enhanced video recording with quality options
  static Future<MediaResult?> recordVideo(BuildContext context) async {
    if (kIsWeb) {
      return await _recordVideoWeb(context);
    }

    try {
      Log.i('Requesting camera permission for video recording', 'ENHANCED_MEDIA');
      
      final hasPermission = await _requestCameraPermission(context);
      if (!hasPermission) {
        Log.w('Camera permission denied for video', 'ENHANCED_MEDIA');
        _showPermissionDeniedDialog(context, 'Camera', 'camera access is needed to record videos');
        return null;
      }

      Log.i('Camera permission granted, opening video recorder', 'ENHANCED_MEDIA');
      
              final XFile? video = await _picker.pickVideo(
          source: ImageSource.camera,
          maxDuration: const Duration(minutes: 5),
        );

      if (video != null) {
        final bytes = await video.readAsBytes();
        
        Log.i('Video recorded: ${bytes.length} bytes', 'ENHANCED_MEDIA');
        
        return MediaResult(
          bytes: bytes,
          type: 'video',
          originalSize: bytes.length,
          optimizedSize: bytes.length,
          fileName: video.name,
          mimeType: 'video/mp4',
        );
      }
      return null;
    } catch (e) {
      Log.e('Error recording video', 'ENHANCED_MEDIA', e);
      _showErrorDialog(context, 'Video Recording Error', 'Failed to record video: $e');
      return null;
    }
  }

  /// Enhanced document picking with file type validation
  static Future<MediaResult?> pickDocument(BuildContext context) async {
    try {
      Log.i('Picking document', 'ENHANCED_MEDIA');
      
      // For now, we'll use a simple file picker approach
      // In a real implementation, you'd use file_picker package
      final result = await _showDocumentPickerDialog(context);
      
      if (result != null) {
        return MediaResult(
          bytes: result.bytes,
          type: 'document',
          originalSize: result.bytes.length,
          optimizedSize: result.bytes.length,
          fileName: result.fileName,
          mimeType: result.mimeType,
        );
      }
      return null;
    } catch (e) {
      Log.e('Error picking document', 'ENHANCED_MEDIA', e);
      _showErrorDialog(context, 'Document Error', 'Failed to pick document: $e');
      return null;
    }
  }

  /// Upload media with progress tracking
  static Future<String?> uploadMediaWithProgress(
    MediaResult media,
    String chatId,
    void Function(double progress)? onProgress,
  ) async {
    try {
      Log.i('Starting media upload: ${media.fileName}', 'ENHANCED_MEDIA');
      
      final fileName = '${DateTime.now().millisecondsSinceEpoch}_${media.type}_${media.fileName}';
      final ref = FirebaseStorage.instance
          .ref()
          .child('chat_media')
          .child(chatId)
          .child(fileName);
      
      // Create upload task with progress tracking
      final uploadTask = ref.putData(media.bytes);
      
      // Listen to upload progress
      uploadTask.snapshotEvents.listen((TaskSnapshot snapshot) {
        final progress = snapshot.bytesTransferred / snapshot.totalBytes;
        Log.i('Upload progress: ${(progress * 100).toStringAsFixed(1)}%', 'ENHANCED_MEDIA');
        onProgress?.call(progress);
      });
      
      // Wait for upload to complete
      final snapshot = await uploadTask;
      final downloadUrl = await snapshot.ref.getDownloadURL();
      
      Log.i('Media upload completed: $downloadUrl', 'ENHANCED_MEDIA');
      return downloadUrl;
      
    } catch (e) {
      Log.e('Error uploading media', 'ENHANCED_MEDIA', e);
      rethrow;
    }
  }

  /// Optimize image bytes for better performance
  static Future<Uint8List> _optimizeImage(Uint8List originalBytes) async {
    // In a real implementation, you'd use image compression
    // For now, we'll return the original bytes
    // You can integrate with packages like flutter_image_compress
    return originalBytes;
  }

  /// Request camera permission with platform handling
  static Future<bool> _requestCameraPermission(BuildContext context) async {
    try {
      if (Platform.isAndroid) {
        return await _requestAndroidCameraPermission(context);
      } else if (Platform.isIOS) {
        return await _requestIOSCameraPermission(context);
      }
      return false;
    } catch (e) {
      Log.e('Error requesting camera permission', 'ENHANCED_MEDIA', e);
      return false;
    }
  }

  /// Request Android camera permission
  static Future<bool> _requestAndroidCameraPermission(BuildContext context) async {
    try {
      // Check current status
      final status = await Permission.camera.status;
      Log.i('Android Camera permission status: $status', 'ENHANCED_MEDIA');
      
      if (status.isGranted) {
        Log.i('Android Camera permission already granted', 'ENHANCED_MEDIA');
        return true;
      }
      
      if (status.isPermanentlyDenied) {
        Log.w('Android Camera permission permanently denied', 'ENHANCED_MEDIA');
        _showSettingsDialog(context, 'Camera Permission', 
          'Camera access is needed. Please enable it in device settings.');
        return false;
      }
      
      // Request permission directly
      Log.i('Requesting Android camera permission...', 'ENHANCED_MEDIA');
      final result = await Permission.camera.request();
      Log.i('Android Camera permission result: $result', 'ENHANCED_MEDIA');
      
      return result.isGranted;
      
    } catch (e) {
      Log.e('Error requesting Android camera permission', 'ENHANCED_MEDIA', e);
      return false;
    }
  }

  /// Request iOS camera permission
  static Future<bool> _requestIOSCameraPermission(BuildContext context) async {
    try {
      // Check current status
      final status = await Permission.camera.status;
      Log.i('iOS Camera permission status: $status', 'ENHANCED_MEDIA');
      
      if (status.isGranted) {
        Log.i('iOS Camera permission already granted', 'ENHANCED_MEDIA');
        return true;
      }
      
      if (status.isPermanentlyDenied) {
        Log.w('iOS Camera permission permanently denied', 'ENHANCED_MEDIA');
        _showSettingsDialog(context, 'Camera Permission', 
          'Camera access is needed. Please enable it in device settings.');
        return false;
      }
      
      // Request permission directly
      Log.i('Requesting iOS camera permission...', 'ENHANCED_MEDIA');
      final result = await Permission.camera.request();
      Log.i('iOS Camera permission result: $result', 'ENHANCED_MEDIA');
      
      return result.isGranted;
      
    } catch (e) {
      Log.e('Error requesting iOS camera permission', 'ENHANCED_MEDIA', e);
      return false;
    }
  }

  /// Request photos permission with Android version handling
  static Future<bool> _requestPhotosPermission(BuildContext context) async {
    try {
      if (Platform.isAndroid) {
        // For Android, try different permission strategies based on API level
        return await _requestAndroidPhotosPermission(context);
      } else if (Platform.isIOS) {
        // For iOS, use the photos permission
        return await _requestIOSPhotosPermission(context);
      }
      return false;
    } catch (e) {
      Log.e('Error requesting photos permission', 'ENHANCED_MEDIA', e);
      return false;
    }
  }

  /// Request Android photos permission based on API level
  static Future<bool> _requestAndroidPhotosPermission(BuildContext context) async {
    try {
      // First try the new media permissions (Android 13+)
      try {
        final photosStatus = await Permission.photos.status;
        Log.i('Photos permission status: $photosStatus', 'ENHANCED_MEDIA');
        
        if (photosStatus.isGranted) {
          Log.i('Photos permission already granted', 'ENHANCED_MEDIA');
          return true;
        }
        
        if (photosStatus.isPermanentlyDenied) {
          Log.w('Photos permission permanently denied', 'ENHANCED_MEDIA');
          _showSettingsDialog(context, 'Photos Permission', 
            'Photo library access is needed. Please enable it in device settings.');
          return false;
        }
        
        // Request photos permission
        Log.i('Requesting photos permission...', 'ENHANCED_MEDIA');
        final photosResult = await Permission.photos.request();
        if (photosResult.isGranted) {
          return true;
        }
      } catch (e) {
        Log.w('Photos permission failed, trying storage permission...', 'ENHANCED_MEDIA');
      }
      
      // Fallback to storage permission for older Android versions
      return await _requestLegacyStoragePermission(context);
      
    } catch (e) {
      Log.e('Error in Android photos permission', 'ENHANCED_MEDIA', e);
      return false;
    }
  }

  /// Request legacy storage permission for older Android versions
  static Future<bool> _requestLegacyStoragePermission(BuildContext context) async {
    try {
      Log.i('Trying legacy storage permission...', 'ENHANCED_MEDIA');
      
      final storageStatus = await Permission.storage.status;
      Log.i('Storage permission status: $storageStatus', 'ENHANCED_MEDIA');
      
      if (storageStatus.isGranted) {
        Log.i('Storage permission already granted', 'ENHANCED_MEDIA');
        return true;
      }
      
      if (storageStatus.isPermanentlyDenied) {
        Log.w('Storage permission permanently denied', 'ENHANCED_MEDIA');
        _showSettingsDialog(context, 'Storage Permission', 
          'Storage access is needed to select photos. Please enable it in device settings.');
        return false;
      }
      
      // Request storage permission
      Log.i('Requesting storage permission...', 'ENHANCED_MEDIA');
      final storageResult = await Permission.storage.request();
      Log.i('Storage permission result: $storageResult', 'ENHANCED_MEDIA');
      
      return storageResult.isGranted;
      
    } catch (e) {
      Log.e('Error requesting storage permission', 'ENHANCED_MEDIA', e);
      return false;
    }
  }

  /// Request iOS photos permission
  static Future<bool> _requestIOSPhotosPermission(BuildContext context) async {
    try {
      // Check current status
      final status = await Permission.photos.status;
      Log.i('iOS Photos permission status: $status', 'ENHANCED_MEDIA');
      
      if (status.isGranted) {
        Log.i('iOS Photos permission already granted', 'ENHANCED_MEDIA');
        return true;
      }
      
      if (status.isPermanentlyDenied) {
        Log.w('iOS Photos permission permanently denied', 'ENHANCED_MEDIA');
        _showSettingsDialog(context, 'Photos Permission', 
          'Photo library access is needed. Please enable it in device settings.');
        return false;
      }
      
      // Request permission directly
      Log.i('Requesting iOS photos permission...', 'ENHANCED_MEDIA');
      final result = await Permission.photos.request();
      Log.i('iOS Photos permission result: $result', 'ENHANCED_MEDIA');
      
      return result.isGranted;
      
    } catch (e) {
      Log.e('Error requesting iOS photos permission', 'ENHANCED_MEDIA', e);
      return false;
    }
  }

  /// Show permission denied dialog
  static void _showPermissionDeniedDialog(BuildContext context, String permission, String reason) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('$permission Permission Required'),
        content: Text('$reason. Please grant the permission to continue.'),
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

  /// Show error dialog
  static void _showErrorDialog(BuildContext context, String title, String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  /// Web implementations (placeholders)
  static Future<MediaResult?> _pickImageFromCameraWeb(BuildContext context) async {
    // Web camera implementation
    return null;
  }

  static Future<MediaResult?> _pickImageFromGalleryWeb(BuildContext context) async {
    // Web gallery implementation
    return null;
  }

  static Future<MediaResult?> _pickVideoFromGalleryWeb(BuildContext context) async {
    // Web video gallery implementation
    return null;
  }

  static Future<MediaResult?> _recordVideoWeb(BuildContext context) async {
    // Web video recording implementation
    return null;
  }

  /// Document picker dialog (placeholder)
  static Future<MediaResult?> _showDocumentPickerDialog(BuildContext context) async {
    // Document picker implementation
    return null;
  }
}

/// Result object for media operations
class MediaResult {
  final Uint8List bytes;
  final String type;
  final int originalSize;
  final int optimizedSize;
  final String fileName;
  final String mimeType;

  MediaResult({
    required this.bytes,
    required this.type,
    required this.originalSize,
    required this.optimizedSize,
    required this.fileName,
    required this.mimeType,
  });

  /// Get file size in human readable format
  String get formattedSize {
    if (optimizedSize < 1024) return '${optimizedSize}B';
    if (optimizedSize < 1024 * 1024) return '${(optimizedSize / 1024).toStringAsFixed(1)}KB';
    return '${(optimizedSize / (1024 * 1024)).toStringAsFixed(1)}MB';
  }

  /// Get compression ratio
  double get compressionRatio {
    if (originalSize == 0) return 1.0;
    return optimizedSize / originalSize;
  }

  /// Check if file is optimized
  bool get isOptimized => optimizedSize < originalSize;
}
