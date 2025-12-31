import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import '../services/improved_media_service.dart';
import '../services/enhanced_unified_media_service.dart';
import '../services/multi_media_upload_service.dart';
import '../services/logger_service.dart';
import '../services/contact_picker_service.dart';
import '../utils/responsive_utils.dart';

/// Enhanced media sender widget with progress tracking and media preview
class EnhancedMediaSender extends StatefulWidget {
  final String chatId;
  final Function(String mediaUrl, String type, String text) onMediaSent;
  final Function(Map<String, dynamic> contactData)? onContactSent; // New callback for contacts
  final VoidCallback? onClose;

  const EnhancedMediaSender({
    super.key,
    required this.chatId,
    required this.onMediaSent,
    this.onContactSent,
    this.onClose,
  });

  @override
  State<EnhancedMediaSender> createState() => _EnhancedMediaSenderState();
}

class _EnhancedMediaSenderState extends State<EnhancedMediaSender> {
  List<EnhancedMediaResult> _selectedMedia = [];
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
      child: SingleChildScrollView(
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
            
            // Media selection buttons (only show if no media selected)
            if (_selectedMedia.isEmpty)
              _buildMediaSelectionButtons(theme, isDark),

            // Selected media preview (show grid if multiple, single if one)
            if (_selectedMedia.isNotEmpty) _buildMediaPreview(theme, isDark),

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
      ),
    );
  }

  Widget _buildMediaSelectionButtons(ThemeData theme, bool isDark) {
    return Column(
      children: [
        Text(
          kIsWeb ? 'Attach a file:' : 'Choose media type:',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: isDark ? Colors.white : Colors.black87,
          ),
        ),
        const SizedBox(height: 16),
        LayoutBuilder(
          builder: (context, constraints) {
            final screenWidth = constraints.maxWidth;
            final isWeb = kIsWeb;
            final isTablet = screenWidth > 600;
            
            // Responsive button size and layout
            double buttonSize;
            int buttonsPerRow;
            
            if (isWeb) {
              buttonSize = 100;
              buttonsPerRow = 4;
            } else if (isTablet) {
              buttonSize = 90;
              buttonsPerRow = 4;
            } else {
              buttonSize = 80;
              buttonsPerRow = 2; // Mobile: 2x2 grid
            }
            
            final buttons;
            
            if (isWeb) {
              // For web: only show document/file attachment (any file type)
              buttons = [
                _buildMediaButton(
                  icon: Icons.attach_file,
                  label: 'Attach File',
                  color: Colors.orange,
                  onTap: () => _pickAnyFile(),
                  size: buttonSize,
                ),
              ];
            } else {
              // For mobile: show all media options including contact
              buttons = [
                _buildMediaButton(
                  icon: Icons.photo_library,
                  label: 'Gallery',
                  color: Colors.blue,
                  onTap: () => _pickImageFromGallery(),
                  size: buttonSize,
                ),
                _buildMediaButton(
                  icon: Icons.camera_alt,
                  label: 'Camera',
                  color: Colors.green,
                  onTap: () => _pickImageFromCamera(),
                  size: buttonSize,
                ),
                _buildMediaButton(
                  icon: Icons.video_library,
                  label: 'Video',
                  color: Colors.red,
                  onTap: () => _pickVideoFromGallery(),
                  size: buttonSize,
                ),
                _buildMediaButton(
                  icon: Icons.attach_file,
                  label: 'Document',
                  color: Colors.orange,
                  onTap: () => _pickDocument(),
                  size: buttonSize,
                ),
                _buildMediaButton(
                  icon: Icons.contact_phone,
                  label: 'Contact',
                  color: Colors.purple,
                  onTap: () => _pickContact(),
                  size: buttonSize,
                ),
              ];
            }
            
            if (buttonsPerRow == 2) {
              // Mobile: 2x2 grid (or 2x3 if 5 buttons)
              final buttonRows = <Widget>[];
              for (int i = 0; i < buttons.length; i += 2) {
                buttonRows.add(
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: buttons.skip(i).take(2).toList(),
                  ),
                );
                if (i + 2 < buttons.length) {
                  buttonRows.add(
                    SizedBox(
                      height: ResponsiveUtils.getResponsiveValue(
                        context,
                        mobile: 12.0,
                        tablet: 14.0,
                        desktop: 16.0,
                      ),
                    ),
                  );
                }
              }
              return Column(
                children: buttonRows,
              );
            } else {
              // Web/Tablet: single row (or wrap if needed)
              return Wrap(
                alignment: WrapAlignment.spaceEvenly,
                spacing: ResponsiveUtils.getResponsiveValue(
                  context,
                  mobile: 8.0,
                  tablet: 12.0,
                  desktop: 16.0,
                ),
                runSpacing: ResponsiveUtils.getResponsiveValue(
                  context,
                  mobile: 8.0,
                  tablet: 12.0,
                  desktop: 16.0,
                ),
                children: buttons,
              );
            }
          },
        ),
      ],
    );
  }

  Widget _buildMediaButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
    required double size,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: size,
        height: size,
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
              size: size * 0.4, // Responsive icon size
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: size * 0.15, // Responsive font size
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMediaPreview(ThemeData theme, bool isDark) {
    if (_selectedMedia.isEmpty) return const SizedBox.shrink();

    Log.i('Building media preview for ${_selectedMedia.length} media files', 'ENHANCED_MEDIA_SENDER');

    // If single media, show detailed preview
    if (_selectedMedia.length == 1) {
      final media = _selectedMedia.first;
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isDark ? Colors.grey.shade800 : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(12),
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
                _getMediaIcon(media.type),
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
                    media.fileName,
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
                    '${media.type.toUpperCase()} • ${_formatFileSize(media.optimizedSize)}',
                    style: TextStyle(
                      color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            // Remove button
            IconButton(
              onPressed: () {
                setState(() {
                  _selectedMedia.clear();
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

    // Multiple media: show grid preview
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? Colors.grey.shade800 : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? Colors.grey.shade700 : Colors.grey.shade300,
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with count and clear button
          Row(
            children: [
              Icon(
                Icons.attach_file,
                color: theme.colorScheme.primary,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                '${_selectedMedia.length} files selected',
                style: TextStyle(
                  color: isDark ? Colors.white : Colors.black87,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              IconButton(
                onPressed: () {
                  setState(() {
                    _selectedMedia.clear();
                    _captionController.clear();
                    _uploadError = null;
                  });
                },
                icon: Icon(
                  Icons.close,
                  color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                  size: 20,
                ),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Grid of media thumbnails
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: ResponsiveUtils.isMobile(context) ? 3 : 4,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
              childAspectRatio: 1,
            ),
            itemCount: _selectedMedia.length,
            itemBuilder: (context, index) {
              final media = _selectedMedia[index];
              return Stack(
                children: [
                  // Thumbnail
                  Container(
                    decoration: BoxDecoration(
                      color: isDark ? Colors.grey.shade700 : Colors.grey.shade200,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isDark ? Colors.grey.shade600 : Colors.grey.shade300,
                        width: 1,
                      ),
                    ),
                    child: media.type == 'image'
                        ? Image.memory(
                            media.bytes,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Icon(
                              _getMediaIcon(media.type),
                              color: theme.colorScheme.primary,
                            ),
                          )
                        : Center(
                            child: Icon(
                              _getMediaIcon(media.type),
                              color: theme.colorScheme.primary,
                              size: 32,
                            ),
                          ),
                  ),
                  // Remove button
                  Positioned(
                    top: 4,
                    right: 4,
                    child: GestureDetector(
                      onTap: () {
                        setState(() {
                          _selectedMedia.removeAt(index);
                        });
                      },
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(
                          color: Colors.red,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.close,
                          color: Colors.white,
                          size: 14,
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
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
                _selectedMedia.clear();
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
            onPressed: (_isUploading || _selectedMedia.isEmpty) ? null : _uploadMedia,
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
      Log.i('Starting multiple image pick from gallery', 'ENHANCED_MEDIA_SENDER');
      if (kIsWeb) {
        // Web: use file picker with multiple and filter for images
        final allResults = await EnhancedUnifiedMediaService.pickMultipleMedia(context);
        final results = allResults.where((r) => r.type == 'image').toList();
        if (results.isNotEmpty) {
          setState(() {
            _selectedMedia.addAll(results);
            _uploadError = null;
          });
          Log.i('Selected ${results.length} images from gallery', 'ENHANCED_MEDIA_SENDER');
        }
      } else {
        // Mobile: use pickMultiImage
        final images = await ImagePicker().pickMultiImage(
          maxWidth: 1920,
          maxHeight: 1080,
          imageQuality: 85,
        );
        if (images.isNotEmpty) {
          final results = <EnhancedMediaResult>[];
          for (final image in images) {
            final bytes = await image.readAsBytes();
            results.add(EnhancedMediaResult(
              bytes: bytes,
              type: 'image',
              fileName: image.name,
              mimeType: 'image/jpeg',
              originalSize: bytes.length,
              optimizedSize: bytes.length,
              metadata: {
                'source': 'gallery',
                'platform': Platform.isIOS ? 'ios' : 'android',
                'timestamp': DateTime.now().toIso8601String(),
              },
            ));
          }
          setState(() {
            _selectedMedia.addAll(results);
            _uploadError = null;
          });
          Log.i('Selected ${results.length} images from gallery', 'ENHANCED_MEDIA_SENDER');
        }
      }
    } catch (e) {
      Log.e('Error picking images from gallery', 'ENHANCED_MEDIA_SENDER', e);
      _showError('Failed to pick images: $e');
    }
  }

  Future<void> _pickImageFromCamera() async {
    try {
      Log.i('Starting image pick from camera', 'ENHANCED_MEDIA_SENDER');
      final result = await ImprovedMediaService.pickImageFromCamera(context);
      Log.i('Camera pick result: ${result != null ? "Success" : "Null"}', 'ENHANCED_MEDIA_SENDER');
      if (result != null) {
        // Convert MediaResult to EnhancedMediaResult
        final enhancedResult = EnhancedMediaResult(
          bytes: result.bytes,
          type: result.type,
          fileName: result.fileName,
          mimeType: result.mimeType,
          originalSize: result.originalSize,
          optimizedSize: result.optimizedSize,
          metadata: {
            'source': 'camera',
            'platform': Platform.isIOS ? 'ios' : 'android',
            'timestamp': DateTime.now().toIso8601String(),
          },
        );
        setState(() {
          _selectedMedia.add(enhancedResult);
          _uploadError = null;
        });
        Log.i('Media selected successfully: ${result.type}', 'ENHANCED_MEDIA_SENDER');
      } else {
        Log.w('No media selected from camera', 'ENHANCED_MEDIA_SENDER');
      }
    } catch (e) {
      Log.e('Error picking image from camera', 'ENHANCED_MEDIA_SENDER', e);
      _showError('Failed to take photo: $e');
    }
  }

  Future<void> _pickVideoFromGallery() async {
    try {
      Log.i('Starting multiple video pick from gallery', 'ENHANCED_MEDIA_SENDER');
      // Use pickMultipleMedia with video filter
      final allResults = await EnhancedUnifiedMediaService.pickMultipleMedia(context);
      final results = allResults.where((r) => r.type == 'video').toList();
      if (results.isNotEmpty) {
        setState(() {
          _selectedMedia.addAll(results);
          _uploadError = null;
        });
        Log.i('Selected ${results.length} videos from gallery', 'ENHANCED_MEDIA_SENDER');
      }
    } catch (e) {
      Log.e('Error picking videos from gallery', 'ENHANCED_MEDIA_SENDER', e);
      _showError('Failed to pick videos: $e');
    }
  }

  Future<void> _pickDocument() async {
    try {
      Log.i('Starting multiple document pick', 'ENHANCED_MEDIA_SENDER');
      // Use pickMultipleMedia with document filter
      final allResults = await EnhancedUnifiedMediaService.pickMultipleMedia(context);
      final results = allResults.where((r) => r.type == 'document').toList();
      if (results.isNotEmpty) {
        setState(() {
          _selectedMedia.addAll(results);
          _uploadError = null;
        });
        Log.i('Selected ${results.length} documents', 'ENHANCED_MEDIA_SENDER');
      }
    } catch (e) {
      Log.e('Error picking documents', 'ENHANCED_MEDIA_SENDER', e);
      _showError('Failed to pick documents: $e');
    }
  }

  Future<void> _pickAnyFile() async {
    try {
      Log.i('Starting pick multiple files (web)', 'ENHANCED_MEDIA_SENDER');
      // On web, use pickMultipleMedia to allow multiple file selection
      final results = await EnhancedUnifiedMediaService.pickMultipleMedia(context);
      if (results.isNotEmpty) {
        setState(() {
          _selectedMedia.addAll(results);
          _uploadError = null;
        });
        Log.i('Selected ${results.length} files successfully', 'ENHANCED_MEDIA_SENDER');
      }
    } catch (e) {
      Log.e('Error picking file', 'ENHANCED_MEDIA_SENDER', e);
      _showError('Failed to pick file: $e');
    }
  }

  Future<void> _uploadMedia() async {
    if (_selectedMedia.isEmpty) return;

    try {
      setState(() {
        _isUploading = true;
        _uploadProgress = 0.0;
        _uploadError = null;
      });

      if (_selectedMedia.length == 1) {
        // Single media: use existing upload method
        final media = _selectedMedia.first;
        final mediaResult = MediaResult(
          bytes: media.bytes,
          type: media.type,
          fileName: media.fileName,
          mimeType: media.mimeType,
          originalSize: media.originalSize,
          optimizedSize: media.optimizedSize,
        );

        final mediaUrl = await ImprovedMediaService.uploadMediaWithProgress(
          mediaResult,
          widget.chatId,
          (progress) {
            setState(() {
              _uploadProgress = progress;
            });
          },
          caption: _captionController.text.trim(),
        );

        if (mediaUrl != null) {
          final caption = _captionController.text.trim();
          final text = caption.isNotEmpty ? caption : _getDefaultMediaText(mediaResult);
          
          widget.onMediaSent(mediaUrl, media.type, text);
          
          // Reset state
          setState(() {
            _selectedMedia.clear();
            _captionController.clear();
            _isUploading = false;
            _uploadProgress = 0.0;
          });
          widget.onClose?.call();
        } else {
          throw Exception('Failed to get media URL');
        }
      } else {
        // Multiple media: use MultiMediaUploadService
        final mediaUrls = <String>[];
        final mediaTypes = <String>[];

        final results = await MultiMediaUploadService().uploadMultiple(
          mediaResults: _selectedMedia,
          chatId: widget.chatId,
          sharedCaption: _captionController.text.isNotEmpty
              ? _captionController.text
              : null,
          onProgress: (uploadInfo) {
            // Update overall progress
            final totalProgress = uploadInfo.progress / _selectedMedia.length;
            setState(() {
              _uploadProgress = totalProgress.clamp(0.0, 1.0);
            });
          },
        );

        // Collect successful uploads
        for (int i = 0; i < results.length && i < _selectedMedia.length; i++) {
          final mediaUrl = results[i];
          if (mediaUrl != null && mediaUrl.isNotEmpty) {
            mediaUrls.add(mediaUrl);
            mediaTypes.add(_selectedMedia[i].type);
          }
        }

        if (mediaUrls.isNotEmpty) {
          // Send all media as separate messages
          Log.i('Sending ${mediaUrls.length} media files to chat', 'ENHANCED_MEDIA_SENDER');
          for (int i = 0; i < mediaUrls.length; i++) {
            // Use caption only for the first media
            final caption = (i == 0 && _captionController.text.isNotEmpty) 
                ? _captionController.text 
                : '';
            await widget.onMediaSent(mediaUrls[i], mediaTypes[i], caption);
            // Small delay between sends
            await Future.delayed(const Duration(milliseconds: 100));
          }
          setState(() {
            _selectedMedia.clear();
            _captionController.clear();
            _isUploading = false;
          });
          widget.onClose?.call();
        } else {
          setState(() {
            _isUploading = false;
            _uploadError = 'Failed to upload media';
          });
        }
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

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  Future<void> _pickContact() async {
    try {
      if (kIsWeb) {
        _showError('Contact picker is not supported on web');
        return;
      }

      if (!mounted) return;

      // Show loading indicator
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(),
        ),
      );

      final contactPicker = ContactPickerService();
      Map<String, dynamic>? contactData;
      
      try {
        contactData = await contactPicker.pickContact();
      } catch (e) {
        // Handle permission-related exceptions with specific messages
        if (mounted) {
          Navigator.pop(context); // Close loading dialog
          
          final errorMessage = e.toString();
          String userMessage;
          
          if (errorMessage.contains('permanently denied') || errorMessage.contains('Settings')) {
            // Permission permanently denied - guide user to settings
            userMessage = errorMessage.replaceAll('Exception: ', '');
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(userMessage),
                  duration: const Duration(seconds: 5),
                  action: SnackBarAction(
                    label: 'OK',
                    onPressed: () {},
                  ),
                ),
              );
            }
          } else if (errorMessage.contains('permission') || errorMessage.contains('denied')) {
            // General permission error
            userMessage = 'Contact permission is required to send contacts. Please grant contact access.';
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(userMessage),
                  duration: const Duration(seconds: 4),
                ),
              );
            }
          } else {
            // Other errors
            Log.e('Error picking contact', 'ENHANCED_MEDIA_SENDER', e);
            _showError('Failed to pick contact. Please try again.');
          }
        }
        return;
      }

      if (!mounted) return;
      Navigator.pop(context); // Close loading dialog

      if (contactData != null) {
        // Close media sender and send contact
        widget.onClose?.call();
        if (widget.onContactSent != null) {
          widget.onContactSent!(contactData);
        } else {
          // Fallback: send as JSON string if callback not provided
          final contactJson = contactData.toString();
          widget.onMediaSent('', 'contact', contactJson);
        }
      } else {
        // User cancelled contact selection (not an error, just inform silently)
        // Don't show error message for cancellation
        Log.i('Contact selection cancelled by user', 'ENHANCED_MEDIA_SENDER');
      }
    } catch (e, stackTrace) {
      Log.e('Unexpected error picking contact', 'ENHANCED_MEDIA_SENDER', e, stackTrace);
      if (mounted) {
        // Try to close loading dialog if still open
        try {
          Navigator.pop(context);
        } catch (_) {
          // Dialog might already be closed
        }
        _showError('Failed to pick contact. Please try again.');
      }
    }
  }
}
