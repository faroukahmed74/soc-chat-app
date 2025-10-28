import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:audioplayers/audioplayers.dart';
import '../services/logger_service.dart';

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
        case 'document':
          setState(() {
            _isLoading = false;
          });
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
      _videoController = VideoPlayerController.networkUrl(Uri.parse(widget.mediaUrl));
      await _videoController!.initialize();
      
      _videoController!.addListener(() {
        if (_videoController!.value.isInitialized) {
          setState(() {
            _isVideoInitialized = true;
            _isLoading = false;
          });
        }
      });

      // Auto-play video
      _videoController!.play();
    } catch (e) {
      Log.e('Error initializing video', 'FULL_SCREEN_MEDIA_PREVIEW', e);
      
      // For web platform, show user-friendly message about format compatibility
      if (kIsWeb) {
        setState(() {
          _isLoading = false;
          _hasError = true;
          _errorMessage = 'Video format not supported by browser. Try downloading the video instead.';
        });
      } else {
        setState(() {
          _isLoading = false;
          _hasError = true;
          _errorMessage = 'Failed to load video: $e';
        });
      }
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

      await _audioPlayer!.setSourceUrl(widget.mediaUrl);
      
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
      final uri = Uri.parse(widget.mediaUrl);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      Log.e('Error downloading media', 'FULL_SCREEN_MEDIA_PREVIEW', e);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to download: $e')),
        );
      }
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
    if (_isLoading) return const SizedBox.shrink();
    if (_hasError) return const SizedBox.shrink();

    switch (widget.mediaType) {
      case 'image':
        return GestureDetector(
          onTap: _toggleControls,
          child: InteractiveViewer(
            minScale: 0.5,
            maxScale: 4.0,
            child: Image.network(
              widget.mediaUrl,
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) {
                return const Center(
                  child: Icon(Icons.broken_image, color: Colors.white, size: 64),
                );
              },
            ),
          ),
        );

      case 'video':
        if (_isVideoInitialized && _videoController != null) {
          return GestureDetector(
            onTap: _toggleControls,
            child: AspectRatio(
              aspectRatio: _videoController!.value.aspectRatio,
              child: VideoPlayer(_videoController!),
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
        return Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white.withValues(alpha: 0.3), width: 2),
              ),
              child: const Icon(
                Icons.description,
                color: Colors.white,
                size: 60,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              widget.fileName ?? 'Document',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            if (widget.fileSize != null)
              Text(
                widget.fileSize!,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 14,
                ),
              ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _downloadMedia,
              icon: const Icon(Icons.download),
              label: const Text('Download'),
            ),
          ],
        );

      default:
        return const Center(
          child: Icon(Icons.file_present, color: Colors.white, size: 64),
        );
    }
  }

  Widget _buildMediaControls() {
    if (widget.mediaType == 'video' && _videoController != null) {
      return VideoProgressIndicator(
        _videoController!,
        allowScrubbing: true,
        colors: const VideoProgressColors(
          playedColor: Colors.white,
          bufferedColor: Colors.white30,
          backgroundColor: Colors.white10,
        ),
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
}
