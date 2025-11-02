import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'web_pdf_thumbnail_web.dart' if (dart.library.io) 'web_pdf_thumbnail_stub.dart';

/// PDF thumbnail widget that conditionally uses web or stub implementation
class WebPdfThumbnail extends StatelessWidget {
  final String url;
  final double width;
  final double height;
  final BorderRadius borderRadius;
  final VoidCallback? onTap;

  const WebPdfThumbnail({
    super.key,
    required this.url,
    required this.width,
    required this.height,
    this.borderRadius = const BorderRadius.all(Radius.circular(12)),
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    // Use conditional import - web_pdf_thumbnail_web.dart on web, stub on mobile
    return WebPdfThumbnailImplementation(
      url: url,
      width: width,
      height: height,
      borderRadius: borderRadius,
      onTap: onTap,
    );
  }
}