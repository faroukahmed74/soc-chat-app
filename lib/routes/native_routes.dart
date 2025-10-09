import 'package:flutter/material.dart';

import '../screens/login_screen.dart';
import '../screens/register_screen_mongodb.dart';
import '../screens/admin_panel_screen_mongodb.dart';
import '../screens/profile_screen.dart';
import '../screens/chat_list_screen_mongodb.dart' if (dart.library.html) '../screens/chat_list_screen_web.dart';
import '../screens/user_search_screen.dart';
import '../screens/create_group_screen.dart';
import '../screens/hash_demo_screen.dart';
import '../screens/settings_screen.dart';
import '../screens/chat_integration_test_screen.dart';
import '../screens/permission_debug_screen.dart';
import '../screens/permission_test_screen.dart';
import '../screens/help_support_screen.dart';
import '../screens/comprehensive_functionality_test_screen.dart';
import '../screens/update_test_screen.dart';
import '../screens/app_health_check_screen.dart';
import '../screens/startup_diagnostics_screen.dart';
import '../screens/fcm_sound_test_screen.dart';
import '../screens/debug_auth_screen.dart';
import '../screens/debug_log_screen.dart';
import '../main.dart';

import '../services/theme_service.dart';

Map<String, WidgetBuilder> buildRoutes(ThemeService themeService) => {
  '/login': (_) => const LoginScreen(),
  '/register': (_) => const RegisterScreenMongoDB(),
  '/admin': (_) => const AdminPanelScreenMongoDB(),
  '/profile': (_) => const ProfileScreen(),
    '/chats': (_) => const ChatListScreenMongoDB(),
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
        themeService.setTheme(dark ? ThemeMode.dark : ThemeMode.light),
  ),
  '/debug-auth': (_) => const DebugAuthScreen(),
  '/debug-logs': (_) => const DebugLogScreen(),
};