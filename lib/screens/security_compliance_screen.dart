// =============================================================================
// SECURITY & COMPLIANCE SCREEN
// =============================================================================
// Comprehensive security settings and compliance tools
// Features: IP management, security settings, GDPR tools, data retention

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'dart:convert';
import '../services/mongodb_admin_service.dart';
import '../services/theme_service.dart';
import '../utils/responsive_utils.dart';
import '../services/logger_service.dart';

class SecurityComplianceScreen extends StatefulWidget {
  const SecurityComplianceScreen({Key? key}) : super(key: key);

  @override
  State<SecurityComplianceScreen> createState() => _SecurityComplianceScreenState();
}

class _SecurityComplianceScreenState extends State<SecurityComplianceScreen> with SingleTickerProviderStateMixin {
  final MongoDBAdminService _adminService = MongoDBAdminService();
  late TabController _tabController;
  late ThemeService _themeService;

  // Security settings
  Map<String, dynamic>? _securitySettings;
  bool _isLoadingSettings = false;
  final TextEditingController _sessionTimeoutController = TextEditingController();
  final TextEditingController _ipWhitelistController = TextEditingController();
  final TextEditingController _ipBlacklistController = TextEditingController();
  final TextEditingController _ipDescriptionController = TextEditingController();
  final TextEditingController _ipReasonController = TextEditingController();
  final TextEditingController _minPasswordLengthController = TextEditingController();
  final TextEditingController _maxLoginAttemptsController = TextEditingController();
  final TextEditingController _lockoutDurationController = TextEditingController();
  final TextEditingController _suspiciousThresholdController = TextEditingController();

  // Failed logins and suspicious activity
  List<Map<String, dynamic>> _failedLogins = [];
  List<Map<String, dynamic>> _suspiciousActivity = [];
  bool _isLoadingFailedLogins = false;
  bool _isLoadingSuspiciousActivity = false;

  // Compliance
  Map<String, dynamic>? _dataRetention;
  bool _isLoadingDataRetention = false;
  final TextEditingController _userDataDaysController = TextEditingController();
  final TextEditingController _messageDataDaysController = TextEditingController();
  final TextEditingController _logDataDaysController = TextEditingController();
  final TextEditingController _gdprUserIdController = TextEditingController();
  final TextEditingController _gdprDeleteReasonController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _themeService = ThemeService.instance;
    _themeService.addListener(() {
      if (mounted) setState(() {});
    });
    
    _tabController = TabController(length: 4, vsync: this);
    _loadSecuritySettings();
    _loadFailedLogins();
    _loadSuspiciousActivity();
    _loadDataRetention();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _sessionTimeoutController.dispose();
    _ipWhitelistController.dispose();
    _ipBlacklistController.dispose();
    _ipDescriptionController.dispose();
    _ipReasonController.dispose();
    _minPasswordLengthController.dispose();
    _maxLoginAttemptsController.dispose();
    _lockoutDurationController.dispose();
    _suspiciousThresholdController.dispose();
    _userDataDaysController.dispose();
    _messageDataDaysController.dispose();
    _logDataDaysController.dispose();
    _gdprUserIdController.dispose();
    _gdprDeleteReasonController.dispose();
    super.dispose();
  }

  Future<void> _loadSecuritySettings() async {
    setState(() => _isLoadingSettings = true);
    try {
      final settings = await _adminService.getSecuritySettings();
      setState(() {
        _securitySettings = settings;
        _sessionTimeoutController.text = ((settings['sessionTimeout'] ?? 86400000) / (60 * 60 * 1000)).toStringAsFixed(0);
        _minPasswordLengthController.text = (settings['passwordPolicy']?['minLength'] ?? 8).toString();
        _maxLoginAttemptsController.text = (settings['failedLoginAttempts']?['maxAttempts'] ?? 5).toString();
        _lockoutDurationController.text = ((settings['failedLoginAttempts']?['lockoutDuration'] ?? 1800000) / (60 * 1000)).toStringAsFixed(0);
        _suspiciousThresholdController.text = (settings['suspiciousActivityAlerts']?['threshold'] ?? 10).toString();
        _isLoadingSettings = false;
      });
    } catch (e) {
      Log.e('Error loading security settings', 'SECURITY_COMPLIANCE', e);
      setState(() => _isLoadingSettings = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load security settings: $e')),
        );
      }
    }
  }

  Future<void> _loadFailedLogins() async {
    setState(() => _isLoadingFailedLogins = true);
    try {
      final data = await _adminService.getFailedLoginAttempts();
      setState(() {
        _failedLogins = List<Map<String, dynamic>>.from(data['failedLogins'] ?? []);
        _isLoadingFailedLogins = false;
      });
    } catch (e) {
      Log.e('Error loading failed logins', 'SECURITY_COMPLIANCE', e);
      setState(() => _isLoadingFailedLogins = false);
    }
  }

  Future<void> _loadSuspiciousActivity() async {
    setState(() => _isLoadingSuspiciousActivity = true);
    try {
      final data = await _adminService.getSuspiciousActivity();
      setState(() {
        _suspiciousActivity = List<Map<String, dynamic>>.from(data['activities'] ?? []);
        _isLoadingSuspiciousActivity = false;
      });
    } catch (e) {
      Log.e('Error loading suspicious activity', 'SECURITY_COMPLIANCE', e);
      setState(() => _isLoadingSuspiciousActivity = false);
    }
  }

  Future<void> _loadDataRetention() async {
    setState(() => _isLoadingDataRetention = true);
    try {
      final policies = await _adminService.getDataRetentionPolicies();
      setState(() {
        _dataRetention = policies;
        _userDataDaysController.text = (policies['userDataDays'] ?? 365).toString();
        _messageDataDaysController.text = (policies['messageDataDays'] ?? 90).toString();
        _logDataDaysController.text = (policies['logDataDays'] ?? 30).toString();
        _isLoadingDataRetention = false;
      });
    } catch (e) {
      Log.e('Error loading data retention', 'SECURITY_COMPLIANCE', e);
      setState(() => _isLoadingDataRetention = false);
    }
  }

  Future<void> _saveSecuritySettings() async {
    try {
      final updates = {
        'sessionTimeout': (double.parse(_sessionTimeoutController.text) * 60 * 60 * 1000).toInt(),
        'passwordPolicy': {
          'minLength': int.parse(_minPasswordLengthController.text),
          'requireUppercase': _securitySettings?['passwordPolicy']?['requireUppercase'] ?? true,
          'requireLowercase': _securitySettings?['passwordPolicy']?['requireLowercase'] ?? true,
          'requireNumbers': _securitySettings?['passwordPolicy']?['requireNumbers'] ?? true,
          'requireSpecialChars': _securitySettings?['passwordPolicy']?['requireSpecialChars'] ?? false,
        },
        'failedLoginAttempts': {
          'maxAttempts': int.parse(_maxLoginAttemptsController.text),
          'lockoutDuration': (double.parse(_lockoutDurationController.text) * 60 * 1000).toInt(),
        },
        'suspiciousActivityAlerts': {
          'enabled': _securitySettings?['suspiciousActivityAlerts']?['enabled'] ?? true,
          'threshold': int.parse(_suspiciousThresholdController.text),
        },
      };
      
      await _adminService.updateSecuritySettings(updates);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Security settings saved successfully')),
        );
      }
      _loadSecuritySettings();
    } catch (e) {
      Log.e('Error saving security settings', 'SECURITY_COMPLIANCE', e);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save settings: $e')),
        );
      }
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
        title: const Text('Security & Compliance'),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: !isTablet && !isMobile,
          tabs: const [
            Tab(icon: Icon(Icons.security), text: 'Security'),
            Tab(icon: Icon(Icons.block), text: 'IP Management'),
            Tab(icon: Icon(Icons.warning), text: 'Activity'),
            Tab(icon: Icon(Icons.gavel), text: 'Compliance'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildSecurityTab(context, isMobile, isTablet, padding, fontSize),
          _buildIpManagementTab(context, isMobile, isTablet, padding, fontSize),
          _buildActivityTab(context, isMobile, isTablet, padding, fontSize),
          _buildComplianceTab(context, isMobile, isTablet, padding, fontSize),
        ],
      ),
    );
  }

  Widget _buildSecurityTab(BuildContext context, bool isMobile, bool isTablet, EdgeInsets padding, double fontSize) {
    if (_isLoadingSettings) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_securitySettings == null) {
      return Center(
        child: Text('Failed to load security settings', style: TextStyle(fontSize: fontSize)),
      );
    }

    return SingleChildScrollView(
      padding: padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Session Timeout
          Card(
            child: Padding(
              padding: padding,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('Session Timeout', style: TextStyle(fontSize: fontSize * 1.2, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _sessionTimeoutController,
                    decoration: const InputDecoration(
                      labelText: 'Timeout (hours)',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                  ),
                ],
              ),
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Password Policy
          Card(
            child: Padding(
              padding: padding,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('Password Policy', style: TextStyle(fontSize: fontSize * 1.2, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _minPasswordLengthController,
                    decoration: const InputDecoration(
                      labelText: 'Minimum Length',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 8),
                  CheckboxListTile(
                    title: const Text('Require Uppercase'),
                    value: _securitySettings?['passwordPolicy']?['requireUppercase'] ?? true,
                    onChanged: (value) {
                      setState(() {
                        _securitySettings?['passwordPolicy']?['requireUppercase'] = value;
                      });
                    },
                  ),
                  CheckboxListTile(
                    title: const Text('Require Lowercase'),
                    value: _securitySettings?['passwordPolicy']?['requireLowercase'] ?? true,
                    onChanged: (value) {
                      setState(() {
                        _securitySettings?['passwordPolicy']?['requireLowercase'] = value;
                      });
                    },
                  ),
                  CheckboxListTile(
                    title: const Text('Require Numbers'),
                    value: _securitySettings?['passwordPolicy']?['requireNumbers'] ?? true,
                    onChanged: (value) {
                      setState(() {
                        _securitySettings?['passwordPolicy']?['requireNumbers'] = value;
                      });
                    },
                  ),
                  CheckboxListTile(
                    title: const Text('Require Special Characters'),
                    value: _securitySettings?['passwordPolicy']?['requireSpecialChars'] ?? false,
                    onChanged: (value) {
                      setState(() {
                        _securitySettings?['passwordPolicy']?['requireSpecialChars'] = value;
                      });
                    },
                  ),
                ],
              ),
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Failed Login Attempts
          Card(
            child: Padding(
              padding: padding,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('Failed Login Attempts', style: TextStyle(fontSize: fontSize * 1.2, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _maxLoginAttemptsController,
                    decoration: const InputDecoration(
                      labelText: 'Max Attempts',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _lockoutDurationController,
                    decoration: const InputDecoration(
                      labelText: 'Lockout Duration (minutes)',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                  ),
                ],
              ),
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Suspicious Activity Alerts
          Card(
            child: Padding(
              padding: padding,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('Suspicious Activity Alerts', style: TextStyle(fontSize: fontSize * 1.2, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  CheckboxListTile(
                    title: const Text('Enable Alerts'),
                    value: _securitySettings?['suspiciousActivityAlerts']?['enabled'] ?? true,
                    onChanged: (value) {
                      setState(() {
                        _securitySettings?['suspiciousActivityAlerts']?['enabled'] = value;
                      });
                    },
                  ),
                  TextField(
                    controller: _suspiciousThresholdController,
                    decoration: const InputDecoration(
                      labelText: 'Alert Threshold',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                  ),
                ],
              ),
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Save Button
          ElevatedButton.icon(
            onPressed: _saveSecuritySettings,
            icon: const Icon(Icons.save),
            label: const Text('Save Security Settings'),
            style: ElevatedButton.styleFrom(
              padding: EdgeInsets.all(padding.left),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIpManagementTab(BuildContext context, bool isMobile, bool isTablet, EdgeInsets padding, double fontSize) {
    final whitelist = List<Map<String, dynamic>>.from(_securitySettings?['ipWhitelist'] ?? []);
    final blacklist = List<Map<String, dynamic>>.from(_securitySettings?['ipBlacklist'] ?? []);

    return SingleChildScrollView(
      padding: padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Add to Whitelist
          Card(
            child: Padding(
              padding: padding,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('Add to Whitelist', style: TextStyle(fontSize: fontSize * 1.2, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _ipWhitelistController,
                    decoration: const InputDecoration(
                      labelText: 'IP Address',
                      hintText: '192.168.1.1',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _ipDescriptionController,
                    decoration: const InputDecoration(
                      labelText: 'Description (optional)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 8),
                  ElevatedButton(
                    onPressed: () async {
                      if (_ipWhitelistController.text.isEmpty) return;
                      try {
                        await _adminService.addIpToWhitelist(
                          _ipWhitelistController.text,
                          description: _ipDescriptionController.text.isEmpty ? null : _ipDescriptionController.text,
                        );
                        _ipWhitelistController.clear();
                        _ipDescriptionController.clear();
                        _loadSecuritySettings();
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('IP added to whitelist')),
                          );
                        }
                      } catch (e) {
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Error: $e')),
                          );
                        }
                      }
                    },
                    child: const Text('Add to Whitelist'),
                  ),
                ],
              ),
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Whitelist
          Card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: padding,
                  child: Text('Whitelist (${whitelist.length})', style: TextStyle(fontSize: fontSize * 1.2, fontWeight: FontWeight.bold)),
                ),
                const Divider(),
                if (whitelist.isEmpty)
                  Padding(
                    padding: padding,
                    child: Text('No IPs in whitelist', style: TextStyle(fontSize: fontSize, color: Colors.grey)),
                  )
                else
                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: whitelist.length,
                    itemBuilder: (context, index) {
                      final entry = whitelist[index];
                      return ListTile(
                        title: Text(entry['ip'] ?? ''),
                        subtitle: Text(entry['description'] ?? ''),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete),
                          onPressed: () async {
                            try {
                              await _adminService.removeIpFromWhitelist(entry['ip']);
                              _loadSecuritySettings();
                            } catch (e) {
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('Error: $e')),
                                );
                              }
                            }
                          },
                        ),
                      );
                    },
                  ),
              ],
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Add to Blacklist
          Card(
            child: Padding(
              padding: padding,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('Add to Blacklist', style: TextStyle(fontSize: fontSize * 1.2, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _ipBlacklistController,
                    decoration: const InputDecoration(
                      labelText: 'IP Address',
                      hintText: '192.168.1.1',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _ipReasonController,
                    decoration: const InputDecoration(
                      labelText: 'Reason (optional)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 8),
                  ElevatedButton(
                    onPressed: () async {
                      if (_ipBlacklistController.text.isEmpty) return;
                      try {
                        await _adminService.addIpToBlacklist(
                          _ipBlacklistController.text,
                          reason: _ipReasonController.text.isEmpty ? null : _ipReasonController.text,
                        );
                        _ipBlacklistController.clear();
                        _ipReasonController.clear();
                        _loadSecuritySettings();
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('IP added to blacklist')),
                          );
                        }
                      } catch (e) {
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Error: $e')),
                          );
                        }
                      }
                    },
                    child: const Text('Add to Blacklist'),
                  ),
                ],
              ),
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Blacklist
          Card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: padding,
                  child: Text('Blacklist (${blacklist.length})', style: TextStyle(fontSize: fontSize * 1.2, fontWeight: FontWeight.bold)),
                ),
                const Divider(),
                if (blacklist.isEmpty)
                  Padding(
                    padding: padding,
                    child: Text('No IPs in blacklist', style: TextStyle(fontSize: fontSize, color: Colors.grey)),
                  )
                else
                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: blacklist.length,
                    itemBuilder: (context, index) {
                      final entry = blacklist[index];
                      return ListTile(
                        title: Text(entry['ip'] ?? ''),
                        subtitle: Text(entry['reason'] ?? ''),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete),
                          onPressed: () async {
                            try {
                              await _adminService.removeIpFromBlacklist(entry['ip']);
                              _loadSecuritySettings();
                            } catch (e) {
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('Error: $e')),
                                );
                              }
                            }
                          },
                        ),
                      );
                    },
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActivityTab(BuildContext context, bool isMobile, bool isTablet, EdgeInsets padding, double fontSize) {
    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          const TabBar(
            tabs: [
              Tab(text: 'Failed Logins'),
              Tab(text: 'Suspicious Activity'),
            ],
          ),
          Expanded(
            child: TabBarView(
              children: [
                _buildFailedLoginsList(context, isMobile, isTablet, padding, fontSize),
                _buildSuspiciousActivityList(context, isMobile, isTablet, padding, fontSize),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFailedLoginsList(BuildContext context, bool isMobile, bool isTablet, EdgeInsets padding, double fontSize) {
    if (_isLoadingFailedLogins) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_failedLogins.isEmpty) {
      return Center(
        child: Text('No failed login attempts', style: TextStyle(fontSize: fontSize, color: Colors.grey)),
      );
    }

    return ListView.builder(
      padding: padding,
      itemCount: _failedLogins.length,
      itemBuilder: (context, index) {
        final attempt = _failedLogins[index];
        return Card(
          child: ListTile(
            leading: const Icon(Icons.block, color: Colors.red),
            title: Text(attempt['ip'] ?? 'Unknown IP'),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(attempt['email'] ?? 'Unknown email'),
                Text(DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.parse(attempt['timestamp'] ?? DateTime.now().toIso8601String()))),
                Text(attempt['reason'] ?? ''),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSuspiciousActivityList(BuildContext context, bool isMobile, bool isTablet, EdgeInsets padding, double fontSize) {
    if (_isLoadingSuspiciousActivity) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_suspiciousActivity.isEmpty) {
      return Center(
        child: Text('No suspicious activity', style: TextStyle(fontSize: fontSize, color: Colors.grey)),
      );
    }

    return ListView.builder(
      padding: padding,
      itemCount: _suspiciousActivity.length,
      itemBuilder: (context, index) {
        final activity = _suspiciousActivity[index];
        final severity = activity['severity'] ?? 'medium';
        Color severityColor = Colors.orange;
        if (severity == 'high') severityColor = Colors.red;
        if (severity == 'low') severityColor = Colors.yellow;
        
        return Card(
          child: ListTile(
            leading: Icon(Icons.warning, color: severityColor),
            title: Text(activity['type'] ?? 'Unknown'),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(activity['description'] ?? ''),
                Text('IP: ${activity['ip'] ?? 'Unknown'}'),
                Text(DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.parse(activity['timestamp'] ?? DateTime.now().toIso8601String()))),
              ],
            ),
            trailing: Chip(
              label: Text(severity.toUpperCase()),
              backgroundColor: severityColor.withOpacity(0.2),
            ),
          ),
        );
      },
    );
  }

  Widget _buildComplianceTab(BuildContext context, bool isMobile, bool isTablet, EdgeInsets padding, double fontSize) {
    if (_isLoadingDataRetention) {
      return const Center(child: CircularProgressIndicator());
    }

    return SingleChildScrollView(
      padding: padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Data Retention Policies
          Card(
            child: Padding(
              padding: padding,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('Data Retention Policies', style: TextStyle(fontSize: fontSize * 1.2, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  CheckboxListTile(
                    title: const Text('Enable Data Retention'),
                    value: _dataRetention?['enabled'] ?? false,
                    onChanged: (value) {
                      setState(() {
                        _dataRetention?['enabled'] = value;
                      });
                    },
                  ),
                  TextField(
                    controller: _userDataDaysController,
                    decoration: const InputDecoration(
                      labelText: 'User Data Retention (days)',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _messageDataDaysController,
                    decoration: const InputDecoration(
                      labelText: 'Message Data Retention (days)',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _logDataDaysController,
                    decoration: const InputDecoration(
                      labelText: 'Log Data Retention (days)',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () async {
                      try {
                        await _adminService.updateDataRetentionPolicies(
                          enabled: _dataRetention?['enabled'] ?? false,
                          userDataDays: int.parse(_userDataDaysController.text),
                          messageDataDays: int.parse(_messageDataDaysController.text),
                          logDataDays: int.parse(_logDataDaysController.text),
                        );
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Data retention policies updated')),
                          );
                        }
                        _loadDataRetention();
                      } catch (e) {
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Error: $e')),
                          );
                        }
                      }
                    },
                    child: const Text('Save Policies'),
                  ),
                ],
              ),
            ),
          ),
          
          const SizedBox(height: 16),
          
          // GDPR Export
          Card(
            child: Padding(
              padding: padding,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('GDPR Data Export', style: TextStyle(fontSize: fontSize * 1.2, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _gdprUserIdController,
                    decoration: const InputDecoration(
                      labelText: 'User ID',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 8),
                  ElevatedButton.icon(
                    onPressed: () async {
                      if (_gdprUserIdController.text.isEmpty) return;
                      try {
                        final data = await _adminService.exportGdprData(_gdprUserIdController.text);
                        // Show data in dialog or download
                        if (mounted) {
                          showDialog(
                            context: context,
                            builder: (context) => AlertDialog(
                              title: const Text('GDPR Data Export'),
                              content: SingleChildScrollView(
                                child: Text(JsonEncoder.withIndent('  ').convert(data)),
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(context),
                                  child: const Text('Close'),
                                ),
                              ],
                            ),
                          );
                        }
                      } catch (e) {
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Error: $e')),
                          );
                        }
                      }
                    },
                    icon: const Icon(Icons.download),
                    label: const Text('Export User Data'),
                  ),
                ],
              ),
            ),
          ),
          
          const SizedBox(height: 16),
          
          // GDPR Delete
          Card(
            child: Padding(
              padding: padding,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('GDPR Data Deletion', style: TextStyle(fontSize: fontSize * 1.2, fontWeight: FontWeight.bold, color: Colors.red)),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _gdprUserIdController,
                    decoration: const InputDecoration(
                      labelText: 'User ID',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _gdprDeleteReasonController,
                    decoration: const InputDecoration(
                      labelText: 'Reason (required)',
                      border: OutlineInputBorder(),
                    ),
                    maxLines: 3,
                  ),
                  const SizedBox(height: 8),
                  ElevatedButton.icon(
                    onPressed: () async {
                      if (_gdprUserIdController.text.isEmpty || _gdprDeleteReasonController.text.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('User ID and reason are required')),
                        );
                        return;
                      }
                      
                      final confirmed = await showDialog<bool>(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: const Text('Confirm Deletion'),
                          content: const Text('This will permanently delete all user data. This action cannot be undone. Are you sure?'),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context, false),
                              child: const Text('Cancel'),
                            ),
                            TextButton(
                              onPressed: () => Navigator.pop(context, true),
                              style: TextButton.styleFrom(foregroundColor: Colors.red),
                              child: const Text('Delete'),
                            ),
                          ],
                        ),
                      );
                      
                      if (confirmed == true) {
                        try {
                          await _adminService.deleteGdprData(_gdprUserIdController.text, _gdprDeleteReasonController.text);
                          _gdprUserIdController.clear();
                          _gdprDeleteReasonController.clear();
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('User data deleted successfully')),
                            );
                          }
                        } catch (e) {
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Error: $e')),
                            );
                          }
                        }
                      }
                    },
                    icon: const Icon(Icons.delete_forever),
                    label: const Text('Delete User Data'),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

