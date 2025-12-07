import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../config/database_config.dart';
import 'logger_service.dart';

/// Call History Service
/// Manages call history retrieval and storage
class CallHistoryService {
  static final CallHistoryService _instance = CallHistoryService._internal();
  factory CallHistoryService() => _instance;
  CallHistoryService._internal();

  /// Save a call to history
  Future<bool> saveCallHistory({
    required String callId,
    required String chatId,
    required String chatName,
    required String callerId,
    required List<String> participantIds,
    required String callType, // 'voice' or 'video'
    required String direction, // 'incoming' or 'outgoing'
    required String status, // 'completed', 'missed', 'rejected', 'cancelled'
    required DateTime startedAt,
    DateTime? answeredAt,
    DateTime? endedAt,
    int duration = 0, // Duration in seconds
    bool isGroupChat = false,
    Map<String, dynamic>? qualityMetrics,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');
      if (token == null) {
        Log.e('Cannot save call history: No auth token', 'CALL_HISTORY');
        return false;
      }

      final baseUrl = DatabaseConfig.physicalServerUrl;
      final url = '$baseUrl/api/calls/history';

      final response = await http.post(
        Uri.parse(url),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: json.encode({
          'callId': callId,
          'chatId': chatId,
          'chatName': chatName,
          'callerId': callerId,
          'participantIds': participantIds,
          'callType': callType,
          'direction': direction,
          'status': status,
          'startedAt': startedAt.toIso8601String(),
          'answeredAt': answeredAt?.toIso8601String(),
          'endedAt': endedAt?.toIso8601String(),
          'duration': duration,
          'isGroupChat': isGroupChat,
          'qualityMetrics': qualityMetrics ?? {},
        }),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        Log.i('Call history saved: $callId', 'CALL_HISTORY');
        return true;
      } else {
        Log.e('Failed to save call history: ${response.statusCode} - ${response.body}', 'CALL_HISTORY');
        return false;
      }
    } catch (e, stackTrace) {
      Log.e('Error saving call history', 'CALL_HISTORY', e, stackTrace);
      return false;
    }
  }

  /// Get call history
  Future<Map<String, dynamic>?> getCallHistory({
    int page = 1,
    int limit = 50,
    String? chatId,
    String? status,
    String? callType,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');
      if (token == null) {
        Log.e('Cannot get call history: No auth token', 'CALL_HISTORY');
        return null;
      }

      final baseUrl = DatabaseConfig.physicalServerUrl;
      final queryParams = <String, String>{
        'page': page.toString(),
        'limit': limit.toString(),
      };
      if (chatId != null) queryParams['chatId'] = chatId;
      if (status != null) queryParams['status'] = status;
      if (callType != null) queryParams['callType'] = callType;

      final uri = Uri.parse('$baseUrl/api/calls/history').replace(queryParameters: queryParams);
      final response = await http.get(
        uri,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          Log.i('Call history retrieved: ${data['calls']?.length ?? 0} calls', 'CALL_HISTORY');
          return data;
        } else {
          Log.e('Failed to get call history: ${data['error']}', 'CALL_HISTORY');
          return null;
        }
      } else {
        Log.e('Failed to get call history: ${response.statusCode} - ${response.body}', 'CALL_HISTORY');
        return null;
      }
    } catch (e, stackTrace) {
      Log.e('Error getting call history', 'CALL_HISTORY', e, stackTrace);
      return null;
    }
  }

  /// Get call history for a specific chat
  Future<List<Map<String, dynamic>>> getChatCallHistory(String chatId, {int limit = 20}) async {
    final result = await getCallHistory(chatId: chatId, limit: limit);
    if (result != null && result['calls'] != null) {
      return List<Map<String, dynamic>>.from(result['calls']);
    }
    return [];
  }

  /// Get missed calls
  Future<List<Map<String, dynamic>>> getMissedCalls({int limit = 20}) async {
    final result = await getCallHistory(status: 'missed', limit: limit);
    if (result != null && result['calls'] != null) {
      return List<Map<String, dynamic>>.from(result['calls']);
    }
    return [];
  }

  /// Get recent calls
  Future<List<Map<String, dynamic>>> getRecentCalls({int limit = 20}) async {
    final result = await getCallHistory(limit: limit);
    if (result != null && result['calls'] != null) {
      return List<Map<String, dynamic>>.from(result['calls']);
    }
    return [];
  }
}

/// Call History Model
class CallHistoryItem {
  final String callId;
  final String chatId;
  final String chatName;
  final String callerId;
  final List<String> participantIds;
  final String callType; // 'voice' or 'video'
  final String direction; // 'incoming' or 'outgoing'
  final String status; // 'completed', 'missed', 'rejected', 'cancelled'
  final DateTime startedAt;
  final DateTime? answeredAt;
  final DateTime? endedAt;
  final int duration; // Duration in seconds
  final bool isGroupChat;
  final Map<String, dynamic>? qualityMetrics;

  CallHistoryItem({
    required this.callId,
    required this.chatId,
    required this.chatName,
    required this.callerId,
    required this.participantIds,
    required this.callType,
    required this.direction,
    required this.status,
    required this.startedAt,
    this.answeredAt,
    this.endedAt,
    required this.duration,
    required this.isGroupChat,
    this.qualityMetrics,
  });

  factory CallHistoryItem.fromJson(Map<String, dynamic> json) {
    return CallHistoryItem(
      callId: json['callId']?.toString() ?? '',
      chatId: json['chatId']?.toString() ?? '',
      chatName: json['chatName']?.toString() ?? 'Unknown',
      callerId: json['callerId']?.toString() ?? '',
      participantIds: (json['participantIds'] as List<dynamic>?)
              ?.map((id) => id.toString())
              .toList() ??
          [],
      callType: json['callType']?.toString() ?? 'voice',
      direction: json['direction']?.toString() ?? 'outgoing',
      status: json['status']?.toString() ?? 'completed',
      startedAt: json['startedAt'] != null
          ? DateTime.parse(json['startedAt'].toString())
          : DateTime.now(),
      answeredAt: json['answeredAt'] != null
          ? DateTime.parse(json['answeredAt'].toString())
          : null,
      endedAt: json['endedAt'] != null
          ? DateTime.parse(json['endedAt'].toString())
          : null,
      duration: json['duration'] is int
          ? json['duration']
          : (json['duration'] is String
              ? int.tryParse(json['duration']) ?? 0
              : 0),
      isGroupChat: json['isGroupChat'] == true,
      qualityMetrics: json['qualityMetrics'] is Map
          ? Map<String, dynamic>.from(json['qualityMetrics'])
          : null,
    );
  }

  String get formattedDuration {
    final hours = duration ~/ 3600;
    final minutes = (duration % 3600) ~/ 60;
    final seconds = duration % 60;
    
    if (hours > 0) {
      return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    }
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  String get statusDisplay {
    switch (status.toLowerCase()) {
      case 'completed':
        return 'Completed';
      case 'missed':
        return 'Missed';
      case 'rejected':
        return 'Rejected';
      case 'cancelled':
        return 'Cancelled';
      default:
        return status;
    }
  }
}

