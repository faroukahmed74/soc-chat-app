// =============================================================================
// ENHANCED MEDIA PREVIEW WIDGET (FIXED)
// =============================================================================

import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import 'package:video_player/video_player.dart';

import 'dart:html' if (dart.library.io) '../widgets/html_stub.dart' as html;

import '../services/logger_service.dart';
import '../services/media_cache_service.dart';
import '../services/media_download_manager.dart' show MediaDownloadManager, DownloadInfo, DownloadState;
import '../services/media_download_service.dart';
import '../services/theme_service.dart';
import '../services/logger_service.dart';
import '../utils/responsive_utils.dart';
import 'mobile_pdf_thumbnail.dart';
import 'web_pdf_thumbnail.dart';
import 'whatsapp_download_indicator.dart';
import 'cached_network_image_widget.dart';

/// =============================================================================
/// MAIN WIDGET
/// =============================================================================

class EnhancedMediaPreview extends StatefulWidget {
  final String mediaUrl;
  final String mediaType;
  final String? fileName;
  final String? fileSize;
  final VoidCallback? onTap;
  final bool showFullScreenButton;
  final bool isCurrentUser;
  final double? maxWidth;
  final double? maxHeight;
  final bool enableRetry;

  const EnhancedMediaPreview({
    super.key,
    required this.mediaUrl,
    required this.mediaType,
    this.fileName,
    this.fileSize,
    this.onTap,
    this.showFullScreenButton = true,
    this.isCurrentUser = false,
    this.maxWidth,
    this.maxHeight,
    this.enableRetry = true,
  });

  @override
  State<EnhancedMediaPreview> createState() => _EnhancedMediaPreviewState();
}

class _EnhancedMediaPreviewState extends State<EnhancedMediaPreview> {
  late final ThemeService _themeService;
  DownloadInfo? _downloadInfo;
  StreamSubscription<DownloadInfo>? _downloadSubscription;

  @override
  void initState() {
    super.initState();
    _themeService = ThemeService.instance;
    _setupDownloadListener();
  }

  @override
  void dispose() {
    _downloadSubscription?.cancel();
    super.dispose();
  }

  void _setupDownloadListener() {
    final resolvedUrl = _resolveWebSameOriginUrl(widget.mediaUrl);
    // Check if download is already in progress
    final existingInfo = MediaDownloadManager().getDownloadInfo(resolvedUrl);
    if (existingInfo != null) {
      setState(() {
        _downloadInfo = existingInfo;
      });
    }
    
    final stream = MediaDownloadManager().getProgressStream(resolvedUrl);
    if (stream != null) {
      _downloadSubscription?.cancel();
      _downloadSubscription = stream.listen((info) {
        if (mounted) {
          setState(() {
            _downloadInfo = info;
          });
        }
      });
    }
  }

  String _resolveWebSameOriginUrl(String url) {
    if (kIsWeb) {
      return url;
    }
    return url;
  }

  Future<void> _downloadMedia() async {
    if (kIsWeb) {
      final uri = Uri.parse(widget.mediaUrl);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
      return;
    }

    final resolvedUrl = _resolveWebSameOriginUrl(widget.mediaUrl);
    
    // Check if already downloading
    if (MediaDownloadManager().isDownloading(resolvedUrl)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Download already in progress')),
      );
      return;
    }

    // Setup listener for this download
    _setupDownloadListener();

    // Start download using manager
    MediaDownloadManager().download(
      url: resolvedUrl,
      mediaType: widget.mediaType,
      fileName: widget.fileName,
      onProgress: (info) {
        if (mounted) {
          setState(() {
            _downloadInfo = info;
          });
        }
      },
    ).then((successMessage) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(successMessage),
            backgroundColor: Colors.green,
          ),
        );
        // Auto-hide indicator after 2 seconds
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) {
            setState(() {
              _downloadInfo = null;
            });
          }
        });
      }
    }).catchError((e) {
      Log.e('Error downloading media', 'ENHANCED_MEDIA_PREVIEW', e);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to download: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
        // Auto-hide indicator after 3 seconds on error
        Future.delayed(const Duration(seconds: 3), () {
          if (mounted) {
            setState(() {
              _downloadInfo = null;
            });
          }
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: _buildContent(),
    );
  }

  Widget _buildContent() {
    switch (widget.mediaType) {
      case 'image':
        return _buildImage();
      case 'video':
        return _buildVideo();
      case 'audio':
      case 'voice':
        return _buildAudio();
      case 'document':
        return _buildDocument();
      default:
        return _buildUnknown();
    }
  }

  /// =============================================================================
  /// IMAGE
  /// =============================================================================

  Widget _buildImage() {
    return Stack(
      children: [
        CachedNetworkImageWidget(
          imageUrl: widget.mediaUrl,
          fit: BoxFit.cover,
          width: double.infinity,
          height: double.infinity,
          errorWidget: _error('Failed to load image'),
          useCache: true,
        ),

        _downloadButton(),

        if (widget.showFullScreenButton) _fullscreenButton(),

        // WhatsApp-style inline download progress indicator
        if (_downloadInfo != null && 
            (_downloadInfo!.state == DownloadState.downloading || 
             _downloadInfo!.state == DownloadState.saving))
          Positioned(
            top: 8,
            right: widget.showFullScreenButton ? 56 : 8,
            child: WhatsAppDownloadIndicator(
              progress: _downloadInfo!.progress,
              statusMessage: _downloadInfo!.statusMessage,
              onCancel: () {
                MediaDownloadManager().cancel(_resolveWebSameOriginUrl(widget.mediaUrl));
                setState(() {
                  _downloadInfo = null;
                });
              },
            ),
          ),

        _bottomInfoBar(Icons.image, widget.fileName ?? 'Image'),
      ],
    );
  }

  /// =============================================================================
  /// VIDEO
  /// =============================================================================

  Widget _buildVideo() {
    return _VideoThumbnailBuilder(
      mediaUrl: widget.mediaUrl,
      fileName: widget.fileName,
      fileSize: widget.fileSize,
      onTap: widget.onTap,
      onDownload: _downloadMedia,
      showFullScreenButton: widget.showFullScreenButton,
      themeService: _themeService,
      downloadInfo: _downloadInfo,
      onCancelDownload: () {
        MediaDownloadManager().cancel(_resolveWebSameOriginUrl(widget.mediaUrl));
        setState(() {
          _downloadInfo = null;
        });
      },
    );
  }

  /// =============================================================================
  /// AUDIO
  /// =============================================================================

  Widget _buildAudio() {
    return Stack(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: _themeService.isDarkMode ? Colors.grey[800] : Colors.grey[200],
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Icon(Icons.play_arrow,
                  color: _themeService.isDarkMode ? Colors.white : Colors.black),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  widget.fileName ?? 'Audio',
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
        _downloadButton(),
        // WhatsApp-style inline download progress indicator
        if (_downloadInfo != null && 
            (_downloadInfo!.state == DownloadState.downloading || 
             _downloadInfo!.state == DownloadState.saving))
          Positioned(
            top: 8,
            right: 8,
            child: WhatsAppDownloadIndicator(
              progress: _downloadInfo!.progress,
              statusMessage: _downloadInfo!.statusMessage,
              onCancel: () {
                MediaDownloadManager().cancel(_resolveWebSameOriginUrl(widget.mediaUrl));
                setState(() {
                  _downloadInfo = null;
                });
              },
            ),
          ),
      ],
    );
  }

  /// =============================================================================
  /// DOCUMENT
  /// =============================================================================

  Widget _buildDocument() {
    // Check if it's a PDF by filename extension or by mediaUrl
    final fileName = widget.fileName ?? '';
    final mediaUrl = widget.mediaUrl.toLowerCase();
    final isPdf = fileName.toLowerCase().endsWith('.pdf') || 
                  mediaUrl.contains('.pdf') || 
                  mediaUrl.contains('application/pdf');

    return Stack(
      children: [
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            color: _themeService.isDarkMode ? Colors.grey[800] : Colors.grey[200],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                height: 180,
                child: isPdf
                    ? (kIsWeb
                        ? WebPdfThumbnail(
                            url: widget.mediaUrl,
                            width: double.infinity,
                            height: 180,
                            borderRadius:
                                const BorderRadius.vertical(top: Radius.circular(12)),
                          )
                        : MobilePdfThumbnail(
                            url: widget.mediaUrl,
                            width: double.infinity,
                            height: 180,
                            borderRadius:
                                const BorderRadius.vertical(top: Radius.circular(12)),
                          ))
                    : Center(
                        child: Icon(Icons.insert_drive_file, size: 64),
                      ),
              ),
              // PDF filename displayed below the thumbnail
              if (isPdf && widget.fileName != null)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  child: Text(
                    widget.fileName!,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: ResponsiveUtils.getResponsiveFontSize(context, baseSize: 14),
                      color: _themeService.isDarkMode ? Colors.white : Colors.black87,
                    ),
                  ),
                ),
              // For non-PDF documents, show filename in the padding section
              if (!isPdf)
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    children: [
                      Text(
                        widget.fileName ?? 'Document',
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: ResponsiveUtils.getResponsiveFontSize(context, baseSize: 14),
                          color: _themeService.isDarkMode ? Colors.white : Colors.black87,
                        ),
                      ),
                    if (widget.fileSize != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        widget.fileSize!,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: ResponsiveUtils.getResponsiveFontSize(context, baseSize: 10),
                          color: _themeService.isDarkMode ? Colors.white70 : Colors.black54,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
        _downloadButton(),
        if (widget.showFullScreenButton) _fullscreenButton(),
        // WhatsApp-style inline download progress indicator
        if (_downloadInfo != null && 
            (_downloadInfo!.state == DownloadState.downloading || 
             _downloadInfo!.state == DownloadState.saving))
          Positioned(
            top: 8,
            right: widget.showFullScreenButton ? 56 : 8,
            child: WhatsAppDownloadIndicator(
              progress: _downloadInfo!.progress,
              statusMessage: _downloadInfo!.statusMessage,
              onCancel: () {
                MediaDownloadManager().cancel(_resolveWebSameOriginUrl(widget.mediaUrl));
                setState(() {
                  _downloadInfo = null;
                });
              },
            ),
          ),
      ],
    );
  }

  /// =============================================================================
  /// HELPERS
  /// =============================================================================

  Widget _downloadButton() {
    return Positioned(
      top: 8,
      left: 8,
      child: _circleButton(Icons.download, _downloadMedia),
    );
  }

  Widget _fullscreenButton() {
    return Positioned(
      top: 8,
      right: 8,
      child: _circleButton(Icons.fullscreen, widget.onTap),
    );
  }

  Widget _circleButton(IconData icon, VoidCallback? onTap) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.7),
        shape: BoxShape.circle,
      ),
      child: IconButton(
        onPressed: onTap,
        icon: Icon(icon, color: Colors.white),
      ),
    );
  }

  Widget _bottomInfoBar(IconData icon, String title) {
    return Positioned(
      bottom: 8,
      left: 8,
      right: 8,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.7),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(icon, color: Colors.white, size: 16),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(color: Colors.white, fontSize: 12),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _error(String msg) {
    return Center(
      child: Text(msg, style: const TextStyle(color: Colors.red)),
    );
  }

  Widget _buildUnknown() {
    return const Center(child: Icon(Icons.help_outline));
  }
}

/// =============================================================================
/// VIDEO THUMBNAIL BUILDER (WITH FIRST FRAME EXTRACTION)
/// =============================================================================

class _VideoThumbnailBuilder extends StatefulWidget {
  final String mediaUrl;
  final String? fileName;
  final String? fileSize;
  final VoidCallback? onTap;
  final VoidCallback? onDownload;
  final bool showFullScreenButton;
  final ThemeService themeService;
  final DownloadInfo? downloadInfo;
  final VoidCallback? onCancelDownload;

  const _VideoThumbnailBuilder({
    required this.mediaUrl,
    required this.themeService,
    this.fileName,
    this.fileSize,
    this.onTap,
    this.onDownload,
    this.showFullScreenButton = true,
    this.downloadInfo,
    this.onCancelDownload,
  });

  @override
  State<_VideoThumbnailBuilder> createState() => _VideoThumbnailBuilderState();
}

class _VideoThumbnailBuilderState extends State<_VideoThumbnailBuilder> {
  VideoPlayerController? _controller;
  bool _isInitialized = false;
  bool _isLoading = true;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _initializeVideo();
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _initializeVideo() async {
    try {
      setState(() {
        _isLoading = true;
        _hasError = false;
      });

      final videoUrl = _resolveWebSameOriginUrl(widget.mediaUrl);
      
      // Add headers for Android, especially for ngrok URLs
      final headers = <String, String>{};
      if (!kIsWeb) {
        // Add ngrok header if URL contains ngrok (required for Android 10+)
        if (videoUrl.contains('ngrok') || 
            videoUrl.contains('ngrok-free.app') || 
            videoUrl.contains('ngrok.app')) {
          headers['ngrok-skip-browser-warning'] = 'true';
        }
        
        // Add platform-specific User-Agent
        if (Platform.isIOS) {
          headers['User-Agent'] = 'Mozilla/5.0 (iPhone; CPU iPhone OS 14_0 like Mac OS X) AppleWebKit/605.1.15';
        } else if (Platform.isAndroid) {
          headers['User-Agent'] = 'Mozilla/5.0 (Linux; Android 10) Mobile';
        }
      }

      _controller = VideoPlayerController.networkUrl(
        Uri.parse(videoUrl),
        httpHeaders: headers,
      );

      // Initialize the controller
      await _controller!.initialize();
      
      // Seek to the first frame (0 seconds)
      await _controller!.seekTo(Duration.zero);
      
      // Pause the video (we only want the thumbnail)
      await _controller!.pause();

      if (mounted) {
        setState(() {
          _isInitialized = true;
          _isLoading = false;
        });
      }
    } catch (e) {
      Log.e('Error initializing video thumbnail', 'VIDEO_THUMBNAIL_BUILDER', e);
      if (mounted) {
        setState(() {
          _isLoading = false;
          _hasError = true;
        });
      }
    }
  }

  String _resolveWebSameOriginUrl(String url) {
    if (kIsWeb) {
      return url;
    }
    return url;
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // Video thumbnail or placeholder
        _buildThumbnail(),
        // Play button overlay
        Center(
          child: Container(
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.5),
              shape: BoxShape.circle,
            ),
            child: IconButton(
              icon: const Icon(Icons.play_arrow, size: 48, color: Colors.white),
              onPressed: widget.onTap,
            ),
          ),
        ),
        // Download button
        if (widget.onDownload != null)
          Positioned(
            top: 8,
            left: 8,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.7),
                shape: BoxShape.circle,
              ),
              child: IconButton(
                onPressed: widget.onDownload,
                icon: const Icon(Icons.download, color: Colors.white),
                tooltip: 'Download video',
              ),
            ),
          ),
        // Fullscreen button
        if (widget.showFullScreenButton)
          Positioned(
            top: 8,
            right: 8,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.7),
                shape: BoxShape.circle,
              ),
              child: IconButton(
                onPressed: widget.onTap,
                icon: const Icon(Icons.fullscreen, color: Colors.white),
                tooltip: 'View full screen',
              ),
            ),
          ),
        // WhatsApp-style inline download progress indicator
        if (widget.downloadInfo != null && 
            (widget.downloadInfo!.state == DownloadState.downloading || 
             widget.downloadInfo!.state == DownloadState.saving))
          Positioned(
            top: 8,
            right: widget.showFullScreenButton ? 56 : 8,
            child: WhatsAppDownloadIndicator(
              progress: widget.downloadInfo!.progress,
              statusMessage: widget.downloadInfo!.statusMessage,
              onCancel: widget.onCancelDownload,
            ),
          ),
        // Video info bar
        if (widget.fileName != null)
          Positioned(
            bottom: 8,
            left: 8,
            right: 8,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.7),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.videocam, color: Colors.white, size: 16),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      widget.fileName!,
                      style: const TextStyle(color: Colors.white, fontSize: 12),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                  ),
                  if (widget.fileSize != null) ...[
                    const SizedBox(width: 6),
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

  Widget _buildThumbnail() {
    if (_isLoading) {
      return Container(
        color: Colors.black26,
        child: const Center(
          child: CircularProgressIndicator(color: Colors.white70),
        ),
      );
    }

    if (_hasError || !_isInitialized || _controller == null) {
      return Container(
        color: Colors.black26,
        child: const Center(
          child: Icon(Icons.videocam, size: 64, color: Colors.white70),
        ),
      );
    }

    // Display the first frame as thumbnail
    return AspectRatio(
      aspectRatio: _controller!.value.aspectRatio,
      child: VideoPlayer(_controller!),
    );
  }
}