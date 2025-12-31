import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'dart:io';
import 'dart:typed_data';
import 'dart:html' if (dart.library.io) '../widgets/html_stub.dart' as html;
import '../services/logger_service.dart';
import '../services/media_download_service.dart';
import '../utils/responsive_utils.dart';
import 'cached_network_image_widget.dart';

/// Enhanced full-screen media preview widget
class FullScreenMediaPreview extends StatefulWidget {
  final String mediaUrl;
  final String mediaType;
  final String? fileName;
  final String? fileSize;

  const FullScreenMediaPreview({
    super.key,
    required this.mediaUrl,
    required this.mediaType,
    this.fileName,
    this.fileSize,
  });

  @override
  State<FullScreenMediaPreview> createState() => _FullScreenMediaPreviewState();
}

class _FullScreenMediaPreviewState extends State<FullScreenMediaPreview> {
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
  Duration _videoPosition = Duration.zero;
  Duration _videoDuration = Duration.zero;
  bool _isVideoPlaying = false;

  @override
  void initState() {
    super.initState();
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
          setState(() {
            _isLoading = false;
          });
          break;
        case 'document':
          // For documents, check if it's a PDF - PDFs need time to load
          final fileName = widget.fileName ?? '';
          final mediaUrl = widget.mediaUrl;
          final mediaUrlLower = mediaUrl.toLowerCase();
          
          // Extract filename from URL if fileName is missing or doesn't have extension
          String? urlFileName;
          try {
            final uri = Uri.parse(mediaUrl);
            final pathSegments = uri.pathSegments;
            if (pathSegments.isNotEmpty) {
              urlFileName = pathSegments.last;
            }
          } catch (_) {
            // If URL parsing fails, try simple string extraction
            final lastSlash = mediaUrl.lastIndexOf('/');
            if (lastSlash != -1 && lastSlash < mediaUrl.length - 1) {
              final afterSlash = mediaUrl.substring(lastSlash + 1);
              final queryIndex = afterSlash.indexOf('?');
              urlFileName = queryIndex != -1 ? afterSlash.substring(0, queryIndex) : afterSlash;
            }
          }
          
          // Check multiple sources for PDF detection - be more lenient
          final isPdf = fileName.toLowerCase().endsWith('.pdf') || 
                       (urlFileName != null && urlFileName.toLowerCase().endsWith('.pdf')) ||
                       mediaUrlLower.contains('.pdf') || 
                       mediaUrlLower.contains('application/pdf') ||
                       mediaUrlLower.contains('content-type:application/pdf') ||
                       mediaUrlLower.contains('type=pdf') ||
                       // If it's a document type and we can't determine otherwise, assume PDF for full screen
                       (fileName.isEmpty && urlFileName == null && !mediaUrlLower.contains('image') && !mediaUrlLower.contains('video'));
          if (isPdf) {
            // PDF will show loading state until onDocumentLoaded is called
            // Keep _isLoading true initially - it will be set to false in onDocumentLoaded
            // Set a timeout to prevent infinite loading (10 seconds)
            Future.delayed(const Duration(seconds: 10), () {
              if (mounted && _isLoading) {
                Log.w('PDF loading timeout, forcing display', 'FULL_SCREEN_MEDIA_PREVIEW');
                setState(() {
                  _isLoading = false;
                });
              }
            });
          } else {
            setState(() {
              _isLoading = false;
            });
          }
          break;
        default:
          setState(() {
            _isLoading = false;
          });
      }
    } catch (e) {
      Log.e('Error initializing media', 'FULL_SCREEN_MEDIA_PREVIEW', e);
      setState(() {
        _isLoading = false;
        _hasError = true;
        _errorMessage = e.toString();
      });
    }
  }

  Future<void> _initializeVideo() async {
    try {
      // Check if Android 10 (API 29) - use download method directly for better reliability
      bool isAndroid10 = false;
      if (Platform.isAndroid && !kIsWeb) {
        try {
          final deviceInfo = DeviceInfoPlugin();
          final androidInfo = await deviceInfo.androidInfo;
          // Android 10 is API level 29
          isAndroid10 = androidInfo.version.sdkInt == 29;
        } catch (e) {
          // If we can't detect, try network first then fallback
        }
      }
      
      // For Android 10, use download method directly (more reliable)
      if (isAndroid10) {
        try {
          await _initializeVideoWithDownload();
          return;
        } catch (e) {
          Log.w('Android 10 download method failed, trying network fallback', 'FULL_SCREEN_MEDIA_PREVIEW');
          // If download fails, try network as last resort
        }
      }
      
      final videoUrl = _resolveWebSameOriginUrl(widget.mediaUrl);
      
      // Check video format and handle platform-specific requirements
      final uri = Uri.parse(videoUrl);
      final path = uri.path.toLowerCase();
      final isHls = path.contains('.m3u8') || uri.queryParameters.containsKey('format') && uri.queryParameters['format'] == 'hls';
      
      // Initialize video controller with proper headers for Android and ngrok URLs
      final headers = <String, String>{};
      if (!kIsWeb) {
        // Add ngrok header if URL contains ngrok (required for Android 10+)
        if (videoUrl.contains('ngrok') || 
            videoUrl.contains('ngrok-free.app') || 
            videoUrl.contains('ngrok.app')) {
          headers['ngrok-skip-browser-warning'] = 'true';
        }
        
        // Add platform-specific User-Agent
        headers['User-Agent'] = Platform.isIOS
            ? 'Mozilla/5.0 (iPhone; CPU iPhone OS 14_0 like Mac OS X) AppleWebKit/605.1.15'
            : 'Mozilla/5.0 (Linux; Android 10) Mobile';
      }
      
      _videoController = VideoPlayerController.networkUrl(
        Uri.parse(videoUrl),
        httpHeaders: headers,
      );
      
      await _videoController!.initialize();
      
      _videoController!.addListener(_videoListener);

      // Auto-play video
      _videoController!.play();
      setState(() {
        _isVideoPlaying = true;
      });
    } catch (e) {
      Log.e('Error initializing video', 'FULL_SCREEN_MEDIA_PREVIEW', e);
      
      // Try fallback: download and play locally (for mobile, especially Android 10)
      if (!kIsWeb) {
        try {
          await _initializeVideoWithDownload();
          return;
        } catch (downloadError) {
          Log.e('Fallback download also failed', 'FULL_SCREEN_MEDIA_PREVIEW', downloadError);
        }
      }
      
      // Show error with format info
      final videoExtension = widget.mediaUrl.toLowerCase().split('.').last;
      String errorMsg;
      
      if (kIsWeb) {
        errorMsg = 'Video format ($videoExtension) may not be supported by browser.\n'
            'Supported formats: MP4 (H.264), WebM\n'
            'Try downloading the video instead.';
      } else if (Platform.isIOS) {
        errorMsg = 'Failed to load video.\n'
            'iOS supports: MP4, MOV, M4V, HLS (.m3u8)\n'
            'Format detected: $videoExtension';
      } else {
        errorMsg = 'Failed to load video.\n'
            'Android supports: MP4, WebM, 3GP, MKV, HLS\n'
            'Format detected: $videoExtension';
      }
      
      setState(() {
        _isLoading = false;
        _hasError = true;
        _errorMessage = errorMsg;
      });
    }
  }

  Future<void> _initializeVideoWithDownload() async {
    try {
      if (kIsWeb) return; // Skip on web
      
      final videoUrl = _resolveWebSameOriginUrl(widget.mediaUrl);
      
      // Get file extension from URL or default to mp4
      final uri = Uri.parse(videoUrl);
      final path = uri.path.toLowerCase();
      String extension = 'mp4';
      if (path.contains('.')) {
        final parts = path.split('.');
        if (parts.length > 1) {
          extension = parts.last.split('?').first; // Remove query params
          // Validate extension
          if (!['mp4', 'webm', '3gp', 'mkv', 'mov', 'm4v'].contains(extension)) {
            extension = 'mp4';
          }
        }
      }
      
      // Add headers for ngrok URLs (required for Android 10+)
      final headers = <String, String>{};
      if (videoUrl.contains('ngrok') || 
          videoUrl.contains('ngrok-free.app') || 
          videoUrl.contains('ngrok.app')) {
        headers['ngrok-skip-browser-warning'] = 'true';
      }
      headers['User-Agent'] = Platform.isIOS
          ? 'Mozilla/5.0 (iPhone; CPU iPhone OS 14_0 like Mac OS X) AppleWebKit/605.1.15'
          : 'Mozilla/5.0 (Linux; Android 10) Mobile';
      
      // Download with timeout
      final response = await http.get(
        Uri.parse(videoUrl), 
        headers: headers,
      ).timeout(
        const Duration(minutes: 5), // 5 minute timeout for large videos
        onTimeout: () {
          throw Exception('Video download timeout - file may be too large');
        },
      );
      
      if (response.statusCode != 200) {
        throw Exception('Download failed: HTTP ${response.statusCode}');
      }
      
      // Save to temp file
      final tempDir = await getTemporaryDirectory();
      final tempFile = File('${tempDir.path}/temp_video_${DateTime.now().millisecondsSinceEpoch}.$extension');
      await tempFile.writeAsBytes(response.bodyBytes);
      
      // Verify file was written
      if (!await tempFile.exists()) {
        throw Exception('Failed to save video to temporary file');
      }
      
      // Initialize from local file
      _videoController = VideoPlayerController.file(tempFile);
      await _videoController!.initialize();
      
      _videoController!.addListener(_videoListener);
      _videoController!.play();
      
      setState(() {
        _isVideoPlaying = true;
        _isLoading = false;
      });
    } catch (e) {
      Log.e('Error in video download fallback', 'FULL_SCREEN_MEDIA_PREVIEW', e);
      rethrow;
    }
  }

  Future<void> _initializeAudio() async {
    try {
      _audioPlayer = AudioPlayer();
      
      _audioPlayer!.onDurationChanged.listen((duration) {
        setState(() {
          _audioDuration = duration;
        });
      });

      _audioPlayer!.onPositionChanged.listen((position) {
        setState(() {
          _audioPosition = position;
        });
      });

      _audioPlayer!.onPlayerStateChanged.listen((state) {
        setState(() {
          _isPlaying = state == PlayerState.playing;
        });
      });

      await _audioPlayer!.setSourceUrl(_resolveWebSameOriginUrl(widget.mediaUrl));
      
      setState(() {
        _isAudioInitialized = true;
        _isLoading = false;
      });
    } catch (e) {
      Log.e('Error initializing audio', 'FULL_SCREEN_MEDIA_PREVIEW', e);
      setState(() {
        _isLoading = false;
        _hasError = true;
        _errorMessage = 'Failed to load audio: $e';
      });
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

  void _videoListener() {
    if (_videoController != null && _videoController!.value.isInitialized) {
      setState(() {
        _isVideoInitialized = true;
        _isLoading = false;
        _isVideoPlaying = _videoController!.value.isPlaying;
        _videoPosition = _videoController!.value.position;
        _videoDuration = _videoController!.value.duration;
      });
    }
  }

  Future<void> _playPauseVideo() async {
    if (_videoController == null || !_videoController!.value.isInitialized) return;
    
    setState(() {
      if (_videoController!.value.isPlaying) {
        _videoController!.pause();
        _isVideoPlaying = false;
      } else {
        _videoController!.play();
        _isVideoPlaying = true;
      }
    });
  }

  Future<void> _seekVideo(Duration position) async {
    if (_videoController == null) return;
    await _videoController!.seekTo(position);
  }

  void _toggleControls() {
    setState(() {
      _showControls = !_showControls;
    });
    if (_showControls) {
      _hideControlsAfterDelay();
    }
  }

  Future<void> _playPauseAudio() async {
    if (_audioPlayer == null) return;

    if (_isPlaying) {
      await _audioPlayer!.pause();
    } else {
      await _audioPlayer!.resume();
    }
  }

  Future<void> _seekAudio(Duration position) async {
    if (_audioPlayer == null) return;
    await _audioPlayer!.seek(position);
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$minutes:$seconds';
  }

  Future<void> _downloadMedia() async {
    try {
      if (mounted) {
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
      }

      final mediaUrl = _resolveWebSameOriginUrl(widget.mediaUrl);
      final uri = Uri.parse(mediaUrl);
      
      if (kIsWeb) {
        // Web: Create download link and trigger download
        try {
          final fileName = widget.fileName ?? _getFileNameFromUrl(mediaUrl);
          final anchor = html.AnchorElement(
            href: mediaUrl,
          )
            ..setAttribute('download', fileName)
            ..target = '_blank';
          
          if (html.document.body != null) {
            html.document.body!.append(anchor);
          }
          anchor.click();
          
          // Clean up after a short delay
          Future.delayed(const Duration(milliseconds: 100), () {
            anchor.remove();
          });
        } catch (e) {
          Log.e('Error downloading on web', 'FULL_SCREEN_MEDIA_PREVIEW', e);
          // Fallback to opening URL
          if (await canLaunchUrl(uri)) {
            await launchUrl(uri, mode: LaunchMode.platformDefault);
          } else {
            throw Exception('Cannot download media');
          }
        }
      } else {
        // Mobile: Download file using path_provider
        await _downloadMediaMobile(mediaUrl);
      }
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Download started successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      Log.e('Error downloading media', 'FULL_SCREEN_MEDIA_PREVIEW', e);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to download: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _downloadMediaMobile(String url) async {
    final successMessage = await MediaDownloadService.saveToDevice(
      url: url,
      mediaType: widget.mediaType,
      fileName: widget.fileName,
    );
    // Success message is handled by the calling method
  }

  String _getFileNameFromUrl(String url) {
    try {
      final uri = Uri.parse(url);
      final pathSegments = uri.pathSegments;
      if (pathSegments.isNotEmpty) {
        final lastSegment = pathSegments.last;
        if (lastSegment.contains('.')) {
          return lastSegment;
        }
      }
      // Fallback: generate filename based on media type
      final extension = widget.mediaType == 'video' 
          ? '.mp4' 
          : widget.mediaType == 'image' 
              ? '.jpg' 
              : widget.mediaType == 'audio' || widget.mediaType == 'voice'
                  ? '.mp3'
                  : widget.mediaType == 'document'
                      ? '.pdf'
                      : '.bin';
      return 'download${DateTime.now().millisecondsSinceEpoch}$extension';
    } catch (e) {
      // Fallback filename
      final extension = widget.mediaType == 'video' 
          ? '.mp4' 
          : widget.mediaType == 'image' 
              ? '.jpg' 
              : widget.mediaType == 'audio' || widget.mediaType == 'voice'
                  ? '.mp3'
                  : widget.mediaType == 'document'
                      ? '.pdf'
                      : '.bin';
      return 'download${DateTime.now().millisecondsSinceEpoch}$extension';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Media content
          Center(
            child: _buildMediaContent(),
          ),

          // Top controls
          if (_showControls)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: Container(
                padding: EdgeInsets.only(
                  top: MediaQuery.of(context).padding.top + 16,
                  left: 16,
                  right: 16,
                  bottom: 16,
                ),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.7),
                      Colors.transparent,
                    ],
                  ),
                ),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.arrow_back, color: Colors.white),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (widget.fileName != null)
                            Text(
                              widget.fileName!,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          if (widget.fileSize != null)
                            Text(
                              widget.fileSize!,
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 12,
                              ),
                            ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: _downloadMedia,
                      icon: const Icon(Icons.download, color: Colors.white),
                    ),
                  ],
                ),
              ),
            ),

          // Bottom controls for video/audio
          if (_showControls && (widget.mediaType == 'video' || widget.mediaType == 'audio' || widget.mediaType == 'voice'))
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.7),
                      Colors.transparent,
                    ],
                  ),
                ),
                child: _buildMediaControls(),
              ),
            ),

          // Loading indicator
          if (_isLoading)
            const Center(
              child: CircularProgressIndicator(color: Colors.white),
            ),

          // Error message
          if (_hasError)
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, color: Colors.white, size: 64),
                  const SizedBox(height: 16),
                  Text(
                    'Failed to load media',
                    style: const TextStyle(color: Colors.white, fontSize: 18),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _errorMessage,
                    style: const TextStyle(color: Colors.white70, fontSize: 14),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _initializeMedia,
                    child: const Text('Retry'),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildMediaContent() {
    // For PDFs, always show content (loading/error handled in _buildPdfViewer)
    if (widget.mediaType == 'document') {
      // Don't return early for documents - let _buildPdfViewer handle loading/error states
    } else {
      if (_isLoading) return const SizedBox.shrink();
      if (_hasError) return const SizedBox.shrink();
    }

    switch (widget.mediaType) {
      case 'image':
        return LayoutBuilder(
          builder: (context, constraints) {
            return GestureDetector(
              onTap: _toggleControls,
              child: Center(
                child: InteractiveViewer(
                  minScale: 0.5,
                  maxScale: 4.0,
                  child: CachedNetworkImageWidget(
                    imageUrl: _resolveWebSameOriginUrl(widget.mediaUrl),
                    width: constraints.maxWidth,
                    height: constraints.maxHeight,
                    fit: BoxFit.contain,
                    errorWidget: const Center(
                      child: Icon(Icons.broken_image, color: Colors.white, size: 64),
                    ),
                    useCache: true,
                  ),
                ),
              ),
            );
          },
        );

      case 'video':
        if (_isVideoInitialized && _videoController != null) {
          return GestureDetector(
            onTap: _toggleControls,
            child: Stack(
              children: [
                AspectRatio(
                  aspectRatio: _videoController!.value.aspectRatio,
                  child: VideoPlayer(_videoController!),
                ),
                // Play/pause overlay button
                if (_showControls)
                  Center(
                    child: IconButton(
                      onPressed: _playPauseVideo,
                      icon: Icon(
                        _isVideoPlaying ? Icons.pause_circle_outline : Icons.play_circle_outline,
                        color: Colors.white,
                        size: 64,
                      ),
                    ),
                  ),
              ],
            ),
          );
        }
        if (_hasError) {
          // Show error with download option for unsupported formats
          return Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.videocam_off, color: Colors.white, size: 64),
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Text(
                  _errorMessage,
                  style: const TextStyle(color: Colors.white, fontSize: 16),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: _downloadMedia,
                icon: const Icon(Icons.download),
                label: const Text('Download Video'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.black87,
                ),
              ),
            ],
          );
        }
        return const Center(
          child: Icon(Icons.videocam, color: Colors.white, size: 64),
        );

      case 'audio':
      case 'voice':
        return GestureDetector(
          onTap: _toggleControls,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 200,
                height: 200,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.1),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.3), width: 2),
                ),
                child: Icon(
                  widget.mediaType == 'voice' ? Icons.mic : Icons.music_note,
                  color: Colors.white,
                  size: 80,
                ),
              ),
              const SizedBox(height: 32),
              Text(
                widget.fileName ?? 'Audio Message',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        );

      case 'document':
        // Enhanced PDF detection - check filename, mediaUrl, and MIME type
        final fileName = widget.fileName ?? '';
        final mediaUrl = widget.mediaUrl;
        final mediaUrlLower = mediaUrl.toLowerCase();
        
        // Extract filename from URL if fileName is missing or doesn't have extension
        String? urlFileName;
        try {
          final uri = Uri.parse(mediaUrl);
          final pathSegments = uri.pathSegments;
          if (pathSegments.isNotEmpty) {
            urlFileName = pathSegments.last;
          }
        } catch (_) {
          // If URL parsing fails, try simple string extraction
          final lastSlash = mediaUrl.lastIndexOf('/');
          if (lastSlash != -1 && lastSlash < mediaUrl.length - 1) {
            final afterSlash = mediaUrl.substring(lastSlash + 1);
            final queryIndex = afterSlash.indexOf('?');
            urlFileName = queryIndex != -1 ? afterSlash.substring(0, queryIndex) : afterSlash;
          }
        }
        
        // Check multiple sources for PDF detection - be more lenient
        final isPdf = fileName.toLowerCase().endsWith('.pdf') || 
                     (urlFileName != null && urlFileName.toLowerCase().endsWith('.pdf')) ||
                     mediaUrlLower.contains('.pdf') || 
                     mediaUrlLower.contains('application/pdf') ||
                     mediaUrlLower.contains('content-type:application/pdf') ||
                     mediaUrlLower.contains('type=pdf') ||
                     // If it's a document type and we can't determine otherwise, assume PDF for full screen
                     (fileName.isEmpty && urlFileName == null && !mediaUrlLower.contains('image') && !mediaUrlLower.contains('video'));
        
        if (isPdf) {
          // Show PDF in full screen on all platforms
          return LayoutBuilder(
            builder: (context, constraints) {
              return Center(
                child: SizedBox(
                  width: constraints.maxWidth,
                  height: constraints.maxHeight,
                  child: InteractiveViewer(
                    minScale: 0.5,
                    maxScale: 4.0,
                    child: _buildPdfViewer(),
                  ),
                ),
              );
            },
          );
        }
        return LayoutBuilder(
          builder: (context, constraints) {
            return Center(
              child: SingleChildScrollView(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: ResponsiveUtils.getResponsiveValue(
                        context,
                        mobile: 100.0,
                        tablet: 120.0,
                        desktop: 150.0,
                      ),
                      height: ResponsiveUtils.getResponsiveValue(
                        context,
                        mobile: 100.0,
                        tablet: 120.0,
                        desktop: 150.0,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.3), width: 2),
                      ),
                      child: Icon(
                        Icons.description,
                        color: Colors.white,
                        size: ResponsiveUtils.getResponsiveValue(
                          context,
                          mobile: 50.0,
                          tablet: 60.0,
                          desktop: 80.0,
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: ResponsiveUtils.getResponsiveValue(
                          context,
                          mobile: 16.0,
                          tablet: 32.0,
                          desktop: 48.0,
                        ),
                      ),
                      child: Text(
                        widget.fileName ?? 'Document',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: ResponsiveUtils.getResponsiveFontSize(
                            context,
                            baseSize: 18,
                          ),
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (widget.fileSize != null)
                      Text(
                        widget.fileSize!,
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: ResponsiveUtils.getResponsiveFontSize(
                            context,
                            baseSize: 14,
                          ),
                        ),
                      ),
                    const SizedBox(height: 24),
                    ElevatedButton.icon(
                      onPressed: _downloadMedia,
                      icon: const Icon(Icons.download),
                      label: const Text('Download'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: Colors.black87,
                        padding: EdgeInsets.symmetric(
                          horizontal: ResponsiveUtils.getResponsiveValue(
                            context,
                            mobile: 16.0,
                            tablet: 24.0,
                            desktop: 32.0,
                          ),
                          vertical: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );

      default:
        return const Center(
          child: Icon(Icons.file_present, color: Colors.white, size: 64),
        );
    }
  }

  Widget _buildMediaControls() {
    if (widget.mediaType == 'video' && _videoController != null && _videoController!.value.isInitialized) {
      return Column(
        children: [
          // Video progress bar with time
          Row(
            children: [
              Text(
                _formatDuration(_videoPosition),
                style: TextStyle(
                  color: Colors.white,
                  fontSize: ResponsiveUtils.getResponsiveFontSize(context, baseSize: 12),
                ),
              ),
              Expanded(
                child: SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    activeTrackColor: Colors.white,
                    inactiveTrackColor: Colors.white30,
                    thumbColor: Colors.white,
                    overlayColor: Colors.white.withValues(alpha: 0.2),
                    trackHeight: 3,
                  ),
                  child: Slider(
                    value: _videoDuration.inMilliseconds > 0
                        ? _videoPosition.inMilliseconds / _videoDuration.inMilliseconds
                        : 0.0,
                    onChanged: (value) {
                      final position = Duration(
                        milliseconds: (value * _videoDuration.inMilliseconds).round(),
                      );
                      _seekVideo(position);
                    },
                  ),
                ),
              ),
              Text(
                _formatDuration(_videoDuration),
                style: TextStyle(
                  color: Colors.white,
                  fontSize: ResponsiveUtils.getResponsiveFontSize(context, baseSize: 12),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Video controls row
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                onPressed: () {
                  final newPosition = _videoPosition - const Duration(seconds: 10);
                  _seekVideo(newPosition > Duration.zero ? newPosition : Duration.zero);
                },
                icon: const Icon(Icons.replay_10, color: Colors.white, size: 28),
                tooltip: 'Rewind 10s',
              ),
              const SizedBox(width: 16),
              IconButton(
                onPressed: _playPauseVideo,
                icon: Icon(
                  _isVideoPlaying ? Icons.pause_circle_filled : Icons.play_circle_filled,
                  color: Colors.white,
                  size: 48,
                ),
                tooltip: _isVideoPlaying ? 'Pause' : 'Play',
              ),
              const SizedBox(width: 16),
              IconButton(
                onPressed: () {
                  final newPosition = _videoPosition + const Duration(seconds: 10);
                  _seekVideo(newPosition < _videoDuration ? newPosition : _videoDuration);
                },
                icon: const Icon(Icons.forward_10, color: Colors.white, size: 28),
                tooltip: 'Forward 10s',
              ),
            ],
          ),
        ],
      );
    }

    if ((widget.mediaType == 'audio' || widget.mediaType == 'voice') && _audioPlayer != null) {
      return Column(
        children: [
          // Progress bar
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: Colors.white,
              inactiveTrackColor: Colors.white30,
              thumbColor: Colors.white,
              overlayColor: Colors.white.withValues(alpha: 0.2),
            ),
            child: Slider(
              value: _audioDuration.inMilliseconds > 0
                  ? _audioPosition.inMilliseconds / _audioDuration.inMilliseconds
                  : 0.0,
              onChanged: (value) {
                final position = Duration(
                  milliseconds: (value * _audioDuration.inMilliseconds).round(),
                );
                _seekAudio(position);
              },
            ),
          ),
          
          // Time and controls
          Row(
            children: [
              Text(
                _formatDuration(_audioPosition),
                style: const TextStyle(color: Colors.white),
              ),
              const Spacer(),
              IconButton(
                onPressed: _playPauseAudio,
                icon: Icon(
                  _isPlaying ? Icons.pause : Icons.play_arrow,
                  color: Colors.white,
                  size: 32,
                ),
              ),
              const Spacer(),
              Text(
                _formatDuration(_audioDuration),
                style: const TextStyle(color: Colors.white),
              ),
            ],
          ),
        ],
      );
    }

    return const SizedBox.shrink();
  }

  Widget _buildPdfViewer() {
    if (!kIsWeb) {
      // On mobile: Show PDF viewer with overlay actions
      return Stack(
        children: [
          // PDF viewer - always show, even if loading
          Positioned.fill(
            child: _buildMobilePdfViewer(),
          ),
          
          // Loading overlay
          if (_isLoading)
            Positioned.fill(
              child: Container(
                color: Colors.black.withValues(alpha: 0.7),
                child: const Center(
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                ),
              ),
            ),
          
          // Error overlay
          if (_hasError)
            Positioned.fill(
              child: Container(
                color: Colors.black.withValues(alpha: 0.9),
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline, color: Colors.white, size: 64),
                      const SizedBox(height: 16),
                      Text(
                        _errorMessage.isNotEmpty ? _errorMessage : 'Failed to load PDF',
                        style: const TextStyle(color: Colors.white),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        onPressed: _downloadMedia,
                        icon: const Icon(Icons.download),
                        label: const Text('Download PDF'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: Colors.black87,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          // Overlay actions: Preview label + Download icon
          Positioned(
            top: ResponsiveUtils.getResponsiveValue(
              context,
              mobile: 40.0,
              tablet: 50.0,
              desktop: 60.0,
            ),
            right: ResponsiveUtils.getResponsiveValue(
              context,
              mobile: 16.0,
              tablet: 20.0,
              desktop: 24.0,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.7),
                    borderRadius: BorderRadius.circular(25),
                  ),
                  child: TextButton.icon(
                    onPressed: () {
                      // Already in preview; this keeps intent explicit.
                    },
                    icon: const Icon(Icons.picture_as_pdf, color: Colors.white),
                    label: const Text(
                      'Preview Document',
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.7),
                    borderRadius: BorderRadius.circular(25),
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.download, color: Colors.white),
                    onPressed: _downloadMedia,
                    tooltip: 'Download PDF',
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    }

    // Web: Use iframe for PDF viewing
    return _buildWebPdfViewer();
  }

  Widget _buildMobilePdfViewer() {
    // Prefer direct network preview on mobile to avoid download-only behavior
    final headers = <String, String>{
      'ngrok-skip-browser-warning': 'true',
      if (!kIsWeb) 'User-Agent': 'Mozilla/5.0 (Linux; Android 10) Mobile',
    };
    
    Log.i('Loading PDF from URL: ${widget.mediaUrl}', 'FULL_SCREEN_MEDIA_PREVIEW');
    Log.i('PDF filename: ${widget.fileName}', 'FULL_SCREEN_MEDIA_PREVIEW');
    
    return SfPdfViewer.network(
      widget.mediaUrl,
      key: ValueKey('pdf_viewer_${widget.mediaUrl.hashCode}'),
      headers: headers,
      onDocumentLoadFailed: (PdfDocumentLoadFailedDetails details) {
        Log.e('PDF load failed for URL: ${widget.mediaUrl}', 'FULL_SCREEN_MEDIA_PREVIEW', details.error);
        Log.e('PDF load error details: ${details.description}', 'FULL_SCREEN_MEDIA_PREVIEW');
        if (mounted) {
          setState(() {
            _hasError = true;
            _errorMessage = 'Failed to load PDF: ${details.error}';
            _isLoading = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to load PDF: ${details.error}'),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 5),
            ),
          );
        }
      },
      onDocumentLoaded: (PdfDocumentLoadedDetails details) {
        Log.i('PDF loaded successfully: ${details.document.pages.count} pages', 'FULL_SCREEN_MEDIA_PREVIEW');
        if (mounted) {
          // Add a small delay to ensure the PDF viewer is ready
          Future.delayed(const Duration(milliseconds: 100), () {
            if (mounted) {
              setState(() {
                _isLoading = false;
                _hasError = false;
              });
            }
          });
        }
      },
    );
  }

  Future<Uint8List?> _loadPdfBytes() async {
    try {
      // Add headers for ngrok URLs on mobile
      final headers = <String, String>{
        'ngrok-skip-browser-warning': 'true',
        if (!kIsWeb) 'User-Agent': 'Mozilla/5.0 (Linux; Android 10) Mobile',
      };
      
      final response = await http.get(Uri.parse(widget.mediaUrl), headers: headers);
      if (response.statusCode == 200) {
        return response.bodyBytes;
      } else {
        throw Exception('Failed to load PDF: HTTP ${response.statusCode}');
      }
    } catch (e) {
      Log.e('Error loading PDF bytes', 'FULL_SCREEN_MEDIA_PREVIEW', e);
      return null;
    }
  }

  Widget _buildWebPdfViewer() {
    // Resolve URL to local network on web - CRITICAL: This converts ngrok URLs to local network
    final resolvedUrl = _resolveWebSameOriginUrl(widget.mediaUrl);
    
    Log.d('PDF Viewer - Original URL: ${widget.mediaUrl}', 'FULL_SCREEN_MEDIA_PREVIEW');
    Log.d('PDF Viewer - Resolved URL: $resolvedUrl', 'FULL_SCREEN_MEDIA_PREVIEW');
    
    // Use button to open PDF with resolved URL (local network)
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.picture_as_pdf, color: Colors.white, size: 64),
          const SizedBox(height: 24),
          Text(
            widget.fileName ?? 'PDF Document',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () async {
              try {
                // Use resolved URL (local network) instead of original ngrok URL
                final uri = Uri.parse(resolvedUrl);
                Log.d('Opening PDF with resolved URL: $resolvedUrl', 'FULL_SCREEN_MEDIA_PREVIEW');
                if (await canLaunchUrl(uri)) {
                  await launchUrl(uri, mode: LaunchMode.platformDefault);
                } else {
                  Log.w('Cannot launch URL: $resolvedUrl', 'FULL_SCREEN_MEDIA_PREVIEW');
                  _downloadMedia();
                }
              } catch (e) {
                Log.e('Error opening PDF: $e', 'FULL_SCREEN_MEDIA_PREVIEW');
                _downloadMedia();
              }
            },
            icon: const Icon(Icons.open_in_browser),
            label: const Text('Open PDF'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: Colors.black87,
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: _downloadMedia,
            icon: const Icon(Icons.download),
            label: const Text('Download'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: Colors.black87,
            ),
          ),
        ],
      ),
    );
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
