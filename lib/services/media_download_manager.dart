import 'dart:async';
import 'package:flutter/foundation.dart';
import 'media_download_service.dart' show MediaDownloadService, DownloadProgressCallback;

/// Download info for tracking individual downloads
class DownloadInfo {
  final String url;
  final String mediaType;
  final String? fileName;
  double progress;
  String? statusMessage;
  DownloadState state;
  String? errorMessage;
  Completer<String>? completer;

  DownloadInfo({
    required this.url,
    required this.mediaType,
    this.fileName,
    this.progress = 0.0,
    this.statusMessage,
    this.state = DownloadState.downloading,
    this.errorMessage,
    this.completer,
  });
}

/// Download state enum
enum DownloadState {
  idle,
  downloading,
  saving,
  completed,
  failed,
}

/// Manager for handling multiple simultaneous media downloads
class MediaDownloadManager {
  static final MediaDownloadManager _instance = MediaDownloadManager._internal();
  factory MediaDownloadManager() => _instance;
  MediaDownloadManager._internal();

  // Map of URL to DownloadInfo for tracking active downloads
  final Map<String, DownloadInfo> _activeDownloads = {};
  
  // Stream controllers for progress updates
  final Map<String, StreamController<DownloadInfo>> _progressControllers = {};

  /// Get download info for a URL
  DownloadInfo? getDownloadInfo(String url) {
    return _activeDownloads[url];
  }

  /// Check if a download is in progress
  bool isDownloading(String url) {
    final info = _activeDownloads[url];
    return info != null && 
           (info.state == DownloadState.downloading || info.state == DownloadState.saving);
  }

  /// Get progress stream for a download
  Stream<DownloadInfo>? getProgressStream(String url) {
    return _progressControllers[url]?.stream;
  }

  /// Start a download
  Future<String> download({
    required String url,
    required String mediaType,
    String? fileName,
    Function(DownloadInfo)? onProgress,
  }) async {
    // Check if already downloading
    if (_activeDownloads.containsKey(url) && 
        (_activeDownloads[url]!.state == DownloadState.downloading || 
         _activeDownloads[url]!.state == DownloadState.saving)) {
      // Return existing download's completer
      return _activeDownloads[url]!.completer!.future;
    }

    // Create download info
    final completer = Completer<String>();
    final downloadInfo = DownloadInfo(
      url: url,
      mediaType: mediaType,
      fileName: fileName,
      progress: 0.0,
      statusMessage: 'Starting download...',
      state: DownloadState.downloading,
      completer: completer,
    );

    _activeDownloads[url] = downloadInfo;
    _progressControllers[url] = StreamController<DownloadInfo>.broadcast();

    // Start download in background
    _startDownload(downloadInfo, onProgress);

    return completer.future;
  }

  Future<void> _startDownload(
    DownloadInfo downloadInfo,
    Function(DownloadInfo)? onProgress,
  ) async {
    try {
      await MediaDownloadService.saveToDevice(
        url: downloadInfo.url,
        mediaType: downloadInfo.mediaType,
        fileName: downloadInfo.fileName,
        onProgress: (progress, status) {
          downloadInfo.progress = progress;
          downloadInfo.statusMessage = status;
          downloadInfo.state = progress < 0.95
              ? DownloadState.downloading
              : progress < 1.0
                  ? DownloadState.saving
                  : DownloadState.completed;

          // Update stream
          _progressControllers[downloadInfo.url]?.add(downloadInfo);
          
          // Call callback if provided
          onProgress?.call(downloadInfo);
        },
      );

      // Success
      downloadInfo.progress = 1.0;
      downloadInfo.state = DownloadState.completed;
      downloadInfo.statusMessage = 'Download complete!';
      
      _progressControllers[downloadInfo.url]?.add(downloadInfo);
      onProgress?.call(downloadInfo);
      
      downloadInfo.completer?.complete(downloadInfo.statusMessage!);
      
      // Clean up after a delay
      Future.delayed(const Duration(seconds: 2), () {
        _cleanup(downloadInfo.url);
      });
    } catch (e) {
      // Error
      downloadInfo.state = DownloadState.failed;
      downloadInfo.errorMessage = e.toString();
      downloadInfo.statusMessage = 'Download failed';
      
      _progressControllers[downloadInfo.url]?.add(downloadInfo);
      onProgress?.call(downloadInfo);
      
      downloadInfo.completer?.completeError(e);
      
      // Clean up after a delay
      Future.delayed(const Duration(seconds: 5), () {
        _cleanup(downloadInfo.url);
      });
    }
  }

  /// Cancel a download
  void cancel(String url) {
    final downloadInfo = _activeDownloads[url];
    if (downloadInfo != null) {
      downloadInfo.state = DownloadState.failed;
      downloadInfo.statusMessage = 'Download cancelled';
      downloadInfo.completer?.completeError(Exception('Download cancelled'));
      _cleanup(url);
    }
  }

  /// Clean up download resources
  void _cleanup(String url) {
    _activeDownloads.remove(url);
    _progressControllers[url]?.close();
    _progressControllers.remove(url);
  }

  /// Clean up all downloads
  void dispose() {
    for (final url in _activeDownloads.keys.toList()) {
      _cleanup(url);
    }
  }
}

