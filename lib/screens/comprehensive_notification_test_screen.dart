import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'dart:convert';
import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/universal_notification_service.dart';
import '../services/production_notification_service.dart';
import '../services/notification_fix_service.dart';
import '../services/chat_management_service.dart';
import '../services/logger_service.dart';

/// Comprehensive notification testing screen for Android, iOS, and Web
/// Tests all notification scenarios: sending, receiving, broadcasting, and FCM
class ComprehensiveNotificationTestScreen extends StatefulWidget {
  const ComprehensiveNotificationTestScreen({Key? key}) : super(key: key);

  @override
  State<ComprehensiveNotificationTestScreen> createState() => _ComprehensiveNotificationTestScreenState();
}

class _ComprehensiveNotificationTestScreenState extends State<ComprehensiveNotificationTestScreen> {
  final UniversalNotificationService _universalService = UniversalNotificationService();
  final ProductionNotificationService _productionService = ProductionNotificationService();
  final NotificationFixService _fixService = NotificationFixService();
  
  Map<String, dynamic> _universalStatus = {};
  Map<String, dynamic> _productionStatus = {};
  Map<String, dynamic> _fixStatus = {};
  
  bool _isLoading = false;
  bool _isInitializing = false;
  bool _isTestingFCM = false;
  bool _isTestingChat = false;
  bool _isTestingBroadcast = false;
  
  String _testResults = '';
  String? _fcmToken;
  String? _currentUserId;

  @override
  void initState() {
    super.initState();
    _loadAllStatuses();
    _getCurrentUser();
  }

  Future<void> _getCurrentUser() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      setState(() {
        _currentUserId = user.uid;
      });
    }
  }

  Future<void> _loadAllStatuses() async {
    setState(() => _isLoading = true);
    
    try {
      final results = await Future.wait([
        _universalService.getNotificationStatus(),
        _productionService.getNotificationStatus(),
        _fixService.getNotificationStatus(),
      ]);
      
      setState(() {
        _universalStatus = results[0];
        _productionStatus = results[1];
        _fixStatus = results[2];
        _isLoading = false;
      });
      
      // Get FCM token
      final token = await _universalService.getFcmToken();
      setState(() {
        _fcmToken = token;
      });
      
    } catch (e) {
      Log.e('Error loading notification statuses', 'COMPREHENSIVE_NOTIFICATION_TEST', e);
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Comprehensive Notification Test'),
        backgroundColor: Colors.purple,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadAllStatuses,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Platform info
            _buildPlatformInfo(),
            const SizedBox(height: 20),
            
            // Service status overview
            _buildServiceStatusOverview(),
            const SizedBox(height: 20),
            
            // FCM Token display
            _buildFCMTokenDisplay(),
            const SizedBox(height: 20),
            
            // Test buttons
            _buildTestButtons(),
            const SizedBox(height: 20),
            
            // Clear results button
            if (_testResults.isNotEmpty) ...[
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _clearResults,
                  icon: const Icon(Icons.clear),
                  label: const Text('Clear Results'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.grey,
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
            
            // Test results
            if (_testResults.isNotEmpty) ...[
              const Text(
                'Test Results:',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey),
                ),
                child: Text(
                  _testResults,
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildPlatformInfo() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: kIsWeb ? Colors.blue.withValues(alpha: 0.1) : 
               Platform.isAndroid ? Colors.green.withValues(alpha: 0.1) : 
               Colors.orange.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: kIsWeb ? Colors.blue : 
                 Platform.isAndroid ? Colors.green : 
                 Colors.orange,
        ),
      ),
      child: Row(
        children: [
          Icon(
            kIsWeb ? Icons.web : 
            Platform.isAndroid ? Icons.android : 
            Icons.phone_iphone,
            color: kIsWeb ? Colors.blue : 
                   Platform.isAndroid ? Colors.green : 
                   Colors.orange,
          ),
          const SizedBox(width: 8),
          Text(
            'Platform: ${kIsWeb ? 'Web' : Platform.isAndroid ? 'Android' : 'iOS'}',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: kIsWeb ? Colors.blue : 
                     Platform.isAndroid ? Colors.green : 
                     Colors.orange,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildServiceStatusOverview() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Notification Service Status:',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          _buildStatusRow('Universal Service', _universalStatus['isInitialized'] ?? false),
          _buildStatusRow('Production Service', _productionStatus['isInitialized'] ?? false),
          _buildStatusRow('Fix Service', _fixStatus['isInitialized'] ?? false),
          _buildStatusRow('FCM Token', _fcmToken != null),
          _buildStatusRow('Notification Permission', _universalStatus['hasNotificationPermission'] ?? false),
          _buildStatusRow('User Authenticated', _currentUserId != null),
        ],
      ),
    );
  }

  Widget _buildStatusRow(String label, bool status) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Icon(
            status ? Icons.check_circle : Icons.cancel,
            size: 16,
            color: status ? Colors.green : Colors.red,
          ),
          const SizedBox(width: 8),
          Text(
            '$label: ${status ? "✅ Ready" : "❌ Not Ready"}',
            style: TextStyle(
              fontSize: 12,
              color: status ? Colors.green : Colors.red,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFCMTokenDisplay() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.blue),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'FCM Token:',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _fcmToken != null 
              ? '${_fcmToken!.substring(0, 50)}...' 
              : 'No FCM token available',
            style: const TextStyle(
              fontFamily: 'monospace',
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTestButtons() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Notification Tests:',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        
        // Initialize services
        _buildTestButton(
          'Initialize All Services',
          Icons.settings,
          Colors.blue,
          _initializeAllServices,
          _isInitializing,
        ),
        const SizedBox(height: 8),
        
        // FCM Tests
        _buildTestButton(
          'Test FCM Server Connection',
          Icons.cloud,
          Colors.cyan,
          _testFCMServerConnection,
          _isTestingFCM,
        ),
        const SizedBox(height: 8),
        
        _buildTestButton(
          'Test FCM Token Generation',
          Icons.vpn_key,
          Colors.cyan,
          _testFCMTokenGeneration,
          _isTestingFCM,
        ),
        const SizedBox(height: 8),
        
        _buildTestButton(
          'Test FCM Message Sending',
          Icons.send,
          Colors.cyan,
          _testFCMMessageSending,
          _isTestingFCM,
        ),
        const SizedBox(height: 8),
        
        // Local notification tests
        _buildTestButton(
          'Test Local Notifications',
          Icons.notifications,
          Colors.orange,
          _testLocalNotifications,
          false,
        ),
        const SizedBox(height: 8),
        
        // Chat notification tests
        _buildTestButton(
          'Test Chat Notifications',
          Icons.chat,
          Colors.green,
          _testChatNotifications,
          _isTestingChat,
        ),
        const SizedBox(height: 8),
        
        // Broadcast notification tests
        _buildTestButton(
          'Test Broadcast Notifications',
          Icons.broadcast_on_personal,
          Colors.purple,
          _testBroadcastNotifications,
          _isTestingBroadcast,
        ),
        const SizedBox(height: 8),
        
        // Permission tests
        _buildTestButton(
          'Test Notification Permissions',
          Icons.security,
          Colors.red,
          _testNotificationPermissions,
          false,
        ),
        const SizedBox(height: 8),
        
        // Comprehensive test
        _buildTestButton(
          'Run All Tests',
          Icons.play_arrow,
          Colors.purple,
          _runAllTests,
          _isLoading,
        ),
      ],
    );
  }

  Widget _buildTestButton(String title, IconData icon, Color color, VoidCallback onPressed, bool isLoading) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: isLoading ? null : onPressed,
        icon: isLoading ? const SizedBox(
          width: 16,
          height: 16,
          child: CircularProgressIndicator(strokeWidth: 2),
        ) : Icon(icon),
        label: Text(title),
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 12),
        ),
      ),
    );
  }

  void _addResult(String result) {
    setState(() {
      _testResults += '${DateTime.now().toString().substring(11, 19)} - $result\n';
    });
  }

  void _clearResults() {
    setState(() {
      _testResults = '';
    });
  }

  Future<void> _initializeAllServices() async {
    setState(() => _isInitializing = true);
    _addResult('Initializing all notification services...');
    
    try {
      await Future.wait([
        _universalService.initialize(),
        _productionService.initialize(),
        _fixService.initialize(),
      ]);
      
      _addResult('✅ All services initialized successfully');
      await _loadAllStatuses();
    } catch (e) {
      _addResult('❌ Error initializing services: $e');
    } finally {
      setState(() => _isInitializing = false);
    }
  }

  Future<void> _testFCMServerConnection() async {
    setState(() => _isTestingFCM = true);
    _addResult('Testing FCM server connection...');
    
    try {
      // Test server health
      final response = await _productionService.testServerConnection();
      if (response) {
        _addResult('✅ FCM server connection successful');
      } else {
        _addResult('❌ FCM server connection failed');
      }
    } catch (e) {
      _addResult('❌ FCM server connection error: $e');
    } finally {
      setState(() => _isTestingFCM = false);
    }
  }

  Future<void> _testFCMTokenGeneration() async {
    setState(() => _isTestingFCM = true);
    _addResult('Testing FCM token generation...');
    
    try {
      final token = await _universalService.getFcmToken();
      if (token != null && token.isNotEmpty) {
        _addResult('✅ FCM token generated: ${token.substring(0, 20)}...');
        setState(() => _fcmToken = token);
      } else {
        _addResult('❌ FCM token generation failed');
      }
    } catch (e) {
      _addResult('❌ FCM token generation error: $e');
    } finally {
      setState(() => _isTestingFCM = false);
    }
  }

  Future<void> _testFCMMessageSending() async {
    setState(() => _isTestingFCM = true);
    _addResult('Testing FCM message sending...');
    
    try {
      if (_fcmToken == null) {
        _addResult('❌ No FCM token available for testing');
        return;
      }
      
      final success = await _productionService.sendNotificationViaServer(
        recipientToken: _fcmToken!,
        title: '🧪 FCM Test',
        body: 'This is a test FCM message from the comprehensive test screen!',
        data: {
          'type': 'fcm_test',
          'timestamp': DateTime.now().toIso8601String(),
          'source': 'comprehensive_test',
        },
      );
      
      if (success) {
        _addResult('✅ FCM message sent successfully');
      } else {
        _addResult('❌ FCM message sending failed');
      }
    } catch (e) {
      _addResult('❌ FCM message sending error: $e');
    } finally {
      setState(() => _isTestingFCM = false);
    }
  }

  Future<void> _testLocalNotifications() async {
    _addResult('Testing local notifications...');
    
    try {
      await _universalService.sendLocalNotification(
        title: '🧪 Local Test',
        body: 'This is a test local notification!',
        payload: jsonEncode({
          'type': 'local_test',
          'timestamp': DateTime.now().toIso8601String(),
        }),
        channelId: UniversalNotificationService.systemChannelId,
      );
      
      _addResult('✅ Local notification sent successfully');
    } catch (e) {
      _addResult('❌ Local notification error: $e');
    }
  }

  Future<void> _testChatNotifications() async {
    setState(() => _isTestingChat = true);
    _addResult('Testing chat notifications...');
    
    try {
      if (_currentUserId == null) {
        _addResult('❌ No authenticated user for chat testing');
        return;
      }
      
      // Create a test chat message
      final messageId = await ChatManagementService.sendMessage(
        chatId: 'test_chat_${DateTime.now().millisecondsSinceEpoch}',
        text: 'Test chat message for notification testing',
        senderId: _currentUserId!,
        senderName: 'Test User',
        type: 'text',
      );
      
      if (messageId != null) {
        _addResult('✅ Chat message sent successfully: $messageId');
      } else {
        _addResult('❌ Chat message sending failed');
      }
    } catch (e) {
      _addResult('❌ Chat notification error: $e');
    } finally {
      setState(() => _isTestingChat = false);
    }
  }

  Future<void> _testBroadcastNotifications() async {
    setState(() => _isTestingBroadcast = true);
    _addResult('Testing broadcast notifications...');
    
    try {
      await _productionService.sendBroadcastViaServer(
        title: '📢 Broadcast Test',
        body: 'This is a test broadcast notification!',
        data: {
          'type': 'broadcast_test',
          'timestamp': DateTime.now().toIso8601String(),
        },
      );
      
      _addResult('✅ Broadcast notification sent successfully');
    } catch (e) {
      _addResult('❌ Broadcast notification error: $e');
    } finally {
      setState(() => _isTestingBroadcast = false);
    }
  }

  Future<void> _testNotificationPermissions() async {
    _addResult('Testing notification permissions...');
    
    try {
      final status = await _universalService.getNotificationStatus();
      final hasPermission = status['hasNotificationPermission'] ?? false;
      
      if (hasPermission) {
        _addResult('✅ Notification permissions granted');
      } else {
        _addResult('❌ Notification permissions not granted');
        _addResult('Requesting notification permissions...');
        
        await _universalService.requestNotificationPermission();
        await _loadAllStatuses();
        
        final newStatus = await _universalService.getNotificationStatus();
        final newHasPermission = newStatus['hasNotificationPermission'] ?? false;
        
        if (newHasPermission) {
          _addResult('✅ Notification permissions granted after request');
        } else {
          _addResult('❌ Notification permissions still not granted');
        }
      }
    } catch (e) {
      _addResult('❌ Notification permission error: $e');
    }
  }

  Future<void> _runAllTests() async {
    _clearResults();
    _addResult('🚀 Starting comprehensive notification tests...');
    _addResult('==========================================');
    
    await _initializeAllServices();
    await _testNotificationPermissions();
    await _testFCMTokenGeneration();
    await _testFCMServerConnection();
    await _testFCMMessageSending();
    await _testLocalNotifications();
    await _testChatNotifications();
    await _testBroadcastNotifications();
    
    _addResult('==========================================');
    _addResult('🎉 All notification tests completed!');
  }
}
