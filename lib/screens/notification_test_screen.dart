import 'package:flutter/material.dart';

import 'dart:convert';
import '../services/universal_notification_service.dart';
import '../services/logger_service.dart';

/// Comprehensive notification testing screen
/// Helps debug notification issues on Android, iOS, and Web
class NotificationTestScreen extends StatefulWidget {
  const NotificationTestScreen({Key? key}) : super(key: key);

  @override
  State<NotificationTestScreen> createState() => _NotificationTestScreenState();
}

class _NotificationTestScreenState extends State<NotificationTestScreen> {
  final UniversalNotificationService _notificationService = UniversalNotificationService();
  
  Map<String, dynamic> _notificationStatus = {};
  bool _isLoading = false;
  bool _isInitializing = false;
  bool _isRequestingPermission = false;
  bool _isSendingNotification = false;

  @override
  void initState() {
    super.initState();
    _loadNotificationStatus();
  }

  /// Load current notification status
  Future<void> _loadNotificationStatus() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final status = await _notificationService.getNotificationStatus();
      setState(() {
        _notificationStatus = status;
        _isLoading = false;
      });
    } catch (e) {
      Log.e('Error loading notification status', 'NOTIFICATION_TEST', e);
      setState(() {
        _isLoading = false;
      });
    }
  }

  /// Initialize notification service
  Future<void> _initializeNotificationService() async {
    setState(() {
      _isInitializing = true;
    });

    try {
      await _notificationService.initialize();
      
      // Reload status after initialization
      await _loadNotificationStatus();
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Notification service initialized successfully!'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      Log.e('Error initializing notification service', 'NOTIFICATION_TEST', e);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error initializing: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isInitializing = false;
      });
    }
  }

  /// Request notification permission
  Future<void> _requestNotificationPermission() async {
    setState(() {
      _isRequestingPermission = true;
    });

    try {
      final hasPermission = await _notificationService.requestPermission();
      
      // Reload status after permission request
      await _loadNotificationStatus();
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(hasPermission 
            ? 'Notification permission granted!' 
            : 'Notification permission denied'),
          backgroundColor: hasPermission ? Colors.green : Colors.orange,
        ),
      );
    } catch (e) {
      Log.e('Error requesting notification permission', 'NOTIFICATION_TEST', e);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error requesting permission: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isRequestingPermission = false;
      });
    }
  }

  /// Send test notification
  Future<void> _sendTestNotification() async {
    setState(() {
      _isSendingNotification = true;
    });

    try {
      await _notificationService.sendLocalNotification(
        title: '🧪 Test Notification',
        body: 'This is a test notification from the notification test screen!',
        payload: jsonEncode({
          'type': 'test',
          'timestamp': DateTime.now().toIso8601String(),
          'source': 'notification_test_screen',
        }),
        channelId: UniversalNotificationService.systemChannelId,
      );
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Test notification sent successfully!'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      Log.e('Error sending test notification', 'NOTIFICATION_TEST', e);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error sending notification: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isSendingNotification = false;
      });
    }
  }

  /// Send test chat notification
  Future<void> _sendTestChatNotification() async {
    setState(() {
      _isSendingNotification = true;
    });

    try {
      await _notificationService.sendLocalNotification(
        title: '💬 New Message',
        body: 'You have a new message from John Doe',
        payload: jsonEncode({
          'type': 'chat',
          'chatId': 'test_chat_123',
          'senderId': 'john_doe_456',
          'senderName': 'John Doe',
          'timestamp': DateTime.now().toIso8601String(),
        }),
        channelId: UniversalNotificationService.chatChannelId,
      );
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Test chat notification sent successfully!'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      Log.e('Error sending test chat notification', 'NOTIFICATION_TEST', e);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error sending chat notification: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isSendingNotification = false;
      });
    }
  }

  /// Send test broadcast notification
  Future<void> _sendTestBroadcastNotification() async {
    setState(() {
      _isSendingNotification = true;
    });

    try {
      await _notificationService.sendLocalNotification(
        title: '📢 Admin Broadcast',
        body: 'Important announcement: System maintenance scheduled for tonight',
        payload: jsonEncode({
          'type': 'broadcast',
          'adminId': 'admin_789',
          'priority': 'high',
          'timestamp': DateTime.now().toIso8601String(),
        }),
        channelId: UniversalNotificationService.broadcastChannelId,
      );
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Test broadcast notification sent successfully!'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      Log.e('Error sending test broadcast notification', 'NOTIFICATION_TEST', e);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error sending broadcast notification: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isSendingNotification = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notification Test'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            onPressed: _loadNotificationStatus,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Service Status
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Service Status',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          const SizedBox(height: 16),
                          _buildStatusRow('Initialized', _notificationStatus['isInitialized'] ?? false),
                          _buildStatusRow('Permission Granted', _notificationStatus['hasPermission'] ?? false),
                          _buildStatusRow('Platform', _notificationStatus['platform'] ?? 'Unknown'),
                          if (_notificationStatus['androidVersion'] != null)
                            _buildStatusRow('Android Version', _notificationStatus['androidVersion']),
                          if (_notificationStatus['fcmToken'] != null)
                            _buildStatusRow('FCM Token', _notificationStatus['fcmToken']),
                          _buildStatusRow('Timestamp', _notificationStatus['timestamp'] ?? 'Unknown'),
                        ],
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Control Buttons
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Service Controls',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          const SizedBox(height: 16),
                          
                          // Initialize Service Button
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: _isInitializing ? null : _initializeNotificationService,
                              icon: _isInitializing 
                                  ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(strokeWidth: 2),
                                    )
                                  : const Icon(Icons.power_settings_new),
                              label: Text(_isInitializing ? 'Initializing...' : 'Initialize Service'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.blue,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.all(16),
                              ),
                            ),
                          ),
                          
                          const SizedBox(height: 8),
                          
                          // Request Permission Button
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: _isRequestingPermission ? null : _requestNotificationPermission,
                              icon: _isRequestingPermission 
                                  ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(strokeWidth: 2),
                                    )
                                  : const Icon(Icons.security),
                              label: Text(_isRequestingPermission ? 'Requesting...' : 'Request Permission'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.orange,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.all(16),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Test Notifications
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Test Notifications',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          const SizedBox(height: 16),
                          
                          // Test System Notification
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: _isSendingNotification ? null : _sendTestNotification,
                              icon: _isSendingNotification 
                                  ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(strokeWidth: 2),
                                    )
                                  : const Icon(Icons.notifications),
                              label: const Text('Send Test Notification'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.all(16),
                              ),
                            ),
                          ),
                          
                          const SizedBox(height: 8),
                          
                          // Test Chat Notification
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: _isSendingNotification ? null : _sendTestChatNotification,
                              icon: _isSendingNotification 
                                  ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(strokeWidth: 2),
                                    )
                                  : const Icon(Icons.chat),
                              label: const Text('Send Test Chat Notification'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.purple,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.all(16),
                              ),
                            ),
                          ),
                          
                          const SizedBox(height: 8),
                          
                          // Test Broadcast Notification
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: _isSendingNotification ? null : _sendTestBroadcastNotification,
                              icon: _isSendingNotification 
                                  ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(strokeWidth: 2),
                                    )
                                  : const Icon(Icons.broadcast_on_personal),
                              label: const Text('Send Test Broadcast Notification'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.red,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.all(16),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Debug Information
                  if (_notificationStatus['error'] != null)
                    Card(
                      color: Colors.red.shade50,
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Error Information',
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                color: Colors.red.shade800,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              _notificationStatus['error'],
                              style: TextStyle(color: Colors.red.shade700),
                            ),
                          ],
                        ),
                      ),
                    ),
                  
                  const SizedBox(height: 24),
                  
                  // Instructions
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Testing Instructions',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            '1. Initialize the notification service first\n'
                            '2. Request notification permission if needed\n'
                            '3. Send test notifications to verify functionality\n'
                            '4. Check device notification settings if issues persist\n'
                            '5. For Android 13+, ensure notification permission is granted',
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

  /// Build status row
  Widget _buildStatusRow(String label, dynamic value) {
    final isBool = value is bool;
    final color = isBool ? (value ? Colors.green : Colors.red) : Colors.grey.shade700;
    final icon = isBool ? (value ? Icons.check_circle : Icons.cancel) : Icons.info;
    
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 8),
          Text(
            '$label: ',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          Text(
            value.toString(),
            style: TextStyle(color: color),
          ),
        ],
      ),
    );
  }
}
