import 'package:flutter/material.dart';
import 'dart:async';
import '../services/upload_progress_service.dart';
import '../widgets/upload_progress_manager.dart';

/// Demo screen to showcase the upload progress system
class UploadProgressDemoScreen extends StatefulWidget {
  const UploadProgressDemoScreen({super.key});

  @override
  State<UploadProgressDemoScreen> createState() => _UploadProgressDemoScreenState();
}

class _UploadProgressDemoScreenState extends State<UploadProgressDemoScreen> {
  final List<String> _demoUploads = [];
  final Map<String, Timer> _progressTimers = {};

  @override
  void dispose() {
    for (var timer in _progressTimers.values) {
      timer.cancel();
    }
    _progressTimers.clear();
    UploadProgressService.cleanup();
    super.dispose();
  }

  void _startDemoUpload(String fileName, String mediaType) {
    final uploadId = 'demo_${DateTime.now().millisecondsSinceEpoch}';
    
    // Start progress tracking
    UploadProgressService.startProgressTracking(uploadId);
    
    // Simulate upload progress
    double progress = 0.0;
    final timer = Timer.periodic(const Duration(milliseconds: 100), (timer) {
      progress += 0.02; // 2% every 100ms
      
      if (progress >= 1.0) {
        // Upload completed
        UploadProgressService.markCompleted(uploadId);
        timer.cancel();
        _progressTimers.remove(uploadId);
        
        // Remove from demo list after a delay
        Future.delayed(const Duration(seconds: 3), () {
          if (mounted) {
            setState(() {
              _demoUploads.remove(uploadId);
            });
          }
        });
      } else {
        // Update progress
        UploadProgressService.updateProgress(uploadId, progress);
      }
    });
    
    _progressTimers[uploadId] = timer;
    
    setState(() {
      _demoUploads.add(uploadId);
    });
  }

  void _startDemoUploadWithError(String fileName, String mediaType) {
    final uploadId = 'demo_error_${DateTime.now().millisecondsSinceEpoch}';
    
    // Start progress tracking
    UploadProgressService.startProgressTracking(uploadId);
    
    // Simulate upload progress with error
    double progress = 0.0;
    final timer = Timer.periodic(const Duration(milliseconds: 150), (timer) {
      progress += 0.03; // 3% every 150ms
      
      if (progress >= 0.6) {
        // Simulate error at 60%
        UploadProgressService.markFailed(uploadId, 'Network connection lost');
        timer.cancel();
        _progressTimers.remove(uploadId);
        
        // Remove from demo list after a delay
        Future.delayed(const Duration(seconds: 5), () {
          if (mounted) {
            setState(() {
              _demoUploads.remove(uploadId);
            });
          }
        });
      } else {
        // Update progress
        UploadProgressService.updateProgress(uploadId, progress);
      }
    });
    
    _progressTimers[uploadId] = timer;
    
    setState(() {
      _demoUploads.add(uploadId);
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Upload Progress Demo'),
        backgroundColor: theme.colorScheme.primary,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Stack(
        children: [
          // Main content
          SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Demo description
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.grey.shade800 : Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: theme.colorScheme.primary.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.info_outline,
                            color: theme.colorScheme.primary,
                            size: 24,
                          ),
                          const SizedBox(width: 12),
                          Text(
                            'Upload Progress Demo',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: theme.colorScheme.primary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'This demo showcases the upload progress tracking system. '
                        'Start demo uploads to see real-time progress indicators, '
                        'completion states, and error handling.',
                        style: TextStyle(
                          fontSize: 16,
                          color: isDark ? Colors.white70 : Colors.black87,
                          height: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 24),
                
                // Demo controls
                Text(
                  'Demo Controls',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
                const SizedBox(height: 16),
                
                // Quick upload buttons
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    _buildDemoButton(
                      '📷 Image Upload',
                      'image',
                      () => _startDemoUpload('demo_image.jpg', 'image'),
                    ),
                    _buildDemoButton(
                      '🎥 Video Upload',
                      'video',
                      () => _startDemoUpload('demo_video.mp4', 'video'),
                    ),
                    _buildDemoButton(
                      '🎵 Audio Upload',
                      'audio',
                      () => _startDemoUpload('demo_audio.mp3', 'audio'),
                    ),
                    _buildDemoButton(
                      '📄 Document Upload',
                      'document',
                      () => _startDemoUpload('demo_document.pdf', 'document'),
                    ),
                  ],
                ),
                
                const SizedBox(height: 24),
                
                // Error demo
                Text(
                  'Error Simulation',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
                const SizedBox(height: 16),
                
                _buildDemoButton(
                  '❌ Upload with Error',
                  'error',
                  () => _startDemoUploadWithError('demo_error.txt', 'document'),
                  isError: true,
                ),
                
                const SizedBox(height: 24),
                
                // Features list
                Text(
                  'Features',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
                const SizedBox(height: 16),
                
                _buildFeatureItem(
                  '📊 Real-time Progress',
                  'Live progress updates with percentage and time estimation',
                ),
                _buildFeatureItem(
                  '🎨 Beautiful UI',
                  'Animated progress bars with color-coded status',
                ),
                _buildFeatureItem(
                  '✅ Success States',
                  'Clear completion indicators with success animations',
                ),
                _buildFeatureItem(
                  '❌ Error Handling',
                  'Graceful error display with retry options',
                ),
                _buildFeatureItem(
                  '🚫 Cancel Support',
                  'Ability to cancel uploads in progress',
                ),
                _buildFeatureItem(
                  '📱 Responsive Design',
                  'Adapts to different screen sizes and themes',
                ),
                
                const SizedBox(height: 100), // Space for floating progress
              ],
            ),
          ),
          
          // Upload Progress Manager
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: UploadProgressManager(
              onUploadsComplete: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('All demo uploads completed!'),
                    backgroundColor: Colors.green,
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDemoButton(String label, String type, VoidCallback onPressed, {bool isError = false}) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: Icon(
        isError ? Icons.error_outline : Icons.cloud_upload,
        size: 20,
      ),
      label: Text(label),
      style: ElevatedButton.styleFrom(
        backgroundColor: isError 
            ? Colors.red.shade600 
            : theme.colorScheme.primary,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(25),
        ),
        elevation: 4,
      ),
    );
  }

  Widget _buildFeatureItem(String title, String description) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? Colors.grey.shade800 : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? Colors.grey.shade700 : Colors.grey.shade300,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              Icons.check_circle,
              color: theme.colorScheme.primary,
              size: 20,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 14,
                    color: isDark ? Colors.white70 : Colors.black54,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
