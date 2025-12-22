// =============================================================================
// INTEGRATION MANAGEMENT SCREEN
// =============================================================================
// Comprehensive integration management with webhook configuration and health monitoring
// Features: Integration CRUD, webhook configuration, health checks, delivery tracking

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'dart:async';
import '../services/mongodb_admin_service.dart';
import '../services/theme_service.dart';
import '../utils/responsive_utils.dart';
import '../services/logger_service.dart';

class IntegrationManagementScreen extends StatefulWidget {
  const IntegrationManagementScreen({Key? key}) : super(key: key);

  @override
  State<IntegrationManagementScreen> createState() => _IntegrationManagementScreenState();
}

class _IntegrationManagementScreenState extends State<IntegrationManagementScreen> with SingleTickerProviderStateMixin {
  final MongoDBAdminService _adminService = MongoDBAdminService();
  late TabController _tabController;
  late ThemeService _themeService;

  // Integrations
  List<Map<String, dynamic>> _integrations = [];
  bool _isLoadingIntegrations = false;

  // Create/Edit integration
  final TextEditingController _integrationNameController = TextEditingController();
  String _selectedType = 'webhook';
  final TextEditingController _webhookUrlController = TextEditingController();
  String? _editingIntegrationId;

  // Webhook history
  List<Map<String, dynamic>> _webhookHistory = [];
  bool _isLoadingHistory = false;
  String? _selectedIntegrationId;

  @override
  void initState() {
    super.initState();
    _themeService = ThemeService.instance;
    _themeService.addListener(() {
      if (mounted) setState(() {});
    });
    
    _tabController = TabController(length: 2, vsync: this);
    _loadIntegrations();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _integrationNameController.dispose();
    _webhookUrlController.dispose();
    super.dispose();
  }

  Future<void> _loadIntegrations() async {
    setState(() => _isLoadingIntegrations = true);
    try {
      final integrations = await _adminService.getIntegrations();
      setState(() {
        _integrations = integrations;
        _isLoadingIntegrations = false;
      });
    } catch (e) {
      Log.e('Error loading integrations', 'INTEGRATION_MANAGEMENT', e);
      setState(() => _isLoadingIntegrations = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load integrations: $e')),
        );
      }
    }
  }

  Future<void> _loadWebhookHistory(String integrationId) async {
    setState(() {
      _isLoadingHistory = true;
      _selectedIntegrationId = integrationId;
    });
    try {
      final history = await _adminService.getWebhookHistory(integrationId);
      setState(() {
        _webhookHistory = history;
        _isLoadingHistory = false;
      });
    } catch (e) {
      Log.e('Error loading webhook history', 'INTEGRATION_MANAGEMENT', e);
      setState(() => _isLoadingHistory = false);
    }
  }

  Future<void> _saveIntegration() async {
    if (_integrationNameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Integration name is required')),
      );
      return;
    }

    try {
      List<Map<String, dynamic>> webhooks = [];
      if (_webhookUrlController.text.trim().isNotEmpty) {
        webhooks.add({
          'url': _webhookUrlController.text.trim(),
          'method': 'POST',
        });
      }

      if (_editingIntegrationId != null) {
        await _adminService.updateIntegration(
          _editingIntegrationId!,
          name: _integrationNameController.text.trim(),
          webhooks: webhooks,
        );
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Integration updated')),
        );
      } else {
        await _adminService.createIntegration(
          name: _integrationNameController.text.trim(),
          type: _selectedType,
          webhooks: webhooks,
        );
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Integration created')),
        );
      }
      _resetForm();
      _loadIntegrations();
      Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save integration: $e')),
        );
      }
    }
  }

  void _resetForm() {
    _integrationNameController.clear();
    _selectedType = 'webhook';
    _webhookUrlController.clear();
    _editingIntegrationId = null;
  }

  void _editIntegration(Map<String, dynamic> integration) {
    setState(() {
      _editingIntegrationId = integration['id'];
      _integrationNameController.text = integration['name'] ?? '';
      _selectedType = integration['type'] ?? 'webhook';
      final webhooks = List<Map<String, dynamic>>.from(integration['webhooks'] ?? []);
      if (webhooks.isNotEmpty) {
        _webhookUrlController.text = webhooks.first['url'] ?? '';
      }
    });
    _showIntegrationDialog();
  }

  Future<void> _deleteIntegration(String integrationId, String integrationName) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Integration'),
        content: Text('Are you sure you want to delete "$integrationName"?'),
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
        await _adminService.deleteIntegration(integrationId);
        _loadIntegrations();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Integration deleted')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to delete integration: $e')),
          );
        }
      }
    }
  }

  Future<void> _checkHealth(String integrationId) async {
    try {
      final health = await _adminService.checkIntegrationHealth(integrationId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Health: ${health['healthStatus']?['status'] ?? 'unknown'} - ${health['healthStatus']?['message'] ?? ''}'),
          ),
        );
      }
      _loadIntegrations();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to check health: $e')),
        );
      }
    }
  }

  void _showIntegrationDialog() {
    showDialog(
      context: context,
      builder: (context) => _buildIntegrationDialog(),
    );
  }

  Widget _buildIntegrationDialog() {
    final isMobile = ResponsiveUtils.isMobile(context);
    final padding = ResponsiveUtils.getResponsivePadding(context);
    final availableTypes = ['webhook', 'database', 'external_api'];

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
                _editingIntegrationId != null ? 'Edit Integration' : 'Create Integration',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _integrationNameController,
                decoration: const InputDecoration(
                  labelText: 'Integration Name',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _selectedType,
                decoration: const InputDecoration(
                  labelText: 'Integration Type',
                  border: OutlineInputBorder(),
                ),
                items: availableTypes.map((type) {
                  return DropdownMenuItem(
                    value: type,
                    child: Text(type),
                  );
                }).toList(),
                onChanged: (value) => setState(() => _selectedType = value ?? 'webhook'),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _webhookUrlController,
                decoration: const InputDecoration(
                  labelText: 'Webhook URL',
                  hintText: 'https://example.com/webhook',
                  border: OutlineInputBorder(),
                ),
              ),
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
                    onPressed: _saveIntegration,
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
        title: const Text('Integration Management'),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: !isTablet && !isMobile,
          tabs: const [
            Tab(icon: Icon(Icons.link), text: 'Integrations'),
            Tab(icon: Icon(Icons.history), text: 'Webhook History'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildIntegrationsTab(context, isMobile, isTablet, padding, fontSize),
          _buildHistoryTab(context, isMobile, isTablet, padding, fontSize),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          _resetForm();
          _showIntegrationDialog();
        },
        child: const Icon(Icons.add),
        tooltip: 'Create Integration',
      ),
    );
  }

  Widget _buildIntegrationsTab(BuildContext context, bool isMobile, bool isTablet, EdgeInsets padding, double fontSize) {
    if (_isLoadingIntegrations) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_integrations.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.link_off, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            Text('No integrations', style: TextStyle(fontSize: fontSize, color: Colors.grey)),
            const SizedBox(height: 8),
            Text('Tap + to create a new integration', style: TextStyle(fontSize: fontSize * 0.9, color: Colors.grey)),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: padding,
      itemCount: _integrations.length,
      itemBuilder: (context, index) {
        final integration = _integrations[index];
        final healthStatus = integration['healthStatus'] ?? {};
        final status = healthStatus['status'] ?? 'unknown';
        Color statusColor = Colors.grey;
        if (status == 'healthy') statusColor = Colors.green;
        else if (status == 'warning') statusColor = Colors.orange;
        else if (status == 'unhealthy') statusColor = Colors.red;

        return Card(
          margin: EdgeInsets.only(bottom: padding.bottom),
          child: ListTile(
            leading: Icon(
              integration['isActive'] == true ? Icons.link : Icons.link_off,
              color: integration['isActive'] == true ? statusColor : Colors.grey,
            ),
            title: Text(integration['name'] ?? 'Unknown', style: TextStyle(fontSize: fontSize)),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Type: ${integration['type'] ?? 'unknown'}', style: TextStyle(fontSize: fontSize * 0.9)),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Chip(
                      label: Text(integration['isActive'] == true ? 'Active' : 'Inactive', style: TextStyle(fontSize: fontSize * 0.8)),
                      backgroundColor: integration['isActive'] == true ? Colors.green.withOpacity(0.2) : Colors.grey.withOpacity(0.2),
                    ),
                    const SizedBox(width: 8),
                    Chip(
                      label: Text(status, style: TextStyle(fontSize: fontSize * 0.8)),
                      backgroundColor: statusColor.withOpacity(0.2),
                    ),
                  ],
                ),
                if (healthStatus['message'] != null) ...[
                  const SizedBox(height: 4),
                  Text(healthStatus['message'], style: TextStyle(fontSize: fontSize * 0.85, color: Colors.grey)),
                ],
              ],
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.health_and_safety),
                  onPressed: () => _checkHealth(integration['id']),
                  tooltip: 'Check Health',
                ),
                IconButton(
                  icon: const Icon(Icons.edit),
                  onPressed: () => _editIntegration(integration),
                ),
                IconButton(
                  icon: const Icon(Icons.delete, color: Colors.red),
                  onPressed: () => _deleteIntegration(integration['id'], integration['name'] ?? 'Unknown'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildHistoryTab(BuildContext context, bool isMobile, bool isTablet, EdgeInsets padding, double fontSize) {
    return Column(
      children: [
        Padding(
          padding: padding,
          child: DropdownButtonFormField<String>(
            value: _selectedIntegrationId,
            decoration: const InputDecoration(
              labelText: 'Select Integration',
              border: OutlineInputBorder(),
            ),
            items: [
              const DropdownMenuItem(value: null, child: Text('Select an integration')),
              ..._integrations.map((integration) {
                return DropdownMenuItem(
                  value: integration['id'],
                  child: Text(integration['name'] ?? 'Unknown'),
                );
              }),
            ],
            onChanged: (value) {
              if (value != null) {
                _loadWebhookHistory(value);
              }
            },
          ),
        ),
        Expanded(
          child: _isLoadingHistory
              ? const Center(child: CircularProgressIndicator())
              : _selectedIntegrationId == null
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.history, size: 64, color: Colors.grey),
                          const SizedBox(height: 16),
                          Text('Select an integration to view webhook history', style: TextStyle(fontSize: fontSize, color: Colors.grey)),
                        ],
                      ),
                    )
                  : _webhookHistory.isEmpty
                      ? Center(
                          child: Text('No webhook history', style: TextStyle(fontSize: fontSize, color: Colors.grey)),
                        )
                      : ListView.builder(
                          padding: padding,
                          itemCount: _webhookHistory.length,
                          itemBuilder: (context, index) {
                            final delivery = _webhookHistory[index];
                            final success = delivery['success'] == true;
                            final statusCode = delivery['statusCode'] ?? 0;

                            return Card(
                              margin: const EdgeInsets.only(bottom: 8),
                              child: ListTile(
                                leading: Icon(
                                  success ? Icons.check_circle : Icons.error,
                                  color: success ? Colors.green : Colors.red,
                                ),
                                title: Text(delivery['url'] ?? 'Unknown', style: TextStyle(fontSize: fontSize)),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Status: $statusCode, Response Time: ${delivery['responseTime'] ?? 0}ms',
                                      style: TextStyle(fontSize: fontSize * 0.9),
                                    ),
                                    if (delivery['timestamp'] != null)
                                      Text(
                                        DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.parse(delivery['timestamp'])),
                                        style: TextStyle(fontSize: fontSize * 0.85, color: Colors.grey),
                                      ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
        ),
      ],
    );
  }
}

