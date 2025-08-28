import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'logger_service.dart';

/// Simple permission test service to debug permission issues
class PermissionTestService {
  /// Test all permissions and show results
  static Future<void> testAllPermissions(BuildContext context) async {
    try {
      Log.i('Starting permission test...', 'PERMISSION_TEST');
      
      // Test camera permission
      final cameraStatus = await Permission.camera.status;
      Log.i('Camera permission status: $cameraStatus', 'PERMISSION_TEST');
      
      // Test photos permission
      final photosStatus = await Permission.photos.status;
      Log.i('Photos permission status: $photosStatus', 'PERMISSION_TEST');
      
      // Test microphone permission
      final micStatus = await Permission.microphone.status;
      Log.i('Microphone permission status: $micStatus', 'PERMISSION_TEST');
      
      // Test notification permission
      final notifStatus = await Permission.notification.status;
      Log.i('Notification permission status: $notifStatus', 'PERMISSION_TEST');
      
      // Test storage permission (for older Android versions)
      final storageStatus = await Permission.storage.status;
      Log.i('Storage permission status: $storageStatus', 'PERMISSION_TEST');
      
      // Show results in a dialog
      if (context.mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Permission Test Results'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Camera: ${_formatStatus(cameraStatus)}'),
                Text('Photos: ${_formatStatus(photosStatus)}'),
                Text('Microphone: ${_formatStatus(micStatus)}'),
                Text('Notifications: ${_formatStatus(notifStatus)}'),
                Text('Storage: ${_formatStatus(storageStatus)}'),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Close'),
              ),
              ElevatedButton(
                onPressed: () async {
                  Navigator.pop(context);
                  await _requestAllPermissions(context);
                },
                child: const Text('Request All'),
              ),
            ],
          ),
        );
      }
      
    } catch (e) {
      Log.e('Error testing permissions', 'PERMISSION_TEST', e);
    }
  }
  
  /// Request all permissions
  static Future<void> _requestAllPermissions(BuildContext context) async {
    try {
      Log.i('Requesting all permissions...', 'PERMISSION_TEST');
      
      // Request camera permission
      final cameraResult = await Permission.camera.request();
      Log.i('Camera permission result: $cameraResult', 'PERMISSION_TEST');
      
      // Request photos permission
      final photosResult = await Permission.photos.request();
      Log.i('Photos permission result: $photosResult', 'PERMISSION_TEST');
      
      // Request microphone permission
      final micResult = await Permission.microphone.request();
      Log.i('Microphone permission result: $micResult', 'PERMISSION_TEST');
      
      // Request notification permission
      final notifResult = await Permission.notification.request();
      Log.i('Notification permission result: $notifResult', 'PERMISSION_TEST');
      
      // Request storage permission
      final storageResult = await Permission.storage.request();
      Log.i('Storage permission result: $storageResult', 'PERMISSION_TEST');
      
      // Show results
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Permissions requested. Check results in logs.'),
            backgroundColor: Colors.blue,
          ),
        );
      }
      
    } catch (e) {
      Log.e('Error requesting permissions', 'PERMISSION_TEST', e);
    }
  }
  
  /// Format permission status for display
  static String _formatStatus(PermissionStatus status) {
    switch (status) {
      case PermissionStatus.granted:
        return '✅ Granted';
      case PermissionStatus.denied:
        return '❌ Denied';
      case PermissionStatus.restricted:
        return '🚫 Restricted';
      case PermissionStatus.limited:
        return '⚠️ Limited';
      case PermissionStatus.permanentlyDenied:
        return '🚫 Permanently Denied';
      case PermissionStatus.provisional:
        return '⏳ Provisional';
      default:
        return '❓ Unknown';
    }
  }
  
  /// Check if a specific permission is granted
  static Future<bool> isPermissionGranted(Permission permission) async {
    try {
      final status = await permission.status;
      return status.isGranted;
    } catch (e) {
      Log.e('Error checking permission status', 'PERMISSION_TEST', e);
      return false;
    }
  }
  
  /// Request a specific permission
  static Future<bool> requestPermission(Permission permission) async {
    try {
      final result = await permission.request();
      return result.isGranted;
    } catch (e) {
      Log.e('Error requesting permission', 'PERMISSION_TEST', e);
      return false;
    }
  }
}
