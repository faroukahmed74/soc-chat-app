// =============================================================================
// BACKGROUND SERVICE MANAGER
// =============================================================================
// Unified manager for all background services
// Handles initialization and lifecycle of background services

import 'package:flutter/foundation.dart';
import 'dart:io';
import 'foreground_chat_service_simple.dart' as fgs;
import 'background_sync_service.dart';
import 'ios_background_service.dart';
import 'logger_service.dart';

class BackgroundServiceManager {
  static final BackgroundServiceManager _instance = BackgroundServiceManager._internal();
  factory BackgroundServiceManager() => _instance;
  BackgroundServiceManager._internal();

  bool _initialized = false;

  /// Initialize all background services
  Future<void> initialize() async {
    if (_initialized) return;
    if (kIsWeb) return; // Not supported on web

    try {
      Log.i('Initializing background services...', 'BACKGROUND_MANAGER');

      // Initialize platform-specific services
      if (Platform.isAndroid) {
        // Android: Foreground service (WorkManager temporarily disabled due to compatibility)
        // await BackgroundSyncService().initialize(); // Disabled due to compatibility issues
        Log.i('Android background services initialized (WorkManager disabled)', 'BACKGROUND_MANAGER');
      } else if (Platform.isIOS) {
        // iOS: Background Fetch (temporarily disabled due to CocoaPods issue)
        // await IOSBackgroundService().initialize();
        // await IOSBackgroundService().start();
        Log.i('iOS background services skipped (background_fetch disabled)', 'BACKGROUND_MANAGER');
      }

      _initialized = true;
      Log.i('Background services initialized successfully', 'BACKGROUND_MANAGER');
    } catch (e) {
      Log.e('Error initializing background services', 'BACKGROUND_MANAGER', e);
    }
  }

  /// Start foreground service (Android only)
  Future<bool> startForegroundService() async {
    if (kIsWeb || !Platform.isAndroid) return false;
    
    try {
      final started = await fgs.ForegroundChatService().start();
      if (started) {
        Log.i('Foreground service started', 'BACKGROUND_MANAGER');
      }
      return started;
    } catch (e) {
      Log.e('Error starting foreground service', 'BACKGROUND_MANAGER', e);
      return false;
    }
  }

  /// Stop foreground service (Android only)
  Future<void> stopForegroundService() async {
    if (kIsWeb || !Platform.isAndroid) return;
    
    try {
      await fgs.ForegroundChatService().stop();
      Log.i('Foreground service stopped', 'BACKGROUND_MANAGER');
    } catch (e) {
      Log.e('Error stopping foreground service', 'BACKGROUND_MANAGER', e);
    }
  }

  /// Update foreground service notification
  void updateForegroundNotification(String text) {
    if (kIsWeb || !Platform.isAndroid) return;
    fgs.ForegroundChatService().updateNotification(text);
  }

  /// Check if foreground service is running
  bool isForegroundServiceRunning() {
    if (kIsWeb || !Platform.isAndroid) return false;
    return fgs.ForegroundChatService().isRunning;
  }

  /// Cleanup all services
  Future<void> cleanup() async {
    try {
      if (Platform.isAndroid) {
        await stopForegroundService();
        // WorkManager disabled - await BackgroundSyncService().cancelAll();
      } else if (Platform.isIOS) {
        await IOSBackgroundService().stop();
      }
      Log.i('Background services cleaned up', 'BACKGROUND_MANAGER');
    } catch (e) {
      Log.e('Error cleaning up background services', 'BACKGROUND_MANAGER', e);
    }
  }
}

