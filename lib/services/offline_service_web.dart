import 'package:flutter/foundation.dart' show kIsWeb;

/// Web-safe stub for OfflineService.
/// Provides no-op implementations for web to avoid dart:io/Hive dependencies.
class OfflineService {
  static final OfflineService _instance = OfflineService._internal();
  factory OfflineService() => _instance;
  OfflineService._internal();

  bool _isOnline = true;

  bool get isInitialized => true;
  bool get isOnline => _isOnline;

  Future<void> initialize() async {
    // No-op on web
  }

  Future<void> dispose() async {
    // No-op on web
  }

  // Connectivity listeners (no-op)
  void addConnectivityListener(Function(bool) listener) {
    // Immediately notify with current status on web
    try {
      listener(_isOnline);
    } catch (_) {}
  }

  void removeConnectivityListener(Function(bool) listener) {
    // No-op on web
  }

  // Offline statistics
  Map<String, dynamic> getOfflineStats() {
    return {
      'isSyncing': false,
      'queuedActions': 0,
      'storageUsage': 0,
    };
  }

  // Commonly used methods as no-ops
  Future<void> clearAllOfflineData() async {}
}