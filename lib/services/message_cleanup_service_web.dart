import 'package:flutter/foundation.dart' show kIsWeb;

/// Web-safe stub for MessageCleanupService.
/// On web, local file cleanup and storage operations are not applicable.
class MessageCleanupService {
  static final MessageCleanupService _instance = MessageCleanupService._internal();
  factory MessageCleanupService() => _instance;
  MessageCleanupService._internal();

  void start() {
    // No-op on web
  }

  void stop() {
    // No-op on web
  }
}