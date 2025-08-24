import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import '../services/production_permission_service.dart';
import '../services/production_notification_service.dart';

/// Example of how to use the new permission system in screens
/// This shows the proper way to request permissions when user interacts with features
class PermissionUsageExample extends StatelessWidget {
  const PermissionUsageExample({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Permission Usage Example'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'How to Request Permissions:',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            
            // Camera Permission Example
            Card(
              child: ListTile(
                leading: const Icon(Icons.camera_alt),
                title: const Text('Take Photo'),
                subtitle: const Text('Camera permission requested when tapped'),
                onTap: () async {
                  // Request camera permission when user wants to take a photo
                  final scaffoldMessenger = ScaffoldMessenger.of(context);
                  final hasPermission = await ProductionPermissionService.requestCameraPermission(context);
                  if (hasPermission) {
                    // Proceed with camera functionality
                    _showMessageWithMessenger(scaffoldMessenger, 'Camera permission granted! Opening camera...');
                  } else {
                    _showMessageWithMessenger(scaffoldMessenger, 'Camera permission denied');
                  }
                },
              ),
            ),
            
            const SizedBox(height: 8),
            
            // Photos Permission Example
            Card(
              child: ListTile(
                leading: const Icon(Icons.photo_library),
                title: const Text('Select from Gallery'),
                subtitle: const Text('Photos permission requested when tapped'),
                onTap: () async {
                  // Request photos permission when user wants to select from gallery
                  final scaffoldMessenger = ScaffoldMessenger.of(context);
                  final hasPermission = await ProductionPermissionService.requestPhotosPermission(context);
                  if (hasPermission) {
                    // Proceed with gallery functionality
                    _showMessageWithMessenger(scaffoldMessenger, 'Photos permission granted! Opening gallery...');
                  } else {
                    _showMessageWithMessenger(scaffoldMessenger, 'Photos permission denied');
                  }
                },
              ),
            ),
            
            const SizedBox(height: 8),
            
            // Microphone Permission Example
            Card(
              child: ListTile(
                leading: const Icon(Icons.mic),
                title: const Text('Record Voice Message'),
                subtitle: const Text('Microphone permission requested when tapped'),
                onTap: () async {
                  // Request microphone permission when user wants to record voice
                  final scaffoldMessenger = ScaffoldMessenger.of(context);
                  final hasPermission = await ProductionPermissionService.requestMicrophonePermission(context);
                  if (hasPermission) {
                    // Proceed with voice recording functionality
                    _showMessageWithMessenger(scaffoldMessenger, 'Microphone permission granted! Starting recording...');
                  } else {
                    _showMessageWithMessenger(scaffoldMessenger, 'Microphone permission denied');
                  }
                },
              ),
            ),
            
            const SizedBox(height: 8),
            
            // Notification Permission Example
            Card(
              child: ListTile(
                leading: const Icon(Icons.notifications),
                title: const Text('Enable Notifications'),
                subtitle: const Text('Notification permission requested when tapped'),
                onTap: () async {
                  // Request notification permission when user wants to enable notifications
                  final scaffoldMessenger = ScaffoldMessenger.of(context);
                  final hasPermission = await ProductionNotificationService().requestNotificationPermission();
                  if (hasPermission) {
                    // Proceed with notification setup
                    _showMessageWithMessenger(scaffoldMessenger, 'Notification permission granted! Notifications enabled.');
                  } else {
                    _showMessageWithMessenger(scaffoldMessenger, 'Notification permission denied');
                  }
                },
              ),
            ),
            
            const SizedBox(height: 8),
            
            // Location Permission Example
            Card(
              child: ListTile(
                leading: const Icon(Icons.location_on),
                title: const Text('Share Location'),
                subtitle: const Text('Location permission requested when tapped'),
                onTap: () async {
                  // Request location permission when user wants to share location
                  final scaffoldMessenger = ScaffoldMessenger.of(context);
                  final hasPermission = await ProductionPermissionService.requestLocationPermission(context);
                  if (hasPermission) {
                    // Proceed with location sharing functionality
                    _showMessageWithMessenger(scaffoldMessenger, 'Location permission granted! Getting location...');
                  } else {
                    _showMessageWithMessenger(scaffoldMessenger, 'Location permission denied');
                  }
                },
              ),
            ),
            
            const SizedBox(height: 24),
            
            const Text(
              'Key Points:',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text('• Never request permissions at app startup'),
            const Text('• Request permissions when user interacts with features'),
            const Text('• Use ProductionPermissionService for consistent behavior'),
            const Text('• iOS gets special handling with explanation dialogs'),
            const Text('• Android gets standard permission requests'),
            
            const SizedBox(height: 24),
            
            ElevatedButton.icon(
                              onPressed: () async {
                  final navigator = Navigator.of(context);
                  final status = await ProductionPermissionService.getPermissionStatus();
                  if (status.isNotEmpty && navigator.mounted) {
                    showDialog(
                      context: navigator.context,
                      builder: (context) => AlertDialog(
                        title: const Text('Permission Status'),
                        content: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Platform: ${defaultTargetPlatform.name}'),
                            if (status['camera'] != null) Text('Camera: ${status['camera']}'),
                            if (status['photos'] != null) Text('Photos: ${status['photos']}'),
                            if (status['microphone'] != null) Text('Microphone: ${status['microphone']}'),
                            if (status['notification'] != null) Text('Notifications: ${status['notification']}'),
                            if (status['location'] != null) Text('Location: ${status['location']}'),
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
                },
              icon: const Icon(Icons.info),
              label: const Text('View Current Permission Status'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  void _showMessage(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 2),
      ),
    );
  }
  
  void _showMessageWithMessenger(ScaffoldMessengerState scaffoldMessenger, String message) {
    scaffoldMessenger.showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 2),
      ),
    );
  }
}
