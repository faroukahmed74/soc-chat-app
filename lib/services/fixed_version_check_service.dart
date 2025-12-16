import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:device_info_plus/device_info_plus.dart';
import '../config/version_config.dart';
import 'logger_service.dart';
import 'dart:typed_data';

/// Download progress callback type
typedef DownloadProgressCallback = void Function(double progress, String? statusMessage);

/// Fixed version check service with proper platform handling
/// Supports both Android APK downloads and iOS App Store redirects
class FixedVersionCheckService {
  static const String _dropboxJsonUrl = VersionConfig.dropboxJsonUrl;
  
  /// Check for updates with proper platform handling
  static Future<Map<String, dynamic>?> checkForUpdates() async {
    try {
      Log.i('Checking for updates...', 'FIXED_VERSION_CHECK');
      
      // Get current app version from version_info.json
      final Map<String, dynamic> localVersionInfo = await _getLocalVersionInfo();
      final String currentVersion = localVersionInfo['version'] ?? '1.0.0';
      final String currentBuildNumber = localVersionInfo['build_number']?.toString() ?? '1';
      
      Log.i('Current version: $currentVersion ($currentBuildNumber)', 'FIXED_VERSION_CHECK');
      
      // Fetch version info from Dropbox
      final response = await http.get(
        Uri.parse(_dropboxJsonUrl),
        headers: {
          'User-Agent': 'SOC-Chat-App/1.0.0',
        },
      ).timeout(const Duration(seconds: 30));
      
      if (response.statusCode == 200) {
        final Map<String, dynamic> versionInfo = json.decode(response.body);
        
        final String latestVersion = versionInfo['version'] ?? '1.0.0';
        final String latestBuildNumber = versionInfo['build_number'] ?? '1';
        final String downloadUrl = versionInfo['download_url'] ?? '';
        // Handle release notes - can be string or array
        String releaseNotes = 'Bug fixes and improvements';
        if (versionInfo['release_notes'] != null) {
          if (versionInfo['release_notes'] is String) {
            releaseNotes = versionInfo['release_notes'] as String;
          } else if (versionInfo['release_notes'] is List) {
            releaseNotes = (versionInfo['release_notes'] as List).join('\n');
          }
        }
        final bool forceUpdate = versionInfo['force_update'] ?? false;
        
        Log.i('Latest version: $latestVersion ($latestBuildNumber)', 'FIXED_VERSION_CHECK');
        
        // Compare versions
        final bool hasUpdate = _compareVersions(
          currentVersion, 
          currentBuildNumber, 
          latestVersion, 
          latestBuildNumber
        );
        
        Log.i('Has update: $hasUpdate', 'FIXED_VERSION_CHECK');
        
        return {
          'hasUpdate': hasUpdate,
          'currentVersion': currentVersion,
          'currentBuildNumber': currentBuildNumber,
          'latestVersion': latestVersion,
          'latestBuildNumber': latestBuildNumber,
          'downloadUrl': downloadUrl,
          'releaseNotes': releaseNotes,
          'forceUpdate': forceUpdate,
          'platform': Platform.operatingSystem,
        };
      } else {
        Log.w('Failed to fetch version info: ${response.statusCode}', 'FIXED_VERSION_CHECK');
      }
    } catch (e) {
      Log.e('Error checking for updates', 'FIXED_VERSION_CHECK', e);
    }
    return null;
  }
  
  /// Compare versions properly
  static bool _compareVersions(
    String currentVersion, 
    String currentBuild, 
    String latestVersion, 
    String latestBuild
  ) {
    try {
      // Compare version strings (e.g., "1.2.3")
      final List<int> current = currentVersion.split('.').map(int.parse).toList();
      final List<int> latest = latestVersion.split('.').map(int.parse).toList();
      
      // Ensure both lists have at least 3 elements
      while (current.length < 3) current.add(0);
      while (latest.length < 3) latest.add(0);
      
      for (int i = 0; i < 3; i++) {
        if (latest[i] > current[i]) return true;
        if (latest[i] < current[i]) return false;
      }
      
      // If versions are equal, compare build numbers
      final int currentBuildNum = int.tryParse(currentBuild) ?? 0;
      final int latestBuildNum = int.tryParse(latestBuild) ?? 0;
      
      return latestBuildNum > currentBuildNum;
    } catch (e) {
      Log.e('Error comparing versions', 'FIXED_VERSION_CHECK', e);
      return false;
    }
  }
  
  /// Download and install update with platform-specific handling
  /// [downloadUrl] - URL to download APK from
  /// [context] - BuildContext for showing dialogs
  /// [onProgress] - Optional callback for download progress (0.0 to 1.0)
  /// [maxRetries] - Maximum number of retry attempts (default: 3)
  static Future<bool> downloadAndInstallUpdate(
    String downloadUrl,
    BuildContext context, {
    DownloadProgressCallback? onProgress,
    int maxRetries = 3,
  }) async {
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    
    try {
      Log.i('Starting update download for ${Platform.operatingSystem}', 'FIXED_VERSION_CHECK');
      
      if (Platform.isAndroid) {
        return await _downloadAndroidUpdateWithRetry(
          downloadUrl,
          context,
          onProgress: onProgress,
          maxRetries: maxRetries,
        );
      } else if (Platform.isIOS) {
        return await _redirectToAppStore(context);
      } else {
        // Web or other platforms
        return await _openDownloadUrl(downloadUrl, context);
      }
    } catch (e) {
      Log.e('Error in downloadAndInstallUpdate', 'FIXED_VERSION_CHECK', e);
      scaffoldMessenger.showSnackBar(
        SnackBar(content: Text('Update failed: ${_getErrorMessage(e)}')),
      );
      return false;
    }
  }
  
  /// Download Android APK with retry mechanism
  static Future<bool> _downloadAndroidUpdateWithRetry(
    String downloadUrl,
    BuildContext context, {
    DownloadProgressCallback? onProgress,
    int maxRetries = 3,
  }) async {
    int attempt = 0;
    Exception? lastError;
    
    while (attempt < maxRetries) {
      attempt++;
      try {
        Log.i('Download attempt $attempt of $maxRetries', 'FIXED_VERSION_CHECK');
        
        final result = await _downloadAndroidUpdate(
          downloadUrl,
          context,
          onProgress: onProgress,
        );
        
        if (result) {
          return true;
        }
        
        // If download failed, wait before retry
        if (attempt < maxRetries) {
          await Future.delayed(Duration(seconds: attempt * 2)); // Exponential backoff
        }
      } catch (e) {
        lastError = e is Exception ? e : Exception(e.toString());
        Log.e('Download attempt $attempt failed', 'FIXED_VERSION_CHECK', lastError);
        
        if (attempt < maxRetries) {
          onProgress?.call(0.0, 'Retrying download... (Attempt ${attempt + 1}/$maxRetries)');
          await Future.delayed(Duration(seconds: attempt * 2));
        }
      }
    }
    
    // All retries failed
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    scaffoldMessenger.showSnackBar(
      SnackBar(
        content: Text('Download failed after $maxRetries attempts. ${_getErrorMessage(lastError)}'),
        duration: const Duration(seconds: 5),
        action: SnackBarAction(
          label: 'Retry',
          onPressed: () => downloadAndInstallUpdate(downloadUrl, context, onProgress: onProgress),
        ),
      ),
    );
    
    return false;
  }
  
  /// Download Android APK update with progress tracking
  static Future<bool> _downloadAndroidUpdate(
    String downloadUrl,
    BuildContext context, {
    DownloadProgressCallback? onProgress,
  }) async {
    String? fileProviderPath; // Store for use in installation
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    File? apkFile;
    
    try {
      // Request storage permission for Android 13+
      final permissionGranted = await _requestStoragePermission(context);
      if (!permissionGranted) {
        return false;
      }
      
      onProgress?.call(0.0, 'Connecting to server...');
      
      // Get content length for progress tracking
      final headResponse = await http.head(
        Uri.parse(downloadUrl),
        headers: {'User-Agent': 'SOC-Chat-App-Android'},
      ).timeout(const Duration(seconds: 10));
      
      final contentLength = headResponse.headers['content-length'];
      final totalBytes = contentLength != null ? int.tryParse(contentLength) : null;
      
      onProgress?.call(0.0, 'Starting download...');
      
      // Download APK with progress tracking
      final request = http.Request('GET', Uri.parse(downloadUrl));
      request.headers['User-Agent'] = 'SOC-Chat-App-Android';
      
      final streamedResponse = await http.Client()
          .send(request)
          .timeout(const Duration(minutes: 5));
      
      if (streamedResponse.statusCode != 200) {
        throw Exception('HTTP ${streamedResponse.statusCode}: ${streamedResponse.reasonPhrase}');
      }
      
      // Get external files directory (works better with FileProvider)
      // For Android 10+, use external files directory
      // For older Android, use downloads directory
      final deviceInfo = DeviceInfoPlugin();
      final androidInfo = await deviceInfo.androidInfo;
      final sdkInt = androidInfo.version.sdkInt;
      
      Directory saveDir;
      String fileProviderPath;
      
      if (sdkInt >= 29) {
        // Android 10+: Use external files directory (scoped storage)
        final externalDir = await getExternalStorageDirectory();
        if (externalDir != null) {
          saveDir = Directory('${externalDir.path}/updates');
          fileProviderPath = 'updates/soc_chat_app_update.apk'; // Matches external-files-path in file_paths.xml
        } else {
          // Fallback to downloads
          saveDir = await getDownloadsDirectory() ?? Directory('/storage/emulated/0/Download');
          fileProviderPath = 'downloads/soc_chat_app_update.apk';
        }
      } else {
        // Android <10: Use downloads directory
        saveDir = await getDownloadsDirectory() ?? Directory('/storage/emulated/0/Download');
        fileProviderPath = 'downloads/soc_chat_app_update.apk';
      }
      
      if (!await saveDir.exists()) {
        await saveDir.create(recursive: true);
      }
      
      // Save APK file with progress tracking
      final String apkPath = '${saveDir.path}/soc_chat_app_update.apk';
      apkFile = File(apkPath);
      
      // Store fileProviderPath for later use in installation
      fileProviderPath = fileProviderPath;
      
      // Delete old APK if exists
      if (await apkFile.exists()) {
        await apkFile.delete();
      }
      
      final fileSink = apkFile.openWrite();
      int downloadedBytes = 0;
      
      try {
        await for (final chunk in streamedResponse.stream) {
          fileSink.add(chunk);
          downloadedBytes += chunk.length;
          
          if (totalBytes != null && totalBytes > 0) {
            final progress = downloadedBytes / totalBytes;
            final mbDownloaded = (downloadedBytes / (1024 * 1024)).toStringAsFixed(1);
            final mbTotal = (totalBytes / (1024 * 1024)).toStringAsFixed(1);
            onProgress?.call(
              progress.clamp(0.0, 1.0),
              'Downloading... $mbDownloaded MB / $mbTotal MB',
            );
          } else {
            final mbDownloaded = (downloadedBytes / (1024 * 1024)).toStringAsFixed(1);
            onProgress?.call(
              (downloadedBytes / (100 * 1024 * 1024)).clamp(0.0, 0.99), // Estimate
              'Downloaded $mbDownloaded MB...',
            );
          }
        }
      } finally {
        await fileSink.close();
      }
      
      onProgress?.call(1.0, 'Download complete. Verifying...');
      
      // Verify APK file
      if (!await apkFile.exists()) {
        throw Exception('Downloaded file not found');
      }
      
      final fileSize = await apkFile.length();
      if (fileSize < 1024) { // Less than 1KB is suspicious
        throw Exception('Downloaded file is too small (${fileSize} bytes). File may be corrupted.');
      }
      
      Log.i('APK downloaded to: $apkPath (${(fileSize / (1024 * 1024)).toStringAsFixed(2)} MB)', 'FIXED_VERSION_CHECK');
      
      onProgress?.call(1.0, 'Installing update...');
      
      // Try to install APK
      final bool installed = await _installApk(apkPath, context, fileProviderPath: fileProviderPath);
      if (installed) {
        onProgress?.call(1.0, 'Installation started!');
        return true;
      } else {
        // If auto-install fails, open file manager
        await _openFileManager(apkPath);
        scaffoldMessenger.showSnackBar(
          const SnackBar(
            content: Text('Update downloaded! Please tap the file to install.'),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 5),
          ),
        );
        return true;
      }
    } catch (e) {
      Log.e('Error downloading Android update', 'FIXED_VERSION_CHECK', e);
      
      // Clean up partial download
      if (apkFile != null && await apkFile.exists()) {
        try {
          await apkFile.delete();
        } catch (_) {}
      }
      
      final errorMsg = _getErrorMessage(e);
      onProgress?.call(0.0, 'Download failed: $errorMsg');
      
      throw Exception(errorMsg);
    }
  }
  
  /// Request storage permission with Android version compatibility
  static Future<bool> _requestStoragePermission(BuildContext context) async {
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    
    try {
      if (await _isAndroid13OrHigher()) {
        // Android 13+ doesn't need storage permission for downloads directory
        // But we still check for manage external storage if needed
        final manageStatus = await Permission.manageExternalStorage.status;
        if (!manageStatus.isGranted) {
          // Try to request, but don't fail if denied (downloads directory should work)
          await Permission.manageExternalStorage.request();
        }
        return true; // Downloads directory should be accessible
      } else if (await _isAndroid10OrHigher()) {
        // Android 10-12: Scoped storage, downloads directory accessible
        return true;
      } else {
        // Android <10: Need storage permission
        final status = await Permission.storage.request();
        if (!status.isGranted) {
          scaffoldMessenger.showSnackBar(
            const SnackBar(
              content: Text('Storage permission required to download update. Please grant permission in Settings.'),
              duration: Duration(seconds: 5),
            ),
          );
          return false;
        }
        return true;
      }
    } catch (e) {
      Log.e('Error requesting storage permission', 'FIXED_VERSION_CHECK', e);
      return false;
    }
  }
  
  /// Check if device is Android 10 or higher
  static Future<bool> _isAndroid10OrHigher() async {
    try {
      if (!Platform.isAndroid) return false;
      final deviceInfo = DeviceInfoPlugin();
      final androidInfo = await deviceInfo.androidInfo;
      return androidInfo.version.sdkInt >= 29; // Android 10 = API 29
    } catch (e) {
      return false;
    }
  }
  
  /// Redirect to App Store for iOS
  static Future<bool> _redirectToAppStore(BuildContext context) async {
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    
    try {
      // App Store URL for SOC Chat App
      const String appStoreUrl = 'https://apps.apple.com/app/soc-chat-app/id1234567890'; // Replace with actual App Store URL
      
      final Uri uri = Uri.parse(appStoreUrl);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
        scaffoldMessenger.showSnackBar(
          const SnackBar(
            content: Text('Redirecting to App Store...'),
            backgroundColor: Colors.blue,
          ),
        );
        return true;
      } else {
        scaffoldMessenger.showSnackBar(
          const SnackBar(content: Text('Could not open App Store')),
        );
        return false;
      }
    } catch (e) {
      Log.e('Error redirecting to App Store', 'FIXED_VERSION_CHECK', e);
      scaffoldMessenger.showSnackBar(
        SnackBar(content: Text('Error opening App Store: $e')),
      );
      return false;
    }
  }
  
  /// Open download URL for web/other platforms
  static Future<bool> _openDownloadUrl(String downloadUrl, BuildContext context) async {
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    
    try {
      final Uri uri = Uri.parse(downloadUrl);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
        scaffoldMessenger.showSnackBar(
          const SnackBar(
            content: Text('Opening download link...'),
            backgroundColor: Colors.blue,
          ),
        );
        return true;
      } else {
        scaffoldMessenger.showSnackBar(
          const SnackBar(content: Text('Could not open download link')),
        );
        return false;
      }
    } catch (e) {
      Log.e('Error opening download URL', 'FIXED_VERSION_CHECK', e);
      scaffoldMessenger.showSnackBar(
        SnackBar(content: Text('Error opening download: $e')),
      );
      return false;
    }
  }
  
  /// Install APK with improved method for all Android versions
  /// Uses FileProvider for Android 7+ (API 24+)
  /// Opens the Android system installation dialog automatically
  static Future<bool> _installApk(String apkPath, BuildContext context, {String? fileProviderPath}) async {
    try {
      Log.i('Attempting to install APK: $apkPath', 'FIXED_VERSION_CHECK');
      
      final deviceInfo = DeviceInfoPlugin();
      final androidInfo = await deviceInfo.androidInfo;
      final sdkInt = androidInfo.version.sdkInt;
      
      // Method 1: Use method channel for reliable installation (preferred)
      // This opens the system installation dialog directly
      try {
        const platform = MethodChannel('soc_chat_app/installer');
        final useFileProvider = sdkInt >= 24; // Android 7+ (API 24+)
        
        final result = await platform.invokeMethod<bool>(
          'installApk',
          {
            'apkPath': apkPath,
            'useFileProvider': useFileProvider,
          },
        );
        
        if (result == true) {
          Log.i('✅ APK installation dialog opened successfully via method channel', 'FIXED_VERSION_CHECK');
          return true;
        }
      } catch (e) {
        Log.w('Method channel install failed, trying fallback: $e', 'FIXED_VERSION_CHECK');
      }
      
      // Method 2: Fallback using Process.run with proper Intent
      bool success = false;
      
      if (sdkInt >= 24) {
        // Android 7+ (API 24+): Use FileProvider
        try {
          final actualPackageName = await _getPackageName();
          final fileName = apkPath.split('/').last;
          
          // Construct FileProvider URI
          String fileProviderUri;
          if (fileProviderPath != null) {
            fileProviderUri = 'content://$actualPackageName.fileprovider/$fileProviderPath';
          } else if (apkPath.contains('/Download/')) {
            fileProviderUri = 'content://$actualPackageName.fileprovider/downloads/$fileName';
          } else {
            fileProviderUri = 'content://$actualPackageName.fileprovider/external_files/updates/$fileName';
          }
          
          Log.i('Using FileProvider URI: $fileProviderUri', 'FIXED_VERSION_CHECK');
          
          final result = await Process.run('am', [
            'start',
            '-a',
            'android.intent.action.VIEW',
            '-d',
            fileProviderUri,
            '-t',
            'application/vnd.android.package-archive',
            '--activity-clear-top',
            '--activity-single-top',
            '--activity-no-history',
            '--grant-read-uri-permission',
            '--grant-write-uri-permission',
          ]);
          
          if (result.exitCode == 0) {
            Log.i('APK install initiated via FileProvider (fallback)', 'FIXED_VERSION_CHECK');
            success = true;
          }
        } catch (e) {
          Log.w('FileProvider install method failed: $e', 'FIXED_VERSION_CHECK');
        }
      }
      
      // Method 3: Using file URI for older Android versions
      if (!success && sdkInt < 24) {
        try {
          final result = await Process.run('am', [
            'start',
            '-a',
            'android.intent.action.VIEW',
            '-d',
            'file://$apkPath',
            '-t',
            'application/vnd.android.package-archive',
            '--activity-clear-top',
          ]);
          
          if (result.exitCode == 0) {
            Log.i('APK install initiated via file URI (fallback)', 'FIXED_VERSION_CHECK');
            success = true;
          }
        } catch (e) {
          Log.w('File URI install method failed: $e', 'FIXED_VERSION_CHECK');
        }
      }
      
      return success;
    } catch (e) {
      Log.e('Auto-install failed', 'FIXED_VERSION_CHECK', e);
      return false;
    }
  }
  
  /// Get package name for FileProvider
  /// Uses the applicationId from AndroidManifest
  static Future<String> _getPackageName() async {
    try {
      // Use platform channel to get package name
      const platform = MethodChannel('soc_chat_app/package');
      final packageName = await platform.invokeMethod<String>('getPackageName');
      if (packageName != null && packageName.isNotEmpty) {
        return packageName;
      }
    } catch (e) {
      Log.w('Could not get package name from platform channel: $e', 'FIXED_VERSION_CHECK');
    }
    
    // Fallback: Use actual package name from build.gradle
    // This matches the applicationId in android/app/build.gradle.kts
    return 'com.faroukahmed74.socchatapp';
  }
  
  /// Get user-friendly error message
  static String _getErrorMessage(dynamic error) {
    if (error == null) return 'Unknown error';
    
    final errorStr = error.toString().toLowerCase();
    
    if (errorStr.contains('timeout') || errorStr.contains('timed out')) {
      return 'Connection timeout. Please check your internet connection.';
    } else if (errorStr.contains('network') || errorStr.contains('socket')) {
      return 'Network error. Please check your internet connection.';
    } else if (errorStr.contains('permission') || errorStr.contains('denied')) {
      return 'Permission denied. Please grant storage permission in Settings.';
    } else if (errorStr.contains('http 4')) {
      return 'Server error. Please try again later.';
    } else if (errorStr.contains('http 5')) {
      return 'Server error. Please try again later.';
    } else if (errorStr.contains('not found') || errorStr.contains('404')) {
      return 'Update file not found. Please contact support.';
    } else if (errorStr.contains('space') || errorStr.contains('storage')) {
      return 'Insufficient storage space. Please free up some space.';
    } else {
      return error.toString();
    }
  }
  
  /// Open file manager to show downloaded APK
  static Future<void> _openFileManager(String apkPath) async {
    try {
      final Uri uri = Uri.file(apkPath);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      Log.e('Error opening file manager', 'FIXED_VERSION_CHECK', e);
    }
  }
  
  /// Check if device is Android 13 or higher
  static Future<bool> _isAndroid13OrHigher() async {
    try {
      if (!Platform.isAndroid) return false;
      
      final deviceInfo = DeviceInfoPlugin();
      final androidInfo = await deviceInfo.androidInfo;
      return androidInfo.version.sdkInt >= 33; // Android 13 = API 33
    } catch (e) {
      Log.w('Error checking Android version: $e', 'FIXED_VERSION_CHECK');
      return false;
    }
  }
  
  /// Get current version info
  static Future<String> getCurrentVersion() async {
    try {
      final Map<String, dynamic> localVersionInfo = await _getLocalVersionInfo();
      final String version = localVersionInfo['version'] ?? '1.0.0';
      final String buildNumber = localVersionInfo['build_number']?.toString() ?? '1';
      return '$version ($buildNumber)';
    } catch (e) {
      return 'Unknown';
    }
  }
  
  /// Get app name
  static Future<String> getAppName() async {
    try {
      final Map<String, dynamic> localVersionInfo = await _getLocalVersionInfo();
      return localVersionInfo['app_name'] ?? 'SOC Chat App';
    } catch (e) {
      return 'SOC Chat App';
    }
  }

  /// Get local version info from version_info.json
  /// 
  /// IMPORTANT: The app reads version from version_info.json (bundled in assets)
  /// NOT from pubspec.yaml directly. You must keep them in sync manually.
  /// 
  /// Current version checking flow:
  /// 1. Reads LOCAL version from version_info.json (bundled in app)
  /// 2. Fetches REMOTE version from Dropbox version_info.json
  /// 3. Compares versions to determine if update is available
  /// 
  /// To keep versions in sync:
  /// - Update version_info.json: "version": "1.0.27", "build_number": "27"
  /// - Update pubspec.yaml: version: 1.0.27+27
  /// - Both should match!
  static Future<Map<String, dynamic>> _getLocalVersionInfo() async {
    try {
      // Primary source: version_info.json (bundled in app assets)
      // This file is included in assets (see pubspec.yaml line 153)
      final String jsonString = await rootBundle.loadString('version_info.json');
      final Map<String, dynamic> versionInfo = json.decode(jsonString);
      
      // Validate that version_info.json has required fields
      if (versionInfo['version'] != null && versionInfo['build_number'] != null) {
        final version = versionInfo['version'] as String;
        final buildNumber = versionInfo['build_number']?.toString() ?? '1';
        Log.i('Version loaded from version_info.json: $version (build $buildNumber)', 'FIXED_VERSION_CHECK');
        
        // Log warning if version seems outdated (optional check)
        if (version == '1.0.0' && buildNumber == '1') {
          Log.w('Warning: Using default version. Ensure version_info.json is up to date!', 'FIXED_VERSION_CHECK');
        }
        
        return versionInfo;
      } else {
        Log.e('version_info.json missing required fields (version or build_number)', 'FIXED_VERSION_CHECK');
        throw Exception('Invalid version_info.json: missing version or build_number');
      }
    } catch (e) {
      Log.e('Error loading version_info.json: $e', 'FIXED_VERSION_CHECK');
      // Fallback: Return default version (should not happen in production)
      Log.w('Using fallback version. Please ensure version_info.json is properly bundled!', 'FIXED_VERSION_CHECK');
      return {
        'version': '1.0.27', // Current version as fallback
        'build_number': '27',
        'app_name': 'SOC Chat App'
      };
    }
  }
  
  /// Test update functionality
  static Future<Map<String, dynamic>> testUpdateFunctionality() async {
    try {
      Log.i('Testing update functionality...', 'FIXED_VERSION_CHECK');
      
      final result = await checkForUpdates();
      if (result != null) {
        return {
          'status': 'success',
          'hasUpdate': result['hasUpdate'],
          'currentVersion': result['currentVersion'],
          'latestVersion': result['latestVersion'],
          'platform': result['platform'],
          'message': 'Update check completed successfully',
        };
      } else {
        return {
          'status': 'error',
          'message': 'Failed to check for updates',
        };
      }
    } catch (e) {
      Log.e('Error testing update functionality', 'FIXED_VERSION_CHECK', e);
      return {
        'status': 'error',
        'message': 'Error: $e',
      };
    }
  }
}
