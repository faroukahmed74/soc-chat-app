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

    await _ensureStoragePermission(isImage: isImage, isVideo: isVideo);

    final response = await http.get(Uri.parse(url), headers: _headers);
    if (response.statusCode != 200) {
      throw Exception('Failed to download media (HTTP ${response.statusCode})');
    }

    final resolvedName = _resolveFileName(
      fileName,
      url,
      normalizedType,
    );

    final tempDir = await getTemporaryDirectory();
    final tempPath = '${tempDir.path}/$resolvedName';
    final tempFile = File(tempPath);
    await tempFile.writeAsBytes(response.bodyBytes);

    try {
      final savedFile = await _saveToDownloads(tempFile, resolvedName);
      if (Platform.isAndroid && (isImage || isVideo)) {
        await _triggerMediaScan(savedFile.path);
      }
    } finally {
      if (await tempFile.exists()) {
        await tempFile.delete();
      }
    }
  }

  static Future<File> _saveToDownloads(File tempFile, String fileName) async {
    final targetDir = await _getDownloadDirectory();
    final targetPath = '${targetDir.path}/$fileName';
    final destFile = await tempFile.copy(targetPath);
    Log.i('Saved file to ${destFile.path}', 'MEDIA_DOWNLOAD');
    return destFile;
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

    final docs = await getApplicationDocumentsDirectory();
    final target = Directory('${docs.path}/Downloads');
    if (!await target.exists()) {
      await target.create(recursive: true);
    }
    return target;
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

    final sdkInt = await _androidSdkInt();
    if (sdkInt >= 33) {
      final permissions = <Permission>[];
      if (isImage) permissions.add(Permission.photos);
      if (isVideo) permissions.add(Permission.videos);
      if (permissions.isEmpty) permissions.add(Permission.storage);

      for (final permission in permissions) {
        final status = await permission.request();
        if (status.isGranted) return;
      }
      throw Exception('Storage permission denied');
    } else if (sdkInt >= 30) {
      final manageStatus = await Permission.manageExternalStorage.request();
      if (manageStatus.isGranted) return;
      final storageStatus = await Permission.storage.request();
      if (!storageStatus.isGranted) {
        throw Exception('Storage permission denied');
      }
    } else {
      final storageStatus = await Permission.storage.request();
      if (!storageStatus.isGranted) {
        throw Exception('Storage permission denied');
      }
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

