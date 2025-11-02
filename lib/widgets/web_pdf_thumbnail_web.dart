import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'dart:html' as html show IFrameElement;
import 'dart:ui_web' as ui_web;

/// Web-specific PDF thumbnail implementation
class WebPdfThumbnailImplementation extends StatefulWidget {
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
  State<WebPdfThumbnailImplementation> createState() => _WebPdfThumbnailImplementationState();
}

class _WebPdfThumbnailImplementationState extends State<WebPdfThumbnailImplementation> {
  late final String _viewType;

  @override
  void initState() {
    super.initState();
    _viewType = 'web-pdf-thumb-${widget.url.hashCode}-${DateTime.now().microsecondsSinceEpoch}';
    // Register a platform view that embeds an iframe displaying the PDF
    // Pointer events are disabled to make it behave like a static thumbnail.
    try {
      ui_web.platformViewRegistry.registerViewFactory(_viewType, (int viewId) {
        final resolvedUrl = widget.url;
        final iframe = html.IFrameElement()
          ..src = resolvedUrl
          ..style.border = 'none'
          ..style.pointerEvents = 'none'
          ..style.width = '100%'
          ..style.height = '100%';
        iframe.setAttribute('sandbox', 'allow-same-origin allow-scripts');
        iframe.setAttribute('scrolling', 'no');
        return iframe;
      });
    } catch (e) {
      // Silently fail if platformViewRegistry is not available
      print('Error registering PDF thumbnail view: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!kIsWeb) {
      // Fallback for non-web (should not happen due to conditional import)
      return Container(
        width: widget.width,
        height: widget.height,
        decoration: BoxDecoration(
          color: Colors.grey[200],
          borderRadius: widget.borderRadius,
        ),
        child: const Center(
          child: Icon(Icons.picture_as_pdf, color: Colors.red, size: 48),
        ),
      );
    }
    
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
