import 'dart:typed_data';
import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

// Conditional imports for platform-specific services
import 'mobile_image_service.dart';
import 'mobile_voice_service.dart';
import 'document_service.dart';
import 'ios_media_permission_fix.dart';
import 'android_permission_fix.dart';

// Conditional imports for web-specific services
import 'web_media_service.dart' if (dart.library.io) 'web_media_stub.dart';

class UnifiedMediaService {
  // Image picking from camera with proper permission handling
  static Future<Uint8List?> pickImageFromCamera(BuildContext context) async {
    if (kIsWeb) {
      final result = await WebMediaService.pickImageFromCamera();
      return result?['bytes'] as Uint8List?;
    } else {
      // Use iOS-specific permission service for iOS, fallback to simple service for Android
      if (Platform.isIOS) {
        try {
          final xFile = await IOSMediaPermissionFix.pickImageFromCamera(context);
          if (xFile != null) {
            final bytes = await xFile.readAsBytes();
            print('[UnifiedMediaService] iOS Camera image captured: ${bytes.length} bytes');
            return bytes;
          }
          print('[UnifiedMediaService] No image captured from iOS camera');
          return null;
        } catch (e) {
          print('[UnifiedMediaService] Error capturing image from iOS camera: $e');
          return null;
        }
      } else {
        // Android permission handling with improved service
        final hasPermission = await AndroidPermissionFix.requestCameraPermission(context);
        
        if (!hasPermission) {
          print('[UnifiedMediaService] Android camera permission denied');
          return null;
        }
        
        try {
          final xFile = await MobileImageService.pickImageFromCamera();
          if (xFile != null) {
            final bytes = await xFile.readAsBytes();
            print('[UnifiedMediaService] Android camera image captured: ${bytes.length} bytes');
            return bytes;
          }
          print('[UnifiedMediaService] No image captured from Android camera');
          return null;
        } catch (e) {
          print('[UnifiedMediaService] Error capturing image from Android camera: $e');
          return null;
        }
      }
    }
  }

  // Image picking from gallery with proper permission handling
  static Future<Uint8List?> pickImageFromGallery(BuildContext context) async {
    if (kIsWeb) {
      final result = await WebMediaService.pickImageFromGallery();
      return result?['bytes'] as Uint8List?;
    } else {
      // Use iOS-specific permission service for iOS, fallback to simple service for Android
      if (Platform.isIOS) {
        try {
          final xFile = await IOSMediaPermissionFix.pickImageFromGallery(context);
          if (xFile != null) {
            final bytes = await xFile.readAsBytes();
            print('[UnifiedMediaService] iOS Gallery image selected: ${bytes.length} bytes');
            return bytes;
          }
          print('[UnifiedMediaService] No image selected from iOS gallery');
          return null;
        } catch (e) {
          print('[UnifiedMediaService] Error selecting image from iOS gallery: $e');
          return null;
        }
      } else {
        // Android permission handling with improved service
        final hasPermission = await AndroidPermissionFix.requestPhotosPermission(context);
        
        if (!hasPermission) {
          print('[UnifiedMediaService] Android photos permission denied');
          return null;
        }
        
        try {
          final xFile = await MobileImageService.pickImageFromGallery();
          if (xFile != null) {
            final bytes = await xFile.readAsBytes();
            print('[UnifiedMediaService] Android gallery image selected: ${bytes.length} bytes');
            return bytes;
          }
          print('[UnifiedMediaService] No image selected from Android gallery');
          return null;
        } catch (e) {
          print('[UnifiedMediaService] Error selecting image from Android gallery: $e');
          return null;
        }
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
      // Use iOS-specific permission service for iOS, fallback to simple service for Android
      if (Platform.isIOS) {
        try {
          final hasPermission = await IOSMediaPermissionFix.requestMicrophonePermission(context);
          if (!hasPermission) {
            print('[UnifiedMediaService] iOS microphone permission denied');
            return null;
          }
          
          final result = await MobileVoiceService.startRecording();
          if (result) {
            return {'status': 'recording', 'message': 'Voice recording started'};
          } else {
            return null;
          }
        } catch (e) {
          print('[UnifiedMediaService] Error starting iOS voice recording: $e');
          return null;
        }
      } else {
        // Android permission handling with improved service
        final hasPermission = await AndroidPermissionFix.requestMicrophonePermission(context);
        
        if (!hasPermission) {
          print('[UnifiedMediaService] Android microphone permission denied');
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
          print('[UnifiedMediaService] Error starting Android voice recording: $e');
          return null;
        }
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
      // Use iOS-specific permission service for iOS, fallback to simple service for Android
      if (Platform.isIOS) {
        try {
          final xFile = await IOSMediaPermissionFix.pickVideoFromCamera(context);
          if (xFile != null) {
            final bytes = await xFile.readAsBytes();
            print('[UnifiedMediaService] iOS Camera video captured: ${bytes.length} bytes');
            return bytes;
          }
          print('[UnifiedMediaService] No video captured from iOS camera');
          return null;
        } catch (e) {
          print('[UnifiedMediaService] Error capturing video from iOS camera: $e');
          return null;
        }
      } else {
        // Android permission handling with improved service
        final hasPermission = await AndroidPermissionFix.requestCameraPermission(context);
        
        if (!hasPermission) {
          print('[UnifiedMediaService] Android camera permission denied');
          return null;
        }
        
        try {
          final xFile = await MobileImageService.pickVideoFromCamera();
          if (xFile != null) {
            final bytes = await xFile.readAsBytes();
            print('[UnifiedMediaService] Android camera video captured: ${bytes.length} bytes');
            return bytes;
          }
          print('[UnifiedMediaService] No video captured from Android camera');
          return null;
        } catch (e) {
          print('[UnifiedMediaService] Error capturing video from Android camera: $e');
          return null;
        }
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
      // Use iOS-specific permission service for iOS, fallback to simple service for Android
      if (Platform.isIOS) {
        try {
          final xFile = await IOSMediaPermissionFix.pickVideoFromGallery(context);
          if (xFile != null) {
            final bytes = await xFile.readAsBytes();
            print('[UnifiedMediaService] iOS Gallery video selected: ${bytes.length} bytes');
            return bytes;
          }
          print('[UnifiedMediaService] No video selected from iOS gallery');
          return null;
        } catch (e) {
          print('[UnifiedMediaService] Error selecting video from iOS gallery: $e');
          return null;
        }
      } else {
        // Android permission handling with improved service
        final hasPermission = await AndroidPermissionFix.requestPhotosPermission(context);
        
        if (!hasPermission) {
          print('[UnifiedMediaService] Android photos permission denied');
          return null;
        }
        
        try {
          final xFile = await MobileImageService.pickVideoFromGallery();
          if (xFile != null) {
            final bytes = await xFile.readAsBytes();
            print('[UnifiedMediaService] Android gallery video selected: ${bytes.length} bytes');
            return bytes;
          }
          print('[UnifiedMediaService] No video selected from Android gallery');
          return null;
        } catch (e) {
          print('[UnifiedMediaService] Error selecting video from Android gallery: $e');
          return null;
        }
      }
    }
  }
} 