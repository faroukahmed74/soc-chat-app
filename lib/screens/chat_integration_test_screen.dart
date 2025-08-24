import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/chat_management_service.dart';
import '../services/production_notification_service.dart';
import '../services/logger_service.dart';

class ChatIntegrationTestScreen extends StatefulWidget {
  const ChatIntegrationTestScreen({super.key});

  @override
  State<ChatIntegrationTestScreen> createState() => _ChatIntegrationTestScreenState();
}

class _ChatIntegrationTestScreenState extends State<ChatIntegrationTestScreen> {
  final _messageController = TextEditingController();
  final _chatIdController = TextEditingController();
  String? _currentUserId;
  String? _currentUserName;
  String? _lastResult;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadCurrentUser();
    _generateTestChatId();
  }

  Future<void> _loadCurrentUser() async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser != null) {
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(currentUser.uid)
            .get();
        
        if (userDoc.exists && mounted) {
          final userData = userDoc.data()!;
          setState(() {
            _currentUserId = currentUser.uid;
            _currentUserName = userData['displayName'] ?? userData['username'] ?? 'User';
          });
        }
      }
    } catch (e) {
      Log.e('Error loading current user', 'CHAT_INTEGRATION_TEST', e);
    }
  }

  void _generateTestChatId() {
    _chatIdController.text = 'test_chat_${DateTime.now().millisecondsSinceEpoch}';
  }

  Future<void> _testChatMessage() async {
    if (_currentUserId == null || _currentUserName == null) {
      setState(() {
        _lastResult = '❌ User not loaded';
      });
      return;
    }

    if (_messageController.text.trim().isEmpty) {
      setState(() {
        _lastResult = '❌ Please enter a message';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _lastResult = null;
    });

    try {
      // Create a test chat document first
      final chatId = _chatIdController.text.trim();
      await FirebaseFirestore.instance.collection('chats').doc(chatId).set({
        'members': [_currentUserId, 'test_user_123'],
        'isGroup': false,
        'otherUserName': 'Test User',
        'otherUserId': 'test_user_123',
        'createdAt': FieldValue.serverTimestamp(),
        'lastMessage': '',
        'lastMessageTime': FieldValue.serverTimestamp(),
        'lastMessageSender': '',
      });

      // Send message using ChatManagementService (this will trigger FCM notification)
      final messageId = await ChatManagementService.sendMessage(
        chatId: chatId,
        text: _messageController.text.trim(),
        senderId: _currentUserId!,
        senderName: _currentUserName!,
        type: 'text',
      );

      if (messageId != null) {
        setState(() {
          _lastResult = '✅ Message sent successfully!\nMessage ID: $messageId\nFCM notification should be sent automatically';
        });
        
        // Clear message input
        _messageController.clear();
        
        Log.i('Test message sent with FCM integration: $messageId', 'CHAT_INTEGRATION_TEST');
      } else {
        setState(() {
          _lastResult = '❌ Failed to send message';
        });
      }
    } catch (e) {
      setState(() {
        _lastResult = '❌ Error: ${e.toString()}';
      });
      Log.e('Error testing chat message', 'CHAT_INTEGRATION_TEST', e);
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _testBroadcastNotification() async {
    setState(() {
      _isLoading = true;
      _lastResult = null;
    });

    try {
      final success = await ProductionNotificationService().sendBroadcastViaServer(
        title: '📢 Test Broadcast from Chat Integration',
        body: 'This is a test broadcast notification to verify the integration!',
        data: {
          'type': 'chat_integration_test',
          'timestamp': DateTime.now().toIso8601String(),
          'source': 'chat_integration_test_screen',
        },
      );

      setState(() {
        _lastResult = success 
          ? '✅ Broadcast notification sent successfully!' 
          : '❌ Failed to send broadcast notification';
      });

      if (success) {
        Log.i('Broadcast test successful from chat integration', 'CHAT_INTEGRATION_TEST');
      }
    } catch (e) {
      setState(() {
        _lastResult = '❌ Error: ${e.toString()}';
      });
      Log.e('Error testing broadcast', 'CHAT_INTEGRATION_TEST', e);
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _subscribeToTestTopics() async {
    if (_currentUserId == null) return;

    setState(() {
      _isLoading = true;
      _lastResult = null;
    });

    try {
      // Subscribe to all user topics
      await ProductionNotificationService().subscribeToAllUserTopics(_currentUserId!);
      
      // Subscribe to test chat topic
      final chatId = _chatIdController.text.trim();
      await ProductionNotificationService().subscribeToChatTopic(chatId);

      setState(() {
        _lastResult = '✅ Subscribed to all test topics!\n- Broadcast: all_users\n- User: user_$_currentUserId\n- Chat: chat_$chatId';
      });

      Log.i('Subscribed to test topics', 'CHAT_INTEGRATION_TEST');
    } catch (e) {
      setState(() {
        _lastResult = '❌ Error subscribing to topics: ${e.toString()}';
      });
      Log.e('Error subscribing to test topics', 'CHAT_INTEGRATION_TEST', e);
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
        title: const Text('Chat-FCM Integration Test'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // User Info
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Current User',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text('User ID: ${_currentUserId ?? 'Loading...'}'),
                    Text('User Name: ${_currentUserName ?? 'Loading...'}'),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Test Chat Message
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Test Chat Message with FCM',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    
                    TextField(
                      controller: _chatIdController,
                      decoration: const InputDecoration(
                        labelText: 'Chat ID',
                        border: OutlineInputBorder(),
                        helperText: 'This will create a test chat if it doesn\'t exist',
                      ),
                    ),
                    
                    const SizedBox(height: 12),
                    
                    TextField(
                      controller: _messageController,
                      decoration: const InputDecoration(
                        labelText: 'Message',
                        border: OutlineInputBorder(),
                        helperText: 'This message will trigger FCM notification',
                      ),
                      maxLines: 3,
                    ),
                    
                    const SizedBox(height: 16),
                    
                    ElevatedButton.icon(
                      onPressed: _isLoading ? null : _testChatMessage,
                      icon: const Icon(Icons.send),
                      label: const Text('Send Test Message'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Topic Management
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Topic Management',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _isLoading ? null : _subscribeToTestTopics,
                            icon: const Icon(Icons.subscriptions),
                            label: const Text('Subscribe to Test Topics'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                              foregroundColor: Colors.white,
                            ),
                          ),
                        ),
                        
                        const SizedBox(width: 12),
                        
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _isLoading ? null : _testBroadcastNotification,
                            icon: const Icon(Icons.broadcast_on_personal),
                            label: const Text('Test Broadcast'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.orange,
                              foregroundColor: Colors.white,
                            ),
                          ),
                        ),
                      ],
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
                        'Test Result',
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
                      '📋 How It Works',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      '1. Subscribe to test topics first\n'
                      '2. Send a test message - this will:\n'
                      '   • Create a test chat in Firestore\n'
                      '   • Send the message\n'
                      '   • Automatically trigger FCM notification\n'
                      '3. Test broadcast notifications\n'
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

  @override
  void dispose() {
    _messageController.dispose();
    _chatIdController.dispose();
    super.dispose();
  }
}
