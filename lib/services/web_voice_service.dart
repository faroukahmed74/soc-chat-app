// Export the platform-specific implementation
export 'web_voice_service_stub.dart'
    if (dart.library.html) 'web_voice_service_web.dart';
