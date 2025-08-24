/// Stub implementation of WebMediaService for mobile platforms
/// This file is imported when dart:html is not available (i.e., on mobile)
class WebMediaService {
  /// Pick an image from camera (stub - not used on mobile)
  static Future<Map<String, dynamic>?> pickImageFromCamera() async {
    return null;
  }

  /// Pick an image from gallery (stub - not used on mobile)
  static Future<Map<String, dynamic>?> pickImageFromGallery() async {
    return null;
  }

  /// Pick a document (stub - not used on mobile)
  static Future<Map<String, dynamic>?> pickDocument() async {
    return null;
  }

  /// Pick a video (stub - not used on mobile)
  static Future<Map<String, dynamic>?> pickVideo() async {
    return null;
  }

  /// Pick a video from camera (stub - not used on mobile)
  static Future<Map<String, dynamic>?> pickVideoFromCamera() async {
    return null;
  }

  /// Pick a video from gallery (stub - not used on mobile)
  static Future<Map<String, dynamic>?> pickVideoFromGallery() async {
    return null;
  }

  /// Start voice recording (stub - not used on mobile)
  static Future<Map<String, dynamic>?> startVoiceRecording() async {
    return null;
  }

  /// Stop voice recording (stub - not used on mobile)
  static Future<Map<String, dynamic>?> stopVoiceRecording() async {
    return null;
  }

  /// Check if voice recording is active (stub - not used on mobile)
  static bool isVoiceRecording() => false;
}

