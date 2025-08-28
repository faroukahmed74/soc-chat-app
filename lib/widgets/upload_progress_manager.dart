import 'package:flutter/material.dart';
import '../services/upload_progress_service.dart';
import 'upload_progress_indicator.dart';

/// Manages and displays all active uploads with progress indicators
class UploadProgressManager extends StatefulWidget {
  final VoidCallback? onUploadsComplete;

  const UploadProgressManager({
    super.key,
    this.onUploadsComplete,
  });

  @override
  State<UploadProgressManager> createState() => _UploadProgressManagerState();
}

class _UploadProgressManagerState extends State<UploadProgressManager> {
  final List<String> _activeUploads = [];
  final Map<String, Map<String, dynamic>> _uploadInfo = {};

  @override
  void initState() {
    super.initState();
    _startMonitoring();
  }

  void _startMonitoring() {
    // Monitor for new uploads and updates
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) {
        setState(() {});
        _startMonitoring();
      }
    });
  }

  /// Add a new upload to track
  void addUpload(String uploadId, String fileName, String mediaType) {
    if (!_activeUploads.contains(uploadId)) {
      setState(() {
        _activeUploads.add(uploadId);
        _uploadInfo[uploadId] = {
          'fileName': fileName,
          'mediaType': mediaType,
          'timestamp': DateTime.now(),
        };
      });
    }
  }

  /// Remove an upload from tracking
  void removeUpload(String uploadId) {
    setState(() {
      _activeUploads.remove(uploadId);
      _uploadInfo.remove(uploadId);
    });
    
    // Check if all uploads are complete
    if (_activeUploads.isEmpty && widget.onUploadsComplete != null) {
      widget.onUploadsComplete!();
    }
  }

  /// Cancel an upload
  void _cancelUpload(String uploadId) {
    // This would integrate with the actual upload cancellation
    removeUpload(uploadId);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Upload cancelled: ${_uploadInfo[uploadId]?['fileName'] ?? 'Unknown'}'),
        backgroundColor: Colors.orange.shade600,
      ),
    );
  }

  /// Retry a failed upload
  void _retryUpload(String uploadId) {
    // This would integrate with actual retry logic
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Retrying upload: ${_uploadInfo[uploadId]?['fileName'] ?? 'Unknown'}'),
        backgroundColor: Colors.blue.shade600,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_activeUploads.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).primaryColor.withValues(alpha: 0.1),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(20),
                topRight: Radius.circular(20),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.cloud_upload,
                  color: Theme.of(context).primaryColor,
                  size: 24,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Media Uploads',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).primaryColor,
                        ),
                      ),
                      Text(
                        '${_activeUploads.length} upload${_activeUploads.length == 1 ? '' : 's'} in progress',
                        style: TextStyle(
                          fontSize: 14,
                          color: Theme.of(context).primaryColor.withValues(alpha: 0.7),
                        ),
                      ),
                    ],
                  ),
                ),
                if (_activeUploads.isNotEmpty)
                  IconButton(
                    onPressed: () {
                      showDialog(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: const Text('Cancel All Uploads'),
                          content: const Text('Are you sure you want to cancel all active uploads?'),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.of(context).pop(),
                              child: const Text('No'),
                            ),
                            TextButton(
                              onPressed: () {
                                for (var uploadId in List.from(_activeUploads)) {
                                  _cancelUpload(uploadId);
                                }
                                Navigator.of(context).pop();
                              },
                              child: const Text('Yes'),
                            ),
                          ],
                        ),
                      );
                    },
                    icon: Icon(
                      Icons.stop_circle,
                      color: Colors.red.shade600,
                      size: 24,
                    ),
                    tooltip: 'Cancel All',
                  ),
              ],
            ),
          ),
          
          // Upload progress indicators
          ..._activeUploads.map((uploadId) {
            final info = _uploadInfo[uploadId];
            if (info == null) return const SizedBox.shrink();
            
            return UploadProgressIndicator(
              uploadId: uploadId,
              fileName: info['fileName'] ?? 'Unknown File',
              mediaType: info['mediaType'] ?? 'unknown',
              onCancel: () => _cancelUpload(uploadId),
              onRetry: () => _retryUpload(uploadId),
            );
          }).toList(),
          
          // Footer with summary
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(20),
                bottomRight: Radius.circular(20),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Total: ${_activeUploads.length} upload${_activeUploads.length == 1 ? '' : 's'}',
                  style: TextStyle(
                    fontSize: 14,
                    color: Theme.of(context).textTheme.bodySmall?.color,
                  ),
                ),
                Text(
                  'Tap to minimize',
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).textTheme.bodySmall?.color?.withValues(alpha: 0.6),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Floating upload progress indicator for minimal view
class FloatingUploadProgress extends StatefulWidget {
  final int uploadCount;
  final VoidCallback onTap;

  const FloatingUploadProgress({
    super.key,
    required this.uploadCount,
    required this.onTap,
  });

  @override
  State<FloatingUploadProgress> createState() => _FloatingUploadProgressState();
}

class _FloatingUploadProgressState extends State<FloatingUploadProgress>
    with TickerProviderStateMixin {
  late AnimationController _bounceController;
  late Animation<double> _bounceAnimation;

  @override
  void initState() {
    super.initState();
    _bounceController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    _bounceAnimation = Tween<double>(
      begin: 1.0,
      end: 1.2,
    ).animate(CurvedAnimation(
      parent: _bounceController,
      curve: Curves.elasticOut,
    ));
    
    if (widget.uploadCount > 0) {
      _bounceController.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _bounceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.uploadCount == 0) return const SizedBox.shrink();

    return Positioned(
      bottom: 100,
      right: 20,
      child: AnimatedBuilder(
        animation: _bounceAnimation,
        builder: (context, child) {
          return Transform.scale(
            scale: _bounceAnimation.value,
            child: FloatingActionButton(
              onPressed: widget.onTap,
              backgroundColor: Theme.of(context).primaryColor,
              child: Badge(
                label: Text('${widget.uploadCount}'),
                child: const Icon(
                  Icons.cloud_upload,
                  color: Colors.white,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
