import 'connectivity_service.dart';
import 'offline_message_queue_service.dart';

/// Native offline service — delegates to connectivity + message queue.
class OfflineService {
  static final OfflineService _instance = OfflineService._internal();
  factory OfflineService() => _instance;
  OfflineService._internal();

  bool get isInitialized => ConnectivityService.instance.isInitialized;
  bool get isOnline => ConnectivityService.instance.isOnline;

  Future<void> initialize() async {
    await ConnectivityService.instance.initialize();
    await OfflineMessageQueueService.instance.initialize();
  }

  Future<void> dispose() async {}

  void addConnectivityListener(Function(bool) listener) {
    ConnectivityService.instance.addListener(listener);
  }

  void removeConnectivityListener(Function(bool) listener) {
    ConnectivityService.instance.removeListener(listener);
  }

  Map<String, dynamic> getOfflineStats() {
    final queueStats = OfflineMessageQueueService.instance.getStats();
    return {
      'isOnline': isOnline,
      'isSyncing': queueStats['isSyncing'] ?? false,
      'syncQueue': queueStats['syncQueue'] ?? 0,
      'messages': queueStats['messages'] ?? 0,
      'users': 0,
      'storageUsage': 0,
    };
  }

  Future<void> clearAllOfflineData() async {}
}
