import 'dart:html' as html;
import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;

class WebImageService {
  static Future<Uint8List?> pickImageFromCamera() async {
    if (!kIsWeb) return null;
    
    try {
      final videoElement = html.VideoElement()
        ..autoplay = true
        ..style.width = '100%'
        ..style.height = '100%';
      
      final stream = await html.window.navigator.mediaDevices?.getUserMedia({
        'video': {
          'facingMode': 'user',
          'width': {'ideal': 1280},
          'height': {'ideal': 720}
        }
      });
      
      if (stream == null) return null;
      
      videoElement.srcObject = stream;
      
      // Create a canvas to capture the image
      final canvas = html.CanvasElement(
        width: 1280,
        height: 720,
      );
      final ctx = canvas.getContext('2d') as html.CanvasRenderingContext2D;
      
      // Wait for video to load
      await videoElement.onLoadedData.first;
      
      // Draw video frame to canvas
      ctx.drawImage(videoElement, 0, 0);
      
      // Stop the stream
      stream.getTracks().forEach((track) => track.stop());
      
      // Convert canvas to blob
      final blob = await canvas.toBlob('image/jpeg');
      if (blob == null) return null;
      
      // Convert blob to Uint8List
      final reader = html.FileReader();
      final completer = Completer<Uint8List>();
      
      reader.onLoad.listen((event) {
        final result = reader.result as Uint8List;
        completer.complete(result);
      });
      
      reader.readAsArrayBuffer(blob);
      return await completer.future;
    } catch (e) {
      print('Error accessing camera: $e');
      return null;
    }
  }

  static Future<Uint8List?> pickImageFromGallery() async {
    if (!kIsWeb) return null;
    
    try {
      final input = html.FileUploadInputElement()
        ..accept = 'image/*'
        ..multiple = false;
      
      input.click();
      
      final completer = Completer<Uint8List>();
      
      input.onChange.listen((event) async {
        final files = input.files;
        if (files != null && files.isNotEmpty) {
          final file = files[0];
          final reader = html.FileReader();
          
          reader.onLoad.listen((event) {
            final result = reader.result as Uint8List;
            completer.complete(result);
          });
          
          reader.readAsArrayBuffer(file);
        } else {
          completer.complete(null);
        }
      });
      
      return await completer.future;
    } catch (e) {
      print('Error picking image from gallery: $e');
      return null;
    }
  }

  static Future<Uint8List?> pickVideoFromGallery() async {
    if (!kIsWeb) return null;
    
    try {
      final input = html.FileUploadInputElement()
        ..accept = 'video/*'
        ..multiple = false;
      
      input.click();
      
      final completer = Completer<Uint8List>();
      
      input.onChange.listen((event) async {
        final files = input.files;
        if (files != null && files.isNotEmpty) {
          final file = files[0];
          final reader = html.FileReader();
          
          reader.onLoad.listen((event) {
            final result = reader.result as Uint8List;
            completer.complete(result);
          });
          
          reader.readAsArrayBuffer(file);
        } else {
          completer.complete(null);
        }
      });
      
      return await completer.future;
    } catch (e) {
      print('Error picking video from gallery: $e');
      return null;
    }
  }

  static Future<Uint8List?> pickVideoFromCamera() async {
    if (!kIsWeb) return null;
    
    try {
      final videoElement = html.VideoElement()
        ..autoplay = true
        ..style.width = '100%'
        ..style.height = '100%';
      
      final stream = await html.window.navigator.mediaDevices?.getUserMedia({
        'video': {
          'facingMode': 'user',
          'width': {'ideal': 1280},
          'height': {'ideal': 720}
        }
      });
      
      if (stream == null) return null;
      
      videoElement.srcObject = stream;
      
      // For video, we'll just capture a thumbnail frame
      final canvas = html.CanvasElement(
        width: 1280,
        height: 720,
      );
      final ctx = canvas.getContext('2d') as html.CanvasRenderingContext2D;
      
      // Wait for video to load
      await videoElement.onLoadedData.first;
      
      // Draw video frame to canvas
      ctx.drawImage(videoElement, 0, 0);
      
      // Stop the stream
      stream.getTracks().forEach((track) => track.stop());
      
      // Convert canvas to blob
      final blob = await canvas.toBlob('image/jpeg');
      if (blob == null) return null;
      
      // Convert blob to Uint8List
      final reader = html.FileReader();
      final completer = Completer<Uint8List>();
      
      reader.onLoad.listen((event) {
        final result = reader.result as Uint8List;
        completer.complete(result);
      });
      
      reader.readAsArrayBuffer(blob);
      return await completer.future;
    } catch (e) {
      print('Error accessing camera for video: $e');
      return null;
    }
  }

  static Future<Uint8List?> pickDocument() async {
    if (!kIsWeb) return null;
    
    try {
      final input = html.FileUploadInputElement()
        ..accept = '.pdf,.doc,.docx,.txt,.ppt,.pptx,.xls,.xlsx'
        ..multiple = false;
      
      input.click();
      
      final completer = Completer<Uint8List>();
      
      input.onChange.listen((event) async {
        final files = input.files;
        if (files != null && files.isNotEmpty) {
          final file = files[0];
          final reader = html.FileReader();
          
          reader.onLoad.listen((event) {
            final result = reader.result as Uint8List;
            completer.complete(result);
          });
          
          reader.readAsArrayBuffer(file);
        } else {
          completer.complete(null);
        }
      });
      
      return await completer.future;
    } catch (e) {
      print('Error picking document: $e');
      return null;
    }
  }
} 