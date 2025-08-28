import 'package:flutter/material.dart';
import 'dart:io';
import '../services/ios_media_permission_fix.dart';

/// Test screen for iOS media permissions
/// This screen allows testing of camera, photos, and microphone permissions on iOS
class IOSPermissionTestScreen extends StatefulWidget {
  const IOSPermissionTestScreen({Key? key}) : super(key: key);

  @override
  State<IOSPermissionTestScreen> createState() => _IOSPermissionTestScreenState();
}

class _IOSPermissionTestScreenState extends State<IOSPermissionTestScreen> {
  String _testResults = '';
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('iOS Permission Test'),
        backgroundColor: Colors.blue,
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
                color: Platform.isIOS ? Colors.green.withValues(alpha: 0.1) : Colors.orange.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: Platform.isIOS ? Colors.green : Colors.orange,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Platform.isIOS ? Icons.phone_iphone : Icons.android,
                    color: Platform.isIOS ? Colors.green : Colors.orange,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Platform: ${Platform.isIOS ? 'iOS' : 'Android'}',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Platform.isIOS ? Colors.green : Colors.orange,
                    ),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 20),
            
            // Test buttons
            if (Platform.isIOS) ...[
              _buildTestButton(
                'Test Camera Permission',
                Icons.camera_alt,
                Colors.green,
                () => _testCameraPermission(),
              ),
              const SizedBox(height: 12),
              _buildTestButton(
                'Test Photos Permission',
                Icons.photo_library,
                Colors.blue,
                () => _testPhotosPermission(),
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
                'Test Camera Image Pick',
                Icons.camera_enhance,
                Colors.green,
                () => _testCameraImagePick(),
              ),
              const SizedBox(height: 12),
              _buildTestButton(
                'Test Gallery Image Pick',
                Icons.image,
                Colors.blue,
                () => _testGalleryImagePick(),
              ),
              const SizedBox(height: 12),
              _buildTestButton(
                'Test Camera Video Pick',
                Icons.videocam,
                Colors.red,
                () => _testCameraVideoPick(),
              ),
              const SizedBox(height: 12),
              _buildTestButton(
                'Test Gallery Video Pick',
                Icons.video_library,
                Colors.red,
                () => _testGalleryVideoPick(),
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
                  'This test is designed for iOS devices. On Android, the standard permission system is used.',
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

  Future<void> _testCameraPermission() async {
    setState(() => _isLoading = true);
    _addResult('Testing camera permission...');
    
    try {
      final result = await IOSMediaPermissionFix.requestCameraPermission(context);
      _addResult('Camera permission result: ${result ? "GRANTED" : "DENIED"}');
    } catch (e) {
      _addResult('Camera permission error: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _testPhotosPermission() async {
    setState(() => _isLoading = true);
    _addResult('Testing photos permission...');
    
    try {
      final result = await IOSMediaPermissionFix.requestPhotosPermission(context);
      _addResult('Photos permission result: ${result ? "GRANTED" : "DENIED"}');
    } catch (e) {
      _addResult('Photos permission error: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _testMicrophonePermission() async {
    setState(() => _isLoading = true);
    _addResult('Testing microphone permission...');
    
    try {
      final result = await IOSMediaPermissionFix.requestMicrophonePermission(context);
      _addResult('Microphone permission result: ${result ? "GRANTED" : "DENIED"}');
    } catch (e) {
      _addResult('Microphone permission error: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _testCameraImagePick() async {
    setState(() => _isLoading = true);
    _addResult('Testing camera image pick...');
    
    try {
      final result = await IOSMediaPermissionFix.pickImageFromCamera(context);
      if (result != null) {
        _addResult('Camera image picked successfully: ${result.name}');
      } else {
        _addResult('Camera image pick cancelled or failed');
      }
    } catch (e) {
      _addResult('Camera image pick error: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _testGalleryImagePick() async {
    setState(() => _isLoading = true);
    _addResult('Testing gallery image pick...');
    
    try {
      final result = await IOSMediaPermissionFix.pickImageFromGallery(context);
      if (result != null) {
        _addResult('Gallery image picked successfully: ${result.name}');
      } else {
        _addResult('Gallery image pick cancelled or failed');
      }
    } catch (e) {
      _addResult('Gallery image pick error: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _testCameraVideoPick() async {
    setState(() => _isLoading = true);
    _addResult('Testing camera video pick...');
    
    try {
      final result = await IOSMediaPermissionFix.pickVideoFromCamera(context);
      if (result != null) {
        _addResult('Camera video picked successfully: ${result.name}');
      } else {
        _addResult('Camera video pick cancelled or failed');
      }
    } catch (e) {
      _addResult('Camera video pick error: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _testGalleryVideoPick() async {
    setState(() => _isLoading = true);
    _addResult('Testing gallery video pick...');
    
    try {
      final result = await IOSMediaPermissionFix.pickVideoFromGallery(context);
      if (result != null) {
        _addResult('Gallery video picked successfully: ${result.name}');
      } else {
        _addResult('Gallery video pick cancelled or failed');
      }
    } catch (e) {
      _addResult('Gallery video pick error: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }
}
