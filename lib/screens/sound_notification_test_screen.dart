import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/unified_notification_service.dart';
import '../services/fcm_notification_service.dart';
import '../services/logger_service.dart';

/// Sound Notification Test Screen
/// Tests notification sounds for chat and group messages
class SoundNotificationTestScreen extends StatefulWidget {
  const SoundNotificationTestScreen({super.key});

  @override
  State<SoundNotificationTestScreen> createState() => _SoundNotificationTestScreenState();
}

class _SoundNotificationTestScreenState extends State<SoundNotificationTestScreen> {
  final UnifiedNotificationService _unifiedService = UnifiedNotificationService();
  final FCMNotificationService _fcmService = FCMNotificationService();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  
  bool _isLoading = false;
  String _status = 'Ready to test sound notifications';

  @override
  void initState() {
    super.initState();
    _initializeServices();
  }

  Future<void> _initializeServices() async {
    try {
      await _unifiedService.initialize();
      setState(() {
        _status = 'Services initialized - Ready to test';
      });
    } catch (e) {
      setState(() {
        _status = 'Error initializing services: $e';
      });
    }
  }

  Future<void> _testChatNotificationSound() async {
    setState(() {
      _isLoading = true;
      _status = 'Testing chat notification sound...';
    });

    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) {
        setState(() {
          _status = 'Error: No authenticated user';
          _isLoading = false;
        });
        return;
      }

      await _unifiedService.sendChatMessageNotification(
        title: '💬 Test Chat Message',
        body: 'This is a test chat message with sound notification!',
        chatId: 'test_chat_${DateTime.now().millisecondsSinceEpoch}',
        senderId: 'test_sender',
        senderName: 'Test User',
        messageType: 'text',
      );

      setState(() {
        _status = '✅ Chat notification sound test completed!';
        _isLoading = false;
      });

      Log.i('Chat notification sound test completed', 'SOUND_TEST');
    } catch (e) {
      setState(() {
        _status = '❌ Error testing chat notification: $e';
        _isLoading = false;
      });
      Log.e('Error testing chat notification sound', 'SOUND_TEST', e);
    }
  }

  Future<void> _testGroupNotificationSound() async {
    setState(() {
      _isLoading = true;
      _status = 'Testing group notification sound...';
    });

    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) {
        setState(() {
          _status = 'Error: No authenticated user';
          _isLoading = false;
        });
        return;
      }

      await _unifiedService.sendGroupMessageNotification(
        title: '👥 Test Group Message',
        body: 'This is a test group message with sound notification!',
        groupId: 'test_group_${DateTime.now().millisecondsSinceEpoch}',
        senderId: 'test_sender',
        senderName: 'Test User',
        messageType: 'text',
      );

      setState(() {
        _status = '✅ Group notification sound test completed!';
        _isLoading = false;
      });

      Log.i('Group notification sound test completed', 'SOUND_TEST');
    } catch (e) {
      setState(() {
        _status = '❌ Error testing group notification: $e';
        _isLoading = false;
      });
      Log.e('Error testing group notification sound', 'SOUND_TEST', e);
    }
  }

  Future<void> _testFCMChatNotification() async {
    setState(() {
      _isLoading = true;
      _status = 'Testing FCM chat notification with sound...';
    });

    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) {
        setState(() {
          _status = 'Error: No authenticated user';
          _isLoading = false;
        });
        return;
      }

      await _fcmService.handleNewMessage(
        chatId: 'test_fcm_chat_${DateTime.now().millisecondsSinceEpoch}',
        senderId: 'test_fcm_sender',
        senderName: 'FCM Test User',
        messageText: 'This is a test FCM chat message with sound!',
        messageType: 'text',
        recipientIds: [currentUser.uid],
      );

      setState(() {
        _status = '✅ FCM chat notification with sound test completed!';
        _isLoading = false;
      });

      Log.i('FCM chat notification sound test completed', 'SOUND_TEST');
    } catch (e) {
      setState(() {
        _status = '❌ Error testing FCM chat notification: $e';
        _isLoading = false;
      });
      Log.e('Error testing FCM chat notification sound', 'SOUND_TEST', e);
    }
  }

  Future<void> _testFCMGroupNotification() async {
    setState(() {
      _isLoading = true;
      _status = 'Testing FCM group notification with sound...';
    });

    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) {
        setState(() {
          _status = 'Error: No authenticated user';
          _isLoading = false;
        });
        return;
      }

      await _fcmService.handleGroupMessage(
        groupId: 'test_fcm_group_${DateTime.now().millisecondsSinceEpoch}',
        groupName: 'FCM Test Group',
        senderId: 'test_fcm_sender',
        senderName: 'FCM Test User',
        messageText: 'This is a test FCM group message with sound!',
        messageType: 'text',
        memberIds: [currentUser.uid],
      );

      setState(() {
        _status = '✅ FCM group notification with sound test completed!';
        _isLoading = false;
      });

      Log.i('FCM group notification sound test completed', 'SOUND_TEST');
    } catch (e) {
      setState(() {
        _status = '❌ Error testing FCM group notification: $e';
        _isLoading = false;
      });
      Log.e('Error testing FCM group notification sound', 'SOUND_TEST', e);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('🔊 Sound Notification Test'),
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
            
            // Test Buttons
            const Text(
              '🧪 Test Sound Notifications',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Local Notification Tests
            const Text(
              '📱 Local Notifications',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.green,
              ),
            ),
            
            const SizedBox(height: 8),
            
            ElevatedButton.icon(
              onPressed: _isLoading ? null : _testChatNotificationSound,
              icon: const Icon(Icons.chat),
              label: const Text('Test Chat Notification Sound'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
            
            const SizedBox(height: 8),
            
            ElevatedButton.icon(
              onPressed: _isLoading ? null : _testGroupNotificationSound,
              icon: const Icon(Icons.group),
              label: const Text('Test Group Notification Sound'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
            
            const SizedBox(height: 20),
            
            // FCM Notification Tests
            const Text(
              '☁️ FCM Notifications',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.orange,
              ),
            ),
            
            const SizedBox(height: 8),
            
            ElevatedButton.icon(
              onPressed: _isLoading ? null : _testFCMChatNotification,
              icon: const Icon(Icons.cloud),
              label: const Text('Test FCM Chat with Sound'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
            
            const SizedBox(height: 8),
            
            ElevatedButton.icon(
              onPressed: _isLoading ? null : _testFCMGroupNotification,
              icon: const Icon(Icons.cloud_queue),
              label: const Text('Test FCM Group with Sound'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.purple,
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
                      '1. Make sure your device volume is turned up\n'
                      '2. Test each notification type to hear different sounds\n'
                      '3. Chat notifications use blue LED and chat sound\n'
                      '4. Group notifications use green LED and group sound\n'
                      '5. Check notification settings if no sound plays',
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
