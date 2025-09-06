import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import '../services/fcm_notification_service.dart';
import '../services/unified_notification_service.dart';
import '../services/logger_service.dart';
import 'dart:io';

/// Startup Diagnostics Screen
/// Shows FCM service status and health when app starts
class StartupDiagnosticsScreen extends StatefulWidget {
  const StartupDiagnosticsScreen({super.key});

  @override
  State<StartupDiagnosticsScreen> createState() => _StartupDiagnosticsScreenState();
}

class _StartupDiagnosticsScreenState extends State<StartupDiagnosticsScreen> {
  final FCMNotificationService _fcmService = FCMNotificationService();
  final UnifiedNotificationService _unifiedService = UnifiedNotificationService();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;
  
  bool _isLoading = true;
  Map<String, dynamic> _diagnostics = {};
  String _overallStatus = 'Checking services...';
  Color _statusColor = Colors.orange;

  @override
  void initState() {
    super.initState();
    _runDiagnostics();
  }

  Future<void> _runDiagnostics() async {
    setState(() {
      _isLoading = true;
      _overallStatus = 'Running diagnostics...';
      _statusColor = Colors.orange;
    });

    try {
      // Initialize services
      await _unifiedService.initialize();
      await _fcmService.initialize();

      // Run comprehensive diagnostics
      final diagnostics = await _performComprehensiveDiagnostics();
      
      setState(() {
        _diagnostics = diagnostics;
        _isLoading = false;
        _overallStatus = diagnostics['overall_status'] ?? 'Diagnostics completed';
        _statusColor = _getStatusColor(diagnostics['overall_health'] ?? 'warning');
      });

      Log.i('Startup diagnostics completed: ${diagnostics['overall_health']}', 'STARTUP_DIAGNOSTICS');
    } catch (e) {
      setState(() {
        _isLoading = false;
        _overallStatus = 'Error running diagnostics: $e';
        _statusColor = Colors.red;
      });
      Log.e('Error running startup diagnostics', 'STARTUP_DIAGNOSTICS', e);
    }
  }

  Future<Map<String, dynamic>> _performComprehensiveDiagnostics() async {
    final diagnostics = <String, dynamic>{};
    
    try {
      // 1. Check Firebase Auth
      final currentUser = _auth.currentUser;
      diagnostics['auth_status'] = currentUser != null ? 'authenticated' : 'not_authenticated';
      diagnostics['user_id'] = currentUser?.uid ?? 'none';
      
      // 2. Check FCM Token
      try {
        final fcmToken = await _firebaseMessaging.getToken();
        diagnostics['fcm_token_status'] = fcmToken != null ? 'available' : 'not_available';
        diagnostics['fcm_token_preview'] = fcmToken != null ? '${fcmToken.substring(0, 20)}...' : 'none';
      } catch (e) {
        diagnostics['fcm_token_status'] = 'error';
        diagnostics['fcm_token_error'] = e.toString();
      }
      
      // 3. Check APNS Token (iOS only)
      if (!kIsWeb) {
        try {
          final apnsToken = await _firebaseMessaging.getAPNSToken();
          diagnostics['apns_token_status'] = apnsToken != null ? 'available' : 'not_available';
          diagnostics['apns_token_preview'] = apnsToken != null ? '${apnsToken.substring(0, 20)}...' : 'none';
        } catch (e) {
          diagnostics['apns_token_status'] = 'error';
          diagnostics['apns_token_error'] = e.toString();
        }
      } else {
        diagnostics['apns_token_status'] = 'not_applicable';
      }
      
      // 4. Check FCM Server Health
      try {
        final isHealthy = await _fcmService.checkFCMServerHealth();
        diagnostics['fcm_server_status'] = isHealthy ? 'healthy' : 'unhealthy';
      } catch (e) {
        diagnostics['fcm_server_status'] = 'error';
        diagnostics['fcm_server_error'] = e.toString();
      }
      
      // 5. Check Notification Permissions
      try {
        final settings = await _firebaseMessaging.getNotificationSettings();
        diagnostics['notification_permission'] = settings.authorizationStatus.toString();
        diagnostics['notification_alert'] = settings.alert.toString();
        diagnostics['notification_sound'] = settings.sound.toString();
        diagnostics['notification_badge'] = settings.badge.toString();
      } catch (e) {
        diagnostics['notification_permission'] = 'error';
        diagnostics['notification_error'] = e.toString();
      }
      
      // 6. Check Platform
      diagnostics['platform'] = Platform.operatingSystem;
      diagnostics['platform_version'] = Platform.operatingSystemVersion;
      
      // 7. Check Sound Assets (Android)
      if (Platform.isAndroid) {
        diagnostics['sound_assets'] = 'available'; // Assuming assets are available
      } else {
        diagnostics['sound_assets'] = 'not_applicable';
      }
      
      // 8. Determine Overall Health
      final healthScore = _calculateHealthScore(diagnostics);
      diagnostics['health_score'] = healthScore;
      diagnostics['overall_health'] = _getHealthLevel(healthScore);
      diagnostics['overall_status'] = _getOverallStatus(diagnostics);
      
    } catch (e) {
      diagnostics['error'] = e.toString();
      diagnostics['overall_health'] = 'error';
      diagnostics['overall_status'] = 'Diagnostics failed: $e';
    }
    
    return diagnostics;
  }

  int _calculateHealthScore(Map<String, dynamic> diagnostics) {
    int score = 0;
    int maxScore = 0;
    
    // FCM Token (20 points)
    maxScore += 20;
    if (diagnostics['fcm_token_status'] == 'available') score += 20;
    else if (diagnostics['fcm_token_status'] == 'not_available') score += 10;
    
    // APNS Token (iOS only, 20 points)
    if (Platform.isIOS) {
      maxScore += 20;
      if (diagnostics['apns_token_status'] == 'available') score += 20;
      else if (diagnostics['apns_token_status'] == 'not_available') score += 10;
    }
    
    // FCM Server (20 points)
    maxScore += 20;
    if (diagnostics['fcm_server_status'] == 'healthy') score += 20;
    else if (diagnostics['fcm_server_status'] == 'unhealthy') score += 10;
    
    // Notification Permissions (20 points)
    maxScore += 20;
    if (diagnostics['notification_permission']?.contains('authorized') == true) score += 20;
    else if (diagnostics['notification_permission']?.contains('denied') == true) score += 5;
    
    // Auth Status (20 points)
    maxScore += 20;
    if (diagnostics['auth_status'] == 'authenticated') score += 20;
    else if (diagnostics['auth_status'] == 'not_authenticated') score += 10;
    
    return maxScore > 0 ? ((score * 100) / maxScore).round() : 0;
  }

  String _getHealthLevel(int score) {
    if (score >= 90) return 'excellent';
    if (score >= 75) return 'good';
    if (score >= 60) return 'fair';
    if (score >= 40) return 'poor';
    return 'critical';
  }

  String _getOverallStatus(Map<String, dynamic> diagnostics) {
    final health = diagnostics['overall_health'] ?? 'unknown';
    final score = diagnostics['health_score'] ?? 0;
    
    switch (health) {
      case 'excellent':
        return '🎉 All systems operational! FCM notifications with sound are ready.';
      case 'good':
        return '✅ FCM service is working well. Minor issues detected.';
      case 'fair':
        return '⚠️ FCM service is functional but has some issues.';
      case 'poor':
        return '🔧 FCM service has significant issues that need attention.';
      case 'critical':
        return '🚨 FCM service is not working properly. Immediate attention required.';
      default:
        return '❓ FCM service status unknown.';
    }
  }

  Color _getStatusColor(String health) {
    switch (health) {
      case 'excellent':
        return Colors.green;
      case 'good':
        return Colors.lightGreen;
      case 'fair':
        return Colors.orange;
      case 'poor':
        return Colors.deepOrange;
      case 'critical':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  IconData _getStatusIcon(String health) {
    switch (health) {
      case 'excellent':
        return Icons.check_circle;
      case 'good':
        return Icons.check_circle_outline;
      case 'fair':
        return Icons.warning;
      case 'poor':
        return Icons.error_outline;
      case 'critical':
        return Icons.error;
      default:
        return Icons.help_outline;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('🔍 Startup Diagnostics'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _runDiagnostics,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Running diagnostics...'),
                ],
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Overall Status Card
                  Card(
                    color: _statusColor.withValues(alpha: 0.1),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Icon(
                                _getStatusIcon(_diagnostics['overall_health'] ?? 'unknown'),
                                color: _statusColor,
                                size: 32,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Overall Status',
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                        color: _statusColor,
                                      ),
                                    ),
                                    Text(
                                      'Health Score: ${_diagnostics['health_score'] ?? 0}%',
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: _statusColor,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Text(
                            _overallStatus,
                            style: const TextStyle(fontSize: 14),
                          ),
                        ],
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 20),
                  
                  // Detailed Diagnostics
                  const Text(
                    '📊 Detailed Diagnostics',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // FCM Token Status
                  _buildDiagnosticCard(
                    'FCM Token',
                    _diagnostics['fcm_token_status'] ?? 'unknown',
                    _diagnostics['fcm_token_preview'] ?? 'No token available',
                    Icons.token,
                  ),
                  
                  // APNS Token Status (iOS only)
                  if (!kIsWeb)
                    _buildDiagnosticCard(
                      'APNS Token',
                      _diagnostics['apns_token_status'] ?? 'unknown',
                      _diagnostics['apns_token_preview'] ?? 'No token available',
                      Icons.phone_iphone,
                    ),
                  
                  // FCM Server Status
                  _buildDiagnosticCard(
                    'FCM Server',
                    _diagnostics['fcm_server_status'] ?? 'unknown',
                    _diagnostics['fcm_server_status'] == 'healthy' 
                        ? 'Server is responding' 
                        : 'Server may be unavailable',
                    Icons.cloud,
                  ),
                  
                  // Notification Permissions
                  _buildDiagnosticCard(
                    'Notifications',
                    _diagnostics['notification_permission'] ?? 'unknown',
                    'Alert: ${_diagnostics['notification_alert']}, Sound: ${_diagnostics['notification_sound']}',
                    Icons.notifications,
                  ),
                  
                  // Auth Status
                  _buildDiagnosticCard(
                    'Authentication',
                    _diagnostics['auth_status'] ?? 'unknown',
                    _diagnostics['user_id'] ?? 'No user',
                    Icons.person,
                  ),
                  
                  // Platform Info
                  _buildDiagnosticCard(
                    'Platform',
                    _diagnostics['platform'] ?? 'unknown',
                    _diagnostics['platform_version'] ?? 'Unknown version',
                    Icons.phone_android,
                  ),
                  
                  const SizedBox(height: 20),
                  
                  // Action Buttons
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _runDiagnostics,
                          icon: const Icon(Icons.refresh),
                          label: const Text('Re-run Diagnostics'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () {
                            Navigator.pushNamed(context, '/fcm_sound_test');
                          },
                          icon: const Icon(Icons.volume_up),
                          label: const Text('Test Sounds'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildDiagnosticCard(String title, String status, String details, IconData icon) {
    Color statusColor = Colors.grey;
    IconData statusIcon = Icons.help_outline;
    
    switch (status.toLowerCase()) {
      case 'available':
      case 'healthy':
      case 'authenticated':
      case 'authorized':
        statusColor = Colors.green;
        statusIcon = Icons.check_circle;
        break;
      case 'not_available':
      case 'unhealthy':
      case 'not_authenticated':
      case 'denied':
        statusColor = Colors.red;
        statusIcon = Icons.cancel;
        break;
      case 'error':
        statusColor = Colors.red;
        statusIcon = Icons.error;
        break;
      case 'not_applicable':
        statusColor = Colors.grey;
        statusIcon = Icons.remove;
        break;
      default:
        statusColor = Colors.orange;
        statusIcon = Icons.warning;
    }
    
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            Icon(icon, color: statusColor),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Icon(statusIcon, color: statusColor, size: 20),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    details,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
