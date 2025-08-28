import 'package:flutter/material.dart';
import 'dart:async';
import '../services/upload_progress_service.dart';

/// Beautiful upload progress indicator widget
class UploadProgressIndicator extends StatefulWidget {
  final String uploadId;
  final String fileName;
  final String mediaType;
  final VoidCallback? onCancel;
  final VoidCallback? onRetry;

  const UploadProgressIndicator({
    super.key,
    required this.uploadId,
    required this.fileName,
    required this.mediaType,
    this.onCancel,
    this.onRetry,
  });

  @override
  State<UploadProgressIndicator> createState() => _UploadProgressIndicatorState();
}

class _UploadProgressIndicatorState extends State<UploadProgressIndicator>
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  late AnimationController _pulseController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _pulseAnimation;
  
  double _progress = 0.0;
  bool _isCompleted = false;
  bool _hasError = false;
  String? _errorMessage;
  StreamSubscription<double>? _progressSubscription;

  @override
  void initState() {
    super.initState();
    
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    
    _scaleAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.elasticOut,
    ));
    
    _pulseAnimation = Tween<double>(
      begin: 1.0,
      end: 1.1,
    ).animate(CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    ));
    
    _animationController.forward();
    _startProgressTracking();
  }

  void _startProgressTracking() {
    final progressStream = UploadProgressService.getProgressStream(widget.uploadId);
    if (progressStream != null) {
      _progressSubscription = progressStream.listen(
        (progress) {
          setState(() {
            _progress = progress;
            if (progress >= 1.0) {
              _isCompleted = true;
              _pulseController.repeat(reverse: true);
            }
          });
        },
        onError: (error) {
          setState(() {
            _hasError = true;
            _errorMessage = error.toString();
          });
        },
      );
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    _pulseController.dispose();
    _progressSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return ScaleTransition(
      scale: _scaleAnimation,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? Colors.grey.shade800 : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: _hasError 
                ? Colors.red.shade300 
                : _isCompleted 
                    ? Colors.green.shade300 
                    : Colors.blue.shade300,
            width: 2,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with icon and filename
            Row(
              children: [
                _buildMediaIcon(),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.fileName,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        _getStatusText(),
                        style: TextStyle(
                          fontSize: 14,
                          color: _getStatusColor(isDark),
                        ),
                      ),
                    ],
                  ),
                ),
                if (_hasError && widget.onRetry != null)
                  IconButton(
                    onPressed: widget.onRetry,
                    icon: Icon(
                      Icons.refresh,
                      color: Colors.orange.shade600,
                      size: 20,
                    ),
                    tooltip: 'Retry',
                  ),
                if (!_isCompleted && !_hasError && widget.onCancel != null)
                  IconButton(
                    onPressed: widget.onCancel,
                    icon: Icon(
                      Icons.close,
                      color: Colors.red.shade600,
                      size: 20,
                    ),
                    tooltip: 'Cancel',
                  ),
              ],
            ),
            
            const SizedBox(height: 16),
            
            // Progress bar
            if (!_isCompleted && !_hasError) ...[
              LinearProgressIndicator(
                value: _progress,
                backgroundColor: isDark ? Colors.grey.shade700 : Colors.grey.shade300,
                valueColor: AlwaysStoppedAnimation<Color>(
                  _getProgressColor(),
                ),
                minHeight: 8,
                borderRadius: BorderRadius.circular(4),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${(_progress * 100).toStringAsFixed(1)}%',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: isDark ? Colors.white70 : Colors.black54,
                    ),
                  ),
                  if (_progress > 0)
                    Text(
                      _getEstimatedTime(),
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? Colors.white54 : Colors.black45,
                      ),
                    ),
                ],
              ),
            ],
            
            // Success or error state
            if (_isCompleted) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.green.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.check_circle,
                      color: Colors.green.shade600,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Upload completed successfully!',
                      style: TextStyle(
                        color: Colors.green.shade700,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
            
            if (_hasError) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.red.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.error,
                      color: Colors.red.shade600,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _errorMessage ?? 'Upload failed',
                        style: TextStyle(
                          color: Colors.red.shade700,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildMediaIcon() {
    IconData iconData;
    Color iconColor;
    
    switch (widget.mediaType.toLowerCase()) {
      case 'image':
        iconData = Icons.image;
        iconColor = Colors.blue.shade600;
        break;
      case 'video':
        iconData = Icons.videocam;
        iconColor = Colors.purple.shade600;
        break;
      case 'audio':
        iconData = Icons.audiotrack;
        iconColor = Colors.orange.shade600;
        break;
      case 'document':
        iconData = Icons.description;
        iconColor = Colors.green.shade600;
        break;
      default:
        iconData = Icons.attach_file;
        iconColor = Colors.grey.shade600;
    }
    
    return AnimatedBuilder(
      animation: _pulseAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: _isCompleted ? _pulseAnimation.value : 1.0,
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              iconData,
              color: iconColor,
              size: 24,
            ),
          ),
        );
      },
    );
  }

  String _getStatusText() {
    if (_hasError) return 'Upload failed';
    if (_isCompleted) return 'Upload completed';
    if (_progress > 0) return 'Uploading...';
    return 'Preparing upload...';
  }

  Color _getStatusColor(bool isDark) {
    if (_hasError) return Colors.red.shade600;
    if (_isCompleted) return Colors.green.shade600;
    return isDark ? Colors.white70 : Colors.black54;
  }

  Color _getProgressColor() {
    if (_progress < 0.3) return Colors.blue.shade400;
    if (_progress < 0.7) return Colors.orange.shade400;
    return Colors.green.shade400;
  }

  String _getEstimatedTime() {
    if (_progress <= 0) return '';
    
    // Simple estimation based on progress
    final remainingProgress = 1.0 - _progress;
    final estimatedSeconds = (remainingProgress * 10).round(); // Rough estimate
    
    if (estimatedSeconds < 60) {
      return '~${estimatedSeconds}s remaining';
    } else {
      final minutes = (estimatedSeconds / 60).round();
      return '~${minutes}m remaining';
    }
  }
}
