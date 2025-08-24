import 'dart:html' as html;
import 'dart:typed_data';
import 'dart:async';
import '../services/logger_service.dart';

/// Modern web media service using package:web instead of deprecated dart:html
class WebMediaService {
  static final WebMediaService _instance = WebMediaService._internal();
  factory WebMediaService() => _instance;
  WebMediaService._internal();

  /// Pick an image from camera (web implementation - same as gallery)
  static Future<Map<String, dynamic>?> pickImageFromCamera() async {
    return await pickImage();
  }

  /// Pick an image from gallery (web implementation)
  static Future<Map<String, dynamic>?> pickImageFromGallery() async {
    return await pickImage();
  }

  /// Pick an image from the web platform
  static Future<Map<String, dynamic>?> pickImage() async {
    try {
      Log.d('Picking image from web', 'WEB_MEDIA');
      
      // Create a file input element
      final input = html.FileUploadInputElement()
        ..accept = 'image/*'
        ..multiple = false
        ..style.display = 'none';

      // Create a completer to handle the async file selection
      final completer = Completer<Map<String, dynamic>?>();
      
      // Add to DOM temporarily
      html.document.body!.append(input);
      
      // Set up the change event listener
      input.onChange.listen((event) async {
        try {
          final files = input.files;
          if (files != null && files.isNotEmpty) {
            final file = files[0];
            final bytes = await _readFileAsBytes(file);
            
            if (bytes != null) {
              completer.complete({
                'bytes': bytes,
                'fileName': file.name,
                'extension': _getFileExtension(file.name),
                'fileSize': file.size,
                'mimeType': file.type,
              });
            } else {
              completer.complete(null);
            }
          } else {
            completer.complete(null);
          }
        } catch (e) {
          Log.e('Error reading image file', 'WEB_MEDIA', e);
          completer.complete(null);
        } finally {
          // Clean up
          input.remove();
        }
      });

      // Trigger file selection
      input.click();
      
      // Add timeout to prevent hanging
      Timer(const Duration(seconds: 30), () {
        if (!completer.isCompleted) {
          completer.complete(null);
          input.remove();
        }
      });
      
      // Return the future from the completer
      return completer.future;
    } catch (e) {
      Log.e('Error picking image from web', 'WEB_MEDIA', e);
      return null;
    }
  }

  /// Pick a document from the web platform
  static Future<Map<String, dynamic>?> pickDocument() async {
    try {
      Log.d('Picking document from web', 'WEB_MEDIA');
      
      // Create a file input element
      final input = html.FileUploadInputElement()
        ..accept = '.pdf,.doc,.docx,.xls,.xlsx,.ppt,.pptx'
        ..multiple = false
        ..style.display = 'none';

      // Create a completer to handle the async file selection
      final completer = Completer<Map<String, dynamic>?>();
      
      // Add to DOM temporarily
      html.document.body!.append(input);
      
      // Set up the change event listener
      input.onChange.listen((event) async {
        try {
          final files = input.files;
          if (files != null && files.isNotEmpty) {
            final file = files[0];
            final bytes = await _readFileAsBytes(file);
            
            if (bytes != null) {
              completer.complete({
                'bytes': bytes,
                'fileName': file.name,
                'extension': _getFileExtension(file.name),
                'fileSize': file.size,
                'mimeType': file.type,
              });
            } else {
              completer.complete(null);
            }
          } else {
            completer.complete(null);
          }
        } catch (e) {
          Log.e('Error reading document file', 'WEB_MEDIA', e);
          completer.complete(null);
        } finally {
          // Clean up
          input.remove();
        }
      });

      // Trigger file selection
      input.click();
      
      // Add timeout to prevent hanging
      Timer(const Duration(seconds: 30), () {
        if (!completer.isCompleted) {
          completer.complete(null);
          input.remove();
        }
      });
      
      // Return the future from the completer
      return completer.future;
    } catch (e) {
      Log.e('Error picking document from web', 'WEB_MEDIA', e);
      return null;
    }
  }

  /// Pick a video from the web platform
  static Future<Map<String, dynamic>?> pickVideo() async {
    try {
      Log.d('Picking video from web', 'WEB_MEDIA');
      
      // Create a file input element
      final input = html.FileUploadInputElement()
        ..accept = 'video/*'
        ..multiple = false
        ..style.display = 'none';

      // Create a completer to handle the async file selection
      final completer = Completer<Map<String, dynamic>?>();
      
      // Add to DOM temporarily
      html.document.body!.append(input);
      
      // Set up the change event listener
      input.onChange.listen((event) async {
        try {
          final files = input.files;
          if (files != null && files.isNotEmpty) {
            final file = files[0];
            final bytes = await _readFileAsBytes(file);
            
            if (bytes != null) {
              completer.complete({
                'bytes': bytes,
                'fileName': file.name,
                'extension': _getFileExtension(file.name),
                'fileSize': file.size,
                'mimeType': file.type,
              });
            } else {
              completer.complete(null);
            }
          } else {
            completer.complete(null);
          }
        } catch (e) {
          Log.e('Error reading video file', 'WEB_MEDIA', e);
          completer.complete(null);
        } finally {
          // Clean up
          input.remove();
        }
      });

      // Trigger file selection
      input.click();
      
      // Add timeout to prevent hanging
      Timer(const Duration(seconds: 30), () {
        if (!completer.isCompleted) {
          completer.complete(null);
          input.remove();
        }
      });
      
      // Return the future from the completer
      return completer.future;
    } catch (e) {
      Log.e('Error picking video from web', 'WEB_MEDIA', e);
      return null;
    }
  }

  /// Pick a video from camera on web platform
  static Future<Map<String, dynamic>?> pickVideoFromCamera() async {
    try {
      Log.d('Picking video from camera on web', 'WEB_MEDIA');
      
      // For web, we'll use the same file picker but with camera constraints
      // Note: This is a simplified implementation for web
      final result = await pickVideo();
      if (result != null) {
        // Add a note that this came from camera (web limitation)
        result['source'] = 'camera';
      }
      return result;
    } catch (e) {
      Log.e('Error picking video from camera on web', 'WEB_MEDIA', e);
      return null;
    }
  }

  /// Pick a video from gallery on web platform
  static Future<Map<String, dynamic>?> pickVideoFromGallery() async {
    try {
      Log.d('Picking video from gallery on web', 'WEB_MEDIA');
      
      // For web, this is the same as the general pickVideo method
      final result = await pickVideo();
      if (result != null) {
        result['source'] = 'gallery';
      }
      return result;
    } catch (e) {
      Log.e('Error picking video from gallery on web', 'WEB_MEDIA', e);
      return null;
    }
  }


  /// Start voice recording (web implementation - not supported)
  static Future<Map<String, dynamic>?> startVoiceRecording() async {
    Log.w('Voice recording not supported on web', 'WEB_MEDIA');
    return null;
  }

  /// Stop voice recording (web implementation - not supported)
  static Future<Map<String, dynamic>?> stopVoiceRecording() async {
    Log.w('Voice recording not supported on web', 'WEB_MEDIA');
    return null;
  }

  /// Check if voice recording is active (web implementation - always false)
  static bool isVoiceRecording() => false;

  /// Read file as bytes using modern web APIs
  static Future<Uint8List?> _readFileAsBytes(html.File file) async {
    try {
      final reader = html.FileReader();
      final completer = Completer<Uint8List?>();
      
      reader.onLoad.listen((event) {
        if (reader.result is Uint8List) {
          completer.complete(reader.result as Uint8List);
        } else {
          completer.complete(null);
        }
      });
      
      reader.onError.listen((event) {
        Log.e('FileReader error', 'WEB_MEDIA', event);
        completer.complete(null);
      });
      
      reader.readAsArrayBuffer(file);
      return completer.future;
    } catch (e) {
      Log.e('Error reading file as bytes', 'WEB_MEDIA', e);
      return null;
    }
  }

  /// Get file extension from filename
  static String? _getFileExtension(String? fileName) {
    if (fileName == null || fileName.isEmpty) return null;
    
    final parts = fileName.split('.');
    if (parts.length > 1) {
      return parts.last.toLowerCase();
    }
    return null;
  }

  /// Get MIME type from file extension
  static String _getMimeType(String? extension) {
    if (extension == null) return 'application/octet-stream';
    
    switch (extension.toLowerCase()) {
      case 'pdf':
        return 'application/pdf';
      case 'doc':
        return 'application/msword';
      case 'docx':
        return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
      case 'xls':
        return 'application/vnd.ms-excel';
      case 'xlsx':
        return 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';
      case 'ppt':
        return 'application/vnd.ms-powerpoint';
      case 'pptx':
        return 'application/vnd.openxmlformats-officedocument.presentationml.presentation';
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      case 'gif':
        return 'image/gif';
      case 'mp4':
        return 'video/mp4';
      case 'avi':
        return 'video/x-msvideo';
      case 'mov':
        return 'video/quicktime';
      default:
        return 'application/octet-stream';
    }
  }
} 