import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'dart:ui' as ui;
import 'dart:html' as html;

class WebPdfThumbnail extends StatefulWidget {
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
  State<WebPdfThumbnail> createState() => _WebPdfThumbnailState();
}

class _WebPdfThumbnailState extends State<WebPdfThumbnail> {
  late final String _viewType;

  @override
  void initState() {
    super.initState();
    _viewType = 'web-pdf-thumb-${widget.url.hashCode}-${DateTime.now().microsecondsSinceEpoch}';
    // Register a platform view that embeds an iframe displaying the PDF
    // Pointer events are disabled to make it behave like a static thumbnail.
    ui.platformViewRegistry.registerViewFactory(_viewType, (int viewId) {
      final iframe = html.IFrameElement()
        ..src = widget.url
        ..style.border = 'none'
        ..style.pointerEvents = 'none'
        ..style.width = '100%'
        ..style.height = '100%';
      iframe.setAttribute('sandbox', 'allow-same-origin allow-scripts');
      iframe.setAttribute('scrolling', 'no');
      return iframe;
    });
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: widget.borderRadius,
      child: GestureDetector(
        onTap: widget.onTap,
        child: SizedBox(
          width: widget.width,
          height: widget.height,
          child: HtmlElementView(viewType: _viewType),
        ),
      ),
    );
  }
}