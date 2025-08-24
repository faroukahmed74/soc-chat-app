// =============================================================================
// APP LOGO WIDGET
// =============================================================================
// This widget displays the SOC Chat App logo in various sizes and styles.
// It can be used in app bars, loading screens, and other UI elements.

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

  const AppLogo({
    super.key,
    this.size = 80,
    this.showBackground = true,
    this.showAppName = false,
    this.appNameStyle,
    this.showSubtitle = false,
    this.subtitleStyle,
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
                  child: _buildLogoSvg(),
                )
              : _buildLogoSvg(),
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

  /// Builds the SVG logo as a CustomPaint widget
  Widget _buildLogoSvg() {
    return CustomPaint(
      size: Size(size, size),
      painter: _LogoPainter(),
    );
  }
}

/// Custom painter for drawing the SOC Chat App logo
class _LogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;

    final scale = size.width / 80; // Base size is 80x80
    
    // Draw chat bubble background
    paint.color = const Color(0xFF667eea);
    final bubbleRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(
        size.width * 0.25, // 20/80
        size.height * 0.125, // 10/80
        size.width * 0.5, // 40/80
        size.height * 0.625, // 50/80
      ),
      Radius.circular(scale * 2),
    );
    canvas.drawRRect(bubbleRect, paint);
    
    // Draw chat bubble tail
    final tailPath = Path()
      ..moveTo(size.width * 0.25, size.height * 0.75) // 20/80, 60/80
      ..lineTo(size.width * 0.4375, size.height * 0.875) // 35/80, 70/80
      ..lineTo(size.width * 0.4375, size.height * 0.75) // 35/80, 60/80
      ..close();
    canvas.drawPath(tailPath, paint);
    
    // Draw message lines
    paint.color = Colors.white;
    
    // Line 1 (longest)
    final line1Rect = RRect.fromRectAndRadius(
      Rect.fromLTWH(
        size.width * 0.35, // 28/80
        size.height * 0.25, // 20/80
        size.width * 0.3, // 24/80
        size.height * 0.0375, // 3/80
      ),
      Radius.circular(scale * 0.75),
    );
    canvas.drawRRect(line1Rect, paint);
    
    // Line 2 (medium)
    final line2Rect = RRect.fromRectAndRadius(
      Rect.fromLTWH(
        size.width * 0.35, // 28/80
        size.height * 0.35, // 28/80
        size.width * 0.25, // 20/80
        size.height * 0.0375, // 3/80
      ),
      Radius.circular(scale * 0.75),
    );
    canvas.drawRRect(line2Rect, paint);
    
    // Line 3 (shortest)
    final line3Rect = RRect.fromRectAndRadius(
      Rect.fromLTWH(
        size.width * 0.35, // 28/80
        size.height * 0.45, // 36/80
        size.width * 0.2, // 16/80
        size.height * 0.0375, // 3/80
      ),
      Radius.circular(scale * 0.75),
    );
    canvas.drawRRect(line3Rect, paint);
    
    // Draw connection dots
    paint.color = const Color(0xFF764ba2);
    
    // Dot 1
    canvas.drawCircle(
      Offset(size.width * 0.75, size.height * 0.25), // 60/80, 20/80
      scale * 2,
      paint,
    );
    
    // Dot 2
    canvas.drawCircle(
      Offset(size.width * 0.75, size.height * 0.375), // 60/80, 30/80
      scale * 2,
      paint,
    );
    
    // Dot 3
    canvas.drawCircle(
      Offset(size.width * 0.75, size.height * 0.5), // 60/80, 40/80
      scale * 2,
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Alternative logo widget that shows just the icon without background
class AppLogoIcon extends StatelessWidget {
  /// Size of the logo icon
  final double size;
  
  /// Color of the logo (defaults to primary color)
  final Color? color;

  const AppLogoIcon({
    super.key,
    this.size = 24,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(size, size),
      painter: _LogoIconPainter(color ?? Theme.of(context).colorScheme.primary),
    );
  }
}

/// Custom painter for the logo icon (simplified version)
class _LogoIconPainter extends CustomPainter {
  final Color color;

  _LogoIconPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.fill
      ..color = color
      ..isAntiAlias = true;

    final scale = size.width / 24; // Base size is 24x24
    
    // Draw chat bubble
    final bubbleRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(
        size.width * 0.25, // 6/24
        size.height * 0.25, // 6/24
        size.width * 0.5, // 12/24
        size.height * 0.5, // 12/24
      ),
      Radius.circular(scale * 1),
    );
    canvas.drawRRect(bubbleRect, paint);
    
    // Draw chat bubble tail
    final tailPath = Path()
      ..moveTo(size.width * 0.25, size.height * 0.75) // 6/24, 18/24
      ..lineTo(size.width * 0.4167, size.height * 0.875) // 10/24, 21/24
      ..lineTo(size.width * 0.4167, size.height * 0.75) // 10/24, 18/24
      ..close();
    canvas.drawPath(tailPath, paint);
    
    // Draw message lines
    paint.color = Colors.white;
    
    // Line 1
    final line1Rect = RRect.fromRectAndRadius(
      Rect.fromLTWH(
        size.width * 0.333, // 8/24
        size.height * 0.333, // 8/24
        size.width * 0.333, // 8/24
        size.height * 0.083, // 2/24
      ),
      Radius.circular(scale * 0.5),
    );
    canvas.drawRRect(line1Rect, paint);
    
    // Line 2
    final line2Rect = RRect.fromRectAndRadius(
      Rect.fromLTWH(
        size.width * 0.333, // 8/24
        size.height * 0.5, // 12/24
        size.width * 0.25, // 6/24
        size.height * 0.083, // 2/24
      ),
      Radius.circular(scale * 0.5),
    );
    canvas.drawRRect(line2Rect, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
