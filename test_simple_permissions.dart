import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'lib/services/production_permission_service.dart';
import 'lib/services/production_notification_service.dart';

void main() {
  runApp(const PermissionTestApp());
}

class PermissionTestApp extends StatelessWidget {
  const PermissionTestApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Permission Test',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
      ),
      home: const PermissionTestScreen(),
    );
  }
}

class PermissionTestScreen extends StatefulWidget {
  const PermissionTestScreen({super.key});

  @override
  State<PermissionTestScreen> createState() => _PermissionTestScreenState();
}

class _PermissionTestScreenState extends State<PermissionTestScreen> {
  String _status = 'Ready to test permissions';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Permission Test'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              _status,
              style: const TextStyle(fontSize: 16),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            
            ElevatedButton(
              onPressed: () => _testCameraPermission(),
              child: const Text('Test Camera Permission'),
            ),
            const SizedBox(height: 16),
            
            ElevatedButton(
              onPressed: () => _testPhotosPermission(),
              child: const Text('Test Photos Permission'),
            ),
            const SizedBox(height: 16),
            
            ElevatedButton(
              onPressed: () => _testMicrophonePermission(),
              child: const Text('Test Microphone Permission'),
            ),
            const SizedBox(height: 16),
            
            ElevatedButton(
              onPressed: () => _testNotificationPermission(),
              child: const Text('Test Notification Permission'),
            ),
            const SizedBox(height: 16),
            
            ElevatedButton(
              onPressed: () => _testLocationPermission(),
              child: const Text('Test Location Permission'),
            ),
            const SizedBox(height: 32),
            
            ElevatedButton(
              onPressed: () => _testAllPermissions(),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
              ),
              child: const Text('Test All Permissions'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _testCameraPermission() async {
    setState(() {
      _status = 'Testing camera permission...';
    });
    
    try {
              final result = await ProductionPermissionService.requestCameraPermission(context);
      setState(() {
        _status = 'Camera permission: ${result ? "GRANTED" : "DENIED"}';
      });
    } catch (e) {
      setState(() {
        _status = 'Camera permission error: $e';
      });
    }
  }

  Future<void> _testPhotosPermission() async {
    setState(() {
      _status = 'Testing photos permission...';
    });
    
    try {
              final result = await ProductionPermissionService.requestPhotosPermission(context);
      setState(() {
        _status = 'Photos permission: ${result ? "GRANTED" : "DENIED"}';
      });
    } catch (e) {
      setState(() {
        _status = 'Photos permission error: $e';
      });
    }
  }

  Future<void> _testMicrophonePermission() async {
    setState(() {
      _status = 'Testing microphone permission...';
    });
    
    try {
              final result = await ProductionPermissionService.requestMicrophonePermission(context);
      setState(() {
        _status = 'Microphone permission: ${result ? "GRANTED" : "DENIED"}';
      });
    } catch (e) {
      setState(() {
        _status = 'Microphone permission error: $e';
      });
    }
  }

  Future<void> _testNotificationPermission() async {
    setState(() {
      _status = 'Testing notification permission...';
    });
    
    try {
              final result = await ProductionNotificationService().requestNotificationPermission();
      setState(() {
        _status = 'Notification permission: ${result ? "GRANTED" : "DENIED"}';
      });
    } catch (e) {
      setState(() {
        _status = 'Notification permission error: $e';
      });
    }
  }

  Future<void> _testLocationPermission() async {
    setState(() {
      _status = 'Testing location permission...';
    });
    
    try {
              final result = await ProductionPermissionService.requestLocationPermission(context);
      setState(() {
        _status = 'Location permission: ${result ? "GRANTED" : "DENIED"}';
      });
    } catch (e) {
      setState(() {
        _status = 'Location permission error: $e';
      });
    }
  }

  Future<void> _testAllPermissions() async {
    setState(() {
      _status = 'Testing all permissions...';
    });
    
    try {
              final results = await ProductionPermissionService.getPermissionStatus();
      
      final statusText = results.entries
          .map((e) => '${e.key.toString().split('.').last}: ${e.value ? "✓" : "✗"}')
          .join('\n');
      
      setState(() {
        _status = 'All permissions status:\n$statusText';
      });
    } catch (e) {
      setState(() {
        _status = 'All permissions error: $e';
      });
    }
  }
}
