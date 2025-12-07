import 'package:flutter/material.dart';

import '../screens/modern_login_screen.dart';
import '../screens/modern_register_screen.dart';
import '../screens/chat_list_screen_mongodb.dart';
import '../screens/admin_panel_screen_mongodb.dart';
import '../screens/user_search_screen.dart';
import '../screens/profile_screen.dart';
import '../screens/create_group_screen.dart';
import '../screens/settings_screen.dart';
import '../screens/notification_test_screen.dart';
import '../screens/hash_demo_screen.dart';
import '../screens/chat_integration_test_screen.dart';
import '../screens/permission_debug_screen.dart';
import '../screens/permission_test_screen.dart';
import '../screens/help_support_screen.dart';
import '../screens/comprehensive_functionality_test_screen.dart';
import '../screens/update_test_screen.dart';
import '../screens/app_health_check_screen.dart';
import '../screens/startup_diagnostics_screen.dart';
import '../screens/fcm_sound_test_screen.dart';
import '../screens/broadcast_messages_screen.dart';
import '../screens/call_screen.dart';
import '../services/call_types.dart';
import '../services/theme_service.dart';

/// Web routes: Use same screens as mobile for consistency
Map<String, WidgetBuilder> buildRoutes(ThemeService themeService) => {
  '/login': (_) => const ModernLoginScreen(),
  '/register': (_) => const ModernRegisterScreen(),
  '/chats': (_) => const ChatListScreenMongoDB(),
  '/admin': (_) => const AdminPanelScreenMongoDB(),
  '/search': (_) => const UserSearchScreen(),
  '/profile': (_) => const ProfileScreen(),
  '/create_group': (_) => const CreateGroupScreen(),
  '/notification-test': (_) => const NotificationTestScreen(),
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
  '/broadcasts': (_) => const BroadcastMessagesScreen(),
  // Call route - parameters passed via arguments
  '/call': (context) {
    final args = ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>;
    final callTypeStr = args['callType'] as String? ?? 'video';
    final directionStr = args['direction'] as String? ?? 'outgoing';
    
    return CallScreen(
      chatId: args['chatId'] as String,
      chatName: args['chatName'] as String,
      isGroupChat: args['isGroupChat'] as bool? ?? false,
      participantIds: args['participantIds'] as List<String>?,
      participantNames: args['participantNames'] as List<String>?,
      callType: callTypeStr == 'voice' ? CallType.voice : CallType.video,
      direction: directionStr == 'incoming' ? CallDirection.incoming : CallDirection.outgoing,
      callId: args['callId'] as String?,
    );
  },
};