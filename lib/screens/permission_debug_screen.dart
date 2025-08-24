import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../services/logger_service.dart';
import '../services/production_permission_service.dart';

class PermissionDebugScreen extends StatefulWidget {
  const PermissionDebugScreen({super.key});

  @override
  State<PermissionDebugScreen> createState() => _PermissionDebugScreenState();
}

class _PermissionDebugScreenState extends State<PermissionDebugScreen> {
  final List<String> _logs = [];
  final ImagePicker _picker = ImagePicker();
  String? _selectedImagePath;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Permission Debug'),
        backgroundColor: Colors.purple,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Permission Status Section
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Permission Status',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton(
                            onPressed: _checkAllPermissions,
                            child: const Text('Check All Permissions'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: _requestPhotosPermission,
                            child: const Text('Request Photos Permission'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Test Gallery Access Section
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Test Gallery Access',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton(
                            onPressed: _testGalleryAccess,
                            child: const Text('Pick from Gallery'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: _testCameraAccess,
                            child: const Text('Take Photo'),
                          ),
                        ),
                      ],
                    ),
                    if (_selectedImagePath != null) ...[
                      const SizedBox(height: 16),
                      Text('Selected: $_selectedImagePath'),
                      if (File(_selectedImagePath!).existsSync())
                        Image.file(
                          File(_selectedImagePath!),
                          height: 100,
                          width: 100,
                          fit: BoxFit.cover,
                        ),
                    ],
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Logs Section
            Expanded(
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Debug Logs',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                          TextButton(
                            onPressed: () {
                              setState(() {
                                _logs.clear();
                              });
                            },
                            child: const Text('Clear'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Expanded(
                        child: ListView.builder(
                          itemCount: _logs.length,
                          itemBuilder: (context, index) {
                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 2),
                              child: Text(
                                _logs[index],
                                style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _addLog(String message) {
    setState(() {
      _logs.add('${DateTime.now().toString().substring(11, 19)}: $message');
    });
    Log.i(message, 'PERMISSION_DEBUG');
  }

  Future<void> _checkAllPermissions() async {
    _addLog('=== Checking All Permissions ===');
    
    try {
      // Use the production permission service debug method
      final debugResults = await ProductionPermissionService.debugAllPermissions();
      
      _addLog('Platform: ${debugResults['platform']}');
      if (debugResults.containsKey('androidVersion')) {
        _addLog('Android Version: ${debugResults['androidVersion']}');
      }
      _addLog('Photos Permission: ${debugResults['photos']}');
      _addLog('Storage Permission: ${debugResults['storage']}');
      _addLog('Camera Permission: ${debugResults['camera']}');
      _addLog('Timestamp: ${debugResults['timestamp']}');
      
      // Also check individual permissions for comparison
      try {
        final photosStatus = await Permission.photos.status;
        _addLog('Direct Photos Check: $photosStatus');
      } catch (e) {
        _addLog('Direct Photos Check: FAILED - $e');
      }
      
      try {
        final storageStatus = await Permission.storage.status;
        _addLog('Direct Storage Check: $storageStatus');
      } catch (e) {
        _addLog('Direct Storage Check: FAILED - $e');
      }
      
    } catch (e) {
      _addLog('Error checking permissions: $e');
    }
  }

  Future<void> _requestPhotosPermission() async {
    _addLog('=== Requesting Photos Permission ===');
    
    try {
      _addLog('Using ProductionPermissionService...');
      final result = await ProductionPermissionService.requestPhotosPermission(context);
      
      if (result) {
        _addLog('Photos permission granted successfully via ProductionPermissionService!');
      } else {
        _addLog('Photos permission denied via ProductionPermissionService');
      }
      
      // Also try direct permission request for comparison
      _addLog('Trying direct permission request for comparison...');
      try {
        final status = await Permission.photos.status;
        _addLog('Current photos status: $status');
        
        if (status.isGranted || status.isLimited) {
          _addLog('Photos permission already granted/limited');
          return;
        }
        
        if (status.isPermanentlyDenied) {
          _addLog('Photos permission permanently denied - showing settings dialog');
          await openAppSettings();
          return;
        }
        
        _addLog('Requesting photos permission directly...');
        final directResult = await Permission.photos.request();
        _addLog('Direct photos permission result: $directResult');
        
        if (directResult.isGranted || directResult.isLimited) {
          _addLog('Direct photos permission granted successfully!');
        } else {
          _addLog('Direct photos permission denied by user');
        }
        
      } catch (e) {
        _addLog('Direct permission request failed: $e');
      }
      
    } catch (e) {
      _addLog('Error requesting photos permission: $e');
    }
  }

  Future<void> _testGalleryAccess() async {
    _addLog('=== Testing Gallery Access ===');
    
    try {
      _addLog('Attempting to pick image from gallery...');
      
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 85,
      );
      
      if (image != null) {
        setState(() {
          _selectedImagePath = image.path;
        });
        _addLog('Gallery access SUCCESS: ${image.path}');
        _addLog('File exists: ${File(image.path).existsSync()}');
        _addLog('File size: ${File(image.path).lengthSync()} bytes');
      } else {
        _addLog('Gallery access: No image selected');
      }
      
    } catch (e) {
      _addLog('Gallery access FAILED: $e');
    }
  }

  Future<void> _testCameraAccess() async {
    _addLog('=== Testing Camera Access ===');
    
    try {
      _addLog('Attempting to take photo with camera...');
      
      final XFile? image = await _picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 85,
      );
      
      if (image != null) {
        setState(() {
          _selectedImagePath = image.path;
        });
        _addLog('Camera access SUCCESS: ${image.path}');
        _addLog('File exists: ${File(image.path).existsSync()}');
        _addLog('File size: ${File(image.path).lengthSync()} bytes');
      } else {
        _addLog('Camera access: No image captured');
      }
      
    } catch (e) {
      _addLog('Camera access FAILED: $e');
    }
  }
}
