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

