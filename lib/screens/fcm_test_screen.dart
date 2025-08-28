import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import '../services/fcm_service.dart';
import '../services/logger_service.dart';

/// FCM Test Screen for testing push notifications
class FCMTestScreen extends StatefulWidget {
  const FCMTestScreen({super.key});

  @override
  State<FCMTestScreen> createState() => _FCMTestScreenState();
}

class _FCMTestScreenState extends State<FCMTestScreen> {
  String? _fcmToken;
  String _notificationStatus = 'No notifications received';
  List<String> _receivedMessages = [];

  @override
  void initState() {
    super.initState();
    _loadFCMToken();
    _setupMessageListener();
  }

  /// Load FCM token
  Future<void> _loadFCMToken() async {
    try {
      final token = FCMService().fcmToken;
      setState(() {
        _fcmToken = token;
      });
    } catch (e) {
      Log.e('Error loading FCM token', 'FCM_TEST_SCREEN', e);
    }
  }

  /// Set up message listener for testing
  void _setupMessageListener() {
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      setState(() {
        _notificationStatus = 'Foreground message received: ${message.messageId}';
        _receivedMessages.add('${DateTime.now().toString()}: ${message.notification?.title ?? 'No title'} - ${message.notification?.body ?? 'No body'}');
      });
      Log.i('Test message received: ${message.messageId}', 'FCM_TEST_SCREEN');
    });

    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      setState(() {
        _notificationStatus = 'App opened from notification: ${message.messageId}';
        _receivedMessages.add('${DateTime.now().toString()}: App opened from notification - ${message.notification?.title ?? 'No title'}');
      });
      Log.i('App opened from notification: ${message.messageId}', 'FCM_TEST_SCREEN');
    });
  }

  /// Subscribe to test topic
  Future<void> _subscribeToTestTopic() async {
    try {
      await FCMService().subscribeToTopic('test_topic');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Subscribed to test_topic')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error subscribing: $e')),
      );
    }
  }

  /// Unsubscribe from test topic
  Future<void> _unsubscribeFromTestTopic() async {
    try {
      await FCMService().unsubscribeFromTopic('test_topic');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unsubscribed from test_topic')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error unsubscribing: $e')),
      );
    }
  }

  /// Copy FCM token to clipboard
  void _copyTokenToClipboard() {
    if (_fcmToken != null) {
      Clipboard.setData(ClipboardData(text: _fcmToken!));
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('FCM Token copied to clipboard')),
      );
    }
  }

  /// Clear received messages
  void _clearMessages() {
    setState(() {
      _receivedMessages.clear();
      _notificationStatus = 'Messages cleared';
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('FCM Test'),
        backgroundColor: theme.colorScheme.primary,
        foregroundColor: theme.colorScheme.onPrimary,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadFCMToken,
            tooltip: 'Refresh Token',
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // FCM Token Section
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'FCM Token',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceVariant,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: theme.colorScheme.outline),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _fcmToken ?? 'Loading...',
                            style: theme.textTheme.bodySmall?.copyWith(
                              fontFamily: 'monospace',
                            ),
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (_fcmToken != null) ...[
                            const SizedBox(height: 8),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                TextButton.icon(
                                  onPressed: _copyTokenToClipboard,
                                  icon: const Icon(Icons.copy),
                                  label: const Text('Copy'),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Topic Management Section
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Topic Management',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _subscribeToTestTopic,
                            icon: const Icon(Icons.add),
                            label: const Text('Subscribe to test_topic'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _unsubscribeFromTestTopic,
                            icon: const Icon(Icons.remove),
                            label: const Text('Unsubscribe'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Notification Status Section
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Notification Status',
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        TextButton.icon(
                          onPressed: _clearMessages,
                          icon: const Icon(Icons.clear),
                          label: const Text('Clear'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceVariant,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: theme.colorScheme.outline),
                      ),
                      child: Text(
                        _notificationStatus,
                        style: theme.textTheme.bodyMedium,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Received Messages Section
            if (_receivedMessages.isNotEmpty) ...[
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Received Messages (${_receivedMessages.length})',
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        height: 200,
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surfaceVariant,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: theme.colorScheme.outline),
                        ),
                        child: ListView.builder(
                          padding: const EdgeInsets.all(8),
                          itemCount: _receivedMessages.length,
                          itemBuilder: (context, index) {
                            final message = _receivedMessages[index];
                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 4),
                              child: Text(
                                message,
                                style: theme.textTheme.bodySmall,
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
            
            const SizedBox(height: 16),
            
            // Instructions Section
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'How to Test FCM',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      '1. Copy the FCM token above\n'
                      '2. Use Firebase Console or Postman to send a test message\n'
                      '3. Send to the token or subscribe to "test_topic"\n'
                      '4. Watch for notifications in foreground and background\n'
                      '5. Check the received messages below',
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
