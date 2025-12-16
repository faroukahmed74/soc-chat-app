import 'package:flutter/material.dart';
import '../utils/responsive_utils.dart';

/// Dialog showing download progress for APK updates
class DownloadProgressDialog extends StatelessWidget {
  final double progress; // 0.0 to 1.0
  final String? statusMessage;
  final bool isDownloading;
  final bool hasError;
  final String? errorMessage;
  final VoidCallback? onRetry;
  final VoidCallback? onCancel;

  const DownloadProgressDialog({
    super.key,
    required this.progress,
    this.statusMessage,
    this.isDownloading = true,
    this.hasError = false,
    this.errorMessage,
    this.onRetry,
    this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    // Responsive sizing
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;
    
    // Responsive dialog width
    final dialogWidth = ResponsiveUtils.getResponsiveValue(
      context,
      mobile: screenWidth * 0.9, // 90% on mobile
      tablet: 400.0,              // Fixed 400px on tablet
      desktop: 500.0,             // Fixed 500px on desktop
    );
    
    // Responsive font sizes
    final titleFontSize = ResponsiveUtils.getResponsiveFontSize(
      context,
      baseSize: 18.0,
    );
    final percentageFontSize = ResponsiveUtils.getResponsiveFontSize(
      context,
      baseSize: 18.0,
    );
    final statusFontSize = ResponsiveUtils.getResponsiveFontSize(
      context,
      baseSize: 12.0,
    );
    final bodyFontSize = ResponsiveUtils.getResponsiveFontSize(
      context,
      baseSize: 14.0,
    );
    
    // Responsive icon sizes
    final smallIconSize = ResponsiveUtils.getResponsiveIconSize(context);
    final largeIconSize = ResponsiveUtils.getResponsiveValue(
      context,
      mobile: 40.0,
      tablet: 48.0,
      desktop: 56.0,
    );

    return PopScope(
      canPop: !isDownloading && !hasError, // Only allow dismiss if not downloading and no error
      child: Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: dialogWidth,
            maxHeight: MediaQuery.of(context).size.height * 0.6,
          ),
          child: Padding(
            padding: ResponsiveUtils.getResponsivePadding(context),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Title
                Row(
                  children: [
                    if (isDownloading)
                      SizedBox(
                        width: smallIconSize,
                        height: smallIconSize,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    else if (hasError)
                      Icon(Icons.error, color: Colors.red.shade700, size: smallIconSize)
                    else
                      Icon(Icons.check_circle, color: Colors.green.shade700, size: smallIconSize),
                    SizedBox(width: ResponsiveUtils.getResponsiveSpacing(context)),
                    Expanded(
                      child: Text(
                        isDownloading
                            ? 'Downloading Update'
                            : hasError
                                ? 'Download Failed'
                                : 'Download Complete',
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
                      children: [
                        if (isDownloading) ...[
                          LinearProgressIndicator(
                            value: progress,
                            backgroundColor: Colors.grey.shade300,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Theme.of(context).primaryColor,
                            ),
                          ),
                          SizedBox(height: ResponsiveUtils.getResponsiveSpacing(context)),
                          Text(
                            '${(progress * 100).toStringAsFixed(1)}%',
                            style: TextStyle(
                              fontSize: percentageFontSize,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          if (statusMessage != null) ...[
                            SizedBox(height: ResponsiveUtils.getResponsiveSpacing(context) * 0.5),
                            Text(
                              statusMessage!,
                              style: TextStyle(
                                fontSize: statusFontSize,
                                color: Colors.grey.shade600,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ] else if (hasError) ...[
                          Icon(
                            Icons.error_outline,
                            color: Colors.red.shade700,
                            size: largeIconSize,
                          ),
                          SizedBox(height: ResponsiveUtils.getResponsiveSpacing(context)),
                          Text(
                            errorMessage ?? 'Download failed. Please try again.',
                            style: TextStyle(fontSize: bodyFontSize),
                            textAlign: TextAlign.center,
                          ),
                        ] else ...[
                          Icon(
                            Icons.check_circle_outline,
                            color: Colors.green.shade700,
                            size: largeIconSize,
                          ),
                          SizedBox(height: ResponsiveUtils.getResponsiveSpacing(context)),
                          Text(
                            'Update downloaded successfully!\nPreparing installation...',
                            style: TextStyle(fontSize: bodyFontSize),
                            textAlign: TextAlign.center,
                          ),
                        ],
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
                    if (isDownloading && onCancel != null)
                      SizedBox(
                        width: isMobile ? double.infinity : null,
                        child: TextButton(
                          onPressed: onCancel,
                          child: Text(
                            'Cancel',
                            style: TextStyle(fontSize: bodyFontSize),
                          ),
                        ),
                      ),
                    if (hasError && onRetry != null)
                      SizedBox(
                        width: isMobile ? double.infinity : null,
                        child: ElevatedButton.icon(
                          onPressed: onRetry,
                          icon: Icon(
                            Icons.refresh,
                            size: ResponsiveUtils.getResponsiveIconSize(context),
                          ),
                          label: Text(
                            'Retry',
                            style: TextStyle(fontSize: bodyFontSize),
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
      ),
    );
  }
}

