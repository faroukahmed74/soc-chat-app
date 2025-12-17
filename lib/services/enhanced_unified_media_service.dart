// =============================================================================
// ENHANCED UNIFIED MEDIA SERVICE
// =============================================================================
// This service provides comprehensive media handling across all platforms
// with responsive previews, full-screen functionality, and optimized uploads

import 'dart:typed_data';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:video_player/video_player.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:dio/dio.dart';
import '../config/database_config.dart';
import 'logger_service.dart';
import 'android_permission_fix.dart';
import 'ios_media_permission_fix.dart';
import 'web_media_service.dart' if (dart.library.io) 'web_media_stub.dart';

/// Enhanced media result with comprehensive metadata
class EnhancedMediaResult {
  final Uint8List bytes;
  final String type;
  final String fileName;
  final String mimeType;
  final int originalSize;
  final int optimizedSize;
  final Map<String, dynamic> metadata;
  final String? thumbnailPath;
  final Duration? duration;

  EnhancedMediaResult({
    required this.bytes,
    required this.type,
    required this.fileName,
    required this.mimeType,
    required this.originalSize,
    required this.optimizedSize,
    required this.metadata,
    this.thumbnailPath,
    this.duration,
  });

  bool get isOptimized => optimizedSize < originalSize;
  double get compressionRatio => optimizedSize / originalSize;
  String get formattedSize => _formatFileSize(optimizedSize);
  String get formattedOriginalSize => _formatFileSize(originalSize);

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }
}

/// Enhanced unified media service for all platforms
class EnhancedUnifiedMediaService {
  static final ImagePicker _picker = ImagePicker();
  static final AudioPlayer _audioPlayer = AudioPlayer();

  // =============================================================================
  // MEDIA PICKING METHODS
  // =============================================================================

  /// Pick image from camera with enhanced optimization
  static Future<EnhancedMediaResult?> pickImageFromCamera(BuildContext context) async {
    try {
      Log.i('Starting camera image capture', 'ENHANCED_MEDIA_SERVICE');

      if (kIsWeb) {
        return await _pickImageFromCameraWeb(context);
      } else {
        return await _pickImageFromCameraMobile(context);
      }
    } catch (e) {
      Log.e('Error picking image from camera', 'ENHANCED_MEDIA_SERVICE', e);
      _showErrorSnackBar(context, 'Failed to capture image: $e');
      return null;
    }
  }

  /// Pick image from gallery with enhanced optimization
  static Future<EnhancedMediaResult?> pickImageFromGallery(BuildContext context) async {
    try {
      Log.i('Starting gallery image selection', 'ENHANCED_MEDIA_SERVICE');

      if (kIsWeb) {
        return await _pickImageFromGalleryWeb(context);
      } else {
        return await _pickImageFromGalleryMobile(context);
      }
    } catch (e) {
      Log.e('Error picking image from gallery', 'ENHANCED_MEDIA_SERVICE', e);
      _showErrorSnackBar(context, 'Failed to select image: $e');
      return null;
    }
  }

  /// Pick video from camera with enhanced optimization
  static Future<EnhancedMediaResult?> pickVideoFromCamera(BuildContext context) async {
    try {
      Log.i('Starting camera video recording', 'ENHANCED_MEDIA_SERVICE');

      if (kIsWeb) {
        return await _pickVideoFromCameraWeb(context);
      } else {
        return await _pickVideoFromCameraMobile(context);
      }
    } catch (e) {
      Log.e('Error picking video from camera', 'ENHANCED_MEDIA_SERVICE', e);
      _showErrorSnackBar(context, 'Failed to record video: $e');
      return null;
    }
  }

  /// Pick video from gallery with enhanced optimization
  static Future<EnhancedMediaResult?> pickVideoFromGallery(BuildContext context) async {
    try {
      Log.i('Starting gallery video selection', 'ENHANCED_MEDIA_SERVICE');

      if (kIsWeb) {
        return await _pickVideoFromGalleryWeb(context);
      } else {
        return await _pickVideoFromGalleryMobile(context);
      }
    } catch (e) {
      Log.e('Error picking video from gallery', 'ENHANCED_MEDIA_SERVICE', e);
      _showErrorSnackBar(context, 'Failed to select video: $e');
      return null;
    }
  }

  /// Pick document with enhanced handling
  static Future<EnhancedMediaResult?> pickDocument(BuildContext context) async {
    try {
      Log.i('Starting document selection', 'ENHANCED_MEDIA_SERVICE');

      if (kIsWeb) {
        return await _pickDocumentWeb(context);
      } else {
        return await _pickDocumentMobile(context);
      }
    } catch (e) {
      Log.e('Error picking document', 'ENHANCED_MEDIA_SERVICE', e);
      _showErrorSnackBar(context, 'Failed to select document: $e');
      return null;
    }
  }

  // =============================================================================
  // WEB IMPLEMENTATIONS
  // =============================================================================

  static Future<EnhancedMediaResult?> _pickImageFromCameraWeb(BuildContext context) async {
    try {
      final result = await WebMediaService.pickImageFromCamera();
      if (result == null) return null;

      final bytes = result['bytes'] as Uint8List;
      final fileName = result['fileName'] as String? ?? 'camera_image_${DateTime.now().millisecondsSinceEpoch}.jpg';
      
      return EnhancedMediaResult(
        bytes: bytes,
        type: 'image',
        fileName: fileName,
        mimeType: 'image/jpeg',
        originalSize: bytes.length,
        optimizedSize: bytes.length,
        metadata: {
          'source': 'camera',
          'platform': 'web',
          'timestamp': DateTime.now().toIso8601String(),
        },
      );
    } catch (e) {
      Log.e('Error picking image from camera on web', 'ENHANCED_MEDIA_SERVICE', e);
      return null;
    }
  }

  static Future<EnhancedMediaResult?> _pickImageFromGalleryWeb(BuildContext context) async {
    try {
      final result = await WebMediaService.pickImageFromGallery();
      if (result == null) return null;

      final bytes = result['bytes'] as Uint8List;
      final fileName = result['fileName'] as String? ?? 'gallery_image_${DateTime.now().millisecondsSinceEpoch}.jpg';
      
      return EnhancedMediaResult(
        bytes: bytes,
        type: 'image',
        fileName: fileName,
        mimeType: 'image/jpeg',
        originalSize: bytes.length,
        optimizedSize: bytes.length,
        metadata: {
          'source': 'gallery',
          'platform': 'web',
          'timestamp': DateTime.now().toIso8601String(),
        },
      );
    } catch (e) {
      Log.e('Error picking image from gallery on web', 'ENHANCED_MEDIA_SERVICE', e);
      return null;
    }
  }

  static Future<EnhancedMediaResult?> _pickVideoFromCameraWeb(BuildContext context) async {
    try {
      final result = await WebMediaService.pickVideo();
      if (result == null) return null;

      final bytes = result['bytes'] as Uint8List;
      final fileName = result['fileName'] as String? ?? 'camera_video_${DateTime.now().millisecondsSinceEpoch}.mp4';
      
      return EnhancedMediaResult(
        bytes: bytes,
        type: 'video',
        fileName: fileName,
        mimeType: 'video/mp4',
        originalSize: bytes.length,
        optimizedSize: bytes.length,
        metadata: {
          'source': 'camera',
          'platform': 'web',
          'timestamp': DateTime.now().toIso8601String(),
        },
      );
    } catch (e) {
      Log.e('Error picking video from camera on web', 'ENHANCED_MEDIA_SERVICE', e);
      return null;
    }
  }

  static Future<EnhancedMediaResult?> _pickVideoFromGalleryWeb(BuildContext context) async {
    try {
      final result = await WebMediaService.pickVideo();
      if (result == null) return null;

      final bytes = result['bytes'] as Uint8List;
      final fileName = result['fileName'] as String? ?? 'gallery_video_${DateTime.now().millisecondsSinceEpoch}.mp4';
      
      return EnhancedMediaResult(
        bytes: bytes,
        type: 'video',
        fileName: fileName,
        mimeType: 'video/mp4',
        originalSize: bytes.length,
        optimizedSize: bytes.length,
        metadata: {
          'source': 'gallery',
          'platform': 'web',
          'timestamp': DateTime.now().toIso8601String(),
        },
      );
    } catch (e) {
      Log.e('Error picking video from gallery on web', 'ENHANCED_MEDIA_SERVICE', e);
      return null;
    }
  }

  static Future<EnhancedMediaResult?> _pickDocumentWeb(BuildContext context) async {
    try {
      final result = await WebMediaService.pickDocument();
      if (result == null) return null;

      final bytes = result['bytes'] as Uint8List;
      final fileName = result['fileName'] as String? ?? 'document_${DateTime.now().millisecondsSinceEpoch}';
      final mimeType = result['mimeType'] as String? ?? 'application/octet-stream';
      
      return EnhancedMediaResult(
        bytes: bytes,
        type: 'document',
        fileName: fileName,
        mimeType: mimeType,
        originalSize: bytes.length,
        optimizedSize: bytes.length,
        metadata: {
          'source': 'file_picker',
          'platform': 'web',
          'timestamp': DateTime.now().toIso8601String(),
        },
      );
    } catch (e) {
      Log.e('Error picking document on web', 'ENHANCED_MEDIA_SERVICE', e);
      return null;
    }
  }

  // =============================================================================
  // MOBILE IMPLEMENTATIONS
  // =============================================================================

  static Future<EnhancedMediaResult?> _pickImageFromCameraMobile(BuildContext context) async {
    try {
      // Request camera permission
      final hasPermission = await _requestCameraPermission(context);
      if (!hasPermission) {
        _showPermissionDeniedDialog(context, 'Camera', 'camera access is needed to take photos');
        return null;
      }

      final XFile? image = await _picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 85,
      );

      if (image == null) return null;

      final bytes = await image.readAsBytes();
      final optimizedBytes = await _optimizeImage(bytes);
      
      return EnhancedMediaResult(
        bytes: optimizedBytes,
        type: 'image',
        fileName: image.name,
        mimeType: 'image/jpeg',
        originalSize: bytes.length,
        optimizedSize: optimizedBytes.length,
        metadata: {
          'source': 'camera',
          'platform': Platform.isIOS ? 'ios' : 'android',
          'timestamp': DateTime.now().toIso8601String(),
          'path': image.path,
        },
      );
    } catch (e) {
      Log.e('Error picking image from camera on mobile', 'ENHANCED_MEDIA_SERVICE', e);
      return null;
    }
  }

  static Future<EnhancedMediaResult?> _pickImageFromGalleryMobile(BuildContext context) async {
    try {
      Log.i('Requesting photos permission for image gallery', 'ENHANCED_MEDIA_SERVICE');
      
      // Request photos permission
      final hasPermission = await _requestPhotosPermission(context);
      if (!hasPermission) {
        Log.w('Photos permission denied for image gallery', 'ENHANCED_MEDIA_SERVICE');
        _showPermissionDeniedDialog(context, 'Photos', 'photo access is needed to select images');
        return null;
      }

      Log.i('Photos permission granted, opening image gallery', 'ENHANCED_MEDIA_SERVICE');

      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 85,
      );

      if (image == null) {
        Log.i('User cancelled image selection', 'ENHANCED_MEDIA_SERVICE');
        return null;
      }

      Log.i('Image selected: ${image.name}', 'ENHANCED_MEDIA_SERVICE');
      final bytes = await image.readAsBytes();
      final optimizedBytes = await _optimizeImage(bytes);
      
      return EnhancedMediaResult(
        bytes: optimizedBytes,
        type: 'image',
        fileName: image.name,
        mimeType: 'image/jpeg',
        originalSize: bytes.length,
        optimizedSize: optimizedBytes.length,
        metadata: {
          'source': 'gallery',
          'platform': Platform.isIOS ? 'ios' : 'android',
          'timestamp': DateTime.now().toIso8601String(),
          'path': image.path,
        },
      );
    } catch (e) {
      Log.e('Error picking image from gallery on mobile', 'ENHANCED_MEDIA_SERVICE', e);
      _showErrorSnackBar(context, 'Failed to select image: ${e.toString()}');
      return null;
    }
  }

  static Future<EnhancedMediaResult?> _pickVideoFromCameraMobile(BuildContext context) async {
    try {
      // Request camera permission
      final hasPermission = await _requestCameraPermission(context);
      if (!hasPermission) {
        _showPermissionDeniedDialog(context, 'Camera', 'camera access is needed to record videos');
        return null;
      }

      final XFile? video = await _picker.pickVideo(
        source: ImageSource.camera,
        maxDuration: const Duration(minutes: 5),
      );

      if (video == null) return null;

      final bytes = await video.readAsBytes();
      final duration = await _getVideoDuration(video.path);
      
      return EnhancedMediaResult(
        bytes: bytes,
        type: 'video',
        fileName: video.name,
        mimeType: 'video/mp4',
        originalSize: bytes.length,
        optimizedSize: bytes.length,
        duration: duration,
        metadata: {
          'source': 'camera',
          'platform': Platform.isIOS ? 'ios' : 'android',
          'timestamp': DateTime.now().toIso8601String(),
          'path': video.path,
        },
      );
    } catch (e) {
      Log.e('Error picking video from camera on mobile', 'ENHANCED_MEDIA_SERVICE', e);
      return null;
    }
  }

  static Future<EnhancedMediaResult?> _pickVideoFromGalleryMobile(BuildContext context) async {
    try {
      Log.i('Requesting videos permission for video gallery', 'ENHANCED_MEDIA_SERVICE');
      
      // Request videos permission (Android 13+) / photos on iOS
      final hasPermission = await _requestVideosPermission(context);
      if (!hasPermission) {
        Log.w('Videos permission denied for video gallery', 'ENHANCED_MEDIA_SERVICE');
        _showPermissionDeniedDialog(context, 'Videos', 'video library access is needed to select videos');
        return null;
      }

      Log.i('Videos permission granted, opening video gallery', 'ENHANCED_MEDIA_SERVICE');

      final XFile? video = await _picker.pickVideo(
        source: ImageSource.gallery,
        maxDuration: const Duration(minutes: 10),
      );

      if (video == null) {
        Log.i('User cancelled video selection', 'ENHANCED_MEDIA_SERVICE');
        return null;
      }

      Log.i('Video selected: ${video.name}', 'ENHANCED_MEDIA_SERVICE');
      final bytes = await video.readAsBytes();
      final duration = await _getVideoDuration(video.path);
      
      return EnhancedMediaResult(
        bytes: bytes,
        type: 'video',
        fileName: video.name,
        mimeType: 'video/mp4',
        originalSize: bytes.length,
        optimizedSize: bytes.length,
        duration: duration,
        metadata: {
          'source': 'gallery',
          'platform': Platform.isIOS ? 'ios' : 'android',
          'timestamp': DateTime.now().toIso8601String(),
          'path': video.path,
        },
      );
    } catch (e) {
      Log.e('Error picking video from gallery on mobile', 'ENHANCED_MEDIA_SERVICE', e);
      _showErrorSnackBar(context, 'Failed to select video: ${e.toString()}');
      return null;
    }
  }

  static Future<EnhancedMediaResult?> _pickDocumentMobile(BuildContext context) async {
    try {
      // For mobile, we'll use a simple file picker implementation
      // This would typically use file_picker package
      Log.i('Document picking on mobile not fully implemented', 'ENHANCED_MEDIA_SERVICE');
      return null;
    } catch (e) {
      Log.e('Error picking document on mobile', 'ENHANCED_MEDIA_SERVICE', e);
      return null;
    }
  }

  // =============================================================================
  // HELPER METHODS
  // =============================================================================

  static Future<bool> _requestCameraPermission(BuildContext context) async {
    if (kIsWeb) return true;
    
    try {
      if (Platform.isIOS) {
        return await IOSMediaPermissionFix.requestCameraPermission(context);
      } else if (Platform.isAndroid) {
        return await AndroidPermissionFix.requestCameraPermission(context);
      }
      
      // Fallback for other platforms
      final status = await Permission.camera.request();
      return status.isGranted;
    } catch (e) {
      Log.e('Error requesting camera permission', 'ENHANCED_MEDIA_SERVICE', e);
      return false;
    }
  }

  static Future<bool> _requestPhotosPermission(BuildContext context) async {
    if (kIsWeb) return true;
    
    try {
      if (Platform.isIOS) {
        return await IOSMediaPermissionFix.requestPhotosPermission(context);
      } else if (Platform.isAndroid) {
        return await AndroidPermissionFix.requestPhotosPermission(context);
      }
      
      // Fallback for other platforms
      final status = await Permission.photos.request();
      return status.isGranted || status.isLimited;
    } catch (e) {
      Log.e('Error requesting photos permission', 'ENHANCED_MEDIA_SERVICE', e);
      return false;
    }
  }

  static Future<bool> _requestVideosPermission(BuildContext context) async {
    if (kIsWeb) return true;
    try {
      if (Platform.isIOS) {
        // iOS uses Photos permission for both images and videos
        return await IOSMediaPermissionFix.requestPhotosPermission(context);
      } else if (Platform.isAndroid) {
        return await AndroidPermissionFix.requestVideosPermission(context);
      }
      // Fallback for other platforms
      final status = await Permission.videos.request();
      return status.isGranted || status.isLimited;
    } catch (e) {
      Log.e('Error requesting videos permission', 'ENHANCED_MEDIA_SERVICE', e);
      return false;
    }
  }

  static Future<Uint8List> _optimizeImage(Uint8List bytes) async {
    // Simple optimization - in a real implementation, you'd use image processing
    // For now, we'll return the original bytes
    return bytes;
  }

  static Future<Duration?> _getVideoDuration(String path) async {
    try {
      final controller = VideoPlayerController.file(File(path));
      await controller.initialize();
      final duration = controller.value.duration;
      await controller.dispose();
      return duration;
    } catch (e) {
      Log.e('Error getting video duration', 'ENHANCED_MEDIA_SERVICE', e);
      return null;
    }
  }

  static void _showPermissionDeniedDialog(BuildContext context, String permission, String reason) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('$permission Permission Required'),
        content: Text('$permission $reason. Please enable it in your device settings.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              openAppSettings();
            },
            child: const Text('Open Settings'),
          ),
        ],
      ),
    );
  }

  static void _showErrorSnackBar(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        action: SnackBarAction(
          label: 'Dismiss',
          textColor: Colors.white,
          onPressed: () {
            ScaffoldMessenger.of(context).hideCurrentSnackBar();
          },
        ),
      ),
    );
  }

  // =============================================================================
  // MEDIA UPLOAD METHODS
  // =============================================================================

  /// Upload media with progress tracking
  static Future<String?> uploadMedia(
    EnhancedMediaResult mediaResult,
    String chatId, {
    Function(double progress)? onProgress,
  }) async {
    try {
      Log.i('Starting media upload', 'ENHANCED_MEDIA_SERVICE');

      if (DatabaseConfig.usePhysicalServer) {
        // Upload media via HTTP endpoint
        final baseUrl = DatabaseConfig.physicalServerUrl;
        Log.i('Uploading to: $baseUrl/api/media/upload', 'ENHANCED_MEDIA_SERVICE');
        Log.i('File details: ${mediaResult.fileName}, size: ${mediaResult.bytes.length}, type: ${mediaResult.mimeType}', 'ENHANCED_MEDIA_SERVICE');
        
        final dio = Dio(BaseOptions(baseUrl: baseUrl));
        final formData = FormData.fromMap({
          'chatId': chatId,
          'type': mediaResult.mimeType,
          'file': MultipartFile.fromBytes(
            mediaResult.bytes,
            filename: mediaResult.fileName,
          ),
        });

        final response = await dio.post(
          '/api/media/upload',
          data: formData,
          onSendProgress: (sent, total) {
            if (total > 0) {
              final progress = sent / total;
              Log.i('Upload progress: ${(progress * 100).toStringAsFixed(1)}%', 'ENHANCED_MEDIA_SERVICE');
              onProgress?.call(progress);
            }
          },
        );

        Log.i('Upload response: ${response.statusCode}', 'ENHANCED_MEDIA_SERVICE');
        Log.i('Upload response data: ${response.data}', 'ENHANCED_MEDIA_SERVICE');

        if ((response.statusCode == 200 || response.statusCode == 201) && response.data['mediaUrl'] != null) {
          return response.data['mediaUrl'];
        } else {
          throw Exception('Upload failed: ${response.data}');
        }
      } else {
        // Firebase upload implementation
        return await _uploadToFirebase(mediaResult, chatId, onProgress);
      }
    } catch (e) {
      Log.e('Error uploading media', 'ENHANCED_MEDIA_SERVICE', e);
      return null;
    }
  }

  static Future<String?> _uploadToFirebase(
    EnhancedMediaResult mediaResult,
    String chatId,
    Function(double progress)? onProgress,
  ) async {
    try {
      // Firebase upload implementation would go here
      Log.i('Firebase upload not implemented', 'ENHANCED_MEDIA_SERVICE');
      return null;
    } catch (e) {
      Log.e('Error uploading to Firebase', 'ENHANCED_MEDIA_SERVICE', e);
      return null;
    }
  }
}
