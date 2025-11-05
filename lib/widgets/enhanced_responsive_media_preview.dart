// =============================================================================
// ENHANCED RESPONSIVE MEDIA PREVIEW WIDGET
// =============================================================================
// This widget provides responsive media previews with full-screen functionality
// across all platforms with optimized performance and user experience

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:video_player/video_player.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import '../services/theme_service.dart';
import '../services/logger_service.dart';
import '../utils/responsive_utils.dart';
import '../services/enhanced_unified_media_service.dart';

/// Enhanced responsive media preview widget
class EnhancedResponsiveMediaPreview extends StatefulWidget {
  final String mediaUrl;
  final String mediaType;
  final String? fileName;
  final String? fileSize;
  final bool isCurrentUser;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final bool showFullScreenButton;
  final double? maxWidth;
  final double? maxHeight;

  const EnhancedResponsiveMediaPreview({
    super.key,
    required this.mediaUrl,
    required this.mediaType,
    this.fileName,
    this.fileSize,
    this.isCurrentUser = false,
    this.onTap,
    this.onLongPress,
    this.showFullScreenButton = true,
    this.maxWidth,
    this.maxHeight,
  });

  @override
  State<EnhancedResponsiveMediaPreview> createState() => _EnhancedResponsiveMediaPreviewState();
}

class _EnhancedResponsiveMediaPreviewState extends State<EnhancedResponsiveMediaPreview> {
  VideoPlayerController? _videoController;
  AudioPlayer? _audioPlayer;
  bool _isVideoInitialized = false;
  bool _isAudioInitialized = false;
  bool _isLoading = true;
  bool _hasError = false;
  String _errorMessage = '';
  bool _showControls = true;
  Duration _audioPosition = Duration.zero;
  Duration _audioDuration = Duration.zero;
  bool _isPlaying = false;
  late ThemeService _themeService;

  @override
  void initState() {
    super.initState();
    _themeService = ThemeService.instance;
    _themeService.addListener(() {
      if (mounted) setState(() {});
    });
    _initializeMedia();
  }

  @override
  void dispose() {
    _videoController?.dispose();
    _audioPlayer?.dispose();
    super.dispose();
  }

  Future<void> _initializeMedia() async {
    try {
      setState(() {
        _isLoading = true;
        _hasError = false;
      });

      switch (widget.mediaType) {
        case 'video':
          await _initializeVideo();
          break;
        case 'audio':
        case 'voice':
          await _initializeAudio();
          break;
        case 'image':
        case 'document':
        default:
          setState(() {
            _isLoading = false;
          });
          break;
      }
    } catch (e) {
      Log.e('Error initializing media', 'ENHANCED_RESPONSIVE_MEDIA_PREVIEW', e);
      setState(() {
        _isLoading = false;
        _hasError = true;
        _errorMessage = e.toString();
      });
    }
  }

  Future<void> _initializeVideo() async {
    try {
      _videoController = VideoPlayerController.networkUrl(Uri.parse(_resolveWebSameOriginUrl(widget.mediaUrl)));
      await _videoController!.initialize();
      
      if (mounted) {
        setState(() {
          _isVideoInitialized = true;
          _isLoading = false;
        });
      }
    } catch (e) {
      Log.e('Error initializing video', 'ENHANCED_RESPONSIVE_MEDIA_PREVIEW', e);
      if (mounted) {
        setState(() {
          _isLoading = false;
          _hasError = true;
          _errorMessage = 'Failed to load video';
        });
      }
    }
  }

  Future<void> _initializeAudio() async {
    try {
      _audioPlayer = AudioPlayer();
      await _audioPlayer!.setSourceUrl(_resolveWebSameOriginUrl(widget.mediaUrl));
      
      // Listen to audio position changes
      _audioPlayer!.onPositionChanged.listen((position) {
        if (mounted) {
          setState(() {
            _audioPosition = position;
          });
        }
      });

      // Listen to audio duration changes
      _audioPlayer!.onDurationChanged.listen((duration) {
        if (mounted) {
          setState(() {
            _audioDuration = duration;
          });
        }
      });

      // Listen to player state changes
      _audioPlayer!.onPlayerStateChanged.listen((state) {
        if (mounted) {
          setState(() {
            _isPlaying = state == PlayerState.playing;
          });
        }
      });

      if (mounted) {
        setState(() {
          _isAudioInitialized = true;
          _isLoading = false;
        });
      }
    } catch (e) {
      Log.e('Error initializing audio', 'ENHANCED_RESPONSIVE_MEDIA_PREVIEW', e);
      if (mounted) {
        setState(() {
          _isLoading = false;
          _hasError = true;
          _errorMessage = 'Failed to load audio';
        });
      }
    }
  }

  void _togglePlayPause() {
    if (widget.mediaType == 'video' && _videoController != null) {
      if (_videoController!.value.isPlaying) {
        _videoController!.pause();
      } else {
        _videoController!.play();
      }
    } else if ((widget.mediaType == 'audio' || widget.mediaType == 'voice') && _audioPlayer != null) {
      if (_isPlaying) {
        _audioPlayer!.pause();
      } else {
        _audioPlayer!.resume();
      }
    }
  }

  void _showFullScreen() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EnhancedFullScreenMediaPreview(
          mediaUrl: _resolveWebSameOriginUrl(widget.mediaUrl),
          mediaType: widget.mediaType,
          fileName: widget.fileName,
          fileSize: widget.fileSize,
        ),
      ),
    );
  }

  void _downloadMedia() async {
    try {
      final uri = Uri.parse(_resolveWebSameOriginUrl(widget.mediaUrl));
      
      // For documents, try to open in browser first
      if (widget.mediaType == 'document') {
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        } else {
          _showErrorSnackBar('Cannot open document. Please try downloading manually.');
        }
      } else {
        // For images and videos, try to open in browser
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        } else {
          _showErrorSnackBar('Cannot open media');
        }
      }
    } catch (e) {
      Log.e('Error downloading media', 'ENHANCED_RESPONSIVE_MEDIA_PREVIEW', e);
      _showErrorSnackBar('Failed to download media: ${e.toString()}');
    }
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = ResponsiveUtils.isMobile(context);
    final isTablet = ResponsiveUtils.isTablet(context);
    final isDesktop = ResponsiveUtils.isDesktop(context);

    // Calculate responsive dimensions
    final maxWidth = widget.maxWidth ?? (isMobile ? 200.0 : isTablet ? 300.0 : 400.0);
    final maxHeight = widget.maxHeight ?? (isMobile ? 200.0 : isTablet ? 300.0 : 400.0);

    return Container(
      constraints: BoxConstraints(
        maxWidth: maxWidth,
        maxHeight: maxHeight,
      ),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: GestureDetector(
          onTap: widget.onTap ?? _showFullScreen,
          onLongPress: widget.onLongPress,
          child: _buildMediaContent(),
        ),
      ),
    );
  }

  Widget _buildMediaContent() {
    if (_isLoading) {
      return _buildLoadingWidget();
    }

    if (_hasError) {
      return _buildErrorWidget();
    }

    switch (widget.mediaType) {
      case 'image':
        return _buildImageWidget();
      case 'video':
        return _buildVideoWidget();
      case 'audio':
      case 'voice':
        return _buildAudioWidget();
      case 'document':
        return _buildDocumentWidget();
      default:
        return _buildUnknownWidget();
    }
  }

  Widget _buildLoadingWidget() {
    return Container(
      color: _themeService.isDarkMode ? Colors.grey[800] : Colors.grey[200],
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 8),
            Text(
              'Loading...',
              style: TextStyle(
                color: _themeService.isDarkMode ? Colors.white : Colors.black87,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorWidget() {
    return Container(
      color: _themeService.isDarkMode ? Colors.grey[800] : Colors.grey[200],
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              color: Colors.red,
              size: ResponsiveUtils.getResponsiveIconSize(context),
            ),
            const SizedBox(height: 8),
            Text(
              'Failed to load',
              style: TextStyle(
                color: Colors.red,
                fontSize: ResponsiveUtils.getResponsiveFontSize(context, baseSize: 12),
              ),
            ),
            if (_errorMessage.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                _errorMessage,
                style: TextStyle(
                  color: Colors.red,
                  fontSize: ResponsiveUtils.getResponsiveFontSize(context, baseSize: 10),
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildImageWidget() {
    return Stack(
      children: [
        Image.network(
          _resolveWebSameOriginUrl(widget.mediaUrl),
          fit: BoxFit.cover,
          width: double.infinity,
          height: double.infinity,
          errorBuilder: (context, error, stackTrace) {
            return _buildErrorWidget();
          },
        ),
        if (widget.showFullScreenButton)
          Positioned(
            top: 8,
            right: 8,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(20),
              ),
              child: IconButton(
                onPressed: _showFullScreen,
                icon: const Icon(Icons.fullscreen, color: Colors.white, size: 20),
                tooltip: 'View full screen',
              ),
            ),
          ),
        Positioned(
          bottom: 8,
          left: 8,
          right: 8,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.image, color: Colors.white, size: 16),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    widget.fileName ?? 'Image',
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (widget.fileSize != null) ...[
                  const SizedBox(width: 4),
                  Text(
                    widget.fileSize!,
                    style: const TextStyle(color: Colors.white70, fontSize: 10),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildVideoWidget() {
    if (!_isVideoInitialized || _videoController == null) {
      return _buildErrorWidget();
    }

    return Stack(
      children: [
        AspectRatio(
          aspectRatio: _videoController!.value.aspectRatio,
          child: VideoPlayer(_videoController!),
        ),
        // Video controls overlay
        Positioned.fill(
          child: GestureDetector(
            onTap: _togglePlayPause,
            child: Container(
              color: Colors.transparent,
              child: Center(
                child: AnimatedOpacity(
                  opacity: _showControls ? 1.0 : 0.0,
                  duration: const Duration(milliseconds: 300),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.5),
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      onPressed: _togglePlayPause,
                      icon: Icon(
                        _videoController!.value.isPlaying ? Icons.pause : Icons.play_arrow,
                        color: Colors.white,
                        size: ResponsiveUtils.getResponsiveIconSize(context),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        if (widget.showFullScreenButton)
          Positioned(
            top: 8,
            right: 8,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(20),
              ),
              child: IconButton(
                onPressed: _showFullScreen,
                icon: const Icon(Icons.fullscreen, color: Colors.white, size: 20),
                tooltip: 'View full screen',
              ),
            ),
          ),
        Positioned(
          bottom: 8,
          left: 8,
          right: 8,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.videocam, color: Colors.white, size: 16),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    widget.fileName ?? 'Video',
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (widget.fileSize != null) ...[
                  const SizedBox(width: 4),
                  Text(
                    widget.fileSize!,
                    style: const TextStyle(color: Colors.white70, fontSize: 10),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAudioWidget() {
    if (!_isAudioInitialized || _audioPlayer == null) {
      return _buildErrorWidget();
    }

    return Container(
      color: _themeService.isDarkMode ? Colors.grey[800] : Colors.grey[100],
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            widget.mediaType == 'voice' ? Icons.mic : Icons.audiotrack,
            color: _themeService.isDarkMode ? Colors.white : Colors.black87,
            size: ResponsiveUtils.getResponsiveIconSize(context) * 2,
          ),
          const SizedBox(height: 16),
          Text(
            widget.fileName ?? (widget.mediaType == 'voice' ? 'Voice Message' : 'Audio'),
            style: TextStyle(
              color: _themeService.isDarkMode ? Colors.white : Colors.black87,
              fontSize: ResponsiveUtils.getResponsiveFontSize(context, baseSize: 14),
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          // Audio controls
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                onPressed: _togglePlayPause,
                icon: Icon(
                  _isPlaying ? Icons.pause : Icons.play_arrow,
                  color: _themeService.isDarkMode ? Colors.white : Colors.black87,
                ),
              ),
              IconButton(
                onPressed: _downloadMedia,
                icon: Icon(
                  Icons.download,
                  color: _themeService.isDarkMode ? Colors.white : Colors.black87,
                ),
                tooltip: 'Download',
              ),
            ],
          ),
          // Progress bar
          if (_audioDuration.inSeconds > 0) ...[
            const SizedBox(height: 8),
            Slider(
              value: _audioPosition.inMilliseconds.toDouble(),
              max: _audioDuration.inMilliseconds.toDouble(),
              onChanged: (value) {
                _audioPlayer!.seek(Duration(milliseconds: value.toInt()));
              },
            ),
            Text(
              '${_formatDuration(_audioPosition)} / ${_formatDuration(_audioDuration)}',
              style: TextStyle(
                color: _themeService.isDarkMode ? Colors.white70 : Colors.black54,
                fontSize: ResponsiveUtils.getResponsiveFontSize(context, baseSize: 10),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDocumentWidget() {
    return Container(
      color: _themeService.isDarkMode ? Colors.grey[800] : Colors.grey[100],
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.insert_drive_file,
            color: _themeService.isDarkMode ? Colors.white : Colors.black87,
            size: ResponsiveUtils.getResponsiveIconSize(context) * 2,
          ),
          const SizedBox(height: 16),
          Text(
            widget.fileName ?? 'Document',
            style: TextStyle(
              color: _themeService.isDarkMode ? Colors.white : Colors.black87,
              fontSize: ResponsiveUtils.getResponsiveFontSize(context, baseSize: 14),
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                onPressed: _downloadMedia,
                icon: Icon(
                  Icons.download,
                  color: _themeService.isDarkMode ? Colors.white : Colors.black87,
                ),
                tooltip: 'Download',
              ),
              if (widget.showFullScreenButton)
                IconButton(
                  onPressed: _showFullScreen,
                  icon: Icon(
                    Icons.fullscreen,
                    color: _themeService.isDarkMode ? Colors.white : Colors.black87,
                  ),
                  tooltip: 'View full screen',
                ),
            ],
          ),
          if (widget.fileSize != null) ...[
            const SizedBox(height: 8),
            Text(
              widget.fileSize!,
              style: TextStyle(
                color: _themeService.isDarkMode ? Colors.white70 : Colors.black54,
                fontSize: ResponsiveUtils.getResponsiveFontSize(context, baseSize: 10),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildUnknownWidget() {
    return Container(
      color: _themeService.isDarkMode ? Colors.grey[800] : Colors.grey[200],
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.help_outline,
              color: _themeService.isDarkMode ? Colors.white : Colors.black87,
              size: ResponsiveUtils.getResponsiveIconSize(context),
            ),
            const SizedBox(height: 8),
            Text(
              'Unknown media type',
              style: TextStyle(
                color: _themeService.isDarkMode ? Colors.white : Colors.black87,
                fontSize: ResponsiveUtils.getResponsiveFontSize(context, baseSize: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$minutes:$seconds';
  }
}

/// Enhanced full-screen media preview
class EnhancedFullScreenMediaPreview extends StatefulWidget {
  final String mediaUrl;
  final String mediaType;
  final String? fileName;
  final String? fileSize;

  const EnhancedFullScreenMediaPreview({
    super.key,
    required this.mediaUrl,
    required this.mediaType,
    this.fileName,
    this.fileSize,
  });

  @override
  State<EnhancedFullScreenMediaPreview> createState() => _EnhancedFullScreenMediaPreviewState();
}

class _EnhancedFullScreenMediaPreviewState extends State<EnhancedFullScreenMediaPreview> {
  VideoPlayerController? _videoController;
  AudioPlayer? _audioPlayer;
  bool _isVideoInitialized = false;
  bool _isAudioInitialized = false;
  bool _isLoading = true;
  bool _hasError = false;
  String _errorMessage = '';
  bool _showControls = true;
  Duration _audioPosition = Duration.zero;
  Duration _audioDuration = Duration.zero;
  bool _isPlaying = false;
  late ThemeService _themeService;

  @override
  void initState() {
    super.initState();
    _themeService = ThemeService.instance;
    _themeService.addListener(() {
      if (mounted) setState(() {});
    });
    _initializeMedia();
    _hideControlsAfterDelay();
  }

  @override
  void dispose() {
    _videoController?.dispose();
    _audioPlayer?.dispose();
    super.dispose();
  }

  Future<void> _initializeMedia() async {
    try {
      setState(() {
        _isLoading = true;
        _hasError = false;
      });

      switch (widget.mediaType) {
        case 'video':
          await _initializeVideo();
          break;
        case 'audio':
        case 'voice':
          await _initializeAudio();
          break;
        case 'image':
        case 'document':
        default:
          setState(() {
            _isLoading = false;
          });
          break;
      }
    } catch (e) {
      Log.e('Error initializing media', 'ENHANCED_FULL_SCREEN_MEDIA_PREVIEW', e);
      setState(() {
        _isLoading = false;
        _hasError = true;
        _errorMessage = e.toString();
      });
    }
  }

  Future<void> _initializeVideo() async {
    try {
      _videoController = VideoPlayerController.networkUrl(Uri.parse(_resolveWebSameOriginUrl(widget.mediaUrl)));
      await _videoController!.initialize();
      
      if (mounted) {
        setState(() {
          _isVideoInitialized = true;
          _isLoading = false;
        });
      }
    } catch (e) {
      Log.e('Error initializing video', 'ENHANCED_FULL_SCREEN_MEDIA_PREVIEW', e);
      if (mounted) {
        setState(() {
          _isLoading = false;
          _hasError = true;
          _errorMessage = 'Failed to load video';
        });
      }
    }
  }

  Future<void> _initializeAudio() async {
    try {
      _audioPlayer = AudioPlayer();
      await _audioPlayer!.setSourceUrl(_resolveWebSameOriginUrl(widget.mediaUrl));
      
      _audioPlayer!.onPositionChanged.listen((position) {
        if (mounted) {
          setState(() {
            _audioPosition = position;
          });
        }
      });

      _audioPlayer!.onDurationChanged.listen((duration) {
        if (mounted) {
          setState(() {
            _audioDuration = duration;
          });
        }
      });

      _audioPlayer!.onPlayerStateChanged.listen((state) {
        if (mounted) {
          setState(() {
            _isPlaying = state == PlayerState.playing;
          });
        }
      });

      if (mounted) {
        setState(() {
          _isAudioInitialized = true;
          _isLoading = false;
        });
      }
    } catch (e) {
      Log.e('Error initializing audio', 'ENHANCED_FULL_SCREEN_MEDIA_PREVIEW', e);
      if (mounted) {
        setState(() {
          _isLoading = false;
          _hasError = true;
          _errorMessage = 'Failed to load audio';
        });
      }
    }
  }

  void _hideControlsAfterDelay() {
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        setState(() {
          _showControls = false;
        });
      }
    });
  }

  void _toggleControls() {
    setState(() {
      _showControls = !_showControls;
    });
    if (_showControls) {
      _hideControlsAfterDelay();
    }
  }

  void _togglePlayPause() {
    if (widget.mediaType == 'video' && _videoController != null) {
      if (_videoController!.value.isPlaying) {
        _videoController!.pause();
      } else {
        _videoController!.play();
      }
    } else if ((widget.mediaType == 'audio' || widget.mediaType == 'voice') && _audioPlayer != null) {
      if (_isPlaying) {
        _audioPlayer!.pause();
      } else {
        _audioPlayer!.resume();
      }
    }
  }

  void _downloadMedia() async {
    try {
      final uri = Uri.parse(_resolveWebSameOriginUrl(widget.mediaUrl));
      
      // For documents, try to open in browser first
      if (widget.mediaType == 'document') {
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        } else {
          _showErrorSnackBar('Cannot open document. Please try downloading manually.');
        }
      } else {
        // For images and videos, try to open in browser
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        } else {
          _showErrorSnackBar('Cannot open media');
        }
      }
    } catch (e) {
      Log.e('Error downloading media', 'ENHANCED_FULL_SCREEN_MEDIA_PREVIEW', e);
      _showErrorSnackBar('Failed to download media: ${e.toString()}');
    }
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black.withValues(alpha: 0.5),
        foregroundColor: Colors.white,
        title: Text(
          widget.fileName ?? 'Media Preview',
          style: const TextStyle(fontSize: 16),
        ),
        actions: [
          IconButton(
            onPressed: _downloadMedia,
            icon: const Icon(Icons.download),
            tooltip: 'Download',
          ),
        ],
      ),
      body: GestureDetector(
        onTap: _toggleControls,
        child: Stack(
          children: [
            _buildMediaContent(),
            if (_showControls) _buildControlsOverlay(),
          ],
        ),
      ),
    );
  }

  Widget _buildMediaContent() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.white),
      );
    }

    if (_hasError) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, color: Colors.white, size: 64),
            const SizedBox(height: 16),
            Text(
              'Failed to load media',
              style: const TextStyle(color: Colors.white, fontSize: 18),
            ),
            if (_errorMessage.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                _errorMessage,
                style: const TextStyle(color: Colors.white70, fontSize: 14),
                textAlign: TextAlign.center,
              ),
            ],
          ],
        ),
      );
    }

      switch (widget.mediaType) {
        case 'image':
          return InteractiveViewer(
            minScale: 0.5,
            maxScale: 4.0,
            child: Image.network(
            _resolveWebSameOriginUrl(widget.mediaUrl),
            fit: BoxFit.contain,
            errorBuilder: (context, error, stackTrace) {
              return const Center(
                child: Icon(Icons.broken_image, color: Colors.white, size: 64),
              );
            },
          ),
        );
      case 'video':
        if (_isVideoInitialized && _videoController != null) {
          return AspectRatio(
            aspectRatio: _videoController!.value.aspectRatio,
            child: VideoPlayer(_videoController!),
          );
        }
        return const Center(
          child: Icon(Icons.videocam, color: Colors.white, size: 64),
        );
      case 'audio':
      case 'voice':
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                widget.mediaType == 'voice' ? Icons.mic : Icons.audiotrack,
                color: Colors.white,
                size: 80,
              ),
              const SizedBox(height: 24),
              Text(
                widget.fileName ?? (widget.mediaType == 'voice' ? 'Voice Message' : 'Audio'),
                style: const TextStyle(color: Colors.white, fontSize: 20),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    onPressed: _togglePlayPause,
                    icon: Icon(
                      _isPlaying ? Icons.pause : Icons.play_arrow,
                      color: Colors.white,
                      size: 48,
                    ),
                  ),
                ],
              ),
              if (_audioDuration.inSeconds > 0) ...[
                const SizedBox(height: 24),
                Slider(
                  value: _audioPosition.inMilliseconds.toDouble(),
                  max: _audioDuration.inMilliseconds.toDouble(),
                  onChanged: (value) {
                    _audioPlayer!.seek(Duration(milliseconds: value.toInt()));
                  },
                ),
                Text(
                  '${_formatDuration(_audioPosition)} / ${_formatDuration(_audioDuration)}',
                  style: const TextStyle(color: Colors.white70, fontSize: 14),
                ),
              ],
            ],
          ),
        );
      case 'document':
        final isPdf = (widget.fileName ?? '').toLowerCase().endsWith('.pdf');
        if (isPdf) {
          // In-app PDF preview on mobile with top-right download icon
          return Stack(
            children: [
              Positioned.fill(
                child: _buildMobilePdfViewer(),
              ),
              Positioned(
                top: 16,
                right: 16,
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: IconButton(
                    onPressed: _downloadMedia,
                    icon: const Icon(Icons.download, color: Colors.white),
                    tooltip: 'Download PDF',
                  ),
                ),
              ),
            ],
          );
        }
        // Non-PDF documents: show generic document UI
        final resolvedUrl = _resolveWebSameOriginUrl(widget.mediaUrl);
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.insert_drive_file, color: Colors.white, size: 80),
              const SizedBox(height: 24),
              Text(
                widget.fileName ?? 'Document',
                style: const TextStyle(color: Colors.white, fontSize: 20),
                textAlign: TextAlign.center,
              ),
              if (widget.fileSize != null) ...[
                const SizedBox(height: 8),
                Text(
                  widget.fileSize!,
                  style: const TextStyle(color: Colors.white70, fontSize: 14),
                ),
              ],
              if (kIsWeb) ...[
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: () async {
                    try {
                      final uri = Uri.parse(resolvedUrl);
                      if (await canLaunchUrl(uri)) {
                        await launchUrl(uri, mode: LaunchMode.platformDefault);
                      }
                    } catch (e) {
                      _downloadMedia();
                    }
                  },
                  icon: const Icon(Icons.open_in_browser),
                  label: const Text('Open'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.black87,
                  ),
                ),
              ],
            ],
          ),
        );
      default:
        return const Center(
          child: Icon(Icons.help_outline, color: Colors.white, size: 64),
        );
    }
  }

  // =============================
  // PDF VIEWER (MOBILE)
  // =============================
  Widget _buildMobilePdfViewer() {
    // Stream directly from ngrok/server; add ngrok header to bypass warning
    final headers = <String, String>{
      'ngrok-skip-browser-warning': 'true',
    };
    return SfPdfViewer.network(
      widget.mediaUrl,
      headers: headers,
    );
  }

  Widget _buildControlsOverlay() {
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.transparent,
              Colors.black.withValues(alpha: 0.7),
            ],
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            IconButton(
              onPressed: _togglePlayPause,
              icon: Icon(
                widget.mediaType == 'video' 
                    ? (_videoController?.value.isPlaying == true ? Icons.pause : Icons.play_arrow)
                    : (_isPlaying ? Icons.pause : Icons.play_arrow),
                color: Colors.white,
                size: 32,
              ),
            ),
            Text(
              widget.fileName ?? 'Media',
              style: const TextStyle(color: Colors.white, fontSize: 16),
              overflow: TextOverflow.ellipsis,
            ),
            IconButton(
              onPressed: _downloadMedia,
              icon: const Icon(Icons.download, color: Colors.white, size: 32),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$minutes:$seconds';
  }
}

// Resolve media URL to same-origin on web for direct loading/downloading
String _resolveWebSameOriginUrl(String url) {
  if (!kIsWeb) return url; // Mobile: return as-is (ngrok URLs preserved)
  try {
    final parsed = Uri.parse(url);
    if (parsed.scheme == 'blob' || parsed.scheme == 'data') return url;
    if (parsed.host.contains('firebasestorage.googleapis.com')) return url;
    
    final base = Uri.base;
    final p = parsed.path;

    // On web, convert ngrok URLs to local network URLs
    if (parsed.host.contains('ngrok') || parsed.host.contains('ngrok-free.app') || parsed.host.contains('ngrok.app')) {
      // Extract the path and convert to same-origin (local network)
      return Uri.parse('${base.origin}$p${parsed.hasQuery ? '?${parsed.query}' : ''}').toString();
    }

    // Prefer rewriting known server paths to same-origin (local network)
    if (p.startsWith('/uploads') || p.contains('/uploads/')) {
      return Uri.parse('${base.origin}$p${parsed.hasQuery ? '?${parsed.query}' : ''}').toString();
    }

    // Handle legacy /chat_media URLs by prefixing /uploads
    if (p.startsWith('/chat_media') || p.contains('/chat_media/')) {
      final adjustedPath = '/uploads' + (p.startsWith('/') ? p : '/$p');
      return Uri.parse('${base.origin}$adjustedPath${parsed.hasQuery ? '?${parsed.query}' : ''}').toString();
    }

    // Proxy API calls to same-origin (local network)
    if (p.startsWith('/api/')) {
      return Uri.parse('${base.origin}$p${parsed.hasQuery ? '?${parsed.query}' : ''}').toString();
    }

    // If already same-origin (local network), leave as-is
    final originUrl = '${parsed.scheme}://${parsed.host}${parsed.hasPort ? ':${parsed.port}' : ''}';
    if (originUrl == base.origin) return url;
    
    // For external URLs that aren't ngrok or same-origin, leave as-is
    return url;
  } catch (_) {
    return url;
  }
}
