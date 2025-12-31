import 'package:flutter/material.dart';
import '../utils/responsive_utils.dart';

/// WhatsApp-style circular download progress indicator
/// Appears inline on media items
class WhatsAppDownloadIndicator extends StatelessWidget {
  final double progress; // 0.0 to 1.0
  final String? statusMessage;
  final VoidCallback? onCancel;

  const WhatsAppDownloadIndicator({
    super.key,
    required this.progress,
    this.statusMessage,
    this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final iconSize = ResponsiveUtils.getResponsiveIconSize(context) * 1.5;

    return Container(
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.7),
        shape: BoxShape.circle,
      ),
      padding: EdgeInsets.all(ResponsiveUtils.getResponsiveSpacing(context) * 0.5),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Circular progress indicator
          SizedBox(
            width: iconSize,
            height: iconSize,
            child: CircularProgressIndicator(
              value: progress,
              strokeWidth: 3.0,
              backgroundColor: Colors.white.withOpacity(0.3),
              valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
            ),
          ),
          // Percentage text in center
          if (progress > 0 && progress < 1.0)
            Text(
              '${(progress * 100).toStringAsFixed(0)}%',
              style: TextStyle(
                color: Colors.white,
                fontSize: ResponsiveUtils.getResponsiveFontSize(context, baseSize: 10),
                fontWeight: FontWeight.bold,
              ),
            ),
          // Download icon when completed
          if (progress >= 1.0)
            const Icon(
              Icons.check,
              color: Colors.white,
              size: 16,
            ),
          // Cancel button overlay
          if (onCancel != null && progress < 1.0)
            Positioned.fill(
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: onCancel,
                  borderRadius: BorderRadius.circular(iconSize / 2),
                  child: Container(
                    alignment: Alignment.center,
                    child: Icon(
                      Icons.close,
                      color: Colors.white.withOpacity(0.8),
                      size: iconSize * 0.4,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

