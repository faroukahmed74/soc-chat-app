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
import 'dart:io';
import '../services/media_cache_service.dart';
import '../services/logger_service.dart';
import '../utils/responsive_utils.dart';

class MobilePdfThumbnail extends StatefulWidget {
  final String url;
  final double width;
  final double height;
  final BorderRadius borderRadius;
  final VoidCallback? onTap;
  final bool showRefreshButton;

  const MobilePdfThumbnail({
    super.key,
    required this.url,
    required this.width,
    required this.height,
    this.borderRadius = const BorderRadius.all(Radius.circular(12)),
    this.onTap,
    this.showRefreshButton = false,
  });

  @override
  State<MobilePdfThumbnail> createState() => _MobilePdfThumbnailState();
}

class _MobilePdfThumbnailState extends State<MobilePdfThumbnail> {
  // Simple in-memory LRU cache to avoid disk reads on repeated builds
  static final Map<String, Uint8List> _memoryCache = <String, Uint8List>{};
  static final List<String> _cacheOrder = <String>[]; // most-recently used at end
  static const int _maxMemoryCacheEntries = 16;

  Uint8List? _pdfBytes;
  bool _isLoading = true;
  bool _hasError = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    // For mobile, we no longer render PDF thumbnails. Show icon only.
    _isLoading = false;
  }

  Future<void> _loadPdf() async {
    try {
      setState(() {
        _isLoading = true;
        _hasError = false;
      });

      // 0) Check in-memory cache to avoid disk/network entirely
      final mem = _getFromMemoryCache(widget.url);
      if (mem != null) {
        setState(() {
          _pdfBytes = mem;
          _isLoading = false;
        });
        return;
      }

      // 1) Try local cache first
      final cachedPath = MediaCacheService.getCachedPath(widget.url);
      if (cachedPath != null) {
        final file = File(cachedPath);
        if (await file.exists()) {
          final bytes = await file.readAsBytes();
          setState(() {
            _pdfBytes = bytes;
            _isLoading = false;
          });
          _putIntoMemoryCache(widget.url, bytes);
          return;
        }
      }

      // 2) Not cached: cache the PDF and then load from file
      final cachedFilePath = await MediaCacheService.cacheMedia(
        widget.url,
        mediaType: 'application/pdf',
      );

      if (cachedFilePath != null) {
        final file = File(cachedFilePath);
        final bytes = await file.readAsBytes();
        setState(() {
          _pdfBytes = bytes;
          _isLoading = false;
        });
        _putIntoMemoryCache(widget.url, bytes);
        return;
      }

      // 3) Fallback: direct fetch (e.g., if cache service fails)
      final headers = <String, String>{
        'ngrok-skip-browser-warning': 'true',
        'User-Agent': 'Mozilla/5.0 (Linux; Android 10) Mobile',
      };
      final response = await http.get(Uri.parse(widget.url), headers: headers);
      if (response.statusCode == 200) {
        setState(() {
          _pdfBytes = response.bodyBytes;
          _isLoading = false;
        });
        _putIntoMemoryCache(widget.url, response.bodyBytes);
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

  Uint8List? _getFromMemoryCache(String url) {
    final bytes = _memoryCache[url];
    if (bytes != null) {
      // move to MRU
      _cacheOrder.remove(url);
      _cacheOrder.add(url);
    }
    return bytes;
  }

  void _putIntoMemoryCache(String url, Uint8List bytes) {
    _memoryCache[url] = bytes;
    _cacheOrder.remove(url);
    _cacheOrder.add(url);
    // Evict LRU if above max
    while (_cacheOrder.length > _maxMemoryCacheEntries) {
      final lru = _cacheOrder.first;
      _cacheOrder.removeAt(0);
      _memoryCache.remove(lru);
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
    // Always show a static PDF icon on mobile instead of rendering a thumbnail
    return Container(
      color: Colors.grey[100],
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.picture_as_pdf,
              color: Colors.red[700],
              size: widget.height * 0.36,
            ),
            const SizedBox(height: 6),
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
          ],
        ),
      ),
    );
  }

  Future<void> _refreshThumbnail() async {
    try {
      setState(() {
        _isLoading = true;
        _hasError = false;
      });

      final headers = <String, String>{
        'ngrok-skip-browser-warning': 'true',
        'User-Agent': 'Mozilla/5.0 (Linux; Android 10) Mobile',
      };

      final response = await http.get(Uri.parse(widget.url), headers: headers);
      if (response.statusCode == 200) {
        final bytes = response.bodyBytes;

        // Update memory cache
        _putIntoMemoryCache(widget.url, bytes);

        // Write-through to disk cache if a path exists; otherwise create it
        try {
          final existingPath = MediaCacheService.getCachedPath(widget.url);
          if (existingPath != null) {
            final file = File(existingPath);
            await file.writeAsBytes(bytes, flush: true);
          } else {
            // Create/ensure disk cache entry
            await MediaCacheService.cacheMedia(widget.url, mediaType: 'application/pdf');
          }
        } catch (e) {
          // Non-fatal: disk cache update failure
          Log.w('Refresh write-through to disk cache failed: $e', 'MOBILE_PDF_THUMBNAIL');
        }

        if (mounted) {
          setState(() {
            _pdfBytes = bytes;
            _isLoading = false;
          });
        }
      } else {
        throw Exception('Failed to refresh PDF: HTTP ${response.statusCode}');
      }
    } catch (e) {
      Log.e('Error refreshing PDF thumbnail', 'MOBILE_PDF_THUMBNAIL', e);
      if (mounted) {
        setState(() {
          _hasError = true;
          _isLoading = false;
          _errorMessage = e.toString();
        });
      }
    }
  }
}
