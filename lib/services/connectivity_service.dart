import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../config/database_config.dart';
import 'logger_service.dart';
import 'connectivity_stub.dart'
    if (dart.library.html) 'connectivity_web.dart';

/// Cross-platform connectivity monitor.
/// Web: browser online/offline events + health ping.
/// Mobile/desktop: periodic health ping to the API server.
class ConnectivityService {
  ConnectivityService._();
  static final ConnectivityService instance = ConnectivityService._();

  bool _isOnline = true;
  bool _initialized = false;
  Timer? _pollTimer;
  final List<void Function(bool isOnline)> _listeners = [];

  bool get isOnline => _isOnline;
  bool get isInitialized => _initialized;

  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;

    attachPlatformConnectivityListeners(_setOnline);

    if (kIsWeb) {
      _setOnline(getPlatformNavigatorOnline());
    }

    await checkNow();

    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 8), (_) => checkNow());

    Log.i('ConnectivityService initialized (online=$_isOnline)', 'CONNECTIVITY');
  }

  void addListener(void Function(bool isOnline) listener) {
    _listeners.add(listener);
    listener(_isOnline);
  }

  void removeListener(void Function(bool isOnline) listener) {
    _listeners.remove(listener);
  }

  Future<bool> checkNow() async {
    final wasOnline = _isOnline;
    var online = kIsWeb ? getPlatformNavigatorOnline() : true;

    if (online) {
      online = await _pingApi();
    }

    _setOnline(online);
    return online;
  }

  Future<bool> _pingApi() async {
    try {
      final base = DatabaseConfig.physicalServerUrl;
      if (base.isEmpty) return false;
      final uri = Uri.parse('$base/api/health');
      final response = await http
          .get(uri, headers: {'ngrok-skip-browser-warning': 'true'})
          .timeout(const Duration(seconds: 5));
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  void _setOnline(bool online) {
    if (_isOnline == online) return;
    _isOnline = online;
    Log.i('Connectivity changed: ${online ? "online" : "offline"}', 'CONNECTIVITY');
    for (final listener in List<void Function(bool)>.from(_listeners)) {
      try {
        listener(online);
      } catch (e) {
        Log.e('Connectivity listener error', 'CONNECTIVITY', e);
      }
    }
  }

  void dispose() {
    _pollTimer?.cancel();
    _pollTimer = null;
    _listeners.clear();
    _initialized = false;
  }
}
