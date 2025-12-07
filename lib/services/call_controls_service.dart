import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../config/database_config.dart';
import 'logger_service.dart';
import 'realtime_service.dart';

/// Call Controls Service
/// Handles call control operations: forwarding, waiting, transfer, mute, screen sharing
class CallControlsService {
  static final CallControlsService _instance = CallControlsService._internal();
  factory CallControlsService() => _instance;
  CallControlsService._internal();

  final RealtimeService _realtime = RealtimeService.instance;

  /// Forward a call to another user
  Future<bool> forwardCall({
    required String callId,
    required String forwardToUserId,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');
      if (token == null) {
        Log.e('Cannot forward call: No auth token', 'CALL_CONTROLS');
        return false;
      }

      final baseUrl = DatabaseConfig.physicalServerUrl;
      final url = '$baseUrl/api/calls/forward';

      final response = await http.post(
        Uri.parse(url),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: json.encode({
          'callId': callId,
          'forwardToUserId': forwardToUserId,
        }),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        Log.i('Call forwarded: $callId to $forwardToUserId', 'CALL_CONTROLS');
        return true;
      } else {
        Log.e('Failed to forward call: ${response.statusCode} - ${response.body}', 'CALL_CONTROLS');
        return false;
      }
    } catch (e, stackTrace) {
      Log.e('Error forwarding call', 'CALL_CONTROLS', e, stackTrace);
      return false;
    }
  }

  /// Hold a call (for call waiting)
  Future<bool> holdCall(String callId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');
      if (token == null) {
        Log.e('Cannot hold call: No auth token', 'CALL_CONTROLS');
        return false;
      }

      final baseUrl = DatabaseConfig.physicalServerUrl;
      final url = '$baseUrl/api/calls/waiting/hold';

      final response = await http.post(
        Uri.parse(url),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: json.encode({
          'callId': callId,
        }),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        Log.i('Call held: $callId', 'CALL_CONTROLS');
        return true;
      } else {
        Log.e('Failed to hold call: ${response.statusCode} - ${response.body}', 'CALL_CONTROLS');
        return false;
      }
    } catch (e, stackTrace) {
      Log.e('Error holding call', 'CALL_CONTROLS', e, stackTrace);
      return false;
    }
  }

  /// Resume a held call
  Future<bool> resumeCall(String callId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');
      if (token == null) {
        Log.e('Cannot resume call: No auth token', 'CALL_CONTROLS');
        return false;
      }

      final baseUrl = DatabaseConfig.physicalServerUrl;
      final url = '$baseUrl/api/calls/waiting/resume';

      final response = await http.post(
        Uri.parse(url),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: json.encode({
          'callId': callId,
        }),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        Log.i('Call resumed: $callId', 'CALL_CONTROLS');
        return true;
      } else {
        Log.e('Failed to resume call: ${response.statusCode} - ${response.body}', 'CALL_CONTROLS');
        return false;
      }
    } catch (e, stackTrace) {
      Log.e('Error resuming call', 'CALL_CONTROLS', e, stackTrace);
      return false;
    }
  }

  /// Transfer a call to another user
  Future<bool> transferCall({
    required String callId,
    required String transferToUserId,
    String transferType = 'blind', // 'blind' or 'attended'
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');
      if (token == null) {
        Log.e('Cannot transfer call: No auth token', 'CALL_CONTROLS');
        return false;
      }

      final baseUrl = DatabaseConfig.physicalServerUrl;
      final url = '$baseUrl/api/calls/transfer';

      final response = await http.post(
        Uri.parse(url),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: json.encode({
          'callId': callId,
          'transferToUserId': transferToUserId,
          'transferType': transferType,
        }),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        Log.i('Call transferred: $callId to $transferToUserId', 'CALL_CONTROLS');
        return true;
      } else {
        Log.e('Failed to transfer call: ${response.statusCode} - ${response.body}', 'CALL_CONTROLS');
        return false;
      }
    } catch (e, stackTrace) {
      Log.e('Error transferring call', 'CALL_CONTROLS', e, stackTrace);
      return false;
    }
  }

  /// Mute a participant in a group call
  Future<bool> muteParticipant({
    required String callId,
    required String participantId,
    bool muted = true,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');
      if (token == null) {
        Log.e('Cannot mute participant: No auth token', 'CALL_CONTROLS');
        return false;
      }

      final baseUrl = DatabaseConfig.physicalServerUrl;
      final url = '$baseUrl/api/calls/participants/mute';

      final response = await http.post(
        Uri.parse(url),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: json.encode({
          'callId': callId,
          'participantId': participantId,
          'muted': muted,
        }),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        Log.i('Participant ${muted ? 'muted' : 'unmuted'}: $participantId in call $callId', 'CALL_CONTROLS');
        return true;
      } else {
        Log.e('Failed to mute participant: ${response.statusCode} - ${response.body}', 'CALL_CONTROLS');
        return false;
      }
    } catch (e, stackTrace) {
      Log.e('Error muting participant', 'CALL_CONTROLS', e, stackTrace);
      return false;
    }
  }

  /// Mute all participants in a group call
  Future<bool> muteAllParticipants({
    required String callId,
    bool muted = true,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');
      if (token == null) {
        Log.e('Cannot mute all participants: No auth token', 'CALL_CONTROLS');
        return false;
      }

      final baseUrl = DatabaseConfig.physicalServerUrl;
      final url = '$baseUrl/api/calls/participants/mute-all';

      final response = await http.post(
        Uri.parse(url),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: json.encode({
          'callId': callId,
          'muted': muted,
        }),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        Log.i('All participants ${muted ? 'muted' : 'unmuted'} in call $callId', 'CALL_CONTROLS');
        return true;
      } else {
        Log.e('Failed to mute all participants: ${response.statusCode} - ${response.body}', 'CALL_CONTROLS');
        return false;
      }
    } catch (e, stackTrace) {
      Log.e('Error muting all participants', 'CALL_CONTROLS', e, stackTrace);
      return false;
    }
  }

  /// Start screen sharing
  Future<bool> startScreenShare(String callId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');
      if (token == null) {
        Log.e('Cannot start screen share: No auth token', 'CALL_CONTROLS');
        return false;
      }

      final baseUrl = DatabaseConfig.physicalServerUrl;
      final url = '$baseUrl/api/calls/screen-share/start';

      final response = await http.post(
        Uri.parse(url),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: json.encode({
          'callId': callId,
        }),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        Log.i('Screen sharing started: $callId', 'CALL_CONTROLS');
        return true;
      } else {
        Log.e('Failed to start screen share: ${response.statusCode} - ${response.body}', 'CALL_CONTROLS');
        return false;
      }
    } catch (e, stackTrace) {
      Log.e('Error starting screen share', 'CALL_CONTROLS', e, stackTrace);
      return false;
    }
  }

  /// Stop screen sharing
  Future<bool> stopScreenShare(String callId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');
      if (token == null) {
        Log.e('Cannot stop screen share: No auth token', 'CALL_CONTROLS');
        return false;
      }

      final baseUrl = DatabaseConfig.physicalServerUrl;
      final url = '$baseUrl/api/calls/screen-share/stop';

      final response = await http.post(
        Uri.parse(url),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: json.encode({
          'callId': callId,
        }),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        Log.i('Screen sharing stopped: $callId', 'CALL_CONTROLS');
        return true;
      } else {
        Log.e('Failed to stop screen share: ${response.statusCode} - ${response.body}', 'CALL_CONTROLS');
        return false;
      }
    } catch (e, stackTrace) {
      Log.e('Error stopping screen share', 'CALL_CONTROLS', e, stackTrace);
      return false;
    }
  }

  /// Listen for call control events
  void onCallForwarded(Function(dynamic) handler) {
    _realtime.on('call_forwarded', (data) {
      if (data is Map<String, dynamic>) {
        handler(data);
      }
    });
  }

  void onCallHeld(Function(dynamic) handler) {
    _realtime.on('call_held', (data) {
      if (data is Map<String, dynamic>) {
        handler(data);
      }
    });
  }

  void onCallResumed(Function(dynamic) handler) {
    _realtime.on('call_resumed', (data) {
      if (data is Map<String, dynamic>) {
        handler(data);
      }
    });
  }

  void onCallTransferred(Function(dynamic) handler) {
    _realtime.on('call_transferred', (data) {
      if (data is Map<String, dynamic>) {
        handler(data);
      }
    });
  }

  void onParticipantMuted(Function(dynamic) handler) {
    _realtime.on('participant_muted', (data) {
      if (data is Map<String, dynamic>) {
        handler(data);
      }
    });
  }

  void onAllParticipantsMuted(Function(dynamic) handler) {
    _realtime.on('all_participants_muted', (data) {
      if (data is Map<String, dynamic>) {
        handler(data);
      }
    });
  }

  void onScreenShareStarted(Function(dynamic) handler) {
    _realtime.on('screen_share_started', (data) {
      if (data is Map<String, dynamic>) {
        handler(data);
      }
    });
  }

  void onScreenShareStopped(Function(dynamic) handler) {
    _realtime.on('screen_share_stopped', (data) {
      if (data is Map<String, dynamic>) {
        handler(data);
      }
    });
  }
}

