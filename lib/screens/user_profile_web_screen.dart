// =============================================================================
// USER PROFILE SCREEN - WEB SAFE
// =============================================================================
// Minimal web-friendly user profile view using PhysicalAuthService.
// Shows current user's basic info and provides quick actions.

import 'package:flutter/material.dart';
import '../services/physical_auth_service.dart';
import '../services/theme_service.dart';
import '../utils/responsive_utils.dart';

class UserProfileWebScreen extends StatefulWidget {
  const UserProfileWebScreen({Key? key}) : super(key: key);

  @override
  State<UserProfileWebScreen> createState() => _UserProfileWebScreenState();
}

class _UserProfileWebScreenState extends State<UserProfileWebScreen> {
  final PhysicalAuthService _authService = PhysicalAuthService();
  late ThemeService _themeService;
  Map<String, dynamic>? _user;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _themeService = ThemeService.instance;
    _themeService.addListener(() {
      if (mounted) setState(() {});
    });
    _loadUser();
  }

  Future<void> _loadUser() async {
    try {
      final user = await _authService.getCurrentUser();
      if (mounted) {
        setState(() {
          _user = user;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = _themeService.isDarkMode;
    final bg = isDark ? Colors.grey[900] : Colors.white;
    final fg = isDark ? Colors.white : Colors.black87;
    final primary = isDark ? Colors.blue[700] : Colors.blue[500];

    final displayName = (_user?['name'] ?? _user?['username'] ?? '').toString();
    final email = (_user?['email'] ?? '').toString();

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Profile'),
        backgroundColor: isDark ? Colors.grey[900] : Colors.blue,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: Icon(isDark ? Icons.light_mode : Icons.dark_mode),
            onPressed: _themeService.toggleTheme,
            tooltip: isDark ? 'Switch to Light Mode' : 'Switch to Dark Mode',
          ),
        ],
      ),
      body: Container(
        color: bg,
        padding: const EdgeInsets.all(24),
        child: Center(
          child: _loading
              ? const CircularProgressIndicator()
              : ConstrainedBox(
                  constraints: ResponsiveUtils.getResponsiveCardConstraints(context),
                  child: Card(
                    elevation: 2,
                    child: Padding(
                      padding: ResponsiveUtils.getResponsivePadding(context),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CircleAvatar(
                            radius: ResponsiveUtils.getResponsiveAvatarRadius(context),
                            backgroundColor: primary,
                            child: Text(
                              (displayName.isNotEmpty ? displayName[0] : (email.isNotEmpty ? email[0] : 'U')).toUpperCase(),
                              style: TextStyle(
                                color: Colors.white, 
                                fontSize: ResponsiveUtils.getResponsiveFontSize(context, baseSize: 28.0), 
                                fontWeight: FontWeight.bold
                              ),
                            ),
                          ),
                          SizedBox(height: ResponsiveUtils.getResponsiveSpacing(context)),
                          Text(
                            displayName.isNotEmpty ? displayName : 'Unknown User',
                            style: ResponsiveUtils.getResponsiveHeadingStyle(context, color: fg),
                          ),
                          SizedBox(height: ResponsiveUtils.getResponsiveSpacing(context) / 2),
                          if (email.isNotEmpty)
                            Text(
                              email,
                              style: TextStyle(color: fg.withValues(alpha: 0.7)),
                            ),
                          SizedBox(height: ResponsiveUtils.getResponsiveSpacing(context) * 1.5),
                          Wrap(
                            spacing: 12,
                            runSpacing: 12,
                            alignment: WrapAlignment.center,
                            children: [
                              ElevatedButton.icon(
                                onPressed: () {
                                  Navigator.pushNamed(context, '/search');
                                },
                                icon: const Icon(Icons.search),
                                label: const Text('Find Users'),
                              ),
                              ElevatedButton.icon(
                                onPressed: () {
                                  Navigator.pushNamed(context, '/chats');
                                },
                                icon: const Icon(Icons.chat),
                                label: const Text('My Chats'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
        ),
      ),
    );
  }
}