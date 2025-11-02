import 'package:flutter/material.dart';

/// Stub implementation of WebPdfThumbnail for non-web platforms.
/// This widget will not be used on mobile, but provides a placeholder
/// to satisfy conditional imports.
class WebPdfThumbnailImplementation extends StatelessWidget {
  final String url;
  final double width;
  final double height;
  final BorderRadius borderRadius;
  final VoidCallback? onTap;

  const WebPdfThumbnailImplementation({
    super.key,
    required this.url,
    required this.width,
    required this.height,
    this.borderRadius = const BorderRadius.all(Radius.circular(12)),
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: Colors.grey[200],
          borderRadius: borderRadius,
        ),
        child: Center(
          child: Icon(Icons.picture_as_pdf, color: Colors.red, size: height * 0.5),
        ),
      ),
    );
  }
}
