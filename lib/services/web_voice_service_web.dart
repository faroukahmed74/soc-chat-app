import 'dart:html' as html;
import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'enhanced_voice_service.dart';

class WebVoiceService {
  static html.MediaRecorder? _mediaRecorder;
  static html.MediaStream? _audioStream;
  static final List<html.Blob> _audioChunks = [];
  static bool _isRecording = false;
  static DateTime? _recordingStartTime;

  static Future<bool> startRecording() async {
    if (!kIsWeb) return false;
    
    try {
      _audioStream = await html.window.navigator.mediaDevices?.getUserMedia({
        'audio': {
          'echoCancellation': true,
          'noiseSuppression': true,
          'autoGainControl': true,
        }
      });
      
      if (_audioStream == null) return false;
      
      _mediaRecorder = html.MediaRecorder(_audioStream!);
      _audioChunks.clear();
      
      _mediaRecorder!.addEventListener('dataavailable', (event) {
        final dataEvent = event as html.BlobEvent;
        if (dataEvent.data != null && dataEvent.data!.size > 0) {
          _audioChunks.add(dataEvent.data!);
        }
      });
      
      _mediaRecorder!.start();
      _isRecording = true;
      _recordingStartTime = DateTime.now();
      
      return true;
    } catch (e) {
      print('Error starting voice recording: $e');
      return false;
    }
  }

  static Future<VoiceRecordingResult?> stopRecording() async {
    if (!kIsWeb || _mediaRecorder == null || !_isRecording) return null;
    
    try {
      final completer = Completer<VoiceRecordingResult?>();
      
      _mediaRecorder!.addEventListener('stop', (event) async {
        if (_audioChunks.isNotEmpty) {
          final audioBlob = html.Blob(_audioChunks, 'audio/webm');
          
          // Convert blob to Uint8List
          final reader = html.FileReader();
          reader.addEventListener('load', (event) {
            final result = reader.result as Uint8List;
            
            // Calculate duration
            double durationInSeconds = 0.0;
            if (_recordingStartTime != null) {
              durationInSeconds = DateTime.now().difference(_recordingStartTime!).inMilliseconds / 1000.0;
            }
            
            final recordingResult = VoiceRecordingResult(
              bytes: result,
              duration: durationInSeconds,
              fileName: 'voice_message_${DateTime.now().millisecondsSinceEpoch}.webm',
              mimeType: 'audio/webm',
            );
            
            completer.complete(recordingResult);
          });
          
          reader.addEventListener('error', (event) {
            completer.complete(null);
          });
          
          reader.readAsArrayBuffer(audioBlob);
        } else {
          completer.complete(null);
        }
      });
      
      _mediaRecorder!.stop();
      _isRecording = false;
      
      // Stop the audio stream
      if (_audioStream != null) {
        _audioStream!.getTracks().forEach((track) => track.stop());
        _audioStream = null;
      }
      
      _recordingStartTime = null;
      _audioChunks.clear();
      
      return await completer.future;
    } catch (e) {
      print('Error stopping voice recording: $e');
      _isRecording = false;
      _recordingStartTime = null;
      return null;
    }
  }
  
  static Future<void> cancelRecording() async {
    if (_mediaRecorder != null && _isRecording) {
      _mediaRecorder!.stop();
    }
    if (_audioStream != null) {
      _audioStream!.getTracks().forEach((track) => track.stop());
      _audioStream = null;
    }
    _isRecording = false;
    _recordingStartTime = null;
    _audioChunks.clear();
  }

  static bool get isRecording => _isRecording;
  
  static Duration? get currentRecordingDuration {
    if (_recordingStartTime == null) return null;
    return DateTime.now().difference(_recordingStartTime!);
  }

  static void dispose() {
    if (_mediaRecorder != null && _isRecording) {
      _mediaRecorder!.stop();
    }
    if (_audioStream != null) {
      _audioStream!.getTracks().forEach((track) => track.stop());
    }
    _isRecording = false;
    _recordingStartTime = null;
    _audioChunks.clear();
  }
}

