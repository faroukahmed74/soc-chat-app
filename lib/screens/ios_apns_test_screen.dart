import 'package:flutter/material.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import '../services/unified_notification_service.dart';
import '../services/logger_service.dart';

/// iOS APNS Test Screen
/// Tests APNS token functionality for iOS notifications
class IOSAPNSTestScreen extends StatefulWidget {
  const IOSAPNSTestScreen({super.key});

  @override
  State<IOSAPNSTestScreen> createState() => _IOSAPNSTestScreenState();
}

class _IOSAPNSTestScreenState extends State<IOSAPNSTestScreen> {
  final UnifiedNotificationService _unifiedService = UnifiedNotificationService();
  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;
  
  bool _isLoading = false;
  String _status = 'Ready to test APNS token';
  String? _apnsToken;
  String? _fcmToken;

  @override
  void initState() {
    super.initState();
    _checkTokens();
  }

  Future<void> _checkTokens() async {
    setState(() {
      _isLoading = true;
      _status = 'Checking APNS and FCM tokens...';
    });

    try {
      // Check APNS token
      final apnsToken = await _firebaseMessaging.getAPNSToken();
      setState(() {
        _apnsToken = apnsToken;
      });

      // Check FCM token
      final fcmToken = await _firebaseMessaging.getToken();
      setState(() {
        _fcmToken = fcmToken;
      });

      setState(() {
        _status = 'Tokens checked successfully';
        _isLoading = false;
      });

      Log.i('APNS Token: ${apnsToken?.substring(0, 20) ?? "null"}...', 'APNS_TEST');
      Log.i('FCM Token: ${fcmToken?.substring(0, 20) ?? "null"}...', 'APNS_TEST');
    } catch (e) {
      setState(() {
        _status = 'Error checking tokens: $e';
        _isLoading = false;
      });
      Log.e('Error checking tokens', 'APNS_TEST', e);
    }
  }

  Future<void> _testAPNSTokenRefresh() async {
    setState(() {
      _isLoading = true;
      _status = 'Testing APNS token refresh...';
    });

    try {
      final success = await _unifiedService.checkAndRefreshAPNSToken();
      
      if (success) {
        setState(() {
          _status = '✅ APNS token refresh successful';
          _isLoading = false;
        });
        
        // Refresh token display
        await _checkTokens();
      } else {
        setState(() {
          _status = '❌ APNS token refresh failed';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _status = '❌ Error refreshing APNS token: $e';
        _isLoading = false;
      });
      Log.e('Error refreshing APNS token', 'APNS_TEST', e);
    }
  }

  Future<void> _testIOSNotification() async {
    setState(() {
      _isLoading = true;
      _status = 'Testing iOS notification...';
    });

    try {
      await _unifiedService.sendTestNotification();
      
      setState(() {
        _status = '✅ iOS notification test sent';
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _status = '❌ Error sending iOS notification: $e';
        _isLoading = false;
      });
      Log.e('Error sending iOS notification', 'APNS_TEST', e);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('🍎 iOS APNS Test'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Status Card
            Card(
              color: Colors.blue.shade50,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '📊 Test Status',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _status,
                      style: const TextStyle(fontSize: 14),
                    ),
                    if (_isLoading) ...[
                      const SizedBox(height: 8),
                      const LinearProgressIndicator(),
                    ],
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 20),
            
            // Token Information
            const Text(
              '🔑 Token Information',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            
            const SizedBox(height: 16),
            
            // APNS Token
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'APNS Token',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.orange,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _apnsToken != null 
                        ? '${_apnsToken!.substring(0, 20)}...' 
                        : 'Not available',
                      style: TextStyle(
                        fontSize: 14,
                        color: _apnsToken != null ? Colors.green : Colors.red,
                      ),
                    ),
                    if (_apnsToken != null) ...[
                      const SizedBox(height: 4),
                      const Text(
                        '✅ APNS token is available',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.green,
                        ),
                      ),
                    ] else ...[
                      const SizedBox(height: 4),
                      const Text(
                        '❌ APNS token is missing',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.red,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 8),
            
            // FCM Token
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'FCM Token',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _fcmToken != null 
                        ? '${_fcmToken!.substring(0, 20)}...' 
                        : 'Not available',
                      style: TextStyle(
                        fontSize: 14,
                        color: _fcmToken != null ? Colors.green : Colors.red,
                      ),
                    ),
                    if (_fcmToken != null) ...[
                      const SizedBox(height: 4),
                      const Text(
                        '✅ FCM token is available',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.green,
                        ),
                      ),
                    ] else ...[
                      const SizedBox(height: 4),
                      const Text(
                        '❌ FCM token is missing',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.red,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 20),
            
            // Test Buttons
            const Text(
              '🧪 Test Actions',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            
            const SizedBox(height: 16),
            
            ElevatedButton.icon(
              onPressed: _isLoading ? null : _checkTokens,
              icon: const Icon(Icons.refresh),
              label: const Text('Refresh Tokens'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
            
            const SizedBox(height: 8),
            
            ElevatedButton.icon(
              onPressed: _isLoading ? null : _testAPNSTokenRefresh,
              icon: const Icon(Icons.autorenew),
              label: const Text('Test APNS Token Refresh'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
            
            const SizedBox(height: 8),
            
            ElevatedButton.icon(
              onPressed: _isLoading ? null : _testIOSNotification,
              icon: const Icon(Icons.notifications),
              label: const Text('Test iOS Notification'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
            
            const SizedBox(height: 20),
            
            // Instructions
            Card(
              color: Colors.amber.shade50,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '📋 Instructions',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.amber,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      '1. APNS token is required for iOS notifications\n'
                      '2. If APNS token is null, try refreshing\n'
                      '3. Test iOS notification to verify functionality\n'
                      '4. Check device logs for detailed information\n'
                      '5. Ensure device is connected to internet',
                      style: TextStyle(fontSize: 14),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
