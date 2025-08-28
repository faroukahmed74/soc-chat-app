import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'dart:io';
import 'package:permission_handler/permission_handler.dart';
import '../services/simple_permission_service.dart';
import '../services/production_permission_service.dart';
import '../services/logger_service.dart';

/// Test screen for Android permissions
/// This screen allows testing of all Android permissions and their handling
class AndroidPermissionTestScreen extends StatefulWidget {
  const AndroidPermissionTestScreen({Key? key}) : super(key: key);

  @override
  State<AndroidPermissionTestScreen> createState() => _AndroidPermissionTestScreenState();
}

class _AndroidPermissionTestScreenState extends State<AndroidPermissionTestScreen> {
  String _testResults = '';
  bool _isLoading = false;
  Map<Permission, PermissionStatus> _permissionStatuses = {};

  @override
  void initState() {
    super.initState();
    _loadPermissionStatuses();
  }

  Future<void> _loadPermissionStatuses() async {
    if (kIsWeb) return;
    
    final permissions = [
      Permission.camera,
      Permission.photos,
      Permission.storage,
      Permission.microphone,
      Permission.location,
      Permission.notification,
    ];
    
    for (final permission in permissions) {
      try {
        final status = await permission.status;
        setState(() {
          _permissionStatuses[permission] = status;
        });
      } catch (e) {
        Log.e('Error checking permission status', 'ANDROID_PERMISSION_TEST', e);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Android Permission Test'),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Platform check
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Platform.isAndroid ? Colors.green.withValues(alpha: 0.1) : Colors.orange.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: Platform.isAndroid ? Colors.green : Colors.orange,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Platform.isAndroid ? Icons.android : Icons.phone_iphone,
                    color: Platform.isAndroid ? Colors.green : Colors.orange,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Platform: ${Platform.isAndroid ? 'Android' : 'iOS'}',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Platform.isAndroid ? Colors.green : Colors.orange,
                    ),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 20),
            
            // Android version info
            if (Platform.isAndroid) ...[
              _buildAndroidVersionInfo(),
              const SizedBox(height: 20),
            ],
            
            // Permission status overview
            _buildPermissionStatusOverview(),
            
            const SizedBox(height: 20),
            
            // Test buttons
            if (Platform.isAndroid) ...[
              _buildTestButton(
                'Test Camera Permission (Simple)',
                Icons.camera_alt,
                Colors.green,
                () => _testCameraPermissionSimple(),
              ),
              const SizedBox(height: 12),
              _buildTestButton(
                'Test Camera Permission (Production)',
                Icons.camera_alt,
                Colors.green,
                () => _testCameraPermissionProduction(),
              ),
              const SizedBox(height: 12),
              _buildTestButton(
                'Test Photos Permission (Simple)',
                Icons.photo_library,
                Colors.blue,
                () => _testPhotosPermissionSimple(),
              ),
              const SizedBox(height: 12),
              _buildTestButton(
                'Test Photos Permission (Production)',
                Icons.photo_library,
                Colors.blue,
                () => _testPhotosPermissionProduction(),
              ),
              const SizedBox(height: 12),
              _buildTestButton(
                'Test Microphone Permission',
                Icons.mic,
                Colors.purple,
                () => _testMicrophonePermission(),
              ),
              const SizedBox(height: 12),
              _buildTestButton(
                'Test Location Permission',
                Icons.location_on,
                Colors.orange,
                () => _testLocationPermission(),
              ),
              const SizedBox(height: 12),
              _buildTestButton(
                'Test Notification Permission',
                Icons.notifications,
                Colors.red,
                () => _testNotificationPermission(),
              ),
              const SizedBox(height: 12),
              _buildTestButton(
                'Test All Permissions Status',
                Icons.list_alt,
                Colors.grey,
                () => _testAllPermissionsStatus(),
              ),
            ] else ...[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange),
                ),
                child: const Text(
                  'This test is designed for Android devices. On iOS, the iOS-specific permission system is used.',
                  style: TextStyle(color: Colors.orange),
                ),
              ),
            ],
            
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

  Widget _buildAndroidVersionInfo() {
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
          Row(
            children: [
              Icon(Icons.info_outline, color: Colors.blue),
              const SizedBox(width: 8),
              Text(
                'Android Version Info',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.blue,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text('Android 13+ (API 33+): Uses READ_MEDIA_* permissions'),
          Text('Android <13 (API <33): Uses READ_EXTERNAL_STORAGE permission'),
          Text('Current detection: ${_isAndroid13OrHigher() ? "Android 13+" : "Android <13"}'),
        ],
      ),
    );
  }

  Widget _buildPermissionStatusOverview() {
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
          Text(
            'Permission Status Overview:',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 8),
          ..._permissionStatuses.entries.map((entry) {
            final permission = entry.key;
            final status = entry.value;
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                children: [
                  Icon(
                    _getPermissionIcon(permission),
                    size: 16,
                    color: _getStatusColor(status),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '${_getPermissionName(permission)}: ${_getStatusText(status)}',
                      style: TextStyle(
                        fontSize: 12,
                        color: _getStatusColor(status),
                      ),
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ],
      ),
    );
  }

  Widget _buildTestButton(String title, IconData icon, Color color, VoidCallback onPressed) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: _isLoading ? null : onPressed,
        icon: _isLoading ? const SizedBox(
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

  Future<void> _testCameraPermissionSimple() async {
    setState(() => _isLoading = true);
    _addResult('Testing camera permission (Simple)...');
    
    try {
      final result = await SimplePermissionService.requestCameraPermission(context);
      _addResult('Camera permission (Simple) result: ${result ? "GRANTED" : "DENIED"}');
    } catch (e) {
      _addResult('Camera permission (Simple) error: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _testCameraPermissionProduction() async {
    setState(() => _isLoading = true);
    _addResult('Testing camera permission (Production)...');
    
    try {
      final result = await ProductionPermissionService.requestCameraPermission(context);
      _addResult('Camera permission (Production) result: ${result ? "GRANTED" : "DENIED"}');
    } catch (e) {
      _addResult('Camera permission (Production) error: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _testPhotosPermissionSimple() async {
    setState(() => _isLoading = true);
    _addResult('Testing photos permission (Simple)...');
    
    try {
      final result = await SimplePermissionService.requestPhotosPermission(context);
      _addResult('Photos permission (Simple) result: ${result ? "GRANTED" : "DENIED"}');
    } catch (e) {
      _addResult('Photos permission (Simple) error: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _testPhotosPermissionProduction() async {
    setState(() => _isLoading = true);
    _addResult('Testing photos permission (Production)...');
    
    try {
      final result = await ProductionPermissionService.requestPhotosPermission(context);
      _addResult('Photos permission (Production) result: ${result ? "GRANTED" : "DENIED"}');
    } catch (e) {
      _addResult('Photos permission (Production) error: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _testMicrophonePermission() async {
    setState(() => _isLoading = true);
    _addResult('Testing microphone permission...');
    
    try {
      final result = await SimplePermissionService.requestMicrophonePermission(context);
      _addResult('Microphone permission result: ${result ? "GRANTED" : "DENIED"}');
    } catch (e) {
      _addResult('Microphone permission error: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _testLocationPermission() async {
    setState(() => _isLoading = true);
    _addResult('Testing location permission...');
    
    try {
      final result = await SimplePermissionService.requestLocationPermission(context);
      _addResult('Location permission result: ${result ? "GRANTED" : "DENIED"}');
    } catch (e) {
      _addResult('Location permission error: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _testNotificationPermission() async {
    setState(() => _isLoading = true);
    _addResult('Testing notification permission...');
    
    try {
      final result = await Permission.notification.request();
      _addResult('Notification permission result: ${result.isGranted ? "GRANTED" : "DENIED"}');
    } catch (e) {
      _addResult('Notification permission error: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _testAllPermissionsStatus() async {
    setState(() => _isLoading = true);
    _addResult('Testing all permissions status...');
    
    try {
      final permissions = [
        Permission.camera,
        Permission.photos,
        Permission.storage,
        Permission.microphone,
        Permission.location,
        Permission.notification,
      ];
      
      for (final permission in permissions) {
        try {
          final status = await permission.status;
          _addResult('${_getPermissionName(permission)}: ${_getStatusText(status)}');
        } catch (e) {
          _addResult('${_getPermissionName(permission)}: ERROR - $e');
        }
      }
    } catch (e) {
      _addResult('Error testing permissions status: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  bool _isAndroid13OrHigher() {
    try {
      // Simple check: if photos permission is available, we're on Android 13+
      return _permissionStatuses.containsKey(Permission.photos);
    } catch (e) {
      return false;
    }
  }

  IconData _getPermissionIcon(Permission permission) {
    switch (permission) {
      case Permission.camera:
        return Icons.camera_alt;
      case Permission.photos:
        return Icons.photo_library;
      case Permission.storage:
        return Icons.storage;
      case Permission.microphone:
        return Icons.mic;
      case Permission.location:
        return Icons.location_on;
      case Permission.notification:
        return Icons.notifications;
      default:
        return Icons.security;
    }
  }

  String _getPermissionName(Permission permission) {
    switch (permission) {
      case Permission.camera:
        return 'Camera';
      case Permission.photos:
        return 'Photos';
      case Permission.storage:
        return 'Storage';
      case Permission.microphone:
        return 'Microphone';
      case Permission.location:
        return 'Location';
      case Permission.notification:
        return 'Notifications';
      default:
        return 'Unknown';
    }
  }

  String _getStatusText(PermissionStatus status) {
    switch (status) {
      case PermissionStatus.granted:
        return 'GRANTED';
      case PermissionStatus.denied:
        return 'DENIED';
      case PermissionStatus.restricted:
        return 'RESTRICTED';
      case PermissionStatus.limited:
        return 'LIMITED';
      case PermissionStatus.permanentlyDenied:
        return 'PERMANENTLY DENIED';
      default:
        return 'UNKNOWN';
    }
  }

  Color _getStatusColor(PermissionStatus status) {
    switch (status) {
      case PermissionStatus.granted:
        return Colors.green;
      case PermissionStatus.denied:
        return Colors.orange;
      case PermissionStatus.restricted:
        return Colors.red;
      case PermissionStatus.limited:
        return Colors.blue;
      case PermissionStatus.permanentlyDenied:
        return Colors.red;
      default:
        return Colors.grey;
    }
  }
}
