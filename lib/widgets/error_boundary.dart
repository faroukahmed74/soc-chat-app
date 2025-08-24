import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import '../services/logger_service.dart';

/// Error boundary widget that catches errors and displays a fallback UI
/// This prevents the entire app from crashing when errors occur
class ErrorBoundary extends StatefulWidget {
  final Widget child;
  final Widget Function(Object error, StackTrace? stackTrace)? errorBuilder;
  final VoidCallback? onError;

  const ErrorBoundary({
    super.key,
    required this.child,
    this.errorBuilder,
    this.onError,
  });

  @override
  State<ErrorBoundary> createState() => _ErrorBoundaryState();
}

class _ErrorBoundaryState extends State<ErrorBoundary> {
  Object? _error;
  StackTrace? _stackTrace;

  @override
  void initState() {
    super.initState();
    // Set up error handling for the widget tree
    // Only set if not already set to avoid conflicts
    if (FlutterError.onError == null) {
      FlutterError.onError = _handleFlutterError;
    }
  }

  @override
  void dispose() {
    // Only clear if we set it
    if (FlutterError.onError == _handleFlutterError) {
      FlutterError.onError = null;
    }
    super.dispose();
  }

  void _handleFlutterError(FlutterErrorDetails details) {
    Log.e('Flutter error caught by ErrorBoundary', 'ERROR_BOUNDARY', details.exception, details.stack);
    // Use a post-frame callback to avoid build context issues
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _setError(details.exception, details.stack);
      }
    });
  }

  void _setError(Object error, StackTrace? stackTrace) {
    if (mounted) {
      try {
        setState(() {
          _error = error;
          _stackTrace = stackTrace;
        });
        
        // Call error callback if provided
        widget.onError?.call();
        
        // Log the error
        Log.e('Error boundary caught error', 'ERROR_BOUNDARY', error, stackTrace);
      } catch (e) {
        // If setState fails, just log the error without updating state
        Log.e('Failed to update error boundary state', 'ERROR_BOUNDARY', e);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return widget.errorBuilder?.call(_error!, _stackTrace) ?? 
             _defaultErrorBuilder(context, _error!, _stackTrace);
    }
    
    return widget.child;
  }

  Widget _defaultErrorBuilder(BuildContext context, Object error, StackTrace? stackTrace) {
    return Material(
      child: Container(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.error_outline,
              size: 64,
              color: Colors.red,
            ),
            const SizedBox(height: 16),
            const Text(
              'Something went wrong',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'We encountered an unexpected error. Please try again.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () {
                if (mounted) {
                  try {
                    setState(() {
                      _error = null;
                      _stackTrace = null;
                    });
                  } catch (e) {
                    Log.e('Failed to reset error boundary', 'ERROR_BOUNDARY', e);
                  }
                }
              },
              child: const Text('Try Again'),
            ),
            if (kDebugMode) ...[
              const SizedBox(height: 16),
              ExpansionTile(
                title: const Text('Error Details (Debug)'),
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Error: ${error.toString()}',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        if (stackTrace != null) ...[
                          const SizedBox(height: 8),
                          const Text('Stack Trace:', style: TextStyle(fontWeight: FontWeight.bold)),
                          const SizedBox(height: 4),
                          Text(
                            stackTrace.toString(),
                            style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Error boundary for specific sections of the app
class SectionErrorBoundary extends StatelessWidget {
  final Widget child;
  final String sectionName;
  final Widget Function(Object error, StackTrace? stackTrace)? errorBuilder;

  const SectionErrorBoundary({
    super.key,
    required this.child,
    required this.sectionName,
    this.errorBuilder,
  });

  @override
  Widget build(BuildContext context) {
    return ErrorBoundary(
      errorBuilder: errorBuilder ?? (error, stackTrace) => _sectionErrorBuilder(context, error, stackTrace),
      onError: () => Log.e('Section error: $sectionName', 'SECTION_ERROR'),
      child: child,
    );
  }

  Widget _sectionErrorBuilder(BuildContext context, Object error, StackTrace? stackTrace) {
    return Container(
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.red[50],
        border: Border.all(color: Colors.red[200] ?? Colors.red),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(Icons.error_outline, color: Colors.red[600]!),
              const SizedBox(width: 8),
              Text(
                'Error in $sectionName',
                style: TextStyle(
                  color: Colors.red[600]!,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'This section encountered an error. Please refresh or try again later.',
                         style: TextStyle(color: Colors.red[600]!),
          ),
        ],
      ),
    );
  }
}

/// Global error handler for the entire app
class GlobalErrorHandler {
  static void initialize() {
    // Handle errors that occur during the build phase
    FlutterError.onError = (FlutterErrorDetails details) {
      Log.e('Global Flutter error', 'GLOBAL_ERROR', details.exception, details.stack);
      FlutterError.presentError(details);
    };

    // Handle errors that occur in the platform channel
    PlatformDispatcher.instance.onError = (Object error, StackTrace stackTrace) {
      Log.e('Platform error', 'PLATFORM_ERROR', error, stackTrace);
      return true; // Return true to prevent the error from being re-thrown
    };
  }
}

/// Error reporting service for production
class ErrorReportingService {
  static void reportError(
    Object error,
    StackTrace? stackTrace, {
    String? context,
    Map<String, dynamic>? additionalData,
  }) {
    Log.e('Error reported', 'ERROR_REPORTING', error, stackTrace);
    
    // In production, you can:
    // - Send to Firebase Crashlytics
    // - Send to external error tracking services
    // - Store locally for debugging
    
    if (kDebugMode) {
      // In debug mode, just log the error
      Log.e('Error in context: $context', 'ERROR_REPORTING', error, stackTrace);
      if (additionalData != null) {
        Log.d('Additional data: $additionalData', 'ERROR_REPORTING');
      }
    } else {
      // In production, send to error tracking service
      _sendToErrorTrackingService(error, stackTrace, context, additionalData);
    }
  }

  static void _sendToErrorTrackingService(
    Object error,
    StackTrace? stackTrace,
    String? context,
    Map<String, dynamic>? additionalData,
  ) {
    // Implementation for production error tracking
    // This could integrate with Firebase Crashlytics, Sentry, etc.
    Log.i('Sending error to tracking service', 'ERROR_REPORTING');
  }
}
