// lib/config/database_config.dart
import '../services/database_service.dart';

/// Database configuration for switching between Firestore and PostgreSQL
class DatabaseConfig {
  // Set to true to use physical server, false to use Firestore
  static const bool usePhysicalServer = false;
  
  // Physical server configuration
  static const String serverUrl = 'https://your-server.com';
  static const String firestoreFallback = 'firestore';
  
  /// Get the appropriate database service based on configuration
  static DatabaseService getDatabaseService() {
    if (usePhysicalServer) {
      return DatabaseFactory.createDatabaseService(
        usePhysicalServer: true,
        serverUrl: serverUrl,
        authToken: _getAuthToken(),
      );
    } else {
      return DatabaseFactory.createDatabaseService(
        usePhysicalServer: false,
      );
    }
  }
  
  /// Get authentication token for physical server
  static String _getAuthToken() {
    // Implement based on your authentication system
    // This could be a JWT token from Firebase Auth or your own auth system
    return 'your_auth_token_here';
  }
  
  /// Check if physical server is enabled
  static bool get isPhysicalServerEnabled => usePhysicalServer;
  
  /// Get server URL for physical server
  static String get physicalServerUrl => serverUrl;
  
  /// Get fallback database type
  static String get fallbackDatabase => firestoreFallback;
}

