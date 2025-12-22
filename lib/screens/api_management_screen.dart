// =============================================================================
// API MANAGEMENT SCREEN
// =============================================================================
// Comprehensive API key management with rate limiting, usage analytics, and endpoint monitoring
// Features: API key CRUD, rate limit configuration, usage analytics, endpoint monitoring

import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'dart:async';
import '../services/mongodb_admin_service.dart';
import '../services/theme_service.dart';
import '../utils/responsive_utils.dart';
import '../services/logger_service.dart';

class ApiManagementScreen extends StatefulWidget {
  const ApiManagementScreen({Key? key}) : super(key: key);

  @override
  State<ApiManagementScreen> createState() => _ApiManagementScreenState();
}

class _ApiManagementScreenState extends State<ApiManagementScreen> with SingleTickerProviderStateMixin {
  final MongoDBAdminService _adminService = MongoDBAdminService();
  late TabController _tabController;
  late ThemeService _themeService;

  // API Keys
  List<Map<String, dynamic>> _keys = [];
  bool _isLoadingKeys = false;

  // Create/Edit key
  final TextEditingController _keyNameController = TextEditingController();
  List<String> _selectedPermissions = ['read'];
  int _rateLimitRequests = 100;
  int _rateLimitWindow = 60;
  String? _editingKeyId;
  String? _newApiKey; // Store newly created key to show once

  // Usage Analytics
  Map<String, dynamic>? _usageAnalytics;
  bool _isLoadingUsage = false;
  String _usagePeriod = '24h';
  String? _selectedKeyId;

  // Endpoint Monitoring
  Map<String, dynamic>? _endpointMonitoring;
  bool _isLoadingEndpoints = false;
  String _endpointPeriod = '24h';

  @override
  void initState() {
    super.initState();
    _themeService = ThemeService.instance;
    _themeService.addListener(() {
      if (mounted) setState(() {});
    });
    
    _tabController = TabController(length: 3, vsync: this);
    _loadKeys();
    _loadUsageAnalytics();
    _loadEndpointMonitoring();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _keyNameController.dispose();
    super.dispose();
  }

  Future<void> _loadKeys() async {
    setState(() => _isLoadingKeys = true);
    try {
      final keys = await _adminService.getApiKeys();
      setState(() {
        _keys = keys;
        _isLoadingKeys = false;
      });
    } catch (e) {
      Log.e('Error loading API keys', 'API_MANAGEMENT', e);
      setState(() => _isLoadingKeys = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load API keys: $e')),
        );
      }
    }
  }

  Future<void> _loadUsageAnalytics() async {
    setState(() => _isLoadingUsage = true);
    try {
      final analytics = await _adminService.getApiUsageAnalytics(
        period: _usagePeriod,
        keyId: _selectedKeyId,
      );
      setState(() {
        _usageAnalytics = analytics;
        _isLoadingUsage = false;
      });
    } catch (e) {
      Log.e('Error loading usage analytics', 'API_MANAGEMENT', e);
      setState(() => _isLoadingUsage = false);
    }
  }

  Future<void> _loadEndpointMonitoring() async {
    setState(() => _isLoadingEndpoints = true);
    try {
      final monitoring = await _adminService.getEndpointMonitoring(period: _endpointPeriod);
      setState(() {
        _endpointMonitoring = monitoring;
        _isLoadingEndpoints = false;
      });
    } catch (e) {
      Log.e('Error loading endpoint monitoring', 'API_MANAGEMENT', e);
      setState(() => _isLoadingEndpoints = false);
    }
  }

  Future<void> _saveKey() async {
    if (_keyNameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Key name is required')),
      );
      return;
    }

    try {
      if (_editingKeyId != null) {
        await _adminService.updateApiKey(
          _editingKeyId!,
          name: _keyNameController.text.trim(),
          permissions: _selectedPermissions,
          rateLimit: {
            'requests': _rateLimitRequests,
            'window': _rateLimitWindow,
          },
        );
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('API key updated')),
        );
      } else {
        final result = await _adminService.createApiKey(
          name: _keyNameController.text.trim(),
          permissions: _selectedPermissions,
          rateLimit: {
            'requests': _rateLimitRequests,
            'window': _rateLimitWindow,
          },
        );
        setState(() {
          _newApiKey = result['key'];
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('API key created - Copy it now!')),
        );
      }
      _resetForm();
      _loadKeys();
      Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save key: $e')),
        );
      }
    }
  }

  void _resetForm() {
    _keyNameController.clear();
    _selectedPermissions = ['read'];
    _rateLimitRequests = 100;
    _rateLimitWindow = 60;
    _editingKeyId = null;
    _newApiKey = null;
  }

  void _editKey(Map<String, dynamic> key) {
    setState(() {
      _editingKeyId = key['id'];
      _keyNameController.text = key['name'] ?? '';
      _selectedPermissions = List<String>.from(key['permissions'] ?? ['read']);
      final rateLimit = key['rateLimit'] ?? {};
      _rateLimitRequests = rateLimit['requests'] ?? 100;
      _rateLimitWindow = rateLimit['window'] ?? 60;
    });
    _showKeyDialog();
  }

  Future<void> _deleteKey(String keyId, String keyName) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete API Key'),
        content: Text('Are you sure you want to delete "$keyName"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _adminService.deleteApiKey(keyId);
        _loadKeys();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('API key deleted')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to delete key: $e')),
          );
        }
      }
    }
  }

  void _showKeyDialog() {
    showDialog(
      context: context,
      builder: (context) => _buildKeyDialog(),
    );
  }

  Widget _buildKeyDialog() {
    final isMobile = ResponsiveUtils.isMobile(context);
    final padding = ResponsiveUtils.getResponsivePadding(context);
    final availablePermissions = ['read', 'write', 'delete', 'admin', '*'];

    return Dialog(
      child: Container(
        width: isMobile ? double.infinity : 600,
        padding: padding,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _editingKeyId != null ? 'Edit API Key' : 'Create API Key',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _keyNameController,
                decoration: const InputDecoration(
                  labelText: 'Key Name',
                  hintText: 'e.g., Production API Key',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              const Text('Permissions:', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: availablePermissions.map((permission) {
                  return FilterChip(
                    label: Text(permission),
                    selected: _selectedPermissions.contains(permission),
                    onSelected: (selected) {
                      setState(() {
                        if (selected) {
                          _selectedPermissions.add(permission);
                        } else {
                          _selectedPermissions.remove(permission);
                        }
                      });
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),
              const Text('Rate Limit:', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text('Requests: $_rateLimitRequests'),
              Slider(
                value: _rateLimitRequests.toDouble(),
                min: 1,
                max: 10000,
                divisions: 100,
                label: '$_rateLimitRequests',
                onChanged: (value) => setState(() => _rateLimitRequests = value.round()),
              ),
              Text('Window: $_rateLimitWindow seconds'),
              Slider(
                value: _rateLimitWindow.toDouble(),
                min: 1,
                max: 3600,
                divisions: 100,
                label: '$_rateLimitWindow seconds',
                onChanged: (value) => setState(() => _rateLimitWindow = value.round()),
              ),
              if (_newApiKey != null) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.amber.withOpacity(0.2),
                    border: Border.all(color: Colors.amber),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('⚠️ Copy this API key now - it won\'t be shown again!', style: TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      SelectableText(_newApiKey!, style: const TextStyle(fontFamily: 'monospace')),
                      const SizedBox(height: 8),
                      ElevatedButton.icon(
                        icon: const Icon(Icons.copy),
                        label: const Text('Copy to Clipboard'),
                        onPressed: () {
                          // Copy to clipboard would require clipboard package
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('API key copied (implement clipboard)')),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () {
                      _resetForm();
                      Navigator.pop(context);
                    },
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: _saveKey,
                    child: const Text('Save'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = ResponsiveUtils.isMobile(context);
    final isTablet = ResponsiveUtils.isTablet(context);
    final padding = ResponsiveUtils.getResponsivePadding(context);
    final fontSize = ResponsiveUtils.getResponsiveFontSize(context, baseSize: 16.0);

    return Scaffold(
      appBar: AppBar(
        title: const Text('API Management'),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: !isTablet && !isMobile,
          tabs: const [
            Tab(icon: Icon(Icons.vpn_key), text: 'API Keys'),
            Tab(icon: Icon(Icons.analytics), text: 'Usage'),
            Tab(icon: Icon(Icons.monitor), text: 'Endpoints'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildKeysTab(context, isMobile, isTablet, padding, fontSize),
          _buildUsageTab(context, isMobile, isTablet, padding, fontSize),
          _buildEndpointsTab(context, isMobile, isTablet, padding, fontSize),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          _resetForm();
          _showKeyDialog();
        },
        child: const Icon(Icons.add),
        tooltip: 'Create API Key',
      ),
    );
  }

  Widget _buildKeysTab(BuildContext context, bool isMobile, bool isTablet, EdgeInsets padding, double fontSize) {
    if (_isLoadingKeys) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_keys.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.vpn_key_outlined, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            Text('No API keys', style: TextStyle(fontSize: fontSize, color: Colors.grey)),
            const SizedBox(height: 8),
            Text('Tap + to create a new API key', style: TextStyle(fontSize: fontSize * 0.9, color: Colors.grey)),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: padding,
      itemCount: _keys.length,
      itemBuilder: (context, index) {
        final key = _keys[index];
        final rateLimit = key['rateLimit'] ?? {};
        final permissions = List<String>.from(key['permissions'] ?? []);

        return Card(
          margin: EdgeInsets.only(bottom: padding.bottom),
          child: ListTile(
            leading: Icon(
              key['isActive'] == true ? Icons.vpn_key : Icons.vpn_key_outlined,
              color: key['isActive'] == true ? Colors.green : Colors.grey,
            ),
            title: Text(key['name'] ?? 'Unknown', style: TextStyle(fontSize: fontSize)),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Key: ${key['keyPrefix'] ?? 'N/A'}', style: TextStyle(fontSize: fontSize * 0.85, fontFamily: 'monospace')),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 4,
                  children: [
                    Chip(
                      label: Text(key['isActive'] == true ? 'Active' : 'Inactive', style: TextStyle(fontSize: fontSize * 0.8)),
                      backgroundColor: key['isActive'] == true ? Colors.green.withOpacity(0.2) : Colors.grey.withOpacity(0.2),
                    ),
                    ...permissions.map((perm) => Chip(
                      label: Text(perm, style: TextStyle(fontSize: fontSize * 0.8)),
                      backgroundColor: Colors.blue.withOpacity(0.2),
                    )),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'Rate Limit: ${rateLimit['requests'] ?? 100} requests per ${rateLimit['window'] ?? 60} seconds',
                  style: TextStyle(fontSize: fontSize * 0.85, color: Colors.grey),
                ),
                if (key['usageCount'] != null && key['usageCount'] > 0) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Usage: ${key['usageCount']} requests',
                    style: TextStyle(fontSize: fontSize * 0.85, color: Colors.grey),
                  ),
                ],
              ],
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.edit),
                  onPressed: () => _editKey(key),
                ),
                IconButton(
                  icon: const Icon(Icons.delete, color: Colors.red),
                  onPressed: () => _deleteKey(key['id'], key['name'] ?? 'Unknown'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildUsageTab(BuildContext context, bool isMobile, bool isTablet, EdgeInsets padding, double fontSize) {
    return Column(
      children: [
        Padding(
          padding: padding,
          child: Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: _selectedKeyId,
                  decoration: const InputDecoration(
                    labelText: 'Filter by API Key (Optional)',
                    border: OutlineInputBorder(),
                  ),
                  items: [
                    const DropdownMenuItem(value: null, child: Text('All Keys')),
                    ..._keys.map((key) {
                      return DropdownMenuItem(
                        value: key['id'],
                        child: Text(key['name'] ?? 'Unknown'),
                      );
                    }),
                  ],
                  onChanged: (value) {
                    setState(() => _selectedKeyId = value);
                    _loadUsageAnalytics();
                  },
                ),
              ),
              const SizedBox(width: 16),
              DropdownButtonFormField<String>(
                value: _usagePeriod,
                decoration: const InputDecoration(
                  labelText: 'Period',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(value: '1h', child: Text('1 Hour')),
                  DropdownMenuItem(value: '24h', child: Text('24 Hours')),
                  DropdownMenuItem(value: '7d', child: Text('7 Days')),
                  DropdownMenuItem(value: '30d', child: Text('30 Days')),
                ],
                onChanged: (value) {
                  if (value != null) {
                    setState(() => _usagePeriod = value);
                    _loadUsageAnalytics();
                  }
                },
              ),
            ],
          ),
        ),
        Expanded(
          child: _isLoadingUsage
              ? const Center(child: CircularProgressIndicator())
              : _usageAnalytics == null
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.analytics_outlined, size: 64, color: Colors.grey),
                          const SizedBox(height: 16),
                          Text('No usage data available', style: TextStyle(fontSize: fontSize, color: Colors.grey)),
                        ],
                      ),
                    )
                  : _buildUsageContent(context, isMobile, isTablet, padding, fontSize),
        ),
      ],
    );
  }

  Widget _buildUsageContent(BuildContext context, bool isMobile, bool isTablet, EdgeInsets padding, double fontSize) {
    if (_usageAnalytics == null) {
      return Center(
        child: Text('No usage data', style: TextStyle(fontSize: fontSize, color: Colors.grey)),
      );
    }
    
    final totalRequests = _usageAnalytics!['totalRequests'] ?? 0;
    final totalErrors = _usageAnalytics!['totalErrors'] ?? 0;
    final errorRate = _usageAnalytics!['errorRate'] ?? 0.0;
    final endpointStats = Map<String, dynamic>.from(_usageAnalytics!['endpointStats'] ?? {});

    return SingleChildScrollView(
      padding: padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Total Requests', style: TextStyle(fontSize: fontSize * 0.9, color: Colors.grey)),
                        const SizedBox(height: 8),
                        Text('$totalRequests', style: TextStyle(fontSize: fontSize * 1.5, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Error Rate', style: TextStyle(fontSize: fontSize * 0.9, color: Colors.grey)),
                        const SizedBox(height: 8),
                        Text('${errorRate.toStringAsFixed(1)}%', style: TextStyle(fontSize: fontSize * 1.5, fontWeight: FontWeight.bold, color: Colors.red)),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (endpointStats.isNotEmpty) ...[
            Text('Endpoint Statistics', style: TextStyle(fontSize: fontSize * 1.1, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            ...endpointStats.entries.map((entry) {
              final endpoint = entry.key;
              final stats = Map<String, dynamic>.from(entry.value);
              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  title: Text(endpoint, style: TextStyle(fontSize: fontSize)),
                  subtitle: Text(
                    'Requests: ${stats['requests'] ?? 0}, Errors: ${stats['errors'] ?? 0}, Avg Response: ${(stats['avgResponseTime'] ?? 0).toStringAsFixed(0)}ms',
                    style: TextStyle(fontSize: fontSize * 0.9),
                  ),
                ),
              );
            }),
          ],
        ],
      ),
    );
  }

  Widget _buildEndpointsTab(BuildContext context, bool isMobile, bool isTablet, EdgeInsets padding, double fontSize) {
    return Column(
      children: [
        Padding(
          padding: padding,
          child: DropdownButtonFormField<String>(
            value: _endpointPeriod,
            decoration: const InputDecoration(
              labelText: 'Period',
              border: OutlineInputBorder(),
            ),
            items: const [
              DropdownMenuItem(value: '1h', child: Text('1 Hour')),
              DropdownMenuItem(value: '24h', child: Text('24 Hours')),
              DropdownMenuItem(value: '7d', child: Text('7 Days')),
              DropdownMenuItem(value: '30d', child: Text('30 Days')),
            ],
            onChanged: (value) {
              if (value != null) {
                setState(() => _endpointPeriod = value);
                _loadEndpointMonitoring();
              }
            },
          ),
        ),
        Expanded(
          child: _isLoadingEndpoints
              ? const Center(child: CircularProgressIndicator())
              : _endpointMonitoring == null
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.monitor_outlined, size: 64, color: Colors.grey),
                          const SizedBox(height: 16),
                          Text('No endpoint data available', style: TextStyle(fontSize: fontSize, color: Colors.grey)),
                        ],
                      ),
                    )
                  : _buildEndpointsContent(context, isMobile, isTablet, padding, fontSize),
        ),
      ],
    );
  }

  Widget _buildEndpointsContent(BuildContext context, bool isMobile, bool isTablet, EdgeInsets padding, double fontSize) {
    if (_endpointMonitoring == null) {
      return Center(
        child: Text('No endpoint data', style: TextStyle(fontSize: fontSize, color: Colors.grey)),
      );
    }
    
    final endpoints = List<Map<String, dynamic>>.from(_endpointMonitoring!['endpoints'] ?? []);

    if (endpoints.isEmpty) {
      return Center(
        child: Text('No endpoints monitored', style: TextStyle(fontSize: fontSize, color: Colors.grey)),
      );
    }

    return ListView.builder(
      padding: padding,
      itemCount: endpoints.length,
      itemBuilder: (context, index) {
        final endpoint = endpoints[index];
        final errorRate = endpoint['errorRate'] ?? 0.0;

        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            leading: Icon(
              errorRate > 10 ? Icons.error : Icons.check_circle,
              color: errorRate > 10 ? Colors.red : Colors.green,
            ),
            title: Text('${endpoint['method']} ${endpoint['endpoint']}', style: TextStyle(fontSize: fontSize)),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Requests: ${endpoint['requests'] ?? 0}, Errors: ${endpoint['errors'] ?? 0}',
                  style: TextStyle(fontSize: fontSize * 0.9),
                ),
                Text(
                  'Avg Response: ${(endpoint['avgResponseTime'] ?? 0).toStringAsFixed(0)}ms, Error Rate: ${errorRate.toStringAsFixed(1)}%',
                  style: TextStyle(fontSize: fontSize * 0.85, color: Colors.grey),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

