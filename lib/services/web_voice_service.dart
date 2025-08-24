import 'dart:html' as html;
import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;

class WebVoiceService {
  static html.MediaRecorder? _mediaRecorder;
  static html.MediaStream? _audioStream;
  static final List<html.Blob> _audioChunks = [];
  static bool _isRecording = false;

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
        final data = (event as html.Event).target as html.MediaRecorder;
        if (data.state == 'recording') {
          // Handle data available
        }
      });
      
      _mediaRecorder!.start();
      _isRecording = true;
      
      return true;
    } catch (e) {
      print('Error starting voice recording: $e');
      return false;
    }
  }

  static Future<Uint8List?> stopRecording() async {
    if (!kIsWeb || _mediaRecorder == null || !_isRecording) return null;
    
    try {
      final completer = Completer<Uint8List?>();
      
      _mediaRecorder!.addEventListener('stop', (event) async {
        if (_audioChunks.isNotEmpty) {
          final audioBlob = html.Blob(_audioChunks, 'audio/webm');
          
          // Convert blob to Uint8List
          final reader = html.FileReader();
          reader.addEventListener('load', (event) {
            final result = reader.result as Uint8List;
            completer.complete(result);
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
      
      return await completer.future;
    } catch (e) {
      print('Error stopping voice recording: $e');
      return null;
    }
  }

  static bool get isRecording => _isRecording;

  static void dispose() {
    if (_mediaRecorder != null && _isRecording) {
      _mediaRecorder!.stop();
    }
    if (_audioStream != null) {
      _audioStream!.getTracks().forEach((track) => track.stop());
    }
    _isRecording = false;
    _audioChunks.clear();
  }
} 