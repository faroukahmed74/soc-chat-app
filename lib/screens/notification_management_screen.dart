// =============================================================================
// NOTIFICATION MANAGEMENT SCREEN
// =============================================================================
// Comprehensive notification management with templates, sending, tracking, and analytics
// Features: Template management, test sending, delivery tracking, analytics

import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'dart:async';
import '../services/mongodb_admin_service.dart';
import '../services/theme_service.dart';
import '../utils/responsive_utils.dart';
import '../services/logger_service.dart';

class NotificationManagementScreen extends StatefulWidget {
  const NotificationManagementScreen({Key? key}) : super(key: key);

  @override
  State<NotificationManagementScreen> createState() => _NotificationManagementScreenState();
}

class _NotificationManagementScreenState extends State<NotificationManagementScreen> with SingleTickerProviderStateMixin {
  final MongoDBAdminService _adminService = MongoDBAdminService();
  late TabController _tabController;
  late ThemeService _themeService;

  // Templates
  List<Map<String, dynamic>> _templates = [];
  bool _isLoadingTemplates = false;
  final TextEditingController _templateNameController = TextEditingController();
  final TextEditingController _templateTitleController = TextEditingController();
  final TextEditingController _templateBodyController = TextEditingController();
  final TextEditingController _templateCategoryController = TextEditingController();

  // Send notification
  final TextEditingController _sendUserIdController = TextEditingController();
  final TextEditingController _sendTitleController = TextEditingController();
  final TextEditingController _sendBodyController = TextEditingController();
  String? _selectedTemplateId;

  // History
  List<Map<String, dynamic>> _history = [];
  bool _isLoadingHistory = false;
  String? _historyStatusFilter;

  // Analytics
  Map<String, dynamic>? _analytics;
  bool _isLoadingAnalytics = false;
  String _analyticsPeriod = '24h';

  @override
  void initState() {
    super.initState();
    _themeService = ThemeService.instance;
    _themeService.addListener(() {
      if (mounted) setState(() {});
    });
    
    _tabController = TabController(length: 4, vsync: this);
    _loadTemplates();
    _loadHistory();
    _loadAnalytics();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _templateNameController.dispose();
    _templateTitleController.dispose();
    _templateBodyController.dispose();
    _templateCategoryController.dispose();
    _sendUserIdController.dispose();
    _sendTitleController.dispose();
    _sendBodyController.dispose();
    super.dispose();
  }

  Future<void> _loadTemplates() async {
    setState(() => _isLoadingTemplates = true);
    try {
      final templates = await _adminService.getNotificationTemplates();
      setState(() {
        _templates = templates;
        _isLoadingTemplates = false;
      });
    } catch (e) {
      Log.e('Error loading templates', 'NOTIFICATION_MANAGEMENT', e);
      setState(() => _isLoadingTemplates = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load templates: $e')),
        );
      }
    }
  }

  Future<void> _loadHistory() async {
    setState(() => _isLoadingHistory = true);
    try {
      final data = await _adminService.getNotificationHistory(status: _historyStatusFilter);
      setState(() {
        _history = List<Map<String, dynamic>>.from(data['history'] ?? []);
        _isLoadingHistory = false;
      });
    } catch (e) {
      Log.e('Error loading history', 'NOTIFICATION_MANAGEMENT', e);
      setState(() => _isLoadingHistory = false);
    }
  }

  Future<void> _loadAnalytics() async {
    setState(() => _isLoadingAnalytics = true);
    try {
      final analytics = await _adminService.getNotificationAnalytics(period: _analyticsPeriod);
      setState(() {
        _analytics = analytics;
        _isLoadingAnalytics = false;
      });
    } catch (e) {
      Log.e('Error loading analytics', 'NOTIFICATION_MANAGEMENT', e);
      setState(() => _isLoadingAnalytics = false);
    }
  }

  Future<void> _createTemplate() async {
    if (_templateNameController.text.isEmpty ||
        _templateTitleController.text.isEmpty ||
        _templateBodyController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Name, title, and body are required')),
      );
      return;
    }

    try {
      await _adminService.createNotificationTemplate(
        name: _templateNameController.text,
        title: _templateTitleController.text,
        body: _templateBodyController.text,
        category: _templateCategoryController.text.isEmpty
            ? null
            : _templateCategoryController.text,
      );
      _templateNameController.clear();
      _templateTitleController.clear();
      _templateBodyController.clear();
      _templateCategoryController.clear();
      _loadTemplates();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Template created successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to create template: $e')),
        );
      }
    }
  }

  Future<void> _sendTestNotification() async {
    if (_sendUserIdController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('User ID is required')),
      );
      return;
    }

    if (_sendTitleController.text.isEmpty && _selectedTemplateId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Title or template is required')),
      );
      return;
    }

    try {
      await _adminService.sendTestNotification(
        userId: _sendUserIdController.text,
        title: _sendTitleController.text.isEmpty ? null : _sendTitleController.text,
        body: _sendBodyController.text.isEmpty ? null : _sendBodyController.text,
        templateId: _selectedTemplateId,
      );
      _loadHistory();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Test notification sent')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to send notification: $e')),
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
        title: const Text('Notification Management'),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: !isTablet && !isMobile,
          tabs: const [
            Tab(icon: Icon(Icons.description), text: 'Templates'),
            Tab(icon: Icon(Icons.send), text: 'Send'),
            Tab(icon: Icon(Icons.history), text: 'History'),
            Tab(icon: Icon(Icons.analytics), text: 'Analytics'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildTemplatesTab(context, isMobile, isTablet, padding, fontSize),
          _buildSendTab(context, isMobile, isTablet, padding, fontSize),
          _buildHistoryTab(context, isMobile, isTablet, padding, fontSize),
          _buildAnalyticsTab(context, isMobile, isTablet, padding, fontSize),
        ],
      ),
    );
  }

  Widget _buildTemplatesTab(BuildContext context, bool isMobile, bool isTablet, EdgeInsets padding, double fontSize) {
    return SingleChildScrollView(
      padding: padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Create Template
          Card(
            child: Padding(
              padding: padding,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('Create Template', style: TextStyle(fontSize: fontSize * 1.2, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _templateNameController,
                    decoration: const InputDecoration(
                      labelText: 'Template Name',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _templateTitleController,
                    decoration: const InputDecoration(
                      labelText: 'Title',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _templateBodyController,
                    decoration: const InputDecoration(
                      labelText: 'Body',
                      border: OutlineInputBorder(),
                    ),
                    maxLines: 3,
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _templateCategoryController,
                    decoration: const InputDecoration(
                      labelText: 'Category (optional)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: _createTemplate,
                    icon: const Icon(Icons.add),
                    label: const Text('Create Template'),
                  ),
                ],
              ),
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Templates List
          Text('Templates (${_templates.length})', style: TextStyle(fontSize: fontSize * 1.2, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          if (_isLoadingTemplates)
            const Center(child: CircularProgressIndicator())
          else if (_templates.isEmpty)
            Card(
              child: Padding(
                padding: padding,
                child: Text('No templates', style: TextStyle(fontSize: fontSize, color: Colors.grey)),
              ),
            )
          else
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _templates.length,
              itemBuilder: (context, index) {
                final template = _templates[index];
                return Card(
                  child: ListTile(
                    title: Text(template['name'] ?? 'Unnamed'),
                    subtitle: Text(template['title'] ?? ''),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit),
                          onPressed: () {
                            // TODO: Implement edit
                          },
                          tooltip: 'Edit',
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete),
                          onPressed: () async {
                            final confirmed = await showDialog<bool>(
                              context: context,
                              builder: (context) => AlertDialog(
                                title: const Text('Delete Template'),
                                content: Text('Delete "${template['name']}"?'),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(context, false),
                                    child: const Text('Cancel'),
                                  ),
                                  TextButton(
                                    onPressed: () => Navigator.pop(context, true),
                                    child: const Text('Delete'),
                                  ),
                                ],
                              ),
                            );
                            if (confirmed == true) {
                              try {
                                await _adminService.deleteNotificationTemplate(template['id']);
                                _loadTemplates();
                              } catch (e) {
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('Error: $e')),
                                  );
                                }
                              }
                            }
                          },
                          tooltip: 'Delete',
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _buildSendTab(BuildContext context, bool isMobile, bool isTablet, EdgeInsets padding, double fontSize) {
    return SingleChildScrollView(
      padding: padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Card(
            child: Padding(
              padding: padding,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('Send Test Notification', style: TextStyle(fontSize: fontSize * 1.2, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _sendUserIdController,
                    decoration: const InputDecoration(
                      labelText: 'User ID',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    value: _selectedTemplateId,
                    decoration: const InputDecoration(
                      labelText: 'Template (optional)',
                      border: OutlineInputBorder(),
                    ),
                    items: [
                      const DropdownMenuItem(value: null, child: Text('None')),
                      ..._templates.map((t) => DropdownMenuItem(
                            value: t['id'],
                            child: Text(t['name'] ?? 'Unnamed'),
                          )),
                    ],
                    onChanged: (value) {
                      setState(() {
                        _selectedTemplateId = value;
                        if (value != null) {
                          final template = _templates.firstWhere((t) => t['id'] == value);
                          _sendTitleController.text = template['title'] ?? '';
                          _sendBodyController.text = template['body'] ?? '';
                        }
                      });
                    },
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _sendTitleController,
                    decoration: const InputDecoration(
                      labelText: 'Title',
                      border: OutlineInputBorder(),
                    ),
                    enabled: _selectedTemplateId == null,
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _sendBodyController,
                    decoration: const InputDecoration(
                      labelText: 'Body',
                      border: OutlineInputBorder(),
                    ),
                    maxLines: 3,
                    enabled: _selectedTemplateId == null,
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: _sendTestNotification,
                    icon: const Icon(Icons.send),
                    label: const Text('Send Test Notification'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryTab(BuildContext context, bool isMobile, bool isTablet, EdgeInsets padding, double fontSize) {
    return Column(
      children: [
        // Filters
        Padding(
          padding: padding,
          child: Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: _historyStatusFilter,
                  decoration: const InputDecoration(
                    labelText: 'Filter by Status',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(value: null, child: Text('All')),
                    DropdownMenuItem(value: 'sent', child: Text('Sent')),
                    DropdownMenuItem(value: 'failed', child: Text('Failed')),
                  ],
                  onChanged: (value) {
                    setState(() {
                      _historyStatusFilter = value;
                      _loadHistory();
                    });
                  },
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: _loadHistory,
                tooltip: 'Refresh',
              ),
            ],
          ),
        ),
        
        // History List
        Expanded(
          child: _isLoadingHistory
              ? const Center(child: CircularProgressIndicator())
              : _history.isEmpty
                  ? Center(
                      child: Text('No notification history', style: TextStyle(fontSize: fontSize, color: Colors.grey)),
                    )
                  : ListView.builder(
                      padding: padding,
                      itemCount: _history.length,
                      itemBuilder: (context, index) {
                        final item = _history[index];
                        final status = item['status'] ?? 'unknown';
                        Color statusColor = Colors.green;
                        if (status == 'failed') statusColor = Colors.red;
                        
                        return Card(
                          child: ListTile(
                            leading: Icon(
                              status == 'sent' ? Icons.check_circle : Icons.error,
                              color: statusColor,
                            ),
                            title: Text(item['title'] ?? 'No title'),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(item['body'] ?? ''),
                                Text('To: ${item['userName'] ?? item['userId'] ?? 'Unknown'}'),
                                Text(DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.parse(item['sentAt'] ?? DateTime.now().toIso8601String()))),
                                if (item['error'] != null)
                                  Text('Error: ${item['error']}', style: const TextStyle(color: Colors.red)),
                              ],
                            ),
                            trailing: status == 'failed'
                                ? IconButton(
                                    icon: const Icon(Icons.refresh),
                                    onPressed: () async {
                                      try {
                                        await _adminService.retryNotification(item['id']);
                                        _loadHistory();
                                        if (mounted) {
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            const SnackBar(content: Text('Notification retried')),
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
                                    tooltip: 'Retry',
                                  )
                                : null,
                          ),
                        );
                      },
                    ),
        ),
      ],
    );
  }

  Widget _buildAnalyticsTab(BuildContext context, bool isMobile, bool isTablet, EdgeInsets padding, double fontSize) {
    if (_isLoadingAnalytics) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_analytics == null) {
      return Center(
        child: Text('Failed to load analytics', style: TextStyle(fontSize: fontSize)),
      );
    }

    final summary = _analytics!['summary'] ?? {};
    final notificationsByTime = List<Map<String, dynamic>>.from(_analytics!['notificationsByTime'] ?? []);
    final topTemplates = List<Map<String, dynamic>>.from(_analytics!['topTemplates'] ?? []);

    return SingleChildScrollView(
      padding: padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Period selector
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: _analyticsPeriod,
                  decoration: const InputDecoration(
                    labelText: 'Period',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(value: '1h', child: Text('Last hour')),
                    DropdownMenuItem(value: '24h', child: Text('Last 24 hours')),
                    DropdownMenuItem(value: '7d', child: Text('Last 7 days')),
                    DropdownMenuItem(value: '30d', child: Text('Last 30 days')),
                  ],
                  onChanged: (value) {
                    setState(() {
                      _analyticsPeriod = value ?? '24h';
                      _loadAnalytics();
                    });
                  },
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 16),
          
          // Summary Cards
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: isMobile ? 2 : 4,
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
            childAspectRatio: 1.5,
            children: [
              _buildMetricCard(
                'Total Sent',
                summary['totalSent']?.toString() ?? '0',
                Icons.send,
                Colors.green,
              ),
              _buildMetricCard(
                'Total Failed',
                summary['totalFailed']?.toString() ?? '0',
                Icons.error,
                Colors.red,
              ),
              _buildMetricCard(
                'Total',
                summary['totalNotifications']?.toString() ?? '0',
                Icons.notifications,
                Colors.blue,
              ),
              _buildMetricCard(
                'Success Rate',
                '${(summary['successRate'] ?? 100).toStringAsFixed(1)}%',
                Icons.trending_up,
                Colors.purple,
              ),
            ],
          ),
          
          const SizedBox(height: 16),
          
          // Notifications by Time Chart
          if (notificationsByTime.isNotEmpty) ...[
            Card(
              child: Padding(
                padding: padding,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text('Notifications Over Time', style: TextStyle(fontSize: fontSize * 1.2, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 16),
                    SizedBox(
                      height: 200,
                      child: BarChart(
                        BarChartData(
                          alignment: BarChartAlignment.spaceAround,
                          maxY: notificationsByTime.map((e) => (e['sent'] ?? 0) + (e['failed'] ?? 0)).fold(0, (a, b) => a > b ? a : b) * 1.2,
                          barTouchData: BarTouchData(enabled: true),
                          titlesData: FlTitlesData(show: true),
                          gridData: FlGridData(show: true),
                          borderData: FlBorderData(show: true),
                          barGroups: notificationsByTime.asMap().entries.map((entry) {
                            final data = entry.value;
                            return BarChartGroupData(
                              x: entry.key,
                              barRods: [
                                BarChartRodData(
                                  toY: (data['sent'] ?? 0).toDouble(),
                                  color: Colors.green,
                                  width: 12,
                                ),
                                BarChartRodData(
                                  toY: (data['failed'] ?? 0).toDouble(),
                                  color: Colors.red,
                                  width: 12,
                                ),
                              ],
                            );
                          }).toList(),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
          
          // Top Templates
          if (topTemplates.isNotEmpty) ...[
            Text('Top Templates', style: TextStyle(fontSize: fontSize * 1.2, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: topTemplates.length,
              itemBuilder: (context, index) {
                final template = topTemplates[index];
                return Card(
                  child: ListTile(
                    leading: Text('${index + 1}', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                    title: Text(template['templateName'] ?? 'Unknown'),
                    subtitle: Text('Sent: ${template['sent']}, Failed: ${template['failed']}'),
                    trailing: Text('${template['count']} total'),
                  ),
                );
              },
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMetricCard(String title, String value, IconData icon, Color color) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 32),
            const SizedBox(height: 8),
            Text(
              value,
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              title,
              style: const TextStyle(fontSize: 12, color: Colors.grey),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

