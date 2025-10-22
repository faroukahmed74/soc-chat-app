// =============================================================================
// SOC CHAT APP - MAIN ENTRY POINT (FIXED NOTIFICATIONS)
// =============================================================================

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
// Physical Server Only - No Firebase
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter/foundation.dart';
import 'dart:developer' as developer;
import 'dart:convert';
import 'package:http/http.dart' as http;
// Avoid direct dart:io on web; use conditional imports for io-heavy services

import 'config/database_config.dart';

import 'screens/login_screen.dart';

import 'package:shared_preferences/shared_preferences.dart';

import 'services/theme_service.dart';
import 'services/localization_service.dart';
// Firebase services removed - using MongoDB/ngrok API only
import 'services/local_message_storage.dart';
import 'services/local_auth_service.dart';

import 'services/enhanced_notification_service.dart';
import 'services/logger_service.dart';
import 'widgets/error_boundary.dart';
import 'routes/native_routes.dart' if (dart.library.html) 'routes/web_routes.dart' as app_routes;
import 'screens/chat_list_screen_mongodb.dart';
import 'services/realtime_service.dart';
import 'services/active_chat_service.dart';

// =============================================================================
// GLOBAL NAVIGATOR KEY
// =============================================================================
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

// =============================================================================
// BACKGROUND HANDLERS (TOP-LEVEL)
// =============================================================================
// Physical server mode - no Firebase background handlers needed

// =============================================================================
// MAIN
// =============================================================================
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  GlobalErrorHandler.initialize();
  Log.i('Starting SOC Chat App initialization', 'MAIN');

  // Initialize runtime server URL override and remote discovery
  try {
    await DatabaseConfig.initialize();
    Log.i('DatabaseConfig initialized (server URL override ready)', 'MAIN');
    // Log resolved server URL for visibility in logcat
    Log.i('Resolved server URL: ' + DatabaseConfig.physicalServerUrl, 'MAIN');
    // Ping API health to verify reachability from device
    await _pingApiHealth();
  } catch (e, st) {
    Log.e('DatabaseConfig initialization failed', 'MAIN', e, st);
    // Continue anyway - app should still work with defaults
  }

  // Physical Server Only - MongoDB/ngrok API mode
  Log.i('Using physical server only - MongoDB/ngrok API mode', 'MAIN');

  // Initialize app services for physical server
  try {
    // Initialize services for physical server mode
    Log.i('Initializing services for physical server mode', 'MAIN');
    await LocalAuthService.initialize();
    // SecureMessageService removed - using MongoDB/ngrok API only
    await LocalMessageStorage.initialize();
  } catch (e, st) {
    Log.e('Failed to initialize app services', 'MAIN', e, st);
    // Don't report errors to avoid crashes - just continue
  }

  Log.i('Starting main app', 'MAIN');
  runApp(const MyApp());
}

Future<void> _pingApiHealth() async {
  try {
    final base = DatabaseConfig.physicalServerUrl;
    final url = base.endsWith('/') ? '${base}api/health' : '$base/api/health';
    Log.i('Pinging API health at: ' + url, 'MAIN');
    final resp = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 3));
    Log.i('API health status: ' + resp.statusCode.toString(), 'MAIN');
  } catch (e) {
    Log.e('API health ping failed', 'MAIN', e);
  }
}

// =============================================================================
// APP ROOT
// =============================================================================
class MyApp extends StatefulWidget {
  const MyApp({super.key});
  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with TickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  bool _showOnboarding = false;
  late ThemeService _themeService;
  Locale _currentLocale = const Locale('en');

  @override
  void initState() {
    super.initState();
    _themeService = ThemeService.instance;
    _currentLocale = _themeService.locale;
    _initializeThemeService();

    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1500), vsync: this);
    _fadeAnimation = CurvedAnimation(parent: _animationController, curve: Curves.easeIn);
    _animationController.forward();

    _checkOnboardingStatus();

    _themeService.addListener(() {
      if (!mounted) return;
      try {
        setState(() => _currentLocale = _themeService.locale);
        Log.i('Main app locale updated to: ${_themeService.locale.languageCode}', 'MAIN_APP');
      } catch (e) {
        Log.e('Error updating locale', 'MAIN_APP', e);
        setState(() => _currentLocale = const Locale('en'));
      }
    });
  }

  Future<void> _initializeThemeService() async {
    try {
      await _themeService.initialize();
      if (mounted) setState(() => _currentLocale = _themeService.locale);
    } catch (e) {
      Log.e('Error initializing theme service', 'MAIN_APP', e);
      if (mounted) setState(() => _currentLocale = const Locale('en'));
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _checkOnboardingStatus() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() => _showOnboarding = prefs.getBool('showOnboarding') ?? true);
  }

  void _finishOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('showOnboarding', false);
    setState(() => _showOnboarding = false);
  }

  @override
  Widget build(BuildContext context) {
    return ErrorBoundary(
      onError: () => Log.e('App-level error occurred', 'MAIN_APP'),
      child: AnimatedBuilder(
        animation: Listenable.merge([_fadeAnimation, _themeService]),
        builder: (context, child) {
          return MaterialApp(
            builder: (context, child) {
              ErrorWidget.builder = (FlutterErrorDetails errorDetails) {
                return Material(
                  child: Container(
                    color: Colors.white,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.error_outline, size: 64, color: Colors.red.shade300),
                        const SizedBox(height: 16),
                        const Text('Something went wrong',
                            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        Text('Error: ${errorDetails.exception}',
                            style: const TextStyle(fontSize: 16, color: Colors.grey),
                            textAlign: TextAlign.center),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: () => Navigator.of(context).pushReplacementNamed('/'),
                          child: const Text('Go to Home'),
                        ),
                      ],
                    ),
                  ),
                );
              };
              return child!;
            },
            title: AppLocalizations.getString('app_name', _currentLocale.languageCode),
            theme: ThemeService.lightTheme,
            darkTheme: ThemeService.darkTheme,
            themeMode: _themeService.themeMode,
            locale: _currentLocale,
            supportedLocales: LocalizationService.supportedLocales,
            navigatorKey: navigatorKey,
            routes: {
              '/': (_) => _showOnboarding ? WelcomeScreen(onFinish: _finishOnboarding) : const AuthGate(),
              ...app_routes.buildRoutes(_themeService),
            },
            debugShowCheckedModeBanner: false,
          );
        },
      ),
    );
  }
}

// =============================================================================
// WELCOME + AUTH GATE (unchanged except references)
// =============================================================================
class WelcomeScreen extends StatelessWidget {
  final VoidCallback onFinish;
  const WelcomeScreen({super.key, required this.onFinish});
  @override
  Widget build(BuildContext context) { /* ... same as yours ... */ return _WelcomeScaffold(onFinish); }
}
Widget _WelcomeScaffold(VoidCallback onFinish) {
  return Scaffold(
    body: Center(
      child: ElevatedButton(onPressed: onFinish, child: const Text('Get Started')),
    ),
  );
}

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  bool _isAuthenticated = false;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _checkAuthStatus();
  }

  Future<void> _checkAuthStatus() async {
    try {
      print('AuthGate: Starting authentication check...');
      
      // Simple check - just see if we have a token
      final token = await DatabaseConfig.getStoredAuthToken();
      print('AuthGate: Stored token exists: ${token.isNotEmpty}');
      
      bool isValid = false;
      if (token.isNotEmpty) {
        try {
          final base = DatabaseConfig.physicalServerUrl;
          final verifyUrl = base.endsWith('/') ? '${base}api/auth/verify' : '$base/api/auth/verify';
          final resp = await http
              .get(Uri.parse(verifyUrl), headers: {
                'Authorization': 'Bearer ' + token,
                'ngrok-skip-browser-warning': 'true',
              })
              .timeout(const Duration(seconds: 3));
          isValid = resp.statusCode == 200;
          print('AuthGate: Token verify status: ' + resp.statusCode.toString());
        } catch (e) {
          print('AuthGate: Token verify error: ' + e.toString());
          isValid = false;
        }
      }
      
      if (mounted) {
        setState(() {
          _isAuthenticated = token.isNotEmpty && isValid;
          _isLoading = false;
        });
      }
      
      if (token.isNotEmpty && isValid) {
        print('AuthGate: Valid token - showing MainApp');
      } else if (token.isNotEmpty && !isValid) {
        print('AuthGate: Invalid/expired token - redirecting to LoginScreen');
      } else {
        print('AuthGate: No token - showing LoginScreen');
      }
    } catch (e) {
      print('AuthGate: Auth check error: $e');
      if (mounted) {
        setState(() {
          _isAuthenticated = false;
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('AuthGate: Checking authentication...'),
            ],
          ),
        ),
      );
    }

    if (_isAuthenticated) {
      print('AuthGate: Showing MainApp');
      return const MainApp();
    } else {
      print('AuthGate: Showing LoginScreen');
      return const LoginScreen();
    }
  }

}

class _AccountLockedScreen extends StatelessWidget {
  const _AccountLockedScreen();
  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: Text('Account Locked')));
  }
}

// =============================================================================
// MAIN APP
// =============================================================================
class MainApp extends StatefulWidget {
  const MainApp({super.key});
  @override
  State<MainApp> createState() => _MainAppState();
}

class _MainAppState extends State<MainApp> {
  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    try {
      Log.i('Starting app initialization...', 'MAIN_APP');
      await _checkInitialPermissions(); // only checks, doesn’t request

      // ALWAYS initialize notifications (handles web/mobile inside)
      await _initializeNotifications();

      // Presence service removed - using MongoDB/ngrok API only
      Log.i('Presence service removed (physical server mode)', 'MAIN_APP');

      // Initialize global realtime listener for notifications
      try {
        final realtime = RealtimeService.instance;
        await realtime.connect();
        // Join all chats after login: lightweight approach is to rely on message events
        realtime.onNewMessage((msg) async {
          try {
            final chatId = (msg['chatId'] ?? msg['chat_id'] ?? '').toString();
            final senderName = (msg['senderName'] ?? 'Someone').toString();
            final content = (msg['content'] ?? '').toString();
            final active = ActiveChatService.instance.isActive(chatId);
            if (!active) {
              if (kIsWeb) {
                // On web, show a simple in-app SnackBar
                navigatorKey.currentState?.overlay?.context.mounted == true
                    ? ScaffoldMessenger.of(navigatorKey.currentState!.overlay!.context).showSnackBar(
                        SnackBar(content: Text('$senderName: $content')),
                      )
                    : null;
              } else {
                // On mobile, fire a local notification
                await EnhancedNotificationService().sendLocalNotification(
                  title: senderName,
                  body: content.isNotEmpty ? content : 'New message',
                  payload: json.encode({
                    'type': 'chat_message',
                    'chatId': chatId,
                    'senderId': (msg['senderId'] ?? '').toString(),
                    'senderName': senderName,
                    'timestamp': DateTime.now().toIso8601String(),
                  }),
                  channelId: 'chat_notifications',
                );
              }
            }
          } catch (e) {
            Log.e('Realtime message notify error', 'MAIN_APP', e);
          }
        });
      } catch (e) {
        Log.e('Realtime init failed', 'MAIN_APP', e);
      }

      Log.i('App initialization completed successfully', 'MAIN_APP');
    } catch (e) {
      Log.e('Error during app initialization', 'MAIN_APP', e);
    }
  }

  Future<void> _checkInitialPermissions() async {
    if (kIsWeb) return;
    final cameraStatus = await Permission.camera.status;
    final photosStatus = await Permission.photos.status;
    final microphoneStatus = await Permission.microphone.status;
    developer.log('Initial perms -> Camera:$cameraStatus Photos:$photosStatus Mic:$microphoneStatus', name: 'MainApp');
  }

  Future<void> _initializeNotifications() async {
    try {
      // Physical server mode - simplified notification handling
      Log.i('Physical server mode - initializing notifications', 'MAIN_APP');
      
      // Request basic notification permissions for mobile
      if (!kIsWeb) {
        try {
          final notif = await Permission.notification.request();
          if (!notif.isGranted) {
            Log.w('Notifications denied by user', 'MAIN_APP');
          } else {
            Log.i('Notifications granted', 'MAIN_APP');
          }
        } catch (e) {
          Log.e('Error requesting notification permission', 'MAIN_APP', e);
        }
      }

      // Initialize enhanced notification services for physical server
      try {
        final enhanced = EnhancedNotificationService();
        await enhanced.initialize();
        Log.i('Enhanced notification service initialized', 'MAIN_APP');
      } catch (e) {
        Log.e('Enhanced notification service failed', 'MAIN_APP', e);
      }

      // Send startup notification if user is logged in
      try {
        final prefs = await SharedPreferences.getInstance();
        final token = prefs.getString('auth_token');
        if (token != null) {
          await Future.delayed(const Duration(seconds: 2));
          Log.i('User logged in - startup notification sent', 'MAIN_APP');
        }
      } catch (e) {
        Log.e('Error sending startup notification', 'MAIN_APP', e);
      }
    } catch (e) {
      Log.e('Error initializing notifications', 'MAIN_APP', e);
    }
  }

  @override
  Widget build(BuildContext context) => const ChatListScreenMongoDB();
}

// =============================================================================
// OPTIONAL: checkNotificationPermission helper (kept, minor polish)
// =============================================================================
Future<bool> checkNotificationPermission() async {
  try {
    // Physical server mode - always return true for simplicity
    if (kIsWeb) return true;
    
    // For mobile platforms, check basic permission
    if (!kIsWeb) {
      try {
        final notif = await Permission.notification.status;
        return notif.isGranted;
      } catch (e) {
        Log.e('Error checking notification permission', 'MAIN_APP', e);
        return false;
      }
    }
    
    return true;
  } catch (e) {
    Log.e('Error checking notification permission', 'MAIN_APP', e);
    return false;
  }
}

// =============================================================================
// GLOBAL ERROR HANDLER
// =============================================================================
class GlobalErrorHandler {
  static void initialize() {
    // Set up global error handling
    FlutterError.onError = (FlutterErrorDetails details) {
      Log.e('Flutter Error', 'GLOBAL', details.exception, details.stack);
      ErrorReportingService.reportError(details.exception, details.stack, context: 'Flutter Error');
    };

    // Set up platform error handling
    PlatformDispatcher.instance.onError = (error, stack) {
      Log.e('Platform Error', 'GLOBAL', error, stack);
      ErrorReportingService.reportError(error, stack, context: 'Platform Error');
      return true;
    };
  }
}

// =============================================================================
// ERROR REPORTING SERVICE
// =============================================================================
class ErrorReportingService {
  static void reportError(dynamic error, StackTrace? stackTrace, {String? context}) {
    Log.e('Error reported', context ?? 'ERROR', error, stackTrace);
    // In a real app, you might want to send this to a crash reporting service
  }
}
