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
      padding: ResponsiveUtils.getResponsivePadding(context),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(
            ResponsiveUtils.getResponsiveValue(
              context,
              mobile: 20.0,
              tablet: 24.0,
              desktop: 28.0,
            ),
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: ResponsiveUtils.getResponsiveValue(
              context,
              mobile: 10.0,
              tablet: 12.0,
              desktop: 14.0,
            ),
            offset: Offset(
              0,
              -ResponsiveUtils.getResponsiveValue(
                context,
                mobile: 2.0,
                tablet: 3.0,
                desktop: 4.0,
              ),
            ),
          ),
        ],
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Drag handle
            Container(
              margin: EdgeInsets.only(
                top: ResponsiveUtils.getResponsiveValue(
                  context,
                  mobile: 8.0,
                  tablet: 10.0,
                  desktop: 12.0,
                ),
                bottom: ResponsiveUtils.getResponsiveValue(
                  context,
                  mobile: 4.0,
                  tablet: 6.0,
                  desktop: 8.0,
                ),
              ),
              width: ResponsiveUtils.getResponsiveValue(
                context,
                mobile: 40.0,
                tablet: 50.0,
                desktop: 60.0,
              ),
              height: ResponsiveUtils.getResponsiveValue(
                context,
                mobile: 4.0,
                tablet: 5.0,
                desktop: 6.0,
              ),
              decoration: BoxDecoration(
                color: isDark ? Colors.grey.shade700 : Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            SizedBox(
              height: ResponsiveUtils.getResponsiveValue(
                context,
                mobile: 8.0,
                tablet: 10.0,
                desktop: 12.0,
              ),
            ),
            // Header
            Row(
              children: [
                Container(
                  padding: EdgeInsets.all(
                    ResponsiveUtils.getResponsiveValue(
                      context,
                      mobile: 8.0,
                      tablet: 10.0,
                      desktop: 12.0,
                    ),
                  ),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        theme.colorScheme.primary,
                        theme.colorScheme.primary.withValues(alpha: 0.7),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(
                      ResponsiveUtils.getResponsiveValue(
                        context,
                        mobile: 12.0,
                        tablet: 14.0,
                        desktop: 16.0,
                      ),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: theme.colorScheme.primary.withValues(alpha: 0.3),
                        blurRadius: ResponsiveUtils.getResponsiveValue(
                          context,
                          mobile: 8.0,
                          tablet: 10.0,
                          desktop: 12.0,
                        ),
                        offset: Offset(
                          0,
                          ResponsiveUtils.getResponsiveValue(
                            context,
                            mobile: 2.0,
                            tablet: 3.0,
                            desktop: 4.0,
                          ),
                        ),
                      ),
                    ],
                  ),
                  child: Icon(
                    Icons.attach_file_rounded,
                    color: Colors.white,
                    size: ResponsiveUtils.getResponsiveIconSize(context),
                  ),
                ),
                SizedBox(
                  width: ResponsiveUtils.getResponsiveValue(
                    context,
                    mobile: 12.0,
                    tablet: 14.0,
                    desktop: 16.0,
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Send Media',
                        style: TextStyle(
                          fontSize: ResponsiveUtils.getResponsiveFontSize(
                            context,
                            baseSize: 20,
                          ),
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : Colors.black87,
                          letterSpacing: -0.5,
                        ),
                      ),
                      Text(
                        'Choose what to share',
                        style: TextStyle(
                          fontSize: ResponsiveUtils.getResponsiveFontSize(
                            context,
                            baseSize: 12,
                          ),
                          color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  decoration: BoxDecoration(
                    color: isDark ? Colors.grey.shade800 : Colors.grey.shade100,
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    onPressed: widget.onClose,
                    icon: Icon(
                      Icons.close_rounded,
                      color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                      size: ResponsiveUtils.getResponsiveIconSize(context),
                    ),
                    padding: EdgeInsets.all(
                      ResponsiveUtils.getResponsiveValue(
                        context,
                        mobile: 8.0,
                        tablet: 10.0,
                        desktop: 12.0,
                      ),
                    ),
                    constraints: const BoxConstraints(),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            
            // Media selection buttons (always show, but can be collapsed)
            _buildMediaSelectionButtons(theme, isDark),

            // Selected media preview (show grid if multiple, single if one)
            if (_selectedMedia.isNotEmpty) ...[
              _buildMediaPreview(theme, isDark),
              SizedBox(
                height: ResponsiveUtils.getResponsiveValue(
                  context,
                  mobile: 12.0,
                  tablet: 14.0,
                  desktop: 16.0,
                ),
              ),
              // Add More button - shows quick action buttons
              Container(
                padding: EdgeInsets.symmetric(
                  vertical: ResponsiveUtils.getResponsiveValue(
                    context,
                    mobile: 8.0,
                    tablet: 10.0,
                    desktop: 12.0,
                  ),
                  horizontal: ResponsiveUtils.getResponsiveValue(
                    context,
                    mobile: 12.0,
                    tablet: 16.0,
                    desktop: 20.0,
                  ),
                ),
                decoration: BoxDecoration(
                  color: isDark ? Colors.grey.shade800 : Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(
                    ResponsiveUtils.getResponsiveValue(
                      context,
                      mobile: 12.0,
                      tablet: 14.0,
                      desktop: 16.0,
                    ),
                  ),
                  border: Border.all(
                    color: isDark ? Colors.grey.shade700 : Colors.grey.shade200,
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildQuickActionButton(
                      icon: Icons.photo_library_rounded,
                      label: 'Photos',
                      color: Colors.blue,
                      onTap: _pickImageFromGallery,
                      theme: theme,
                    ),
                    _buildQuickActionButton(
                      icon: Icons.video_library_rounded,
                      label: 'Videos',
                      color: Colors.red,
                      onTap: _pickVideoFromGallery,
                      theme: theme,
                    ),
                    _buildQuickActionButton(
                      icon: Icons.insert_drive_file_rounded,
                      label: 'Files',
                      color: Colors.orange,
                      onTap: _pickDocument,
                      theme: theme,
                    ),
                  ],
                ),
              ),
            ],

            // Caption input
            if (_selectedMedia.isNotEmpty) ...[
              SizedBox(
                height: ResponsiveUtils.getResponsiveSpacing(context),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.text_fields_rounded,
                        size: ResponsiveUtils.getResponsiveValue(
                          context,
                          mobile: 16.0,
                          tablet: 18.0,
                          desktop: 20.0,
                        ),
                        color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                      ),
                      SizedBox(
                        width: ResponsiveUtils.getResponsiveValue(
                          context,
                          mobile: 6.0,
                          tablet: 8.0,
                          desktop: 10.0,
                        ),
                      ),
                      Text(
                        'Caption (optional)',
                        style: TextStyle(
                          fontSize: ResponsiveUtils.getResponsiveFontSize(
                            context,
                            baseSize: 12,
                          ),
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                          letterSpacing: 0.3,
                        ),
                      ),
                      const Spacer(),
                      ValueListenableBuilder<TextEditingValue>(
                        valueListenable: _captionController,
                        builder: (context, value, child) {
                          final length = value.text.length;
                          return Text(
                            '$length / 500',
                            style: TextStyle(
                              fontSize: ResponsiveUtils.getResponsiveFontSize(
                                context,
                                baseSize: 11,
                              ),
                              color: length > 450
                                  ? Colors.orange
                                  : (isDark ? Colors.grey.shade500 : Colors.grey.shade500),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                  SizedBox(
                    height: ResponsiveUtils.getResponsiveValue(
                      context,
                      mobile: 8.0,
                      tablet: 10.0,
                      desktop: 12.0,
                    ),
                  ),
                  TextField(
                    controller: _captionController,
                    decoration: InputDecoration(
                      hintText: 'Add a caption to your media...',
                      hintStyle: TextStyle(
                        color: isDark ? Colors.grey.shade500 : Colors.grey.shade500,
                        fontSize: ResponsiveUtils.getResponsiveFontSize(
                          context,
                          baseSize: 14,
                        ),
                      ),
                      prefixIcon: Icon(
                        Icons.edit_rounded,
                        size: ResponsiveUtils.getResponsiveIconSize(context),
                        color: isDark ? Colors.grey.shade500 : Colors.grey.shade500,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(
                          ResponsiveUtils.getResponsiveValue(
                            context,
                            mobile: 16.0,
                            tablet: 18.0,
                            desktop: 20.0,
                          ),
                        ),
                        borderSide: BorderSide(
                          color: isDark ? Colors.grey.shade700 : Colors.grey.shade300,
                        ),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(
                          ResponsiveUtils.getResponsiveValue(
                            context,
                            mobile: 16.0,
                            tablet: 18.0,
                            desktop: 20.0,
                          ),
                        ),
                        borderSide: BorderSide(
                          color: isDark ? Colors.grey.shade700 : Colors.grey.shade300,
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(
                          ResponsiveUtils.getResponsiveValue(
                            context,
                            mobile: 16.0,
                            tablet: 18.0,
                            desktop: 20.0,
                          ),
                        ),
                        borderSide: BorderSide(
                          color: theme.colorScheme.primary,
                          width: ResponsiveUtils.getResponsiveValue(
                            context,
                            mobile: 2.0,
                            tablet: 2.5,
                            desktop: 3.0,
                          ),
                        ),
                      ),
                      filled: true,
                      fillColor: isDark ? Colors.grey.shade800 : Colors.grey.shade50,
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: ResponsiveUtils.getResponsiveValue(
                          context,
                          mobile: 16.0,
                          tablet: 20.0,
                          desktop: 24.0,
                        ),
                        vertical: ResponsiveUtils.getResponsiveValue(
                          context,
                          mobile: 14.0,
                          tablet: 16.0,
                          desktop: 18.0,
                        ),
                      ),
                    ),
                    style: TextStyle(
                      color: isDark ? Colors.white : Colors.black87,
                      fontSize: ResponsiveUtils.getResponsiveFontSize(
                        context,
                        baseSize: 14,
                      ),
                    ),
                    maxLines: ResponsiveUtils.getResponsiveValue(
                      context,
                      mobile: 3,
                      tablet: 4,
                      desktop: 5,
                    ),
                    maxLength: 500,
                    buildCounter: (context, {required currentLength, required isFocused, maxLength}) => null,
                  ),
                ],
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
            if (_selectedMedia.isNotEmpty) ...[
              const SizedBox(height: 20),
              _buildActionButtons(theme, isDark),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildMediaSelectionButtons(ThemeData theme, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Text(
            kIsWeb ? 'Attach a file' : 'Choose media type',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.grey.shade300 : Colors.grey.shade700,
              letterSpacing: 0.5,
            ),
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
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                color.withValues(alpha: 0.15),
                color.withValues(alpha: 0.08),
              ],
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: color.withValues(alpha: 0.2),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: 0.1),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: EdgeInsets.all(size * 0.15),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  icon,
                  color: color,
                  size: size * 0.35,
                ),
              ),
              SizedBox(height: size * 0.08),
              Text(
                label,
                style: TextStyle(
                  color: color,
                  fontSize: size * 0.14,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.3,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
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
        padding: ResponsiveUtils.getResponsivePadding(context),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isDark
                ? [
                    Colors.grey.shade800,
                    Colors.grey.shade900,
                  ]
                : [
                    Colors.grey.shade50,
                    Colors.white,
                  ],
          ),
          borderRadius: BorderRadius.circular(
            ResponsiveUtils.getResponsiveValue(
              context,
              mobile: 16.0,
              tablet: 18.0,
              desktop: 20.0,
            ),
          ),
          border: Border.all(
            color: isDark ? Colors.grey.shade700 : Colors.grey.shade300,
            width: ResponsiveUtils.getResponsiveValue(
              context,
              mobile: 1.5,
              tablet: 2.0,
              desktop: 2.5,
            ),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: ResponsiveUtils.getResponsiveValue(
                context,
                mobile: 8.0,
                tablet: 10.0,
                desktop: 12.0,
              ),
              offset: Offset(
                0,
                ResponsiveUtils.getResponsiveValue(
                  context,
                  mobile: 2.0,
                  tablet: 3.0,
                  desktop: 4.0,
                ),
              ),
            ),
          ],
        ),
        child: Row(
          children: [
            // Media icon with gradient
            Container(
              width: ResponsiveUtils.getResponsiveValue(
                context,
                mobile: 56.0,
                tablet: 64.0,
                desktop: 72.0,
              ),
              height: ResponsiveUtils.getResponsiveValue(
                context,
                mobile: 56.0,
                tablet: 64.0,
                desktop: 72.0,
              ),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    theme.colorScheme.primary,
                    theme.colorScheme.primary.withValues(alpha: 0.7),
                  ],
                ),
                borderRadius: BorderRadius.circular(
                  ResponsiveUtils.getResponsiveValue(
                    context,
                    mobile: 14.0,
                    tablet: 16.0,
                    desktop: 18.0,
                  ),
                ),
                boxShadow: [
                  BoxShadow(
                    color: theme.colorScheme.primary.withValues(alpha: 0.3),
                    blurRadius: ResponsiveUtils.getResponsiveValue(
                      context,
                      mobile: 8.0,
                      tablet: 10.0,
                      desktop: 12.0,
                    ),
                    offset: Offset(
                      0,
                      ResponsiveUtils.getResponsiveValue(
                        context,
                        mobile: 2.0,
                        tablet: 3.0,
                        desktop: 4.0,
                      ),
                    ),
                  ),
                ],
              ),
              child: Icon(
                _getMediaIcon(media.type),
                color: Colors.white,
                size: ResponsiveUtils.getResponsiveValue(
                  context,
                  mobile: 28.0,
                  tablet: 32.0,
                  desktop: 36.0,
                ),
              ),
            ),
            SizedBox(
              width: ResponsiveUtils.getResponsiveSpacing(context),
            ),
            // Media info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    media.fileName,
                    style: TextStyle(
                      color: isDark ? Colors.white : Colors.black87,
                      fontSize: ResponsiveUtils.getResponsiveFontSize(
                        context,
                        baseSize: 15,
                      ),
                      fontWeight: FontWeight.w700,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  SizedBox(
                    height: ResponsiveUtils.getResponsiveValue(
                      context,
                      mobile: 6.0,
                      tablet: 8.0,
                      desktop: 10.0,
                    ),
                  ),
                  Row(
                    children: [
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: ResponsiveUtils.getResponsiveValue(
                            context,
                            mobile: 8.0,
                            tablet: 10.0,
                            desktop: 12.0,
                          ),
                          vertical: ResponsiveUtils.getResponsiveValue(
                            context,
                            mobile: 4.0,
                            tablet: 5.0,
                            desktop: 6.0,
                          ),
                        ),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primary.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(
                            ResponsiveUtils.getResponsiveValue(
                              context,
                              mobile: 6.0,
                              tablet: 8.0,
                              desktop: 10.0,
                            ),
                          ),
                        ),
                        child: Text(
                          media.type.toUpperCase(),
                          style: TextStyle(
                            color: theme.colorScheme.primary,
                            fontSize: ResponsiveUtils.getResponsiveFontSize(
                              context,
                              baseSize: 10,
                            ),
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                      SizedBox(
                        width: ResponsiveUtils.getResponsiveValue(
                          context,
                          mobile: 8.0,
                          tablet: 10.0,
                          desktop: 12.0,
                        ),
                      ),
                      Icon(
                        Icons.info_outline_rounded,
                        size: ResponsiveUtils.getResponsiveValue(
                          context,
                          mobile: 14.0,
                          tablet: 16.0,
                          desktop: 18.0,
                        ),
                        color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                      ),
                      SizedBox(
                        width: ResponsiveUtils.getResponsiveValue(
                          context,
                          mobile: 4.0,
                          tablet: 6.0,
                          desktop: 8.0,
                        ),
                      ),
                      Text(
                        _formatFileSize(media.optimizedSize),
                        style: TextStyle(
                          color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                          fontSize: ResponsiveUtils.getResponsiveFontSize(
                            context,
                            baseSize: 12,
                          ),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            // Remove button
            Container(
              decoration: BoxDecoration(
                color: isDark ? Colors.grey.shade700 : Colors.grey.shade200,
                shape: BoxShape.circle,
              ),
              child: IconButton(
                onPressed: () {
                  setState(() {
                    _selectedMedia.clear();
                    _captionController.clear();
                    _uploadError = null;
                  });
                },
                icon: Icon(
                  Icons.close_rounded,
                  color: isDark ? Colors.grey.shade300 : Colors.grey.shade700,
                  size: 20,
                ),
                padding: const EdgeInsets.all(8),
                constraints: const BoxConstraints(),
              ),
            ),
          ],
        ),
      );
    }

    // Multiple media: show grid preview
    return Container(
      padding: ResponsiveUtils.getResponsivePadding(context),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? [
                  Colors.grey.shade800,
                  Colors.grey.shade900,
                ]
              : [
                  Colors.grey.shade50,
                  Colors.white,
                ],
        ),
        borderRadius: BorderRadius.circular(
          ResponsiveUtils.getResponsiveValue(
            context,
            mobile: 16.0,
            tablet: 18.0,
            desktop: 20.0,
          ),
        ),
        border: Border.all(
          color: isDark ? Colors.grey.shade700 : Colors.grey.shade300,
          width: ResponsiveUtils.getResponsiveValue(
            context,
            mobile: 1.5,
            tablet: 2.0,
            desktop: 2.5,
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: ResponsiveUtils.getResponsiveValue(
              context,
              mobile: 8.0,
              tablet: 10.0,
              desktop: 12.0,
            ),
            offset: Offset(
              0,
              ResponsiveUtils.getResponsiveValue(
                context,
                mobile: 2.0,
                tablet: 3.0,
                desktop: 4.0,
              ),
            ),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with count and clear button
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(
                  ResponsiveUtils.getResponsiveValue(
                    context,
                    mobile: 6.0,
                    tablet: 8.0,
                    desktop: 10.0,
                  ),
                ),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      theme.colorScheme.primary,
                      theme.colorScheme.primary.withValues(alpha: 0.7),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(
                    ResponsiveUtils.getResponsiveValue(
                      context,
                      mobile: 8.0,
                      tablet: 10.0,
                      desktop: 12.0,
                    ),
                  ),
                ),
                child: Icon(
                  Icons.collections_rounded,
                  color: Colors.white,
                  size: ResponsiveUtils.getResponsiveValue(
                    context,
                    mobile: 18.0,
                    tablet: 20.0,
                    desktop: 22.0,
                  ),
                ),
              ),
              SizedBox(
                width: ResponsiveUtils.getResponsiveValue(
                  context,
                  mobile: 10.0,
                  tablet: 12.0,
                  desktop: 14.0,
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${_selectedMedia.length} ${_selectedMedia.length == 1 ? 'file' : 'files'} selected',
                      style: TextStyle(
                        color: isDark ? Colors.white : Colors.black87,
                        fontSize: ResponsiveUtils.getResponsiveFontSize(
                          context,
                          baseSize: 15,
                        ),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      'Tap to remove any item',
                      style: TextStyle(
                        color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                        fontSize: ResponsiveUtils.getResponsiveFontSize(
                          context,
                          baseSize: 11,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                decoration: BoxDecoration(
                  color: isDark ? Colors.grey.shade700 : Colors.grey.shade200,
                  shape: BoxShape.circle,
                ),
                child: IconButton(
                  onPressed: () {
                    setState(() {
                      _selectedMedia.clear();
                      _captionController.clear();
                      _uploadError = null;
                    });
                  },
                  icon: Icon(
                    Icons.close_rounded,
                    color: isDark ? Colors.grey.shade300 : Colors.grey.shade700,
                    size: ResponsiveUtils.getResponsiveValue(
                      context,
                      mobile: 18.0,
                      tablet: 20.0,
                      desktop: 22.0,
                    ),
                  ),
                  padding: EdgeInsets.all(
                    ResponsiveUtils.getResponsiveValue(
                      context,
                      mobile: 6.0,
                      tablet: 8.0,
                      desktop: 10.0,
                    ),
                  ),
                  constraints: const BoxConstraints(),
                ),
              ),
            ],
          ),
          SizedBox(
            height: ResponsiveUtils.getResponsiveSpacing(context),
          ),
          // Grid of media thumbnails
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: ResponsiveUtils.getResponsiveValue(
                context,
                mobile: 3,
                tablet: 4,
                desktop: 5,
              ),
              crossAxisSpacing: ResponsiveUtils.getResponsiveValue(
                context,
                mobile: 10.0,
                tablet: 12.0,
                desktop: 14.0,
              ),
              mainAxisSpacing: ResponsiveUtils.getResponsiveValue(
                context,
                mobile: 10.0,
                tablet: 12.0,
                desktop: 14.0,
              ),
              childAspectRatio: 1,
            ),
            itemCount: _selectedMedia.length,
            itemBuilder: (context, index) {
              final media = _selectedMedia[index];
              return Stack(
                children: [
                  // Thumbnail with enhanced styling
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      decoration: BoxDecoration(
                        color: isDark ? Colors.grey.shade700 : Colors.grey.shade200,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isDark ? Colors.grey.shade600 : Colors.grey.shade300,
                          width: 1.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.1),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: media.type == 'image'
                          ? Image.memory(
                              media.bytes,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => Container(
                                color: isDark ? Colors.grey.shade800 : Colors.grey.shade100,
                                child: Icon(
                                  _getMediaIcon(media.type),
                                  color: theme.colorScheme.primary,
                                  size: 32,
                                ),
                              ),
                            )
                          : Container(
                              color: isDark ? Colors.grey.shade800 : Colors.grey.shade100,
                              child: Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      _getMediaIcon(media.type),
                                      color: theme.colorScheme.primary,
                                      size: 32,
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      media.type.substring(0, 1).toUpperCase(),
                                      style: TextStyle(
                                        color: theme.colorScheme.primary,
                                        fontSize: 10,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                    ),
                  ),
                  // Remove button with better styling
                  Positioned(
                    top: 6,
                    right: 6,
                    child: GestureDetector(
                      onTap: () {
                        setState(() {
                          _selectedMedia.removeAt(index);
                        });
                      },
                      child: Container(
                        padding: const EdgeInsets.all(5),
                        decoration: BoxDecoration(
                          color: Colors.red,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.3),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.close_rounded,
                          color: Colors.white,
                          size: 14,
                        ),
                      ),
                    ),
                  ),
                  // Index badge for multiple items
                  if (_selectedMedia.length > 1)
                    Positioned(
                      top: 6,
                      left: 6,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.6),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '${index + 1}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
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
    return Container(
      padding: ResponsiveUtils.getResponsivePadding(context),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            theme.colorScheme.primary.withValues(alpha: 0.1),
            theme.colorScheme.primary.withValues(alpha: 0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(
          ResponsiveUtils.getResponsiveValue(
            context,
            mobile: 16.0,
            tablet: 18.0,
            desktop: 20.0,
          ),
        ),
        border: Border.all(
          color: theme.colorScheme.primary.withValues(alpha: 0.3),
          width: ResponsiveUtils.getResponsiveValue(
            context,
            mobile: 1.5,
            tablet: 2.0,
            desktop: 2.5,
          ),
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(
                  ResponsiveUtils.getResponsiveValue(
                    context,
                    mobile: 8.0,
                    tablet: 10.0,
                    desktop: 12.0,
                  ),
                ),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.cloud_upload_rounded,
                  color: theme.colorScheme.primary,
                  size: ResponsiveUtils.getResponsiveIconSize(context),
                ),
              ),
              SizedBox(
                width: ResponsiveUtils.getResponsiveValue(
                  context,
                  mobile: 12.0,
                  tablet: 14.0,
                  desktop: 16.0,
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Uploading media...',
                      style: TextStyle(
                        color: isDark ? Colors.white : Colors.black87,
                        fontSize: ResponsiveUtils.getResponsiveFontSize(
                          context,
                          baseSize: 15,
                        ),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    SizedBox(
                      height: ResponsiveUtils.getResponsiveValue(
                        context,
                        mobile: 2.0,
                        tablet: 4.0,
                        desktop: 6.0,
                      ),
                    ),
                    Text(
                      'Please wait while we upload your files',
                      style: TextStyle(
                        color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                        fontSize: ResponsiveUtils.getResponsiveFontSize(
                          context,
                          baseSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: ResponsiveUtils.getResponsiveValue(
                    context,
                    mobile: 10.0,
                    tablet: 12.0,
                    desktop: 14.0,
                  ),
                  vertical: ResponsiveUtils.getResponsiveValue(
                    context,
                    mobile: 6.0,
                    tablet: 8.0,
                    desktop: 10.0,
                  ),
                ),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(
                    ResponsiveUtils.getResponsiveValue(
                      context,
                      mobile: 8.0,
                      tablet: 10.0,
                      desktop: 12.0,
                    ),
                  ),
                ),
                child: Text(
                  '${(_uploadProgress * 100).toStringAsFixed(0)}%',
                  style: TextStyle(
                    color: theme.colorScheme.primary,
                    fontSize: ResponsiveUtils.getResponsiveFontSize(
                      context,
                      baseSize: 14,
                    ),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(
            height: ResponsiveUtils.getResponsiveValue(
              context,
              mobile: 12.0,
              tablet: 14.0,
              desktop: 16.0,
            ),
          ),
          ClipRRect(
            borderRadius: BorderRadius.circular(
              ResponsiveUtils.getResponsiveValue(
                context,
                mobile: 8.0,
                tablet: 10.0,
                desktop: 12.0,
              ),
            ),
            child: LinearProgressIndicator(
              value: _uploadProgress,
              minHeight: ResponsiveUtils.getResponsiveValue(
                context,
                mobile: 6.0,
                tablet: 7.0,
                desktop: 8.0,
              ),
              backgroundColor: isDark ? Colors.grey.shade700 : Colors.grey.shade300,
              valueColor: AlwaysStoppedAnimation<Color>(theme.colorScheme.primary),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorMessage(ThemeData theme, bool isDark) {
    return Container(
      padding: EdgeInsets.all(
        ResponsiveUtils.getResponsiveValue(
          context,
          mobile: 12.0,
          tablet: 14.0,
          desktop: 16.0,
        ),
      ),
      decoration: BoxDecoration(
        color: isDark ? Colors.red.shade900 : Colors.red.shade50,
        borderRadius: BorderRadius.circular(
          ResponsiveUtils.getResponsiveValue(
            context,
            mobile: 12.0,
            tablet: 14.0,
            desktop: 16.0,
          ),
        ),
        border: Border.all(
          color: isDark ? Colors.red.shade700 : Colors.red.shade200,
          width: ResponsiveUtils.getResponsiveValue(
            context,
            mobile: 1.0,
            tablet: 1.5,
            desktop: 2.0,
          ),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.error_outline,
            color: isDark ? Colors.red.shade300 : Colors.red.shade600,
            size: ResponsiveUtils.getResponsiveIconSize(context),
          ),
          SizedBox(
            width: ResponsiveUtils.getResponsiveValue(
              context,
              mobile: 8.0,
              tablet: 10.0,
              desktop: 12.0,
            ),
          ),
          Expanded(
            child: Text(
              _uploadError!,
              style: TextStyle(
                color: isDark ? Colors.red.shade300 : Colors.red.shade700,
                fontSize: ResponsiveUtils.getResponsiveFontSize(
                  context,
                  baseSize: 14,
                ),
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
          child: OutlinedButton.icon(
            onPressed: _isUploading ? null : () {
              setState(() {
                _selectedMedia.clear();
                _captionController.clear();
                _uploadError = null;
              });
            },
            icon: Icon(
              Icons.close_rounded,
              size: ResponsiveUtils.getResponsiveValue(
                context,
                mobile: 18.0,
                tablet: 20.0,
                desktop: 22.0,
              ),
              color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
            ),
            label: Text(
              'Cancel',
              style: TextStyle(
                color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                fontSize: ResponsiveUtils.getResponsiveFontSize(
                  context,
                  baseSize: 15,
                ),
                fontWeight: FontWeight.w600,
              ),
            ),
            style: OutlinedButton.styleFrom(
              padding: EdgeInsets.symmetric(
                vertical: ResponsiveUtils.getResponsiveButtonHeight(context) * 0.3,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(
                  ResponsiveUtils.getResponsiveValue(
                    context,
                    mobile: 14.0,
                    tablet: 16.0,
                    desktop: 18.0,
                  ),
                ),
              ),
              side: BorderSide(
                color: isDark ? Colors.grey.shade700 : Colors.grey.shade300,
                width: ResponsiveUtils.getResponsiveValue(
                  context,
                  mobile: 1.5,
                  tablet: 2.0,
                  desktop: 2.5,
                ),
              ),
            ),
          ),
        ),
        SizedBox(
          width: ResponsiveUtils.getResponsiveValue(
            context,
            mobile: 12.0,
            tablet: 14.0,
            desktop: 16.0,
          ),
        ),
        Expanded(
          flex: 2,
          child: ElevatedButton.icon(
            onPressed: (_isUploading || _selectedMedia.isEmpty) ? null : _uploadMedia,
            icon: _isUploading
                ? SizedBox(
                    width: ResponsiveUtils.getResponsiveValue(
                      context,
                      mobile: 18.0,
                      tablet: 20.0,
                      desktop: 22.0,
                    ),
                    height: ResponsiveUtils.getResponsiveValue(
                      context,
                      mobile: 18.0,
                      tablet: 20.0,
                      desktop: 22.0,
                    ),
                    child: CircularProgressIndicator(
                      strokeWidth: ResponsiveUtils.getResponsiveValue(
                        context,
                        mobile: 2.5,
                        tablet: 3.0,
                        desktop: 3.5,
                      ),
                      valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : Icon(
                    Icons.send_rounded,
                    size: ResponsiveUtils.getResponsiveValue(
                      context,
                      mobile: 18.0,
                      tablet: 20.0,
                      desktop: 22.0,
                    ),
                    color: Colors.white,
                  ),
            label: Text(
              _isUploading ? 'Sending...' : 'Send ${_selectedMedia.length > 1 ? '(${_selectedMedia.length})' : ''}',
              style: TextStyle(
                fontSize: ResponsiveUtils.getResponsiveFontSize(
                  context,
                  baseSize: 15,
                ),
                fontWeight: FontWeight.w700,
                letterSpacing: 0.3,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: theme.colorScheme.primary,
              foregroundColor: Colors.white,
              padding: EdgeInsets.symmetric(
                vertical: ResponsiveUtils.getResponsiveButtonHeight(context) * 0.3,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(
                  ResponsiveUtils.getResponsiveValue(
                    context,
                    mobile: 14.0,
                    tablet: 16.0,
                    desktop: 18.0,
                  ),
                ),
              ),
              elevation: ResponsiveUtils.getResponsiveValue(
                context,
                mobile: 2.0,
                tablet: 3.0,
                desktop: 4.0,
              ),
              shadowColor: theme.colorScheme.primary.withValues(alpha: 0.4),
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
      // Use pickMultipleVideosFromGallery to open native video gallery (not documents picker)
      final results = await EnhancedUnifiedMediaService.pickMultipleVideosFromGallery(context);
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

  Widget _buildQuickActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
    required ThemeData theme,
  }) {
    final isDark = theme.brightness == Brightness.dark;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(
          ResponsiveUtils.getResponsiveValue(
            context,
            mobile: 10.0,
            tablet: 12.0,
            desktop: 14.0,
          ),
        ),
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: ResponsiveUtils.getResponsiveValue(
              context,
              mobile: 12.0,
              tablet: 14.0,
              desktop: 16.0,
            ),
            vertical: ResponsiveUtils.getResponsiveValue(
              context,
              mobile: 8.0,
              tablet: 10.0,
              desktop: 12.0,
            ),
          ),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(
              ResponsiveUtils.getResponsiveValue(
                context,
                mobile: 10.0,
                tablet: 12.0,
                desktop: 14.0,
              ),
            ),
            border: Border.all(
              color: color.withValues(alpha: 0.3),
              width: ResponsiveUtils.getResponsiveValue(
                context,
                mobile: 1.0,
                tablet: 1.5,
                desktop: 2.0,
              ),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                color: color,
                size: ResponsiveUtils.getResponsiveValue(
                  context,
                  mobile: 18.0,
                  tablet: 20.0,
                  desktop: 22.0,
                ),
              ),
              SizedBox(
                width: ResponsiveUtils.getResponsiveValue(
                  context,
                  mobile: 6.0,
                  tablet: 8.0,
                  desktop: 10.0,
                ),
              ),
              Text(
                label,
                style: TextStyle(
                  color: color,
                  fontSize: ResponsiveUtils.getResponsiveFontSize(
                    context,
                    baseSize: 12,
                  ),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
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
