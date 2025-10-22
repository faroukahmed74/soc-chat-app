import 'package:flutter/material.dart';
import '../services/enhanced_notification_service.dart';
import '../utils/responsive_utils.dart';
import '../services/logger_service.dart';

class NotificationTestScreen extends StatefulWidget {
  const NotificationTestScreen({super.key});

  @override
  State<NotificationTestScreen> createState() => _NotificationTestScreenState();
}

class _NotificationTestScreenState extends State<NotificationTestScreen> {
  final EnhancedNotificationService _notificationService = EnhancedNotificationService();
  Map<String, dynamic> _status = {};
  bool _isLoading = false;
  List<Map<String, dynamic>> _notifications = [];

  @override
  void initState() {
    super.initState();
    _loadStatus();
  }

  Future<void> _loadStatus() async {
    setState(() => _isLoading = true);
    try {
      await _notificationService.initialize();
      final status = await _notificationService.getNotificationStatus();
      final notifications = await _notificationService.getUserNotifications();
      
      setState(() {
        _status = status;
        _notifications = notifications;
        _isLoading = false;
      });
    } catch (e) {
      Log.e('Error loading notification status', 'NOTIFICATION_TEST', e);
      setState(() => _isLoading = false);
    }
  }

  Future<void> _testLocalNotification() async {
    try {
      await _notificationService.sendTestNotification();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Local test notification sent!')),
      );
    } catch (e) {
      Log.e('Error sending test notification', 'NOTIFICATION_TEST', e);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  Future<void> _testServerNotification() async {
    try {
      final success = await _notificationService.testServerNotification();
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Server test notification sent!')),
        );
        _loadStatus(); // Refresh notifications
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to send server notification')),
        );
      }
    } catch (e) {
      Log.e('Error sending server notification', 'NOTIFICATION_TEST', e);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  Future<void> _requestPermission() async {
    try {
      final granted = await _notificationService.requestPermission();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(granted ? 'Permission granted!' : 'Permission denied')),
      );
      _loadStatus(); // Refresh status
    } catch (e) {
      Log.e('Error requesting permission', 'NOTIFICATION_TEST', e);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notification Test'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: EdgeInsets.all(ResponsiveUtils.getResponsiveSpacing(context)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildStatusCard(),
                  SizedBox(height: ResponsiveUtils.getResponsiveSpacing(context)),
                  _buildTestButtons(),
                  SizedBox(height: ResponsiveUtils.getResponsiveSpacing(context)),
                  _buildNotificationsList(),
                ],
              ),
            ),
    );
  }

  Widget _buildStatusCard() {
    return Card(
      elevation: 4,
      child: Padding(
        padding: EdgeInsets.all(ResponsiveUtils.getResponsiveSpacing(context)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Notification Status',
              style: TextStyle(
                fontSize: ResponsiveUtils.getResponsiveFontSize(context, baseSize: 18),
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: ResponsiveUtils.getResponsiveSpacing(context) * 0.5),
            _buildStatusRow('Platform', _status['platform'] ?? 'Unknown'),
            _buildStatusRow('Initialized', _status['isInitialized'] == true ? 'Yes' : 'No'),
            _buildStatusRow('Permission', _status['hasNotificationPermission'] == true ? 'Granted' : 'Denied'),
            _buildStatusRow('Socket Connected', _status['socketConnected'] == true ? 'Yes' : 'No'),
            _buildStatusRow('Auth Token', _status['authTokenPresent'] == true ? 'Present' : 'Missing'),
            _buildStatusRow('User ID', _status['currentUserId'] ?? 'None'),
            _buildStatusRow('Channels Created', _status['channelsCreated'] == true ? 'Yes' : 'No'),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusRow(String label, String value) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            '$label:',
            style: TextStyle(
              fontSize: ResponsiveUtils.getResponsiveFontSize(context, baseSize: 14),
              fontWeight: FontWeight.w500,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: ResponsiveUtils.getResponsiveFontSize(context, baseSize: 14),
              color: _getStatusColor(value),
            ),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(String value) {
    switch (value.toLowerCase()) {
      case 'yes':
      case 'granted':
      case 'present':
      case 'connected':
        return Colors.green;
      case 'no':
      case 'denied':
      case 'missing':
      case 'disconnected':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  Widget _buildTestButtons() {
    return Card(
      elevation: 4,
      child: Padding(
        padding: EdgeInsets.all(ResponsiveUtils.getResponsiveSpacing(context)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Test Notifications',
              style: TextStyle(
                fontSize: ResponsiveUtils.getResponsiveFontSize(context, baseSize: 18),
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: ResponsiveUtils.getResponsiveSpacing(context) * 0.5),
            Wrap(
              spacing: ResponsiveUtils.getResponsiveSpacing(context) * 0.5,
              runSpacing: ResponsiveUtils.getResponsiveSpacing(context) * 0.5,
              children: [
                ElevatedButton.icon(
                  onPressed: _testLocalNotification,
                  icon: const Icon(Icons.notifications),
                  label: const Text('Test Local'),
                ),
                ElevatedButton.icon(
                  onPressed: _testServerNotification,
                  icon: const Icon(Icons.cloud_upload),
                  label: const Text('Test Server'),
                ),
                ElevatedButton.icon(
                  onPressed: _requestPermission,
                  icon: const Icon(Icons.security),
                  label: const Text('Request Permission'),
                ),
                ElevatedButton.icon(
                  onPressed: _loadStatus,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Refresh'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNotificationsList() {
    return Card(
      elevation: 4,
      child: Padding(
        padding: EdgeInsets.all(ResponsiveUtils.getResponsiveSpacing(context)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Recent Notifications (${_notifications.length})',
              style: TextStyle(
                fontSize: ResponsiveUtils.getResponsiveFontSize(context, baseSize: 18),
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: ResponsiveUtils.getResponsiveSpacing(context) * 0.5),
            if (_notifications.isEmpty)
              const Text('No notifications found')
            else
              ..._notifications.take(10).map((notification) => _buildNotificationItem(notification)),
          ],
        ),
      ),
    );
  }

  Widget _buildNotificationItem(Map<String, dynamic> notification) {
    final title = notification['title'] ?? 'No Title';
    final body = notification['body'] ?? 'No Body';
    final timestamp = notification['timestamp'];
    final read = notification['read'] == true;
    
    DateTime? dateTime;
    if (timestamp != null) {
      try {
        dateTime = DateTime.parse(timestamp);
      } catch (e) {
        Log.e('Error parsing timestamp', 'NOTIFICATION_TEST', e);
      }
    }

    return Container(
      margin: EdgeInsets.symmetric(vertical: 4),
      padding: EdgeInsets.all(ResponsiveUtils.getResponsiveSpacing(context) * 0.5),
      decoration: BoxDecoration(
        color: read ? Colors.grey[100] : Colors.blue[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: read ? Colors.grey[300]! : Colors.blue[200]!,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: ResponsiveUtils.getResponsiveFontSize(context, baseSize: 14),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              if (!read)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.blue,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                    'NEW',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
            ],
          ),
          if (body.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              body,
              style: TextStyle(
                fontSize: ResponsiveUtils.getResponsiveFontSize(context, baseSize: 12),
                color: Colors.grey[600],
              ),
            ),
          ],
          if (dateTime != null) ...[
            const SizedBox(height: 4),
            Text(
              _formatDateTime(dateTime),
              style: TextStyle(
                fontSize: ResponsiveUtils.getResponsiveFontSize(context, baseSize: 10),
                color: Colors.grey[500],
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _formatDateTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);
    
    if (difference.inDays > 0) {
      return '${difference.inDays} day${difference.inDays == 1 ? '' : 's'} ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} hour${difference.inHours == 1 ? '' : 's'} ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes} minute${difference.inMinutes == 1 ? '' : 's'} ago';
    } else {
      return 'Just now';
    }
  }
}
