import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'dart:typed_data';
import '../services/enhanced_voice_service.dart';
import '../services/logger_service.dart';

class VoiceMessagePlayer extends StatefulWidget {
  final Uint8List audioBytes;
  final String? fileName;
  final double? duration;
  final bool isSender;
  final VoidCallback? onPlayStateChanged;

  const VoiceMessagePlayer({
    super.key,
    required this.audioBytes,
    this.fileName,
    this.duration,
    this.isSender = false,
    this.onPlayStateChanged,
  });

  @override
  State<VoiceMessagePlayer> createState() => _VoiceMessagePlayerState();
}

class _VoiceMessagePlayerState extends State<VoiceMessagePlayer> {
  bool _isPlaying = false;
  bool _isLoading = false;
  Duration _totalDuration = Duration.zero;

  @override
  void initState() {
    super.initState();
    _totalDuration = widget.duration != null 
        ? Duration(milliseconds: (widget.duration! * 1000).round())
        : Duration.zero;
    _setupAudioPlayer();
  }

  void _setupAudioPlayer() {
    // No streams available in current service
    // We'll use the available methods instead
  }

  @override
  void dispose() {
    // Stop audio if this widget is disposed
    if (_isPlaying) {
      EnhancedVoiceService.stopAudio();
    }
    super.dispose();
  }

  Future<void> _togglePlayPause() async {
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
    });

    try {
      if (_isPlaying) {
        // Pause audio
        await EnhancedVoiceService.pauseAudio();
        setState(() {
          _isPlaying = false;
        });
      } else {
        // Play audio
        final success = await EnhancedVoiceService.playAudio(
          widget.audioBytes,
          fileName: widget.fileName,
        );
        
        if (success) {
          setState(() {
            _isPlaying = true;
          });
          
          // Set up a timer to check completion status
          _checkPlaybackStatus();
        }
      }
      
      widget.onPlayStateChanged?.call();
    } catch (e) {
      Log.e('Error toggling play/pause', 'VOICE_PLAYER', e);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error playing voice message: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _stopAudio() async {
    if (_isLoading) return;

    try {
      await EnhancedVoiceService.stopAudio();
      setState(() {
        _isPlaying = false;
      });
      widget.onPlayStateChanged?.call();
    } catch (e) {
      Log.e('Error stopping audio', 'VOICE_PLAYER', e);
    }
  }

  void _checkPlaybackStatus() {
    // Check playback status periodically
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted && _isPlaying) {
        final state = EnhancedVoiceService.audioPlayerState;
        if (state == PlayerState.completed || state == PlayerState.stopped) {
          setState(() {
            _isPlaying = false;
          });
          widget.onPlayStateChanged?.call();
        } else {
          // Continue checking
          _checkPlaybackStatus();
        }
      }
    });
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: widget.isSender 
            ? theme.colorScheme.primary.withOpacity(0.1)
            : theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: widget.isSender 
              ? theme.colorScheme.primary.withOpacity(0.3)
              : theme.colorScheme.outline.withOpacity(0.3),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Play/Pause Button
          GestureDetector(
            onTap: _togglePlayPause,
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: widget.isSender 
                    ? theme.colorScheme.primary
                    : theme.colorScheme.secondary,
                shape: BoxShape.circle,
              ),
              child: _isLoading
                  ? const Center(
                      child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      ),
                    )
                  : Icon(
                      _isPlaying ? Icons.pause : Icons.play_arrow,
                      color: Colors.white,
                      size: 20,
                    ),
            ),
          ),
          
          const SizedBox(width: 12),
          
          // Audio Waveform Icon
          Icon(
            Icons.graphic_eq,
            color: _isPlaying 
                ? theme.colorScheme.primary
                : theme.colorScheme.onSurface.withOpacity(0.6),
            size: 20,
          ),
          
          const SizedBox(width: 8),
          
          // Duration Text
          Text(
            _formatDuration(_totalDuration),
            style: TextStyle(
              fontSize: 12,
              color: theme.colorScheme.onSurface.withOpacity(0.7),
              fontWeight: FontWeight.w500,
            ),
          ),
          
          const SizedBox(width: 8),
          
          // Stop Button (only show when playing)
          if (_isPlaying)
            GestureDetector(
              onTap: _stopAudio,
              child: Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: theme.colorScheme.error.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.stop,
                  color: theme.colorScheme.error,
                  size: 14,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// A simplified voice message indicator for chat list
class VoiceMessageIndicator extends StatelessWidget {
  final bool isSender;
  final VoidCallback? onTap;

  const VoiceMessageIndicator({
    super.key,
    this.isSender = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: isSender 
              ? theme.colorScheme.primary.withOpacity(0.1)
              : theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSender 
                ? theme.colorScheme.primary.withOpacity(0.3)
                : theme.colorScheme.outline.withOpacity(0.3),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.mic,
              size: 16,
              color: isSender 
                  ? theme.colorScheme.primary
                  : theme.colorScheme.onSurface.withOpacity(0.7),
            ),
            const SizedBox(width: 4),
            Text(
              'Voice Message',
              style: TextStyle(
                fontSize: 12,
                color: isSender 
                    ? theme.colorScheme.primary
                    : theme.colorScheme.onSurface.withOpacity(0.7),
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              Icons.play_arrow,
              size: 14,
              color: isSender 
                  ? theme.colorScheme.primary
                  : theme.colorScheme.onSurface.withOpacity(0.7),
            ),
          ],
        ),
      ),
    );
  }
}
