import 'dart:async';
import 'dart:collection';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import '../config/database_config.dart';
import 'logger_service.dart';
import 'enhanced_unified_media_service.dart';

/// Upload info for tracking individual file uploads
class UploadInfo {
  final String id;
  final String fileName;
  final String mediaType;
  final Uint8List bytes;
  final String? caption;
  double progress;
  String? statusMessage;
  UploadState state;
  String? errorMessage;
  String? mediaUrl;
  Completer<String?>? completer;

  UploadInfo({
    required this.id,
    required this.fileName,
    required this.mediaType,
    required this.bytes,
    this.caption,
    this.progress = 0.0,
    this.statusMessage,
    this.state = UploadState.queued,
    this.errorMessage,
    this.mediaUrl,
    this.completer,
  });
}

/// Upload state enum
enum UploadState {
  queued,
  uploading,
  completed,
  failed,
  cancelled,
}

/// Manager for handling multiple simultaneous media uploads
class MultiMediaUploadService {
  static final MultiMediaUploadService _instance = MultiMediaUploadService._internal();
  factory MultiMediaUploadService() => _instance;
  MultiMediaUploadService._internal();

  // Map of upload ID to UploadInfo for tracking active uploads
  final Map<String, UploadInfo> _activeUploads = {};
  
  // Stream controllers for progress updates
  final Map<String, StreamController<UploadInfo>> _progressControllers = {};

  /// Get upload info for an ID
  UploadInfo? getUploadInfo(String id) {
    return _activeUploads[id];
  }

  /// Get all active uploads
  List<UploadInfo> getActiveUploads() {
    return _activeUploads.values.toList();
  }

  /// Get progress stream for an upload
  Stream<UploadInfo>? getProgressStream(String id) {
    return _progressControllers[id]?.stream;
  }

  /// Upload multiple media files simultaneously
  Future<List<String?>> uploadMultiple({
    required List<EnhancedMediaResult> mediaResults,
    required String chatId,
    String? sharedCaption,
    Function(UploadInfo)? onProgress,
    int maxConcurrent = 3, // Maximum concurrent uploads
  }) async {
    final uploadFutures = <Future<String?>>[];
    final uploadInfos = <UploadInfo>[];

    // Create upload info for each file
    for (final media in mediaResults) {
      final uploadId = '${DateTime.now().millisecondsSinceEpoch}_${media.fileName}';
      final uploadInfo = UploadInfo(
        id: uploadId,
        fileName: media.fileName,
        mediaType: media.type,
        bytes: media.bytes,
        caption: sharedCaption,
        state: UploadState.queued,
        statusMessage: 'Queued...',
        completer: Completer<String?>(),
      );

      _activeUploads[uploadId] = uploadInfo;
      _progressControllers[uploadId] = StreamController<UploadInfo>.broadcast();
      uploadInfos.add(uploadInfo);
    }

    // Upload files with concurrency limit
    final semaphore = Semaphore(maxConcurrent);
    
    for (final uploadInfo in uploadInfos) {
      uploadFutures.add(
        semaphore.acquire().then((_) {
          return _startUpload(uploadInfo, chatId, onProgress).whenComplete(() {
            semaphore.release();
          });
        }),
      );
    }

    // Wait for all uploads to complete
    final results = await Future.wait(uploadFutures);
    
    return results;
  }

  Future<String?> _startUpload(
    UploadInfo uploadInfo,
    String chatId,
    Function(UploadInfo)? onProgress,
  ) async {
    try {
      uploadInfo.state = UploadState.uploading;
      uploadInfo.statusMessage = 'Uploading...';
      uploadInfo.progress = 0.0;
      _notifyProgress(uploadInfo, onProgress);

      if (DatabaseConfig.usePhysicalServer) {
        final baseUrl = DatabaseConfig.physicalServerUrl;
        final token = await DatabaseConfig.getStoredAuthToken();

        // Adjust timeouts based on file size for better compatibility across all Android/iOS versions
        final fileSizeMB = uploadInfo.bytes.length / (1024 * 1024);
        final sendTimeout = fileSizeMB > 50 
            ? const Duration(seconds: 300) // 5 minutes for large files
            : fileSizeMB > 10
                ? const Duration(seconds: 180) // 3 minutes for medium files
                : const Duration(seconds: 120); // 2 minutes for small files

        final dio = Dio(BaseOptions(
          baseUrl: baseUrl,
          headers: {
            if (token.isNotEmpty) 'Authorization': 'Bearer $token',
            'ngrok-skip-browser-warning': 'true',
            'User-Agent': 'SOC-Chat-App/1.0',
          },
          connectTimeout: const Duration(seconds: 30),
          receiveTimeout: sendTimeout,
          sendTimeout: sendTimeout,
          // Enable follow redirects for better compatibility
          followRedirects: true,
          maxRedirects: 5,
        ));

        final formData = FormData.fromMap({
          'chatId': chatId,
          'type': uploadInfo.mediaType,
          'file': MultipartFile.fromBytes(
            uploadInfo.bytes,
            filename: uploadInfo.fileName,
          ),
          if (uploadInfo.caption != null && uploadInfo.caption!.isNotEmpty)
            'caption': uploadInfo.caption,
        });

        // Add retry logic for better reliability across all Android/iOS versions
        DioException? lastError;
        const maxRetries = 3;
        
        for (int attempt = 0; attempt < maxRetries; attempt++) {
          try {
            if (attempt > 0) {
              uploadInfo.statusMessage = 'Retrying upload... (Attempt ${attempt + 1}/$maxRetries)';
              _notifyProgress(uploadInfo, onProgress);
              // Wait before retry with exponential backoff
              await Future.delayed(Duration(seconds: attempt * 2));
            }

            final response = await dio.post(
              '/api/media/upload',
              data: formData,
              onSendProgress: (sent, total) {
                if (total > 0 && uploadInfo.state != UploadState.cancelled) {
                  uploadInfo.progress = sent / total;
                  final mbSent = (sent / (1024 * 1024)).toStringAsFixed(1);
                  final mbTotal = (total / (1024 * 1024)).toStringAsFixed(1);
                  uploadInfo.statusMessage = 'Uploading... ${(uploadInfo.progress * 100).toStringAsFixed(1)}% ($mbSent MB / $mbTotal MB)';
                  _notifyProgress(uploadInfo, onProgress);
                }
              },
              // Add options for better compatibility
              options: Options(
                validateStatus: (status) => status != null && status < 500, // Accept 4xx as errors, retry 5xx
              ),
            );

            if ((response.statusCode == 200 || response.statusCode == 201) && 
                response.data is Map && 
                response.data['mediaUrl'] != null) {
              uploadInfo.mediaUrl = response.data['mediaUrl'];
              uploadInfo.state = UploadState.completed;
              uploadInfo.progress = 1.0;
              uploadInfo.statusMessage = 'Upload complete';
              _notifyProgress(uploadInfo, onProgress);
              
              uploadInfo.completer?.complete(uploadInfo.mediaUrl);
              
              // Clean up after delay
              Future.delayed(const Duration(seconds: 2), () {
                _cleanup(uploadInfo.id);
              });
              
              return uploadInfo.mediaUrl;
            } else {
              // Non-retryable error (4xx)
              throw Exception('Upload failed: HTTP ${response.statusCode}');
            }
          } on DioException catch (e) {
            lastError = e;
            // Retry on network errors or 5xx errors
            if (e.type == DioExceptionType.connectionTimeout ||
                e.type == DioExceptionType.receiveTimeout ||
                e.type == DioExceptionType.sendTimeout ||
                e.type == DioExceptionType.connectionError ||
                (e.response?.statusCode != null && e.response!.statusCode! >= 500)) {
              if (attempt < maxRetries - 1) {
                continue; // Retry
              }
            }
            // Don't retry for other errors
            rethrow;
          }
        }
        
        // If we get here, all retries failed
        throw lastError ?? Exception('Upload failed after $maxRetries attempts');
      } else {
        throw Exception('Physical server not enabled');
      }
    } catch (e) {
      Log.e('Error uploading file: ${uploadInfo.fileName}', 'MULTI_MEDIA_UPLOAD', e);
      uploadInfo.state = UploadState.failed;
      uploadInfo.errorMessage = e.toString();
      uploadInfo.statusMessage = 'Upload failed';
      _notifyProgress(uploadInfo, onProgress);
      
      uploadInfo.completer?.completeError(e);
      
      // Clean up after delay
      Future.delayed(const Duration(seconds: 5), () {
        _cleanup(uploadInfo.id);
      });
      
      return null;
    }
  }

  void _notifyProgress(UploadInfo uploadInfo, Function(UploadInfo)? onProgress) {
    _progressControllers[uploadInfo.id]?.add(uploadInfo);
    onProgress?.call(uploadInfo);
  }

  /// Cancel an upload
  void cancel(String id) {
    final uploadInfo = _activeUploads[id];
    if (uploadInfo != null) {
      uploadInfo.state = UploadState.cancelled;
      uploadInfo.statusMessage = 'Cancelled';
      uploadInfo.completer?.completeError(Exception('Upload cancelled'));
      _notifyProgress(uploadInfo, null);
      _cleanup(id);
    }
  }

  /// Clean up upload resources
  void _cleanup(String id) {
    _activeUploads.remove(id);
    _progressControllers[id]?.close();
    _progressControllers.remove(id);
  }

  /// Clean up all uploads
  void dispose() {
    for (final id in _activeUploads.keys.toList()) {
      _cleanup(id);
    }
  }
}

/// Simple semaphore for limiting concurrent operations
class Semaphore {
  final int maxCount;
  int _currentCount;
  final Queue<Completer<void>> _waitQueue = Queue<Completer<void>>();

  Semaphore(this.maxCount) : _currentCount = maxCount;

  Future<void> acquire() async {
    if (_currentCount > 0) {
      _currentCount--;
      return;
    }

    final completer = Completer<void>();
    _waitQueue.add(completer);
    return completer.future;
  }

  void release() {
    if (_waitQueue.isNotEmpty) {
      final completer = _waitQueue.removeFirst();
      completer.complete();
    } else {
      _currentCount++;
    }
  }
}

