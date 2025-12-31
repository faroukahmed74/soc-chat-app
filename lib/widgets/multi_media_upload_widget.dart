import 'package:flutter/material.dart';
import '../services/multi_media_upload_service.dart';
import '../services/enhanced_unified_media_service.dart';
import '../services/logger_service.dart';
import '../utils/responsive_utils.dart';
import 'upload_progress_indicator.dart';

/// Widget for displaying and managing multiple media uploads
class MultiMediaUploadWidget extends StatefulWidget {
  final String chatId;
  final Function(List<String> mediaUrls, List<String> mediaTypes)? onUploadComplete;
  final VoidCallback? onClose;

  const MultiMediaUploadWidget({
    super.key,
    required this.chatId,
    this.onUploadComplete,
    this.onClose,
  });

  @override
  State<MultiMediaUploadWidget> createState() => _MultiMediaUploadWidgetState();
}

class _MultiMediaUploadWidgetState extends State<MultiMediaUploadWidget> {
  final List<EnhancedMediaResult> _selectedMedia = [];
  final Map<String, UploadInfo> _uploadInfos = {};
  final TextEditingController _captionController = TextEditingController();
  bool _isUploading = false;

  @override
  void dispose() {
    _captionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final screenType = ResponsiveUtils.getScreenType(context);
    final isMobile = ResponsiveUtils.isMobile(context);
    final isTablet = ResponsiveUtils.isTablet(context);
    final isDesktop = ResponsiveUtils.isDesktop(context);
    final screenHeight = MediaQuery.of(context).size.height;
    final spacing = ResponsiveUtils.getResponsiveSpacing(context);

    // Responsive max height
    final maxHeight = ResponsiveUtils.getResponsiveValue(
      context,
      mobile: screenHeight * 0.85,
      tablet: screenHeight * 0.9,
      desktop: screenHeight * 0.95,
    );

    return Container(
      constraints: BoxConstraints(
        maxHeight: maxHeight,
      ),
      padding: ResponsiveUtils.getResponsivePadding(context),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(ResponsiveUtils.getResponsiveValue(
            context,
            mobile: 16.0,
            tablet: 20.0,
            desktop: 24.0,
          )),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: ResponsiveUtils.getResponsiveValue(
              context,
              mobile: 8.0,
              tablet: 10.0,
              desktop: 12.0,
            ),
            offset: Offset(
              0,
              -ResponsiveUtils.getResponsiveValue(
                context,
                mobile: 2.0,
                tablet: 2.0,
                desktop: 4.0,
              ),
            ),
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
                size: ResponsiveUtils.getResponsiveIconSize(context) * 1.2,
              ),
              SizedBox(width: spacing * 0.75),
              Expanded(
                child: Text(
                  'Send Multiple Media (${_selectedMedia.length})',
                  style: TextStyle(
                    fontSize: ResponsiveUtils.getResponsiveFontSize(context, baseSize: 18),
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              IconButton(
                onPressed: widget.onClose,
                icon: Icon(
                  Icons.close,
                  color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                ),
              ),
            ],
          ),
          SizedBox(height: spacing),

          // Media selection button
          if (_selectedMedia.isEmpty)
            _buildSelectMediaButton(theme, isDark, isMobile, isTablet, isDesktop),

          // Selected media grid
          if (_selectedMedia.isNotEmpty) ...[
            _buildMediaGrid(theme, isDark, isMobile, isTablet, isDesktop),
            SizedBox(height: spacing),
            
            // Caption input
            TextField(
              controller: _captionController,
              decoration: InputDecoration(
                hintText: 'Add caption (optional)',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(
                    ResponsiveUtils.getResponsiveValue(
                      context,
                      mobile: 8.0,
                      tablet: 10.0,
                      desktop: 12.0,
                    ),
                  ),
                ),
                filled: true,
                fillColor: isDark ? Colors.grey[800] : Colors.grey[100],
                contentPadding: ResponsiveUtils.getResponsivePadding(context) * 0.75,
              ),
              maxLines: ResponsiveUtils.getResponsiveValue(
                context,
                mobile: 2,
                tablet: 3,
                desktop: 4,
              ),
              style: TextStyle(
                fontSize: ResponsiveUtils.getResponsiveFontSize(context, baseSize: 14),
              ),
            ),
            SizedBox(height: spacing),

            // Action buttons
            ResponsiveUtils.isMobile(context)
                ? Column(
                    children: [
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: _isUploading ? null : _startUpload,
                          icon: _isUploading
                              ? SizedBox(
                                  width: ResponsiveUtils.getResponsiveIconSize(context) * 0.8,
                                  height: ResponsiveUtils.getResponsiveIconSize(context) * 0.8,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : Icon(
                                  Icons.send,
                                  size: ResponsiveUtils.getResponsiveIconSize(context),
                                ),
                          label: Text(
                            _isUploading ? 'Uploading...' : 'Send All',
                            style: TextStyle(
                              fontSize: ResponsiveUtils.getResponsiveFontSize(context, baseSize: 14),
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: theme.colorScheme.primary,
                            foregroundColor: Colors.white,
                            padding: EdgeInsets.symmetric(
                              vertical: ResponsiveUtils.getResponsiveSpacing(context),
                            ),
                            minimumSize: Size(
                              double.infinity,
                              ResponsiveUtils.getResponsiveButtonHeight(context),
                            ),
                          ),
                        ),
                      ),
                      if (!_isUploading) SizedBox(height: spacing * 0.5),
                      if (!_isUploading)
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: () {
                              setState(() {
                                _selectedMedia.clear();
                                _captionController.clear();
                              });
                            },
                            icon: Icon(
                              Icons.clear,
                              size: ResponsiveUtils.getResponsiveIconSize(context),
                            ),
                            label: Text(
                              'Clear All',
                              style: TextStyle(
                                fontSize: ResponsiveUtils.getResponsiveFontSize(context, baseSize: 14),
                              ),
                            ),
                            style: OutlinedButton.styleFrom(
                              padding: EdgeInsets.symmetric(
                                vertical: ResponsiveUtils.getResponsiveSpacing(context),
                              ),
                              minimumSize: Size(
                                double.infinity,
                                ResponsiveUtils.getResponsiveButtonHeight(context),
                              ),
                            ),
                          ),
                        ),
                    ],
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      if (!_isUploading)
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () {
                              setState(() {
                                _selectedMedia.clear();
                                _captionController.clear();
                              });
                            },
                            icon: Icon(
                              Icons.clear,
                              size: ResponsiveUtils.getResponsiveIconSize(context),
                            ),
                            label: Text(
                              'Clear All',
                              style: TextStyle(
                                fontSize: ResponsiveUtils.getResponsiveFontSize(context, baseSize: 14),
                              ),
                            ),
                            style: OutlinedButton.styleFrom(
                              padding: EdgeInsets.symmetric(
                                vertical: ResponsiveUtils.getResponsiveSpacing(context),
                              ),
                              minimumSize: Size(
                                0,
                                ResponsiveUtils.getResponsiveButtonHeight(context),
                              ),
                            ),
                          ),
                        ),
                      if (!_isUploading) SizedBox(width: spacing),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _isUploading ? null : _startUpload,
                          icon: _isUploading
                              ? SizedBox(
                                  width: ResponsiveUtils.getResponsiveIconSize(context) * 0.8,
                                  height: ResponsiveUtils.getResponsiveIconSize(context) * 0.8,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : Icon(
                                  Icons.send,
                                  size: ResponsiveUtils.getResponsiveIconSize(context),
                                ),
                          label: Text(
                            _isUploading ? 'Uploading...' : 'Send All',
                            style: TextStyle(
                              fontSize: ResponsiveUtils.getResponsiveFontSize(context, baseSize: 14),
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: theme.colorScheme.primary,
                            foregroundColor: Colors.white,
                            padding: EdgeInsets.symmetric(
                              vertical: ResponsiveUtils.getResponsiveSpacing(context),
                            ),
                            minimumSize: Size(
                              0,
                              ResponsiveUtils.getResponsiveButtonHeight(context),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
          ],

          // Upload progress list
          if (_isUploading && _uploadInfos.isNotEmpty) ...[
            SizedBox(height: spacing),
            _buildUploadProgressList(theme, isDark, isMobile, isTablet, isDesktop),
          ],
        ],
      ),
    );
  }

  Widget _buildSelectMediaButton(
    ThemeData theme,
    bool isDark,
    bool isMobile,
    bool isTablet,
    bool isDesktop,
  ) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: _selectMultipleMedia,
        icon: Icon(
          Icons.add_photo_alternate,
          size: ResponsiveUtils.getResponsiveIconSize(context),
        ),
        label: Text(
          'Select Multiple Files',
          style: TextStyle(
            fontSize: ResponsiveUtils.getResponsiveFontSize(context, baseSize: 14),
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: theme.colorScheme.primary,
          foregroundColor: Colors.white,
          padding: ResponsiveUtils.getResponsivePadding(context) * 0.75,
          minimumSize: Size(
            double.infinity,
            ResponsiveUtils.getResponsiveButtonHeight(context),
          ),
        ),
      ),
    );
  }

  Widget _buildMediaGrid(
    ThemeData theme,
    bool isDark,
    bool isMobile,
    bool isTablet,
    bool isDesktop,
  ) {
    final crossAxisCount = ResponsiveUtils.getResponsiveValue(
      context,
      mobile: 2,
      tablet: 3,
      desktop: 4,
    );
    final spacing = ResponsiveUtils.getResponsiveSpacing(context) * 0.5;

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        crossAxisSpacing: spacing,
        mainAxisSpacing: spacing,
        childAspectRatio: 1.0,
      ),
      itemCount: _selectedMedia.length,
      itemBuilder: (context, index) {
        final media = _selectedMedia[index];
        return _buildMediaThumbnail(media, index, theme, isDark);
      },
    );
  }

  Widget _buildMediaThumbnail(
    EnhancedMediaResult media,
    int index,
    ThemeData theme,
    bool isDark,
  ) {
    return Stack(
      children: [
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            color: isDark ? Colors.grey[800] : Colors.grey[200],
          ),
          child: media.type == 'image'
              ? Image.memory(
                  media.bytes,
                  fit: BoxFit.cover,
                )
              : Center(
                  child: Icon(
                    media.type == 'video'
                        ? Icons.videocam
                        : media.type == 'audio'
                            ? Icons.audiotrack
                            : Icons.insert_drive_file,
                    size: ResponsiveUtils.getResponsiveIconSize(context) * 2,
                    color: isDark ? Colors.white70 : Colors.black54,
                  ),
                ),
        ),
        Positioned(
          top: ResponsiveUtils.getResponsiveValue(
            context,
            mobile: 4.0,
            tablet: 6.0,
            desktop: 8.0,
          ),
          right: ResponsiveUtils.getResponsiveValue(
            context,
            mobile: 4.0,
            tablet: 6.0,
            desktop: 8.0,
          ),
          child: IconButton(
            icon: Icon(
              Icons.close,
              size: ResponsiveUtils.getResponsiveIconSize(context),
            ),
            color: Colors.white,
            onPressed: () {
              setState(() {
                _selectedMedia.removeAt(index);
              });
            },
            style: IconButton.styleFrom(
              backgroundColor: Colors.red.withOpacity(0.7),
              padding: EdgeInsets.all(
                ResponsiveUtils.getResponsiveValue(
                  context,
                  mobile: 4.0,
                  tablet: 6.0,
                  desktop: 8.0,
                ),
              ),
              minimumSize: Size(
                ResponsiveUtils.getResponsiveValue(
                  context,
                  mobile: 32.0,
                  tablet: 36.0,
                  desktop: 40.0,
                ),
                ResponsiveUtils.getResponsiveValue(
                  context,
                  mobile: 32.0,
                  tablet: 36.0,
                  desktop: 40.0,
                ),
              ),
            ),
          ),
        ),
        Positioned(
          bottom: ResponsiveUtils.getResponsiveValue(
            context,
            mobile: 4.0,
            tablet: 6.0,
            desktop: 8.0,
          ),
          left: ResponsiveUtils.getResponsiveValue(
            context,
            mobile: 4.0,
            tablet: 6.0,
            desktop: 8.0,
          ),
          right: ResponsiveUtils.getResponsiveValue(
            context,
            mobile: 4.0,
            tablet: 6.0,
            desktop: 8.0,
          ),
          child: Text(
            media.fileName,
            style: TextStyle(
              color: Colors.white,
              fontSize: ResponsiveUtils.getResponsiveFontSize(context, baseSize: 10),
              shadows: [
                Shadow(
                  color: Colors.black,
                  blurRadius: ResponsiveUtils.getResponsiveValue(
                    context,
                    mobile: 4.0,
                    tablet: 6.0,
                    desktop: 8.0,
                  ),
                ),
              ],
            ),
            maxLines: ResponsiveUtils.getResponsiveValue(
              context,
              mobile: 1,
              tablet: 2,
              desktop: 2,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _buildUploadProgressList(
    ThemeData theme,
    bool isDark,
    bool isMobile,
    bool isTablet,
    bool isDesktop,
  ) {
    final maxHeight = ResponsiveUtils.getResponsiveValue(
      context,
      mobile: 150.0,
      tablet: 200.0,
      desktop: 250.0,
    );
    final spacing = ResponsiveUtils.getResponsiveSpacing(context);

    return Container(
      constraints: BoxConstraints(maxHeight: maxHeight),
      child: ListView.builder(
        shrinkWrap: true,
        itemCount: _uploadInfos.length,
        itemBuilder: (context, index) {
          final uploadInfo = _uploadInfos.values.elementAt(index);
          return Card(
            margin: EdgeInsets.only(
              bottom: spacing * 0.5,
            ),
            child: ListTile(
              contentPadding: ResponsiveUtils.getResponsivePadding(context) * 0.5,
              leading: Icon(
                _getMediaIcon(uploadInfo.mediaType),
                color: theme.colorScheme.primary,
                size: ResponsiveUtils.getResponsiveIconSize(context) * 1.2,
              ),
              title: Text(
                uploadInfo.fileName,
                maxLines: ResponsiveUtils.getResponsiveValue(
                  context,
                  mobile: 1,
                  tablet: 2,
                  desktop: 2,
                ),
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: ResponsiveUtils.getResponsiveFontSize(context, baseSize: 14),
                ),
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(height: spacing * 0.25),
                  LinearProgressIndicator(
                    value: uploadInfo.progress,
                    backgroundColor: isDark ? Colors.grey[700] : Colors.grey[300],
                    valueColor: AlwaysStoppedAnimation<Color>(
                      uploadInfo.state == UploadState.completed
                          ? Colors.green
                          : uploadInfo.state == UploadState.failed
                              ? Colors.red
                              : theme.colorScheme.primary,
                    ),
                    minHeight: ResponsiveUtils.getResponsiveValue(
                      context,
                      mobile: 4.0,
                      tablet: 6.0,
                      desktop: 8.0,
                    ),
                  ),
                  SizedBox(height: spacing * 0.25),
                  Text(
                    uploadInfo.statusMessage ?? '',
                    style: TextStyle(
                      fontSize: ResponsiveUtils.getResponsiveFontSize(context, baseSize: 12),
                      color: uploadInfo.state == UploadState.failed
                          ? Colors.red
                          : isDark
                              ? Colors.grey[400]
                              : Colors.grey[600],
                    ),
                    maxLines: ResponsiveUtils.getResponsiveValue(
                      context,
                      mobile: 1,
                      tablet: 2,
                      desktop: 2,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
              trailing: uploadInfo.state == UploadState.uploading
                  ? IconButton(
                      icon: Icon(
                        Icons.cancel,
                        size: ResponsiveUtils.getResponsiveIconSize(context),
                      ),
                      onPressed: () {
                        MultiMediaUploadService().cancel(uploadInfo.id);
                      },
                      tooltip: 'Cancel upload',
                    )
                  : uploadInfo.state == UploadState.completed
                      ? Icon(
                          Icons.check_circle,
                          color: Colors.green,
                          size: ResponsiveUtils.getResponsiveIconSize(context) * 1.2,
                        )
                      : uploadInfo.state == UploadState.failed
                          ? Icon(
                              Icons.error,
                              color: Colors.red,
                              size: ResponsiveUtils.getResponsiveIconSize(context) * 1.2,
                            )
                          : null,
            ),
          );
        },
      ),
    );
  }

  IconData _getMediaIcon(String mediaType) {
    switch (mediaType) {
      case 'image':
        return Icons.image;
      case 'video':
        return Icons.videocam;
      case 'audio':
        return Icons.audiotrack;
      default:
        return Icons.insert_drive_file;
    }
  }

  Future<void> _selectMultipleMedia() async {
    final results = await EnhancedUnifiedMediaService.pickMultipleMedia(context);
    if (results.isNotEmpty && mounted) {
      setState(() {
        _selectedMedia.addAll(results);
      });
    }
  }

  Future<void> _startUpload() async {
    if (_selectedMedia.isEmpty) return;

    setState(() {
      _isUploading = true;
      _uploadInfos.clear();
    });

    final mediaUrls = <String>[];
    final mediaTypes = <String>[];

    try {
      // Track progress for UI updates
      final progressMap = <String, UploadInfo>{};
      
      final results = await MultiMediaUploadService().uploadMultiple(
        mediaResults: _selectedMedia,
        chatId: widget.chatId,
        sharedCaption: _captionController.text.isNotEmpty
            ? _captionController.text
            : null,
        onProgress: (uploadInfo) {
          if (mounted) {
            setState(() {
              _uploadInfos[uploadInfo.id] = uploadInfo;
              progressMap[uploadInfo.id] = uploadInfo;
            });
          }
        },
      );

      // Use the results directly from uploadMultiple - it returns all URLs in order
      // Filter out null values and match with media types
      for (int i = 0; i < results.length && i < _selectedMedia.length; i++) {
        final mediaUrl = results[i];
        if (mediaUrl != null && mediaUrl.isNotEmpty) {
          mediaUrls.add(mediaUrl);
          mediaTypes.add(_selectedMedia[i].type);
        }
      }

      // Also check progress map as fallback for any missing URLs
      for (var media in _selectedMedia) {
        // Find matching upload info by checking all upload infos
        for (var uploadInfo in _uploadInfos.values) {
          if (uploadInfo.fileName == media.fileName && 
              uploadInfo.mediaUrl != null &&
              !mediaUrls.contains(uploadInfo.mediaUrl)) {
            mediaUrls.add(uploadInfo.mediaUrl!);
            mediaTypes.add(uploadInfo.mediaType);
            break;
          }
        }
      }

      if (mounted) {
        // Only call callback if we have at least one successful upload
        if (mediaUrls.isNotEmpty) {
          Log.i('Sending ${mediaUrls.length} media files: $mediaUrls', 'MULTI_MEDIA_UPLOAD_WIDGET');
          widget.onUploadComplete?.call(mediaUrls, mediaTypes);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('No files were uploaded successfully'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      }
    } catch (e) {
      Log.e('Error in _startUpload', 'MULTI_MEDIA_UPLOAD_WIDGET', e);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Upload error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isUploading = false;
        });
      }
    }
  }
}

