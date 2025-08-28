import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';

void main() {
  runApp(const GalleryPermissionTest());
}

class GalleryPermissionTest extends StatelessWidget {
  const GalleryPermissionTest({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Gallery Permission Test',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
      ),
      home: const GalleryPermissionTestScreen(),
    );
  }
}

class GalleryPermissionTestScreen extends StatefulWidget {
  const GalleryPermissionTestScreen({super.key});

  @override
  State<GalleryPermissionTestScreen> createState() => _GalleryPermissionTestScreenState();
}

class _GalleryPermissionTestScreenState extends State<GalleryPermissionTestScreen> {
  final List<String> _logs = [];
  PermissionStatus? _photosStatus;
  PermissionStatus? _storageStatus;
  PermissionStatus? _cameraStatus;

  @override
  void initState() {
    super.initState();
    _checkPermissions();
  }

  Future<void> _checkPermissions() async {
    _addLog('🔍 Checking permissions...');
    
    try {
      // Check photos permission
      _photosStatus = await Permission.photos.status;
      _addLog('📸 Photos permission: ${_getStatusString(_photosStatus!)}');
      
      // Check storage permission (for older Android)
      _storageStatus = await Permission.storage.status;
      _addLog('💾 Storage permission: ${_getStatusString(_storageStatus!)}');
      
      // Check camera permission
      _cameraStatus = await Permission.camera.status;
      _addLog('📱 Camera permission: ${_getStatusString(_cameraStatus!)}');
      
      setState(() {});
    } catch (e) {
      _addLog('❌ Error checking permissions: $e');
    }
  }

  Future<void> _requestPhotosPermission() async {
    _addLog('🔐 Requesting photos permission...');
    try {
      final result = await Permission.photos.request();
      _addLog('📸 Photos permission result: ${_getStatusString(result)}');
      setState(() {
        _photosStatus = result;
      });
    } catch (e) {
      _addLog('❌ Error requesting photos permission: $e');
    }
  }

  Future<void> _requestStoragePermission() async {
    _addLog('🔐 Requesting storage permission...');
    try {
      final result = await Permission.storage.request();
      _addLog('💾 Storage permission result: ${_getStatusString(result)}');
      setState(() {
        _storageStatus = result;
      });
    } catch (e) {
      _addLog('❌ Error requesting storage permission: $e');
    }
  }

  Future<void> _testImagePicker() async {
    _addLog('🖼️ Testing ImagePicker from gallery...');
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 800,
        maxHeight: 600,
        imageQuality: 85,
      );
      
      if (image != null) {
        _addLog('✅ Image picked successfully: ${image.name}');
        _addLog('📍 Path: ${image.path}');
      } else {
        _addLog('❌ No image selected or permission denied');
      }
    } catch (e) {
      _addLog('❌ Error picking image: $e');
    }
  }

  Future<void> _testCamera() async {
    _addLog('📷 Testing camera...');
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 800,
        maxHeight: 600,
        imageQuality: 85,
      );
      
      if (image != null) {
        _addLog('✅ Photo taken successfully: ${image.name}');
        _addLog('📍 Path: ${image.path}');
      } else {
        _addLog('❌ No photo taken or permission denied');
      }
    } catch (e) {
      _addLog('❌ Error taking photo: $e');
    }
  }

  void _addLog(String message) {
    setState(() {
      _logs.add('${DateTime.now().toString().substring(11, 19)}: $message');
    });
    print(message);
  }

  String _getStatusString(PermissionStatus status) {
    if (status.isGranted) return '✅ Granted';
    if (status.isLimited) return '⚠️ Limited';
    if (status.isDenied) return '❌ Denied';
    if (status.isPermanentlyDenied) return '🚫 Permanently Denied';
    if (status.isRestricted) return '🔒 Restricted';
    return '❓ Unknown';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Gallery Permission Test'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Permission Status Cards
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Permission Status',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 8),
                    Text('📸 Photos: ${_getStatusString(_photosStatus ?? PermissionStatus.denied)}'),
                    Text('💾 Storage: ${_getStatusString(_storageStatus ?? PermissionStatus.denied)}'),
                    Text('📱 Camera: ${_getStatusString(_cameraStatus ?? PermissionStatus.denied)}'),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Action Buttons
            ElevatedButton(
              onPressed: _requestPhotosPermission,
              child: const Text('Request Photos Permission'),
            ),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: _requestStoragePermission,
              child: const Text('Request Storage Permission'),
            ),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: _testImagePicker,
              child: const Text('Test Gallery Picker'),
            ),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: _testCamera,
              child: const Text('Test Camera'),
            ),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: _checkPermissions,
              child: const Text('Refresh Permissions'),
            ),
            
            const SizedBox(height: 16),
            
            // Logs
            Expanded(
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Test Logs',
                        style: Theme.of(context).textTheme.titleLarge,
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
}
