import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/fcm_notification_service.dart';
import '../services/unified_notification_service.dart';
import '../services/logger_service.dart';

/// FCM Sound Test Screen
/// Tests FCM notifications with sound for chat, group, and broadcast messages
class FCMSoundTestScreen extends StatefulWidget {
  const FCMSoundTestScreen({super.key});

  @override
  State<FCMSoundTestScreen> createState() => _FCMSoundTestScreenState();
}

class _FCMSoundTestScreenState extends State<FCMSoundTestScreen> {
  final FCMNotificationService _fcmService = FCMNotificationService();
  final UnifiedNotificationService _unifiedService = UnifiedNotificationService();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  
  bool _isLoading = false;
  String _status = 'Ready to test FCM notifications with sound';
  bool _isFCMHealthy = false;

  @override
  void initState() {
    super.initState();
    _initializeServices();
  }

  Future<void> _initializeServices() async {
    try {
      await _unifiedService.initialize();
      await _fcmService.initialize();
      
      final isHealthy = await _fcmService.checkFCMServerHealth();
      setState(() {
        _isFCMHealthy = isHealthy;
        _status = isHealthy 
          ? 'Services initialized - FCM server healthy' 
          : 'Services initialized - FCM server may be unavailable';
      });
    } catch (e) {
      setState(() {
        _status = 'Error initializing services: $e';
      });
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
        senderId: 'test_sender',
        senderName: 'FCM Test User',
        message: 'This is a test FCM chat message with sound!',
        receiverId: currentUser.uid,
        messageType: 'text',
      );

      setState(() {
        _status = '✅ FCM chat notification with sound test completed!';
        _isLoading = false;
      });

      Log.i('FCM chat notification with sound test completed', 'FCM_SOUND_TEST');
    } catch (e) {
      setState(() {
        _status = '❌ Error testing FCM chat notification: $e';
        _isLoading = false;
      });
      Log.e('Error testing FCM chat notification with sound', 'FCM_SOUND_TEST', e);
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
        senderId: 'test_sender',
        senderName: 'FCM Test User',
        message: 'This is a test FCM group message with sound!',
        groupId: 'test_fcm_group_${DateTime.now().millisecondsSinceEpoch}',
        groupName: 'FCM Test Group',
        messageType: 'text',
      );

      setState(() {
        _status = '✅ FCM group notification with sound test completed!';
        _isLoading = false;
      });

      Log.i('FCM group notification with sound test completed', 'FCM_SOUND_TEST');
    } catch (e) {
      setState(() {
        _status = '❌ Error testing FCM group notification: $e';
        _isLoading = false;
      });
      Log.e('Error testing FCM group notification with sound', 'FCM_SOUND_TEST', e);
    }
  }

  Future<void> _testFCMBroadcastNotification() async {
    setState(() {
      _isLoading = true;
      _status = 'Testing FCM broadcast notification with sound...';
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

      await _fcmService.handleBroadcastMessage(
        senderId: 'test_sender',
        senderName: 'FCM Test User',
        message: 'This is a test FCM broadcast message with sound!',
        messageType: 'text',
      );

      setState(() {
        _status = '✅ FCM broadcast notification with sound test completed!';
        _isLoading = false;
      });

      Log.i('FCM broadcast notification with sound test completed', 'FCM_SOUND_TEST');
    } catch (e) {
      setState(() {
        _status = '❌ Error testing FCM broadcast notification: $e';
        _isLoading = false;
      });
      Log.e('Error testing FCM broadcast notification with sound', 'FCM_SOUND_TEST', e);
    }
  }

  Future<void> _testFCMImageNotification() async {
    setState(() {
      _isLoading = true;
      _status = 'Testing FCM image notification with sound...';
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
        senderId: 'test_sender',
        senderName: 'FCM Test User',
        message: 'Sent you a photo',
        receiverId: currentUser.uid,
        messageType: 'image',
      );

      setState(() {
        _status = '✅ FCM image notification with sound test completed!';
        _isLoading = false;
      });

      Log.i('FCM image notification with sound test completed', 'FCM_SOUND_TEST');
    } catch (e) {
      setState(() {
        _status = '❌ Error testing FCM image notification: $e';
        _isLoading = false;
      });
      Log.e('Error testing FCM image notification with sound', 'FCM_SOUND_TEST', e);
    }
  }

  Future<void> _testFCMVoiceNotification() async {
    setState(() {
      _isLoading = true;
      _status = 'Testing FCM voice notification with sound...';
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
        senderId: 'test_sender',
        senderName: 'FCM Test User',
        message: 'Sent you a voice message',
        receiverId: currentUser.uid,
        messageType: 'audio',
      );

      setState(() {
        _status = '✅ FCM voice notification with sound test completed!';
        _isLoading = false;
      });

      Log.i('FCM voice notification with sound test completed', 'FCM_SOUND_TEST');
    } catch (e) {
      setState(() {
        _status = '❌ Error testing FCM voice notification: $e';
        _isLoading = false;
      });
      Log.e('Error testing FCM voice notification with sound', 'FCM_SOUND_TEST', e);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('🔊 FCM Sound Test'),
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
              color: _isFCMHealthy ? Colors.green.shade50 : Colors.orange.shade50,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          _isFCMHealthy ? Icons.check_circle : Icons.warning,
                          color: _isFCMHealthy ? Colors.green : Colors.orange,
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          'FCM Server Status',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
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
              '🧪 Test FCM Notifications with Sound',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Chat Notifications
            const Text(
              '💬 Chat Notifications',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.blue,
              ),
            ),
            
            const SizedBox(height: 8),
            
            ElevatedButton.icon(
              onPressed: _isLoading ? null : _testFCMChatNotification,
              icon: const Icon(Icons.chat),
              label: const Text('Test FCM Chat with Sound'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
            
            const SizedBox(height: 8),
            
            ElevatedButton.icon(
              onPressed: _isLoading ? null : _testFCMImageNotification,
              icon: const Icon(Icons.image),
              label: const Text('Test FCM Image with Sound'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.purple,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
            
            const SizedBox(height: 8),
            
            ElevatedButton.icon(
              onPressed: _isLoading ? null : _testFCMVoiceNotification,
              icon: const Icon(Icons.mic),
              label: const Text('Test FCM Voice with Sound'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
            
            const SizedBox(height: 20),
            
            // Group Notifications
            const Text(
              '👥 Group Notifications',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.green,
              ),
            ),
            
            const SizedBox(height: 8),
            
            ElevatedButton.icon(
              onPressed: _isLoading ? null : _testFCMGroupNotification,
              icon: const Icon(Icons.group),
              label: const Text('Test FCM Group with Sound'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
            
            const SizedBox(height: 20),
            
            // Broadcast Notifications
            const Text(
              '📢 Broadcast Notifications',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.red,
              ),
            ),
            
            const SizedBox(height: 8),
            
            ElevatedButton.icon(
              onPressed: _isLoading ? null : _testFCMBroadcastNotification,
              icon: const Icon(Icons.broadcast_on_personal),
              label: const Text('Test FCM Broadcast with Sound'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
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
                      '5. Broadcast notifications use system default sound\n'
                      '6. FCM notifications work when app is closed\n'
                      '7. Check notification settings if no sound plays',
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
