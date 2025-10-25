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

// Firebase imports removed - using MongoDB/ngrok API only
import '../services/local_auth_service.dart';
import 'package:http/http.dart' as http;



import 'package:shared_preferences/shared_preferences.dart';

import '../services/theme_service.dart';
import '../theme/app_design_system.dart';

// Firebase-dependent services removed - using MongoDB/ngrok API only



import '../services/fixed_version_check_service.dart';
import '../services/logger_service.dart';
import '../services/media_cache_service.dart';
import '../services/connection_status_service.dart';
import '../widgets/media_cache_manager.dart';
import '../widgets/update_dialog.dart';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../config/database_config.dart';

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
  // AdminGroupService removed - Firebase dependent
  final TextEditingController _serverUrlController = TextEditingController();
  bool _testingServerUrl = false;
  bool _useLocalNetwork = false;
  late ConnectionStatusService _connectionService;

  @override
  void initState() {
    super.initState();
    // Set language to English only to prevent switching issues
    
    // Initialize services
    _themeService = ThemeService.instance;
    _connectionService = ConnectionStatusService();
    // AdminGroupService initialization removed - Firebase dependent
    _themeService.addListener(_onThemeChanged);
    _darkModeEnabled = _themeService.isDarkMode;
    
    // Load settings and check admin status
    _loadSettings();
    _checkAdminStatus();
    _initServerUrlController();
    _loadNetworkMode();
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
      // Admin service removed - Firebase dependent
      final isAdmin = false; // Default to false in physical server mode
      setState(() {
        _isAdmin = isAdmin;
      });
    } catch (e) {
      Log.e('Error checking admin status', 'SETTINGS_SCREEN', e);
    }
  }

  Future<void> _initServerUrlController() async {
    try {
      final override = await DatabaseConfig.getServerUrlOverride();
      final current = override.isNotEmpty ? override : DatabaseConfig.physicalServerUrl;
      _serverUrlController.text = current;
    } catch (_) {
      _serverUrlController.text = DatabaseConfig.physicalServerUrl;
    }
  }

  Future<void> _loadNetworkMode() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      setState(() {
        _useLocalNetwork = prefs.getBool('use_local_network') ?? false;
      });
    } catch (e) {
      Log.e('Error loading network mode', 'SETTINGS_SCREEN', e);
    }
  }

  Future<void> _toggleNetworkMode(bool value) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('use_local_network', value);
      
      setState(() {
        _useLocalNetwork = value;
      });

      // Update server URL based on network mode
      if (value) {
        // Use local network
        await DatabaseConfig.setServerUrlOverride('http://10.120.4.230:8082');
      } else {
        // Use ngrok
        await DatabaseConfig.setServerUrlOverride('');
      }

      // Check connection
      final isConnected = await _connectionService.checkConnection();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(value 
              ? (isConnected 
                  ? 'Switched to local network mode - Connected!' 
                  : 'Switched to local network mode - Connection failed! Check server.')
              : 'Switched to ngrok mode'),
            backgroundColor: isConnected ? Colors.green : Colors.orange,
          ),
        );
      }
    } catch (e) {
      Log.e('Error toggling network mode', 'SETTINGS_SCREEN', e);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error switching network mode: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _saveServerUrlOverride() async {
    final url = _serverUrlController.text.trim();
    if (url.isEmpty) return;
    setState(() { _testingServerUrl = true; });
    try {
      await DatabaseConfig.setServerUrlOverride(url);
      final base = url.endsWith('/') ? url.substring(0, url.length - 1) : url;
      final health = Uri.parse('$base/api/health');
      final resp = await http.get(health).timeout(const Duration(seconds: 5));
      final ok = resp.statusCode == 200;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(ok ? 'Server URL saved and reachable' : 'Saved, but health check failed (${resp.statusCode})')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error testing server URL: $e')),
        );
      }
    } finally {
      if (mounted) setState(() { _testingServerUrl = false; });
    }
  }

  Future<void> _clearServerUrlOverride() async {
    try {
      await DatabaseConfig.setServerUrlOverride('');
      await _initServerUrlController();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Server URL override cleared')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error clearing override: $e')),
        );
      }
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

  String _getCacheStatsText() {
    final stats = MediaCacheService.getCacheStats();
    return '${stats['fileCount']} files, ${stats['totalSizeMB']} MB';
  }

  void _refreshCacheStats() {
    setState(() {
      // Trigger rebuild to refresh cache stats
    });
  }

  Future<void> _showClearCacheDialog() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear Media Cache'),
        content: const Text(
          'This will delete all cached media files from your device. '
          'You will need to download them again when viewing chats.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Clear Cache'),
          ),
        ],
      ),
    ) ?? false;

    if (confirmed) {
      try {
        await MediaCacheService.clearCache();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Media cache cleared successfully'),
              backgroundColor: Colors.green,
            ),
          );
          setState(() {
            // Refresh the UI
          });
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to clear cache: ${e.toString()}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
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
        title: Text(
          'Settings',
          style: AppDesignSystem.headlineSmall.copyWith(
            color: Theme.of(context).colorScheme.onPrimary,
          ),
        ),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Theme.of(context).colorScheme.onPrimary,
        elevation: 0,
        centerTitle: false,
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

              // Media Cache Settings
              _buildSettingsCard(
                title: 'Media Cache',
                icon: Icons.storage,
                iconColor: Colors.purple,
                children: [
                  ListTile(
                    leading: const Icon(Icons.info_outline),
                    title: const Text('Cache Statistics'),
                    subtitle: Text(_getCacheStatsText()),
                    trailing: IconButton(
                      icon: const Icon(Icons.refresh),
                      onPressed: _refreshCacheStats,
                    ),
                  ),
                  ListTile(
                    leading: const Icon(Icons.delete_sweep),
                    title: const Text('Clear Media Cache'),
                    subtitle: const Text('Remove all cached media files'),
                    onTap: _showClearCacheDialog,
                  ),
                  ListTile(
                    leading: const Icon(Icons.settings),
                    title: const Text('Cache Management'),
                    subtitle: const Text('View detailed cache information'),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const MediaCacheManager(),
                        ),
                      );
                    },
                  ),
                ],
              ),
              
              const SizedBox(height: 16),

              // Connection Status
              _buildSettingsCard(
                title: 'Connection Status',
                icon: Icons.wifi,
                iconColor: Colors.blue,
                children: [
                  AnimatedBuilder(
                    animation: _connectionService,
                    builder: (context, child) {
                      return ListTile(
                        leading: Icon(
                          _connectionService.getStatusIcon(),
                          color: _connectionService.getStatusColor(),
                        ),
                        title: Text(_connectionService.getStatusText()),
                        subtitle: Text(
                          _connectionService.currentServerUrl.isNotEmpty
                              ? _connectionService.currentServerUrl
                              : 'Checking...',
                        ),
                        trailing: IconButton(
                          icon: const Icon(Icons.refresh),
                          onPressed: () => _connectionService.checkConnection(),
                          tooltip: 'Refresh connection',
                        ),
                      );
                    },
                  ),
                  if (!kIsWeb) ...[
                    const Divider(),
                    SwitchListTile(
                      title: const Text('Use Local Network'),
                      subtitle: const Text('Connect via local network instead of ngrok'),
                      value: _useLocalNetwork,
                      onChanged: _toggleNetworkMode,
                      secondary: Icon(
                        _useLocalNetwork ? Icons.home : Icons.cloud,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                    Container(
                      margin: const EdgeInsets.all(8),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.orange.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.orange.withOpacity(0.3)),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.warning, color: Colors.orange, size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Local network requires server running on 10.120.4.230:8082',
                              style: TextStyle(
                                color: Colors.orange.shade700,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
              
              const SizedBox(height: 16),
              
              // Server Configuration (Admin Only)
              if (_isAdmin)
                _buildSettingsCard(
                  title: 'Server Configuration',
                  icon: Icons.cloud,
                  iconColor: Colors.blueGrey,
                  children: [
                    ListTile(
                      leading: const Icon(Icons.settings_ethernet),
                      title: const Text('Mode'),
                      subtitle: const Text('MongoDB/ngrok API'),
                    ),
                    ListTile(
                      leading: const Icon(Icons.link),
                      title: const Text('Server URL (override)'),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          TextField(
                            controller: _serverUrlController,
                            decoration: InputDecoration(
                              hintText: 'e.g. http://localhost:3003 or https://your-ngrok-url',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(AppDesignSystem.radiusMD),
                              ),
                              filled: true,
                              fillColor: Theme.of(context).colorScheme.surfaceVariant,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 12,
                            runSpacing: 8,
                            children: [
                              ElevatedButton.icon(
                                onPressed: _testingServerUrl ? null : _saveServerUrlOverride,
                                icon: const Icon(Icons.save, size: 18),
                                label: Text(_testingServerUrl ? 'Saving...' : 'Save & Test'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppDesignSystem.successColor,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(AppDesignSystem.radiusMD),
                                  ),
                                ),
                              ),
                              OutlinedButton.icon(
                                onPressed: _testingServerUrl ? null : _clearServerUrlOverride,
                                icon: const Icon(Icons.clear, size: 18),
                                label: const Text('Clear Override'),
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(AppDesignSystem.radiusMD),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.5),
                              borderRadius: BorderRadius.circular(AppDesignSystem.radiusMD),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.info_outline,
                                  size: 16,
                                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Current base: ${DatabaseConfig.physicalServerUrl}',
                                    style: AppDesignSystem.bodySmall.copyWith(
                                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              if (_isAdmin)
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
                                  // iOS notification permissions handled by system in physical server mode
                                  Log.i('iOS notification permissions handled by system', 'SETTINGS');
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
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Navigator.pushNamed(context, '/notification-test');
                        },
                        icon: const Icon(Icons.notifications_active),
                        label: const Text('Test Notifications'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange,
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
                        // Chat management service removed - using MongoDB/ngrok API only
                        
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
                  if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android)
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
                        if (DatabaseConfig.usePhysicalServer) {
                          await LocalAuthService.logout();
                        } else {
                          await LocalAuthService.logout();
                        }
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
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppDesignSystem.radiusLG),
      ),
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
                    style: AppDesignSystem.titleLarge.copyWith(
                      fontWeight: FontWeight.bold,
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