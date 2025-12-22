// =============================================================================
// SYSTEM CONFIGURATION SCREEN
// =============================================================================
// Comprehensive system configuration management
// Features: Maintenance mode, system settings, environment variables

import 'package:flutter/material.dart';
import 'dart:async';
import '../services/mongodb_admin_service.dart';
import '../services/theme_service.dart';
import '../utils/responsive_utils.dart';
import '../services/logger_service.dart';

class SystemConfigurationScreen extends StatefulWidget {
  const SystemConfigurationScreen({Key? key}) : super(key: key);

  @override
  State<SystemConfigurationScreen> createState() => _SystemConfigurationScreenState();
}

class _SystemConfigurationScreenState extends State<SystemConfigurationScreen> {
  final MongoDBAdminService _adminService = MongoDBAdminService();
  late ThemeService _themeService;

  Map<String, dynamic>? _config;
  bool _isLoadingConfig = false;
  bool _maintenanceMode = false;

  @override
  void initState() {
    super.initState();
    _themeService = ThemeService.instance;
    _themeService.addListener(() {
      if (mounted) setState(() {});
    });
    _loadConfig();
  }

  Future<void> _loadConfig() async {
    setState(() => _isLoadingConfig = true);
    try {
      final config = await _adminService.getSystemConfig();
      setState(() {
        _config = config;
        _maintenanceMode = config['maintenanceMode'] ?? false;
        _isLoadingConfig = false;
      });
    } catch (e) {
      Log.e('Error loading system config', 'SYSTEM_CONFIG', e);
      setState(() => _isLoadingConfig = false);
    }
  }

  Future<void> _updateConfig() async {
    try {
      await _adminService.updateSystemConfig(maintenanceMode: _maintenanceMode);
      _loadConfig();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('System configuration updated')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update config: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = ResponsiveUtils.isMobile(context);
    final isTablet = ResponsiveUtils.isTablet(context);
    final padding = ResponsiveUtils.getResponsivePadding(context);
    final fontSize = ResponsiveUtils.getResponsiveFontSize(context, baseSize: 16.0);

    return Scaffold(
      appBar: AppBar(
        title: const Text('System Configuration'),
      ),
      body: _isLoadingConfig
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: padding,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('System Settings', style: TextStyle(fontSize: fontSize * 1.2, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  Card(
                    child: SwitchListTile(
                      title: Text('Maintenance Mode', style: TextStyle(fontSize: fontSize)),
                      subtitle: Text(
                        _maintenanceMode
                            ? 'System is in maintenance mode. Users cannot access the app.'
                            : 'System is operational.',
                        style: TextStyle(fontSize: fontSize * 0.9),
                      ),
                      value: _maintenanceMode,
                      onChanged: (value) {
                        setState(() => _maintenanceMode = value);
                        _updateConfig();
                      },
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text('Configuration Details', style: TextStyle(fontSize: fontSize * 1.2, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  if (_config != null)
                    Card(
                      child: Padding(
                        padding: padding,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Maintenance Mode: ${_maintenanceMode ? 'Enabled' : 'Disabled'}', style: TextStyle(fontSize: fontSize)),
                            const SizedBox(height: 8),
                            Text('Settings: ${(_config?['settings'] ?? {}).toString()}', style: TextStyle(fontSize: fontSize)),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
    );
  }
}

