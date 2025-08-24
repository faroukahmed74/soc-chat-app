import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:permission_handler/permission_handler.dart';
import 'package:path_provider/path_provider.dart';
import 'package:audioplayers/audioplayers.dart';
import 'production_permission_service.dart';

class MobileVoiceService {
  static AudioPlayer? _audioPlayer;
  static bool _isRecording = false;
  static String? _recordingPath;

  // Request microphone permission
  // Note: This method now requires BuildContext for proper permission handling
  // Use ProductionPermissionService.requestMicrophonePermission(context) instead
  static Future<bool> requestMicrophonePermission() async {
    if (kIsWeb) return true;
    
    try {
      // Check current status first
      final currentStatus = await Permission.microphone.status;
      
      // If already granted, return true
      if (currentStatus.isGranted) {
        return true;
      }
      
      // If permanently denied, guide user to settings
      await openAppSettings();
      return false;
    } catch (e) {
      print('MobileVoiceService: Error checking microphone permission: $e');
      return false;
    }
  }

  // Start recording (simulated for now - you can integrate with record package later)
  static Future<bool> startRecording() async {
    if (kIsWeb) return false;
    
    try {
      final hasPermission = await requestMicrophonePermission();
      if (!hasPermission) return false;
      
      // For now, we'll simulate recording by creating a dummy audio file
      // In a real implementation, you would use the record package
      final tempDir = await getTemporaryDirectory();
      _recordingPath = '${tempDir.path}/voice_message_${DateTime.now().millisecondsSinceEpoch}.wav';
      
      // Create a dummy audio file (1 second of silence)
      final dummyAudioData = List<int>.filled(44100 * 2, 0); // 1 second of 44.1kHz stereo
      final file = File(_recordingPath!);
      await file.writeAsBytes(dummyAudioData);
      
      _isRecording = true;
      return true;
    } catch (e) {
      print('Error starting voice recording: $e');
      return false;
    }
  }

  // Stop recording
  static Future<Uint8List?> stopRecording() async {
    if (!kIsWeb && _isRecording && _recordingPath != null) {
      try {
        _isRecording = false;
        
        // Read the recorded file
        final file = File(_recordingPath!);
        if (await file.exists()) {
          final bytes = await file.readAsBytes();
          // Clean up
          await file.delete();
          _recordingPath = null;
          return bytes;
        }
        return null;
      } catch (e) {
        print('Error stopping voice recording: $e');
        return null;
      }
    }
    return null;
  }

  // Check if currently recording
  static bool get isRecording => _isRecording;

  // Play audio
  static Future<void> playAudio(Uint8List audioBytes) async {
    if (kIsWeb) return;
    
    try {
      // Save bytes to temporary file
      final tempDir = await getTemporaryDirectory();
      final tempFile = File('${tempDir.path}/temp_audio.wav');
      await tempFile.writeAsBytes(audioBytes);
      
      // Play audio
      _audioPlayer = AudioPlayer();
      await _audioPlayer!.play(DeviceFileSource(tempFile.path));
      
      // Clean up after playing
      _audioPlayer!.onPlayerComplete.listen((_) async {
        await tempFile.delete();
        await _audioPlayer!.dispose();
      });
    } catch (e) {
      print('Error playing audio: $e');
    }
  }

  // Stop playing audio
  static Future<void> stopAudio() async {
    if (_audioPlayer != null) {
      await _audioPlayer!.stop();
      await _audioPlayer!.dispose();
      _audioPlayer = null;
    }
  }

  // Dispose resources
  static void dispose() {
    if (_audioPlayer != null) {
      _audioPlayer!.dispose();
      _audioPlayer = null;
    }
    _isRecording = false;
    _recordingPath = null;
  }
} 