import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:uuid/uuid.dart';

import 'logger_service.dart';

class MediaDownloadService {
  static const String _albumName = 'SOC Chat';
  static const _headers = {
    'ngrok-skip-browser-warning': 'true',
    'User-Agent': 'Mozilla/5.0 (Linux; Android 13; Mobile)',
  };

  static Future<void> saveToDevice({
    required String url,
    required String mediaType,
    String? fileName,
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

      // Request permissions
      await _ensureStoragePermission(isImage: isImage, isVideo: isVideo);
      Log.i('Permissions granted', 'MEDIA_DOWNLOAD');

      // Download the file
      Log.i('Downloading from URL: $url', 'MEDIA_DOWNLOAD');
      final response = await http.get(Uri.parse(url), headers: _headers).timeout(
        const Duration(minutes: 5),
        onTimeout: () {
          throw Exception('Download timeout - file may be too large or network is slow');
        },
      );
      
      if (response.statusCode != 200) {
        Log.e('Download failed with status ${response.statusCode}', 'MEDIA_DOWNLOAD', null);
        throw Exception('Failed to download media (HTTP ${response.statusCode})');
      }

      Log.i('Downloaded ${response.bodyBytes.length} bytes', 'MEDIA_DOWNLOAD');

      final resolvedName = _resolveFileName(
        fileName,
        url,
        normalizedType,
      );
      Log.i('Resolved filename: $resolvedName', 'MEDIA_DOWNLOAD');

      // Save to temporary file first
      final tempDir = await getTemporaryDirectory();
      final tempPath = '${tempDir.path}/$resolvedName';
      final tempFile = File(tempPath);
      await tempFile.writeAsBytes(response.bodyBytes);
      Log.i('Saved to temp file: $tempPath', 'MEDIA_DOWNLOAD');

      try {
        if (Platform.isIOS && (isImage || isVideo)) {
          // For iOS images/videos, save to Photos library
          Log.i('Saving to Photos library (iOS)', 'MEDIA_DOWNLOAD');
          await _saveToPhotosLibraryIOS(tempFile, isVideo);
        } else {
          // For Android or iOS documents/audio, save to Downloads
          Log.i('Saving to Downloads folder', 'MEDIA_DOWNLOAD');
          final savedFile = await _saveToDownloads(tempFile, resolvedName);
          Log.i('File saved successfully to: ${savedFile.path}', 'MEDIA_DOWNLOAD');
          
          if (Platform.isAndroid && (isImage || isVideo)) {
            Log.i('Triggering media scan for Android', 'MEDIA_DOWNLOAD');
            await _triggerMediaScan(savedFile.path);
          }
        }
        Log.i('Download completed successfully', 'MEDIA_DOWNLOAD');
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
  }) async {
    if (Platform.isIOS) {
      final photosStatus = await Permission.photosAddOnly.request();
      if (photosStatus.isGranted) return;
      final storageStatus = await Permission.storage.request();
      if (!storageStatus.isGranted) {
        throw Exception('Storage permission denied');
      }
      return;
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
      // Android 11+ (API 30+): Try manageExternalStorage first, then storage
      Log.i('Requesting manageExternalStorage permission for Android 11+', 'MEDIA_DOWNLOAD');
      final manageStatus = await Permission.manageExternalStorage.request();
      if (manageStatus.isGranted) {
        Log.i('manageExternalStorage granted', 'MEDIA_DOWNLOAD');
        return;
      }
      
      // Fallback to storage permission
      Log.i('manageExternalStorage denied, trying storage permission', 'MEDIA_DOWNLOAD');
      final storageStatus = await Permission.storage.request();
      if (!storageStatus.isGranted) {
        Log.e('Storage permission denied on Android 11+', 'MEDIA_DOWNLOAD', null);
        throw Exception('Storage permission denied. Please grant storage permission in app settings.');
      }
      Log.i('Storage permission granted', 'MEDIA_DOWNLOAD');
    } else {
      // Android 9 and below: Use storage permission
      Log.i('Requesting storage permission for Android 9-', 'MEDIA_DOWNLOAD');
      final storageStatus = await Permission.storage.request();
      if (!storageStatus.isGranted) {
        Log.e('Storage permission denied on Android 9-', 'MEDIA_DOWNLOAD', null);
        throw Exception('Storage permission denied. Please grant storage permission in app settings.');
      }
      Log.i('Storage permission granted', 'MEDIA_DOWNLOAD');
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

