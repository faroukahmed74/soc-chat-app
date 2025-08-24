import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

// Conditional imports for platform-specific services
import 'mobile_image_service.dart';
import 'mobile_voice_service.dart';
import 'production_permission_service.dart';
import 'document_service.dart';

// Conditional imports for web-specific services
import 'web_media_service.dart' if (dart.library.io) 'web_media_stub.dart';

class UnifiedMediaService {
  // Image picking from camera with proper permission handling
  static Future<Uint8List?> pickImageFromCamera(BuildContext context) async {
    if (kIsWeb) {
      final result = await WebMediaService.pickImageFromCamera();
      return result?['bytes'] as Uint8List?;
    } else {
      // Request camera permission first using production approach
      final hasPermission = await ProductionPermissionService.requestCameraPermission(context);
      
      if (!hasPermission) {
        print('[UnifiedMediaService] Camera permission denied');
        return null;
      }
      
      try {
        final xFile = await MobileImageService.pickImageFromCamera();
        if (xFile != null) {
          final bytes = await xFile.readAsBytes();
          print('[UnifiedMediaService] Camera image captured: ${bytes.length} bytes');
          return bytes;
        }
        print('[UnifiedMediaService] No image captured from camera');
        return null;
      } catch (e) {
        print('[UnifiedMediaService] Error capturing image from camera: $e');
        return null;
      }
    }
  }

  // Image picking from gallery with proper permission handling
  static Future<Uint8List?> pickImageFromGallery(BuildContext context) async {
    if (kIsWeb) {
      final result = await WebMediaService.pickImageFromGallery();
      return result?['bytes'] as Uint8List?;
    } else {
      // Request photos permission first using production approach
      final hasPermission = await ProductionPermissionService.requestPhotosPermission(context);
      
      if (!hasPermission) {
        print('[UnifiedMediaService] Photos permission denied');
        return null;
      }
      
      try {
        final xFile = await MobileImageService.pickImageFromGallery();
        if (xFile != null) {
          final bytes = await xFile.readAsBytes();
          print('[UnifiedMediaService] Gallery image selected: ${bytes.length} bytes');
          return bytes;
        }
        print('[UnifiedMediaService] No image selected from gallery');
        return null;
      } catch (e) {
        print('[UnifiedMediaService] Error selecting image from gallery: $e');
        return null;
      }
    }
  }

  // Document picking with proper permission handling
  static Future<Map<String, dynamic>?> pickDocument(BuildContext context) async {
    if (kIsWeb) {
      return await WebMediaService.pickDocument();
    } else {
      try {
        // Use the new DocumentService for proper file type filtering
        final result = await DocumentService.pickDocument();
        if (result != null && result.files.isNotEmpty) {
          final file = result.files.first;
          final bytes = file.bytes;
          final fileName = file.name;
          final extension = file.extension;
          final fileSize = file.size;
          
          if (bytes != null) {
            print('[UnifiedMediaService] Document selected: $fileName, size: $fileSize bytes, extension: $extension');
            
            return {
              'bytes': bytes,
              'fileName': fileName,
              'extension': extension,
              'fileSize': fileSize,
              'mimeType': DocumentService.mimeTypes[extension?.toLowerCase()] ?? 'application/octet-stream',
            };
          }
        }
        print('[UnifiedMediaService] No document selected');
        return null;
      } catch (e) {
        print('[UnifiedMediaService] Error picking document: $e');
        return null;
      }
    }
  }

  // Voice recording with proper permission handling
  static Future<Map<String, dynamic>?> startVoiceRecording(BuildContext context) async {
    if (kIsWeb) {
      return await WebMediaService.startVoiceRecording();
    } else {
      // Request microphone permission first using production approach
      final hasPermission = await ProductionPermissionService.requestMicrophonePermission(context);
      
      if (!hasPermission) {
        print('[UnifiedMediaService] Microphone permission denied');
        return null;
      }
      
      try {
        final result = await MobileVoiceService.startRecording();
        if (result) {
          return {'status': 'recording', 'message': 'Voice recording started'};
        } else {
          return null;
        }
      } catch (e) {
        print('[UnifiedMediaService] Error starting voice recording: $e');
        return null;
      }
    }
  }

  // Stop voice recording
  static Future<Map<String, dynamic>?> stopVoiceRecording() async {
    if (kIsWeb) {
      return await WebMediaService.stopVoiceRecording();
    } else {
      try {
        final audioBytes = await MobileVoiceService.stopRecording();
        if (audioBytes != null) {
          return {'status': 'stopped', 'audioBytes': audioBytes, 'message': 'Voice recording stopped'};
        } else {
          return null;
        }
      } catch (e) {
        print('[UnifiedMediaService] Error stopping voice recording: $e');
        return null;
      }
    }
  }

  // Check if voice recording is active
  static bool isVoiceRecording() {
    if (kIsWeb) {
      return WebMediaService.isVoiceRecording();
    } else {
      return MobileVoiceService.isRecording;
    }
  }

  // Video picking from camera with proper permission handling
  static Future<Uint8List?> pickVideoFromCamera(BuildContext context) async {
    if (kIsWeb) {
      try {
        final result = await WebMediaService.pickVideo();
        if (result != null) {
          return result['bytes'] as Uint8List?;
        }
        return null;
      } catch (e) {
        print('[UnifiedMediaService] Error picking video from camera on web: $e');
        return null;
      }
    } else {
      // Request camera permission first using production approach
      final hasPermission = await ProductionPermissionService.requestCameraPermission(context);
      
      if (!hasPermission) {
        print('[UnifiedMediaService] Camera permission denied');
        return null;
      }
      
      try {
        final xFile = await MobileImageService.pickVideoFromCamera();
        if (xFile != null) {
          final bytes = await xFile.readAsBytes();
          print('[UnifiedMediaService] Camera video captured: ${bytes.length} bytes');
          return bytes;
        }
        print('[UnifiedMediaService] No video captured from camera');
        return null;
      } catch (e) {
        print('[UnifiedMediaService] Error capturing video from camera: $e');
        return null;
      }
    }
  }

  // Video picking from gallery with proper permission handling
  static Future<Uint8List?> pickVideoFromGallery(BuildContext context) async {
    if (kIsWeb) {
      try {
        final result = await WebMediaService.pickVideo();
        if (result != null) {
          return result['bytes'] as Uint8List?;
        }
        return null;
      } catch (e) {
        print('[UnifiedMediaService] Error picking video from gallery on web: $e');
        return null;
      }
    } else {
      // Request photos permission first using production approach
      final hasPermission = await ProductionPermissionService.requestPhotosPermission(context);
      
      if (!hasPermission) {
        print('[UnifiedMediaService] Photos permission denied');
        return null;
      }
      
      try {
        final xFile = await MobileImageService.pickVideoFromGallery();
        if (xFile != null) {
          final bytes = await xFile.readAsBytes();
          print('[UnifiedMediaService] Gallery video selected: ${bytes.length} bytes');
          return bytes;
        }
        print('[UnifiedMediaService] No video selected from gallery');
        return null;
      } catch (e) {
        print('[UnifiedMediaService] Error selecting video from gallery: $e');
        return null;
      }
    }
  }
} 