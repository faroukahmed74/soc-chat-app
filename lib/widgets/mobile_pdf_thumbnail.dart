// =============================================================================
// MOBILE PDF THUMBNAIL WIDGET
// =============================================================================
// This widget displays a PDF thumbnail on mobile platforms by rendering
// the first page of the PDF document

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import 'package:http/http.dart' as http;
import 'dart:typed_data';
import '../services/logger_service.dart';
import '../utils/responsive_utils.dart';

class MobilePdfThumbnail extends StatefulWidget {
  final String url;
  final double width;
  final double height;
  final BorderRadius borderRadius;
  final VoidCallback? onTap;

  const MobilePdfThumbnail({
    super.key,
    required this.url,
    required this.width,
    required this.height,
    this.borderRadius = const BorderRadius.all(Radius.circular(12)),
    this.onTap,
  });

  @override
  State<MobilePdfThumbnail> createState() => _MobilePdfThumbnailState();
}

class _MobilePdfThumbnailState extends State<MobilePdfThumbnail> {
  Uint8List? _pdfBytes;
  bool _isLoading = true;
  bool _hasError = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    if (!kIsWeb) {
      _loadPdf();
    }
  }

  Future<void> _loadPdf() async {
    try {
      setState(() {
        _isLoading = true;
        _hasError = false;
      });

      final response = await http.get(Uri.parse(widget.url));
      
      if (response.statusCode == 200) {
        setState(() {
          _pdfBytes = response.bodyBytes;
          _isLoading = false;
        });
      } else {
        throw Exception('Failed to load PDF: HTTP ${response.statusCode}');
      }
    } catch (e) {
      Log.e('Error loading PDF for thumbnail', 'MOBILE_PDF_THUMBNAIL', e);
      setState(() {
        _hasError = true;
        _isLoading = false;
        _errorMessage = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      child: Container(
        width: widget.width,
        height: widget.height,
        decoration: BoxDecoration(
          color: Colors.grey[200],
          borderRadius: widget.borderRadius,
          border: Border.all(color: Colors.grey[300]!, width: 1),
        ),
        child: ClipRRect(
          borderRadius: widget.borderRadius,
          child: _buildContent(),
        ),
      ),
    );
  }

  Widget _buildContent() {
    if (_isLoading) {
      return Container(
        color: Colors.grey[100],
        child: const Center(
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }

    if (_hasError || _pdfBytes == null) {
      return Container(
        color: Colors.red[50],
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.picture_as_pdf,
                color: Colors.red[700],
                size: widget.height * 0.3,
              ),
              const SizedBox(height: 8),
              Text(
                'PDF',
                style: TextStyle(
                  color: Colors.red[700],
                  fontSize: ResponsiveUtils.getResponsiveFontSize(
                    context,
                    baseSize: 12,
                  ),
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (_errorMessage != null) ...[
                const SizedBox(height: 4),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Text(
                    'Preview unavailable',
                    style: TextStyle(
                      color: Colors.red[700],
                      fontSize: ResponsiveUtils.getResponsiveFontSize(
                        context,
                        baseSize: 10,
                      ),
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ],
          ),
        ),
      );
    }

    // Render first page of PDF as thumbnail
    return SfPdfViewer.memory(
      _pdfBytes!,
      onDocumentLoadFailed: (PdfDocumentLoadFailedDetails details) {
        Log.e('PDF load failed', 'MOBILE_PDF_THUMBNAIL', details.error);
        if (mounted) {
          setState(() {
            _hasError = true;
            _errorMessage = details.error.toString();
          });
        }
      },
      controller: PdfViewerController()
        ..jumpToPage(0), // Show first page
      enableDoubleTapZooming: false,
      enableTextSelection: false,
      canShowScrollHead: false,
      canShowScrollStatus: false,
      showDocumentOverlay: false,
      enableDocumentLinkAnnotation: false,
      interactionMode: PdfInteractionMode.none, // Disable interaction for thumbnail
    );
  }
}
