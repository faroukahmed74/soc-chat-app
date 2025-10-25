// lib/services/connection_status_service.dart
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../config/database_config.dart';

/// Service to monitor and report connection status
class ConnectionStatusService extends ChangeNotifier {
  static final ConnectionStatusService _instance = ConnectionStatusService._internal();
  factory ConnectionStatusService() => _instance;
  ConnectionStatusService._internal();

  bool _isConnected = true;
  bool _isChecking = false;
  String _currentServerUrl = '';
  String? _lastError;

  bool get isConnected => _isConnected;
  bool get isChecking => _isChecking;
  String get currentServerUrl => _currentServerUrl;
  String? get lastError => _lastError;

  /// Check connection status
  Future<bool> checkConnection() async {
    if (_isChecking) return _isConnected;
    
    _isChecking = true;
    notifyListeners();

    try {
      final serverUrl = DatabaseConfig.physicalServerUrl;
      _currentServerUrl = serverUrl;
      
      final uri = Uri.parse('$serverUrl/api/health');
      final response = await http.get(uri).timeout(
        const Duration(seconds: 5),
      );

      _isConnected = response.statusCode == 200;
      _lastError = _isConnected ? null : 'Server returned ${response.statusCode}';
    } catch (e) {
      _isConnected = false;
      _lastError = e.toString();
    } finally {
      _isChecking = false;
      notifyListeners();
    }

    return _isConnected;
  }

  /// Get connection status text
  String getStatusText() {
    if (_isChecking) return 'Checking...';
    if (_isConnected) return 'Connected';
    return 'Disconnected';
  }

  /// Get connection status color
  Color getStatusColor() {
    if (_isChecking) return Colors.orange;
    if (_isConnected) return Colors.green;
    return Colors.red;
  }

  /// Get connection status icon
  IconData getStatusIcon() {
    if (_isChecking) return Icons.sync;
    if (_isConnected) return Icons.check_circle;
    return Icons.error;
  }
}

