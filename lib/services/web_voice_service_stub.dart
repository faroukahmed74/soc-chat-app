import 'dart:typed_data';
import 'enhanced_voice_service.dart';

/// Stub implementation for non-web platforms
class WebVoiceService {
  static Future<bool> startRecording() async => false;
  static Future<VoiceRecordingResult?> stopRecording() async => null;
  static Future<void> cancelRecording() async {}
  static bool get isRecording => false;
  static Duration? get currentRecordingDuration => null;
  static void dispose() {}
}

