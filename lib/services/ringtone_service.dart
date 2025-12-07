import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:audioplayers/audioplayers.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../config/database_config.dart';
import 'logger_service.dart';

/// Ringtone Service
/// Manages custom ringtones for incoming calls
class RingtoneService {
  static final RingtoneService _instance = RingtoneService._internal();
  factory RingtoneService() => _instance;
  RingtoneService._internal();

  static const String _ringtonePathKey = 'custom_ringtone_path';
  static const String _ringtoneNameKey = 'custom_ringtone_name';
  static const String _ringtoneUrlKey = 'custom_ringtone_url';
  
  final AudioPlayer _player = AudioPlayer();
  String? _currentRingtonePath;
  bool _isPlaying = false;

  /// Get the directory for storing ringtones
  Future<Directory> _getRingtonesDirectory() async {
    if (kIsWeb) {
      throw UnsupportedError('Ringtones not supported on web');
    }
    
    final appDir = await getApplicationDocumentsDirectory();
    final ringtonesDir = Directory('${appDir.path}/ringtones');
    
    if (!await ringtonesDir.exists()) {
      await ringtonesDir.create(recursive: true);
    }
    
    return ringtonesDir;
  }

  /// Download ringtone from URL
  Future<String?> downloadRingtone(String url, String fileName) async {
    try {
      if (kIsWeb) {
        Log.w('Ringtone download not supported on web', 'RINGTONE_SERVICE');
        return null;
      }

      Log.i('Downloading ringtone from: $url', 'RINGTONE_SERVICE');
      
      final response = await http.get(Uri.parse(url));
      
      if (response.statusCode != 200) {
        Log.e('Failed to download ringtone: ${response.statusCode}', 'RINGTONE_SERVICE');
        return null;
      }

      final ringtonesDir = await _getRingtonesDirectory();
      final file = File('${ringtonesDir.path}/$fileName');
      
      await file.writeAsBytes(response.bodyBytes);
      
      Log.i('Ringtone downloaded to: ${file.path}', 'RINGTONE_SERVICE');
      return file.path;
    } catch (e, stackTrace) {
      Log.e('Error downloading ringtone', 'RINGTONE_SERVICE', e, stackTrace);
      return null;
    }
  }

  /// Save ringtone from local file path
  Future<String?> saveRingtoneFromFile(String sourcePath, String fileName) async {
    try {
      if (kIsWeb) {
        Log.w('Ringtone save not supported on web', 'RINGTONE_SERVICE');
        return null;
      }

      final sourceFile = File(sourcePath);
      if (!await sourceFile.exists()) {
        Log.e('Source file does not exist: $sourcePath', 'RINGTONE_SERVICE');
        return null;
      }

      final ringtonesDir = await _getRingtonesDirectory();
      final destFile = File('${ringtonesDir.path}/$fileName');
      
      await sourceFile.copy(destFile.path);
      
      Log.i('Ringtone saved to: ${destFile.path}', 'RINGTONE_SERVICE');
      return destFile.path;
    } catch (e, stackTrace) {
      Log.e('Error saving ringtone', 'RINGTONE_SERVICE', e, stackTrace);
      return null;
    }
  }

  /// Set custom ringtone
  Future<bool> setCustomRingtone(String filePath, {String? name, String? url}) async {
    try {
      if (kIsWeb) {
        return false;
      }

      final file = File(filePath);
      if (!await file.exists()) {
        Log.e('Ringtone file does not exist: $filePath', 'RINGTONE_SERVICE');
        return false;
      }

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_ringtonePathKey, filePath);
      if (name != null) {
        await prefs.setString(_ringtoneNameKey, name);
      }
      if (url != null) {
        await prefs.setString(_ringtoneUrlKey, url);
      }

      _currentRingtonePath = filePath;
      Log.i('Custom ringtone set: $filePath', 'RINGTONE_SERVICE');
      
      // Sync with server (optional - fails gracefully if server not configured)
      if (name != null) {
        _syncRingtoneToServer(name, url).catchError((e) {
          Log.w('Failed to sync ringtone to server (non-critical): $e', 'RINGTONE_SERVICE');
        });
      }
      
      return true;
    } catch (e, stackTrace) {
      Log.e('Error setting custom ringtone', 'RINGTONE_SERVICE', e, stackTrace);
      return false;
    }
  }

  /// Sync ringtone preference to server (optional)
  Future<void> _syncRingtoneToServer(String name, String? url) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');
      
      if (token == null) {
        Log.w('No auth token, skipping server sync', 'RINGTONE_SERVICE');
        return;
      }

      final baseUrl = DatabaseConfig.physicalServerUrl;
      final response = await http.put(
        Uri.parse('$baseUrl/api/users/ringtone'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
          if (!kIsWeb) 'ngrok-skip-browser-warning': 'true',
        },
        body: jsonEncode({
          'ringtoneName': name,
          if (url != null) 'ringtoneUrl': url,
        }),
      );

      if (response.statusCode == 200) {
        Log.i('Ringtone preference synced to server: $name', 'RINGTONE_SERVICE');
      } else {
        Log.w('Server sync failed (non-critical): ${response.statusCode}', 'RINGTONE_SERVICE');
      }
    } catch (e) {
      // Fail silently - server sync is optional
      Log.w('Server sync error (non-critical): $e', 'RINGTONE_SERVICE');
    }
  }

  /// Get current ringtone path
  Future<String?> getCurrentRingtonePath() async {
    if (_currentRingtonePath != null) {
      return _currentRingtonePath;
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      final path = prefs.getString(_ringtonePathKey);
      
      if (path != null) {
        final file = File(path);
        if (await file.exists()) {
          _currentRingtonePath = path;
          return path;
        } else {
          // File doesn't exist, clear preference
          await clearCustomRingtone();
        }
      }
      
      return null;
    } catch (e) {
      Log.e('Error getting ringtone path', 'RINGTONE_SERVICE', e);
      return null;
    }
  }

  /// Get current ringtone name
  Future<String?> getCurrentRingtoneName() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_ringtoneNameKey);
    } catch (e) {
      Log.e('Error getting ringtone name', 'RINGTONE_SERVICE', e);
      return null;
    }
  }

  /// Get current ringtone URL (if downloaded from URL)
  Future<String?> getCurrentRingtoneUrl() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_ringtoneUrlKey);
    } catch (e) {
      Log.e('Error getting ringtone URL', 'RINGTONE_SERVICE', e);
      return null;
    }
  }

  /// Clear custom ringtone (use default)
  Future<void> clearCustomRingtone() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_ringtonePathKey);
      await prefs.remove(_ringtoneNameKey);
      await prefs.remove(_ringtoneUrlKey);
      _currentRingtonePath = null;
      Log.i('Custom ringtone cleared', 'RINGTONE_SERVICE');
      
      // Sync with server (optional)
      _syncRingtoneToServer('default', null).catchError((e) {
        Log.w('Failed to sync ringtone clear to server (non-critical): $e', 'RINGTONE_SERVICE');
      });
    } catch (e) {
      Log.e('Error clearing ringtone', 'RINGTONE_SERVICE', e);
    }
  }

  /// Play ringtone (looping)
  Future<void> playRingtone() async {
    if (_isPlaying) return;
    
    try {
      final ringtonePath = await getCurrentRingtonePath();
      
      if (ringtonePath != null && !kIsWeb) {
        await _player.setReleaseMode(ReleaseMode.loop);
        await _player.play(DeviceFileSource(ringtonePath));
        _isPlaying = true;
        Log.i('Playing custom ringtone: $ringtonePath', 'RINGTONE_SERVICE');
      } else {
        // Use default system ringtone (handled by system notifications)
        Log.i('Using default system ringtone', 'RINGTONE_SERVICE');
      }
    } catch (e, stackTrace) {
      Log.e('Error playing ringtone', 'RINGTONE_SERVICE', e, stackTrace);
      _isPlaying = false;
    }
  }

  /// Stop playing ringtone
  Future<void> stopRingtone() async {
    if (!_isPlaying) return;
    
    try {
      await _player.stop();
      _isPlaying = false;
      Log.i('Ringtone stopped', 'RINGTONE_SERVICE');
    } catch (e) {
      Log.e('Error stopping ringtone', 'RINGTONE_SERVICE', e);
      _isPlaying = false;
    }
  }

  /// Get list of available ringtones in the ringtones directory
  Future<List<FileSystemEntity>> getAvailableRingtones() async {
    try {
      if (kIsWeb) {
        return [];
      }

      final ringtonesDir = await _getRingtonesDirectory();
      final files = ringtonesDir.listSync();
      
      return files.where((file) {
        if (file is File) {
          final ext = file.path.split('.').last.toLowerCase();
          return ['mp3', 'wav', 'm4a', 'aac', 'ogg'].contains(ext);
        }
        return false;
      }).toList();
    } catch (e) {
      Log.e('Error getting available ringtones', 'RINGTONE_SERVICE', e);
      return [];
    }
  }

  /// Delete a ringtone file
  Future<bool> deleteRingtone(String filePath) async {
    try {
      if (kIsWeb) {
        return false;
      }

      final file = File(filePath);
      if (await file.exists()) {
        await file.delete();
        
        // If this was the current ringtone, clear it
        final currentPath = await getCurrentRingtonePath();
        if (currentPath == filePath) {
          await clearCustomRingtone();
        }
        
        Log.i('Ringtone deleted: $filePath', 'RINGTONE_SERVICE');
        return true;
      }
      
      return false;
    } catch (e) {
      Log.e('Error deleting ringtone', 'RINGTONE_SERVICE', e);
      return false;
    }
  }

  /// Dispose resources
  void dispose() {
    _player.dispose();
  }
}

