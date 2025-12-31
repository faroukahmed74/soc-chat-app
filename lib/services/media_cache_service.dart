import 'dart:io';
import 'dart:typed_data';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;
import 'package:crypto/crypto.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'logger_service.dart';

/// Service for caching media files locally on the device
/// Provides offline access to previously viewed media
class MediaCacheService {
  static const String _cacheDirName = 'media_cache';
  static const String _cacheIndexKey = 'media_cache_index';
  static const String _cacheSizeKey = 'media_cache_size';
  static const int _maxCacheSizeMB = 500; // 500MB max cache size
  static const int _maxFileAgeDays = 30; // 30 days max file age
  
  static Directory? _cacheDirectory;
  static Map<String, MediaCacheEntry> _cacheIndex = {};
  static int _currentCacheSizeBytes = 0;

  /// Initialize the media cache service
  static Future<void> initialize() async {
    try {
      // Web: Use browser cache + IndexedDB (handled by browser)
      if (kIsWeb) {
        Log.i('MediaCacheService: Web platform detected, using browser cache', 'MEDIA_CACHE');
        // Web browsers handle caching automatically via HTTP cache headers
        // We can enhance this later with IndexedDB for offline support
        return;
      }
      
      _cacheDirectory = await _getCacheDirectory();
      await _loadCacheIndex();
      await _cleanupOldFiles();
      Log.i('MediaCacheService initialized - ${_cacheIndex.length} files cached', 'MEDIA_CACHE');
    } catch (e) {
      Log.e('Failed to initialize MediaCacheService', 'MEDIA_CACHE', e);
      // Initialize with empty state to prevent crashes
      _cacheIndex = {};
      _currentCacheSizeBytes = 0;
    }
  }

  /// Get cache directory
  static Future<Directory> _getCacheDirectory() async {
    final appDir = await getApplicationDocumentsDirectory();
    final cacheDir = Directory('${appDir.path}/$_cacheDirName');
    
    if (!await cacheDir.exists()) {
      await cacheDir.create(recursive: true);
    }
    
    return cacheDir;
  }

  /// Load cache index from SharedPreferences
  static Future<void> _loadCacheIndex() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final indexJson = prefs.getString(_cacheIndexKey);
      final sizeBytes = prefs.getInt(_cacheSizeKey) ?? 0;
      
      if (indexJson != null) {
        _cacheIndex = Map<String, MediaCacheEntry>.from(
          (json.decode(indexJson) as Map).map(
            (key, value) => MapEntry(key, MediaCacheEntry.fromJson(value))
          )
        );
      }
      
      _currentCacheSizeBytes = sizeBytes;
      Log.i('Loaded cache index: ${_cacheIndex.length} entries, ${_formatBytes(_currentCacheSizeBytes)}', 'MEDIA_CACHE');
    } catch (e) {
      Log.e('Failed to load cache index', 'MEDIA_CACHE', e);
      _cacheIndex = {};
      _currentCacheSizeBytes = 0;
    }
  }

  /// Save cache index to SharedPreferences
  static Future<void> _saveCacheIndex() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final indexJson = json.encode(_cacheIndex.map(
        (key, value) => MapEntry(key, value.toJson())
      ));
      
      await prefs.setString(_cacheIndexKey, indexJson);
      await prefs.setInt(_cacheSizeKey, _currentCacheSizeBytes);
    } catch (e) {
      Log.e('Failed to save cache index', 'MEDIA_CACHE', e);
    }
  }

  /// Generate cache key from media URL
  static String _generateCacheKey(String mediaUrl) {
    final bytes = utf8.encode(mediaUrl);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  /// Check if media is cached locally
  static bool isCached(String mediaUrl) {
    if (kIsWeb || _cacheDirectory == null) return false;
    final key = _generateCacheKey(mediaUrl);
    return _cacheIndex.containsKey(key);
  }

  /// Get cached media file path
  static String? getCachedPath(String mediaUrl) {
    if (kIsWeb || _cacheDirectory == null) return null;
    final key = _generateCacheKey(mediaUrl);
    final entry = _cacheIndex[key];
    
    if (entry != null) {
      final file = File('${_cacheDirectory!.path}/$key${entry.extension}');
      if (file.existsSync()) {
        return file.path;
      } else {
        // File doesn't exist, remove from index
        _removeFromIndex(key);
      }
    }
    
    return null;
  }

  /// Download and cache media file
  static Future<String?> cacheMedia(String mediaUrl, {String? mediaType}) async {
    try {
      final key = _generateCacheKey(mediaUrl);
      
      // Check if already cached
      if (_cacheIndex.containsKey(key)) {
        final cachedPath = getCachedPath(mediaUrl);
        if (cachedPath != null) {
          Log.i('Media already cached: $mediaUrl', 'MEDIA_CACHE');
          return cachedPath;
        }
      }

      Log.i('Downloading media for cache: $mediaUrl', 'MEDIA_CACHE');
      
      // Download the file
      final response = await http.get(Uri.parse(mediaUrl));
      if (response.statusCode != 200) {
        Log.e('Failed to download media: HTTP ${response.statusCode}', 'MEDIA_CACHE');
        return null;
      }

      // Determine file extension
      final extension = _getFileExtension(mediaUrl, mediaType);
      final filePath = '${_cacheDirectory!.path}/$key$extension';
      final file = File(filePath);
      
      // Write file to cache
      await file.writeAsBytes(response.bodyBytes);
      
      // Update cache index
      final entry = MediaCacheEntry(
        url: mediaUrl,
        filePath: filePath,
        sizeBytes: response.bodyBytes.length,
        cachedAt: DateTime.now(),
        extension: extension,
        mediaType: mediaType ?? 'unknown',
      );
      
      _cacheIndex[key] = entry;
      _currentCacheSizeBytes += response.bodyBytes.length;
      
      // Save index
      await _saveCacheIndex();
      
      // Check cache size and cleanup if needed
      await _enforceCacheSizeLimit();
      
      Log.i('Media cached successfully: ${_formatBytes(response.bodyBytes.length)}', 'MEDIA_CACHE');
      return filePath;
      
    } catch (e) {
      Log.e('Failed to cache media: $mediaUrl', 'MEDIA_CACHE', e);
      return null;
    }
  }

  /// Get file extension from URL or media type
  static String _getFileExtension(String url, String? mediaType) {
    // Try to get extension from URL
    final urlLower = url.toLowerCase();
    if (urlLower.contains('.jpg') || urlLower.contains('.jpeg')) return '.jpg';
    if (urlLower.contains('.png')) return '.png';
    if (urlLower.contains('.gif')) return '.gif';
    if (urlLower.contains('.mp4')) return '.mp4';
    if (urlLower.contains('.mov')) return '.mov';
    if (urlLower.contains('.avi')) return '.avi';
    if (urlLower.contains('.mp3')) return '.mp3';
    if (urlLower.contains('.wav')) return '.wav';
    if (urlLower.contains('.pdf')) return '.pdf';
    if (urlLower.contains('.doc')) return '.doc';
    if (urlLower.contains('.docx')) return '.docx';
    
    // Fallback to media type
    if (mediaType != null) {
      if (mediaType.startsWith('image/')) return '.jpg';
      if (mediaType.startsWith('video/')) return '.mp4';
      if (mediaType.startsWith('audio/')) return '.mp3';
      if (mediaType.contains('pdf')) return '.pdf';
    }
    
    return '.bin'; // Default extension
  }

  /// Enforce cache size limit by removing oldest files
  static Future<void> _enforceCacheSizeLimit() async {
    const maxSizeBytes = _maxCacheSizeMB * 1024 * 1024;
    
    if (_currentCacheSizeBytes <= maxSizeBytes) return;
    
    Log.i('Cache size limit exceeded, cleaning up...', 'MEDIA_CACHE');
    
    // Sort entries by cache date (oldest first)
    final sortedEntries = _cacheIndex.entries.toList()
      ..sort((a, b) => a.value.cachedAt.compareTo(b.value.cachedAt));
    
    // Remove oldest files until under limit
    for (final entry in sortedEntries) {
      if (_currentCacheSizeBytes <= maxSizeBytes) break;
      
      await _removeCachedFile(entry.key);
    }
    
    Log.i('Cache cleanup completed: ${_formatBytes(_currentCacheSizeBytes)}', 'MEDIA_CACHE');
  }

  /// Remove cached file
  static Future<void> _removeCachedFile(String key) async {
    try {
      final entry = _cacheIndex[key];
      if (entry == null) return;
      
      final file = File(entry.filePath);
      if (await file.exists()) {
        await file.delete();
        _currentCacheSizeBytes -= entry.sizeBytes;
      }
      
      _cacheIndex.remove(key);
      await _saveCacheIndex();
      
    } catch (e) {
      Log.e('Failed to remove cached file: $key', 'MEDIA_CACHE', e);
    }
  }

  /// Remove from cache index only
  static void _removeFromIndex(String key) {
    final entry = _cacheIndex[key];
    if (entry != null) {
      _currentCacheSizeBytes -= entry.sizeBytes;
      _cacheIndex.remove(key);
    }
  }

  /// Cleanup old files
  static Future<void> _cleanupOldFiles() async {
    final cutoffDate = DateTime.now().subtract(Duration(days: _maxFileAgeDays));
    final keysToRemove = <String>[];
    
    for (final entry in _cacheIndex.entries) {
      if (entry.value.cachedAt.isBefore(cutoffDate)) {
        keysToRemove.add(entry.key);
      }
    }
    
    for (final key in keysToRemove) {
      await _removeCachedFile(key);
    }
    
    if (keysToRemove.isNotEmpty) {
      Log.i('Cleaned up ${keysToRemove.length} old cached files', 'MEDIA_CACHE');
    }
  }

  /// Get cache statistics
  static Map<String, dynamic> getCacheStats() {
    return {
      'fileCount': _cacheIndex.length,
      'totalSizeBytes': _currentCacheSizeBytes,
      'totalSizeMB': (_currentCacheSizeBytes / (1024 * 1024)).toStringAsFixed(2),
      'maxSizeMB': _maxCacheSizeMB,
      'maxFileAgeDays': _maxFileAgeDays,
    };
  }

  /// Clear all cached files
  static Future<void> clearCache() async {
    try {
      if (_cacheDirectory != null && await _cacheDirectory!.exists()) {
        await _cacheDirectory!.delete(recursive: true);
        await _cacheDirectory!.create(recursive: true);
      }
      
      _cacheIndex.clear();
      _currentCacheSizeBytes = 0;
      await _saveCacheIndex();
      
      Log.i('Media cache cleared', 'MEDIA_CACHE');
    } catch (e) {
      Log.e('Failed to clear cache', 'MEDIA_CACHE', e);
    }
  }

  /// Format bytes to human readable string
  static String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  /// Preload media for offline access
  static Future<void> preloadMedia(List<String> mediaUrls) async {
    Log.i('Preloading ${mediaUrls.length} media files...', 'MEDIA_CACHE');
    
    for (final url in mediaUrls) {
      if (!isCached(url)) {
        await cacheMedia(url);
        // Small delay to avoid overwhelming the network
        await Future.delayed(Duration(milliseconds: 100));
      }
    }
    
    Log.i('Media preloading completed', 'MEDIA_CACHE');
  }
}

/// Cache entry model
class MediaCacheEntry {
  final String url;
  final String filePath;
  final int sizeBytes;
  final DateTime cachedAt;
  final String extension;
  final String mediaType;

  MediaCacheEntry({
    required this.url,
    required this.filePath,
    required this.sizeBytes,
    required this.cachedAt,
    required this.extension,
    required this.mediaType,
  });

  Map<String, dynamic> toJson() {
    return {
      'url': url,
      'filePath': filePath,
      'sizeBytes': sizeBytes,
      'cachedAt': cachedAt.toIso8601String(),
      'extension': extension,
      'mediaType': mediaType,
    };
  }

  factory MediaCacheEntry.fromJson(Map<String, dynamic> json) {
    return MediaCacheEntry(
      url: json['url'],
      filePath: json['filePath'],
      sizeBytes: json['sizeBytes'],
      cachedAt: DateTime.parse(json['cachedAt']),
      extension: json['extension'],
      mediaType: json['mediaType'],
    );
  }
}
