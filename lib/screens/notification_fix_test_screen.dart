import 'package:flutter/material.dart';
import '../services/unified_notification_service.dart';
import '../services/logger_service.dart';

/// Test screen for the notification fix service
class NotificationFixTestScreen extends StatefulWidget {
  const NotificationFixTestScreen({Key? key}) : super(key: key);

  @override
  State<NotificationFixTestScreen> createState() => _NotificationFixTestScreenState();
}

class _NotificationFixTestScreenState extends State<NotificationFixTestScreen> {
  final UnifiedNotificationService _notificationService = UnifiedNotificationService();
  
  Map<String, dynamic> _status = {};
  bool _isLoading = false;
  bool _isInitializing = false;
  bool _isSendingTest = false;

  @override
  void initState() {
    super.initState();
    _loadStatus();
  }

  /// Load current notification status
  Future<void> _loadStatus() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final status = await _notificationService.getNotificationStatus();
      setState(() {
        _status = status;
        _isLoading = false;
      });
    } catch (e) {
      Log.e('Error loading notification status', 'NOTIFICATION_FIX_TEST', e);
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
      await _loadStatus();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Notification service initialized successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      Log.e('Error initializing notification service', 'NOTIFICATION_FIX_TEST', e);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Error initializing: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isInitializing = false;
        });
      }
    }
  }

  /// Send test notification
  Future<void> _sendTestNotification() async {
    setState(() {
      _isSendingTest = true;
    });

    try {
      await _notificationService.sendTestNotification();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('🔔 Test notification sent! Check your device.'),
            backgroundColor: Colors.blue,
          ),
        );
      }
    } catch (e) {
      Log.e('Error sending test notification', 'NOTIFICATION_FIX_TEST', e);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Error sending test: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSendingTest = false;
        });
      }
    }
  }

  /// Refresh status
  Future<void> _refreshStatus() async {
    await _loadStatus();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('🔧 Notification Fix Test'),
        backgroundColor: Colors.orange,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refreshStatus,
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Status Card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.info, color: Colors.blue),
                        const SizedBox(width: 8),
                        const Text(
                          'Notification System Status',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    if (_isLoading)
                      const Center(child: CircularProgressIndicator())
                    else
                      ..._status.entries.map((entry) => _buildStatusRow(entry)),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Action Buttons
            ElevatedButton.icon(
              onPressed: _isInitializing ? null : _initializeNotificationService,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.all(16),
              ),
              icon: _isInitializing 
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                    )
                  : const Icon(Icons.play_arrow),
              label: Text(
                _isInitializing ? 'Initializing...' : '🚀 Initialize Service',
                style: const TextStyle(fontSize: 16),
              ),
            ),
            
            const SizedBox(height: 12),
            
            ElevatedButton.icon(
              onPressed: _isSendingTest || !_notificationService.isInitialized ? null : _sendTestNotification,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.all(16),
              ),
              icon: _isSendingTest 
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                    )
                  : const Icon(Icons.notifications),
              label: Text(
                _isSendingTest ? 'Sending...' : '🔔 Send Test Notification',
                style: const TextStyle(fontSize: 16),
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Information Card
            const Card(
              child: Padding(
                padding: EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.help, color: Colors.orange),
                        SizedBox(width: 8),
                        Text(
                          'What This Test Does',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 12),
                    Text('1. ✅ Checks user authentication'),
                    Text('2. 🔐 Requests notification permissions'),
                    Text('3. 📱 Generates and saves FCM token'),
                    Text('4. 🔔 Sets up local notifications'),
                    Text('5. 📨 Configures FCM message handlers'),
                    Text('6. 💾 Verifies Firestore integration'),
                    SizedBox(height: 8),
                    Text(
                      'Note: Make sure you are logged in to test FCM token generation.',
                      style: TextStyle(
                        fontStyle: FontStyle.italic,
                        color: Colors.grey,
                      ),
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

  /// Build status row with color coding
  Widget _buildStatusRow(MapEntry<String, dynamic> entry) {
    Color textColor = Colors.black87;
    IconData icon = Icons.info;
    
    // Color code based on value
    if (entry.value == true) {
      textColor = Colors.green;
      icon = Icons.check_circle;
    } else if (entry.value == false) {
      textColor = Colors.red;
      icon = Icons.error;
    } else if (entry.value == null) {
      textColor = Colors.orange;
      icon = Icons.warning;
    }
    
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, color: textColor, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '${entry.key}: ',
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              entry.value?.toString() ?? 'null',
              style: TextStyle(color: textColor),
            ),
          ),
        ],
      ),
    );
  }
}
