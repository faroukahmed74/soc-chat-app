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
//
// ARCHITECTURE:
// - Uses ThemeService for theme management
// - Implements LocalizationService for language support
// - Provides persistent storage of user preferences
// - Responsive layout with conditional rendering
//
// PLATFORM SUPPORT:
// - Web: Full functionality with responsive design
// - Mobile: Touch-optimized interface
// - Cross-platform: Unified settings experience

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/theme_service.dart';
import '../services/localization_service.dart';


import '../services/admin_group_service.dart';
import '../services/chat_management_service.dart';
import '../services/production_permission_service.dart';
import 'package:permission_handler/permission_handler.dart';
import '../services/version_check_service.dart';
import '../services/logger_service.dart'; // Added import for logging
import '../widgets/update_dialog.dart';


class SettingsScreen extends StatefulWidget {
  final Function(bool)? onThemeChanged;
  
  const SettingsScreen({super.key, this.onThemeChanged});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _notificationsEnabled = true;
  bool _darkModeEnabled = false;
  String _currentLanguage = 'en';
  bool _isLoading = false;
  late ThemeService _themeService;

  @override
  void initState() {
    super.initState();
    // Set language to English only to prevent switching issues
    _currentLanguage = 'en';
    
    // Initialize theme service
    _themeService = ThemeService.instance;
    _themeService.addListener(_onThemeChanged);
    _darkModeEnabled = _themeService.isDarkMode;
    
    // Load settings (excluding language)
    _loadSettings();
    
    // Check notification status
    _checkNotificationStatus();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _notificationsEnabled = prefs.getBool('notifications_enabled') ?? true;
      _darkModeEnabled = _themeService.isDarkMode;
      // Language preference loading removed - fixed to English only
      // _currentLanguage = prefs.getString('language') ?? 'en';
    });
  }

  Future<void> _checkForUpdates(BuildContext context) async {
    setState(() {
      _isLoading = true;
    });

    try {
      final updateInfo = await VersionCheckService.checkForUpdates();
      
      if (updateInfo != null && updateInfo['hasUpdate'] == true) {
        // Add app name to update info
        updateInfo['appName'] = await VersionCheckService.getAppName();
        
        if (mounted) {
          // ignore: use_build_context_synchronously
          final navigator = Navigator.of(context);
          showDialog(
            context: navigator.context,
            barrierDismissible: updateInfo['forceUpdate'] != true,
            builder: (context) => UpdateDialog(
              updateInfo: updateInfo,
              onDismiss: () {
                Navigator.of(context).pop();
              },
            ),
          );
        }
      } else {
        if (mounted) {
          // ignore: use_build_context_synchronously
          final scaffoldMessenger = ScaffoldMessenger.of(context);
          scaffoldMessenger.showSnackBar(
            const SnackBar(
              content: Text('You are using the latest version!'),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        // ignore: use_build_context_synchronously
        final scaffoldMessenger = ScaffoldMessenger.of(context);
        scaffoldMessenger.showSnackBar(
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

  Future<void> _toggleNotifications(bool value) async {
    setState(() {
      _notificationsEnabled = value;
    });
    
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('notifications_enabled', value);
    
    if (value) {
      await FirebaseMessaging.instance.requestPermission();
    }
  }

  Future<void> _toggleDarkMode(bool value) async {
    setState(() {
      _darkModeEnabled = value;
    });
    
    if (value) {
      await _themeService.setTheme(ThemeMode.dark);
    } else {
      await _themeService.setTheme(ThemeMode.light);
    }
    
    widget.onThemeChanged?.call(value);
  }

  /// Callback when theme changes
  void _onThemeChanged() {
    if (mounted) {
      setState(() {
        _darkModeEnabled = _themeService.isDarkMode;
      });
    }
  }

  @override
  void dispose() {
    _themeService.removeListener(_onThemeChanged);
    super.dispose();
  }

  Future<void> _checkNotificationStatus() async {
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    try {
      setState(() => _isLoading = true);
      
      // Check notification permission status
      final hasPermission = await _checkNotificationPermission();
      
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Notification Status'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Permission Status: ${hasPermission ? "Granted" : "Denied"}'),
                const SizedBox(height: 8),
                Text('Notifications Enabled: $_notificationsEnabled'),
                const SizedBox(height: 8),
                const Text('Platform: ${kIsWeb ? "Web" : "Mobile"}'),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        scaffoldMessenger.showSnackBar(
          SnackBar(content: Text('Error checking status: $e')),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<bool> _checkNotificationPermission() async {
    try {
      if (kIsWeb) {
        return true; // Web notifications handled by browser
      }
      
      // Check Firebase messaging permission
      final messaging = FirebaseMessaging.instance;
      final settings = await messaging.getNotificationSettings();
      
      switch (settings.authorizationStatus) {
        case AuthorizationStatus.authorized:
          return true;
        case AuthorizationStatus.denied:
          return false;
        case AuthorizationStatus.notDetermined:
          return false;
        case AuthorizationStatus.provisional:
          return true;
      }
    } catch (e) {
              Log.e('Error checking notification permission', 'SETTINGS_SCREEN', e);
      return false;
    }
  }

  Future<void> _testNotification() async {
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    const AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
      'chat_channel',
      'Chat Notifications',
      channelDescription: 'Channel for testing notifications',
      importance: Importance.max,
      priority: Priority.high,
      enableVibration: true,
      playSound: true,
    );
    
    const DarwinNotificationDetails iosPlatformChannelSpecifics =
        DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );
    
    const NotificationDetails platformChannelSpecifics =
        NotificationDetails(
      android: androidPlatformChannelSpecifics,
      iOS: iosPlatformChannelSpecifics,
    );
    
    try {
      await FlutterLocalNotificationsPlugin().show(
        0,
        'Test Notification',
        'This is a test notification from the app',
        platformChannelSpecifics,
      );
      
      if (mounted) {
        scaffoldMessenger.showSnackBar(
          const SnackBar(
            content: Text('Test notification sent successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        scaffoldMessenger.showSnackBar(
          SnackBar(
            content: Text('Failed to send test notification: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }



  Future<void> _showMakeUserAdminDialog() async {
    final TextEditingController _emailController = TextEditingController();
    final TextEditingController _roleController = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Make User Admin'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _emailController,
              decoration: const InputDecoration(
                labelText: 'User Email',
                hintText: 'Enter user email',
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _roleController,
              decoration: const InputDecoration(
                labelText: 'Role (e.g., admin)',
                hintText: 'Enter role',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(AppLocalizations.getString('cancel', _currentLanguage)),
          ),
          ElevatedButton(
            onPressed: () async {
              final scaffoldMessenger = ScaffoldMessenger.of(context);
              final navigator = Navigator.of(context);
              final email = _emailController.text.trim();
              final role = _roleController.text.trim();

              if (email.isEmpty || role.isEmpty) {
                scaffoldMessenger.showSnackBar(
                  const SnackBar(
                    content: Text('Email and role cannot be empty.'),
                    backgroundColor: Colors.red,
                  ),
                );
                return;
              }
              setState(() {
                _isLoading = true;
              });

              try {
                final success = await AdminGroupService().makeUserAdminByEmail(email, role);
                if (success) {
                  scaffoldMessenger.showSnackBar(
                    const SnackBar(
                      content: Text('User promoted to admin successfully!'),
                      backgroundColor: Colors.green,
                    ),
                  );
                } else {
                  scaffoldMessenger.showSnackBar(
                    const SnackBar(
                      content: Text('Failed to promote user to admin.'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              } catch (e) {
                scaffoldMessenger.showSnackBar(
                  SnackBar(
                    content: Text('Error promoting user: $e'),
                    backgroundColor: Colors.red,
                  ),
                );
              } finally {
                setState(() {
                  _isLoading = false;
                });
              }
              navigator.pop(true);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              foregroundColor: Colors.white,
            ),
            child: Text(AppLocalizations.getString('promote', _currentLanguage)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      // Optionally, you might want to refresh the role status after promotion
      // For now, we'll just show a success message.
      // ignore: use_build_context_synchronously
      final scaffoldMessenger = ScaffoldMessenger.of(context);
      scaffoldMessenger.showSnackBar(
        const SnackBar(
          content: Text('User promoted to admin successfully!'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  Future<void> _showAllUsersDialog() async {
    // ignore: use_build_context_synchronously
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    final users = await AdminGroupService().getAllUsers();

    final confirmed = await showDialog<bool>(
      // ignore: use_build_context_synchronously
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('All Users'),
        content: ListView.builder(
          shrinkWrap: true,
          itemCount: users.length,
          itemBuilder: (context, index) {
            final user = users[index];
            return ListTile(
              title: Text('Email: ${user['email']}'),
              subtitle: Text('Role: ${user['role']}'),
            );
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(AppLocalizations.getString('close', _currentLanguage)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      // Optionally, you might want to refresh the role status after viewing
      // For now, we'll just show a success message.
      // ignore: use_build_context_synchronously
      scaffoldMessenger.showSnackBar(
        const SnackBar(
          content: Text('Viewed all users.'),
          backgroundColor: Colors.blue,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isWideScreen = MediaQuery.of(context).size.width > 600;
    final screenWidth = MediaQuery.of(context).size.width;
    
    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.getString('settings', _currentLanguage)),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: EdgeInsets.all(isWideScreen ? 24.0 : 16.0),
        children: [
          // Theme Settings
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        _darkModeEnabled ? Icons.dark_mode : Icons.light_mode,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        AppLocalizations.getString('dark_mode', _currentLanguage),
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  SwitchListTile(
                    title: Text(
                      _darkModeEnabled 
                        ? AppLocalizations.getString('dark_mode', _currentLanguage)
                        : AppLocalizations.getString('light_mode', _currentLanguage),
                    ),
                    subtitle: Text(
                      _darkModeEnabled 
                        ? AppLocalizations.getString('switch_to_light_mode', _currentLanguage)
                        : AppLocalizations.getString('switch_to_dark_mode', _currentLanguage),
                    ),
                    value: _darkModeEnabled,
                    onChanged: _toggleDarkMode,
                    secondary: Icon(
                      _darkModeEnabled ? Icons.dark_mode : Icons.light_mode,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Language Settings - REMOVED DUE TO ISSUES
          // Temporarily removed until language switching issues are resolved
          
          const SizedBox(height: 16),
          
          // Notification Settings
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.notifications,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        AppLocalizations.getString('notifications', _currentLanguage),
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  SwitchListTile(
                    title: Text('Enable Notifications'),
                    subtitle: const Text('Receive push notifications'),
                    value: _notificationsEnabled,
                    onChanged: _toggleNotifications,
                    secondary: Icon(
                      Icons.notifications,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _testNotification,
                      icon: const Icon(Icons.notification_add),
                      label: const Text('Test Notification'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _checkNotificationStatus,
                      icon: const Icon(Icons.info_outline),
                      label: const Text('Check Notification Status'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () => Navigator.pushNamed(context, '/fcm-test'),
                      icon: const Icon(Icons.cloud_upload),
                      label: const Text('Test FCM Server'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                                     SizedBox(
                     width: double.infinity,
                     child: ElevatedButton.icon(
                       onPressed: () => Navigator.pushNamed(context, '/chat-integration-test'),
                       icon: const Icon(Icons.chat_bubble),
                       label: const Text('Test Chat-FCM Integration'),
                       style: ElevatedButton.styleFrom(
                         padding: const EdgeInsets.symmetric(vertical: 12),
                         backgroundColor: Colors.purple,
                         foregroundColor: Colors.white,
                       ),
                     ),
                   ),
                   const SizedBox(height: 8),
                   SizedBox(
                     width: double.infinity,
                     child: ElevatedButton.icon(
                       onPressed: () => Navigator.pushNamed(context, '/permission-debug'),
                       icon: const Icon(Icons.security),
                       label: const Text('Debug Permissions'),
                       style: ElevatedButton.styleFrom(
                         padding: const EdgeInsets.symmetric(vertical: 12),
                         backgroundColor: Colors.orange,
                         foregroundColor: Colors.white,
                       ),
                     ),
                   ),

                ],
              ),
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Account Settings
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.account_circle,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'Account',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  ListTile(
                    leading: Icon(
                      Icons.person,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    title: const Text('Edit Profile'),
                    subtitle: const Text('Update your profile information'),
                    onTap: () => Navigator.pushNamed(context, '/profile'),
                  ),
                  ListTile(
                    leading: Icon(
                      Icons.lock,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    title: const Text('Change Password'),
                    subtitle: const Text('Update your password'),
                    onTap: () {
                      // Navigate to change password screen
                    },
                  ),

                ],
              ),
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Role Management Section - Only show if user is admin
          FutureBuilder<bool>(
            future: AdminGroupService().isCurrentUserAdmin(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const SizedBox.shrink();
              }
              
              if (snapshot.data == true) {
                return Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.admin_panel_settings,
                              color: Colors.orange,
                            ),
                            const SizedBox(width: 12),
                            Text(
                              'Role Management',
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        ListTile(
                          leading: Icon(
                            Icons.person_add,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                          title: const Text('Make User Admin'),
                          subtitle: const Text('Promote a user to admin role'),
                          onTap: () => _showMakeUserAdminDialog(),
                        ),
                        ListTile(
                          leading: Icon(
                            Icons.people,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                          title: const Text('View All Users'),
                          subtitle: const Text('See all users and their roles'),
                          onTap: () => _showAllUsersDialog(),
                        ),
                      ],
                    ),
                  ),
                );
              }
              
              return const SizedBox.shrink();
            },
          ),
          
          const SizedBox(height: 16),
          
          // Permission Status Section
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.security,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'Permission Status',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  FutureBuilder<Map<String, dynamic>>(
                    future: ProductionPermissionService.getPermissionStatus(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      
                      if (snapshot.hasError) {
                        return Text('Error: ${snapshot.error}');
                      }
                      
                      final data = snapshot.data ?? {};
                      final platform = data['platform'] ?? 'Unknown';
                      final needsSettingsReset = data['needsSettingsReset'] ?? false;
                      
                      return Column(
                        children: [
                          ListTile(
                            leading: Icon(
                              Icons.devices,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                            title: const Text('Platform'),
                            subtitle: Text('$platform'),
                          ),
                          if (data['camera'] != null) ...[
                            ListTile(
                              leading: Icon(
                                data['camera'] == 'granted' ? Icons.camera_alt : Icons.camera_alt_outlined,
                                color: data['camera'] == 'granted' ? Colors.green : Colors.red,
                              ),
                              title: const Text('Camera'),
                              subtitle: Text('Status: ${data['camera']}'),
                              trailing: data['camera'] == 'granted' 
                                  ? const Icon(Icons.check_circle, color: Colors.green)
                                  : const Icon(Icons.error, color: Colors.red),
                            ),
                          ],
                          if (data['photos'] != null) ...[
                            ListTile(
                              leading: Icon(
                                data['photos'] == 'granted' || data['photos'] == 'limited' ? Icons.photo_library : Icons.photo_library_outlined,
                                color: data['photos'] == 'granted' || data['photos'] == 'limited' ? Colors.green : Colors.red,
                              ),
                              title: const Text('Photos'),
                              subtitle: Text('Status: ${data['photos']}'),
                              trailing: data['photos'] == 'granted' || data['photos'] == 'limited'
                                  ? const Icon(Icons.check_circle, color: Colors.green)
                                  : const Icon(Icons.error, color: Colors.red),
                            ),
                          ],
                          if (data['microphone'] != null) ...[
                            ListTile(
                              leading: Icon(
                                data['microphone'] == 'granted' ? Icons.mic : Icons.mic_off,
                                color: data['microphone'] == 'granted' ? Colors.green : Colors.red,
                            ),
                              title: const Text('Microphone'),
                              subtitle: Text('Status: ${data['microphone']}'),
                              trailing: data['microphone'] == 'granted'
                                  ? const Icon(Icons.check_circle, color: Colors.green)
                                  : const Icon(Icons.error, color: Colors.red),
                            ),
                          ],
                          if (data['storage'] != null) ...[
                            ListTile(
                              leading: Icon(
                                data['storage'] == 'granted' ? Icons.folder : Icons.folder_outlined,
                                color: data['storage'] == 'granted' ? Colors.green : Colors.red,
                              ),
                              title: const Text('Storage'),
                              subtitle: Text('Status: ${data['storage']}'),
                              trailing: data['storage'] == 'granted'
                                  ? const Icon(Icons.check_circle, color: Colors.green)
                                  : const Icon(Icons.error, color: Colors.red),
                            ),
                          ],
                          if (data['notification'] != null) ...[
                            ListTile(
                              leading: Icon(
                                data['notification'] == 'granted' ? Icons.notifications : Icons.notifications_off,
                                color: data['notification'] == 'granted' ? Colors.green : Colors.red,
                              ),
                              title: const Text('Notifications'),
                              subtitle: Text('Status: ${data['notification']}'),
                              trailing: data['notification'] == 'granted'
                                  ? const Icon(Icons.check_circle, color: Colors.green)
                                  : const Icon(Icons.error, color: Colors.red),
                            ),
                          ],
                          if (data['location'] != null) ...[
                            ListTile(
                              leading: Icon(
                                data['location'] == 'granted' ? Icons.location_on : Icons.location_off,
                                color: data['location'] == 'granted' ? Colors.green : Colors.red,
                              ),
                              title: const Text('Location'),
                              subtitle: Text('Status: ${data['location']}'),
                              trailing: data['location'] == 'granted'
                                  ? const Icon(Icons.check_circle, color: Colors.green)
                                  : const Icon(Icons.error, color: Colors.red),
                            ),
                          ],
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: () => _showPermissionStatusDialog(context),
                                  icon: const Icon(Icons.info),
                                  label: const Text('View Details'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.blue,
                                    foregroundColor: Colors.white,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: () => openAppSettings(),
                                  icon: const Icon(Icons.settings),
                                  label: const Text('Settings'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.orange,
                                    foregroundColor: Colors.white,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Permissions are requested when you use features. Use Settings to reset denied permissions.',
                            style: TextStyle(fontSize: 12, color: Colors.grey),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Chat Migration
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.chat,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(width: 12),
                      const Text(
                        'Chat Management',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
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
                            const SnackBar(content: Text('Chat names updated successfully!')),
                          );
                        }
                      } catch (e) {
                        if (mounted) {
                          scaffoldMessenger.showSnackBar(
                            SnackBar(content: Text('Error updating chat names: $e')),
                          );
                        }
                      }
                    },
                  ),
                ],
              ),
            ),
          ),
          
          const SizedBox(height: 16),
          
          // App Information
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.info,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        AppLocalizations.getString('about', _currentLanguage),
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  ListTile(
                    leading: Icon(
                      Icons.info_outline,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    title: Text(AppLocalizations.getString('version', _currentLanguage)),
                    subtitle: FutureBuilder<String>(
                      future: VersionCheckService.getCurrentVersion(),
                      builder: (context, snapshot) {
                        if (snapshot.hasData) {
                          return Text(snapshot.data!);
                        }
                        return const Text('Loading...');
                      },
                    ),
                  ),
                  // Android-only update check
                  if (defaultTargetPlatform == TargetPlatform.android)
                    ListTile(
                      leading: Icon(
                        Icons.system_update,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      title: const Text('Check for Updates'),
                      subtitle: const Text('Check for app updates'),
                      onTap: () => _checkForUpdates(context),
                    ),
                  ListTile(
                    leading: Icon(
                      Icons.description,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    title: Text(AppLocalizations.getString('terms_of_service', _currentLanguage)),
                    subtitle: const Text('Read our terms of service'),
                    onTap: () {
                      // Navigate to terms of service
                    },
                  ),
                  ListTile(
                    leading: Icon(
                      Icons.privacy_tip,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    title: Text(AppLocalizations.getString('privacy_policy', _currentLanguage)),
                    subtitle: const Text('Read our privacy policy'),
                    onTap: () {
                      // Navigate to privacy policy
                    },
                  ),
                ],
              ),
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Logout Button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () async {
                final navigator = Navigator.of(context);
                final confirmed = await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: Text(AppLocalizations.getString('logout', _currentLanguage)),
                    content: Text('Are you sure you want to logout?'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: Text(AppLocalizations.getString('cancel', _currentLanguage)),
                      ),
                      ElevatedButton(
                        onPressed: () => Navigator.pop(context, true),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          foregroundColor: Colors.white,
                        ),
                        child: Text(AppLocalizations.getString('logout', _currentLanguage)),
                      ),
                    ],
                  ),
                );
                
                if (confirmed == true) {
                  await FirebaseAuth.instance.signOut();
                  if (mounted) {
                    navigator.pushReplacementNamed('/login');
                  }
                }
              },
              icon: const Icon(Icons.logout),
              label: Text(AppLocalizations.getString('logout', _currentLanguage)),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Show permission status dialog
  void _showPermissionStatusDialog(BuildContext context) async {
            final status = await ProductionPermissionService.getPermissionStatus();
    
    if (status.isEmpty) return;
    
    // ignore: use_build_context_synchronously
    showDialog(
      // ignore: use_build_context_synchronously
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Permission Status'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Platform: ${defaultTargetPlatform.name}'),
            if (status['camera'] != null) Text('Camera: ${status['camera']}'),
            if (status['photos'] != null) Text('Photos: ${status['photos']}'),
            if (status['microphone'] != null) Text('Microphone: ${status['microphone']}'),
            if (status['notification'] != null) Text('Notifications: ${status['notification']}'),
            if (status['location'] != null) Text('Location: ${status['location']}'),
            const SizedBox(height: 16),
            if (status['overallWorking'] == false)
              const Text(
                'Some permissions are not working. You may need to enable them in device settings.',
                style: TextStyle(fontStyle: FontStyle.italic, color: Colors.orange),
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
          if (status['overallWorking'] == false)
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                openAppSettings();
              },
              child: const Text('Open Settings'),
            ),
        ],
      ),
    );
  }
} 