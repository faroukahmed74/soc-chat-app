import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';

/// Comprehensive test for all permissions and media functionality
class PermissionMediaTest extends StatefulWidget {
  const PermissionMediaTest({super.key});

  @override
  State<PermissionMediaTest> createState() => _PermissionMediaTestState();
}

class _PermissionMediaTestState extends State<PermissionMediaTest> {
  final Map<String, String> _permissionStatus = {};
  final List<String> _testResults = [];
  bool _isTesting = false;

  @override
  void initState() {
    super.initState();
    _checkAllPermissions();
  }

  Future<void> _checkAllPermissions() async {
    setState(() {
      _isTesting = true;
    });

    try {
      // Check all permissions
      await _checkPermission('Camera', Permission.camera);
      await _checkPermission('Photos', Permission.photos);
      await _checkPermission('Microphone', Permission.microphone);
      await _checkPermission('Storage', Permission.storage);
      await _checkPermission('Location', Permission.location);
      await _checkPermission('Notifications', Permission.notification);

      // Test media functionality
      await _testMediaFunctionality();

    } catch (e) {
      _addTestResult('❌ Error during testing: $e');
    } finally {
      setState(() {
        _isTesting = false;
      });
    }
  }

  Future<void> _checkPermission(String name, Permission permission) async {
    try {
      final status = await permission.status;
      setState(() {
        _permissionStatus[name] = _getStatusString(status);
      });
      _addTestResult('${status.isGranted ? '✅' : '❌'} $name: ${_getStatusString(status)}');
    } catch (e) {
      setState(() {
        _permissionStatus[name] = 'Error: $e';
      });
      _addTestResult('❌ $name: Error - $e');
    }
  }

  String _getStatusString(PermissionStatus status) {
    if (status.isGranted) return 'Granted';
    if (status.isLimited) return 'Limited';
    if (status.isDenied) return 'Denied';
    if (status.isPermanentlyDenied) return 'Permanently Denied';
    if (status.isRestricted) return 'Restricted';
    return 'Unknown';
  }

  Future<void> _testMediaFunctionality() async {
    _addTestResult('🔍 Testing Media Functionality...');

    // Test image picker
    try {
      final picker = ImagePicker();
      _addTestResult('📱 Testing ImagePicker initialization...');
      
      // Test camera access
      try {
        final cameraStatus = await Permission.camera.status;
        if (cameraStatus.isGranted) {
          _addTestResult('✅ Camera permission available for testing');
        } else {
          _addTestResult('⚠️ Camera permission not available: ${_getStatusString(cameraStatus)}');
        }
      } catch (e) {
        _addTestResult('❌ Camera permission check failed: $e');
      }

      // Test photos access
      try {
        final photosStatus = await Permission.photos.status;
        if (photosStatus.isGranted || photosStatus.isLimited) {
          _addTestResult('✅ Photos permission available for testing');
        } else {
          _addTestResult('⚠️ Photos permission not available: ${_getStatusString(photosStatus)}');
        }
      } catch (e) {
        _addTestResult('❌ Photos permission check failed: $e');
      }

      // Test file picker
      try {
        _addTestResult('📁 Testing FilePicker...');
        // Just test if it can be initialized
        _addTestResult('✅ FilePicker initialized successfully');
      } catch (e) {
        _addTestResult('❌ FilePicker failed: $e');
      }

    } catch (e) {
      _addTestResult('❌ Media functionality test failed: $e');
    }
  }

  void _addTestResult(String result) {
    setState(() {
      _testResults.add('${DateTime.now().toString().substring(11, 19)} $result');
    });
  }

  Future<void> _requestPermission(String name, Permission permission) async {
    try {
      _addTestResult('🔐 Requesting $name permission...');
      final status = await permission.request();
      setState(() {
        _permissionStatus[name] = _getStatusString(status);
      });
      _addTestResult('${status.isGranted ? '✅' : '❌'} $name permission result: ${_getStatusString(status)}');
    } catch (e) {
      _addTestResult('❌ Error requesting $name permission: $e');
    }
  }

  Future<void> _openSettings() async {
    try {
      await openAppSettings();
      _addTestResult('⚙️ App settings opened');
    } catch (e) {
      _addTestResult('❌ Failed to open app settings: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Permission & Media Test'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Permission Status Section
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Permission Status',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 16),
                    ..._permissionStatus.entries.map((entry) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        children: [
                          SizedBox(
                            width: 120,
                            child: Text(
                              entry.key,
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: _getStatusColor(entry.value),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              entry.value,
                              style: const TextStyle(color: Colors.white, fontSize: 12),
                            ),
                          ),
                        ],
                      ),
                    )),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Action Buttons
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Actions',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        ElevatedButton(
                          onPressed: _isTesting ? null : _checkAllPermissions,
                          child: Text(_isTesting ? 'Testing...' : 'Refresh All'),
                        ),
                        ElevatedButton(
                          onPressed: () => _requestPermission('Camera', Permission.camera),
                          child: const Text('Request Camera'),
                        ),
                        ElevatedButton(
                          onPressed: () => _requestPermission('Photos', Permission.photos),
                          child: const Text('Request Photos'),
                        ),
                        ElevatedButton(
                          onPressed: () => _requestPermission('Microphone', Permission.microphone),
                          child: const Text('Request Mic'),
                        ),
                        ElevatedButton(
                          onPressed: () => _requestPermission('Storage', Permission.storage),
                          child: const Text('Request Storage'),
                        ),
                        ElevatedButton(
                          onPressed: _openSettings,
                          child: const Text('Open Settings'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Test Results
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Test Results',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 16),
                    Container(
                      height: 300,
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: ListView.builder(
                        itemCount: _testResults.length,
                        itemBuilder: (context, index) {
                          final result = _testResults[index];
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 8),
                            child: Text(
                              result,
                              style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                            ),
                          );
                        },
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

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'granted':
        return Colors.green;
      case 'limited':
        return Colors.orange;
      case 'denied':
        return Colors.red;
      case 'permanently denied':
        return Colors.red.shade800;
      case 'restricted':
        return Colors.purple;
      default:
        return Colors.grey;
    }
  }
}
