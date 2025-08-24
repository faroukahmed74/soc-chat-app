// This is a stub file for mobile platforms
// It provides empty implementations of web media service methods

import 'dart:typed_data';

class WebMediaService {
  static Future<Uint8List?> pickImageFromCamera() async => null;
  static Future<Uint8List?> pickImageFromGallery() async => null;
  static Future<Uint8List?> pickVideoFromCamera() async => null;
  static Future<Uint8List?> pickVideoFromGallery() async => null;
  static Future<Map<String, dynamic>?> pickDocument() async => null;
  static Future<bool> startVoiceRecording() async => false;
  static Future<Uint8List?> stopVoiceRecording() async => null;
  static bool get isVoiceRecording => false;
  static void dispose() {}
} 