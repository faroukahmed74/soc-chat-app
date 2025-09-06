// =============================================================================
// SETTINGS SCREEN
// =============================================================================
// This screen provides comprehensive user settings and app configuration options.
// It includes theme switching, language selection, notification preferences,
// and various app management features.
//
// KEY FEATURES:
// - Theme switching (light/dark mode)
// - Language selection (English/Arabic)
// - Notification preferences
// - Account management
// - App information and version
// - Responsive design for different screen sizes
// - Admin-only test features
//
// ARCHITECTURE:
// - Uses ThemeService for theme management
// - Implements LocalizationService for language support
// - Provides persistent storage of user preferences
// - Responsive layout with conditional rendering
// - Role-based access control for admin features
//
// PLATFORM SUPPORT:
// - Web: Full functionality with responsive design
// - Mobile: Touch-optimized interface
// - Cross-platform: Unified settings experience

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';

import 'package:firebase_auth/firebase_auth.dart';



import 'package:shared_preferences/shared_preferences.dart';

import '../services/theme_service.dart';

import '../services/admin_group_service.dart';
import '../services/chat_management_service.dart';



import '../services/fixed_version_check_service.dart';
import '../services/logger_service.dart';
import '../widgets/update_dialog.dart';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class SettingsScreen extends StatefulWidget {
  final Function(bool)? onThemeChanged;
  
  const SettingsScreen({super.key, this.onThemeChanged});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _notificationsEnabled = true;
  bool _darkModeEnabled = false;

  bool _isLoading = false;
  bool _isAdmin = false;
  late ThemeService _themeService;
  late AdminGroupService _adminService;

  @override
  void initState() {
    super.initState();
    // Set language to English only to prevent switching issues
    
    // Initialize services
    _themeService = ThemeService.instance;
    _adminService = AdminGroupService();
    _themeService.addListener(_onThemeChanged);
    _darkModeEnabled = _themeService.isDarkMode;
    
    // Load settings and check admin status
    _loadSettings();
    _checkAdminStatus();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _notificationsEnabled = prefs.getBool('notifications_enabled') ?? true;
      _darkModeEnabled = _themeService.isDarkMode;
    });
  }

  Future<void> _checkAdminStatus() async {
    try {
      final isAdmin = await _adminService.isCurrentUserAdmin();
      setState(() {
        _isAdmin = isAdmin;
      });
    } catch (e) {
      Log.e('Error checking admin status', 'SETTINGS_SCREEN', e);
    }
  }

  Future<void> _checkForUpdates(BuildContext context) async {
    setState(() {
      _isLoading = true;
    });

    try {
      final updateInfo = await FixedVersionCheckService.checkForUpdates();
      
      if (updateInfo != null && updateInfo['hasUpdate'] == true) {
        if (mounted) {
                      showDialog(
              context: context,
              builder: (context) => UpdateDialog(
                updateInfo: updateInfo,
                onDismiss: () {
                  // Handle dismiss action
                  Navigator.pop(context);
                },
              ),
            );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('No updates available'),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error checking for updates: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _onThemeChanged() {
    setState(() {
      _darkModeEnabled = _themeService.isDarkMode;
    });
    widget.onThemeChanged?.call(_darkModeEnabled);
  }

  Future<void> _toggleTheme() async {
    await _themeService.toggleTheme();
  }

  Future<void> _toggleNotifications() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _notificationsEnabled = !_notificationsEnabled;
    });
    await prefs.setBool('notifications_enabled', _notificationsEnabled);
  }

  @override
  void dispose() {
    _themeService.removeListener(_onThemeChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 600;
    final isMediumScreen = screenWidth >= 600 && screenWidth < 1200;
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        elevation: 2,
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(isSmallScreen ? 16.0 : 24.0),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: isMediumScreen ? 800 : 1200,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Theme Settings
              _buildSettingsCard(
                title: 'Theme Settings',
                icon: Icons.palette,
                iconColor: Colors.blue,
                children: [
                  SwitchListTile(
                    title: const Text('Dark Mode'),
                    subtitle: const Text('Switch between light and dark themes'),
                    value: _darkModeEnabled,
                    onChanged: (value) => _toggleTheme(),
                    secondary: Icon(
                      _darkModeEnabled ? Icons.dark_mode : Icons.light_mode,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 16),
              
              // Notification Settings
              _buildSettingsCard(
                title: 'Notification Settings',
                icon: Icons.notifications,
                iconColor: Colors.orange,
                children: [
                  SwitchListTile(
                    title: const Text('Enable Notifications'),
                    subtitle: const Text('Receive push notifications for messages and updates'),
                    value: _notificationsEnabled,
                    onChanged: (value) => _toggleNotifications(),
                    secondary: Icon(
                      Icons.notifications_active,
                      color: _notificationsEnabled ? Colors.green : Colors.grey,
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 16),
              
              // Language Settings
              _buildSettingsCard(
                title: 'Language Settings',
                icon: Icons.language,
                iconColor: Colors.green,
                children: [
                  ListTile(
                    title: const Text('Language'),
                    subtitle: const Text('English (Fixed)'),
                    leading: const Icon(Icons.language),
                    trailing: const Icon(Icons.lock, color: Colors.grey),
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16.0),
                    child: Text(
                      'Language switching is temporarily disabled to prevent issues',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 16),
              
              // Admin Test Features (Only for Admin Users)
              if (_isAdmin) ...[
                _buildSettingsCard(
                  title: 'Admin Test Features',
                  icon: Icons.admin_panel_settings,
                  iconColor: Colors.purple,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () {
                              Navigator.pushNamed(context, '/permission-test');
                            },
                            icon: const Icon(Icons.bug_report),
                            label: const Text('Test Permissions'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Theme.of(context).colorScheme.secondary,
                              foregroundColor: Colors.white,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () async {
                              try {
                                // Test local notification
                                final localNotifications = FlutterLocalNotificationsPlugin();
                                
                                // Initialize if needed
                                const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
                                const iosSettings = DarwinInitializationSettings(
                                  requestAlertPermission: true,
                                  requestBadgePermission: true,
                                  requestSoundPermission: true,
                                );
                                const initSettings = InitializationSettings(
                                  android: androidSettings,
                                  iOS: iosSettings,
                                );
                                
                                await localNotifications.initialize(initSettings);
                                
                                // Request iOS permissions explicitly
                                if (defaultTargetPlatform == TargetPlatform.iOS) {
                                  await localNotifications
                                      .resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>()
                                      ?.requestPermissions(
                                        alert: true,
                                        badge: true,
                                        sound: true,
                                      );
                                }
                                
                                // Show test notification
                                await localNotifications.show(
                                  999,
                                  '🔔 Test Notification',
                                  'This is a test notification from the real system!',
                                  const NotificationDetails(
                                    android: AndroidNotificationDetails(
                                      'test_channel',
                                      'Test Notifications',
                                      importance: Importance.high,
                                      priority: Priority.high,
                                    ),
                                    iOS: DarwinNotificationDetails(
                                      presentAlert: true,
                                      presentBadge: true,
                                      presentSound: true,
                                    ),
                                  ),
                                );
                                
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('✅ Test notification sent!'),
                                    backgroundColor: Colors.green,
                                  ),
                                );
                              } catch (e) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('❌ Error: $e'),
                                    backgroundColor: Colors.red,
                                  ),
                                );
                              }
                            },
                            icon: const Icon(Icons.notifications_active),
                            label: const Text('Test Real Notification'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green.shade600,
                              foregroundColor: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Navigator.pushNamed(context, '/comprehensive-test');
                        },
                        icon: const Icon(Icons.app_registration),
                        label: const Text('Comprehensive App Test'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.deepPurple,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Admin-only testing tools for debugging and system verification',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
                const SizedBox(height: 16),
              ],
              
              // Chat Management
              _buildSettingsCard(
                title: 'Chat Management',
                icon: Icons.chat,
                iconColor: Colors.blue,
                children: [
                  ListTile(
                    leading: Icon(
                      Icons.build,
                      color: Colors.orange,
                    ),
                    title: const Text('Fix Chat Names'),
                    subtitle: const Text('Update existing chats with proper user names'),
                    onTap: () async {
                      final scaffoldMessenger = ScaffoldMessenger.of(context);
                      try {
                        // Show loading indicator
                        scaffoldMessenger.showSnackBar(
                          const SnackBar(content: Text('Updating chat names...')),
                        );
                        
                        // Call the migration function
                        await ChatManagementService.fixMissingUserNames();
                        
                        if (mounted) {
                          scaffoldMessenger.showSnackBar(
                            const SnackBar(
                              content: Text('Chat names updated successfully!'),
                              backgroundColor: Colors.green,
                            ),
                          );
                        }
                      } catch (e) {
                        if (mounted) {
                          scaffoldMessenger.showSnackBar(
                            SnackBar(
                              content: Text('Error updating chat names: $e'),
                              backgroundColor: Colors.red,
                            ),
                          );
                        }
                      }
                    },
                  ),
                ],
              ),
              
              const SizedBox(height: 16),
              
              // App Information
              _buildSettingsCard(
                title: 'App Information',
                icon: Icons.info,
                iconColor: Colors.teal,
                children: [
                  ListTile(
                    leading: const Icon(Icons.info_outline),
                    title: const Text('Version'),
                    subtitle: const Text('1.0.0 (Build 1)'),
                  ),
                  ListTile(
                    leading: const Icon(Icons.update),
                    title: const Text('Check for Updates'),
                    subtitle: const Text('Check if a new version is available'),
                    onTap: () => _checkForUpdates(context),
                    trailing: _isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.arrow_forward_ios),
                  ),
                ],
              ),
              
              const SizedBox(height: 16),
              
              // Account Actions
              _buildSettingsCard(
                title: 'Account Actions',
                icon: Icons.account_circle,
                iconColor: Colors.indigo,
                children: [
                  ListTile(
                    leading: const Icon(Icons.logout, color: Colors.red),
                    title: const Text('Sign Out'),
                    subtitle: const Text('Sign out of your account'),
                    onTap: () async {
                      final confirmed = await showDialog<bool>(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: const Text('Sign Out'),
                          content: const Text('Are you sure you want to sign out?'),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context, false),
                              child: const Text('Cancel'),
                            ),
                            TextButton(
                              onPressed: () => Navigator.pop(context, true),
                              child: const Text('Sign Out'),
                              style: TextButton.styleFrom(foregroundColor: Colors.red),
                            ),
                          ],
                        ),
                      );
                      
                      if (confirmed == true && mounted) {
                        await FirebaseAuth.instance.signOut();
                        if (mounted) {
                          Navigator.of(context).pushNamedAndRemoveUntil(
                            '/login',
                            (route) => false,
                          );
                        }
                      }
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSettingsCard({
    required String title,
    required IconData icon,
    required Color iconColor,
    required List<Widget> children,
  }) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: iconColor),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ...children,
          ],
        ),
      ),
    );
  }
} 