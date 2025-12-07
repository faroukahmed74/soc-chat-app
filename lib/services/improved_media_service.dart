// =============================================================================
// IMPROVED MEDIA SERVICE
// =============================================================================
// Enhanced media service with better error handling, progress tracking,
// and platform-specific optimizations

import 'dart:typed_data';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import '../config/database_config.dart';
import 'logger_service.dart';
import 'document_service.dart';
import 'web_media_service.dart' if (dart.library.io) 'web_media_stub.dart';
import 'android_permission_fix.dart';

/// Improved media service with better error handling and progress tracking
class ImprovedMediaService {
  static final ImagePicker _picker = ImagePicker();
  
  /// Media upload progress callback
  static void Function(double progress)? onProgress;
  
  /// Enhanced image picking from camera with better error handling
  static Future<MediaResult?> pickImageFromCamera(BuildContext context) async {
    if (kIsWeb) {
      return await _pickImageFromCameraWeb(context);
    }

    try {
      Log.i('Requesting camera permission for image capture', 'IMPROVED_MEDIA');
      
      final hasPermission = await _requestCameraPermission(context);
      if (!hasPermission) {
        Log.w('Camera permission denied', 'IMPROVED_MEDIA');
        _showPermissionDeniedDialog(context, 'Camera', 'camera access is needed to take photos');
        return null;
      }

      Log.i('Camera permission granted, opening camera', 'IMPROVED_MEDIA');
      
      final XFile? image = await _picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 85,
        preferredCameraDevice: CameraDevice.rear,
      );

      if (image != null) {
        final processedBytes = await _prepareImageBytes(context, image);
        Log.i('Image captured successfully: ${processedBytes.length} bytes (pre-optimize)', 'IMPROVED_MEDIA');
        
        final optimizedBytes = await _optimizeImage(processedBytes);
        
        return MediaResult(
          bytes: optimizedBytes,
          type: 'image',
          originalSize: processedBytes.length,
          optimizedSize: optimizedBytes.length,
          fileName: 'camera_${DateTime.now().millisecondsSinceEpoch}.jpg',
          mimeType: 'image/jpeg',
        );
      }
      return null;
    } catch (e) {
      Log.e('Error capturing image from camera', 'IMPROVED_MEDIA', e);
      _showErrorDialog(context, 'Camera Error', 'Failed to capture image: $e');
      return null;
    }
  }

  /// Enhanced image picking from gallery
  static Future<MediaResult?> pickImageFromGallery(BuildContext context) async {
    if (kIsWeb) {
      return await _pickImageFromGalleryWeb(context);
    }

    try {
      Log.i('Picking image from gallery', 'IMPROVED_MEDIA');

      // Android: use modern media permission routing via AndroidPermissionFix
      // iOS: request Photos permission directly
      bool hasPermission = false;
      if (Platform.isAndroid) {
        hasPermission = await AndroidPermissionFix.requestPhotosPermission(context);
      } else if (Platform.isIOS) {
        final status = await Permission.photos.request();
        hasPermission = status == PermissionStatus.granted || status == PermissionStatus.limited;
      }
      if (!hasPermission) {
        Log.w('Photos permission denied', 'IMPROVED_MEDIA');
        _showPermissionDeniedDialog(context, 'Photos', 'photo library access is needed to select photos');
        return null;
      }

      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 85,
      );

      if (image != null) {
        final processedBytes = await _prepareImageBytes(context, image);
        Log.i('Image selected successfully: ${processedBytes.length} bytes (pre-optimize)', 'IMPROVED_MEDIA');
        
        final optimizedBytes = await _optimizeImage(processedBytes);
        
        return MediaResult(
          bytes: optimizedBytes,
          type: 'image',
          originalSize: processedBytes.length,
          optimizedSize: optimizedBytes.length,
          fileName: image.name,
          mimeType: 'image/jpeg',
        );
      }
      return null;
    } catch (e) {
      Log.e('Error picking image from gallery', 'IMPROVED_MEDIA', e);
      _showErrorDialog(context, 'Gallery Error', 'Failed to select image: $e');
      return null;
    }
  }

  /// Enhanced video picking from gallery
  static Future<MediaResult?> pickVideoFromGallery(BuildContext context) async {
    if (kIsWeb) {
      return await _pickVideoFromGalleryWeb(context);
    }

    try {
      Log.i('Picking video from gallery', 'IMPROVED_MEDIA');

      // Android: use modern media permission routing via AndroidPermissionFix
      // iOS: request Photos permission (covers videos in library access)
      bool hasPermission = false;
      if (Platform.isAndroid) {
        hasPermission = await AndroidPermissionFix.requestVideosPermission(context);
      } else if (Platform.isIOS) {
        final status = await Permission.photos.request();
        hasPermission = status == PermissionStatus.granted || status == PermissionStatus.limited;
      }
      if (!hasPermission) {
        Log.w('Videos permission denied', 'IMPROVED_MEDIA');
        _showPermissionDeniedDialog(context, 'Videos', 'video library access is needed to select videos');
        return null;
      }

      final XFile? video = await _picker.pickVideo(
        source: ImageSource.gallery,
        maxDuration: const Duration(minutes: 5),
      );

      if (video != null) {
        final bytes = await video.readAsBytes();
        
        Log.i('Video selected successfully: ${bytes.length} bytes', 'IMPROVED_MEDIA');
        
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
      Log.e('Error picking video from gallery', 'IMPROVED_MEDIA', e);
      _showErrorDialog(context, 'Gallery Error', 'Failed to select video: $e');
      return null;
    }
  }

  /// Enhanced document picking with file type validation
  static Future<MediaResult?> pickDocument(BuildContext context) async {
    try {
      Log.i('Picking document', 'IMPROVED_MEDIA');
      
      final result = await FilePicker.platform.pickFiles(
        type: FileType.any,
        allowMultiple: false,
        withData: true,
      );

      if (result != null && result.files.isNotEmpty) {
        final file = result.files.first;
        final bytes = file.bytes;
        final extension = file.extension?.toLowerCase();
        
        if (bytes != null) {
          final detectedType = _detectMediaType(
            extension: extension,
            fileName: file.name,
          );
          Log.i(
            'File selected successfully: ${bytes.length} bytes (type: $detectedType, ext: $extension)',
            'IMPROVED_MEDIA',
          );
          
          return MediaResult(
            bytes: bytes,
            type: detectedType,
            originalSize: bytes.length,
            optimizedSize: bytes.length,
            fileName: file.name,
            mimeType: _getMimeType(extension),
          );
        }
      }
      return null;
    } catch (e) {
      Log.e('Error picking document', 'IMPROVED_MEDIA', e);
      _showErrorDialog(context, 'Document Error', 'Failed to pick document: $e');
      return null;
    }
  }

  /// Upload media with improved progress tracking and error handling
  static Future<String?> uploadMediaWithProgress(
    MediaResult media,
    String chatId,
    void Function(double progress)? onProgress,
    {String? caption}
  ) async {
    try {
      Log.i('Starting media upload: ${media.fileName}', 'IMPROVED_MEDIA');

      // If physical server is enabled, use local API upload with Dio
      if (DatabaseConfig.isPhysicalServerEnabled) {
        return await _uploadToPhysicalServer(media, chatId, onProgress, caption: caption);
      }

      // Fallback to Firebase Storage when physical server is disabled
      return await _uploadToFirebase(media, chatId, onProgress);
      
    } catch (e) {
      Log.e('Error uploading media', 'IMPROVED_MEDIA', e);
      rethrow;
    }
  }

  /// Upload to physical server with improved error handling
  static Future<String?> _uploadToPhysicalServer(
    MediaResult media,
    String chatId,
    void Function(double progress)? onProgress,
    {String? caption}
  ) async {
    try {
      final baseUrl = DatabaseConfig.physicalServerUrl;
      final token = await DatabaseConfig.getStoredAuthToken();

      if (token.isEmpty) {
        throw Exception('No authentication token available');
      }

      final dio = Dio(BaseOptions(
        baseUrl: baseUrl,
        headers: {
          'Authorization': 'Bearer $token',
          'ngrok-skip-browser-warning': 'true',
        },
        // Increased timeouts for larger files
        connectTimeout: const Duration(seconds: 30),
        receiveTimeout: const Duration(seconds: 120),
        sendTimeout: const Duration(seconds: 120),
      ));

      final formData = FormData.fromMap({
        'chatId': chatId,
        'type': media.type,
        'file': MultipartFile.fromBytes(
          media.bytes,
          filename: media.fileName,
          contentType: DioMediaType.parse(media.mimeType),
        ),
        if (caption != null && caption.isNotEmpty) 'caption': caption,
      });

      final response = await dio.post(
        '/api/media/upload',
        data: formData,
        onSendProgress: (sent, total) {
          if (total > 0) {
            final progress = sent / total;
            Log.i('Upload progress: ${(progress * 100).toStringAsFixed(1)}%', 'IMPROVED_MEDIA');
            onProgress?.call(progress);
          }
        },
      );

      if (response.statusCode == 201 || response.statusCode == 200) {
        final data = response.data as Map;
        final mediaUrl = data['mediaUrl'] as String?;
        if (mediaUrl != null && mediaUrl.isNotEmpty) {
          Log.i('Media upload completed (server): $mediaUrl', 'IMPROVED_MEDIA');
          return mediaUrl;
        }
        throw Exception('Upload succeeded but no mediaUrl returned');
      } else {
        final code = response.statusCode ?? 0;
        final msg = response.statusMessage ?? 'Unknown error';
        throw Exception('Upload failed: HTTP $code $msg');
      }
    } catch (e) {
      Log.e('Error uploading to physical server', 'IMPROVED_MEDIA', e);
      rethrow;
    }
  }

  /// Upload to Firebase with improved error handling
  static Future<String?> _uploadToFirebase(
    MediaResult media,
    String chatId,
    void Function(double progress)? onProgress,
  ) async {
    try {
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
        Log.i('Upload progress: ${(progress * 100).toStringAsFixed(1)}%', 'IMPROVED_MEDIA');
        onProgress?.call(progress);
      });
      
      // Wait for upload to complete
      final snapshot = await uploadTask;
      final downloadUrl = await snapshot.ref.getDownloadURL();
      
      Log.i('Media upload completed (Firebase): $downloadUrl', 'IMPROVED_MEDIA');
      return downloadUrl;
      
    } catch (e) {
      Log.e('Error uploading to Firebase', 'IMPROVED_MEDIA', e);
      rethrow;
    }
  }

  /// Optimize image bytes for better performance
  static Future<Uint8List> _optimizeImage(Uint8List originalBytes) async {
    try {
      // For now, we'll return the original bytes
      // In a real implementation, you'd use image compression
      // You can integrate with packages like flutter_image_compress
      
      // Basic size check - if image is too large, we might want to compress
      if (originalBytes.length > 5 * 1024 * 1024) { // 5MB
        Log.w('Large image detected: ${originalBytes.length} bytes', 'IMPROVED_MEDIA');
        // TODO: Implement image compression here
      }
      
      return originalBytes;
    } catch (e) {
      Log.e('Error optimizing image', 'IMPROVED_MEDIA', e);
      return originalBytes; // Return original if optimization fails
    }
  }

  static Future<Uint8List> _prepareImageBytes(BuildContext context, XFile image) async {
    try {
      if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
        final editedBytes = await _launchImageEditor(context, image.path);
        if (editedBytes != null) {
          Log.i('Image edited via cropper (size: ${editedBytes.length})', 'IMPROVED_MEDIA');
          return editedBytes;
        }
        Log.i('Image editing skipped, using original bytes', 'IMPROVED_MEDIA');
        return await image.readAsBytes();
      } else {
        return await image.readAsBytes();
      }
    } catch (e) {
      Log.e('Error preparing image bytes', 'IMPROVED_MEDIA', e);
      return await image.readAsBytes();
    }
  }

  static Future<Uint8List?> _launchImageEditor(BuildContext context, String sourcePath) async {
    try {
      final cropper = ImageCropper();
      final theme = Theme.of(context);
      final cropped = await cropper.cropImage(
        sourcePath: sourcePath,
        compressFormat: ImageCompressFormat.jpg,
        compressQuality: 95,
        uiSettings: [
          AndroidUiSettings(
            toolbarTitle: 'Edit photo',
            toolbarColor: theme.colorScheme.primary,
            toolbarWidgetColor: Colors.white,
            activeControlsWidgetColor: theme.colorScheme.primary,
            initAspectRatio: CropAspectRatioPreset.original,
            lockAspectRatio: false,
            hideBottomControls: false,
            showCropGrid: true,
          ),
          IOSUiSettings(
            title: 'Edit Photo',
            aspectRatioLockEnabled: false,
            rotateButtonsHidden: false,
            rotateClockwiseButtonHidden: false,
          ),
        ],
      );
      if (cropped == null) {
        return null;
      }
      return await cropped.readAsBytes();
    } catch (e) {
      Log.e('Image editing error', 'IMPROVED_MEDIA', e);
      return null;
    }
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
      Log.e('Error requesting camera permission', 'IMPROVED_MEDIA', e);
      return false;
    }
  }

  /// Deprecated: Storage permission is not used on Android 13+ for media picking.
  /// Retained for backward compatibility in other call sites if any.
  static Future<bool> _requestStoragePermission(BuildContext context) async {
    try {
      if (Platform.isAndroid) {
        // For legacy Android (<13), request storage; otherwise rely on AndroidPermissionFix in callers.
        return await _requestAndroidStoragePermission(context);
      } else if (Platform.isIOS) {
        return await _requestIOSStoragePermission(context);
      }
      return false;
    } catch (e) {
      Log.e('Error requesting storage permission', 'IMPROVED_MEDIA', e);
      return false;
    }
  }

  /// Request Android camera permission
  static Future<bool> _requestAndroidCameraPermission(BuildContext context) async {
    final status = await Permission.camera.request();
    return status == PermissionStatus.granted;
  }

  /// Request iOS camera permission
  static Future<bool> _requestIOSCameraPermission(BuildContext context) async {
    final status = await Permission.camera.request();
    return status == PermissionStatus.granted;
  }

  /// Request Android storage permission (legacy Android <13 only)
  static Future<bool> _requestAndroidStoragePermission(BuildContext context) async {
    final status = await Permission.storage.request();
    return status == PermissionStatus.granted;
  }

  /// Request iOS storage permission
  static Future<bool> _requestIOSStoragePermission(BuildContext context) async {
    final status = await Permission.photos.request();
    return status == PermissionStatus.granted;
  }

  /// Show permission denied dialog
  static void _showPermissionDeniedDialog(BuildContext context, String permission, String reason) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('$permission Permission Required'),
        content: Text('$permission $reason. Please grant permission in settings.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              openAppSettings();
            },
            child: const Text('Settings'),
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
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  /// Get MIME type from file extension
  static String _getMimeType(String? extension) {
    if (extension == null) return 'application/octet-stream';
    final ext = extension.toLowerCase();
    
    switch (ext) {
      case 'pdf':
        return 'application/pdf';
      case 'doc':
      case 'docx':
        return 'application/msword';
      case 'xls':
      case 'xlsx':
        return 'application/vnd.ms-excel';
      case 'ppt':
      case 'pptx':
        return 'application/vnd.ms-powerpoint';
      case 'txt':
        return 'text/plain';
      case 'jpg':
      case 'jpeg':
      case 'heic':
      case 'heif':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      case 'gif':
        return 'image/gif';
      case 'webp':
        return 'image/webp';
      case 'mp4':
      case 'm4v':
      case 'mov':
      case 'mkv':
      case 'webm':
        return 'video/mp4';
      case 'mp3':
      case 'm4a':
      case 'aac':
      case 'wav':
      case 'ogg':
        return 'audio/mpeg';
      default:
        return 'application/octet-stream';
    }
  }

  static String _detectMediaType({
    String? extension,
    String? mimeType,
    String? fileName,
  }) {
    String? ext = extension?.toLowerCase();
    if ((ext == null || ext.isEmpty) && fileName != null && fileName.contains('.')) {
      ext = fileName.split('.').last.toLowerCase();
    }
    if ((ext == null || ext.isEmpty) && mimeType != null) {
      ext = _mapMimeToExtension(mimeType);
    }

    final mime = mimeType?.toLowerCase();
    if (mime != null) {
      if (mime.startsWith('image/')) return 'image';
      if (mime.startsWith('video/')) return 'video';
      if (mime.startsWith('audio/')) return 'audio';
    }

    const imageExts = {
      'jpg',
      'jpeg',
      'png',
      'gif',
      'bmp',
      'webp',
      'heic',
      'heif',
      'tiff',
    };
    const videoExts = {
      'mp4',
      'm4v',
      'mov',
      'avi',
      'mkv',
      'webm',
      'flv',
    };
    const audioExts = {
      'mp3',
      'm4a',
      'aac',
      'wav',
      'ogg',
      'oga',
      'flac',
      'amr',
    };
    
    if (ext != null) {
      if (imageExts.contains(ext)) return 'image';
      if (videoExts.contains(ext)) return 'video';
      if (audioExts.contains(ext)) return 'audio';
      if (ext == 'pdf') return 'document';
    }
    return 'document';
  }

  static String? _mapMimeToExtension(String mimeType) {
    final lower = mimeType.toLowerCase();
    if (lower.contains('/')) {
      final subtype = lower.split('/').last;
      if (subtype.isNotEmpty) return subtype;
    }
    return null;
  }

  // Web-specific methods (stubs for mobile)
  static Future<MediaResult?> _pickImageFromCameraWeb(BuildContext context) async {
    // Web implementation would go here
    return null;
  }

  static Future<MediaResult?> _pickImageFromGalleryWeb(BuildContext context) async {
    // Web implementation would go here
    return null;
  }

  static Future<MediaResult?> _pickVideoFromGalleryWeb(BuildContext context) async {
    // Web implementation would go here
    return null;
  }
}

/// Media result class
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
}
