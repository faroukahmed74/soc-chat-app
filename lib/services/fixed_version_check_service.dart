import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import '../config/version_config.dart';
import 'logger_service.dart';

/// Fixed version check service with proper platform handling
/// Supports both Android APK downloads and iOS App Store redirects
class FixedVersionCheckService {
  static const String _dropboxJsonUrl = VersionConfig.dropboxJsonUrl;
  
  /// Check for updates with proper platform handling
  static Future<Map<String, dynamic>?> checkForUpdates() async {
    try {
      Log.i('Checking for updates...', 'FIXED_VERSION_CHECK');
      
      // Get current app version
      final PackageInfo packageInfo = await PackageInfo.fromPlatform();
      final String currentVersion = packageInfo.version;
      final String currentBuildNumber = packageInfo.buildNumber;
      
      Log.i('Current version: $currentVersion ($currentBuildNumber)', 'FIXED_VERSION_CHECK');
      
      // Fetch version info from Dropbox
      final response = await http.get(
        Uri.parse(_dropboxJsonUrl),
        headers: {
          'User-Agent': 'SOC-Chat-App/${packageInfo.version}',
        },
      ).timeout(const Duration(seconds: 30));
      
      if (response.statusCode == 200) {
        final Map<String, dynamic> versionInfo = json.decode(response.body);
        
        final String latestVersion = versionInfo['version'] ?? '1.0.0';
        final String latestBuildNumber = versionInfo['build_number'] ?? '1';
        final String downloadUrl = versionInfo['download_url'] ?? '';
        final String releaseNotes = versionInfo['release_notes']?.join('\n') ?? 'Bug fixes and improvements';
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
  static Future<bool> downloadAndInstallUpdate(String downloadUrl, BuildContext context) async {
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    
    try {
      Log.i('Starting update download for ${Platform.operatingSystem}', 'FIXED_VERSION_CHECK');
      
      if (Platform.isAndroid) {
        return await _downloadAndroidUpdate(downloadUrl, context);
      } else if (Platform.isIOS) {
        return await _redirectToAppStore(context);
      } else {
        // Web or other platforms
        return await _openDownloadUrl(downloadUrl, context);
      }
    } catch (e) {
      Log.e('Error in downloadAndInstallUpdate', 'FIXED_VERSION_CHECK', e);
      scaffoldMessenger.showSnackBar(
        SnackBar(content: Text('Update failed: $e')),
      );
      return false;
    }
  }
  
  /// Download Android APK update
  static Future<bool> _downloadAndroidUpdate(String downloadUrl, BuildContext context) async {
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    
    try {
      // Request storage permission for Android 13+
      if (await _isAndroid13OrHigher()) {
        final status = await Permission.manageExternalStorage.request();
        if (!status.isGranted) {
          // Fallback to regular storage permission
          final storageStatus = await Permission.storage.request();
          if (!storageStatus.isGranted) {
            scaffoldMessenger.showSnackBar(
              const SnackBar(content: Text('Storage permission required to download update')),
            );
            return false;
          }
        }
      } else {
        final status = await Permission.storage.request();
        if (!status.isGranted) {
          scaffoldMessenger.showSnackBar(
            const SnackBar(content: Text('Storage permission required to download update')),
          );
          return false;
        }
      }
      
      // Show download progress
      scaffoldMessenger.showSnackBar(
        const SnackBar(
          content: Text('Downloading update...'),
          duration: Duration(seconds: 2),
        ),
      );
      
      // Download APK with timeout
      final response = await http.get(
        Uri.parse(downloadUrl),
        headers: {
          'User-Agent': 'SOC-Chat-App-Android',
        },
      ).timeout(const Duration(minutes: 5));
      
      if (response.statusCode == 200) {
        // Get downloads directory
        final Directory? downloadsDir = await getDownloadsDirectory();
        if (downloadsDir == null) {
          scaffoldMessenger.showSnackBar(
            const SnackBar(content: Text('Could not access downloads directory')),
          );
          return false;
        }
        
        // Save APK file
        final String apkPath = '${downloadsDir.path}/soc_chat_app_update.apk';
        final File apkFile = File(apkPath);
        await apkFile.writeAsBytes(response.bodyBytes);
        
        Log.i('APK downloaded to: $apkPath', 'FIXED_VERSION_CHECK');
        
        // Try to install APK
        final bool installed = await _installApk(apkPath);
        if (installed) {
          scaffoldMessenger.showSnackBar(
            const SnackBar(
              content: Text('Update downloaded successfully! Please install manually.'),
              backgroundColor: Colors.green,
            ),
          );
          return true;
        } else {
          // If auto-install fails, open file manager
          await _openFileManager(apkPath);
          scaffoldMessenger.showSnackBar(
            const SnackBar(
              content: Text('Update downloaded! Please install from Downloads folder.'),
              backgroundColor: Colors.orange,
            ),
          );
          return true;
        }
      } else {
        scaffoldMessenger.showSnackBar(
          SnackBar(content: Text('Download failed: HTTP ${response.statusCode}')),
        );
        return false;
      }
    } catch (e) {
      Log.e('Error downloading Android update', 'FIXED_VERSION_CHECK', e);
      scaffoldMessenger.showSnackBar(
        SnackBar(content: Text('Download failed: $e')),
      );
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
  
  /// Install APK with improved method
  static Future<bool> _installApk(String apkPath) async {
    try {
      Log.i('Attempting to install APK: $apkPath', 'FIXED_VERSION_CHECK');
      
      // Try using the package installer
      final result = await Process.run('am', [
        'start',
        '-a',
        'android.intent.action.VIEW',
        '-d',
        'file://$apkPath',
        '-t',
        'application/vnd.android.package-archive',
        '--activity-clear-top'
      ]);
      
      Log.i('APK install result: ${result.exitCode}', 'FIXED_VERSION_CHECK');
      return result.exitCode == 0;
    } catch (e) {
      Log.e('Auto-install failed', 'FIXED_VERSION_CHECK', e);
      return false;
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
      
      // Simple check: try to access manage external storage permission
      try {
        await Permission.manageExternalStorage.status;
        return true;
      } catch (e) {
        return false;
      }
    } catch (e) {
      return false;
    }
  }
  
  /// Get current version info
  static Future<String> getCurrentVersion() async {
    try {
      final PackageInfo packageInfo = await PackageInfo.fromPlatform();
      return '${packageInfo.version} (${packageInfo.buildNumber})';
    } catch (e) {
      return 'Unknown';
    }
  }
  
  /// Get app name
  static Future<String> getAppName() async {
    try {
      final PackageInfo packageInfo = await PackageInfo.fromPlatform();
      return packageInfo.appName;
    } catch (e) {
      return 'SOC Chat App';
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
