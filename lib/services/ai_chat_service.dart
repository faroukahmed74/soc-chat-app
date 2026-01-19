import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../config/database_config.dart';
import 'logger_service.dart';

/// Service for managing AI chat interactions
class AIChatService {
  static const String _logTag = 'AI_CHAT_SERVICE';

  /// Get AI status (Ollama availability, models, etc.)
  static Future<Map<String, dynamic>?> getAIStatus() async {
    String? baseUrl;
    Uri? url;
    
    try {
      final token = await _getAuthToken();
      if (token == null) {
        Log.w('No auth token available', _logTag);
        return null;
      }

      baseUrl = DatabaseConfig.physicalServerUrl;
      url = Uri.parse('$baseUrl/api/ai/status');
      
      Log.i('AI Status Request - Platform: ${kIsWeb ? "Web" : "Mobile"}', _logTag);
      Log.i('AI Status Request - URL: $url', _logTag);
      Log.i('AI Status Request - Base URL: $baseUrl', _logTag);

      final headers = <String, String>{
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      };

      if (!kIsWeb) {
        headers['ngrok-skip-browser-warning'] = 'true';
      }

      final response = await http.get(url, headers: headers).timeout(
        const Duration(seconds: 10),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        Log.i('AI status retrieved: enabled=${data['enabled']}, ollamaAvailable=${data['ollamaAvailable']}', _logTag);
        return data;
      } else {
        final errorBody = response.body.isNotEmpty ? json.decode(response.body) : {'error': 'Unknown error'};
        Log.w('Failed to get AI status: ${response.statusCode} - ${errorBody['error']}', _logTag);
        Log.w('Response URL: $url', _logTag);
        return null;
      }
    } catch (e) {
      Log.e('Error getting AI status: $e', _logTag);
      if (url != null) Log.e('Request URL was: $url', _logTag);
      if (baseUrl != null) Log.e('Base URL was: $baseUrl', _logTag);
      return null;
    }
  }

  /// Get or create user's private AI chat
  static Future<Map<String, dynamic>?> getOrCreateAIChat() async {
    String? baseUrl;
    Uri? url;
    
    try {
      final token = await _getAuthToken();
      if (token == null) {
        Log.w('No auth token available', _logTag);
        return null;
      }

      baseUrl = DatabaseConfig.physicalServerUrl;
      url = Uri.parse('$baseUrl/api/ai/chat');
      
      Log.i('AI Chat Request - Platform: ${kIsWeb ? "Web" : "Mobile"}', _logTag);
      Log.i('AI Chat Request - URL: $url', _logTag);
      Log.i('AI Chat Request - Base URL: $baseUrl', _logTag);

      final headers = <String, String>{
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      };

      if (!kIsWeb) {
        headers['ngrok-skip-browser-warning'] = 'true';
      }

      final response = await http.get(url, headers: headers).timeout(
        const Duration(seconds: 15),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = json.decode(response.body);
        Log.i('AI chat retrieved/created: ${data['chatId']}', _logTag);
        return data;
      } else {
        final errorData = response.body.isNotEmpty ? json.decode(response.body) : {'error': 'Unknown error'};
        Log.w('Failed to get/create AI chat: ${response.statusCode} - ${errorData['error']}', _logTag);
        Log.w('Response URL: $url', _logTag);
        return null;
      }
    } catch (e) {
      Log.e('Error getting/creating AI chat: $e', _logTag);
      if (url != null) Log.e('Request URL was: $url', _logTag);
      if (baseUrl != null) Log.e('Base URL was: $baseUrl', _logTag);
      return null;
    }
  }

  /// Get authentication token
  static Future<String?> _getAuthToken() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString('auth_token');
    } catch (e) {
      Log.e('Error getting auth token', _logTag, e);
      return null;
    }
  }
}
