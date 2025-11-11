import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:flutter/foundation.dart';
import 'package:chewie/chewie.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;

class InAppVideoPlayer extends StatefulWidget {
  final String videoUrl;
  final String videoTitle;

  const InAppVideoPlayer({
    Key? key,
    required this.videoUrl,
    required this.videoTitle,
  }) : super(key: key);

  @override
  State<InAppVideoPlayer> createState() => _InAppVideoPlayerState();
}

class _InAppVideoPlayerState extends State<InAppVideoPlayer> {
  VideoPlayerController? _videoPlayerController;
  ChewieController? _chewieController;
  bool _isLoading = true;
  bool _hasError = false;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _initializeVideoPlayer();
  }

  Future<void> _initializeVideoPlayer() async {
    try {
      setState(() {
        _isLoading = true;
        _hasError = false;
      });

      // Platform-specific video handling
      if (Platform.isIOS) {
        // iOS-specific video handling with better error recovery
        await _initializeVideoPlayerIOS();
      } else {
        // Android and other platforms
        await _initializeVideoPlayerStandard();
      }

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _hasError = true;
        _errorMessage = e.toString();
      });
    }
  }

  Future<void> _initializeVideoPlayerIOS() async {
    final videoUrl = _resolveWebSameOriginUrl(widget.videoUrl);
    
    // Build headers with ngrok support
    final headers = <String, String>{};
    if (videoUrl.contains('ngrok') || 
        videoUrl.contains('ngrok-free.app') || 
        videoUrl.contains('ngrok.app')) {
      headers['ngrok-skip-browser-warning'] = 'true';
    }
    headers['User-Agent'] = 'Mozilla/5.0 (iPhone; CPU iPhone OS 14_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/14.0 Mobile/15E148 Safari/604.1';
    
    try {
      // First try with headers
      _videoPlayerController = VideoPlayerController.networkUrl(
        Uri.parse(videoUrl),
        httpHeaders: headers,
      );
      await _videoPlayerController!.initialize();
    } catch (e) {
      // If that fails, try downloading first
      try {
        await _initializeVideoPlayerWithDownload();
      } catch (e2) {
        // Re-throw if download also fails
        rethrow;
      }
    }

    _createChewieController();
  }

  Future<void> _initializeVideoPlayerStandard() async {
    // Add headers for Android, especially for ngrok URLs
    final headers = <String, String>{};
    final videoUrl = _resolveWebSameOriginUrl(widget.videoUrl);
    
    // Add ngrok header if URL contains ngrok (required for Android 10+)
    if (videoUrl.contains('ngrok') || 
        videoUrl.contains('ngrok-free.app') || 
        videoUrl.contains('ngrok.app')) {
      headers['ngrok-skip-browser-warning'] = 'true';
    }
    
    // Add User-Agent for Android
    headers['User-Agent'] = 'Mozilla/5.0 (Linux; Android 10) Mobile';
    
    _videoPlayerController = VideoPlayerController.networkUrl(
      Uri.parse(videoUrl),
      httpHeaders: headers,
    );
    await _videoPlayerController!.initialize();
    _createChewieController();
  }

  Future<void> _initializeVideoPlayerWithDownload() async {
    try {
      // Download video to temporary file first
      final tempDir = await getTemporaryDirectory();
      final tempFile = File('${tempDir.path}/temp_video_${DateTime.now().millisecondsSinceEpoch}.mp4');
      
      final videoUrl = _resolveWebSameOriginUrl(widget.videoUrl);
      
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
      
      final response = await http.get(Uri.parse(videoUrl), headers: headers);
      await tempFile.writeAsBytes(response.bodyBytes);
      
      _videoPlayerController = VideoPlayerController.file(tempFile);
      await _videoPlayerController!.initialize();
      _createChewieController();
    } catch (e) {
      throw Exception('Failed to load video: $e');
    }
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

  void _createChewieController() {
    _chewieController = ChewieController(
      videoPlayerController: _videoPlayerController!,
      autoPlay: true,
      looping: false,
      allowFullScreen: true,
      allowMuting: true,
      showControls: true,
      materialProgressColors: ChewieProgressColors(
        playedColor: Colors.blue,
        handleColor: Colors.blue,
        backgroundColor: Colors.grey,
        bufferedColor: Colors.grey.shade300,
      ),
      placeholder: Container(
        color: Colors.black,
        child: const Center(
          child: CircularProgressIndicator(
            color: Colors.white,
          ),
        ),
      ),
      errorBuilder: (context, errorMessage) {
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.error_outline,
                color: Colors.white,
                size: 50,
              ),
              const SizedBox(height: 16),
              Text(
                'Error loading video',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                errorMessage,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 14,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    _videoPlayerController?.dispose();
    _chewieController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(
          widget.videoTitle,
          style: const TextStyle(color: Colors.white),
        ),
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.fullscreen, color: Colors.white),
            onPressed: () {
              if (_chewieController != null) {
                _chewieController!.enterFullScreen();
              }
            },
          ),
        ],
      ),
      body: _buildVideoContent(),
    );
  }

  Widget _buildVideoContent() {
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(
              color: Colors.white,
            ),
            SizedBox(height: 16),
            Text(
              'Loading video...',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
              ),
            ),
          ],
        ),
      );
    }

    if (_hasError) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.error_outline,
              color: Colors.white,
              size: 64,
            ),
            const SizedBox(height: 16),
            const Text(
              'Failed to load video',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _errorMessage,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _initializeVideoPlayer,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
              ),
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (_chewieController != null) {
      return Chewie(controller: _chewieController!);
    }

    return const Center(
      child: Text(
        'Video player not initialized',
        style: TextStyle(color: Colors.white),
      ),
    );
  }
}
