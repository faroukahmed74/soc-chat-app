import 'dart:async';
import 'package:firebase_storage/firebase_storage.dart';
import 'logger_service.dart';

/// Service to handle media upload progress tracking
class UploadProgressService {
  static final Map<String, StreamController<double>> _progressControllers = {};
  static final Map<String, bool> _uploadStatus = {};
  static final Map<String, String> _uploadErrors = {};

  /// Start tracking upload progress for a specific upload
  static StreamController<double> startProgressTracking(String uploadId) {
    if (_progressControllers.containsKey(uploadId)) {
      _progressControllers[uploadId]!.close();
    }
    
    _progressControllers[uploadId] = StreamController<double>.broadcast();
    _uploadStatus[uploadId] = false; // false = in progress, true = completed
    _uploadErrors.remove(uploadId);
    
    Log.i('Started progress tracking for upload: $uploadId', 'UPLOAD_PROGRESS');
    return _progressControllers[uploadId]!;
  }

  /// Update upload progress
  static void updateProgress(String uploadId, double progress) {
    if (_progressControllers.containsKey(uploadId)) {
      _progressControllers[uploadId]!.add(progress);
      Log.i('Upload progress: ${(progress * 100).toStringAsFixed(1)}% for $uploadId', 'UPLOAD_PROGRESS');
    }
  }

  /// Mark upload as completed
  static void markCompleted(String uploadId) {
    if (_progressControllers.containsKey(uploadId)) {
      _uploadStatus[uploadId] = true;
      _progressControllers[uploadId]!.add(1.0);
      _progressControllers[uploadId]!.close();
      _progressControllers.remove(uploadId);
      Log.i('Upload completed: $uploadId', 'UPLOAD_PROGRESS');
    }
  }

  /// Mark upload as failed
  static void markFailed(String uploadId, String error) {
    if (_progressControllers.containsKey(uploadId)) {
      _uploadStatus[uploadId] = false;
      _uploadErrors[uploadId] = error;
      _progressControllers[uploadId]!.addError(error);
      _progressControllers[uploadId]!.close();
      _progressControllers.remove(uploadId);
      Log.e('Upload failed: $uploadId - $error', 'UPLOAD_PROGRESS');
    }
  }

  /// Get current progress stream
  static Stream<double>? getProgressStream(String uploadId) {
    return _progressControllers[uploadId]?.stream;
  }

  /// Check if upload is completed
  static bool isCompleted(String uploadId) {
    return _uploadStatus[uploadId] ?? false;
  }

  /// Check if upload has error
  static String? getError(String uploadId) {
    return _uploadErrors[uploadId];
  }

  /// Clean up completed uploads
  static void cleanup() {
    for (var controller in _progressControllers.values) {
      controller.close();
    }
    _progressControllers.clear();
    _uploadStatus.clear();
    _uploadErrors.clear();
  }

  /// Get active upload count
  static int getActiveUploadCount() {
    return _progressControllers.length;
  }
}

/// Enhanced upload task with progress tracking
class ProgressTrackingUploadTask {
  final String uploadId;
  final UploadTask uploadTask;
  final StreamController<double> progressController;
  StreamSubscription<dynamic>? _subscription;

  ProgressTrackingUploadTask({
    required this.uploadId,
    required this.uploadTask,
  }) : progressController = UploadProgressService.startProgressTracking(uploadId);

  /// Start monitoring upload progress
  void startMonitoring() {
    _subscription = uploadTask.snapshotEvents.listen(
      (snapshot) {
        final progress = snapshot.bytesTransferred / snapshot.totalBytes;
        UploadProgressService.updateProgress(uploadId, progress);
        
        if (snapshot.state == TaskState.success) {
          UploadProgressService.markCompleted(uploadId);
          _subscription?.cancel();
        } else if (snapshot.state == TaskState.error) {
          UploadProgressService.markFailed(uploadId, 'Upload failed');
          _subscription?.cancel();
        }
      },
      onError: (error) {
        UploadProgressService.markFailed(uploadId, error.toString());
        _subscription?.cancel();
      },
    );
  }

  /// Cancel the upload
  void cancel() {
    uploadTask.cancel();
    _subscription?.cancel();
    UploadProgressService.markFailed(uploadId, 'Upload cancelled');
  }

  /// Dispose resources
  void dispose() {
    _subscription?.cancel();
    progressController.close();
  }
}
