import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'dart:io';
import '../services/fixed_media_service.dart';
import '../services/working_notification_service.dart';


/// Test screen for media permissions and notifications
/// This screen tests both media sending and notification functionality
class MediaNotificationTestScreen extends StatefulWidget {
  const MediaNotificationTestScreen({Key? key}) : super(key: key);

  @override
  State<MediaNotificationTestScreen> createState() => _MediaNotificationTestScreenState();
}

class _MediaNotificationTestScreenState extends State<MediaNotificationTestScreen> {
  final WorkingNotificationService _notificationService = WorkingNotificationService();
  
  String _testResults = '';

  bool _isTestingMedia = false;
  bool _isTestingNotifications = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Media & Notification Test'),
        backgroundColor: Colors.purple,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Platform info
            _buildPlatformInfo(),
            const SizedBox(height: 20),
            
            // Media permission tests
            _buildMediaTests(),
            const SizedBox(height: 20),
            
            // Notification tests
            _buildNotificationTests(),
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

  Widget _buildMediaTests() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Media Permission Tests:',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        
        _buildTestButton(
          'Test Camera Permission',
          Icons.camera_alt,
          Colors.green,
          _testCameraPermission,
          _isTestingMedia,
        ),
        const SizedBox(height: 8),
        
        _buildTestButton(
          'Test Photos Permission',
          Icons.photo_library,
          Colors.blue,
          _testPhotosPermission,
          _isTestingMedia,
        ),
        const SizedBox(height: 8),
        
        _buildTestButton(
          'Test Camera Image Pick',
          Icons.camera_enhance,
          Colors.green,
          _testCameraImagePick,
          _isTestingMedia,
        ),
        const SizedBox(height: 8),
        
        _buildTestButton(
          'Test Gallery Image Pick',
          Icons.image,
          Colors.blue,
          _testGalleryImagePick,
          _isTestingMedia,
        ),
        const SizedBox(height: 8),
        
        _buildTestButton(
          'Test Camera Video Pick',
          Icons.videocam,
          Colors.red,
          _testCameraVideoPick,
          _isTestingMedia,
        ),
        const SizedBox(height: 8),
        
        _buildTestButton(
          'Test Gallery Video Pick',
          Icons.video_library,
          Colors.red,
          _testGalleryVideoPick,
          _isTestingMedia,
        ),
      ],
    );
  }

  Widget _buildNotificationTests() {
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
        
        _buildTestButton(
          'Test Local Notification',
          Icons.notifications,
          Colors.orange,
          _testLocalNotification,
          _isTestingNotifications,
        ),
        const SizedBox(height: 8),
        
        _buildTestButton(
          'Test Notification Permission',
          Icons.security,
          Colors.red,
          _testNotificationPermission,
          _isTestingNotifications,
        ),
        const SizedBox(height: 8),
        
        _buildTestButton(
          'Get FCM Token',
          Icons.vpn_key,
          Colors.cyan,
          _testFCMToken,
          _isTestingNotifications,
        ),
        const SizedBox(height: 8),
        
        _buildTestButton(
          'Get Notification Status',
          Icons.info,
          Colors.grey,
          _testNotificationStatus,
          _isTestingNotifications,
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

  // Media permission tests
  Future<void> _testCameraPermission() async {
    setState(() => _isTestingMedia = true);
    _addResult('Testing camera permission...');
    
    try {
      // This will show the permission dialog
      final result = await FixedMediaService.pickImageFromCamera(context);
      if (result != null) {
        _addResult('✅ Camera permission granted and image captured: ${result.length} bytes');
      } else {
        _addResult('❌ Camera permission denied or no image captured');
      }
    } catch (e) {
      _addResult('❌ Camera permission error: $e');
    } finally {
      setState(() => _isTestingMedia = false);
    }
  }

  Future<void> _testPhotosPermission() async {
    setState(() => _isTestingMedia = true);
    _addResult('Testing photos permission...');
    
    try {
      // This will show the permission dialog
      final result = await FixedMediaService.pickImageFromGallery(context);
      if (result != null) {
        _addResult('✅ Photos permission granted and image selected: ${result.length} bytes');
      } else {
        _addResult('❌ Photos permission denied or no image selected');
      }
    } catch (e) {
      _addResult('❌ Photos permission error: $e');
    } finally {
      setState(() => _isTestingMedia = false);
    }
  }

  Future<void> _testCameraImagePick() async {
    setState(() => _isTestingMedia = true);
    _addResult('Testing camera image pick...');
    
    try {
      final result = await FixedMediaService.pickImageFromCamera(context);
      if (result != null) {
        _addResult('✅ Camera image pick successful: ${result.length} bytes');
      } else {
        _addResult('❌ Camera image pick failed or cancelled');
      }
    } catch (e) {
      _addResult('❌ Camera image pick error: $e');
    } finally {
      setState(() => _isTestingMedia = false);
    }
  }

  Future<void> _testGalleryImagePick() async {
    setState(() => _isTestingMedia = true);
    _addResult('Testing gallery image pick...');
    
    try {
      final result = await FixedMediaService.pickImageFromGallery(context);
      if (result != null) {
        _addResult('✅ Gallery image pick successful: ${result.length} bytes');
      } else {
        _addResult('❌ Gallery image pick failed or cancelled');
      }
    } catch (e) {
      _addResult('❌ Gallery image pick error: $e');
    } finally {
      setState(() => _isTestingMedia = false);
    }
  }

  Future<void> _testCameraVideoPick() async {
    setState(() => _isTestingMedia = true);
    _addResult('Testing camera video pick...');
    
    try {
      final result = await FixedMediaService.pickVideoFromCamera(context);
      if (result != null) {
        _addResult('✅ Camera video pick successful: ${result.length} bytes');
      } else {
        _addResult('❌ Camera video pick failed or cancelled');
      }
    } catch (e) {
      _addResult('❌ Camera video pick error: $e');
    } finally {
      setState(() => _isTestingMedia = false);
    }
  }

  Future<void> _testGalleryVideoPick() async {
    setState(() => _isTestingMedia = true);
    _addResult('Testing gallery video pick...');
    
    try {
      final result = await FixedMediaService.pickVideoFromGallery(context);
      if (result != null) {
        _addResult('✅ Gallery video pick successful: ${result.length} bytes');
      } else {
        _addResult('❌ Gallery video pick failed or cancelled');
      }
    } catch (e) {
      _addResult('❌ Gallery video pick error: $e');
    } finally {
      setState(() => _isTestingMedia = false);
    }
  }

  // Notification tests
  Future<void> _testLocalNotification() async {
    setState(() => _isTestingNotifications = true);
    _addResult('Testing local notification...');
    
    try {
      await _notificationService.sendTestNotification();
      _addResult('✅ Local notification sent successfully');
    } catch (e) {
      _addResult('❌ Local notification error: $e');
    } finally {
      setState(() => _isTestingNotifications = false);
    }
  }

  Future<void> _testNotificationPermission() async {
    setState(() => _isTestingNotifications = true);
    _addResult('Testing notification permission...');
    
    try {
      final status = await _notificationService.getNotificationStatus();
      final hasPermission = status['hasNotificationPermission'] ?? false;
      
      if (hasPermission) {
        _addResult('✅ Notification permission granted');
      } else {
        _addResult('❌ Notification permission not granted');
        _addResult('Requesting notification permission...');
        
        // Try to initialize the service again to request permission
        await _notificationService.initialize();
        
        final newStatus = await _notificationService.getNotificationStatus();
        final newHasPermission = newStatus['hasNotificationPermission'] ?? false;
        
        if (newHasPermission) {
          _addResult('✅ Notification permission granted after request');
        } else {
          _addResult('❌ Notification permission still not granted');
        }
      }
    } catch (e) {
      _addResult('❌ Notification permission error: $e');
    } finally {
      setState(() => _isTestingNotifications = false);
    }
  }

  Future<void> _testFCMToken() async {
    setState(() => _isTestingNotifications = true);
    _addResult('Testing FCM token...');
    
    try {
      final token = await _notificationService.getFcmToken();
      if (token != null) {
        _addResult('✅ FCM token generated: ${token.substring(0, 20)}...');
      } else {
        _addResult('❌ FCM token not available');
      }
    } catch (e) {
      _addResult('❌ FCM token error: $e');
    } finally {
      setState(() => _isTestingNotifications = false);
    }
  }

  Future<void> _testNotificationStatus() async {
    setState(() => _isTestingNotifications = true);
    _addResult('Testing notification status...');
    
    try {
      final status = await _notificationService.getNotificationStatus();
      _addResult('Notification Status:');
      status.forEach((key, value) {
        _addResult('  $key: $value');
      });
    } catch (e) {
      _addResult('❌ Notification status error: $e');
    } finally {
      setState(() => _isTestingNotifications = false);
    }
  }
}
