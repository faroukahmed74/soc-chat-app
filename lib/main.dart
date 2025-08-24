// =============================================================================
// SOC CHAT APP - MAIN ENTRY POINT
// =============================================================================
// This file serves as the main entry point for the Flutter application.
// It handles Firebase initialization, app lifecycle, theme management,
// localization, and the main navigation structure.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter/foundation.dart';
import 'dart:developer' as developer;
import 'firebase_options.dart';
import 'screens/login_screen.dart';
import 'screens/register_screen.dart';
import 'screens/admin_panel_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'screens/profile_screen.dart';
import 'screens/chat_list_screen.dart';
import 'screens/user_search_screen.dart';
import 'screens/create_group_screen.dart';
import 'screens/hash_demo_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/fcm_server_test_screen.dart';
import 'screens/chat_integration_test_screen.dart';
import 'screens/permission_debug_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'services/presence_service.dart';
import 'services/theme_service.dart';
import 'services/localization_service.dart';
import 'services/message_cleanup_service.dart';
import 'services/offline_service.dart';
import 'services/scheduled_messages_service.dart';
import 'services/secure_message_service.dart';
import 'services/local_message_storage.dart';
import 'services/production_notification_service.dart';
import 'services/logger_service.dart';
import 'widgets/error_boundary.dart';

// =============================================================================
// GLOBAL NAVIGATOR KEY
// =============================================================================
// This key allows navigation from anywhere in the app, including
// from background services and callbacks.
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

// =============================================================================
// MAIN FUNCTION
// =============================================================================
// Entry point that initializes Firebase and runs the app
void main() async {
  // Ensure Flutter bindings are initialized
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize global error handling
  GlobalErrorHandler.initialize();
  
  // Initialize logging
  Log.i('Starting SOC Chat App initialization', 'MAIN');
  
  try {
    // Initialize Firebase with platform-specific options
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    Log.i('Firebase initialized successfully', 'MAIN');
  } catch (e, stackTrace) {
    Log.e('Failed to initialize Firebase', 'MAIN', e, stackTrace);
    ErrorReportingService.reportError(e, stackTrace, context: 'Firebase initialization');
    rethrow;
  }
  
  try {
    // Initialize and start the message cleanup service
    MessageCleanupService().start();
    Log.i('Message cleanup service started', 'MAIN');
    
    // Initialize the offline service for offline functionality
    await OfflineService().initialize();
    Log.i('Offline service initialized', 'MAIN');
    
    // Initialize the scheduled messages service
    await ScheduledMessagesService().initialize();
    Log.i('Scheduled messages service initialized', 'MAIN');
    
    // Initialize secure message services
    SecureMessageService.initialize();
    await LocalMessageStorage.initialize();
    Log.i('Secure message services initialized', 'MAIN');
    
    // Initialize production notification service
    await ProductionNotificationService().initialize();
    Log.i('Production notification service initialized', 'MAIN');
  } catch (e, stackTrace) {
    Log.e('Failed to initialize app services', 'MAIN', e, stackTrace);
    ErrorReportingService.reportError(e, stackTrace, context: 'App services initialization');
    // Continue with app startup even if some services fail
  }
  
  // Run the main app
  Log.i('Starting main app', 'MAIN');
  runApp(const MyApp());
}

// =============================================================================
// MAIN APP WIDGET
// =============================================================================
// Root widget that sets up the app structure, theme, and navigation
class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

// =============================================================================
// MAIN APP STATE
// =============================================================================
// Manages app-wide state including theme, language, and onboarding
class _MyAppState extends State<MyApp> with TickerProviderStateMixin {
  // Animation controller for app startup fade-in effect
  late AnimationController _animationController;
  
  // Animation for the fade-in effect
  late Animation<double> _fadeAnimation;
  
  // Whether to show the onboarding screen
  bool _showOnboarding = false;
  
  // Service for managing theme (light/dark mode)
  late ThemeService _themeService;
  
  // Current locale for internationalization
  Locale _currentLocale = const Locale('en'); // Default to English

  // =============================================================================
  // INITIALIZATION
  // =============================================================================
  @override
  void initState() {
    super.initState();
    
    // Initialize theme service for managing app appearance
    _themeService = ThemeService.instance;
    
    // Set initial locale from theme service (synchronous)
    _currentLocale = _themeService.locale;
    
    // Initialize theme service and update locale if needed
    _initializeThemeService();
    
    // Set up animation controller for startup effect
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    
    // Create fade-in animation
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeIn,
    ));
    
    // Check if user has completed onboarding
    _checkOnboardingStatus();
    
    // Start the fade-in animation
    _animationController.forward();
    
    // Listen to theme changes to update locale and rebuild when needed
    _themeService.addListener(() {
      try {
        if (mounted) {
          setState(() {
            _currentLocale = _themeService.locale;
          });
          Log.i('Main app locale updated to: ${_themeService.locale.languageCode}', 'MAIN_APP');
        }
      } catch (e) {
        Log.e('Error updating locale', 'MAIN_APP', e);
        // Fallback to English if there's an error
        if (mounted) {
          setState(() {
            _currentLocale = const Locale('en');
          });
        }
      }
    });
  }
  
  /// Initialize theme service asynchronously
  Future<void> _initializeThemeService() async {
    try {
      await _themeService.initialize();
      if (mounted) {
        setState(() {
          _currentLocale = _themeService.locale;
        });
      }
    } catch (e) {
      Log.e('Error initializing theme service', 'MAIN_APP', e);
      // Ensure we always have a valid locale
      if (mounted) {
        setState(() {
          _currentLocale = const Locale('en');
        });
      }
    }
  }

  // =============================================================================
  // CLEANUP
  // =============================================================================
  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  // =============================================================================
  // ONBOARDING STATUS CHECK
  // =============================================================================
  // Checks if the user has completed the onboarding process
  // If not, shows the welcome screen
  Future<void> _checkOnboardingStatus() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _showOnboarding = prefs.getBool('showOnboarding') ?? true;
    });
  }

  // =============================================================================
  // ONBOARDING COMPLETION
  // =============================================================================
  // Marks onboarding as complete and hides the welcome screen
  void _finishOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('showOnboarding', false);
    setState(() {
      _showOnboarding = false;
    });
  }



  // =============================================================================
  // BUILD METHOD
  // =============================================================================
  // Builds the main app structure with theme, localization, and navigation
  @override
  Widget build(BuildContext context) {
    return ErrorBoundary(
      onError: () => Log.e('App-level error occurred', 'MAIN_APP'),
      child: AnimatedBuilder(
        animation: Listenable.merge([_fadeAnimation, _themeService]),
        builder: (context, child) {
          return MaterialApp(
            // Global error handling
          builder: (context, child) {
            ErrorWidget.builder = (FlutterErrorDetails errorDetails) {
              return Material(
                child: Container(
                  color: Colors.white,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.error_outline,
                        size: 64,
                        color: Colors.red.shade300,
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
                        'Error: ${errorDetails.exception}',
                        style: const TextStyle(
                          fontSize: 16,
                          color: Colors.grey,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: () {
                          // Reload the current route
                          Navigator.of(context).pushReplacementNamed('/');
                        },
                        child: const Text('Go to Home'),
                      ),
                    ],
                  ),
                ),
              );
            };
            return child!;
          },
          // App title that changes based on current language
          title: AppLocalizations.getString('app_name', _currentLocale?.languageCode ?? 'en'),
          
          // Light theme configuration
          theme: ThemeService.lightTheme,
          
          // Dark theme configuration
          darkTheme: ThemeService.darkTheme,
          
          // Current theme mode (light/dark/system)
          themeMode: _themeService.themeMode,
          
          // Current locale for internationalization
          locale: _currentLocale ?? const Locale('en'),
          
          // Supported locales (English and Arabic)
          supportedLocales: LocalizationService.supportedLocales,
          
          // Global navigator key for app-wide navigation
          navigatorKey: navigatorKey,
          
          // Home screen - either onboarding or main app
          home: _showOnboarding
              ? WelcomeScreen(onFinish: _finishOnboarding)
              : AuthGate(),
          
          // =============================================================================
          // ROUTE DEFINITIONS
          // =============================================================================
          // All named routes in the application
          routes: {
            '/login': (context) => const LoginScreen(),
            '/register': (context) => const RegisterScreen(),
            '/admin': (context) => const AdminPanelScreen(),
            '/profile': (context) => const ProfileScreen(),
            '/chats': (context) => const ChatListScreen(),
            '/search': (context) => const UserSearchScreen(),
            '/create_group': (context) => const CreateGroupScreen(),
            '/hash_demo': (context) => const HashDemoScreen(),
                      '/fcm-test': (context) => const FcmServerTestScreen(),
          '/chat-integration-test': (context) => const ChatIntegrationTestScreen(),
          '/permission-debug': (context) => const PermissionDebugScreen(),
            '/settings': (context) => SettingsScreen(onThemeChanged: (bool darkMode) {
              _themeService.setTheme(darkMode ? ThemeMode.dark : ThemeMode.light);
            }),
          },
          
          // Remove debug banner in production
          debugShowCheckedModeBanner: false,
        );
      },
    ));
  }
}

// =============================================================================
// WELCOME SCREEN
// =============================================================================
// Onboarding screen shown to new users
class WelcomeScreen extends StatelessWidget {
  final VoidCallback onFinish;
  
  const WelcomeScreen({super.key, required this.onFinish});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Theme.of(context).colorScheme.primary,
              Theme.of(context).colorScheme.secondary,
            ],
          ),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // App icon
              Icon(
                Icons.chat_bubble,
                size: 100,
                color: Colors.white,
              ),
              const SizedBox(height: 32),
              
              // Welcome title
              const Text(
                'Welcome to Soc Chat App',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 16),
              
              // Welcome subtitle
              const Text(
                'Connect safely and securely',
                style: TextStyle(
                  fontSize: 18,
                  color: Colors.white70,
                ),
              ),
              const SizedBox(height: 48),
              
              // Get started button
              ElevatedButton(
                onPressed: onFinish,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: Theme.of(context).colorScheme.primary,
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Get Started',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// AUTHENTICATION GATE
// =============================================================================
// Controls access to the main app based on authentication status
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      // Listen to Firebase Auth state changes
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        // Show loading while checking auth status
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(),
            ),
          );
        }

        // If user is authenticated, check if account is locked
        if (snapshot.hasData) {
          return FutureBuilder<DocumentSnapshot>(
            // Check user's Firestore document for lock status
            future: FirebaseFirestore.instance
                .collection('users')
                .doc(snapshot.data!.uid)
                .get(),
            builder: (context, userSnapshot) {
              if (userSnapshot.connectionState == ConnectionState.waiting) {
                return const Scaffold(
                  body: Center(
                    child: CircularProgressIndicator(),
                  ),
                );
              }

              if (userSnapshot.hasData) {
                final userData = userSnapshot.data!.data() as Map<String, dynamic>?;
                final isDisabled = userData?['disabled'] == true;

                // If account is locked, show locked screen
                if (isDisabled) {
                  return _AccountLockedScreen(
                    lockReason: userData?['lockReason'],
                    lockedAt: userData?['lockedAt'],
                    lockedBy: userData?['lockedBy'],
                  );
                }
              }

              // Account not locked, show main app
              return const MainApp();
            },
          );
        }

        // User not authenticated, show login screen
        return const LoginScreen();
      },
    );
  }
}

// =============================================================================
// ACCOUNT LOCKED SCREEN
// =============================================================================
// Displayed when a user's account has been locked by an administrator
class _AccountLockedScreen extends StatelessWidget {
  final String? lockReason;
  final Timestamp? lockedAt;
  final String? lockedBy;

  const _AccountLockedScreen({
    this.lockReason,
    this.lockedAt,
    this.lockedBy,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Account Locked'),
        backgroundColor: Colors.red,
        foregroundColor: Colors.white,
        automaticallyImplyLeading: false,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Lock icon
              Icon(
                Icons.lock,
                size: 80,
                color: Colors.red.shade400,
              ),
              const SizedBox(height: 24),
              
              // Locked message
              const Text(
                'Your account has been locked',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              
              // Reason for lock (if provided)
              if (lockReason != null) ...[
                Text(
                  'Reason: $lockReason',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey.shade600,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
              ],
              
              // Lock details
              if (lockedAt != null) ...[
                Text(
                  'Locked on: ${lockedAt!.toDate().toString().split(' ')[0]}',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade500,
                  ),
                ),
                const SizedBox(height: 8),
              ],
              
              if (lockedBy != null) ...[
                Text(
                  'Locked by: $lockedBy',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade500,
                  ),
                ),
                const SizedBox(height: 32),
              ],
              
              // Contact admin button
              ElevatedButton.icon(
                onPressed: () => _showContactAdminDialog(context),
                icon: const Icon(Icons.contact_support),
                label: const Text('Contact Administrator'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red.shade600,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
              ),
              const SizedBox(height: 16),
              
              // Sign out button
              OutlinedButton(
                onPressed: () async {
                  await FirebaseAuth.instance.signOut();
                },
                child: const Text('Sign Out'),
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  /// Shows the contact admin dialog
  void _showContactAdminDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Contact Administrator'),
        content: Text(
          'If you believe your account was locked in error, '
          'please contact the administrator with the following information:\n\n'
          '• Your email: ${FirebaseAuth.instance.currentUser?.email ?? 'Unknown'}\n'
          '• Account locked at: ${DateTime.now()}\n'
          '• Reason: Account locked due to security concerns\n\n'
          'The administrator will review your case and respond within 24 hours.'
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Close'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              _copyContactInfo(context);
            },
            child: const Text('Copy Info'),
          ),
        ],
      ),
    );
  }
  
  /// Copies contact information to clipboard
  void _copyContactInfo(BuildContext context) async {
    try {
      final contactInfo = '''
Account Locked - Contact Administrator

Email: ${FirebaseAuth.instance.currentUser?.email ?? 'Unknown'}
Locked At: ${DateTime.now()}
Reason: Account locked due to security concerns

Please review this case and respond within 24 hours.
      ''';
      
      await Clipboard.setData(ClipboardData(text: contactInfo));
      
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Contact information copied to clipboard')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error copying information: $e')),
        );
      }
    }
  }
}

// =============================================================================
// MAIN APPLICATION
// =============================================================================
// The main app interface after authentication
class MainApp extends StatefulWidget {
  const MainApp({super.key});

  @override
  State<MainApp> createState() => _MainAppState();
}

// =============================================================================
// MAIN APP STATE
// =============================================================================
// Manages the main app functionality including notifications and presence
class _MainAppState extends State<MainApp> {
  // =============================================================================
  // INITIALIZATION
  // =============================================================================
  @override
  void initState() {
    super.initState();
    
    // Initialize app components
    _initializeApp();
  }

  // =============================================================================
  // APP INITIALIZATION
  // =============================================================================
  // Sets up all necessary app services (permissions requested when needed)
  Future<void> _initializeApp() async {
    // Check initial permission status (but don't request them)
    // iOS requires user interaction before requesting permissions
    await _checkInitialPermissions();
    
    // Initialize notifications (mobile only)
    if (!kIsWeb) {
      await _initializeNotifications();
    }
    
    // Start presence service for online/offline tracking (mobile only)
    if (!kIsWeb) {
      PresenceService().start();
    }
  }

  // =============================================================================
  // INITIAL PERMISSION CHECK (NOT REQUEST)
  // =============================================================================
  // Only checks permission status, doesn't request them on startup
  // iOS requires user interaction before requesting permissions
  // Permissions will be requested when user actually needs them
  Future<void> _checkInitialPermissions() async {
    if (kIsWeb) return; // Web doesn't need mobile permissions
    
    developer.log('Checking initial permission status (not requesting)...', name: 'MainApp');
    developer.log('iOS: Permissions will be requested when user interacts with features', name: 'MainApp');
    
    // Only check status, don't request
    final cameraStatus = await Permission.camera.status;
    final photosStatus = await Permission.photos.status;
    final microphoneStatus = await Permission.microphone.status;
    
    developer.log('Initial permission status - Camera: $cameraStatus, Photos: $photosStatus, Microphone: $microphoneStatus', name: 'MainApp');
    
    // Log if permissions are permanently denied (user needs to go to Settings)
    if (cameraStatus == PermissionStatus.permanentlyDenied) {
      developer.log('Camera permission permanently denied - user needs to enable in iOS Settings', name: 'MainApp');
    }
    if (photosStatus == PermissionStatus.permanentlyDenied) {
      developer.log('Photos permission permanently denied - user needs to enable in iOS Settings', name: 'MainApp');
    }
    if (microphoneStatus == PermissionStatus.permanentlyDenied) {
      developer.log('Microphone permission permanently denied - user needs to enable in iOS Settings', name: 'MainApp');
    }
    
    // Log iOS-specific guidance
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS) {
      developer.log('iOS: Use IOSPermissionService.requestCameraPermission() when user taps camera', name: 'MainApp');
      developer.log('iOS: Use IOSPermissionService.requestPhotosPermission() when user taps gallery', name: 'MainApp');
      developer.log('iOS: Use IOSPermissionService.requestMicrophonePermission() when user taps voice', name: 'MainApp');
    }
  }

  // =============================================================================
  // NOTIFICATION INITIALIZATION
  // =============================================================================
  // Sets up Firebase Cloud Messaging and local notifications
  Future<void> _initializeNotifications() async {
    try {
      if (kIsWeb) {
        // Web notification setup
        await _initializeWebNotifications();
      } else {
        // Mobile notification setup
        await _initializeMobileNotifications();
      }
      
      // Subscribe to user topics for FCM notifications
      await _subscribeToUserTopics();
          } catch (e) {
        developer.log('Error initializing notifications: $e', name: 'MainApp');
      }
    }

  /// Subscribe to user topics for FCM notifications
  Future<void> _subscribeToUserTopics() async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser != null) {
        // Subscribe to broadcast and user-specific topics
        await ProductionNotificationService().subscribeToAllUserTopics(currentUser.uid);
        
        // Subscribe to all user's chat topics
        await ProductionNotificationService().subscribeToUserChatTopics();
        
        developer.log('Subscribed to all user topics for: ${currentUser.uid}', name: 'MainApp');
      }
    } catch (e) {
      developer.log('Error subscribing to user topics: $e', name: 'MainApp');
    }
  }

  // =============================================================================
  // MOBILE NOTIFICATION SETUP
  // =============================================================================
  Future<void> _initializeMobileNotifications() async {
    try {
      // Use the production notification service
      final notificationService = ProductionNotificationService();
      await notificationService.initialize();
    } catch (e) {
      Log.e('Error initializing mobile notifications', 'MAIN_APP', e);
    }
  }

  // =============================================================================
  // WEB NOTIFICATION SETUP
  // =============================================================================
  Future<void> _initializeWebNotifications() async {
    try {
      Log.i('Initializing web notifications', 'MAIN_APP');
      
      // For web, we'll use a simpler approach
      // Web notifications will be handled by the browser's native notification system
      Log.i('Web notifications initialized - using browser native system', 'MAIN_APP');
    } catch (e) {
      Log.e('Error initializing web notifications', 'MAIN_APP', e);
    }
  }

  // =============================================================================
  // LOCAL NOTIFICATIONS SETUP
  // =============================================================================
  // Configures local notifications for the app
  Future<void> _initializeLocalNotifications() async {
    final flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();
    
    // Android settings
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    
    // iOS settings
    const iosSettings = DarwinInitializationSettings();
    
    // Initialize settings
    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );
    
    // Initialize the plugin
    await flutterLocalNotificationsPlugin.initialize(initSettings);
    
    // Create Android notification channel
    const androidChannel = AndroidNotificationChannel(
      'chat_channel',
      'Chat Notifications',
      description: 'Notifications for chat messages',
      importance: Importance.high,
      enableVibration: true,
      playSound: true,
    );
    
    await flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(androidChannel);
  }

  // =============================================================================
  // FOREGROUND MESSAGE HANDLER
  // =============================================================================
  // Handles messages received while the app is in the foreground
  void _handleForegroundMessage(RemoteMessage message) {
    Log.i('Received foreground message: ${message.messageId}', 'MAIN_APP');
    Log.i('Message data: ${message.data}', 'MAIN_APP');
    Log.i('Message notification: ${message.notification?.title} - ${message.notification?.body}', 'MAIN_APP');
    
    // Show local notification
    _showLocalNotification(
      title: message.notification?.title ?? 'New Message',
      body: message.notification?.body ?? 'You have a new message',
    );
  }

  // =============================================================================
  // LOCAL NOTIFICATION DISPLAY
  // =============================================================================
  // Shows a local notification to the user
  Future<void> _showLocalNotification({
    required String title,
    required String body,
  }) async {
    final flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();
    
    const androidDetails = AndroidNotificationDetails(
      'chat_channel',
      'Chat Notifications',
      channelDescription: 'Notifications for chat messages',
      importance: Importance.high,
      priority: Priority.high,
      enableVibration: true,
      playSound: true,
    );
    
    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );
    
    const notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );
    
    await flutterLocalNotificationsPlugin.show(
      0,
      title,
      body,
      notificationDetails,
    );
  }

  // =============================================================================
  // BUILD METHOD
  // =============================================================================
  // Builds the main app interface
  @override
  Widget build(BuildContext context) {
    return const ChatListScreen();
  }
}

  // =============================================================================
  // BACKGROUND MESSAGE HANDLER
  // =============================================================================
  // Handles Firebase messages received while the app is in the background
  // This function must be top-level (not inside a class)
  Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
    // Ensure Firebase is initialized
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    
    Log.i('Handling background message: ${message.messageId}', 'BACKGROUND_HANDLER');
    Log.i('Background message data: ${message.data}', 'BACKGROUND_HANDLER');
    
    // You can perform background tasks here
    // For example, updating local storage, sending analytics, etc.
  }

  // =============================================================================
  // NOTIFICATION PERMISSION CHECK
  // =============================================================================
  // Checks if notifications are enabled and requests permission if needed
  Future<bool> checkNotificationPermission() async {
    try {
      if (kIsWeb) {
        // Web notifications are handled by browser
        return true;
      }
      
      final messaging = FirebaseMessaging.instance;
      final settings = await messaging.getNotificationSettings();
      
      switch (settings.authorizationStatus) {
        case AuthorizationStatus.authorized:
          Log.i('Notifications are authorized', 'MAIN_APP');
          return true;
        case AuthorizationStatus.denied:
          Log.w('Notifications are denied', 'MAIN_APP');
          return false;
        case AuthorizationStatus.notDetermined:
          Log.i('Notification permission not determined, requesting...', 'MAIN_APP');
          final newSettings = await messaging.requestPermission();
          return newSettings.authorizationStatus == AuthorizationStatus.authorized;
        case AuthorizationStatus.provisional:
          Log.i('Notifications are provisionally authorized', 'MAIN_APP');
          return true;
      }
    } catch (e) {
      Log.e('Error checking notification permission', 'MAIN_APP', e);
      return false;
    }
  }
