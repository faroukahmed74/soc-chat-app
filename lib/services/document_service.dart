import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:file_picker/file_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;


class DocumentService {
  // Supported document types
  static const List<String> supportedExtensions = [
    // Microsoft Office
    'pdf', 'doc', 'docx', 'xls', 'xlsx', 'ppt', 'pptx',
    // Text files
    'txt', 'rtf', 'odt', 'ods', 'odp',
    // Images (for document previews)
    'jpg', 'jpeg', 'png', 'gif',
    // Other
    'csv',
  ];
  
  static const Map<String, String> mimeTypes = {
    'pdf': 'application/pdf',
    'doc': 'application/msword',
    'docx': 'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
    'xls': 'application/vnd.ms-excel',
    'xlsx': 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
    'ppt': 'application/vnd.ms-powerpoint',
    'pptx': 'application/vnd.openxmlformats-officedocument.presentationml.presentation',
    'txt': 'text/plain',
    'rtf': 'application/rtf',
    'odt': 'application/vnd.oasis.opendocument.text',
    'ods': 'application/vnd.oasis.opendocument.spreadsheet',
    'odp': 'application/vnd.oasis.opendocument.presentation',
    'csv': 'text/csv',
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
      case 'txt':
        return 'Text Document';
      case 'rtf':
        return 'Rich Text Document';
      case 'odt':
        return 'OpenDocument Text';
      case 'ods':
        return 'OpenDocument Spreadsheet';
      case 'odp':
        return 'OpenDocument Presentation';
      case 'csv':
        return 'CSV File';
      case 'jpg':
      case 'jpeg':
      case 'png':
      case 'gif':
        return 'Image File';
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
      case 'txt':
        return '📝';
      case 'csv':
        return '📊';
      case 'rtf':
      case 'odt':
      case 'ods':
      case 'odp':
        return '📋';
      case 'jpg':
      case 'jpeg':
      case 'png':
      case 'gif':
        return '🖼️';
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
        // For web, use enhanced online viewers
        final extension = _getExtensionFromFileName(fileName);
        final viewerUrl = _getWebViewerUrl(url, extension);
        print('[DocumentService] Opening document with viewer: $viewerUrl');
        return await launchUrl(Uri.parse(viewerUrl), mode: LaunchMode.externalApplication);
      } else {
        // For mobile, open with system app (Word, Excel, PowerPoint, PDF viewer, etc.)
        // This will open with the default app installed on the device
        print('[DocumentService] Opening document with system app on mobile');
        
        // Try to open directly first
        try {
          final uri = Uri.parse(url);
          final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
          if (launched) {
            print('[DocumentService] Successfully opened with external app');
            return true;
          }
        } catch (e) {
          print('[DocumentService] Direct opening failed: $e');
        }
        
        // If direct opening fails, download and open
        return await _downloadAndOpenDocument(url, fileName);
      }
    } catch (e) {
      print('[DocumentService] Error opening document: $e');
      return false;
    }
  }

  /// Get extension from file name
  static String _getExtensionFromFileName(String fileName) {
    final parts = fileName.split('.');
    if (parts.length > 1) {
      return parts.last.toLowerCase();
    }
    return 'pdf'; // Default to PDF
  }

  /// Get appropriate web viewer URL based on file type
  static String _getWebViewerUrl(String url, String extension) {
    try {
      // For text files, use raw view or browser default
      if (['txt', 'csv'].contains(extension)) {
        // Open directly in browser
        return url;
      }
      
      // For images, open directly in browser
      if (['jpg', 'jpeg', 'png', 'gif'].contains(extension)) {
        return url;
      }
      
      // Microsoft Office Online Viewer (supports Word, Excel, PowerPoint)
      if (['doc', 'docx', 'xls', 'xlsx', 'ppt', 'pptx'].contains(extension)) {
        // Use Microsoft Office Online
        return 'https://view.officeapps.live.com/op/view.aspx?src=${Uri.encodeComponent(url)}';
      }
      
      // For PDFs, use browser's built-in PDF viewer or Adobe
      if (extension == 'pdf') {
        // Let browser handle PDFs natively (modern browsers support this)
        return url;
      }
      
      // Fallback: Use Google Docs Viewer (supports most formats)
      return 'https://docs.google.com/viewer?url=${Uri.encodeComponent(url)}&embedded=true';
    } catch (e) {
      print('[DocumentService] Error creating viewer URL: $e');
      // Fallback to original URL
      return url;
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
