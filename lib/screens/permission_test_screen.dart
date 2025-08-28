import 'package:flutter/material.dart';

import '../services/simple_permission_service.dart';
import '../services/logger_service.dart';

/// Comprehensive permission testing screen
/// Helps debug permission issues on both Android and iOS
class PermissionTestScreen extends StatefulWidget {
  const PermissionTestScreen({Key? key}) : super(key: key);

  @override
  State<PermissionTestScreen> createState() => _PermissionTestScreenState();
}

class _PermissionTestScreenState extends State<PermissionTestScreen> {
  Map<String, dynamic> _permissionStatus = {};
  Map<String, bool> _permissionResults = {};
  bool _isLoading = false;
  bool _isTesting = false;

  @override
  void initState() {
    super.initState();
    _loadPermissionStatus();
  }

  /// Load current permission status
  Future<void> _loadPermissionStatus() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final status = await SimplePermissionService.getPermissionStatus();
      setState(() {
        _permissionStatus = status;
        _isLoading = false;
      });
    } catch (e) {
      Log.e('Error loading permission status', 'PERMISSION_TEST', e);
      setState(() {
        _isLoading = false;
      });
    }
  }

  /// Test all permissions
  Future<void> _testAllPermissions() async {
    setState(() {
      _isTesting = true;
    });

    try {
      final results = await SimplePermissionService.requestAllPermissions(context);
      setState(() {
        _permissionResults = results;
        _isTesting = false;
      });
      
      // Reload status after testing
      await _loadPermissionStatus();
      
      // Show results summary
      _showResultsSummary(results);
    } catch (e) {
      Log.e('Error testing permissions', 'PERMISSION_TEST', e);
      setState(() {
        _isTesting = false;
      });
    }
  }

  /// Test individual permission
  Future<void> _testPermission(String permissionName, Future<bool> Function(BuildContext) requestFunction) async {
    setState(() {
      _isTesting = true;
    });

    try {
      final result = await requestFunction(context);
      setState(() {
        _permissionResults[permissionName] = result;
        _isTesting = false;
      });
      
      // Reload status after testing
      await _loadPermissionStatus();
      
      // Show individual result
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$permissionName permission: ${result ? 'GRANTED' : 'DENIED'}'),
          backgroundColor: result ? Colors.green : Colors.red,
        ),
      );
    } catch (e) {
      Log.e('Error testing $permissionName permission', 'PERMISSION_TEST', e);
      setState(() {
        _isTesting = false;
      });
    }
  }

  /// Show results summary
  void _showResultsSummary(Map<String, bool> results) {
    final grantedCount = results.values.where((granted) => granted).length;
    final totalCount = results.length;
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Permission Test Results'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Granted: $grantedCount/$totalCount'),
            const SizedBox(height: 16),
            ...results.entries.map((entry) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Icon(
                    entry.value ? Icons.check_circle : Icons.cancel,
                    color: entry.value ? Colors.green : Colors.red,
                  ),
                  const SizedBox(width: 8),
                  Text('${entry.key}: ${entry.value ? 'GRANTED' : 'DENIED'}'),
                ],
              ),
            )),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  /// Get status color
  Color _getStatusColor(String status) {
    switch (status) {
      case 'granted':
        return Colors.green;
      case 'limited':
        return Colors.orange;
      case 'denied':
        return Colors.red;
      case 'permanently_denied':
        return Colors.red.shade800;
      case 'restricted':
        return Colors.orange.shade800;
      default:
        return Colors.grey;
    }
  }

  /// Get status icon
  IconData _getStatusIcon(String status) {
    switch (status) {
      case 'granted':
        return Icons.check_circle;
      case 'limited':
        return Icons.warning;
      case 'denied':
        return Icons.cancel;
      case 'permanently_denied':
        return Icons.block;
      case 'restricted':
        return Icons.lock;
      default:
        return Icons.help;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Permission Test'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            onPressed: _loadPermissionStatus,
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
                  // Platform Info
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
                          const SizedBox(height: 8),
                          Text('Platform: ${_permissionStatus['platform'] ?? 'Unknown'}'),
                          if (_permissionStatus['androidVersion'] != null)
                            Text('Android Version: ${_permissionStatus['androidVersion']}'),
                          Text('Timestamp: ${_permissionStatus['timestamp'] ?? 'Unknown'}'),
                        ],
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Test All Permissions Button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _isTesting ? null : _testAllPermissions,
                      icon: _isTesting 
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.security),
                      label: Text(_isTesting ? 'Testing...' : 'Test All Permissions'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.all(16),
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 24),
                  
                  // Individual Permission Tests
                  Text(
                    'Individual Permission Tests',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 16),
                  
                  // Camera Permission
                  _buildPermissionTestCard(
                    'Camera',
                    'Take photos and videos',
                    Icons.camera_alt,
                    _permissionStatus['camera'] ?? 'unknown',
                    () => _testPermission('camera', SimplePermissionService.requestCameraPermission),
                  ),
                  
                  // Photos Permission
                  _buildPermissionTestCard(
                    'Photos',
                    'Access photo library',
                    Icons.photo_library,
                    _permissionStatus['photos'] ?? 'unknown',
                    () => _testPermission('photos', SimplePermissionService.requestPhotosPermission),
                  ),
                  
                  // Microphone Permission
                  _buildPermissionTestCard(
                    'Microphone',
                    'Record voice messages',
                    Icons.mic,
                    _permissionStatus['microphone'] ?? 'unknown',
                    () => _testPermission('microphone', SimplePermissionService.requestMicrophonePermission),
                  ),
                  
                  // Storage Permission
                  _buildPermissionTestCard(
                    'Storage',
                    'Access device storage',
                    Icons.storage,
                    _permissionStatus['storage'] ?? 'unknown',
                    () => _testPermission('storage', SimplePermissionService.requestPhotosPermission),
                  ),
                  
                  // Notification Permission
                  _buildPermissionTestCard(
                    'Notifications',
                    'Receive app notifications',
                    Icons.notifications,
                    _permissionStatus['notification'] ?? 'unknown',
                    () => _testPermission('notification', SimplePermissionService.requestNotificationPermission),
                  ),
                  
                  // Location Permission
                  _buildPermissionTestCard(
                    'Location',
                    'Share location in chats',
                    Icons.location_on,
                    _permissionStatus['location'] ?? 'unknown',
                    () => _testPermission('location', SimplePermissionService.requestLocationPermission),
                  ),
                  
                  const SizedBox(height: 24),
                  
                  // Permission Status Summary
                  Text(
                    'Current Permission Status',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 16),
                  
                  // Status Grid
                  GridView.count(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisCount: 2,
                    crossAxisSpacing: 8,
                    mainAxisSpacing: 8,
                    childAspectRatio: 2.5,
                    children: [
                      _buildStatusCard('Camera', _permissionStatus['camera'] ?? 'unknown'),
                      _buildStatusCard('Photos', _permissionStatus['photos'] ?? 'unknown'),
                      _buildStatusCard('Microphone', _permissionStatus['microphone'] ?? 'unknown'),
                      _buildStatusCard('Storage', _permissionStatus['storage'] ?? 'unknown'),
                      _buildStatusCard('Notifications', _permissionStatus['notification'] ?? 'unknown'),
                      _buildStatusCard('Location', _permissionStatus['location'] ?? 'unknown'),
                    ],
                  ),
                  
                  const SizedBox(height: 24),
                  
                  // Debug Information
                  if (_permissionStatus['error'] != null)
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
                              _permissionStatus['error'],
                              style: TextStyle(color: Colors.red.shade700),
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

  /// Build permission test card
  Widget _buildPermissionTestCard(
    String title,
    String description,
    IconData icon,
    String currentStatus,
    VoidCallback onTest,
  ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(icon, size: 32, color: Theme.of(context).colorScheme.primary),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  Text(
                    description,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(
                        _getStatusIcon(currentStatus),
                        size: 16,
                        color: _getStatusColor(currentStatus),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        currentStatus.replaceAll('_', ' ').toUpperCase(),
                        style: TextStyle(
                          fontSize: 12,
                          color: _getStatusColor(currentStatus),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            ElevatedButton(
              onPressed: _isTesting ? null : onTest,
              child: const Text('Test'),
            ),
          ],
        ),
      ),
    );
  }

  /// Build status card
  Widget _buildStatusCard(String permission, String status) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              _getStatusIcon(status),
              color: _getStatusColor(status),
              size: 24,
            ),
            const SizedBox(height: 4),
            Text(
              permission,
              style: Theme.of(context).textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 2),
            Text(
              status.replaceAll('_', ' ').toUpperCase(),
              style: TextStyle(
                fontSize: 10,
                color: _getStatusColor(status),
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
