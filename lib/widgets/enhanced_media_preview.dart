// =============================================================================
// ENHANCED MEDIA PREVIEW WIDGET
// =============================================================================
// This widget provides enhanced media previews with better error handling,
// retry functionality, and improved URL validation for chat screens

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'dart:io';
import 'package:url_launcher/url_launcher.dart';
// Web-only PDF thumbnail embed - temporarily disabled
// import 'web_pdf_thumbnail.dart';
import '../services/theme_service.dart';
import '../services/logger_service.dart';
import '../services/media_cache_service.dart';
import '../utils/responsive_utils.dart';

/// Enhanced media preview widget for chat screens
class EnhancedMediaPreview extends StatefulWidget {
  final String mediaUrl;
  final String mediaType;
  final String? fileName;
  final String? fileSize;
  final bool isCurrentUser;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final double? maxWidth;
  final double? maxHeight;
  final bool showFullScreenButton;
  final bool enableRetry;

  const EnhancedMediaPreview({
    super.key,
    required this.mediaUrl,
    required this.mediaType,
    this.fileName,
    this.fileSize,
    this.isCurrentUser = false,
    this.onTap,
    this.onLongPress,
    this.maxWidth,
    this.maxHeight,
    this.showFullScreenButton = true,
    this.enableRetry = true,
  });

  @override
  State<EnhancedMediaPreview> createState() => _EnhancedMediaPreviewState();
}

class _EnhancedMediaPreviewState extends State<EnhancedMediaPreview> {
  bool _isRetrying = false;
  late ThemeService _themeService;

  @override
  void initState() {
    super.initState();
    _themeService = ThemeService.instance;
    _themeService.addListener(() {
      if (mounted) setState(() {});
    });
  }

  void _retryLoad() {
    if (_isRetrying) return;
    
    setState(() {
      _isRetrying = true;
    });

    // Simulate retry delay
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) {
        setState(() {
          _isRetrying = false;
        });
      }
    });
  }

  bool _isValidUrl(String url) {
    try {
      final uri = Uri.parse(url);
      return uri.hasScheme && (uri.scheme == 'http' || uri.scheme == 'https');
    } catch (e) {
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = ResponsiveUtils.isMobile(context);
    final isTablet = ResponsiveUtils.isTablet(context);
    
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
          onTap: widget.onTap,
          onLongPress: widget.onLongPress,
          child: _buildMediaContent(),
        ),
      ),
    );
  }

  Widget _buildMediaContent() {
    // Validate URL first
    if (!_isValidUrl(widget.mediaUrl)) {
      return _buildErrorWidget('Invalid media URL');
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

  Widget _buildImageWidget() {
    return Stack(
      children: [
        _buildCachedImage(),
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
                onPressed: widget.onTap,
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
    return Stack(
      children: [
        Container(
          width: double.infinity,
          height: double.infinity,
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.videocam,
                size: ResponsiveUtils.getResponsiveIconSize(context) * 2,
                color: _themeService.isDarkMode ? Colors.white : Colors.black87,
              ),
              const SizedBox(height: 8),
              Text(
                'Video Preview',
                style: TextStyle(
                  color: _themeService.isDarkMode ? Colors.white : Colors.black87,
                  fontSize: ResponsiveUtils.getResponsiveFontSize(context, baseSize: 14),
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Tap to play',
                style: TextStyle(
                  color: _themeService.isDarkMode ? Colors.white70 : Colors.black54,
                  fontSize: ResponsiveUtils.getResponsiveFontSize(context, baseSize: 12),
                ),
              ),
            ],
          ),
        ),
        // Play button overlay
        Center(
          child: Container(
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.6),
              shape: BoxShape.circle,
            ),
            child: IconButton(
              onPressed: widget.onTap,
              icon: const Icon(
                Icons.play_arrow,
                color: Colors.white,
                size: 40,
              ),
            ),
          ),
        ),
        // Download button overlay
        Positioned(
          top: 8,
          left: 8,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(20),
            ),
            child: IconButton(
              onPressed: _downloadMedia,
              icon: const Icon(Icons.download, color: Colors.white, size: 20),
              tooltip: 'Download video',
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
                onPressed: widget.onTap,
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
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                onPressed: widget.onTap,
                icon: Icon(
                  Icons.play_arrow,
                  color: _themeService.isDarkMode ? Colors.white : Colors.black87,
                ),
                tooltip: 'Play audio',
              ),
              if (widget.showFullScreenButton)
                IconButton(
                  onPressed: widget.onTap,
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

  Widget _buildDocumentWidget() {
    final name = widget.fileName?.toLowerCase() ?? '';
    final isPdf = name.endsWith('.pdf');
    final isMobile = ResponsiveUtils.isMobile(context);
    final isTablet = ResponsiveUtils.isTablet(context);
    final maxWidth = widget.maxWidth ?? (isMobile ? 200.0 : isTablet ? 300.0 : 400.0);
    final maxHeight = widget.maxHeight ?? (isMobile ? 200.0 : isTablet ? 300.0 : 400.0);
    final thumbHeight = maxHeight * 0.6;

    return Container(
      color: _themeService.isDarkMode ? Colors.grey[800] : Colors.grey[100],
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (isPdf)
            SizedBox(
              width: maxWidth,
              height: thumbHeight,
              child: Icon(
                Icons.picture_as_pdf,
                color: Colors.red,
                size: ResponsiveUtils.getResponsiveIconSize(context) * 2,
              ),
            )
          else
            Icon(
              Icons.insert_drive_file,
              color: _themeService.isDarkMode ? Colors.white : Colors.black87,
              size: ResponsiveUtils.getResponsiveIconSize(context) * 2,
            ),
          const SizedBox(height: 12),
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
                  onPressed: widget.onTap,
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

  Widget _buildErrorWidget(String message) {
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
              message,
              style: TextStyle(
                color: Colors.red,
                fontSize: ResponsiveUtils.getResponsiveFontSize(context, baseSize: 12),
              ),
              textAlign: TextAlign.center,
            ),
            if (widget.enableRetry) ...[
              const SizedBox(height: 8),
              ElevatedButton.icon(
                onPressed: _isRetrying ? null : _retryLoad,
                icon: _isRetrying 
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.refresh, size: 16),
                label: Text(_isRetrying ? 'Retrying...' : 'Retry'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  textStyle: const TextStyle(fontSize: 10),
                ),
              ),
            ],
            if (widget.mediaUrl.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                'URL: ${widget.mediaUrl.length > 50 ? '${widget.mediaUrl.substring(0, 50)}...' : widget.mediaUrl}',
                style: TextStyle(
                  color: Colors.grey[500],
                  fontSize: 8,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ],
        ),
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

  /// Build cached image widget with fallback to network
  Widget _buildCachedImage() {
    return FutureBuilder<String?>(
      future: _getCachedMediaPath(),
      builder: (context, snapshot) {
        if (snapshot.hasData && snapshot.data != null) {
          // Use cached image
          return Image.file(
            File(snapshot.data!),
            fit: BoxFit.cover,
            width: double.infinity,
            height: double.infinity,
            errorBuilder: (context, error, stackTrace) {
              // Fallback to network if cached file is corrupted
              return _buildNetworkImage();
            },
          );
        } else {
          // Use network image and cache it
          return _buildNetworkImage();
        }
      },
    );
  }

  /// Build network image with caching
  Widget _buildNetworkImage() {
    final resolvedUrl = _resolveWebSameOriginUrl(widget.mediaUrl);
    return Image.network(
      resolvedUrl,
      fit: BoxFit.cover,
      width: double.infinity,
      height: double.infinity,
      loadingBuilder: (context, child, loadingProgress) {
        if (loadingProgress == null) {
          // Image loaded, cache it
          MediaCacheService.cacheMedia(resolvedUrl, mediaType: 'image');
          return child;
        }
        return _buildLoadingWidget();
      },
      errorBuilder: (context, error, stackTrace) {
        Log.e('Image loading error', 'ENHANCED_MEDIA_PREVIEW', error);
        Log.e('Failed URL: $resolvedUrl', 'ENHANCED_MEDIA_PREVIEW');
        return _buildErrorWidget('Failed to load image');
      },
    );
  }

  // Resolve media URL to same-origin on web for direct loading/downloading
  String _resolveWebSameOriginUrl(String url) {
    if (!kIsWeb) return url;
    try {
      final parsed = Uri.parse(url);
      if (parsed.scheme == 'blob' || parsed.scheme == 'data') return url;
      if (parsed.host.contains('firebasestorage.googleapis.com')) return url;
      final base = Uri.base;
      final p = parsed.path;

      // Prefer rewriting known server paths to same-origin
      if (p.startsWith('/uploads') || p.contains('/uploads/')) {
        return Uri.parse('${base.origin}$p${parsed.hasQuery ? '?${parsed.query}' : ''}').toString();
      }

      // Handle legacy /chat_media URLs by prefixing /uploads
      if (p.startsWith('/chat_media') || p.contains('/chat_media/')) {
        final adjustedPath = '/uploads' + (p.startsWith('/') ? p : '/$p');
        return Uri.parse('${base.origin}$adjustedPath${parsed.hasQuery ? '?${parsed.query}' : ''}').toString();
      }

      // Proxy API calls to same-origin
      if (p.startsWith('/api/')) {
        return Uri.parse('${base.origin}$p${parsed.hasQuery ? '?${parsed.query}' : ''}').toString();
      }

      // If already same-origin or an external URL, leave as-is
      final originUrl = '${parsed.scheme}://${parsed.host}${parsed.hasPort ? ':${parsed.port}' : ''}';
      if (originUrl == base.origin) return url;
      return url;
    } catch (_) {
      return url;
    }
  }

  /// Get cached media path or cache the media
  Future<String?> _getCachedMediaPath() async {
    if (MediaCacheService.isCached(widget.mediaUrl)) {
      return MediaCacheService.getCachedPath(widget.mediaUrl);
    } else {
      // Cache the media in background
      MediaCacheService.cacheMedia(widget.mediaUrl, mediaType: widget.mediaType);
      return null;
    }
  }

  void _downloadMedia() async {
    try {
      final uri = Uri.parse(_resolveWebSameOriginUrl(widget.mediaUrl));
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        _showSnackBar('Cannot open media');
      }
    } catch (e) {
      Log.e('Error downloading media', 'ENHANCED_MEDIA_PREVIEW', e);
      _showSnackBar('Failed to download media: ${e.toString()}');
    }
  }

  void _showSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }
}