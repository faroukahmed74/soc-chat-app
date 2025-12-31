import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:uuid/uuid.dart';

import 'logger_service.dart';

/// Callback type for download progress updates
typedef DownloadProgressCallback = void Function(double progress, String status);

class MediaDownloadService {
  static const String _albumName = 'SOC Chat';
  static const _headers = {
    'ngrok-skip-browser-warning': 'true',
    'User-Agent': 'Mozilla/5.0 (Linux; Android 13; Mobile)',
  };

  static Future<String> saveToDevice({
    required String url,
    required String mediaType,
    String? fileName,
    DownloadProgressCallback? onProgress,
  }) async {
    try {
      Log.i('Starting download: type=$mediaType, url=$url', 'MEDIA_DOWNLOAD');
      
      if (kIsWeb) {
        throw UnsupportedError('MediaDownloadService is for mobile platforms only');
      }
      if (!(Platform.isAndroid || Platform.isIOS)) {
        throw UnsupportedError('Downloads supported only on Android/iOS');
      }

      final normalizedType = mediaType.toLowerCase();
      final isVideo = normalizedType.contains('video');
      final isImage = normalizedType.contains('image') ||
          normalizedType.contains('gif') ||
          normalizedType.contains('sticker');
      final isAudio = normalizedType.contains('audio') ||
          normalizedType.contains('voice');
      final isDocument = normalizedType.contains('document') ||
          normalizedType.contains('pdf') ||
          normalizedType.contains('file');

      Log.i('Media type detection: isImage=$isImage, isVideo=$isVideo, isAudio=$isAudio, isDocument=$isDocument', 'MEDIA_DOWNLOAD');

      // Request permissions (for images/videos, or documents/audio)
      await _ensureStoragePermission(
        isImage: isImage, 
        isVideo: isVideo,
        isDocument: isDocument,
        isAudio: isAudio,
      );
      Log.i('Permissions granted', 'MEDIA_DOWNLOAD');

      // Download the file with progress tracking
      Log.i('Downloading from URL: $url', 'MEDIA_DOWNLOAD');
      onProgress?.call(0.0, 'Starting download...');
      
      final request = http.Request('GET', Uri.parse(url));
      request.headers.addAll(_headers);
      
      final client = http.Client();
      final streamedResponse = await client.send(request).timeout(
        const Duration(minutes: 5),
        onTimeout: () {
          throw Exception('Download timeout - file may be too large or network is slow');
        },
      );
      
      if (streamedResponse.statusCode != 200) {
        Log.e('Download failed with status ${streamedResponse.statusCode}', 'MEDIA_DOWNLOAD', null);
        onProgress?.call(0.0, 'Download failed: HTTP ${streamedResponse.statusCode}');
        throw Exception('Failed to download media (HTTP ${streamedResponse.statusCode})');
      }

      final contentLength = streamedResponse.contentLength ?? 0;
      final bytes = <int>[];
      int downloadedBytes = 0;
      
      onProgress?.call(0.0, 'Downloading...');
      
      await for (final chunk in streamedResponse.stream) {
        bytes.addAll(chunk);
        downloadedBytes += chunk.length;
        
        if (contentLength > 0) {
          final progress = downloadedBytes / contentLength;
          final mbDownloaded = (downloadedBytes / (1024 * 1024)).toStringAsFixed(1);
          final mbTotal = (contentLength / (1024 * 1024)).toStringAsFixed(1);
          onProgress?.call(progress.clamp(0.0, 0.95), 'Downloading... $mbDownloaded MB / $mbTotal MB');
        } else {
          // If content length is unknown, estimate progress
          onProgress?.call(0.5, 'Downloading... ${(downloadedBytes / (1024 * 1024)).toStringAsFixed(1)} MB');
        }
      }
      
      client.close();
      
      Log.i('Downloaded ${bytes.length} bytes', 'MEDIA_DOWNLOAD');
      onProgress?.call(0.95, 'Download complete. Saving...');

      final resolvedName = _resolveFileName(
        fileName,
        url,
        normalizedType,
      );
      Log.i('Resolved filename: $resolvedName', 'MEDIA_DOWNLOAD');

      // Save to temporary file first
      onProgress?.call(0.95, 'Saving to temporary file...');
      final tempDir = await getTemporaryDirectory();
      final tempPath = '${tempDir.path}/$resolvedName';
      final tempFile = File(tempPath);
      await tempFile.writeAsBytes(bytes);
      Log.i('Saved to temp file: $tempPath', 'MEDIA_DOWNLOAD');

      try {
        String successMessage;
        onProgress?.call(0.97, 'Saving to device...');
        
        if (Platform.isIOS && (isImage || isVideo)) {
          // For iOS images/videos, save to Photos library
          Log.i('Saving to Photos library (iOS)', 'MEDIA_DOWNLOAD');
          onProgress?.call(0.98, 'Saving to Photos library...');
          await _saveToPhotosLibraryIOS(tempFile, isVideo);
          successMessage = 'Saved to Photos library';
        } else if (Platform.isAndroid && (isImage || isVideo)) {
          // For Android images/videos, save to Gallery using MediaStore API
          Log.i('Saving to Gallery (Android)', 'MEDIA_DOWNLOAD');
          onProgress?.call(0.98, 'Saving to Gallery...');
          await _saveToGalleryAndroid(tempFile, isVideo);
          successMessage = 'Saved to Gallery';
        } else {
          // For Android/iOS documents/audio, save to Downloads
          Log.i('Saving to Downloads folder', 'MEDIA_DOWNLOAD');
          onProgress?.call(0.98, 'Saving to Downloads...');
          if (Platform.isAndroid) {
            // Use MediaStore API for Android 10+ for better accessibility
            await _saveToDownloadsAndroid(tempFile, resolvedName, normalizedType);
            successMessage = 'Saved to Downloads';
          } else {
            // iOS: Save to Documents directory (accessible via Files app)
            final savedFile = await _saveToDownloads(tempFile, resolvedName);
            Log.i('File saved successfully to: ${savedFile.path}', 'MEDIA_DOWNLOAD');
            successMessage = 'Saved to Downloads';
          }
        }
        
        onProgress?.call(1.0, 'Download complete!');
        Log.i('Download completed successfully', 'MEDIA_DOWNLOAD');
        return successMessage;
      } finally {
        // Clean up temp file
        if (await tempFile.exists()) {
          await tempFile.delete();
          Log.i('Temp file deleted', 'MEDIA_DOWNLOAD');
        }
      }
    } catch (e, stackTrace) {
      Log.e('Error in saveToDevice', 'MEDIA_DOWNLOAD', e);
      Log.e('Stack trace: $stackTrace', 'MEDIA_DOWNLOAD', null);
      rethrow;
    }
  }
  
  /// Get success message based on platform and media type
  static String getSuccessMessage(String mediaType, {bool isAndroid = false, bool isIOS = false}) {
    final normalizedType = mediaType.toLowerCase();
    final isVideo = normalizedType.contains('video');
    final isImage = normalizedType.contains('image') ||
        normalizedType.contains('gif') ||
        normalizedType.contains('sticker');
    
    if (isIOS && (isImage || isVideo)) {
      return 'Saved to Photos library';
    } else if (isAndroid && (isImage || isVideo)) {
      return 'Saved to Gallery';
    } else {
      return 'Saved to Downloads';
    }
  }

  /// Save document/audio to Downloads on Android using MediaStore API
  static Future<void> _saveToDownloadsAndroid(File tempFile, String fileName, String normalizedType) async {
    if (!Platform.isAndroid) return;
    
    try {
      // Determine MIME type
      String mimeType = 'application/octet-stream';
      final lastDotIndex = fileName.lastIndexOf('.');
      final extension = lastDotIndex >= 0 && lastDotIndex < fileName.length - 1
          ? fileName.substring(lastDotIndex + 1).toLowerCase()
          : '';
      
      if (normalizedType.contains('audio') || normalizedType.contains('voice')) {
        switch (extension) {
          case 'mp3':
            mimeType = 'audio/mpeg';
            break;
          case 'wav':
            mimeType = 'audio/wav';
            break;
          case 'm4a':
            mimeType = 'audio/mp4';
            break;
          case 'ogg':
            mimeType = 'audio/ogg';
            break;
          case 'aac':
            mimeType = 'audio/aac';
            break;
          default:
            mimeType = 'audio/mpeg';
        }
      } else if (normalizedType.contains('document') || normalizedType.contains('pdf')) {
        switch (extension) {
          case 'pdf':
            mimeType = 'application/pdf';
            break;
          case 'doc':
            mimeType = 'application/msword';
            break;
          case 'docx':
            mimeType = 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
            break;
          case 'xls':
            mimeType = 'application/vnd.ms-excel';
            break;
          case 'xlsx':
            mimeType = 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';
            break;
          case 'ppt':
            mimeType = 'application/vnd.ms-powerpoint';
            break;
          case 'pptx':
            mimeType = 'application/vnd.openxmlformats-officedocument.presentationml.presentation';
            break;
          case 'txt':
            mimeType = 'text/plain';
            break;
          case 'rtf':
            mimeType = 'application/rtf';
            break;
          case 'zip':
            mimeType = 'application/zip';
            break;
          case 'rar':
            mimeType = 'application/x-rar-compressed';
            break;
          default:
            mimeType = 'application/octet-stream';
        }
      }
      
      const channel = MethodChannel('soc_chat_app/gallery');
      final result = await channel.invokeMethod<String>('saveToDownloads', {
        'path': tempFile.path,
        'fileName': fileName,
        'mimeType': mimeType,
      });
      
      if (result != null && result.isNotEmpty) {
        Log.i('Saved to Downloads successfully: $result', 'MEDIA_DOWNLOAD');
      } else {
        throw Exception('Failed to save to Downloads - no URI returned');
      }
    } catch (e) {
      Log.e('Error saving to Downloads (Android)', 'MEDIA_DOWNLOAD', e);
      // Fallback to old method
      Log.i('Falling back to legacy Downloads method', 'MEDIA_DOWNLOAD');
      final savedFile = await _saveToDownloads(tempFile, fileName);
      Log.i('Saved to Downloads (fallback): ${savedFile.path}', 'MEDIA_DOWNLOAD');
      await _triggerMediaScan(savedFile.path);
      rethrow;
    }
  }
  
  static Future<File> _saveToDownloads(File tempFile, String fileName) async {
    try {
      final targetDir = await _getDownloadDirectory();
      Log.i('Target directory: ${targetDir.path}', 'MEDIA_DOWNLOAD');
      
      // Ensure directory exists
      if (!await targetDir.exists()) {
        Log.i('Creating target directory', 'MEDIA_DOWNLOAD');
        await targetDir.create(recursive: true);
      }
      
      final targetPath = '${targetDir.path}/$fileName';
      Log.i('Copying file to: $targetPath', 'MEDIA_DOWNLOAD');
      
      // Check if file already exists and handle it
      final destFile = File(targetPath);
      if (await destFile.exists()) {
        Log.w('File already exists, will overwrite: $targetPath', 'MEDIA_DOWNLOAD');
        await destFile.delete();
      }
      
      final savedFile = await tempFile.copy(targetPath);
      Log.i('File saved successfully to: ${savedFile.path}', 'MEDIA_DOWNLOAD');
      
      // Verify file was saved
      if (await savedFile.exists()) {
        final fileSize = await savedFile.length();
        Log.i('File saved successfully, size: $fileSize bytes', 'MEDIA_DOWNLOAD');
        return savedFile;
      } else {
        throw Exception('File was not saved - verification failed');
      }
    } catch (e, stackTrace) {
      Log.e('Error saving file to Downloads', 'MEDIA_DOWNLOAD', e);
      Log.e('Stack trace: $stackTrace', 'MEDIA_DOWNLOAD', null);
      rethrow;
    }
  }

  static Future<Directory> _getDownloadDirectory() async {
    if (Platform.isAndroid) {
      final dirs = await getExternalStorageDirectories(
        type: StorageDirectory.downloads,
      );
      if (dirs != null && dirs.isNotEmpty) {
        final target = Directory('${dirs.first.path}/SOC Chat');
        if (!await target.exists()) {
          await target.create(recursive: true);
        }
        return target;
      }
      final external = await getExternalStorageDirectory();
      if (external != null) {
        final target = Directory('${external.path}/SOC Chat');
        if (!await target.exists()) {
          await target.create(recursive: true);
        }
        return target;
      }
    }

    // For iOS, save to a location accessible via Files app
    if (Platform.isIOS) {
      // Use the app's Documents directory which is accessible via Files app
      final docs = await getApplicationDocumentsDirectory();
      final target = Directory('${docs.path}/SOC Chat Downloads');
      if (!await target.exists()) {
        await target.create(recursive: true);
      }
      return target;
    }

    // Fallback for other platforms
    final docs = await getApplicationDocumentsDirectory();
    final target = Directory('${docs.path}/Downloads');
    if (!await target.exists()) {
      await target.create(recursive: true);
    }
    return target;
  }

  /// Save image or video to Gallery on Android using MediaStore API
  static Future<void> _saveToGalleryAndroid(File file, bool isVideo) async {
    if (!Platform.isAndroid) return;
    
    try {
      // Verify file exists and is readable
      if (!await file.exists()) {
        throw Exception('Source file does not exist: ${file.path}');
      }
      
      final fileSize = await file.length();
      if (fileSize == 0) {
        throw Exception('Source file is empty: ${file.path}');
      }
      
      Log.i('Attempting to save to Gallery: ${file.path} (${fileSize} bytes)', 'MEDIA_DOWNLOAD');
      
      const channel = MethodChannel('soc_chat_app/gallery');
      final result = await channel.invokeMethod<String>('saveToGallery', {
        'path': file.path,
        'isVideo': isVideo,
        'albumName': _albumName,
      });
      
      if (result != null && result.isNotEmpty) {
        Log.i('Saved to Gallery successfully: $result', 'MEDIA_DOWNLOAD');
        return; // Success, no need to throw
      } else {
        throw Exception('Gallery save failed - no URI returned from native code');
      }
    } catch (e) {
      Log.e('Error saving to Gallery', 'MEDIA_DOWNLOAD', e);
      Log.i('Gallery save failed, attempting fallback to Downloads', 'MEDIA_DOWNLOAD');
      
      // Fallback: save to Downloads directory and trigger media scan
      try {
        final fileName = file.path.split('/').last;
        final savedFile = await _saveToDownloads(file, fileName);
        Log.i('Saved to Downloads (fallback): ${savedFile.path}', 'MEDIA_DOWNLOAD');
        await _triggerMediaScan(savedFile.path);
        // Don't throw here - the file was saved successfully, just to a different location
        // The error message will indicate the fallback location
        throw Exception('Gallery save failed. File saved to Downloads folder instead.');
      } catch (fallbackError) {
        Log.e('Fallback save also failed', 'MEDIA_DOWNLOAD', fallbackError);
        // If fallback also fails, throw the original error
        rethrow;
      }
    }
  }

  /// Save image or video to Photos library on iOS
  static Future<void> _saveToPhotosLibraryIOS(File file, bool isVideo) async {
    if (!Platform.isIOS) return;
    
    try {
      const channel = MethodChannel('soc_chat_app/photos_library');
      final result = await channel.invokeMethod('saveToPhotos', {
        'path': file.path,
        'isVideo': isVideo,
        'albumName': _albumName,
      });
      
      if (result == true) {
        Log.i('Saved to Photos library successfully', 'MEDIA_DOWNLOAD');
      } else {
        throw Exception('Failed to save to Photos library');
      }
    } catch (e) {
      Log.e('Error saving to Photos library', 'MEDIA_DOWNLOAD', e);
      // Fallback: save to Documents directory
      Log.i('Falling back to Documents directory', 'MEDIA_DOWNLOAD');
      final docs = await getApplicationDocumentsDirectory();
      final targetDir = Directory('${docs.path}/SOC Chat Downloads');
      if (!await targetDir.exists()) {
        await targetDir.create(recursive: true);
      }
      final fileName = file.path.split('/').last;
      await file.copy('${targetDir.path}/$fileName');
      Log.i('Saved to Documents: ${targetDir.path}/$fileName', 'MEDIA_DOWNLOAD');
      throw Exception('Photos library save failed. File saved to Documents. Access via Files app > On My iPhone > SOC Chat App > SOC Chat Downloads');
    }
  }

  static Future<void> _ensureStoragePermission({
    required bool isImage,
    required bool isVideo,
    bool isDocument = false,
    bool isAudio = false,
  }) async {
    if (Platform.isIOS) {
      // For iOS, use photosAddOnly permission for saving to Photos library
      // This is the correct permission for iOS 14+ and doesn't require full library access
      Log.i('Requesting iOS photosAddOnly permission for saving media', 'MEDIA_DOWNLOAD');
      final photosStatus = await Permission.photosAddOnly.request();
      Log.i('iOS photosAddOnly permission status: $photosStatus', 'MEDIA_DOWNLOAD');
      
      if (photosStatus.isGranted) {
        Log.i('iOS photosAddOnly permission granted', 'MEDIA_DOWNLOAD');
        return;
      }
      
      // If photosAddOnly is denied, try full photos permission as fallback
      Log.w('photosAddOnly denied, trying full photos permission', 'MEDIA_DOWNLOAD');
      final fullPhotosStatus = await Permission.photos.request();
      Log.i('iOS photos permission status: $fullPhotosStatus', 'MEDIA_DOWNLOAD');
      
      if (fullPhotosStatus.isGranted || fullPhotosStatus.isLimited) {
        Log.i('iOS photos permission granted/limited', 'MEDIA_DOWNLOAD');
        return;
      }
      
      // If both are denied, throw error
      Log.e('Both photosAddOnly and photos permissions denied on iOS', 'MEDIA_DOWNLOAD', null);
      throw Exception('Photo library permission denied. Please grant permission in iOS Settings > Privacy & Security > Photos.');
    }

    // Android permission handling
    final sdkInt = await _androidSdkInt();
    Log.i('Android SDK version: $sdkInt', 'MEDIA_DOWNLOAD');
    
    if (sdkInt >= 33) {
      // Android 13+ (API 33+): Use granular permissions
      final permissions = <Permission>[];
      if (isImage) {
        permissions.add(Permission.photos);
        Log.i('Requesting photos permission for image', 'MEDIA_DOWNLOAD');
      }
      if (isVideo) {
        permissions.add(Permission.videos);
        Log.i('Requesting videos permission for video', 'MEDIA_DOWNLOAD');
      }
      // For audio/documents on Android 13+, we can use storage permission
      if (permissions.isEmpty) {
        permissions.add(Permission.storage);
        Log.i('Requesting storage permission for audio/document', 'MEDIA_DOWNLOAD');
      }

      bool hasPermission = false;
      for (final permission in permissions) {
        final status = await permission.request();
        Log.i('Permission ${permission.toString()} status: $status', 'MEDIA_DOWNLOAD');
        if (status.isGranted) {
          hasPermission = true;
          break;
        }
      }
      
      if (!hasPermission) {
        Log.e('All permissions denied on Android 13+', 'MEDIA_DOWNLOAD', null);
        throw Exception('Storage permission denied. Please grant storage permission in app settings.');
      }
    } else if (sdkInt >= 30) {
      // Android 11-12 (API 30-32): Try manageExternalStorage first, then storage
      Log.i('Requesting manageExternalStorage permission for Android 11-12', 'MEDIA_DOWNLOAD');
      final manageStatus = await Permission.manageExternalStorage.request();
      if (manageStatus.isGranted) {
        Log.i('manageExternalStorage granted', 'MEDIA_DOWNLOAD');
        return;
      }
      
      // Fallback to storage permission
      Log.i('manageExternalStorage denied, trying storage permission', 'MEDIA_DOWNLOAD');
      final storageStatus = await Permission.storage.request();
      if (!storageStatus.isGranted) {
        Log.w('Storage permission denied on Android 11-12, but MediaStore should still work', 'MEDIA_DOWNLOAD');
        // Don't throw - MediaStore API on Android 10+ doesn't require WRITE permission
      }
      Log.i('Permission check completed for Android 11-12', 'MEDIA_DOWNLOAD');
    } else if (sdkInt >= 29) {
      // Android 10 (API 29): MediaStore doesn't require WRITE_EXTERNAL_STORAGE
      Log.i('Android 10: MediaStore API available, no write permission needed', 'MEDIA_DOWNLOAD');
      // Try to request READ permission for compatibility, but don't fail if denied
      final readStatus = await Permission.storage.request();
      if (!readStatus.isGranted) {
        Log.w('Read storage permission denied, but MediaStore should still work on Android 10+', 'MEDIA_DOWNLOAD');
      }
    } else {
      // Android 9 and below (API <29): Use storage permission - REQUIRED for MediaStore
      Log.i('Requesting storage permission for Android 9- (API <29)', 'MEDIA_DOWNLOAD');
      final storageStatus = await Permission.storage.request();
      Log.i('Storage permission status: $storageStatus', 'MEDIA_DOWNLOAD');
      
      if (!storageStatus.isGranted) {
        Log.e('Storage permission denied on Android 9-', 'MEDIA_DOWNLOAD', null);
        throw Exception('Storage permission denied. Please grant storage permission in app settings to save media to gallery.');
      }
      Log.i('Storage permission granted for Android 9-', 'MEDIA_DOWNLOAD');
    }
  }

  static Future<void> _triggerMediaScan(String path) async {
    if (!Platform.isAndroid) return;
    const channel = MethodChannel('soc_chat_app/media_scanner');
    try {
      await channel.invokeMethod('scanFile', {'path': path});
    } catch (e) {
      Log.w('Media scan failed: $e', 'MEDIA_DOWNLOAD');
    }
  }

  static Future<int> _androidSdkInt() async {
    if (!Platform.isAndroid) return 0;
    final info = await DeviceInfoPlugin().androidInfo;
    return info.version.sdkInt;
  }

  static String _resolveFileName(
    String? providedName,
    String url,
    String normalizedType,
  ) {
    final uri = Uri.parse(url);
    final urlSegment = uri.pathSegments.isNotEmpty ? uri.pathSegments.last : '';
    final extensionFromUrl =
        urlSegment.contains('.') ? '.${urlSegment.split('.').last}' : '';

    String extension;
    if (extensionFromUrl.isNotEmpty) {
      extension = '.$extensionFromUrl';
    } else if (normalizedType.contains('video')) {
      extension = '.mp4';
    } else if (normalizedType.contains('image')) {
      extension = '.jpg';
    } else if (normalizedType.contains('audio') ||
        normalizedType.contains('voice')) {
      extension = '.mp3';
    } else if (normalizedType.contains('document')) {
      extension = '.pdf';
    } else {
      extension = '.bin';
    }

    if (providedName != null && providedName.isNotEmpty) {
      return providedName.endsWith(extension)
          ? providedName
          : '$providedName$extension';
    }

    if (urlSegment.isNotEmpty) {
      return urlSegment.contains('.')
          ? urlSegment
          : '$urlSegment$extension';
    }

    return '${const Uuid().v4()}$extension';
  }
}

