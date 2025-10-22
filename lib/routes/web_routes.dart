import 'package:flutter/material.dart';

import '../screens/login_screen.dart';
import '../screens/register_screen_mongodb.dart';
import '../screens/chat_list_screen_web_mongodb.dart';
import '../screens/enhanced_admin_panel.dart';
import '../screens/user_search_screen.dart';
import '../screens/user_profile_web_screen.dart';
import '../screens/create_group_screen.dart';
import '../screens/settings_screen.dart';
import '../screens/notification_test_screen.dart';

import '../services/theme_service.dart';

/// Web-safe routes: avoid importing screens/services that rely on dart:io.
Map<String, WidgetBuilder> buildRoutes(ThemeService themeService) => {
  '/login': (_) => const LoginScreen(),
  '/register': (_) => const RegisterScreenMongoDB(),
    '/chats': (_) => const ChatListScreenWebMongoDB(),
    '/admin': (_) => const EnhancedAdminPanel(),
    // Web-safe additions
    '/search': (_) => const UserSearchScreen(),
    '/profile': (_) => const UserProfileWebScreen(),
    '/create_group': (_) => const CreateGroupScreen(),
    '/notification-test': (_) => const NotificationTestScreen(),
    '/settings': (_) => SettingsScreen(
      onThemeChanged: (bool dark) =>
          themeService.setTheme(dark ? ThemeMode.dark : ThemeMode.light),
    ),
};