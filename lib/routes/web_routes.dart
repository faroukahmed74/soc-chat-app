import 'package:flutter/material.dart';

import '../screens/login_screen.dart';
import '../screens/register_screen_mongodb.dart';
import '../screens/chat_list_screen_web_mongodb.dart';

import '../services/theme_service.dart';

/// Web-safe routes: avoid importing screens/services that rely on dart:io.
Map<String, WidgetBuilder> buildRoutes(ThemeService themeService) => {
  '/login': (_) => const LoginScreen(),
  '/register': (_) => const RegisterScreenMongoDB(),
    '/chats': (_) => const ChatListScreenWebMongoDB(),
};