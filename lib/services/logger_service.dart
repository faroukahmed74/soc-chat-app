import 'package:flutter/foundation.dart';
import 'dart:developer' as developer;

/// Centralized logging service for the SOC Chat App
/// Provides structured logging with different levels and proper formatting
class LoggerService {
  static final LoggerService _instance = LoggerService._internal();
  factory LoggerService() => _instance;
  LoggerService._internal();

  // Log levels
  static const String _debug = '🔍 DEBUG';
  static const String _info = 'ℹ️ INFO';
  static const String _warning = '⚠️ WARNING';
  static const String _error = '❌ ERROR';
  static const String _critical = '🚨 CRITICAL';

  /// Debug level logging
  static void debug(String message, [String? tag, Object? error, StackTrace? stackTrace]) {
    _log(_debug, message, tag, error, stackTrace);
  }

  /// Info level logging
  static void info(String message, [String? tag, Object? error, StackTrace? stackTrace]) {
    _log(_info, message, tag, error, stackTrace);
  }

  /// Warning level logging
  static void warning(String message, [String? tag, Object? error, StackTrace? stackTrace]) {
    _log(_warning, message, tag, error, stackTrace);
  }

  /// Error level logging
  static void error(String message, [String? tag, Object? error, StackTrace? stackTrace]) {
    _log(_error, message, tag, error, stackTrace);
  }

  /// Critical level logging
  static void critical(String message, [String? tag, Object? error, StackTrace? stackTrace]) {
    _log(_critical, message, tag, error, stackTrace);
  }

  /// Internal logging method
  static void _log(String level, String message, String? tag, Object? error, StackTrace? stackTrace) {
    final timestamp = DateTime.now().toIso8601String();
    final tagPrefix = tag != null ? '[$tag]' : '';
    final logMessage = '$timestamp $level$tagPrefix: $message';
    
    if (kDebugMode) {
      // In debug mode, use developer.log for better debugging
      developer.log(
        logMessage,
        name: 'SOC_CHAT_APP',
        level: _getLogLevel(level),
        error: error,
        stackTrace: stackTrace,
      );
    } else {
      // In production, use structured logging
      _logToProduction(logMessage, level, tag, error, stackTrace);
    }
  }

  /// Get log level for developer.log
  static int _getLogLevel(String level) {
    switch (level) {
      case _debug:
        return 500; // ALL
      case _info:
        return 800; // INFO
      case _warning:
        return 900; // WARNING
      case _error:
        return 1000; // ERROR
      case _critical:
        return 1200; // SEVERE
      default:
        return 800; // INFO
    }
  }

  /// Production logging (can be extended to send to external services)
  static void _logToProduction(String message, String level, String? tag, Object? error, StackTrace? stackTrace) {
    // In production, you can:
    // - Send logs to external services (Firebase Analytics, Crashlytics, etc.)
    // - Store logs locally for debugging
    // - Filter logs based on level
    
    if (level == _error || level == _critical) {
      // Always log errors and critical issues
      developer.log(
        message,
        name: 'SOC_CHAT_APP_PROD',
        level: _getLogLevel(level),
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  /// Log method calls for debugging
  static void logMethodCall(String methodName, [Map<String, dynamic>? parameters]) {
    final params = parameters != null ? ' with params: $parameters' : '';
    debug('Method called: $methodName$params', 'METHOD_CALL');
  }

  /// Log API calls
  static void logApiCall(String endpoint, [String? method, int? statusCode, String? response]) {
    final methodStr = method ?? 'GET';
    final statusStr = statusCode != null ? ' ($statusCode)' : '';
    final responseStr = response != null ? ' - Response: ${response.length > 100 ? '${response.substring(0, 100)}...' : response}' : '';
    
    info('API $methodStr: $endpoint$statusStr$responseStr', 'API_CALL');
  }

  /// Log user actions for analytics
  static void logUserAction(String action, [Map<String, dynamic>? context]) {
    final contextStr = context != null ? ' - Context: $context' : '';
    info('User action: $action$contextStr', 'USER_ACTION');
  }

  /// Log performance metrics
  static void logPerformance(String operation, Duration duration, [String? tag]) {
    final durationMs = duration.inMilliseconds;
    if (durationMs > 100) {
      warning('Performance issue: $operation took ${durationMs}ms', tag ?? 'PERFORMANCE');
    } else {
      debug('Performance: $operation took ${durationMs}ms', tag ?? 'PERFORMANCE');
    }
  }
}

/// Convenience methods for quick logging
class Log {
  static void d(String message, [String? tag]) => LoggerService.debug(message, tag);
  static void i(String message, [String? tag]) => LoggerService.info(message, tag);
  static void w(String message, [String? tag]) => LoggerService.warning(message, tag);
  static void e(String message, [String? tag, Object? error, StackTrace? stackTrace]) => 
      LoggerService.error(message, tag, error, stackTrace);
  static void c(String message, [String? tag, Object? error, StackTrace? stackTrace]) => 
      LoggerService.critical(message, tag, error, stackTrace);
}
