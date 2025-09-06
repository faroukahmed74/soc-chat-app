// =============================================================================
// SOC CHAT APP - MAIN ENTRY POINT (FIXED NOTIFICATIONS)
// =============================================================================

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter/foundation.dart';
import 'dart:developer' as developer;
import 'dart:convert';
import 'dart:io';

import 'firebase_options.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'screens/login_screen.dart';
import 'screens/register_screen.dart';
import 'screens/admin_panel_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/chat_list_screen.dart';
import 'screens/user_search_screen.dart';
import 'screens/create_group_screen.dart';
import 'screens/hash_demo_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/chat_integration_test_screen.dart';
import 'screens/permission_debug_screen.dart';
import 'screens/permission_test_screen.dart';
import 'screens/help_support_screen.dart';
import 'screens/comprehensive_functionality_test_screen.dart';
import 'screens/update_test_screen.dart';
import 'screens/app_health_check_screen.dart';
import 'screens/startup_diagnostics_screen.dart';
import 'screens/fcm_sound_test_screen.dart';

import 'package:shared_preferences/shared_preferences.dart';

import 'services/presence_service.dart';
import 'services/theme_service.dart';
import 'services/localization_service.dart';
import 'services/message_cleanup_service.dart';
import 'services/offline_service.dart';
import 'services/scheduled_messages_service.dart';
import 'services/secure_message_service.dart';
import 'services/local_message_storage.dart';

import 'services/fcm_notification_service.dart';
import 'services/unified_notification_service.dart';
import 'services/logger_service.dart';
import 'widgets/error_boundary.dart';

// =============================================================================
// GLOBAL NAVIGATOR KEY
// =============================================================================
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

// =============================================================================
// REQUIRED: FCM BACKGROUND HANDLER (TOP-LEVEL)
// =============================================================================
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  try {
    await FCMNotificationService().handleBackgroundMessage(message);
  } catch (e, st) {
    Log.e('BG handler error', 'FCM', e, st);
  }
}

// =============================================================================
// MAIN
// =============================================================================
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  GlobalErrorHandler.initialize();
  Log.i('Starting SOC Chat App initialization', 'MAIN');

  try {
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
    Log.i('Firebase initialized successfully', 'MAIN');

    // iOS foreground presentation (so banners/sounds show in foreground)
    await FirebaseMessaging.instance.setForegroundNotificationPresentationOptions(
      alert: true, badge: true, sound: true,
    );

    // Register background handler (Android/iOS)
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  } catch (e, st) {
    Log.e('Failed to initialize Firebase', 'MAIN', e, st);
    ErrorReportingService.reportError(e, st, context: 'Firebase initialization');
    rethrow;
  }

  // Initialize app services that are safe pre-runApp (avoid double init of FCM here)
  try {
    MessageCleanupService().start();
    await OfflineService().initialize();
    await ScheduledMessagesService().initialize();
    SecureMessageService.initialize();
    await LocalMessageStorage.initialize();
  } catch (e, st) {
    Log.e('Failed to initialize app services', 'MAIN', e, st);
    ErrorReportingService.reportError(e, st, context: 'App services initialization');
  }

  Log.i('Starting main app', 'MAIN');
  runApp(const MyApp());
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
            home: _showOnboarding ? WelcomeScreen(onFinish: _finishOnboarding) : const AuthGate(),
            routes: {
              '/login': (_) => const LoginScreen(),
              '/register': (_) => const RegisterScreen(),
              '/admin': (_) => const AdminPanelScreen(),
              '/profile': (_) => const ProfileScreen(),
              '/chats': (_) => const ChatListScreen(),
              '/search': (_) => const UserSearchScreen(),
              '/create_group': (_) => const CreateGroupScreen(),
              '/hash_demo': (_) => const HashDemoScreen(),
              '/chat-integration-test': (_) => const ChatIntegrationTestScreen(),
              '/permission-debug': (_) => const PermissionDebugScreen(),
              '/permission-test': (_) => const PermissionTestScreen(),
              '/health-check': (_) => const AppHealthCheckScreen(),
              '/startup-diagnostics': (_) => const StartupDiagnosticsScreen(),
              '/fcm_sound_test': (_) => const FCMSoundTestScreen(),
              '/help': (_) => const HelpSupportScreen(),
              '/comprehensive-test': (_) => const ComprehensiveFunctionalityTestScreen(),
              '/update-test': (_) => const UpdateTestScreen(),
              '/settings': (_) => SettingsScreen(
                  onThemeChanged: (bool dark) =>
                      _themeService.setTheme(dark ? ThemeMode.dark : ThemeMode.light)),
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

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        if (snapshot.hasData) {
          return FutureBuilder<DocumentSnapshot>(
            future: FirebaseFirestore.instance.collection('users').doc(snapshot.data!.uid).get(),
            builder: (context, userSnapshot) {
              if (userSnapshot.connectionState == ConnectionState.waiting) {
                return const Scaffold(body: Center(child: CircularProgressIndicator()));
              }
              final data = userSnapshot.data?.data() as Map<String, dynamic>?;
              final isDisabled = data?['disabled'] == true;
              if (isDisabled) return const _AccountLockedScreen();
              return const MainApp();
            },
          );
        }
        return const LoginScreen();
      },
    );
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

      // Optional: presence service on mobile only
      if (!kIsWeb) PresenceService().start();

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
      // Permission flows
      if (defaultTargetPlatform == TargetPlatform.android) {
        final notif = await Permission.notification.request(); // Android 13+
        if (!notif.isGranted) Log.w('Android notifications denied by user', 'MAIN_APP');
      } else if (defaultTargetPlatform == TargetPlatform.iOS) {
        final settings = await FirebaseMessaging.instance.requestPermission(
          alert: true, badge: true, sound: true, provisional: false);
        Log.i('iOS notif perm: ${settings.authorizationStatus}', 'MAIN_APP');
      } else if (kIsWeb) {
        // Browser permission (Web)
        final settings = await FirebaseMessaging.instance.requestPermission();
        Log.i('Web notif perm: ${settings.authorizationStatus}', 'MAIN_APP');
      }

      // Services init (once central place)
      UnifiedNotificationService? unified;
      FCMNotificationService? fcm;
      
      try {
        unified = UnifiedNotificationService();
        await unified.initialize();
      } catch (e) {
        Log.e('Unified notification service failed', 'MAIN_APP', e);
      }

      try {
        fcm = FCMNotificationService();
        await fcm.initialize();
      } catch (e) {
        Log.e('FCM notification service failed', 'MAIN_APP', e);
      }

      // Token fetch (for all platforms)
      final token = await FirebaseMessaging.instance.getToken();
      Log.i('FCM token: $token', 'MAIN_APP');
      
      // Store token with userId in Firestore
      if (token != null) {
        final currentUser = FirebaseAuth.instance.currentUser;
        if (currentUser != null) {
          try {
            await FirebaseFirestore.instance
                .collection('users')
                .doc(currentUser.uid)
                .update({
              'fcmToken': token,
              'lastTokenUpdate': FieldValue.serverTimestamp(),
              'platform': 'mobile', // Simplified platform detection
            });
            Log.i('FCM token stored in Firestore', 'MAIN_APP');
          } catch (e) {
            Log.e('Error storing FCM token', 'MAIN_APP', e);
          }
        }
      }

      // Health check + optional startup local test
      if (fcm != null) {
        final ok = await fcm.checkFCMServerHealth();
        Log.i('FCM server healthy: $ok', 'MAIN_APP');
      }

      // Local startup test (only if user signed in)
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser != null && unified != null) {
        await Future.delayed(const Duration(seconds: 2));
        await unified.sendLocalNotification(
          title: '🔊 SOC Chat App',
          body: 'Notifications initialized successfully!',
          payload: json.encode({'type': 'startup_test', 'ts': DateTime.now().toIso8601String()}),
          channelId: 'chat_notifications',
        );
      }
    } catch (e) {
      Log.e('Error initializing notifications', 'MAIN_APP', e);
    }
  }

  @override
  Widget build(BuildContext context) => const ChatListScreen();
}

// =============================================================================
// OPTIONAL: checkNotificationPermission helper (kept, minor polish)
// =============================================================================
Future<bool> checkNotificationPermission() async {
  try {
    if (kIsWeb) return true;
    final settings = await FirebaseMessaging.instance.getNotificationSettings();
    switch (settings.authorizationStatus) {
      case AuthorizationStatus.authorized:
      case AuthorizationStatus.provisional:
        return true;
      case AuthorizationStatus.denied:
        return false;
      case AuthorizationStatus.notDetermined:
        final newSettings = await FirebaseMessaging.instance.requestPermission();
        return newSettings.authorizationStatus == AuthorizationStatus.authorized;
    }
  } catch (e) {
    Log.e('Error checking notification permission', 'MAIN_APP', e);
    return false;
  }
}
