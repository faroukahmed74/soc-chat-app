// =============================================================================
// ENHANCED MEDIA PREVIEW WIDGET
// =============================================================================
// This widget provides enhanced media previews with better error handling,
// retry functionality, and improved URL validation for chat screens

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'dart:io';
import 'package:url_launcher/url_launcher.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:video_player/video_player.dart';
// Conditional import: web_pdf_thumbnail handles web/mobile conditional internally
import 'web_pdf_thumbnail.dart';
import 'mobile_pdf_thumbnail.dart';
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
    if (url.isEmpty || url.trim().isEmpty) return false;
    try {
      final uri = Uri.parse(url);
      // Allow http, https, data, blob, file schemes
      return uri.hasScheme && (
        uri.scheme == 'http' || 
        uri.scheme == 'https' || 
        uri.scheme == 'data' || 
        uri.scheme == 'blob' ||
        uri.scheme == 'file'
      );
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
    // Basic URL validation - be more lenient
    if (widget.mediaUrl.isEmpty || widget.mediaUrl.trim().isEmpty) {
      return _buildErrorWidget('No media URL provided');
    }
    
    // Try to parse URL - if it fails, still try to load (might be a relative path)
    try {
      final uri = Uri.parse(widget.mediaUrl);
      // Only reject if it's clearly invalid (empty scheme and not a relative path)
      if (!uri.hasScheme && !widget.mediaUrl.startsWith('/') && !widget.mediaUrl.startsWith('uploads/')) {
        Log.w('Media URL might be invalid, but trying anyway', 'ENHANCED_MEDIA_PREVIEW');
      }
    } catch (e) {
      Log.w('Error parsing media URL, but trying anyway: $e', 'ENHANCED_MEDIA_PREVIEW');
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
    // Ensure URL is resolved before building
    final resolvedUrl = _resolveWebSameOriginUrl(widget.mediaUrl);
    
    return GestureDetector(
      onTap: widget.onTap, // Make entire image tappable for fullscreen
      child: Stack(
      children: [
          // Image thumbnail/preview - this will use resolved URL internally
        _buildCachedImage(),
          // Download button overlay
          Positioned(
            top: 8,
            left: 8,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.7),
                borderRadius: BorderRadius.circular(20),
              ),
              child: IconButton(
                onPressed: _downloadMedia,
                icon: const Icon(Icons.download, color: Colors.white, size: 20),
                tooltip: 'Download image',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(
                  minWidth: 40,
                  minHeight: 40,
                ),
              ),
            ),
          ),
          // Fullscreen button overlay
        if (widget.showFullScreenButton)
          Positioned(
            top: 8,
            right: 8,
            child: Container(
              decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.7),
                borderRadius: BorderRadius.circular(20),
              ),
              child: IconButton(
                onPressed: widget.onTap,
                icon: const Icon(Icons.fullscreen, color: Colors.white, size: 20),
                tooltip: 'View full screen',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: 40,
                    minHeight: 40,
              ),
            ),
          ),
            ),
          // Image info bar - only show if image loaded successfully
          Positioned(
          bottom: 8,
          left: 8,
          right: 8,
          child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.7),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.image, color: Colors.white, size: 16),
                  const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    widget.fileName ?? 'Image',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: ResponsiveUtils.getResponsiveFontSize(context, baseSize: 12),
                        fontWeight: FontWeight.w500,
                      ),
                    overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                  ),
                ),
                if (widget.fileSize != null) ...[
                    const SizedBox(width: 6),
                  Text(
                    widget.fileSize!,
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: ResponsiveUtils.getResponsiveFontSize(context, baseSize: 10),
                      ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
      ),
    );
  }

  Widget _buildVideoWidget() {
    return _VideoThumbnailBuilder(
      mediaUrl: widget.mediaUrl,
      fileName: widget.fileName,
      fileSize: widget.fileSize,
      onTap: widget.onTap,
      onDownload: _downloadMedia,
      showFullScreenButton: widget.showFullScreenButton,
      themeService: _themeService,
    );
  }

  Widget _buildAudioWidget() {
    return GestureDetector(
      onTap: widget.onTap, // Make entire audio widget tappable
      child: Stack(
      children: [
        Container(
          decoration: BoxDecoration(
              color: _themeService.isDarkMode ? Colors.grey[800] : Colors.grey[100],
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _themeService.isDarkMode ? Colors.grey[700] : Colors.grey[200],
                  ),
                  child: Icon(
                    widget.mediaType == 'voice' ? Icons.mic : Icons.music_note,
                    color: _themeService.isDarkMode ? Colors.white : Colors.black87,
                size: ResponsiveUtils.getResponsiveIconSize(context) * 2,
                  ),
                ),
                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Text(
                    widget.fileName ?? (widget.mediaType == 'voice' ? 'Voice Message' : 'Audio'),
                style: TextStyle(
                      color: _themeService.isDarkMode ? Colors.white : Colors.black87,
                  fontSize: ResponsiveUtils.getResponsiveFontSize(context, baseSize: 14),
                      fontWeight: FontWeight.w600,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
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
                        size: 32,
                      ),
                      tooltip: 'Play audio',
                    ),
                  ],
                ),
                if (widget.fileSize != null) ...[
              const SizedBox(height: 4),
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
        ),
        // Download button overlay
        Positioned(
          top: 8,
          left: 8,
          child: Container(
            decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.7),
              borderRadius: BorderRadius.circular(20),
            ),
            child: IconButton(
              onPressed: _downloadMedia,
              icon: const Icon(Icons.download, color: Colors.white, size: 20),
                tooltip: 'Download audio',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(
                  minWidth: 40,
                  minHeight: 40,
            ),
          ),
        ),
          ),
          // Fullscreen button overlay
        if (widget.showFullScreenButton)
          Positioned(
            top: 8,
            right: 8,
            child: Container(
              decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.7),
                borderRadius: BorderRadius.circular(20),
              ),
              child: IconButton(
                onPressed: widget.onTap,
                icon: const Icon(Icons.fullscreen, color: Colors.white, size: 20),
                tooltip: 'View full screen',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: 40,
                    minHeight: 40,
              ),
            ),
          ),
            ),
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
    final thumbHeight = maxHeight * 0.75;

    return GestureDetector(
      onTap: widget.onTap, // Make entire document tappable for fullscreen
      child: Stack(
        children: [
          Container(
            decoration: BoxDecoration(
      color: _themeService.isDarkMode ? Colors.grey[800] : Colors.grey[100],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: _themeService.isDarkMode ? Colors.grey[700]! : Colors.grey[300]!,
                width: 1,
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Document thumbnail/preview
                SizedBox(
                  width: maxWidth,
                  height: thumbHeight,
                  child: isPdf && kIsWeb
                      ? // PDF thumbnail on web - show first page
                        ClipRRect(
                            borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
                            child: WebPdfThumbnail(
                              url: '${widget.mediaUrl}#page=1&toolbar=0&navpanes=0&zoom=page-fit',
                              width: maxWidth,
                              height: thumbHeight,
                              borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                              onTap: widget.onTap,
                            ),
                          )
                      : isPdf && !kIsWeb
                          ? // PDF thumbnail on mobile - show first page
                            MobilePdfThumbnail(
                                url: widget.mediaUrl,
                                width: maxWidth,
                                height: thumbHeight,
                                borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
                                onTap: widget.onTap,
                              )
                          : // Other document types
                            Container(
                                decoration: BoxDecoration(
                                  color: _themeService.isDarkMode ? Colors.grey[700] : Colors.grey[200],
                                  borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
                                ),
                                child: Center(
                                  child: Icon(
                                    _getDocumentIcon(name),
                                    color: _themeService.isDarkMode ? Colors.white70 : Colors.black54,
                                    size: ResponsiveUtils.getResponsiveIconSize(context) * 2.5,
                                  ),
                                ),
                              ),
                ),
                // Document info
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    children: [
                      Text(
                        widget.fileName ?? 'Document',
                        style: TextStyle(
                          color: _themeService.isDarkMode ? Colors.white : Colors.black87,
                          fontSize: ResponsiveUtils.getResponsiveFontSize(context, baseSize: 12),
                          fontWeight: FontWeight.w600,
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
          ),
          if (widget.fileSize != null) ...[
                        const SizedBox(height: 4),
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
                ),
              ],
            ),
          ),
          // Full screen button overlay
          if (widget.showFullScreenButton)
            Positioned(
              top: 8,
              right: 8,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.7),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: IconButton(
                  onPressed: widget.onTap,
                  icon: const Icon(Icons.fullscreen, color: Colors.white, size: 20),
                  tooltip: 'View full screen',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: 40,
                    minHeight: 40,
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
                color: Colors.black.withValues(alpha: 0.7),
                borderRadius: BorderRadius.circular(20),
              ),
              child: IconButton(
                onPressed: _downloadMedia,
                icon: const Icon(Icons.download, color: Colors.white, size: 20),
                tooltip: 'Download document',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(
                  minWidth: 40,
                  minHeight: 40,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  IconData _getDocumentIcon(String fileName) {
    final ext = fileName.split('.').last.toLowerCase();
    switch (ext) {
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
      case 'zip':
      case 'rar':
        return Icons.folder_zip;
      default:
        return Icons.insert_drive_file;
    }
  }

  String _resolveWebSameOriginUrl(String url) {
    if (!kIsWeb) return url; // Mobile: return as-is (ngrok URLs preserved)
    
    if (url.isEmpty || url.trim().isEmpty) return url;
    
    try {
      final parsed = Uri.parse(url);
      
      // Preserve data and blob URLs
      if (parsed.scheme == 'blob' || parsed.scheme == 'data') return url;
      
      // Preserve Firebase Storage URLs
      if (parsed.host.contains('firebasestorage.googleapis.com')) return url;
      
      final base = Uri.base;
      final baseOrigin = base.origin; // e.g., "http://192.168.1.100:8082"
      final p = parsed.path;
      final query = parsed.hasQuery ? '?${parsed.query}' : '';

      // On web, convert ngrok URLs to local network URLs
      final host = parsed.host.toLowerCase();
      if (host.contains('ngrok') || host.contains('ngrok-free.app') || host.contains('ngrok.app')) {
        // Extract the path and convert to same-origin (local network)
        // Ensure path starts with /
        final cleanPath = p.startsWith('/') ? p : '/$p';
        final resolved = '$baseOrigin$cleanPath$query';
        Log.d('Resolved ngrok URL: $url -> $resolved', 'ENHANCED_MEDIA_PREVIEW');
        return resolved;
      }

      // Prefer rewriting known server paths to same-origin (local network)
      if (p.startsWith('/uploads') || p.contains('/uploads/')) {
        final resolved = '$baseOrigin$p$query';
        Log.d('Resolved uploads URL: $url -> $resolved', 'ENHANCED_MEDIA_PREVIEW');
        return resolved;
      }

      // Handle legacy /chat_media URLs by prefixing /uploads
      if (p.startsWith('/chat_media') || p.contains('/chat_media/')) {
        final adjustedPath = p.startsWith('/chat_media') 
            ? p.replaceFirst('/chat_media', '/uploads/chat_media')
            : '/uploads/chat_media/$p';
        final resolved = '$baseOrigin$adjustedPath$query';
        Log.d('Resolved chat_media URL: $url -> $resolved', 'ENHANCED_MEDIA_PREVIEW');
        return resolved;
      }

      // Proxy API calls to same-origin (local network)
      if (p.startsWith('/api/')) {
        final resolved = '$baseOrigin$p$query';
        Log.d('Resolved API URL: $url -> $resolved', 'ENHANCED_MEDIA_PREVIEW');
        return resolved;
      }

      // Check if it's already a relative path (starts with /)
      if (p.startsWith('/') && !parsed.hasAuthority && parsed.host.isEmpty) {
        // Already a relative path, just prepend base origin
        final resolved = '$baseOrigin$p$query';
        Log.d('Resolved relative URL: $url -> $resolved', 'ENHANCED_MEDIA_PREVIEW');
        return resolved;
      }

      // If already same-origin (local network), leave as-is
      final originUrl = '${parsed.scheme}://${parsed.host}${parsed.hasPort ? ':${parsed.port}' : ''}';
      if (originUrl == baseOrigin || originUrl == baseOrigin.replaceAll('http://', '').replaceAll('https://', '')) {
        Log.d('URL already same-origin: $url', 'ENHANCED_MEDIA_PREVIEW');
        return url;
      }
      
      // For external URLs that aren't ngrok or same-origin, log and try to convert if path exists
      if (p.isNotEmpty && p.startsWith('/')) {
        // Has a path, try to use it with base origin
        final resolved = '$baseOrigin$p$query';
        Log.d('Attempting to resolve external URL: $url -> $resolved', 'ENHANCED_MEDIA_PREVIEW');
        return resolved;
      }
      
      Log.w('Could not resolve URL, returning as-is: $url', 'ENHANCED_MEDIA_PREVIEW');
      return url;
    } catch (e) {
      Log.e('Error resolving URL: $url', 'ENHANCED_MEDIA_PREVIEW', e);
      return url;
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

  Widget _buildErrorWidget(String message) {
    // Don't show ngrok URLs to users - show resolved URL or simplified message
    final displayUrl = widget.mediaUrl.isNotEmpty 
        ? (_resolveWebSameOriginUrl(widget.mediaUrl).length > 50 
            ? '${_resolveWebSameOriginUrl(widget.mediaUrl).substring(0, 50)}...' 
            : _resolveWebSameOriginUrl(widget.mediaUrl))
        : '';
    
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
            if (displayUrl.isNotEmpty && !displayUrl.contains('ngrok')) ...[
              const SizedBox(height: 4),
              Text(
                'URL: $displayUrl',
                style: TextStyle(
                  color: Colors.grey[500],
                  fontSize: 8,
                ),
                textAlign: TextAlign.center,
              ),
            ],
            if (widget.enableRetry) ...[
              const SizedBox(height: 12),
              ElevatedButton.icon(
                onPressed: _retryLoad,
                icon: const Icon(Icons.refresh, size: 16),
                label: const Text('Retry'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                ),
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
              widget.mediaType,
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
    // On web, always use network image directly (no file caching)
    if (kIsWeb) {
      return _buildNetworkImage();
    }
    
    // On mobile, try cache first, then fallback to network
    return FutureBuilder<String?>(
      future: _getCachedMediaPath(),
      builder: (context, snapshot) {
        if (snapshot.hasData && snapshot.data != null && !kIsWeb) {
          // Use cached image (mobile only)
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
    
    // Validate URL
    if (resolvedUrl.isEmpty) {
      return _buildErrorWidget('Invalid image URL');
    }
    
    try {
      final uri = Uri.parse(resolvedUrl);
      if (!uri.hasScheme || (!uri.scheme.startsWith('http') && uri.scheme != 'data' && uri.scheme != 'blob')) {
        return _buildErrorWidget('Invalid URL scheme');
      }
    } catch (e) {
      return _buildErrorWidget('Invalid URL format');
    }
    
    return Image.network(
      resolvedUrl,
      fit: BoxFit.cover,
      width: double.infinity,
      height: double.infinity,
      loadingBuilder: (context, child, loadingProgress) {
        if (loadingProgress == null) {
          // Image loaded, cache it (mobile only)
          if (!kIsWeb) {
            MediaCacheService.cacheMedia(resolvedUrl, mediaType: 'image');
          }
          return child;
        }
        return _buildLoadingWidget();
      },
      errorBuilder: (context, error, stackTrace) {
        Log.e('Image loading error', 'ENHANCED_MEDIA_PREVIEW', error);
        Log.e('Failed URL (resolved): $resolvedUrl', 'ENHANCED_MEDIA_PREVIEW');
        Log.e('Original URL: ${widget.mediaUrl}', 'ENHANCED_MEDIA_PREVIEW');
        
        // Return error widget with retry option
        return _buildErrorWidget('Failed to load image');
      },
      frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
        // Show loading indicator while frame is being loaded
        if (wasSynchronouslyLoaded) return child;
        if (frame == null) return _buildLoadingWidget();
        return child;
      },
    );
  }

  /// Get cached media path or cache the media
  Future<String?> _getCachedMediaPath() async {
    if (kIsWeb) return null; // No file caching on web
    
    if (MediaCacheService.isCached(widget.mediaUrl)) {
      return MediaCacheService.getCachedPath(widget.mediaUrl);
    } else {
      // Cache the media in background
      MediaCacheService.cacheMedia(widget.mediaUrl, mediaType: widget.mediaType);
      return null;
    }
  }

  Future<void> _downloadMedia() async {
    try {
      if (!mounted) return;
      
      // Show downloading indicator
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
              ),
              SizedBox(width: 12),
              Text('Downloading...'),
            ],
          ),
          duration: Duration(seconds: 2),
        ),
      );

      final mediaUrl = _resolveWebSameOriginUrl(widget.mediaUrl);
      final uri = Uri.parse(mediaUrl);
      
      if (kIsWeb) {
        // Web: Open in new tab for download
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.platformDefault);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Download started'),
                backgroundColor: Colors.green,
              ),
            );
          }
        } else {
          _showSnackBar('Cannot open media URL');
        }
      } else {
        // Mobile: Download file to device
        await _downloadMediaMobile(mediaUrl);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Downloaded successfully'),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    } catch (e) {
      Log.e('Error downloading media', 'ENHANCED_MEDIA_PREVIEW', e);
      _showSnackBar('Failed to download: ${e.toString()}');
    }
  }

  Future<void> _downloadMediaMobile(String url) async {
    try {
      if (kIsWeb) return;
      
      final response = await http.get(Uri.parse(url));
      if (response.statusCode != 200) {
        throw Exception('Failed to download: HTTP ${response.statusCode}');
      }

      // Get file name from URL or use default
      String fileName = widget.fileName ?? 'download';
      final uri = Uri.parse(url);
      final pathSegments = uri.pathSegments;
      if (pathSegments.isNotEmpty) {
        final lastSegment = pathSegments.last;
        if (lastSegment.contains('.')) {
          fileName = lastSegment;
        } else {
          // Add extension based on media type
          final extension = widget.mediaType == 'video' 
              ? '.mp4' 
              : widget.mediaType == 'image' 
                  ? '.jpg' 
                  : widget.mediaType == 'audio' || widget.mediaType == 'voice'
                      ? '.mp3'
                      : widget.mediaType == 'document'
                          ? '.pdf'
                          : '.bin';
          fileName = '$fileName$extension';
        }
      }

      // Use path_provider to get Documents directory
      final directory = await getApplicationDocumentsDirectory();
      final filePath = '${directory.path}/$fileName';
      final file = File(filePath);
      
      await file.writeAsBytes(response.bodyBytes);
      
      if (await file.exists()) {
        Log.i('File downloaded to: $filePath', 'ENHANCED_MEDIA_PREVIEW');
      }
    } catch (e) {
      Log.e('Error in mobile download', 'ENHANCED_MEDIA_PREVIEW', e);
      rethrow;
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

// Video Thumbnail Builder Widget
class _VideoThumbnailBuilder extends StatefulWidget {
  final String mediaUrl;
  final String? fileName;
  final String? fileSize;
  final VoidCallback? onTap;
  final VoidCallback? onDownload;
  final bool showFullScreenButton;
  final ThemeService themeService;

  const _VideoThumbnailBuilder({
    required this.mediaUrl,
    this.fileName,
    this.fileSize,
    this.onTap,
    this.onDownload,
    this.showFullScreenButton = true,
    required this.themeService,
  });

  @override
  State<_VideoThumbnailBuilder> createState() => _VideoThumbnailBuilderState();
}

class _VideoThumbnailBuilderState extends State<_VideoThumbnailBuilder> {
  String? _thumbnailUrl;
  bool _isLoadingThumbnail = true;
  bool _hasThumbnailError = false;
  VideoPlayerController? _previewVideoController;
  bool _isPreviewPlaying = false;
  bool _showPreviewControls = false;
  bool _usingVideoFrame = false;

  @override
  void initState() {
    super.initState();
    _loadVideoThumbnail();
    // Initialize video controller to extract first frame
    _initializeVideoForThumbnail();
  }

  @override
  void dispose() {
    _previewVideoController?.dispose();
    super.dispose();
  }

  Future<void> _initializeVideoForThumbnail() async {
    // First, try server thumbnails. If not found, extract first frame from video
    // Wait a bit for thumbnail check to complete
    await Future.delayed(const Duration(milliseconds: 500));
    
    // If no server thumbnail found, extract first frame from video
    if (!_isLoadingThumbnail && _thumbnailUrl == null && mounted) {
      try {
        _previewVideoController = VideoPlayerController.networkUrl(
          Uri.parse(widget.mediaUrl),
          httpHeaders: kIsWeb 
              ? <String, String>{}
              : (!kIsWeb && Platform.isIOS
                  ? {
                      'User-Agent': 'Mozilla/5.0 (iPhone; CPU iPhone OS 14_0 like Mac OS X) AppleWebKit/605.1.15'
                    }
                  : {
                      'User-Agent': 'Mozilla/5.0 (Linux; Android 10) Mobile'
                    }),
        );
        
        await _previewVideoController!.initialize();
        
        // Seek to first frame (0 seconds) to show thumbnail
        await _previewVideoController!.seekTo(Duration.zero);
        _previewVideoController!.pause(); // Pause at first frame
        
        if (mounted) {
          setState(() {
            _usingVideoFrame = true;
            _hasThumbnailError = false;
          });
        }
      } catch (e) {
        Log.e('Error extracting video frame', 'VIDEO_THUMBNAIL_BUILDER', e);
        // Keep placeholder if extraction fails
        if (mounted) {
          setState(() {
            _usingVideoFrame = false;
          });
        }
      }
    }
  }

  Future<void> _initializeVideoPreview() async {
    try {
      if (_previewVideoController == null) {
        _previewVideoController = VideoPlayerController.networkUrl(Uri.parse(widget.mediaUrl));
        await _previewVideoController!.initialize();
      }
      _previewVideoController!.setLooping(true);
      _previewVideoController!.setVolume(0); // Mute preview
      setState(() {});
    } catch (e) {
      Log.e('Error initializing video preview', 'VIDEO_THUMBNAIL_BUILDER', e);
      // Fallback to thumbnail if preview fails
    }
  }

  void _togglePreviewPlayPause() {
    if (_previewVideoController == null || !_previewVideoController!.value.isInitialized) {
      // If video controller not initialized, open fullscreen instead
      widget.onTap?.call();
      return;
    }

    setState(() {
      if (_previewVideoController!.value.isPlaying) {
        _previewVideoController!.pause();
        _isPreviewPlaying = false;
      } else {
        _previewVideoController!.play();
        _isPreviewPlaying = true;
      }
      _showPreviewControls = true;
    });

    // Hide controls after 3 seconds
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        setState(() {
          _showPreviewControls = false;
        });
      }
    });
  }

  Future<void> _loadVideoThumbnail() async {
    if (!mounted) return;
    
    try {
      // Try to get thumbnail URL (server-generated or fallback to video frame)
      // Check if server provides thumbnail at video_url + '_thumb.jpg' or similar
      final videoUrl = widget.mediaUrl;
      
      // Try common thumbnail URL patterns
      final thumbnailPatterns = [
        videoUrl.replaceAll(RegExp(r'\.(mp4|mov|avi|webm)$', caseSensitive: false), '_thumb.jpg'),
        videoUrl.replaceAll(RegExp(r'\.(mp4|mov|avi|webm)$', caseSensitive: false), '.thumb.jpg'),
        videoUrl + '_thumbnail.jpg',
        videoUrl.replaceFirst(RegExp(r'/[^/]+$'), '/thumbnails/${Uri.parse(videoUrl).pathSegments.last.replaceAll(RegExp(r'\.(mp4|mov|avi|webm)$', caseSensitive: false), '.jpg')}'),
      ];
      
      // Try to verify thumbnail exists (for web, we can check; for mobile, try loading)
      if (kIsWeb) {
        // On web, try to load thumbnail asynchronously
        for (final pattern in thumbnailPatterns) {
          try {
            final response = await http.head(Uri.parse(pattern));
            if (response.statusCode == 200) {
              if (mounted) {
                setState(() {
                  _thumbnailUrl = pattern;
                  _isLoadingThumbnail = false;
                });
                return;
              }
            }
          } catch (e) {
            continue;
          }
        }
      }
      
      // No thumbnail found, use placeholder
      if (mounted) {
        setState(() {
          _isLoadingThumbnail = false;
          _hasThumbnailError = true;
        });
      }
    } catch (e) {
      Log.e('Error loading video thumbnail', 'ENHANCED_MEDIA_PREVIEW', e);
      if (mounted) {
        setState(() {
          _isLoadingThumbnail = false;
          _hasThumbnailError = true;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
        children: [
        // Video thumbnail or placeholder
        Container(
          width: double.infinity,
          height: double.infinity,
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(12),
            gradient: _thumbnailUrl == null
                ? LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      widget.themeService.isDarkMode 
                          ? Colors.grey[800]! 
                          : Colors.grey[300]!,
                      widget.themeService.isDarkMode 
                          ? Colors.grey[900]! 
                          : Colors.grey[400]!,
                    ],
                  )
                : null,
          ),
          child: _isLoadingThumbnail
              ? Center(
                  child: SizedBox(
                    width: ResponsiveUtils.getResponsiveIconSize(context),
                    height: ResponsiveUtils.getResponsiveIconSize(context),
                    child: const CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white70,
                    ),
                  ),
                )
              : _thumbnailUrl != null
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.network(
                        _thumbnailUrl!,
                        fit: BoxFit.cover,
                        width: double.infinity,
                        height: double.infinity,
                        errorBuilder: (context, error, stackTrace) {
                          // If server thumbnail fails, try video frame
                          if (!_usingVideoFrame && _previewVideoController == null) {
                            _initializeVideoForThumbnail();
                          }
                          return _buildVideoPlaceholder();
                        },
                        loadingBuilder: (context, child, loadingProgress) {
                          if (loadingProgress == null) return child;
                          return Center(
                            child: CircularProgressIndicator(
                              value: loadingProgress.expectedTotalBytes != null
                                  ? loadingProgress.cumulativeBytesLoaded /
                                      loadingProgress.expectedTotalBytes!
                                  : null,
                              color: Colors.white70,
                            ),
                          );
                        },
                      ),
                    )
                  : _previewVideoController != null && 
                     _previewVideoController!.value.isInitialized &&
                     _usingVideoFrame
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: AspectRatio(
                            aspectRatio: _previewVideoController!.value.aspectRatio,
                            child: VideoPlayer(_previewVideoController!),
                          ),
                        )
                      : _buildVideoPlaceholder(),
        ),
        // Play button overlay - always opens fullscreen on tap
        Center(
          child: GestureDetector(
            onTap: widget.onTap, // Always open fullscreen player
            child: Container(
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.7),
                shape: BoxShape.circle,
              ),
              padding: const EdgeInsets.all(8),
              child: IconButton(
                  onPressed: widget.onTap,
                icon: const Icon(
                  Icons.play_arrow,
                  color: Colors.white,
                  size: 48,
                ),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
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
              color: Colors.black.withValues(alpha: 0.7),
              borderRadius: BorderRadius.circular(20),
            ),
            child: IconButton(
              onPressed: widget.onDownload,
              icon: const Icon(Icons.download, color: Colors.white, size: 20),
              tooltip: 'Download video',
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(
                minWidth: 40,
                minHeight: 40,
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
                color: Colors.black.withValues(alpha: 0.7),
                borderRadius: BorderRadius.circular(20),
              ),
              child: IconButton(
                onPressed: widget.onTap,
                icon: const Icon(Icons.fullscreen, color: Colors.white, size: 20),
                  tooltip: 'View full screen',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(
                  minWidth: 40,
                  minHeight: 40,
                ),
              ),
            ),
          ),
        Positioned(
          bottom: 8,
          left: 8,
          right: 8,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.7),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.videocam, color: Colors.white, size: 16),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    widget.fileName ?? 'Video',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: ResponsiveUtils.getResponsiveFontSize(context, baseSize: 12),
                      fontWeight: FontWeight.w500,
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
          ),
          if (widget.fileSize != null) ...[
                  const SizedBox(width: 6),
            Text(
              widget.fileSize!,
              style: TextStyle(
                      color: Colors.white70,
                fontSize: ResponsiveUtils.getResponsiveFontSize(context, baseSize: 10),
              ),
            ),
          ],
        ],
      ),
          ),
        ),
      ],
    );
  }

  Widget _buildVideoPlaceholder() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          Icons.videocam,
          size: ResponsiveUtils.getResponsiveIconSize(context) * 2,
          color: widget.themeService.isDarkMode ? Colors.white70 : Colors.black54,
        ),
        const SizedBox(height: 8),
        Text(
          'Video',
          style: TextStyle(
            color: widget.themeService.isDarkMode ? Colors.white70 : Colors.black54,
            fontSize: ResponsiveUtils.getResponsiveFontSize(context, baseSize: 14),
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

}