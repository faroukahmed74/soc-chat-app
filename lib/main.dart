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
import 'services/connectivity_service.dart';
import 'services/offline_message_queue_service.dart';
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
import 'services/webrtc_call_service.dart';
import 'package:firebase_core/firebase_core.dart';
import 'dart:io' if (dart.library.html) 'dart:html' as io;

// =============================================================================
// GLOBAL NAVIGATOR KEY
// =============================================================================
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

// =============================================================================
// ACTIVE CALL TRACKING (Prevent duplicate call screens)
// =============================================================================
class ActiveCallTracker {
  static String? _activeCallId;
  
  static bool isCallActive(String callId) => _activeCallId == callId;
  
  /// Set active call ID atomically
  /// Returns true if successfully set (was not already set), false if already active
  static bool setActiveCall(String callId) {
    if (_activeCallId == callId) {
      return false; // Already active
    }
    if (_activeCallId != null && _activeCallId != callId) {
      return false; // Another call is active
    }
    _activeCallId = callId;
    return true; // Successfully set
  }
  
  static void clearActiveCall(String callId) {
    if (_activeCallId == callId) {
      _activeCallId = null;
    }
  }
  static void clearAll() => _activeCallId = null;
  
  static String? getActiveCallId() {
    return _activeCallId;
  }
}

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
    
    // For web, initialize LocalMessageStorage in background to prevent blocking
    if (kIsWeb) {
      LocalMessageStorage.initialize().then((_) {
        Log.i('LocalMessageStorage initialized (background)', 'MAIN');
      }).catchError((e) {
        Log.e('LocalMessageStorage initialization failed (non-blocking)', 'MAIN', e);
      });
    } else {
      await LocalMessageStorage.initialize();
    }

    // Connectivity + offline message queue (all platforms)
    try {
      await ConnectivityService.instance.initialize();
      await OfflineMessageQueueService.instance.initialize();
      Log.i('Connectivity and offline queue initialized', 'MAIN');
    } catch (e) {
      Log.e('Offline queue init failed (non-blocking)', 'MAIN', e);
    }
    
    // Initialize media cache service with error handling
    try {
      await MediaCacheService.initialize();
      Log.i('MediaCacheService initialized successfully', 'MAIN');
    } catch (cacheError) {
      Log.e('MediaCacheService initialization failed, continuing without cache', 'MAIN', cacheError);
      // Continue without media caching if it fails
    }
    
    // Initialize background services (after user might be logged in)
    // For web, initialize in background to prevent blocking
    if (kIsWeb) {
      BackgroundServiceManager().initialize().then((_) {
        Log.i('Background services initialized (background)', 'MAIN');
      }).catchError((bgError) {
        Log.e('Background services initialization failed (non-blocking)', 'MAIN', bgError);
      });
    } else {
      try {
        await BackgroundServiceManager().initialize();
        Log.i('Background services initialized', 'MAIN');
      } catch (bgError) {
        Log.e('Background services initialization failed, continuing', 'MAIN', bgError);
        // Continue without background services if they fail
      }
    }
  } catch (e, st) {
    Log.e('Failed to initialize app services', 'MAIN', e, st);
    // Don't report errors to avoid crashes - just continue
  }

  // TURN initialization moved to _initializeApp() to prevent blocking app startup
  // It will be called after app initialization completes

  Log.i('Starting main app', 'MAIN');
  runApp(const MyApp());
}

/// Initialize WebRTC Call Service with TURN server configuration (called from main())
/// Mobile: Uses ngrok URL for TURN server access
Future<void> _initializeWebRTCCallServiceInMain() async {
  try {
    print('🔵 [MAIN] ===========================================');
    print('🔵 [MAIN] Initializing WebRTC Call Service in main()...');
    print('🔵 [MAIN] Platform: Mobile');
    print('🔵 [MAIN] ===========================================');
    
    final callService = WebRTCCallService();
    
    // Initialize the service first
    print('🔵 [MAIN] Step 1: Initializing WebRTC service...');
    await callService.initialize();
    print('✅ [MAIN] Step 1: WebRTC Call Service initialized');
    
    // Mobile clients: MUST use ngrok TCP tunnel for cross-network calls
    print('🔵 [MAIN] Step 2: Configuring TURN for Mobile...');
    final ngrokUrl = DatabaseConfig.physicalServerUrl;
    print('🔵 [MAIN] Server URL from DatabaseConfig: $ngrokUrl');
    print('🔵 [MAIN] CRITICAL: Mobile devices MUST use ngrok TURN for cross-network calls');
    
    if (ngrokUrl.isEmpty) {
      print('❌ [MAIN] ===========================================');
      print('❌ [MAIN] ERROR: ngrokUrl is empty!');
      print('❌ [MAIN] Cross-network calls will FAIL!');
      print('❌ [MAIN] ===========================================');
      Log.e('ngrokUrl is empty - cross-network calls will fail', 'MAIN');
      throw Exception('ngrokUrl is empty - cannot configure TURN servers');
    }
    
    print('🔵 [MAIN] Calling setTurnServerConfig with ngrokUrl=$ngrokUrl');
    await callService.setTurnServerConfig(
      ngrokUrl: ngrokUrl,  // Ngrok HTTP URL - will be used to find TCP tunnel
      serverIp: null,  // CRITICAL: Don't add local IP for mobile - it breaks cross-network calls
      port: '3478',
      username: 'soc-chat-turn',
      password: 'yG5EJFUdLgT7xqXr',
    );
    Log.i('✅ WebRTC Call Service initialized with TURN server (Mobile - ngrok TCP tunnel only)', 'MAIN');
    print('✅ [MAIN] ===========================================');
    print('✅ [MAIN] TURN configuration COMPLETE');
    print('✅ [MAIN] ===========================================');
  } catch (e, stackTrace) {
    print('❌ [MAIN] ===========================================');
    print('❌ [MAIN] ERROR initializing WebRTC Call Service in main()!');
    print('❌ [MAIN] Error: $e');
    print('❌ [MAIN] Stack trace: $stackTrace');
    print('❌ [MAIN] ===========================================');
    Log.e('Failed to initialize WebRTC Call Service in main()', 'MAIN', e, stackTrace);
    // Don't rethrow - allow app to continue (calls just won't work cross-network)
  }
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
    // For web, show UI immediately and check auth in background
    if (kIsWeb) {
      // Show login screen immediately to prevent blocking
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isAuthenticated = false; // Default to login screen
        });
      }
      // Check auth in background without blocking
      Future.microtask(() {
        _checkAuthStatus();
      });
    } else {
      _checkAuthStatus();
    }
  }

  Future<void> _checkAuthStatus() async {
    try {
      print('AuthGate: Starting authentication check...');
      
      // For web, add timeout to prevent blocking
      Future<String> tokenFuture = DatabaseConfig.getStoredAuthToken();
      if (kIsWeb) {
        tokenFuture = tokenFuture.timeout(
          const Duration(milliseconds: 500),
          onTimeout: () {
            print('AuthGate: Token check timeout (non-blocking)');
            return '';
          },
        );
      }
      
      // Simple check - just see if we have a token
      final token = await tokenFuture;
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
    // For web, wrap initialization in timeout to prevent freezing
    if (kIsWeb) {
      _initializeApp().timeout(
        const Duration(seconds: 2),
        onTimeout: () {
          Log.w('App initialization timeout (non-blocking)', 'MAIN_APP');
          // Continue - app will work but some features may not be initialized
        },
      ).catchError((e) {
        Log.e('App initialization error (non-blocking)', 'MAIN_APP', e);
        // Continue - app will work but some features may not be initialized
      });
    } else {
      _initializeApp();
    }
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
      await _checkInitialPermissions(); // only checks, doesn't request

      // ALWAYS initialize notifications (handles web/mobile inside)
      await _initializeNotifications();

      // Note: Web audio requires user interaction before it can play
      // Audio will be unlocked automatically on first user interaction with the app

      // Presence service removed - using MongoDB/ngrok API only
      Log.i('Presence service removed (physical server mode)', 'MAIN_APP');

      // Initialize global realtime listener for notifications
      try {
        final realtime = RealtimeService.instance;
        
        // =============================================================================
        // WEBCRTC AND CALLING SYSTEM DISABLED - TO BE IMPLEMENTED LATER
        // =============================================================================
        // WebRTC initialization and call invitation listeners are disabled
        // until the calling system is fully implemented.
        // Uncomment the code below when ready to enable calling features.
        // =============================================================================
        
        // Connect realtime service (for messaging) but skip WebRTC/calling initialization
        if (kIsWeb) {
          // On web, connect in background - don't block app initialization
          realtime.connect().then((_) async {
            // Call invitation listener disabled - to be implemented later
            // _setupCallInvitationListener(realtime);
            Log.i('Realtime service connected (calling system disabled)', 'MAIN_APP');
          }).catchError((e) {
            Log.e('Realtime connect failed (non-blocking)', 'MAIN_APP', e);
          });
        } else {
          // On mobile, connect synchronously
          try {
            await realtime.connect();
            // Call invitation listener disabled - to be implemented later
            // _setupCallInvitationListener(realtime);
            Log.i('Realtime service connected (calling system disabled)', 'MAIN_APP');
          } catch (realtimeError) {
            print('❌ [MAIN_APP] Realtime connection failed: $realtimeError');
            Log.e('Realtime connection failed', 'MAIN_APP', realtimeError);
          }
        }
        
        /* DISABLED - WebRTC initialization (to be implemented later)
        // For web, make TURN initialization non-blocking to prevent freezing
        if (kIsWeb) {
          // On web, initialize TURN in background - don't block app initialization
          print('🔵 [MAIN_APP] Initializing TURN configuration in background (Web)...');
          _initializeWebRTCCallService().then((_) {
            print('✅ [MAIN_APP] TURN configuration initialized successfully (background)');
          }).catchError((turnError, turnStack) {
            print('❌ [MAIN_APP] ERROR initializing TURN config (non-blocking): $turnError');
            Log.e('Failed to initialize TURN configuration (non-blocking)', 'MAIN_APP', turnError, turnStack);
            // Continue - app will work but cross-network calls will fail
          });
          
          // On web, connect in background - don't block app initialization
          realtime.connect().then((_) async {
            // Set up global call invitation listener after connection
            _setupCallInvitationListener(realtime);
          }).catchError((e) {
            Log.e('Realtime connect failed (non-blocking)', 'MAIN_APP', e);
          });
        } else {
          // For mobile, initialize TURN synchronously
          print('🔵 [MAIN_APP] Initializing TURN configuration (Mobile)...');
          try {
            await _initializeWebRTCCallService();
            print('✅ [MAIN_APP] TURN configuration initialized successfully');
          } catch (turnError, turnStack) {
            print('❌ [MAIN_APP] ERROR initializing TURN config: $turnError');
            Log.e('Failed to initialize TURN configuration', 'MAIN_APP', turnError, turnStack);
            // Continue - app will work but cross-network calls will fail
          }
          
          // On mobile, connect synchronously
          try {
            await realtime.connect();
            // Set up global call invitation listener after connection
            _setupCallInvitationListener(realtime);
          } catch (realtimeError) {
            print('❌ [MAIN_APP] Realtime connection failed: $realtimeError');
            Log.e('Realtime connection failed', 'MAIN_APP', realtimeError);
            // Continue - TURN config is already initialized
          }
        }
        */
        
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

  /// Initialize WebRTC Call Service with TURN server configuration (called from main())
  /// This ensures TURN servers are configured regardless of MainApp initialization status
  /// Mobile: Uses ngrok URL for TURN server access
  Future<void> _initializeWebRTCCallServiceInMain() async {
    try {
      print('🔵 [MAIN] ===========================================');
      print('🔵 [MAIN] Initializing WebRTC Call Service in main()...');
      print('🔵 [MAIN] Platform: Mobile');
      print('🔵 [MAIN] ===========================================');
      
      final callService = WebRTCCallService();
      
      // Initialize the service first
      print('🔵 [MAIN] Step 1: Initializing WebRTC service...');
      await callService.initialize();
      print('✅ [MAIN] Step 1: WebRTC Call Service initialized');
      
      // Mobile clients: MUST use ngrok TCP tunnel for cross-network calls
      print('🔵 [MAIN] Step 2: Configuring TURN for Mobile...');
      final ngrokUrl = DatabaseConfig.physicalServerUrl;
      print('🔵 [MAIN] Server URL from DatabaseConfig: $ngrokUrl');
      print('🔵 [MAIN] CRITICAL: Mobile devices MUST use ngrok TURN for cross-network calls');
      
      if (ngrokUrl.isEmpty) {
        print('❌ [MAIN] ===========================================');
        print('❌ [MAIN] ERROR: ngrokUrl is empty!');
        print('❌ [MAIN] Cross-network calls will FAIL!');
        print('❌ [MAIN] ===========================================');
        Log.e('ngrokUrl is empty - cross-network calls will fail', 'MAIN');
        throw Exception('ngrokUrl is empty - cannot configure TURN servers');
      }
      
      print('🔵 [MAIN] Calling setTurnServerConfig with ngrokUrl=$ngrokUrl');
      await callService.setTurnServerConfig(
        ngrokUrl: ngrokUrl,  // Ngrok HTTP URL - will be used to find TCP tunnel
        serverIp: null,  // CRITICAL: Don't add local IP for mobile - it breaks cross-network calls
        port: '3478',
        username: 'soc-chat-turn',
        password: 'yG5EJFUdLgT7xqXr',
      );
      Log.i('✅ WebRTC Call Service initialized with TURN server (Mobile - ngrok TCP tunnel only)', 'MAIN');
      print('✅ [MAIN] ===========================================');
      print('✅ [MAIN] Mobile TURN configuration COMPLETE');
      print('✅ [MAIN] ===========================================');
    } catch (e, stackTrace) {
      print('❌ [MAIN] ===========================================');
      print('❌ [MAIN] ERROR initializing WebRTC Call Service in main()!');
      print('❌ [MAIN] Error: $e');
      print('❌ [MAIN] Stack trace: $stackTrace');
      print('❌ [MAIN] ===========================================');
      Log.e('Failed to initialize WebRTC Call Service in main()', 'MAIN', e, stackTrace);
      // Re-throw to ensure caller knows it failed
      rethrow;
    }
  }

  /// Set up global call invitation listener
  /// Initialize WebRTC Call Service with TURN server configuration
  /// Web: Uses local network IP (10.120.4.230)
  /// Mobile: Uses ngrok URL for TURN server access (only if not already initialized in main())
  /// DISABLED - To be implemented later
  Future<void> _initializeWebRTCCallService() async {
    // WebRTC initialization disabled - to be implemented later
    Log.i('WebRTC Call Service initialization skipped (disabled until calling system is implemented)', 'MAIN_APP');
    return;
    
    /* DISABLED - WebRTC initialization (to be implemented later)
    try {
      print('🔵 [MAIN_APP] ===========================================');
      print('🔵 [MAIN_APP] Initializing WebRTC Call Service...');
      print('🔵 [MAIN_APP] Platform: ${kIsWeb ? "Web" : "Mobile"}');
      print('🔵 [MAIN_APP] ===========================================');
      
      final callService = WebRTCCallService();
      
      // Initialize the service first
      print('🔵 [MAIN_APP] Step 1: Initializing WebRTC service...');
      await callService.initialize();
      print('✅ [MAIN_APP] Step 1: WebRTC Call Service initialized');
      
      // Configure TURN server based on platform
      // Web: Use local network IP (primary) + ngrok TCP tunnel (for cross-platform calls with mobile)
      // Mobile: Use ngrok TCP tunnel (required for cross-network calls)
      if (kIsWeb) {
        // Web clients: Fetch TURN config from server (includes cloud TURN if configured)
        // Server will return cloud TURN first (if enabled), then local IP as fallback
        final serverUrl = DatabaseConfig.physicalServerUrl;
        print('🔵 [MAIN_APP] Configuring TURN for Web: serverUrl=$serverUrl');
        print('🔵 [MAIN_APP] Server will return cloud TURN (if enabled) or local IP fallback');
        await callService.setTurnServerConfig(
          serverIp: '10.120.4.230',  // Local IP for same-network web-to-web calls (fallback)
          ngrokUrl: serverUrl,  // Fetch TURN config from server (includes cloud TURN if configured)
          port: '3478',
          username: 'soc-chat-turn',
          password: 'yG5EJFUdLgT7xqXr',
        );
        Log.i('✅ WebRTC Call Service initialized with TURN server (Web - cloud TURN preferred, local IP fallback)', 'MAIN_APP');
        print('✅ [MAIN_APP] Web TURN configuration complete');
      } else {
        // Mobile clients: Fetch TURN config from server (includes cloud TURN if enabled)
        // Cloud TURN (Twilio) is used for cross-network calls (no router access needed)
        print('🔵 [MAIN_APP] Step 2: Configuring TURN for Mobile...');
        final ngrokUrl = DatabaseConfig.physicalServerUrl;
        print('🔵 [MAIN_APP] Server URL from DatabaseConfig: $ngrokUrl');
        print('🔵 [MAIN_APP] Mobile devices will fetch TURN config from server (includes cloud TURN if enabled)');
        
        if (ngrokUrl.isEmpty) {
          print('❌ [MAIN_APP] ===========================================');
          print('❌ [MAIN_APP] ERROR: ngrokUrl is empty!');
          print('❌ [MAIN_APP] Cross-network calls will FAIL!');
          print('❌ [MAIN_APP] ===========================================');
          Log.e('ngrokUrl is empty - cross-network calls will fail', 'MAIN_APP');
          throw Exception('ngrokUrl is empty - cannot configure TURN servers');
        }
        
        print('🔵 [MAIN_APP] Calling setTurnServerConfig with ngrokUrl=$ngrokUrl');
        await callService.setTurnServerConfig(
          ngrokUrl: ngrokUrl,  // Ngrok HTTP URL - will be used to find TCP tunnel
          serverIp: null,  // CRITICAL: Don't add local IP for mobile - it breaks cross-network calls
          port: '3478',
          username: 'soc-chat-turn',
          password: 'yG5EJFUdLgT7xqXr',
        );
        Log.i('✅ WebRTC Call Service initialized with TURN server (Mobile - cloud TURN preferred)', 'MAIN_APP');
        print('✅ [MAIN_APP] ===========================================');
        print('✅ [MAIN_APP] Mobile TURN configuration COMPLETE');
        print('✅ [MAIN_APP] ===========================================');
      }
    } catch (e, stackTrace) {
      print('❌ [MAIN_APP] ERROR initializing WebRTC Call Service: $e');
      print('❌ [MAIN_APP] Stack trace: $stackTrace');
      Log.e('Failed to initialize WebRTC Call Service', 'MAIN_APP', e, stackTrace);
      // Continue without TURN - STUN servers will still work, but cross-network calls will fail
      print('⚠️ [MAIN_APP] Continuing without TURN - cross-network calls will NOT work');
    }
    */
  }

  /// Set up global call invitation listener
  /// DISABLED - To be implemented later
  void _setupCallInvitationListener(RealtimeService realtime) {
    // Call invitation listener disabled - to be implemented later
    Log.i('Call invitation listener setup skipped (disabled until calling system is implemented)', 'MAIN_APP');
    return;
    
    /* DISABLED - Call invitation listener (to be implemented later)
    realtime.onCallInvitation((data) {
      try {
        Log.i('📞 Received call invitation globally: $data', 'MAIN_APP');
        // Navigate to call screen from anywhere in the app
        WidgetsBinding.instance.addPostFrameCallback((_) {
          final navigator = navigatorKey.currentState;
          if (navigator != null) {
            final chatId = (data['chatId'] ?? '').toString();
            final chatName = (data['chatName'] ?? 'Unknown').toString();
            final callTypeStr = (data['callType'] ?? 'video').toString();
            final callId = (data['callId'] ?? '').toString(); // WebRTC uses callId
            final isGroupChat = data['isGroupChat'] ?? false;
            
            // Handle both 'voice' and 'audio' (server normalizes 'voice' to 'audio')
            // Convert to string for navigation (CallScreen expects 'voice' or 'video' string)
            // Note: CallTypeHelper handles the conversion, but we need string for navigation
            final callType = (callTypeStr == 'voice' || callTypeStr == 'audio') ? 'voice' : 'video';
            
            Log.i('📞 Call invitation details: chatId=$chatId, callId=$callId, callType=$callType (from $callTypeStr)', 'MAIN_APP');
            
            if (callId.isEmpty || chatId.isEmpty) {
              Log.w('❌ Call invitation missing required fields: callId=$callId, chatId=$chatId', 'MAIN_APP');
              return;
            }
            
            // CRITICAL: Try to set active call atomically - if it fails, another handler got there first
            final wasSet = ActiveCallTracker.setActiveCall(callId);
            if (!wasSet) {
              // Check if we're already in a call - if so, reject the new call
              final currentActiveCallId = ActiveCallTracker.getActiveCallId();
              if (currentActiveCallId != null && currentActiveCallId != callId) {
                Log.w('⚠️ [MAIN_APP] User already in call $currentActiveCallId, rejecting new call $callId');
                // Optionally: Show a notification that a call was missed
                // For now, we'll just ignore it (caller will see timeout)
                return;
              }
              Log.w('⚠️ [MAIN_APP] Call screen already being opened for callId: $callId, ignoring duplicate invitation');
              return;
            }
            
            // Additional check: if navigator is already showing a call screen, don't navigate again
            final currentContext = navigatorKey.currentContext;
            if (currentContext != null) {
              final route = ModalRoute.of(currentContext);
              if (route?.settings.name == '/call') {
                Log.w('⚠️ [MAIN_APP] Call screen route already active, ignoring duplicate invitation');
                ActiveCallTracker.clearActiveCall(callId); // Clear since we're not navigating
                return;
              }
            }
            
            Log.i('📞 Navigating to call screen via global listener: chatId=$chatId, callId=$callId', 'MAIN_APP');
            try {
              print('🔵 [MAIN_APP] Setting active call and navigating to call screen');
              navigator.pushNamed('/call', arguments: {
                'chatId': chatId,
                'chatName': chatName,
                'isGroupChat': isGroupChat,
                'callType': callType, // Pass as 'voice' or 'video' string
                'direction': 'incoming',
                'callId': callId,
              }).then((_) {
                // Clear active call ID when screen is closed
                ActiveCallTracker.clearActiveCall(callId);
                Log.i('📞 [MAIN_APP] Call screen closed, cleared active call ID', 'MAIN_APP');
              }).catchError((e) {
                // Clear on navigation error
                ActiveCallTracker.clearActiveCall(callId);
                Log.e('Error navigating to call screen', 'MAIN_APP', e);
              });
              Log.i('✅ Successfully navigated to call screen', 'MAIN_APP');
            } catch (e, stackTrace) {
              ActiveCallTracker.clearActiveCall(callId); // Clear on error
              Log.e('Error navigating to call screen', 'MAIN_APP', e);
              Log.e('Stack trace', 'MAIN_APP', stackTrace);
            }
          } else {
            Log.w('❌ Navigator not available for call screen', 'MAIN_APP');
          }
        });
      } catch (e, stackTrace) {
        Log.e('Error handling global call invitation', 'MAIN_APP', e);
        Log.e('Stack trace', 'MAIN_APP', stackTrace);
      }
    });
    Log.i('✅ Global call invitation listener set up', 'MAIN_APP');
    */
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
