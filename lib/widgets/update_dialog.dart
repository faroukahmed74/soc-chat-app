import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import '../services/version_check_service.dart';
import '../services/fixed_version_check_service.dart';
import '../utils/responsive_utils.dart';
import 'download_progress_dialog.dart';

class UpdateDialog extends StatelessWidget {
  final Map<String, dynamic> updateInfo;
  final VoidCallback? onDismiss;

  const UpdateDialog({
    super.key,
    required this.updateInfo,
    this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    // Only show on Android
    if (!kIsWeb && defaultTargetPlatform != TargetPlatform.android) {
      return const SizedBox.shrink();
    }

    // Responsive sizing
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;
    final isTablet = screenWidth >= 600 && screenWidth < 900;
    
    // Responsive dialog width
    final dialogWidth = ResponsiveUtils.getResponsiveValue(
      context,
      mobile: screenWidth * 0.9, // 90% on mobile
      tablet: 500.0,              // Fixed 500px on tablet
      desktop: 600.0,             // Fixed 600px on desktop
    );
    
    // Responsive icon size
    final iconSize = ResponsiveUtils.getResponsiveIconSize(context) + 8;
    
    // Responsive font sizes
    final titleFontSize = ResponsiveUtils.getResponsiveFontSize(
      context,
      baseSize: 20.0,
    );
    final bodyFontSize = ResponsiveUtils.getResponsiveFontSize(
      context,
      baseSize: 16.0,
    );
    final notesFontSize = ResponsiveUtils.getResponsiveFontSize(
      context,
      baseSize: 14.0,
    );

    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: dialogWidth,
          maxHeight: MediaQuery.of(context).size.height * 0.8,
        ),
        child: Padding(
          padding: ResponsiveUtils.getResponsivePadding(context),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Title
              Row(
                children: [
                  Icon(
                    Icons.system_update,
                    color: Theme.of(context).primaryColor,
                    size: iconSize,
                  ),
                  SizedBox(width: ResponsiveUtils.getResponsiveSpacing(context)),
                  Expanded(
                    child: Text(
                      'Update Available',
                      style: TextStyle(
                        fontSize: titleFontSize,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: ResponsiveUtils.getResponsiveSpacing(context)),
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'A new version of ${updateInfo['appName'] ?? 'SOC Chat App'} is available!',
                        style: TextStyle(
                          fontSize: bodyFontSize,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      SizedBox(height: ResponsiveUtils.getResponsiveSpacing(context)),
                      _buildVersionInfo(updateInfo, context),
                      SizedBox(height: ResponsiveUtils.getResponsiveSpacing(context)),
                      if (updateInfo['releaseNotes'] != null) ...[
                        Text(
                          'What\'s New:',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: bodyFontSize,
                          ),
                        ),
                        SizedBox(height: ResponsiveUtils.getResponsiveSpacing(context) * 0.5),
                        Text(
                          updateInfo['releaseNotes'],
                          style: TextStyle(fontSize: notesFontSize),
                        ),
                        SizedBox(height: ResponsiveUtils.getResponsiveSpacing(context)),
                      ],
                      if (updateInfo['forceUpdate'] == true)
                        Container(
                          padding: ResponsiveUtils.getResponsivePadding(context).copyWith(
                            left: 12,
                            right: 12,
                            top: 12,
                            bottom: 12,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.orange.shade100,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.orange.shade300),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.warning,
                                color: Colors.orange.shade700,
                                size: ResponsiveUtils.getResponsiveIconSize(context),
                              ),
                              SizedBox(width: ResponsiveUtils.getResponsiveSpacing(context) * 0.5),
                              Expanded(
                                child: Text(
                                  'This update is required to continue using the app.',
                                  style: TextStyle(
                                    color: Colors.orange.shade700,
                                    fontWeight: FontWeight.w500,
                                    fontSize: notesFontSize,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              SizedBox(height: ResponsiveUtils.getResponsiveSpacing(context)),
              // Actions - Responsive button layout
              Wrap(
                spacing: ResponsiveUtils.getResponsiveSpacing(context) * 0.5,
                runSpacing: ResponsiveUtils.getResponsiveSpacing(context) * 0.5,
                alignment: WrapAlignment.end,
                children: [
                  // Only show "Later" button if update is not forced
                  if (updateInfo['forceUpdate'] != true)
                    SizedBox(
                      width: isMobile ? double.infinity : null,
                      child: TextButton(
                        onPressed: () {
                          Navigator.of(context).pop();
                          onDismiss?.call();
                        },
                        child: Text(
                          'Later',
                          style: TextStyle(
                            fontSize: bodyFontSize,
                          ),
                        ),
                      ),
                  ),
                  // Primary action: Download Update
                  SizedBox(
                    width: isMobile ? double.infinity : null,
                    child: ElevatedButton.icon(
                      onPressed: () => _downloadUpdate(context),
                      icon: Icon(
                        Icons.download,
                        size: ResponsiveUtils.getResponsiveIconSize(context),
                      ),
                      label: Text(
                        'Download Update',
                        style: TextStyle(
                          fontSize: bodyFontSize,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Theme.of(context).primaryColor,
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.symmetric(
                          horizontal: ResponsiveUtils.getResponsiveSpacing(context),
                          vertical: ResponsiveUtils.getResponsiveSpacing(context) * 0.75,
                        ),
                        minimumSize: Size(
                          isMobile ? double.infinity : 0,
                          ResponsiveUtils.getResponsiveButtonHeight(context),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildVersionInfo(Map<String, dynamic> updateInfo, BuildContext context) {
    final fontSize = ResponsiveUtils.getResponsiveFontSize(
      context,
      baseSize: 14.0,
    );
    
    return Container(
      padding: ResponsiveUtils.getResponsivePadding(context).copyWith(
        left: 12,
        right: 12,
        top: 12,
        bottom: 12,
      ),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Current Version:',
                style: TextStyle(fontSize: fontSize),
              ),
              Flexible(
                child: Text(
                  '${updateInfo['currentVersion']} (${updateInfo['currentBuildNumber']})',
                  style: TextStyle(
                    fontWeight: FontWeight.w500,
                    fontSize: fontSize,
                  ),
                  textAlign: TextAlign.end,
                ),
              ),
            ],
          ),
          SizedBox(height: ResponsiveUtils.getResponsiveSpacing(context) * 0.5),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Latest Version:',
                style: TextStyle(fontSize: fontSize),
              ),
              Flexible(
                child: Text(
                  '${updateInfo['latestVersion']} (${updateInfo['latestBuildNumber']})',
                  style: TextStyle(
                    fontWeight: FontWeight.w500,
                    color: Colors.green,
                    fontSize: fontSize,
                  ),
                  textAlign: TextAlign.end,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _downloadUpdate(BuildContext context) async {
    Navigator.of(context).pop(); // Close update dialog
    
    // Show download progress dialog
    showDialog(
      context: context,
      barrierDismissible: false, // Prevent dismissing during download
      builder: (dialogContext) => _DownloadProgressHandler(
        downloadUrl: updateInfo['downloadUrl'],
        context: context,
      ),
    );
  }
}

/// Widget to handle download progress and show progress dialog
class _DownloadProgressHandler extends StatefulWidget {
  final String downloadUrl;
  final BuildContext context;

  const _DownloadProgressHandler({
    required this.downloadUrl,
    required this.context,
  });

  @override
  State<_DownloadProgressHandler> createState() => _DownloadProgressHandlerState();
}

class _DownloadProgressHandlerState extends State<_DownloadProgressHandler> {
  double _progress = 0.0;
  String? _statusMessage;
  bool _isDownloading = true;
  bool _hasError = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _startDownload();
  }

  Future<void> _startDownload() async {
    try {
      setState(() {
        _isDownloading = true;
        _hasError = false;
        _progress = 0.0;
        _statusMessage = 'Preparing download...';
      });

      final success = await FixedVersionCheckService.downloadAndInstallUpdate(
        widget.downloadUrl,
        widget.context,
        onProgress: (progress, statusMessage) {
          if (mounted) {
            setState(() {
              _progress = progress;
              _statusMessage = statusMessage;
            });
          }
        },
        maxRetries: 3,
      );

      if (mounted) {
        if (success) {
          setState(() {
            _isDownloading = false;
            _hasError = false;
            _progress = 1.0;
            _statusMessage = 'Installation started!';
          });
          
          // Close dialog after 2 seconds
          Future.delayed(const Duration(seconds: 2), () {
            if (mounted) {
              Navigator.of(context).pop();
            }
          });
        } else {
          setState(() {
            _isDownloading = false;
            _hasError = true;
            _errorMessage = 'Download failed. Please try again.';
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isDownloading = false;
          _hasError = true;
          _errorMessage = 'Error: $e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return DownloadProgressDialog(
      progress: _progress,
      statusMessage: _statusMessage,
      isDownloading: _isDownloading,
      hasError: _hasError,
      errorMessage: _errorMessage,
      onRetry: _hasError ? _startDownload : null,
      onCancel: _isDownloading
          ? () {
              // Cancel download (would need to implement cancellation in service)
              Navigator.of(context).pop();
            }
          : null,
    );
  }
}
