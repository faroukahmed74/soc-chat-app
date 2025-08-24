import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:file_picker/file_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;


class DocumentService {
  // Supported document types
  static const List<String> supportedExtensions = [
    'pdf', 'doc', 'docx', 'xls', 'xlsx', 'ppt', 'pptx'
  ];
  
  static const Map<String, String> mimeTypes = {
    'pdf': 'application/pdf',
    'doc': 'application/msword',
    'docx': 'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
    'xls': 'application/vnd.ms-excel',
    'xlsx': 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
    'ppt': 'application/vnd.ms-powerpoint',
    'pptx': 'application/vnd.openxmlformats-officedocument.presentationml.presentation',
  };

  /// Pick a document with file type filtering
  static Future<FilePickerResult?> pickDocument() async {
    if (kIsWeb) return null;
    
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: supportedExtensions,
        allowMultiple: false,
        withData: true,
      );
      
      if (result != null && result.files.isNotEmpty) {
        final file = result.files.first;
        print('[DocumentService] Document selected: ${file.name}, size: ${file.size} bytes, extension: ${file.extension}');
        
        // Validate file type
        if (file.extension != null && supportedExtensions.contains(file.extension!.toLowerCase())) {
          return result;
        } else {
          print('[DocumentService] Unsupported file type: ${file.extension}');
          return null;
        }
      }
      
      return null;
    } catch (e) {
      print('[DocumentService] Error picking document: $e');
      return null;
    }
  }

  /// Get file type from extension
  static String getFileType(String? extension) {
    if (extension == null) return 'Document';
    
    switch (extension.toLowerCase()) {
      case 'pdf':
        return 'PDF Document';
      case 'doc':
      case 'docx':
        return 'Word Document';
      case 'xls':
      case 'xlsx':
        return 'Excel Spreadsheet';
      case 'ppt':
      case 'pptx':
        return 'PowerPoint Presentation';
      default:
        return 'Document';
    }
  }

  /// Get appropriate icon for file type
  static String getFileIcon(String? extension) {
    if (extension == null) return '📄';
    
    switch (extension.toLowerCase()) {
      case 'pdf':
        return '📕';
      case 'doc':
      case 'docx':
        return '📘';
      case 'xls':
      case 'xlsx':
        return '📗';
      case 'ppt':
      case 'pptx':
        return '📙';
      default:
        return '📄';
    }
  }

  /// Get color for file type
  static int getFileColor(String? extension) {
    if (extension == null) return 0xFF808080; // Grey
    
    switch (extension.toLowerCase()) {
      case 'pdf':
        return 0xFFE53E3E; // Red
      case 'doc':
      case 'docx':
        return 0xFF3182CE; // Blue
      case 'xls':
      case 'xlsx':
        return 0xFF38A169; // Green
      case 'ppt':
      case 'pptx':
        return 0xFFDD6B20; // Orange
      default:
        return 0xFF808080; // Grey
    }
  }

  /// Open document with appropriate app
  static Future<bool> openDocument(String url, String fileName) async {
    try {
      print('[DocumentService] Opening document: $fileName from URL: $url');
      
      if (kIsWeb) {
        // For web, open in new tab
        print('[DocumentService] Opening document in web browser');
        return await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
      } else {
        // For mobile, check if it's a Firebase Storage URL
        if (url.contains('firebasestorage.googleapis.com')) {
          print('[DocumentService] Firebase Storage URL detected, opening directly');
          // For Firebase Storage URLs, try to open directly first
          try {
            final uri = Uri.parse(url);
            return await launchUrl(uri, mode: LaunchMode.externalApplication);
          } catch (e) {
            print('[DocumentService] Direct opening failed, trying download: $e');
            // If direct opening fails, try download and open
            return await _downloadAndOpenDocument(url, fileName);
          }
        } else {
          // For other URLs, try direct opening first
          try {
            final uri = Uri.parse(url);
            return await launchUrl(uri, mode: LaunchMode.externalApplication);
          } catch (e) {
            print('[DocumentService] Direct opening failed, trying download: $e');
            // If direct opening fails, try download and open
            return await _downloadAndOpenDocument(url, fileName);
          }
        }
      }
    } catch (e) {
      print('[DocumentService] Error opening document: $e');
      return false;
    }
  }

  /// Download document and open with system app
  static Future<bool> _downloadAndOpenDocument(String url, String fileName) async {
    try {
      print('[DocumentService] Starting download for: $fileName');
      
      // Get temporary directory
      final tempDir = await getTemporaryDirectory();
      final filePath = '${tempDir.path}/$fileName';
      final file = File(filePath);
      
      print('[DocumentService] Will save to: $filePath');
      
      // Download file
      print('[DocumentService] Downloading document from: $url');
      final response = await http.get(Uri.parse(url));
      
      print('[DocumentService] Download response status: ${response.statusCode}');
      
      if (response.statusCode == 200) {
        // Save file
        await file.writeAsBytes(response.bodyBytes);
        print('[DocumentService] Document saved to: $filePath');
        print('[DocumentService] File size: ${response.bodyBytes.length} bytes');
        
        // Check if file exists and has content
        if (await file.exists()) {
          final fileSize = await file.length();
          print('[DocumentService] File exists, size: $fileSize bytes');
          
          // Open with system app
          final uri = Uri.file(filePath);
          print('[DocumentService] Attempting to open file with URI: $uri');
          
          final success = await launchUrl(uri, mode: LaunchMode.externalApplication);
          print('[DocumentService] Launch result: $success');
          
          return success;
        } else {
          print('[DocumentService] File does not exist after saving');
          return false;
        }
      } else {
        print('[DocumentService] Failed to download document: ${response.statusCode}');
        print('[DocumentService] Response body: ${response.body}');
        return false;
      }
    } catch (e) {
      print('[DocumentService] Error downloading document: $e');
      return false;
    }
  }

  /// Format file size
  static String formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  /// Validate file size (max 50MB for documents)
  static bool isValidFileSize(int bytes) {
    const maxSize = 50 * 1024 * 1024; // 50MB
    return bytes <= maxSize;
  }
}
