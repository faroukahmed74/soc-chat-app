import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:path_provider/path_provider.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:record/record.dart';
import 'logger_service.dart';

/// Enhanced voice service with real audio recording capabilities
class EnhancedVoiceService {
  static AudioPlayer? _audioPlayer;
  static AudioRecorder? _audioRecorder;
  static bool _isRecording = false;
  static String? _recordingPath;
  static DateTime? _recordingStartTime;
  
  /// Request microphone permission
  static Future<bool> requestMicrophonePermission(BuildContext context) async {
    try {
      Log.i('Requesting microphone permission', 'ENHANCED_VOICE');
      
      final status = await Permission.microphone.status;
      Log.i('Microphone permission status: $status', 'ENHANCED_VOICE');
      
      if (status.isGranted) {
        Log.i('Microphone permission already granted', 'ENHANCED_VOICE');
        return true;
      }
      
      if (status.isPermanentlyDenied) {
        Log.w('Microphone permission permanently denied', 'ENHANCED_VOICE');
        _showSettingsDialog(context, 'Microphone Permission', 
          'Microphone access is needed to record voice messages. Please enable it in device settings.');
        return false;
      }
      
      // Request permission
      Log.i('Requesting microphone permission...', 'ENHANCED_VOICE');
      final result = await Permission.microphone.request();
      Log.i('Microphone permission result: $result', 'ENHANCED_VOICE');
      
      return result.isGranted;
      
    } catch (e) {
      Log.e('Error requesting microphone permission', 'ENHANCED_VOICE', e);
      return false;
    }
  }
  
  /// Start voice recording
  static Future<bool> startRecording(BuildContext context) async {
    try {
      Log.i('Starting voice recording...', 'ENHANCED_VOICE');
      
      if (kIsWeb) {
        // Web recording handled separately via WebVoiceService
        Log.w('Web recording should use WebVoiceService', 'ENHANCED_VOICE');
        return false;
      }
      
      // Check permission first
      final hasPermission = await requestMicrophonePermission(context);
      if (!hasPermission) {
        Log.w('Microphone permission denied', 'ENHANCED_VOICE');
        return false;
      }
      
      // Initialize recorder if needed
      _audioRecorder ??= AudioRecorder();
      
      // Check if recorder is available
      if (!await _audioRecorder!.hasPermission()) {
        Log.w('Audio recorder permission denied', 'ENHANCED_VOICE');
        return false;
      }
      
      // Get temporary directory for recording
      final tempDir = await getTemporaryDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      
      // Use appropriate format for each platform
      if (Platform.isIOS) {
        _recordingPath = '${tempDir.path}/voice_message_$timestamp.m4a';
      } else if (Platform.isAndroid) {
        _recordingPath = '${tempDir.path}/voice_message_$timestamp.m4a';
      } else {
        _recordingPath = '${tempDir.path}/voice_message_$timestamp.wav';
      }
      
      Log.i('Recording path: $_recordingPath', 'ENHANCED_VOICE');
      
      // Start recording
      await _audioRecorder!.start(
        const RecordConfig(
          encoder: AudioEncoder.aacLc, // Use AAC for better compression
          bitRate: 128000,
          sampleRate: 44100,
        ),
        path: _recordingPath!,
      );
      
      _isRecording = true;
      _recordingStartTime = DateTime.now();
      
      Log.i('Voice recording started successfully', 'ENHANCED_VOICE');
      return true;
      
    } catch (e) {
      Log.e('Error starting voice recording', 'ENHANCED_VOICE', e);
      _isRecording = false;
      _recordingPath = null;
      _recordingStartTime = null;
      return false;
    }
  }
  
  /// Stop voice recording and get audio data
  static Future<VoiceRecordingResult?> stopRecording() async {
    try {
      print('[ENHANCED_VOICE] stopRecording called, _isRecording: $_isRecording, _audioRecorder: ${_audioRecorder != null}');
      
      if (!_isRecording || _audioRecorder == null) {
        Log.w('No recording in progress', 'ENHANCED_VOICE');
        print('[ENHANCED_VOICE] Cannot stop: isRecording=$_isRecording, recorder=${_audioRecorder != null}');
        return null;
      }
      
      Log.i('Stopping voice recording...', 'ENHANCED_VOICE');
      print('[ENHANCED_VOICE] Calling recorder.stop()...');
      
      // Stop the recorder
      final path = await _audioRecorder!.stop();
      _isRecording = false;
      
      print('[ENHANCED_VOICE] Recorder stopped, path: $path');
      
      if (path == null || path.isEmpty) {
        Log.w('No recording path returned', 'ENHANCED_VOICE');
        print('[ENHANCED_VOICE] ERROR: No path returned from recorder.stop()');
        _recordingPath = null;
        _recordingStartTime = null;
        return null;
      }
      
      // Update recording path with actual path returned
      _recordingPath = path;
      
      // Calculate recording duration
      Duration? duration;
      if (_recordingStartTime != null) {
        duration = DateTime.now().difference(_recordingStartTime!);
      }
      
      // Try to get duration from the recorder
      final durationInSeconds = duration != null 
          ? duration.inMilliseconds / 1000.0
          : 0.0;
      
      Log.i('Recording duration: ${durationInSeconds.toStringAsFixed(1)}s', 'ENHANCED_VOICE');
      
      // Read the recorded file
      final file = File(path);
      print('[ENHANCED_VOICE] Checking if file exists: $path');
      if (!await file.exists()) {
        Log.e('Recorded file does not exist: $path', 'ENHANCED_VOICE', null);
        print('[ENHANCED_VOICE] ERROR: File does not exist at path: $path');
        _recordingPath = null;
        _recordingStartTime = null;
        return null;
      }
      
      print('[ENHANCED_VOICE] Reading file bytes...');
      final bytes = await file.readAsBytes();
      print('[ENHANCED_VOICE] File read successfully, size: ${bytes.length} bytes');
      
      // Determine mime type based on file extension
      String mimeType = 'audio/m4a';
      String fileName = 'voice_message_${DateTime.now().millisecondsSinceEpoch}';
      if (path.endsWith('.m4a')) {
        mimeType = 'audio/m4a';
        fileName += '.m4a';
      } else if (path.endsWith('.aac')) {
        mimeType = 'audio/aac';
        fileName += '.aac';
      } else if (path.endsWith('.wav')) {
        mimeType = 'audio/wav';
        fileName += '.wav';
      } else if (path.endsWith('.mp3')) {
        mimeType = 'audio/mp3';
        fileName += '.mp3';
      }
      
      // Clean up temporary file after reading (optional - you might want to keep it)
      // await file.delete();
      
      final result = VoiceRecordingResult(
        bytes: bytes,
        duration: durationInSeconds,
        fileName: fileName,
        mimeType: mimeType,
      );
      
      // Clean up
      _recordingPath = null;
      _recordingStartTime = null;
      
      Log.i('Voice recording stopped successfully, size: ${bytes.length} bytes', 'ENHANCED_VOICE');
      return result;
      
    } catch (e) {
      Log.e('Error stopping voice recording', 'ENHANCED_VOICE', e);
      _isRecording = false;
      _recordingPath = null;
      _recordingStartTime = null;
      return null;
    }
  }
  
  /// Cancel recording without saving
  static Future<void> cancelRecording() async {
    try {
      if (_isRecording && _audioRecorder != null) {
        await _audioRecorder!.stop();
        _isRecording = false;
        
        // Delete the recording file if it exists
        if (_recordingPath != null) {
          final file = File(_recordingPath!);
          if (await file.exists()) {
            await file.delete();
          }
        }
      }
      
      _recordingPath = null;
      _recordingStartTime = null;
      Log.i('Recording cancelled', 'ENHANCED_VOICE');
    } catch (e) {
      Log.e('Error cancelling recording', 'ENHANCED_VOICE', e);
    }
  }
  
  
  /// Check if currently recording
  static bool get isRecording => _isRecording;
  
  /// Get current recording duration
  static Duration? get currentRecordingDuration {
    if (_recordingStartTime == null) return null;
    return DateTime.now().difference(_recordingStartTime!);
  }
  
  /// Play audio from bytes
  static Future<bool> playAudio(Uint8List audioBytes, {String? fileName}) async {
    try {
      Log.i('Playing audio: ${fileName ?? 'unknown'}', 'ENHANCED_VOICE');
      
      // Save bytes to temporary file
      final tempDir = await getTemporaryDirectory();
      final tempFile = File('${tempDir.path}/temp_audio_${DateTime.now().millisecondsSinceEpoch}.m4a');
      await tempFile.writeAsBytes(audioBytes);
      
      // Initialize audio player if needed
      _audioPlayer ??= AudioPlayer();
      
      // Play the audio
      await _audioPlayer!.play(DeviceFileSource(tempFile.path));
      
      Log.i('Audio playback started', 'ENHANCED_VOICE');
      return true;
      
    } catch (e) {
      Log.e('Error playing audio', 'ENHANCED_VOICE', e);
      return false;
    }
  }
  
  /// Stop audio playback
  static Future<void> stopAudio() async {
    try {
      await _audioPlayer?.stop();
      Log.i('Audio playback stopped', 'ENHANCED_VOICE');
    } catch (e) {
      Log.e('Error stopping audio', 'ENHANCED_VOICE', e);
    }
  }
  
  /// Pause audio playback
  static Future<void> pauseAudio() async {
    try {
      await _audioPlayer?.pause();
      Log.i('Audio playback paused', 'ENHANCED_VOICE');
    } catch (e) {
      Log.e('Error pausing audio', 'ENHANCED_VOICE', e);
    }
  }
  
  /// Resume audio playback
  static Future<void> resumeAudio() async {
    try {
      await _audioPlayer?.resume();
      Log.i('Audio playback resumed', 'ENHANCED_VOICE');
    } catch (e) {
      Log.e('Error resuming audio', 'ENHANCED_VOICE', e);
    }
  }
  
  /// Get audio player state
  static PlayerState? get audioPlayerState => _audioPlayer?.state;
  
  /// Dispose audio player and recorder
  static void dispose() {
    _audioPlayer?.dispose();
    _audioPlayer = null;
    _audioRecorder?.dispose();
    _audioRecorder = null;
  }
  
  /// Show settings dialog
  static void _showSettingsDialog(BuildContext context, String title, String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              openAppSettings();
            },
            child: const Text('Open Settings'),
          ),
        ],
      ),
    );
  }
}

/// Result object for voice recording
class VoiceRecordingResult {
  final Uint8List bytes;
  final double duration;
  final String fileName;
  final String mimeType;
  
  VoiceRecordingResult({
    required this.bytes,
    required this.duration,
    required this.fileName,
    required this.mimeType,
  });
  
  /// Get formatted duration string
  String get formattedDuration {
    final minutes = (duration / 60).floor();
    final seconds = (duration % 60).round();
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }
  
  /// Get file size in human readable format
  String get formattedSize {
    if (bytes.length < 1024) return '${bytes.length}B';
    if (bytes.length < 1024 * 1024) return '${(bytes.length / 1024).toStringAsFixed(1)}KB';
    return '${(bytes.length / (1024 * 1024)).toStringAsFixed(1)}MB';
  }
}
