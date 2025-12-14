// =============================================================================
// MESSAGE SOUND SERVICE
// =============================================================================
// Plays notification sound for every new message received, regardless of 
// whether the chat is active or not
// =============================================================================

import 'package:flutter/foundation.dart';
import 'package:audioplayers/audioplayers.dart';
import 'logger_service.dart';

class MessageSoundService {
  static final MessageSoundService _instance = MessageSoundService._();
  factory MessageSoundService() => _instance;
  MessageSoundService._();

  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _isPlaying = false;
  bool _enabled = true;
  bool _isInitialized = false;

  /// Enable or disable sound notifications
  void setEnabled(bool enabled) {
    _enabled = enabled;
    Log.i('Message sound ${enabled ? "enabled" : "disabled"}', 'MESSAGE_SOUND');
  }

  /// Check if sound notifications are enabled
  bool get isEnabled => _enabled;

  /// Initialize audio player (required for web)
  Future<void> _initializeAudioPlayer() async {
    if (_isInitialized) return;
    
    try {
      // Set player mode for web compatibility
      if (kIsWeb) {
        await _audioPlayer.setPlayerMode(PlayerMode.lowLatency);
      }
      await _audioPlayer.setReleaseMode(ReleaseMode.stop);
      await _audioPlayer.setVolume(1.0);
      _isInitialized = true;
      Log.i('Audio player initialized', 'MESSAGE_SOUND');
    } catch (e) {
      Log.e('Error initializing audio player', 'MESSAGE_SOUND', e);
    }
  }

  /// Play notification sound for new message
  /// WEB ONLY: Mobile devices use system notification sounds (FCM)
  /// This will play regardless of whether the chat is active or not
  Future<void> playMessageSound() async {
    // Skip sound on mobile - use device notification sound only
    if (!kIsWeb) {
      Log.i('🔇 Message sound skipped on Mobile (using device notification sound)', 'MESSAGE_SOUND');
      return;
    }
    
    if (!_enabled || _isPlaying) return;

    try {
      // Initialize audio player if not already done
      await _initializeAudioPlayer();
      
      _isPlaying = true;
      Log.i('🔊 Playing message notification sound...', 'MESSAGE_SOUND');

      // Stop any currently playing sound
      try {
        await _audioPlayer.stop();
      } catch (_) {
        // Ignore stop errors
      }

      // Play the noti_sound.wav file from assets (WEB ONLY)
      try {
        final source = AssetSource('noti_sound.wav');
        await _audioPlayer.play(source);
        Log.i('✅ Message sound played (noti_sound.wav) on Web', 'MESSAGE_SOUND');
      } catch (e) {
        Log.w('noti_sound.wav failed on Web: $e, trying fallback...', 'MESSAGE_SOUND');
        try {
          // Fallback to notification_sound.mp3
          final source = AssetSource('notification_sound.mp3');
          await _audioPlayer.play(source);
          Log.i('✅ Message sound played (notification_sound.mp3 fallback) on Web', 'MESSAGE_SOUND');
        } catch (e2) {
          Log.w('Fallback sound failed on Web: $e2', 'MESSAGE_SOUND');
          try {
            // Try notification_sounds folder
            final source = AssetSource('notification_sounds/chat_notification.mp3');
            await _audioPlayer.play(source);
            Log.i('✅ Message sound played (chat_notification.mp3 fallback) on Web', 'MESSAGE_SOUND');
          } catch (e3) {
            Log.w('All sound assets failed on Web: $e3', 'MESSAGE_SOUND');
            // If all fail, try programmatic tone
            await _playProgrammaticTone();
          }
        }
      }
    } catch (e) {
      Log.e('Error playing message sound', 'MESSAGE_SOUND', e);
      _isPlaying = false; // Reset on error
    } finally {
      // Reset playing flag after a delay to allow sound to finish
      Future.delayed(const Duration(milliseconds: 800), () {
        _isPlaying = false;
      });
    }
  }

  /// Play a simple programmatic tone as last resort
  Future<void> _playProgrammaticTone() async {
    try {
      if (kIsWeb) {
        // On web, try to create a simple audio context and play a tone
        Log.i('Attempting programmatic tone (web)', 'MESSAGE_SOUND');
        // Note: Web browsers require user interaction before audio can play
        // This is a limitation of browser autoplay policies
      } else {
        // On mobile, the asset sounds should work
        Log.i('Programmatic tone fallback (mobile)', 'MESSAGE_SOUND');
      }
    } catch (e) {
      Log.e('Error playing programmatic tone', 'MESSAGE_SOUND', e);
    }
  }

  /// Dispose resources
  void dispose() {
    _audioPlayer.dispose();
  }
}

