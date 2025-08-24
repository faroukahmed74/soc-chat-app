import 'package:flutter/material.dart';
import '../services/production_notification_service.dart';
import '../services/logger_service.dart';

class FcmServerTestScreen extends StatefulWidget {
  const FcmServerTestScreen({super.key});

  @override
  State<FcmServerTestScreen> createState() => _FcmServerTestScreenState();
}

class _FcmServerTestScreenState extends State<FcmServerTestScreen> {
  final ProductionNotificationService _notificationService = ProductionNotificationService();
  String? _fcmToken;
  String? _lastResult;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _getFcmToken();
    _subscribeToTopics();
  }

  Future<void> _getFcmToken() async {
    try {
      final token = await _notificationService.getFcmToken();
      setState(() {
        _fcmToken = token;
      });
      Log.i('FCM Token: $token', 'FCM_SERVER_TEST');
    } catch (e) {
      Log.e('Error getting FCM token', 'FCM_SERVER_TEST', e);
    }
  }

  Future<void> _subscribeToTopics() async {
    try {
      // Subscribe to broadcast topic
      await _notificationService.subscribeToBroadcastTopic();
      
      // Subscribe to user-specific topic (example)
      await _notificationService.subscribeToUserTopic('test_user_123');
      
      // Subscribe to chat-specific topic (example)
      await _notificationService.subscribeToChatTopic('test_chat_456');
      
      Log.i('Subscribed to all topics', 'FCM_SERVER_TEST');
    } catch (e) {
      Log.e('Error subscribing to topics', 'FCM_SERVER_TEST', e);
    }
  }

  Future<void> _testBroadcastNotification() async {
    setState(() {
      _isLoading = true;
      _lastResult = null;
    });

    try {
      final success = await _notificationService.sendBroadcastViaServer(
        title: '🧪 Test Broadcast',
        body: 'This is a test broadcast from your Flutter app!',
        data: {
          'type': 'test_broadcast',
          'timestamp': DateTime.now().toIso8601String(),
          'source': 'flutter_app',
        },
      );

      setState(() {
        _lastResult = success 
          ? '✅ Broadcast sent successfully!' 
          : '❌ Failed to send broadcast';
      });

      if (success) {
        Log.i('Broadcast test successful', 'FCM_SERVER_TEST');
      } else {
        Log.e('Broadcast test failed', 'FCM_SERVER_TEST');
      }
    } catch (e) {
      setState(() {
        _lastResult = '❌ Error: ${e.toString()}';
      });
      Log.e('Error testing broadcast', 'FCM_SERVER_TEST', e);
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _testIndividualNotification() async {
    if (_fcmToken == null) {
      setState(() {
        _lastResult = '❌ No FCM token available';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _lastResult = null;
    });

    try {
      final success = await _notificationService.sendNotificationViaServer(
        recipientToken: _fcmToken!,
        title: '📱 Individual Test',
        body: 'This is a test notification sent to you specifically!',
        data: {
          'type': 'individual_test',
          'timestamp': DateTime.now().toIso8601String(),
          'recipient': 'current_user',
        },
      );

      setState(() {
        _lastResult = success 
          ? '✅ Individual notification sent successfully!' 
          : '❌ Failed to send individual notification';
      });

      if (success) {
        Log.i('Individual notification test successful', 'FCM_SERVER_TEST');
      } else {
        Log.e('Individual notification test failed', 'FCM_SERVER_TEST');
      }
    } catch (e) {
      setState(() {
        _lastResult = '❌ Error: ${e.toString()}';
      });
      Log.e('Error testing individual notification', 'FCM_SERVER_TEST', e);
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('FCM Server Test'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // FCM Token Display
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'FCM Token',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _fcmToken ?? 'Loading...',
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ElevatedButton(
                      onPressed: _getFcmToken,
                      child: const Text('Refresh Token'),
                    ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Test Buttons
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'Test Notifications',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    
                    ElevatedButton.icon(
                      onPressed: _isLoading ? null : _testBroadcastNotification,
                      icon: const Icon(Icons.broadcast_on_personal),
                      label: const Text('Test Broadcast (Topic)'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                      ),
                    ),
                    
                    const SizedBox(height: 12),
                    
                    ElevatedButton.icon(
                      onPressed: _isLoading ? null : _testIndividualNotification,
                      icon: const Icon(Icons.person),
                      label: const Text('Test Individual (Token)'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Results Display
            if (_lastResult != null)
              Card(
                color: _lastResult!.contains('✅') 
                  ? Colors.green.shade50 
                  : Colors.red.shade50,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Last Result',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(_lastResult!),
                    ],
                  ),
                ),
              ),
            
            const Spacer(),
            
            // Instructions
            Card(
              color: Colors.blue.shade50,
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
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      '1. Make sure your FCM server is running on localhost:3000\n'
                      '2. Test broadcast notifications (sent to all users)\n'
                      '3. Test individual notifications (sent to your device)\n'
                      '4. Check your device for incoming notifications',
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
