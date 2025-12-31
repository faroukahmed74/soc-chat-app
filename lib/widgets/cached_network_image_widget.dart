// =============================================================================
// CACHED NETWORK IMAGE WIDGET
// =============================================================================
// This widget provides efficient image caching for chat media
// Works on Android, iOS, and Web with persistent cache

import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'dart:html' if (dart.library.io) '../widgets/html_stub.dart' as html;
import '../services/media_cache_service.dart';
import '../services/logger_service.dart';

/// Cached network image widget that uses persistent cache
class CachedNetworkImageWidget extends StatefulWidget {
  final String imageUrl;
  final BoxFit? fit;
  final Widget? placeholder;
  final Widget? errorWidget;
  final double? width;
  final double? height;
  final Map<String, String>? headers;
  final bool useCache;

  const CachedNetworkImageWidget({
    super.key,
    required this.imageUrl,
    this.fit,
    this.placeholder,
    this.errorWidget,
    this.width,
    this.height,
    this.headers,
    this.useCache = true,
  });

  @override
  State<CachedNetworkImageWidget> createState() => _CachedNetworkImageWidgetState();
}

class _CachedNetworkImageWidgetState extends State<CachedNetworkImageWidget> {
  Uint8List? _cachedBytes;
  bool _isLoading = true;
  bool _hasError = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadImage();
  }

  Future<void> _loadImage() async {
    if (!widget.useCache) {
      // Direct load without cache
      _loadFromNetwork();
      return;
    }

    try {
      // Check cache first
      if (kIsWeb) {
        await _loadFromWebCache();
      } else {
        await _loadFromMobileCache();
      }
    } catch (e) {
      Log.e('Error loading cached image', 'CACHED_NETWORK_IMAGE', e);
      _loadFromNetwork();
    }
  }

  Future<void> _loadFromMobileCache() async {
    // Check if cached
    final cachedPath = MediaCacheService.getCachedPath(widget.imageUrl);
    if (cachedPath != null) {
      try {
        final file = File(cachedPath);
        if (await file.exists()) {
          final bytes = await file.readAsBytes();
          if (mounted) {
            setState(() {
              _cachedBytes = bytes;
              _isLoading = false;
              _hasError = false;
            });
          }
          return;
        }
      } catch (e) {
        Log.w('Error reading cached file: $e', 'CACHED_NETWORK_IMAGE');
      }
    }

    // Not cached or cache read failed - load from network and cache
    await _loadFromNetworkAndCache();
  }

  Future<void> _loadFromWebCache() async {
    // Web: Use browser cache + IndexedDB for persistence
    // For now, rely on browser cache and load from network
    // TODO: Implement IndexedDB caching for web
    await _loadFromNetwork();
  }

  Future<void> _loadFromNetwork() async {
    try {
      setState(() {
        _isLoading = true;
        _hasError = false;
      });

      final headers = <String, String>{
        'ngrok-skip-browser-warning': 'true',
        ...?widget.headers,
      };

      final response = await http.get(Uri.parse(widget.imageUrl), headers: headers);
      
      if (response.statusCode == 200) {
        if (mounted) {
          setState(() {
            _cachedBytes = response.bodyBytes;
            _isLoading = false;
            _hasError = false;
          });
        }
      } else {
        throw Exception('HTTP ${response.statusCode}');
      }
    } catch (e) {
      Log.e('Error loading image from network', 'CACHED_NETWORK_IMAGE', e);
      if (mounted) {
        setState(() {
          _hasError = true;
          _errorMessage = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _loadFromNetworkAndCache() async {
    try {
      setState(() {
        _isLoading = true;
        _hasError = false;
      });

      // Cache the media (this will download and save it)
      final cachedPath = await MediaCacheService.cacheMedia(
        widget.imageUrl,
        mediaType: 'image',
      );

      if (cachedPath != null) {
        final file = File(cachedPath);
        if (await file.exists()) {
          final bytes = await file.readAsBytes();
          if (mounted) {
            setState(() {
              _cachedBytes = bytes;
              _isLoading = false;
              _hasError = false;
            });
          }
          return;
        }
      }

      // Fallback to direct network load
      await _loadFromNetwork();
    } catch (e) {
      Log.e('Error caching image', 'CACHED_NETWORK_IMAGE', e);
      await _loadFromNetwork();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return widget.placeholder ?? 
        Container(
          width: widget.width,
          height: widget.height,
          color: Colors.grey[200],
          child: const Center(
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        );
    }

    if (_hasError || _cachedBytes == null) {
      return widget.errorWidget ??
        Container(
          width: widget.width,
          height: widget.height,
          color: Colors.grey[200],
          child: const Icon(Icons.broken_image, color: Colors.grey),
        );
    }

    return Image.memory(
      _cachedBytes!,
      fit: widget.fit ?? BoxFit.cover,
      width: widget.width,
      height: widget.height,
      errorBuilder: (context, error, stackTrace) {
        return widget.errorWidget ??
          Container(
            width: widget.width,
            height: widget.height,
            color: Colors.grey[200],
            child: const Icon(Icons.broken_image, color: Colors.grey),
          );
      },
    );
  }
}

