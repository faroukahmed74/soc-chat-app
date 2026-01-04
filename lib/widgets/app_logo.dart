// =============================================================================
// APP LOGO WIDGET
// =============================================================================
// This widget displays the SOC Chat App logo in various sizes and styles.
// It can be used in app bars, loading screens, and other UI elements.
// Uses the actual SOCLogo.png image from assets.

import 'package:flutter/material.dart';

class AppLogo extends StatelessWidget {
  /// Size of the logo (width and height will be the same)
  final double size;
  
  /// Whether to show the logo with a background circle
  final bool showBackground;
  
  /// Whether to show the app name below the logo
  final bool showAppName;
  
  /// Text style for the app name
  final TextStyle? appNameStyle;
  
  /// Whether to show the subtitle
  final bool showSubtitle;
  
  /// Text style for the subtitle
  final TextStyle? subtitleStyle;
  
  /// BoxFit for the logo image
  final BoxFit fit;

  const AppLogo({
    super.key,
    this.size = 80,
    this.showBackground = false,
    this.showAppName = false,
    this.appNameStyle,
    this.showSubtitle = false,
    this.subtitleStyle,
    this.fit = BoxFit.contain,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Logo container
        Container(
          width: size,
          height: size,
          decoration: showBackground ? BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(size * 0.2),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: size * 0.1,
                offset: Offset(0, size * 0.05),
              ),
            ],
          ) : null,
          child: showBackground
              ? Padding(
                  padding: EdgeInsets.all(size * 0.15),
                  child: _buildLogoImage(),
                )
              : ClipRRect(
                borderRadius: BorderRadius.circular(size * 0.2),
                child: _buildLogoImage(),
              ),
        ),
        
        // App name (if requested)
        if (showAppName) ...[
          SizedBox(height: size * 0.2),
          Text(
            'SOC Chat App',
            style: appNameStyle ?? TextStyle(
              fontSize: size * 0.25,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
        ],
        
        // Subtitle (if requested)
        if (showSubtitle) ...[
          SizedBox(height: size * 0.1),
          Text(
            'Secure messaging for friends and groups',
            style: subtitleStyle ?? TextStyle(
              fontSize: size * 0.15,
              color: Colors.grey.shade600,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ],
    );
  }

  /// Builds the logo using the actual PNG image
  Widget _buildLogoImage() {
    return Image.asset(
      'assets/logo/SOCLogo.png',
      width: size,
      height: size,
      fit: fit,
      errorBuilder: (context, error, stackTrace) {
        // Fallback to a simple icon if image fails to load
        return Icon(
          Icons.chat_bubble,
          size: size * 0.7,
          color: Colors.grey,
        );
      },
    );
  }
}

/// Alternative logo widget that shows just the icon without background
class AppLogoIcon extends StatelessWidget {
  /// Size of the logo icon
  final double size;
  
  /// BoxFit for the logo image
  final BoxFit fit;

  const AppLogoIcon({
    super.key,
    this.size = 24,
    this.fit = BoxFit.contain,
  });

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'assets/logo/SOCLogo.png',
      width: size,
      height: size,
      fit: fit,
      errorBuilder: (context, error, stackTrace) {
        // Fallback to a simple icon if image fails to load
        return Icon(
          Icons.chat_bubble,
          size: size,
          color: Theme.of(context).colorScheme.primary,
        );
      },
    );
  }
}
