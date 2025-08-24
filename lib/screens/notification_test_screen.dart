import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/production_notification_service.dart';
import '../services/logger_service.dart'; // Added import for logging
import 'package:flutter/foundation.dart';

class NotificationTestScreen extends StatefulWidget {
  const NotificationTestScreen({super.key});

  @override
  State<NotificationTestScreen> createState() => _NotificationTestScreenState();
}

class _NotificationTestScreenState extends State<NotificationTestScreen> {
  final ProductionNotificationService _notificationService = ProductionNotificationService();
  bool _isLoading = false;
  String _statusMessage = '';
  String _fcmToken = '';
  String _permissionStatus = 'Unknown';
  List<Map<String, dynamic>> _users = [];

  @override
  void initState() {
    super.initState();
    _loadNotificationInfo();
    _loadUsers();
  }

  Future<void> _loadNotificationInfo() async {
    setState(() => _isLoading = true);
    
    try {
      // Get FCM token
      final token = await _notificationService.getFcmToken();
      setState(() => _fcmToken = token ?? 'No token available');

      // Get permission status
      final status = await _notificationService.getNotificationPermissionStatus();
      setState(() => _permissionStatus = status.toString().split('.').last);
      
    } catch (e) {
      setState(() => _statusMessage = 'Error loading info: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadUsers() async {
    try {
      final snapshot = await FirebaseFirestore.instance.collection('users').get();
      final users = snapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          'name': data['displayName'] ?? data['email'] ?? 'Unknown User',
          'email': data['email'] ?? 'No email',
          'platform': data['platform'] ?? 'Unknown',
          'hasFcmToken': data['fcmToken'] != null,
        };
      }).toList();
      
      setState(() => _users = users);
    } catch (e) {
      Log.e('Error loading users', 'NOTIFICATION_TEST', e);
    }
  }

  Future<void> _testLocalNotification() async {
    setState(() => _isLoading = true);
    
    try {
      await _notificationService.sendTestNotification();
      setState(() => _statusMessage = '✅ Local test notification sent successfully!');
    } catch (e) {
      setState(() => _statusMessage = '❌ Error sending local notification: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _testNotificationToAllUsers() async {
    setState(() => _isLoading = true);
    
    try {
      // Send test notification to all users via Firestore
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser != null) {
        final testNotification = {
          'type': 'test_notification',
          'title': '🧪 Test Notification',
          'body': 'This is a test notification sent to all users!',
          'senderId': currentUser.uid,
          'senderName': currentUser.displayName ?? currentUser.email ?? 'Admin',
          'timestamp': FieldValue.serverTimestamp(),
          'platform': kIsWeb ? 'web' : (defaultTargetPlatform == TargetPlatform.iOS ? 'ios' : 'android'),
        };

        // Add to each user's notifications collection
        int successCount = 0;
        for (final user in _users) {
          try {
            await FirebaseFirestore.instance
                .collection('users')
                .doc(user['id'])
                .collection('notifications')
                .add(testNotification);
            successCount++;
          } catch (e) {
            Log.e('Failed to send notification to user ${user['id']}', 'NOTIFICATION_TEST', e);
          }
        }

        setState(() => _statusMessage = '✅ Test notification sent to $successCount users!');
      }
    } catch (e) {
      setState(() => _statusMessage = '❌ Error sending test notifications: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _requestPermission() async {
    setState(() => _isLoading = true);
    
    try {
      final granted = await _notificationService.requestNotificationPermission();
      if (granted) {
        setState(() => _statusMessage = '✅ Notification permission granted!');
        await _loadNotificationInfo(); // Refresh info
      } else {
        setState(() => _statusMessage = '❌ Notification permission denied');
      }
    } catch (e) {
      setState(() => _statusMessage = '❌ Error requesting permission: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _subscribeToTopic() async {
    setState(() => _isLoading = true);
    
    try {
      await _notificationService.subscribeToTopic('test_topic');
      setState(() => _statusMessage = '✅ Subscribed to test_topic!');
    } catch (e) {
      setState(() => _statusMessage = '❌ Error subscribing to topic: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final platform = kIsWeb ? 'Web' : (defaultTargetPlatform == TargetPlatform.iOS ? 'iOS' : 'Android');
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notification Test'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Platform Info Card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Platform Information',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 16),
                    _buildInfoRow('Platform', platform),
                    _buildInfoRow('Permission Status', _permissionStatus),
                    _buildInfoRow('FCM Token', _fcmToken.isNotEmpty ? '${_fcmToken.substring(0, 30)}...' : 'No token'),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Test Actions Card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Test Actions',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 16),
                    
                    // Local Test Notification
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _isLoading ? null : _testLocalNotification,
                        icon: const Icon(Icons.notifications),
                        label: const Text('Send Local Test Notification'),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.all(16),
                        ),
                      ),
                    ),
                    
                    const SizedBox(height: 8),
                    
                    // Test to All Users
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _isLoading ? null : _testNotificationToAllUsers,
                        icon: const Icon(Icons.send),
                        label: const Text('Send Test to All Users'),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.all(16),
                        ),
                      ),
                    ),
                    
                    const SizedBox(height: 8),
                    
                    // Request Permission
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _isLoading ? null : _requestPermission,
                        icon: const Icon(Icons.security),
                        label: const Text('Request Notification Permission'),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.all(16),
                        ),
                      ),
                    ),
                    
                    const SizedBox(height: 8),
                    
                    // Subscribe to Topic
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _isLoading ? null : _subscribeToTopic,
                        icon: const Icon(Icons.topic),
                        label: const Text('Subscribe to Test Topic'),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.all(16),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Status Message
            if (_statusMessage.isNotEmpty) ...[
              Card(
                color: _statusMessage.contains('✅') ? Colors.green.shade50 : Colors.red.shade50,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Icon(
                        _statusMessage.contains('✅') ? Icons.check_circle : Icons.error,
                        color: _statusMessage.contains('✅') ? Colors.green : Colors.red,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _statusMessage,
                          style: TextStyle(
                            color: _statusMessage.contains('✅') ? Colors.green.shade800 : Colors.red.shade800,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
            
            // Users List Card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Users & FCM Status (${_users.length})',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 16),
                    
                    if (_users.isEmpty)
                      const Center(
                        child: Padding(
                          padding: EdgeInsets.all(16),
                          child: CircularProgressIndicator(),
                        ),
                      )
                    else
                      ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _users.length,
                        itemBuilder: (context, index) {
                          final user = _users[index];
                          return ListTile(
                            leading: CircleAvatar(
                              backgroundColor: user['hasFcmToken'] ? Colors.green : Colors.grey,
                              child: Icon(
                                user['hasFcmToken'] ? Icons.notifications_active : Icons.notifications_off,
                                color: Colors.white,
                              ),
                            ),
                            title: Text(user['name']),
                            subtitle: Text(user['email']),
                            trailing: Chip(
                              label: Text(user['platform']),
                              backgroundColor: _getPlatformColor(user['platform']),
                            ),
                          );
                        },
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

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontFamily: 'monospace'),
            ),
          ),
        ],
      ),
    );
  }

  Color _getPlatformColor(String platform) {
    switch (platform.toLowerCase()) {
      case 'android':
        return Colors.green.shade100;
      case 'ios':
        return Colors.blue.shade100;
      case 'web':
        return Colors.orange.shade100;
      default:
        return Colors.grey.shade100;
    }
  }
}
