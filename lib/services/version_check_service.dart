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

class VersionCheckService {
  static const String _dropboxJsonUrl = VersionConfig.dropboxJsonUrl;
  
  static Future<Map<String, dynamic>?> checkForUpdates() async {
    try {
      // Get current app version
      final PackageInfo packageInfo = await PackageInfo.fromPlatform();
      final String currentVersion = packageInfo.version;
      final String currentBuildNumber = packageInfo.buildNumber;
      
      // Fetch version info from Dropbox
      final response = await http.get(Uri.parse(_dropboxJsonUrl));
      if (response.statusCode == 200) {
        final Map<String, dynamic> versionInfo = json.decode(response.body);
        
        final String latestVersion = versionInfo['version'];
        final String latestBuildNumber = versionInfo['build_number'];
        final String downloadUrl = versionInfo['download_url'];
        final String releaseNotes = versionInfo['release_notes'] ?? 'Bug fixes and improvements';
        final bool forceUpdate = versionInfo['force_update'] ?? false;
        
        // Compare versions
        final bool hasUpdate = _compareVersions(
          currentVersion, 
          currentBuildNumber, 
          latestVersion, 
          latestBuildNumber
        );
        
        return {
          'hasUpdate': hasUpdate,
          'currentVersion': currentVersion,
          'currentBuildNumber': currentBuildNumber,
          'latestVersion': latestVersion,
          'latestBuildNumber': latestBuildNumber,
          'downloadUrl': downloadUrl,
          'releaseNotes': releaseNotes,
          'forceUpdate': forceUpdate,
        };
      }
    } catch (e) {
      Log.e('[VersionCheck] Error checking for updates: $e');
    }
    return null;
  }
  
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
      
      for (int i = 0; i < 3; i++) {
        final int currentPart = i < current.length ? current[i] : 0;
        final int latestPart = i < latest.length ? latest[i] : 0;
        
        if (latestPart > currentPart) return true;
        if (latestPart < currentPart) return false;
      }
      
      // If versions are equal, compare build numbers
      final int currentBuildNum = int.tryParse(currentBuild) ?? 0;
      final int latestBuildNum = int.tryParse(latestBuild) ?? 0;
      
      return latestBuildNum > currentBuildNum;
    } catch (e) {
      Log.e('[VersionCheck] Error comparing versions: $e');
      return false;
    }
  }
  
  static Future<bool> downloadAndInstallUpdate(String downloadUrl, BuildContext context) async {
    // Store context before async operations to avoid BuildContext issues
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    
    try {
      // Request storage permission
      final status = await Permission.storage.request();
      if (!status.isGranted) {
        scaffoldMessenger.showSnackBar(
          const SnackBar(content: Text('Storage permission required to download update')),
        );
        return false;
      }
      
      // Show download progress
      scaffoldMessenger.showSnackBar(
        const SnackBar(content: Text('Downloading update...')),
      );
      
      // Download APK
      final response = await http.get(Uri.parse(downloadUrl));
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
        
        // Install APK
        final bool installed = await _installApk(apkPath);
        if (installed) {
          scaffoldMessenger.showSnackBar(
            const SnackBar(content: Text('Update downloaded successfully! Please install manually.')),
          );
          return true;
        } else {
          // If auto-install fails, open file manager
          await _openFileManager(apkPath);
          return true;
        }
      }
          } catch (e) {
        Log.e('[VersionCheck] Error downloading update: $e');
        scaffoldMessenger.showSnackBar(
        SnackBar(content: Text('Download failed: $e')),
      );
    }
    return false;
  }
  
  static Future<bool> _installApk(String apkPath) async {
    try {
      // Try to install APK using package installer
      final result = await Process.run('am', [
        'start',
        '-a',
        'android.intent.action.VIEW',
        '-d',
        'file://$apkPath',
        '-t',
        'application/vnd.android.package-archive'
      ]);
      return result.exitCode == 0;
    } catch (e) {
      Log.e('[VersionCheck] Auto-install failed: $e');
      return false;
    }
  }
  
  static Future<void> _openFileManager(String apkPath) async {
    try {
      final Uri uri = Uri.file(apkPath);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      }
    } catch (e) {
      Log.e('[VersionCheck] Error opening file manager: $e');
    }
  }
  
  static Future<String> getCurrentVersion() async {
    try {
      final PackageInfo packageInfo = await PackageInfo.fromPlatform();
      return '${packageInfo.version} (${packageInfo.buildNumber})';
    } catch (e) {
      return 'Unknown';
    }
  }
  
  static Future<String> getAppName() async {
    try {
      final PackageInfo packageInfo = await PackageInfo.fromPlatform();
      return packageInfo.appName;
    } catch (e) {
      return 'SOC Chat App';
    }
  }
}
