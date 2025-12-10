/// Call type enumeration
enum CallType {
  voice,  // Audio-only call
  video,   // Video call with audio
}

/// Call state enumeration
enum CallState {
  idle,      // No call active
  initiating, // Call is being initiated
  ringing,   // Call is ringing (incoming or outgoing)
  active,    // Call is active
  ended,     // Call has ended
  rejected,  // Call was rejected
  busy,      // Call failed - user is busy
}

/// Call direction
enum CallDirection {
  incoming,  // Incoming call
  outgoing,  // Outgoing call
}

/// Helper class for CallType conversions
class CallTypeHelper {
  /// Convert CallType enum to string for API/server communication
  /// Returns 'voice' for CallType.voice, 'video' for CallType.video
  static String toServerString(CallType type) {
    return type == CallType.voice ? 'voice' : 'video';
  }
  
  /// Convert string to CallType enum
  /// Handles both 'voice' and 'audio' strings (server normalizes 'voice' to 'audio')
  /// Returns CallType.voice for 'voice'/'audio', CallType.video for 'video'
  static CallType fromString(String str) {
    return (str == 'voice' || str == 'audio') ? CallType.voice : CallType.video;
  }
  
  /// Convert CallType enum to string for UI display
  /// Returns 'voice' for CallType.voice, 'video' for CallType.video
  static String toDisplayString(CallType type) {
    return type == CallType.voice ? 'voice' : 'video';
  }
}

