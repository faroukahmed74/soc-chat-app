import 'package:flutter/material.dart';
import '../utils/responsive_utils.dart';

/// Download state enum
enum DownloadState {
  idle,
  downloading,
  saving,
  completed,
  failed,
}

/// Responsive download progress indicator widget for media downloads
/// Works on all platforms (Android, iOS, Web)
class MediaDownloadProgressIndicator extends StatefulWidget {
  final double progress; // 0.0 to 1.0
  final String? statusMessage;
  final DownloadState state;
  final String? fileName;
  final String? errorMessage;
  final VoidCallback? onCancel;
  final VoidCallback? onRetry;
  final bool showInOverlay; // If true, shows as overlay, if false shows inline

  const MediaDownloadProgressIndicator({
    super.key,
    required this.progress,
    this.statusMessage,
    this.state = DownloadState.downloading,
    this.fileName,
    this.errorMessage,
    this.onCancel,
    this.onRetry,
    this.showInOverlay = false,
  });

  @override
  State<MediaDownloadProgressIndicator> createState() =>
      _MediaDownloadProgressIndicatorState();
}

class _MediaDownloadProgressIndicatorState
    extends State<MediaDownloadProgressIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;
    final isTablet = screenWidth >= 600 && screenWidth < 1024;

    // Responsive sizing
    final fontSize = ResponsiveUtils.getResponsiveFontSize(context, baseSize: 14.0);
    final smallFontSize = ResponsiveUtils.getResponsiveFontSize(context, baseSize: 12.0);
    final iconSize = ResponsiveUtils.getResponsiveIconSize(context);
    final spacing = ResponsiveUtils.getResponsiveSpacing(context);

    if (widget.showInOverlay) {
      return _buildOverlayIndicator(context, theme, isDark, isMobile, isTablet, fontSize, smallFontSize, iconSize, spacing);
    } else {
      return _buildInlineIndicator(context, theme, isDark, isMobile, isTablet, fontSize, smallFontSize, iconSize, spacing);
    }
  }

  Widget _buildOverlayIndicator(
    BuildContext context,
    ThemeData theme,
    bool isDark,
    bool isMobile,
    bool isTablet,
    double fontSize,
    double smallFontSize,
    double iconSize,
    double spacing,
  ) {
    final maxWidth = ResponsiveUtils.getResponsiveValue(
      context,
      mobile: MediaQuery.of(context).size.width * 0.85,
      tablet: 400.0,
      desktop: 500.0,
    );

    return FadeTransition(
      opacity: _fadeAnimation,
      child: Material(
        color: Colors.transparent,
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: maxWidth,
            ),
            child: Container(
              padding: EdgeInsets.all(spacing),
              decoration: BoxDecoration(
                color: isDark ? Colors.grey[900]!.withOpacity(0.95) : Colors.white.withOpacity(0.95),
                borderRadius: BorderRadius.circular(
                  ResponsiveUtils.getResponsiveValue(
                    context,
                    mobile: 12.0,
                    tablet: 16.0,
                    desktop: 20.0,
                  ),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
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
                        mobile: 4.0,
                        tablet: 4.0,
                        desktop: 6.0,
                      ),
                    ),
                  ),
                ],
              ),
              child: _buildContent(context, theme, isDark, isMobile, isTablet, fontSize, smallFontSize, iconSize, spacing),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInlineIndicator(
    BuildContext context,
    ThemeData theme,
    bool isDark,
    bool isMobile,
    bool isTablet,
    double fontSize,
    double smallFontSize,
    double iconSize,
    double spacing,
  ) {
    return Container(
      padding: ResponsiveUtils.getResponsivePadding(context) * 0.75,
      decoration: BoxDecoration(
        color: isDark ? Colors.grey[800] : Colors.grey[100],
        borderRadius: BorderRadius.circular(
          ResponsiveUtils.getResponsiveValue(
            context,
            mobile: 8.0,
            tablet: 10.0,
            desktop: 12.0,
          ),
        ),
      ),
      child: _buildContent(context, theme, isDark, isMobile, isTablet, fontSize, smallFontSize, iconSize, spacing),
    );
  }

  Widget _buildContent(
    BuildContext context,
    ThemeData theme,
    bool isDark,
    bool isMobile,
    bool isTablet,
    double fontSize,
    double smallFontSize,
    double iconSize,
    double spacing,
  ) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header with icon and title
        Row(
          children: [
            _buildStateIcon(iconSize, isDark),
            SizedBox(width: spacing * 0.5),
            Expanded(
              child: Text(
                _getTitle(),
                style: TextStyle(
                  fontSize: fontSize,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
            ),
            if (widget.state == DownloadState.downloading && widget.onCancel != null)
              IconButton(
                icon: Icon(Icons.close, size: iconSize * 0.8),
                onPressed: widget.onCancel,
                tooltip: 'Cancel',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
          ],
        ),
        SizedBox(height: spacing * 0.5),
        
        // File name if provided
        if (widget.fileName != null) ...[
          Text(
            widget.fileName!,
            style: TextStyle(
              fontSize: smallFontSize,
              color: isDark ? Colors.white70 : Colors.black54,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          SizedBox(height: spacing * 0.25),
        ],
        
        // Progress bar (only show when downloading or saving)
        if (widget.state == DownloadState.downloading || widget.state == DownloadState.saving) ...[
          ClipRRect(
            borderRadius: BorderRadius.circular(
              ResponsiveUtils.getResponsiveValue(
                context,
                mobile: 4.0,
                tablet: 6.0,
                desktop: 8.0,
              ),
            ),
            child: LinearProgressIndicator(
              value: widget.progress,
              backgroundColor: isDark ? Colors.grey[700] : Colors.grey[300],
              valueColor: AlwaysStoppedAnimation<Color>(
                widget.state == DownloadState.saving
                    ? Colors.orange
                    : theme.primaryColor,
              ),
              minHeight: ResponsiveUtils.getResponsiveValue(
                context,
                mobile: 6.0,
                tablet: 8.0,
                desktop: 10.0,
              ),
            ),
          ),
          SizedBox(height: spacing * 0.25),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${(widget.progress * 100).toStringAsFixed(1)}%',
                style: TextStyle(
                  fontSize: smallFontSize,
                  fontWeight: FontWeight.w500,
                  color: isDark ? Colors.white70 : Colors.black54,
                ),
              ),
              if (widget.statusMessage != null)
                Expanded(
                  child: Text(
                    widget.statusMessage!,
                    style: TextStyle(
                      fontSize: smallFontSize * 0.9,
                      color: isDark ? Colors.white60 : Colors.black45,
                    ),
                    textAlign: TextAlign.end,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
            ],
          ),
        ],
        
        // Status message for other states
        if (widget.state != DownloadState.downloading && widget.state != DownloadState.saving) ...[
          if (widget.statusMessage != null)
            Text(
              widget.statusMessage!,
              style: TextStyle(
                fontSize: smallFontSize,
                color: _getStatusColor(isDark),
              ),
            ),
        ],
        
        // Error message
        if (widget.state == DownloadState.failed && widget.errorMessage != null) ...[
          SizedBox(height: spacing * 0.25),
          Text(
            widget.errorMessage!,
            style: TextStyle(
              fontSize: smallFontSize,
              color: Colors.red,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
        
        // Retry button for failed state
        if (widget.state == DownloadState.failed && widget.onRetry != null) ...[
          SizedBox(height: spacing * 0.5),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: widget.onRetry,
              icon: Icon(
                Icons.refresh,
                size: iconSize * 0.8,
              ),
              label: Text(
                'Retry',
                style: TextStyle(fontSize: smallFontSize),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.primaryColor,
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(
                  horizontal: spacing,
                  vertical: spacing * 0.5,
                ),
                minimumSize: Size(
                  double.infinity,
                  ResponsiveUtils.getResponsiveButtonHeight(context),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildStateIcon(double iconSize, bool isDark) {
    switch (widget.state) {
      case DownloadState.downloading:
      case DownloadState.saving:
        return SizedBox(
          width: iconSize,
          height: iconSize,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            value: widget.state == DownloadState.downloading ? widget.progress : null,
            valueColor: AlwaysStoppedAnimation<Color>(
              widget.state == DownloadState.saving ? Colors.orange : Colors.blue,
            ),
          ),
        );
      case DownloadState.completed:
        return Icon(
          Icons.check_circle,
          color: Colors.green,
          size: iconSize,
        );
      case DownloadState.failed:
        return Icon(
          Icons.error,
          color: Colors.red,
          size: iconSize,
        );
      case DownloadState.idle:
        return Icon(
          Icons.download,
          color: isDark ? Colors.white70 : Colors.black54,
          size: iconSize,
        );
    }
  }

  String _getTitle() {
    switch (widget.state) {
      case DownloadState.downloading:
        return 'Downloading...';
      case DownloadState.saving:
        return 'Saving...';
      case DownloadState.completed:
        return 'Download Complete';
      case DownloadState.failed:
        return 'Download Failed';
      case DownloadState.idle:
        return 'Ready to Download';
    }
  }

  Color _getStatusColor(bool isDark) {
    switch (widget.state) {
      case DownloadState.completed:
        return Colors.green;
      case DownloadState.failed:
        return Colors.red;
      default:
        return isDark ? Colors.white70 : Colors.black54;
    }
  }
}

/// Overlay widget to show download progress on top of media
class MediaDownloadOverlay extends StatelessWidget {
  final double progress;
  final String? statusMessage;
  final DownloadState state;
  final VoidCallback? onCancel;

  const MediaDownloadOverlay({
    super.key,
    required this.progress,
    this.statusMessage,
    this.state = DownloadState.downloading,
    this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: Container(
        color: Colors.black.withOpacity(0.7),
        child: Center(
          child: MediaDownloadProgressIndicator(
            progress: progress,
            statusMessage: statusMessage,
            state: state,
            showInOverlay: true,
            onCancel: onCancel,
          ),
        ),
      ),
    );
  }
}

