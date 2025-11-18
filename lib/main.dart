// =============================================================================
// SOC CHAT APP - MAIN ENTRY POINT (FIXED NOTIFICATIONS)
// =============================================================================

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
// Physical Server Only - No Firebase
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter/foundation.dart';
import 'dart:developer' as developer;
import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
// Avoid direct dart:io on web; use conditional imports for io-heavy services

import 'config/database_config.dart';

import 'screens/login_screen.dart';
import 'screens/modern_login_screen.dart';
import 'screens/modern_register_screen.dart';
import 'theme/app_design_system.dart';

import 'package:shared_preferences/shared_preferences.dart';

import 'services/theme_service.dart';
import 'services/localization_service.dart';
// Firebase services removed - using MongoDB/ngrok API only
import 'services/local_message_storage.dart';
import 'services/local_auth_service.dart';
import 'services/media_cache_service.dart';

import 'services/enhanced_notification_service.dart';
import 'services/logger_service.dart';
import 'widgets/error_boundary.dart';
import 'routes/native_routes.dart' if (dart.library.html) 'routes/web_routes.dart' as app_routes;
import 'screens/chat_list_screen_mongodb.dart';
import 'services/realtime_service.dart';
import 'services/active_chat_service.dart';
import 'services/message_sound_service.dart';
import 'services/background_service_manager.dart';
import 'services/ios_notification_service.dart';
import 'services/fcm_service.dart';
import 'package:firebase_core/firebase_core.dart';
import 'dart:io' if (dart.library.html) 'dart:html' as io;

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
    // Ping API health to verify reachability from device (non-blocking for web)
    if (kIsWeb) {
      // For web, don't block startup - ping in background
      _pingApiHealth().catchError((e) {
        Log.e('API health ping failed (non-blocking)', 'MAIN', e);
      });
    } else {
      // For mobile, ping synchronously but don't block if it fails
      await _pingApiHealth();
    }
  } catch (e, st) {
    Log.e('DatabaseConfig initialization failed', 'MAIN', e, st);
    // Continue anyway - app should still work with defaults
  }

  // Physical Server Only - MongoDB/ngrok API mode
  Log.i('Using physical server only - MongoDB/ngrok API mode', 'MAIN');

  // Initialize Firebase (required for FCM push notifications only)
  // Note: We use MongoDB for database, but Firebase is needed for FCM
  // For web offline mode, Firebase is optional and non-blocking
  if (kIsWeb) {
    // On web, initialize Firebase in background (non-blocking)
    Firebase.initializeApp().then((_) {
      Log.i('✅ Firebase initialized successfully (for FCM only)', 'MAIN');
    }).catchError((e) {
      Log.e('Firebase initialization failed - FCM notifications will not work', 'MAIN', e);
      // Continue without Firebase - app will work but no push notifications
    });
  } else {
    // On mobile, initialize Firebase with timeout
    try {
      Log.i('Initializing Firebase for FCM notifications...', 'MAIN');
      await Firebase.initializeApp().timeout(
        const Duration(seconds: 5),
        onTimeout: () {
          Log.e('Firebase initialization timeout - continuing without FCM', 'MAIN');
          throw TimeoutException('Firebase initialization timeout');
        },
      );
      Log.i('✅ Firebase initialized successfully (for FCM only)', 'MAIN');
    } catch (e) {
      Log.e('Firebase initialization failed - FCM notifications will not work', 'MAIN', e);
      // Continue without Firebase - app will work but no push notifications
    }
  }

  // Initialize app services for physical server
  try {
    // Initialize services for physical server mode
    Log.i('Initializing services for physical server mode', 'MAIN');
    await LocalAuthService.initialize();
    // SecureMessageService removed - using MongoDB/ngrok API only
    await LocalMessageStorage.initialize();
    
    // Initialize media cache service with error handling
    try {
      await MediaCacheService.initialize();
      Log.i('MediaCacheService initialized successfully', 'MAIN');
    } catch (cacheError) {
      Log.e('MediaCacheService initialization failed, continuing without cache', 'MAIN', cacheError);
      // Continue without media caching if it fails
    }
    
    // Initialize background services (after user might be logged in)
    try {
      await BackgroundServiceManager().initialize();
      Log.i('Background services initialized', 'MAIN');
    } catch (bgError) {
      Log.e('Background services initialization failed, continuing', 'MAIN', bgError);
      // Continue without background services if they fail
    }
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
  TextTheme _withFallback(TextTheme base, String primary) {
    const f = [
      'NotoColorEmoji',
      'NotoSansArabic',
      'Apple Color Emoji',
      'Segoe UI Emoji',
      'Segoe UI Symbol',
      'Noto Color Emoji',
      'Android Emoji',
      'EmojiSymbols',
      'EmojiOne Mozilla',
      'Twemoji Mozilla',
      'Segoe UI Historic',
      'Arial',
      'Helvetica',
      'Segoe UI',
      'Tahoma',
      'sans-serif'
    ];
    return TextTheme(
      displayLarge: base.displayLarge?.copyWith(fontFamily: primary, fontFamilyFallback: f),
      displayMedium: base.displayMedium?.copyWith(fontFamily: primary, fontFamilyFallback: f),
      displaySmall: base.displaySmall?.copyWith(fontFamily: primary, fontFamilyFallback: f),
      headlineLarge: base.headlineLarge?.copyWith(fontFamily: primary, fontFamilyFallback: f),
      headlineMedium: base.headlineMedium?.copyWith(fontFamily: primary, fontFamilyFallback: f),
      headlineSmall: base.headlineSmall?.copyWith(fontFamily: primary, fontFamilyFallback: f),
      titleLarge: base.titleLarge?.copyWith(fontFamily: primary, fontFamilyFallback: f),
      titleMedium: base.titleMedium?.copyWith(fontFamily: primary, fontFamilyFallback: f),
      titleSmall: base.titleSmall?.copyWith(fontFamily: primary, fontFamilyFallback: f),
      bodyLarge: base.bodyLarge?.copyWith(fontFamily: primary, fontFamilyFallback: f),
      bodyMedium: base.bodyMedium?.copyWith(fontFamily: primary, fontFamilyFallback: f),
      bodySmall: base.bodySmall?.copyWith(fontFamily: primary, fontFamilyFallback: f),
      labelLarge: base.labelLarge?.copyWith(fontFamily: primary, fontFamilyFallback: f),
      labelMedium: base.labelMedium?.copyWith(fontFamily: primary, fontFamilyFallback: f),
      labelSmall: base.labelSmall?.copyWith(fontFamily: primary, fontFamilyFallback: f),
    );
  }

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
            theme: kIsWeb
                ? ThemeService.lightTheme.copyWith(
                    textTheme: _withFallback(ThemeService.lightTheme.textTheme, 'NotoNaskhArabic'),
                    primaryTextTheme: _withFallback(ThemeService.lightTheme.primaryTextTheme, 'NotoNaskhArabic'),
                  )
                : ThemeService.lightTheme,
            darkTheme: kIsWeb
                ? ThemeService.darkTheme.copyWith(
                    textTheme: _withFallback(ThemeService.darkTheme.textTheme, 'NotoNaskhArabic'),
                    primaryTextTheme: _withFallback(ThemeService.darkTheme.primaryTextTheme, 'NotoNaskhArabic'),
                  )
                : ThemeService.darkTheme,
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
      
      // For web offline mode, don't verify token immediately - show login screen
      // Token verification can happen later when user tries to use the app
      if (kIsWeb) {
        // On web, if we have a token, assume it's valid for now (will verify on first API call)
        // This allows the app to start immediately without waiting for network
        if (mounted) {
          setState(() {
            _isAuthenticated = token.isNotEmpty; // Assume valid for offline mode
            _isLoading = false;
          });
        }
        print('AuthGate: Web mode - showing ${token.isNotEmpty ? "MainApp" : "LoginScreen"}');
        return;
      }
      
      // For mobile, verify token with server
      bool isValid = false;
      if (token.isNotEmpty) {
        try {
          // On mobile, use the configured server URL
          final base = DatabaseConfig.physicalServerUrl;
          final verifyUrl = base.endsWith('/') ? '${base}api/auth/verify' : '$base/api/auth/verify';
          
          print('AuthGate: Verifying token at: $verifyUrl');
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
      return const ModernLoginScreen();
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

class _MainAppState extends State<MainApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeApp();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    
    // Handle iOS background/foreground transitions
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS) {
      final iosService = IOSNotificationService();
      if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
        iosService.onAppPaused();
      } else if (state == AppLifecycleState.resumed) {
        iosService.onAppResumed();
      }
    }
  }

  Future<void> _initializeApp() async {
    try {
      Log.i('Starting app initialization...', 'MAIN_APP');
      await _checkInitialPermissions(); // only checks, doesn’t request

      // ALWAYS initialize notifications (handles web/mobile inside)
      await _initializeNotifications();

      // Note: Web audio requires user interaction before it can play
      // Audio will be unlocked automatically on first user interaction with the app

      // Presence service removed - using MongoDB/ngrok API only
      Log.i('Presence service removed (physical server mode)', 'MAIN_APP');

      // Initialize global realtime listener for notifications
      try {
        final realtime = RealtimeService.instance;
        // For web offline mode, connect in background (non-blocking)
        if (kIsWeb) {
          // On web, connect in background - don't block app initialization
          realtime.connect().catchError((e) {
            Log.e('Realtime connect failed (non-blocking)', 'MAIN_APP', e);
          });
        } else {
          // On mobile, connect synchronously
          await realtime.connect();
        }
        // Join all chats after login: lightweight approach is to rely on message events
        realtime.onNewMessage((msg) async {
          try {
            final chatId = (msg['chatId'] ?? msg['chat_id'] ?? '').toString();
            final senderId = (msg['senderId'] ?? msg['sender_id'] ?? '').toString();
            final senderName = (msg['senderName'] ?? 'Someone').toString();
            final content = (msg['content'] ?? '').toString();
            final currentUserId = await LocalAuthService.getCurrentUserIdAsync();
            
            // Only play sound and show notifications if message is not from current user
            if (senderId != currentUserId) {
              // Always play sound for new messages (even if chat is open)
              await MessageSoundService().playMessageSound();
              
              final active = ActiveChatService.instance.isActive(chatId);
              if (!active) {
                // Only show visual notifications if chat is not active
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
                      'senderId': senderId,
                      'senderName': senderName,
                      'timestamp': DateTime.now().toIso8601String(),
                    }),
                    channelId: 'chat_notifications',
                  );
                }
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
      // Physical server mode - comprehensive notification handling
      Log.i('Physical server mode - initializing notifications', 'MAIN_APP');
      
      if (kIsWeb) {
        Log.i('Web platform - skipping mobile notification setup', 'MAIN_APP');
        return;
      }
      
      // Step 1: Request notification permissions (critical for Android 13+)
      bool hasNotificationPermission = false;
      try {
        final notifStatus = await Permission.notification.status;
        Log.i('Notification permission status: $notifStatus', 'MAIN_APP');
        
        if (notifStatus.isGranted) {
          hasNotificationPermission = true;
          Log.i('Notification permission already granted', 'MAIN_APP');
        } else {
          Log.i('Requesting notification permission...', 'MAIN_APP');
          final notif = await Permission.notification.request();
          hasNotificationPermission = notif.isGranted;
          if (hasNotificationPermission) {
            Log.i('✅ Notification permission granted', 'MAIN_APP');
          } else {
            Log.w('❌ Notification permission denied - notifications will not work', 'MAIN_APP');
          }
        }
      } catch (e) {
        Log.e('Error requesting notification permission', 'MAIN_APP', e);
      }
      
      // Step 2: Request battery optimization exemption (Android only)
      if (defaultTargetPlatform == TargetPlatform.android) {
        try {
          final batteryStatus = await Permission.ignoreBatteryOptimizations.status;
          if (!batteryStatus.isGranted) {
            Log.i('Requesting battery optimization exemption...', 'MAIN_APP');
            final batteryResult = await Permission.ignoreBatteryOptimizations.request();
            if (batteryResult.isGranted) {
              Log.i('✅ Battery optimization exemption granted', 'MAIN_APP');
            } else {
              Log.w('⚠️ Battery optimization exemption denied - notifications may be unreliable', 'MAIN_APP');
            }
          } else {
            Log.i('✅ Battery optimization already ignored', 'MAIN_APP');
          }
        } catch (e) {
          Log.e('Error requesting battery optimization exemption', 'MAIN_APP', e);
        }
      }

      // Step 3: Initialize enhanced notification service
      try {
        final enhanced = EnhancedNotificationService();
        
        if (!enhanced.isInitialized) {
          Log.i('Initializing enhanced notification service...', 'MAIN_APP');
          await enhanced.initialize();
          Log.i('✅ Enhanced notification service initialized', 'MAIN_APP');
          
          // Verify initialization
          final status = await enhanced.getNotificationStatus();
          Log.i('Notification status: ${status.toString()}', 'MAIN_APP');
        } else {
          Log.i('Enhanced notification service already initialized', 'MAIN_APP');
        }
        
        // Request notification permission through service (important for iOS)
        // On iOS, this will show the system permission dialog
        Log.i('Requesting notification permission through service...', 'MAIN_APP');
        final hasPermission = await enhanced.requestPermission();
        if (hasPermission) {
          hasNotificationPermission = true;
          Log.i('✅ Notification permission granted via service', 'MAIN_APP');
        } else {
          Log.w('⚠️ Notification permission not granted via service', 'MAIN_APP');
        }
        
        // Previously we sent a test notification automatically; disable for production
        if (!hasNotificationPermission) {
          Log.w('Skipping notification tests - permission not granted', 'MAIN_APP');
        }
      } catch (e) {
        Log.e('Enhanced notification service failed', 'MAIN_APP', e);
      }

      // Step 3.5: Initialize FCM service (Firebase Cloud Messaging)
      try {
        Log.i('Initializing FCM service...', 'MAIN_APP');
        final fcmService = FCMService();
        await fcmService.initialize();
        Log.i('✅ FCM service initialized', 'MAIN_APP');
        
        // Update user ID in FCM service if user is logged in
        final prefs = await SharedPreferences.getInstance();
        final userId = prefs.getString('user_id');
        if (userId != null) {
          await fcmService.updateUserId(userId);
          Log.i('✅ FCM user ID updated', 'MAIN_APP');
        }
      } catch (e) {
        Log.e('FCM service initialization failed', 'MAIN_APP', e);
        // Continue without FCM if it fails
      }

      // Step 4: Start background services if user is logged in
      try {
        final prefs = await SharedPreferences.getInstance();
        final token = prefs.getString('auth_token');
        if (token != null && token.isNotEmpty) {
          Log.i('User logged in - starting background services...', 'MAIN_APP');
          
          // Wait for services to be ready
          await Future.delayed(const Duration(seconds: 3));
          
          // Platform-specific background services
          if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
            // Android: Start foreground service with retry logic
            bool started = false;
            for (int attempt = 1; attempt <= 3; attempt++) {
              Log.i('Starting foreground service (attempt $attempt/3)...', 'MAIN_APP');
              started = await BackgroundServiceManager().startForegroundService();
              if (started) {
                Log.i('✅ Background services started successfully', 'MAIN_APP');
                break;
              } else {
                Log.w('Foreground service failed to start (attempt $attempt/3)', 'MAIN_APP');
                if (attempt < 3) {
                  await Future.delayed(const Duration(seconds: 2));
                }
              }
            }
            
            if (!started) {
              Log.e('❌ Background services failed to start after 3 attempts', 'MAIN_APP');
            }
            
            // Verify service is running
            await Future.delayed(const Duration(seconds: 2));
            final isRunning = BackgroundServiceManager().isForegroundServiceRunning();
            if (isRunning) {
              Log.i('✅ Foreground service is running', 'MAIN_APP');
            } else {
              Log.w('⚠️ Foreground service may not be running', 'MAIN_APP');
            }
          } else if (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS) {
            // iOS: Initialize iOS notification service
            Log.i('Initializing iOS notification service...', 'MAIN_APP');
            try {
              final iosService = IOSNotificationService();
              await iosService.initialize();
              Log.i('✅ iOS notification service initialized', 'MAIN_APP');
            } catch (e) {
              Log.e('Error initializing iOS notification service', 'MAIN_APP', e);
            }
          }
        } else {
          Log.i('User not logged in - skipping background services', 'MAIN_APP');
        }
      } catch (e) {
        Log.e('Error starting background services', 'MAIN_APP', e);
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
