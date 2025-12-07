import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../config/database_config.dart';
import 'logger_service.dart';
import 'realtime_service.dart';

/// Call Scheduling Service
/// Handles scheduling calls for future dates
class CallSchedulingService {
  static final CallSchedulingService _instance = CallSchedulingService._internal();
  factory CallSchedulingService() => _instance;
  CallSchedulingService._internal();

  final RealtimeService _realtime = RealtimeService.instance;

  /// Schedule a call
  Future<Map<String, dynamic>?> scheduleCall({
    required String chatId,
    required String chatName,
    required List<String> participantIds,
    required String callType, // 'voice' or 'video'
    required DateTime scheduledAt,
    int reminderMinutes = 15,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');
      if (token == null) {
        Log.e('Cannot schedule call: No auth token', 'CALL_SCHEDULING');
        return null;
      }

      final baseUrl = DatabaseConfig.physicalServerUrl;
      final url = '$baseUrl/api/calls/schedule';

      final response = await http.post(
        Uri.parse(url),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: json.encode({
          'chatId': chatId,
          'chatName': chatName,
          'participantIds': participantIds,
          'callType': callType,
          'scheduledAt': scheduledAt.toIso8601String(),
          'reminderMinutes': reminderMinutes,
        }),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          Log.i('Call scheduled: ${data['scheduledCallId']}', 'CALL_SCHEDULING');
          return data;
        } else {
          Log.e('Failed to schedule call: ${data['error']}', 'CALL_SCHEDULING');
          return null;
        }
      } else {
        Log.e('Failed to schedule call: ${response.statusCode} - ${response.body}', 'CALL_SCHEDULING');
        return null;
      }
    } catch (e, stackTrace) {
      Log.e('Error scheduling call', 'CALL_SCHEDULING', e, stackTrace);
      return null;
    }
  }

  /// Get scheduled calls
  Future<List<Map<String, dynamic>>> getScheduledCalls({bool upcoming = true}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');
      if (token == null) {
        Log.e('Cannot get scheduled calls: No auth token', 'CALL_SCHEDULING');
        return [];
      }

      final baseUrl = DatabaseConfig.physicalServerUrl;
      final url = '$baseUrl/api/calls/schedule?upcoming=$upcoming';

      final response = await http.get(
        Uri.parse(url),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true && data['scheduledCalls'] != null) {
          return List<Map<String, dynamic>>.from(data['scheduledCalls']);
        }
      }
      return [];
    } catch (e, stackTrace) {
      Log.e('Error getting scheduled calls', 'CALL_SCHEDULING', e, stackTrace);
      return [];
    }
  }

  /// Cancel a scheduled call
  Future<bool> cancelScheduledCall(String scheduledCallId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');
      if (token == null) {
        Log.e('Cannot cancel scheduled call: No auth token', 'CALL_SCHEDULING');
        return false;
      }

      final baseUrl = DatabaseConfig.physicalServerUrl;
      final url = '$baseUrl/api/calls/schedule/$scheduledCallId';

      final response = await http.delete(
        Uri.parse(url),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        Log.i('Scheduled call cancelled: $scheduledCallId', 'CALL_SCHEDULING');
        return true;
      } else {
        Log.e('Failed to cancel scheduled call: ${response.statusCode} - ${response.body}', 'CALL_SCHEDULING');
        return false;
      }
    } catch (e, stackTrace) {
      Log.e('Error cancelling scheduled call', 'CALL_SCHEDULING', e, stackTrace);
      return false;
    }
  }

  /// Listen for scheduled call notifications
  void onCallScheduled(Function(Map<String, dynamic>) handler) {
    _realtime.on('call_scheduled', handler);
  }
}

/// Scheduled Call Model
class ScheduledCall {
  final String scheduledCallId;
  final String chatId;
  final String chatName;
  final String callerId;
  final List<String> participantIds;
  final String callType;
  final DateTime scheduledAt;
  final int reminderMinutes;
  final String status; // 'scheduled', 'completed', 'cancelled'
  final DateTime createdAt;

  ScheduledCall({
    required this.scheduledCallId,
    required this.chatId,
    required this.chatName,
    required this.callerId,
    required this.participantIds,
    required this.callType,
    required this.scheduledAt,
    required this.reminderMinutes,
    required this.status,
    required this.createdAt,
  });

  factory ScheduledCall.fromJson(Map<String, dynamic> json) {
    return ScheduledCall(
      scheduledCallId: json['_id']?.toString() ?? json['scheduledCallId']?.toString() ?? '',
      chatId: json['chatId']?.toString() ?? '',
      chatName: json['chatName']?.toString() ?? 'Unknown',
      callerId: json['callerId']?.toString() ?? '',
      participantIds: (json['participantIds'] as List<dynamic>?)
              ?.map((id) => id.toString())
              .toList() ??
          [],
      callType: json['callType']?.toString() ?? 'voice',
      scheduledAt: json['scheduledAt'] != null
          ? DateTime.parse(json['scheduledAt'].toString())
          : DateTime.now(),
      reminderMinutes: json['reminderMinutes'] is int
          ? json['reminderMinutes']
          : (json['reminderMinutes'] is String
              ? int.tryParse(json['reminderMinutes']) ?? 15
              : 15),
      status: json['status']?.toString() ?? 'scheduled',
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'].toString())
          : DateTime.now(),
    );
  }

  bool get isUpcoming => scheduledAt.isAfter(DateTime.now()) && status == 'scheduled';
  bool get isPast => scheduledAt.isBefore(DateTime.now());
}

