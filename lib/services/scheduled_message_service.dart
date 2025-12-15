import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'logger_service.dart' as Log;

/// Service for managing scheduled messages
class ScheduledMessageService {
  static final ScheduledMessageService _instance = ScheduledMessageService._internal();
  factory ScheduledMessageService() => _instance;
  ScheduledMessageService._internal();

  static const String _scheduledMessagesKey = 'scheduled_messages';
  Timer? _checkTimer;

  /// Initialize the service and start checking for scheduled messages
  Future<void> initialize() async {
    _startPeriodicCheck();
    Log.LoggerService.info('Scheduled message service initialized', 'SCHEDULED_MESSAGE');
  }

  /// Start periodic check for scheduled messages (every 30 seconds)
  void _startPeriodicCheck() {
    _checkTimer?.cancel();
    _checkTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      _checkAndSendScheduledMessages();
    });
  }

  /// Schedule a message to be sent at a specific time
  Future<String> scheduleMessage({
    required String chatId,
    required String content,
    required DateTime scheduledTime,
    String messageType = 'text',
    String? mediaUrl,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final scheduledMessages = await getScheduledMessages();
      
      final scheduledMessage = {
        'id': DateTime.now().millisecondsSinceEpoch.toString(),
        'chatId': chatId,
        'content': content,
        'messageType': messageType,
        'mediaUrl': mediaUrl,
        'scheduledTime': scheduledTime.toIso8601String(),
        'createdAt': DateTime.now().toIso8601String(),
      };
      
      scheduledMessages.add(scheduledMessage);
      
      await prefs.setString(
        _scheduledMessagesKey,
        jsonEncode(scheduledMessages),
      );
      
      Log.LoggerService.info('Message scheduled for ${scheduledTime.toIso8601String()}', 'SCHEDULED_MESSAGE');
      return scheduledMessage['id'] as String;
    } catch (e) {
      Log.LoggerService.error('Error scheduling message', 'SCHEDULED_MESSAGE', e);
      rethrow;
    }
  }

  /// Get all scheduled messages
  Future<List<Map<String, dynamic>>> getScheduledMessages() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = prefs.getString(_scheduledMessagesKey);
      if (jsonString == null || jsonString.isEmpty) {
        return [];
      }
      final List<dynamic> decoded = jsonDecode(jsonString);
      return decoded.map((item) => Map<String, dynamic>.from(item)).toList();
    } catch (e) {
      Log.LoggerService.error('Error getting scheduled messages', 'SCHEDULED_MESSAGE', e);
      return [];
    }
  }

  /// Get scheduled messages for a specific chat
  Future<List<Map<String, dynamic>>> getScheduledMessagesForChat(String chatId) async {
    final allMessages = await getScheduledMessages();
    return allMessages.where((msg) => msg['chatId'] == chatId).toList();
  }

  /// Cancel a scheduled message
  Future<bool> cancelScheduledMessage(String messageId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final scheduledMessages = await getScheduledMessages();
      final updatedMessages = scheduledMessages.where((msg) => msg['id'] != messageId).toList();
      
      await prefs.setString(
        _scheduledMessagesKey,
        jsonEncode(updatedMessages),
      );
      
      Log.LoggerService.info('Scheduled message cancelled: $messageId', 'SCHEDULED_MESSAGE');
      return true;
    } catch (e) {
      Log.LoggerService.error('Error cancelling scheduled message', 'SCHEDULED_MESSAGE', e);
      return false;
    }
  }

  /// Check and send scheduled messages that are due
  Future<void> _checkAndSendScheduledMessages() async {
    try {
      final scheduledMessages = await getScheduledMessages();
      final now = DateTime.now();
      final messagesToSend = <Map<String, dynamic>>[];
      
      for (final message in scheduledMessages) {
        final scheduledTime = DateTime.parse(message['scheduledTime'] as String);
        if (scheduledTime.isBefore(now) || scheduledTime.isAtSameMomentAs(now)) {
          messagesToSend.add(message);
        }
      }
      
      if (messagesToSend.isNotEmpty) {
        Log.LoggerService.info('Found ${messagesToSend.length} scheduled messages to send', 'SCHEDULED_MESSAGE');
        // The actual sending will be handled by the callback provided by the chat screen
        // This service just manages the storage and checking
      }
    } catch (e) {
      Log.LoggerService.error('Error checking scheduled messages', 'SCHEDULED_MESSAGE', e);
    }
  }

  /// Get messages that are ready to be sent (due now or in the past)
  Future<List<Map<String, dynamic>>> getMessagesReadyToSend() async {
    try {
      final scheduledMessages = await getScheduledMessages();
      final now = DateTime.now();
      
      return scheduledMessages.where((message) {
        final scheduledTime = DateTime.parse(message['scheduledTime'] as String);
        return scheduledTime.isBefore(now) || scheduledTime.isAtSameMomentAs(now);
      }).toList();
    } catch (e) {
      Log.LoggerService.error('Error getting messages ready to send', 'SCHEDULED_MESSAGE', e);
      return [];
    }
  }

  /// Remove a message after it's been sent
  Future<void> removeScheduledMessage(String messageId) async {
    await cancelScheduledMessage(messageId);
  }

  /// Dispose resources
  void dispose() {
    _checkTimer?.cancel();
    _checkTimer = null;
  }
}

