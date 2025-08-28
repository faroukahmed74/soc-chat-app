import 'package:flutter/material.dart';
import 'dart:typed_data';
import '../services/enhanced_media_service.dart';
import '../services/logger_service.dart';
import '../services/permission_test_service.dart';

/// Enhanced media sender widget with progress tracking and media preview
class EnhancedMediaSender extends StatefulWidget {
  final String chatId;
  final Function(String mediaUrl, String type, String text) onMediaSent;
  final VoidCallback? onClose;

  const EnhancedMediaSender({
    super.key,
    required this.chatId,
    required this.onMediaSent,
    this.onClose,
  });

  @override
  State<EnhancedMediaSender> createState() => _EnhancedMediaSenderState();
}

class _EnhancedMediaSenderState extends State<EnhancedMediaSender> {
  MediaResult? _selectedMedia;
  bool _isUploading = false;
  double _uploadProgress = 0.0;
  String? _uploadError;
  final TextEditingController _captionController = TextEditingController();

  @override
  void dispose() {
    _captionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header
          Row(
            children: [
              Icon(
                Icons.attach_file,
                color: theme.colorScheme.primary,
                size: 24,
              ),
              const SizedBox(width: 12),
              Text(
                'Send Media',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
              const Spacer(),
              IconButton(
                onPressed: widget.onClose,
                icon: Icon(
                  Icons.close,
                  color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Media selection buttons
          if (_selectedMedia == null) _buildMediaSelectionButtons(theme, isDark),
          
          // Permission test button
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: () => PermissionTestService.testAllPermissions(context),
            icon: const Icon(Icons.security, size: 16),
            label: const Text('Test Permissions'),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
            ),
          ),

          // Selected media preview
          if (_selectedMedia != null) _buildMediaPreview(theme, isDark),

          // Caption input
          if (_selectedMedia != null) ...[
            const SizedBox(height: 16),
            TextField(
              controller: _captionController,
              decoration: InputDecoration(
                hintText: 'Add a caption...',
                hintStyle: TextStyle(
                  color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: isDark ? Colors.grey.shade700 : Colors.grey.shade300,
                  ),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: isDark ? Colors.grey.shade700 : Colors.grey.shade300,
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: theme.colorScheme.primary,
                    width: 2,
                  ),
                ),
                filled: true,
                fillColor: isDark ? Colors.grey.shade800 : Colors.grey.shade50,
              ),
              style: TextStyle(
                color: isDark ? Colors.white : Colors.black87,
              ),
              maxLines: 3,
            ),
          ],

          // Upload progress
          if (_isUploading) ...[
            const SizedBox(height: 16),
            _buildUploadProgress(theme, isDark),
          ],

          // Error message
          if (_uploadError != null) ...[
            const SizedBox(height: 16),
            _buildErrorMessage(theme, isDark),
          ],

          // Action buttons
          if (_selectedMedia != null) ...[
            const SizedBox(height: 16),
            _buildActionButtons(theme, isDark),
          ],
        ],
      ),
    );
  }

  Widget _buildMediaSelectionButtons(ThemeData theme, bool isDark) {
    return Column(
      children: [
        Text(
          'Choose media type:',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: isDark ? Colors.white : Colors.black87,
          ),
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildMediaButton(
              icon: Icons.photo_library,
              label: 'Gallery',
              color: Colors.blue,
              onTap: () => _pickImageFromGallery(),
            ),
            _buildMediaButton(
              icon: Icons.camera_alt,
              label: 'Camera',
              color: Colors.green,
              onTap: () => _pickImageFromCamera(),
            ),
            _buildMediaButton(
              icon: Icons.video_library,
              label: 'Video',
              color: Colors.red,
              onTap: () => _pickVideoFromGallery(),
            ),
            _buildMediaButton(
              icon: Icons.attach_file,
              label: 'Document',
              color: Colors.orange,
              onTap: () => _pickDocument(),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildMediaButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: 80,
        height: 80,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: color.withValues(alpha: 0.3),
            width: 1,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: color,
              size: 32,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMediaPreview(ThemeData theme, bool isDark) {
    if (_selectedMedia == null) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? Colors.grey.shade800 : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? Colors.grey.shade700 : Colors.grey.shade300,
          width: 1,
        ),
      ),
      child: Row(
        children: [
          // Media icon
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              _getMediaIcon(_selectedMedia!.type),
              color: theme.colorScheme.primary,
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          // Media info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _selectedMedia!.fileName,
                  style: TextStyle(
                    color: isDark ? Colors.white : Colors.black87,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  '${_selectedMedia!.type.toUpperCase()} • ${_selectedMedia!.formattedSize}',
                  style: TextStyle(
                    color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                    fontSize: 12,
                  ),
                ),
                if (_selectedMedia!.isOptimized) ...[
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(
                        Icons.compress,
                        size: 12,
                        color: Colors.green,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Optimized (${(_selectedMedia!.compressionRatio * 100).toStringAsFixed(0)}%)',
                        style: const TextStyle(
                          color: Colors.green,
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          // Remove button
          IconButton(
            onPressed: () {
              setState(() {
                _selectedMedia = null;
                _captionController.clear();
                _uploadError = null;
              });
            },
            icon: Icon(
              Icons.close,
              color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUploadProgress(ThemeData theme, bool isDark) {
    return Column(
      children: [
        Row(
          children: [
            Icon(
              Icons.cloud_upload,
              color: theme.colorScheme.primary,
              size: 20,
            ),
            const SizedBox(width: 8),
            Text(
              'Uploading...',
              style: TextStyle(
                color: isDark ? Colors.white : Colors.black87,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            const Spacer(),
            Text(
              '${(_uploadProgress * 100).toStringAsFixed(0)}%',
              style: TextStyle(
                color: theme.colorScheme.primary,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        LinearProgressIndicator(
          value: _uploadProgress,
          backgroundColor: isDark ? Colors.grey.shade700 : Colors.grey.shade300,
          valueColor: AlwaysStoppedAnimation<Color>(theme.colorScheme.primary),
        ),
      ],
    );
  }

  Widget _buildErrorMessage(ThemeData theme, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? Colors.red.shade900 : Colors.red.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? Colors.red.shade700 : Colors.red.shade200,
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.error_outline,
            color: isDark ? Colors.red.shade300 : Colors.red.shade600,
            size: 20,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _uploadError!,
              style: TextStyle(
                color: isDark ? Colors.red.shade300 : Colors.red.shade700,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons(ThemeData theme, bool isDark) {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton(
            onPressed: _isUploading ? null : () {
              setState(() {
                _selectedMedia = null;
                _captionController.clear();
                _uploadError = null;
              });
            },
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              side: BorderSide(
                color: isDark ? Colors.grey.shade600 : Colors.grey.shade400,
              ),
            ),
            child: Text(
              'Cancel',
              style: TextStyle(
                color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: ElevatedButton(
            onPressed: _isUploading ? null : _uploadMedia,
            style: ElevatedButton.styleFrom(
              backgroundColor: theme.colorScheme.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: _isUploading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : Text(
                    'Send',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
          ),
        ),
      ],
    );
  }

  IconData _getMediaIcon(String type) {
    switch (type) {
      case 'image':
        return Icons.photo;
      case 'video':
        return Icons.videocam;
      case 'document':
        return Icons.description;
      case 'audio':
        return Icons.audiotrack;
      default:
        return Icons.insert_drive_file;
    }
  }

  Future<void> _pickImageFromGallery() async {
    try {
      final result = await EnhancedMediaService.pickImageFromGallery(context);
      if (result != null) {
        setState(() {
          _selectedMedia = result;
          _uploadError = null;
        });
      }
    } catch (e) {
      Log.e('Error picking image from gallery', 'ENHANCED_MEDIA_SENDER', e);
      _showError('Failed to pick image: $e');
    }
  }

  Future<void> _pickImageFromCamera() async {
    try {
      final result = await EnhancedMediaService.pickImageFromCamera(context);
      if (result != null) {
        setState(() {
          _selectedMedia = result;
          _uploadError = null;
        });
      }
    } catch (e) {
      Log.e('Error picking image from camera', 'ENHANCED_MEDIA_SENDER', e);
      _showError('Failed to take photo: $e');
    }
  }

  Future<void> _pickVideoFromGallery() async {
    try {
      final result = await EnhancedMediaService.pickVideoFromGallery(context);
      if (result != null) {
        setState(() {
          _selectedMedia = result;
          _uploadError = null;
        });
      }
    } catch (e) {
      Log.e('Error picking video from gallery', 'ENHANCED_MEDIA_SENDER', e);
      _showError('Failed to pick video: $e');
    }
  }

  Future<void> _pickDocument() async {
    try {
      final result = await EnhancedMediaService.pickDocument(context);
      if (result != null) {
        setState(() {
          _selectedMedia = result;
          _uploadError = null;
        });
      }
    } catch (e) {
      Log.e('Error picking document', 'ENHANCED_MEDIA_SENDER', e);
      _showError('Failed to pick document: $e');
    }
  }

  Future<void> _uploadMedia() async {
    if (_selectedMedia == null) return;

    try {
      setState(() {
        _isUploading = true;
        _uploadProgress = 0.0;
        _uploadError = null;
      });

      final mediaUrl = await EnhancedMediaService.uploadMediaWithProgress(
        _selectedMedia!,
        widget.chatId,
        (progress) {
          setState(() {
            _uploadProgress = progress;
          });
        },
      );

      if (mediaUrl != null) {
        final caption = _captionController.text.trim();
        final text = caption.isNotEmpty ? caption : _getDefaultMediaText(_selectedMedia!);
        
        widget.onMediaSent(mediaUrl, _selectedMedia!.type, text);
        
        // Reset state
        setState(() {
          _selectedMedia = null;
          _captionController.clear();
          _isUploading = false;
          _uploadProgress = 0.0;
        });
      } else {
        throw Exception('Failed to get media URL');
      }
    } catch (e) {
      Log.e('Error uploading media', 'ENHANCED_MEDIA_SENDER', e);
      setState(() {
        _isUploading = false;
        _uploadError = 'Upload failed: $e';
      });
    }
  }

  String _getDefaultMediaText(MediaResult media) {
    switch (media.type) {
      case 'image':
        return '📷 Image';
      case 'video':
        return '🎥 Video';
      case 'document':
        return '📄 ${media.fileName}';
      case 'audio':
        return '🎵 Audio Message';
      default:
        return '📎 File';
    }
  }

  void _showError(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }
}
