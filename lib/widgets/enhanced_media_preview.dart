import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/logger_service.dart';

/// Enhanced media preview widget with fullscreen display
class EnhancedMediaPreview extends StatefulWidget {
  final String mediaUrl;
  final String mediaType;
  final String? fileName;
  final String? fileSize;
  final bool isCurrentUser;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  const EnhancedMediaPreview({
    super.key,
    required this.mediaUrl,
    required this.mediaType,
    this.fileName,
    this.fileSize,
    this.isCurrentUser = false,
    this.onTap,
    this.onLongPress,
  });

  @override
  State<EnhancedMediaPreview> createState() => _EnhancedMediaPreviewState();
}

class _EnhancedMediaPreviewState extends State<EnhancedMediaPreview> {
  VideoPlayerController? _videoController;
  bool _isVideoInitialized = false;
  bool _isLoading = true;
  bool _hasError = false;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _initializeMedia();
  }

  @override
  void dispose() {
    _videoController?.dispose();
    super.dispose();
  }

  Future<void> _initializeMedia() async {
    try {
      setState(() {
        _isLoading = true;
        _hasError = false;
      });

      if (widget.mediaType == 'video') {
        await _initializeVideo();
      } else {
        // For images and documents, just mark as loaded
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      Log.e('Error initializing media', 'ENHANCED_MEDIA_PREVIEW', e);
      setState(() {
        _isLoading = false;
        _hasError = true;
        _errorMessage = e.toString();
      });
    }
  }

  Future<void> _initializeVideo() async {
    try {
      _videoController = VideoPlayerController.networkUrl(Uri.parse(widget.mediaUrl));
      await _videoController!.initialize();
      
      if (mounted) {
        setState(() {
          _isVideoInitialized = true;
          _isLoading = false;
        });
      }
    } catch (e) {
      Log.e('Error initializing video', 'ENHANCED_MEDIA_PREVIEW', e);
      setState(() {
        _isLoading = false;
        _hasError = true;
        _errorMessage = 'Failed to load video: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    try {
      final theme = Theme.of(context);
      final isDark = theme.brightness == Brightness.dark;
      final screenSize = MediaQuery.of(context).size;

      return Material(
        color: Colors.transparent,
        child: GestureDetector(
          onTap: widget.onTap,
          onLongPress: widget.onLongPress,
          child: Container(
            // Fullscreen constraints - adapts to device screen size
            constraints: BoxConstraints(
              maxWidth: screenSize.width,  // Full screen width
              maxHeight: screenSize.height * 0.85, // 85% of screen height
              minWidth: screenSize.width * 0.95,  // 95% of screen width
              minHeight: screenSize.height * 0.7, // 70% of screen height
            ),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
                                                  boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.3),
                blurRadius: 15,
                offset: const Offset(0, 8),
              ),
            ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: _buildMediaContent(theme, isDark, screenSize),
            ),
          ),
        ),
      );
    } catch (e) {
      Log.e('Error building EnhancedMediaPreview', 'ENHANCED_MEDIA_PREVIEW', e);
      return Material(
        color: Colors.red.shade100,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.error_outline,
                size: 64,
                color: Colors.red.shade600,
              ),
              const SizedBox(height: 16),
              Text(
                'Error Loading Media',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.red.shade800,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Please try again',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.red.shade600,
                ),
              ),
            ],
          ),
        ),
      );
    }
  }

  Widget _buildMediaContent(ThemeData theme, bool isDark, Size screenSize) {
    try {
      if (_isLoading) {
        return _buildLoadingState(theme, isDark, screenSize);
      }

      if (_hasError) {
        return _buildErrorState(theme, isDark, screenSize);
      }

      switch (widget.mediaType) {
        case 'image':
          return _buildImageContent(theme, isDark, screenSize);
        case 'video':
          return _buildVideoContent(theme, isDark, screenSize);
        case 'document':
          return _buildDocumentContent(theme, isDark, screenSize);
        case 'audio':
          return _buildAudioContent(theme, isDark, screenSize);
        default:
          return _buildUnknownContent(theme, isDark, screenSize);
      }
    } catch (e) {
      Log.e('Error building media content', 'ENHANCED_MEDIA_PREVIEW', e);
      return _buildErrorState(theme, isDark, screenSize);
    }
  }

  Widget _buildLoadingState(ThemeData theme, bool isDark, Size screenSize) {
    return Container(
      width: screenSize.width,
      height: screenSize.height * 0.85,
      decoration: BoxDecoration(
        color: isDark ? Colors.grey.shade800 : Colors.grey.shade200,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(theme.colorScheme.primary),
            strokeWidth: 4,
          ),
          const SizedBox(height: 24),
          Text(
            'Loading ${widget.mediaType}...',
            style: TextStyle(
              color: isDark ? Colors.white70 : Colors.grey.shade700,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(ThemeData theme, bool isDark, Size screenSize) {
    return Container(
      width: screenSize.width,
      height: screenSize.height * 0.85,
      decoration: BoxDecoration(
        color: isDark ? Colors.red.shade900 : Colors.red.shade50,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? Colors.red.shade700 : Colors.red.shade200,
          width: 2,
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline,
            size: 80,
            color: isDark ? Colors.red.shade300 : Colors.red.shade600,
          ),
          const SizedBox(height: 24),
          Text(
            'Failed to load',
            style: TextStyle(
              color: isDark ? Colors.red.shade300 : Colors.red.shade700,
              fontSize: 24,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            _errorMessage,
            style: TextStyle(
              color: isDark ? Colors.red.shade400 : Colors.red.shade600,
              fontSize: 16,
            ),
            textAlign: TextAlign.center,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 32),
          ElevatedButton.icon(
            onPressed: _initializeMedia,
            icon: const Icon(Icons.refresh, size: 24),
            label: const Text('Retry'),
            style: ElevatedButton.styleFrom(
              backgroundColor: isDark ? Colors.red.shade700 : Colors.red.shade100,
              foregroundColor: isDark ? Colors.white : Colors.red.shade700,
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(25),
              ),
              textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImageContent(ThemeData theme, bool isDark, Size screenSize) {
    return Stack(
      children: [
        // Fullscreen image
        Image.network(
          widget.mediaUrl,
          fit: BoxFit.contain,
          width: screenSize.width,
          height: screenSize.height * 0.85,
          loadingBuilder: (context, child, loadingProgress) {
            if (loadingProgress == null) return child;
            return Container(
              width: screenSize.width,
              height: screenSize.height * 0.85,
              decoration: BoxDecoration(
                color: isDark ? Colors.grey.shade800 : Colors.grey.shade200,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Center(
                child: CircularProgressIndicator(
                  value: loadingProgress.expectedTotalBytes != null
                      ? loadingProgress.cumulativeBytesLoaded / 
                        loadingProgress.expectedTotalBytes!
                      : null,
                  valueColor: AlwaysStoppedAnimation<Color>(theme.colorScheme.primary),
                  strokeWidth: 4,
                ),
              ),
            );
          },
          errorBuilder: (context, error, stackTrace) {
            return _buildErrorState(theme, isDark, screenSize);
          },
        ),
        // Media type indicator
        Positioned(
          top: 24,
          right: 24,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.8),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.photo,
                  color: Colors.white,
                  size: 24,
                ),
                const SizedBox(width: 8),
                Text(
                  'IMAGE',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ),
        // File info overlay
        if (widget.fileName != null || widget.fileSize != null)
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.8),
                  ],
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (widget.fileName != null)
                    Text(
                      widget.fileName!,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  if (widget.fileSize != null)
                    Text(
                      widget.fileSize!,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.9),
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildVideoContent(ThemeData theme, bool isDark, Size screenSize) {
    if (!_isVideoInitialized || _videoController == null) {
      return _buildVideoPlaceholder(theme, isDark, screenSize);
    }

    return Stack(
      children: [
        // Fullscreen video player
        SizedBox(
          width: screenSize.width,
          height: screenSize.height * 0.85,
          child: _buildCustomVideoPlayer(theme, isDark),
        ),
        // Media type indicator
        Positioned(
          top: 24,
          right: 24,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.8),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.videocam,
                  color: Colors.white,
                  size: 24,
                ),
                const SizedBox(width: 8),
                Text(
                  'VIDEO',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCustomVideoPlayer(ThemeData theme, bool isDark) {
    return Stack(
      alignment: Alignment.center,
      children: [
        AspectRatio(
          aspectRatio: _videoController!.value.aspectRatio,
          child: VideoPlayer(_videoController!),
        ),
        // Custom video controls
        Container(
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(25),
          ),
          child: IconButton(
            onPressed: () {
              setState(() {
                if (_videoController!.value.isPlaying) {
                  _videoController!.pause();
                } else {
                  _videoController!.play();
                }
              });
            },
            icon: Icon(
              _videoController!.value.isPlaying ? Icons.pause : Icons.play_arrow,
              color: Colors.white,
              size: 48,
            ),
            iconSize: 48,
          ),
        ),
      ],
    );
  }

  Widget _buildVideoPlaceholder(ThemeData theme, bool isDark, Size screenSize) {
    return Container(
      width: screenSize.width,
      height: screenSize.height * 0.85,
      decoration: BoxDecoration(
        color: isDark ? Colors.grey.shade800 : Colors.grey.shade200,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Icon(
            Icons.videocam,
            size: 120,
            color: isDark ? Colors.grey.shade600 : Colors.grey.shade400,
          ),
          if (widget.fileName != null)
            Positioned(
              bottom: 32,
              left: 32,
              right: 32,
              child: Text(
                widget.fileName!,
                style: TextStyle(
                  color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildDocumentContent(ThemeData theme, bool isDark, Size screenSize) {
    return Container(
      width: screenSize.width,
      height: screenSize.height * 0.85,
      decoration: BoxDecoration(
        color: isDark ? Colors.grey.shade800 : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? Colors.grey.shade700 : Colors.grey.shade300,
          width: 2,
        ),
      ),
      child: InkWell(
        onTap: () => _openDocument(widget.mediaUrl),
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(30),
                ),
                child: Icon(
                  _getDocumentIcon(widget.fileName ?? ''),
                  color: theme.colorScheme.primary,
                  size: 60,
                ),
              ),
              const SizedBox(height: 32),
              if (widget.fileName != null)
                Text(
                  widget.fileName!,
                  style: TextStyle(
                    color: isDark ? Colors.white : Colors.black87,
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                ),
              if (widget.fileSize != null) ...[
                const SizedBox(height: 16),
                Text(
                  widget.fileSize!,
                  style: TextStyle(
                    color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                    fontSize: 18,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
              const SizedBox(height: 32),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary,
                  borderRadius: BorderRadius.circular(25),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.download,
                      color: Colors.white,
                      size: 24,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Open Document',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAudioContent(ThemeData theme, bool isDark, Size screenSize) {
    return Container(
      width: screenSize.width,
      height: screenSize.height * 0.85,
      decoration: BoxDecoration(
        color: isDark ? Colors.grey.shade800 : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? Colors.grey.shade700 : Colors.grey.shade300,
          width: 2,
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 120,
            height: 120,
            margin: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(30),
            ),
            child: Icon(
              Icons.audiotrack,
              color: theme.colorScheme.primary,
              size: 60,
            ),
          ),
          const SizedBox(height: 32),
          Text(
            'Audio Message',
            style: TextStyle(
              color: isDark ? Colors.white : Colors.black87,
              fontSize: 28,
              fontWeight: FontWeight.w700,
            ),
          ),
          if (widget.fileSize != null) ...[
            const SizedBox(height: 16),
            Text(
              widget.fileSize!,
              style: TextStyle(
                color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                fontSize: 18,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
          const SizedBox(height: 32),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            decoration: BoxDecoration(
              color: theme.colorScheme.primary,
              borderRadius: BorderRadius.circular(25),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.play_arrow,
                  color: Colors.white,
                  size: 24,
                ),
                const SizedBox(width: 8),
                Text(
                  'Play Audio',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUnknownContent(ThemeData theme, bool isDark, Size screenSize) {
    return Container(
      width: screenSize.width,
      height: screenSize.height * 0.85,
      decoration: BoxDecoration(
        color: isDark ? Colors.grey.shade800 : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? Colors.grey.shade700 : Colors.grey.shade300,
          width: 2,
        ),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.file_present,
              size: 80,
              color: isDark ? Colors.grey.shade600 : Colors.grey.shade400,
            ),
            const SizedBox(height: 24),
            Text(
              'Unknown File Type',
              style: TextStyle(
                color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                fontSize: 24,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'This file type is not supported',
              style: TextStyle(
                color: isDark ? Colors.grey.shade500 : Colors.grey.shade500,
                fontSize: 16,
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _getDocumentIcon(String fileName) {
    final extension = fileName.split('.').last.toLowerCase();
    switch (extension) {
      case 'pdf':
        return Icons.picture_as_pdf;
      case 'doc':
      case 'docx':
        return Icons.description;
      case 'xls':
      case 'xlsx':
        return Icons.table_chart;
      case 'ppt':
      case 'pptx':
        return Icons.slideshow;
      case 'txt':
        return Icons.text_snippet;
      default:
        return Icons.insert_drive_file;
    }
  }

  Future<void> _openDocument(String url) async {
    try {
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      Log.e('Error opening document', 'ENHANCED_MEDIA_PREVIEW', e);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error opening document: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
