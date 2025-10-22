import 'package:flutter/material.dart';

import '../screens/login_screen.dart';
import '../screens/register_screen_mongodb.dart';
import '../screens/enhanced_admin_panel.dart';
import '../screens/chat_list_screen_mongodb.dart';
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
import '../screens/profile_view.dart';
import '../screens/notification_test_screen.dart';

import '../services/theme_service.dart';
import '../services/physical_auth_service.dart';

Future<String?> _getCurrentUserId() async {
  final authService = PhysicalAuthService();
  final user = await authService.getCurrentUser();
  return user?['id'];
}

Map<String, WidgetBuilder> buildRoutes(ThemeService themeService) => {
  '/login': (_) => const LoginScreen(),
  '/register': (_) => const RegisterScreenMongoDB(),
  '/admin': (_) => const EnhancedAdminPanel(),
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
  '/notification-test': (_) => const NotificationTestScreen(),
  '/profile': (_) => FutureBuilder<String?>(
    future: _getCurrentUserId(),
    builder: (context, snapshot) {
      if (snapshot.hasData && snapshot.data != null) {
        return ProfileView(userId: snapshot.data!);
      }
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    },
  ),
  '/settings': (_) => SettingsScreen(
    onThemeChanged: (bool dark) =>
        themeService.setTheme(dark ? ThemeMode.dark : ThemeMode.light),
  ),
};