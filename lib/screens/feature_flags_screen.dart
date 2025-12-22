// =============================================================================
// FEATURE FLAGS & A/B TESTING SCREEN
// =============================================================================
// Comprehensive feature flag management with A/B testing, rollout percentage, and analytics
// Features: Flag CRUD, toggle on/off, percentage rollout, A/B test configuration, usage analytics

import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'dart:async';
import '../services/mongodb_admin_service.dart';
import '../services/theme_service.dart';
import '../utils/responsive_utils.dart';
import '../services/logger_service.dart';

class FeatureFlagsScreen extends StatefulWidget {
  const FeatureFlagsScreen({Key? key}) : super(key: key);

  @override
  State<FeatureFlagsScreen> createState() => _FeatureFlagsScreenState();
}

class _FeatureFlagsScreenState extends State<FeatureFlagsScreen> with SingleTickerProviderStateMixin {
  final MongoDBAdminService _adminService = MongoDBAdminService();
  late TabController _tabController;
  late ThemeService _themeService;

  // Flags list
  List<Map<String, dynamic>> _flags = [];
  bool _isLoadingFlags = false;

  // Create/Edit flag
  final TextEditingController _flagNameController = TextEditingController();
  final TextEditingController _flagDescriptionController = TextEditingController();
  bool _flagEnabled = false;
  double _rolloutPercentage = 0.0;
  bool _abTestEnabled = false;
  List<Map<String, dynamic>> _abTestVariants = [];
  final TextEditingController _variantNameController = TextEditingController();
  final TextEditingController _variantValueController = TextEditingController();
  String? _editingFlagId;

  // Analytics
  Map<String, dynamic>? _selectedFlagAnalytics;
  bool _isLoadingAnalytics = false;
  String _analyticsPeriod = '7d';
  String? _selectedFlagId;

  @override
  void initState() {
    super.initState();
    _themeService = ThemeService.instance;
    _themeService.addListener(() {
      if (mounted) setState(() {});
    });
    
    _tabController = TabController(length: 3, vsync: this);
    _loadFlags();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _flagNameController.dispose();
    _flagDescriptionController.dispose();
    _variantNameController.dispose();
    _variantValueController.dispose();
    super.dispose();
  }

  Future<void> _loadFlags() async {
    setState(() => _isLoadingFlags = true);
    try {
      final flags = await _adminService.getFeatureFlags();
      setState(() {
        _flags = flags;
        _isLoadingFlags = false;
      });
    } catch (e) {
      Log.e('Error loading feature flags', 'FEATURE_FLAGS', e);
      setState(() => _isLoadingFlags = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load feature flags: $e')),
        );
      }
    }
  }

  Future<void> _loadAnalytics(String flagId) async {
    setState(() {
      _isLoadingAnalytics = true;
      _selectedFlagId = flagId;
    });
    try {
      final analytics = await _adminService.getFeatureFlagAnalytics(flagId, period: _analyticsPeriod);
      setState(() {
        _selectedFlagAnalytics = analytics;
        _isLoadingAnalytics = false;
      });
    } catch (e) {
      Log.e('Error loading analytics', 'FEATURE_FLAGS', e);
      setState(() => _isLoadingAnalytics = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load analytics: $e')),
        );
      }
    }
  }

  Future<void> _saveFlag() async {
    if (_flagNameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Flag name is required')),
      );
      return;
    }

    try {
      if (_editingFlagId != null) {
        await _adminService.updateFeatureFlag(
          _editingFlagId!,
          name: _flagNameController.text.trim(),
          description: _flagDescriptionController.text.trim(),
          enabled: _flagEnabled,
          rolloutPercentage: _rolloutPercentage.round(),
          abTestEnabled: _abTestEnabled,
          abTestVariants: _abTestVariants,
        );
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Feature flag updated')),
        );
      } else {
        await _adminService.createFeatureFlag(
          name: _flagNameController.text.trim(),
          description: _flagDescriptionController.text.trim(),
          enabled: _flagEnabled,
          rolloutPercentage: _rolloutPercentage.round(),
          abTestEnabled: _abTestEnabled,
          abTestVariants: _abTestVariants,
        );
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Feature flag created')),
        );
      }
      _resetForm();
      _loadFlags();
      Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save flag: $e')),
        );
      }
    }
  }

  void _resetForm() {
    _flagNameController.clear();
    _flagDescriptionController.clear();
    _flagEnabled = false;
    _rolloutPercentage = 0.0;
    _abTestEnabled = false;
    _abTestVariants = [];
    _editingFlagId = null;
  }

  void _editFlag(Map<String, dynamic> flag) {
    setState(() {
      _editingFlagId = flag['id'];
      _flagNameController.text = flag['name'] ?? '';
      _flagDescriptionController.text = flag['description'] ?? '';
      _flagEnabled = flag['enabled'] ?? false;
      _rolloutPercentage = (flag['rolloutPercentage'] ?? 0).toDouble();
      _abTestEnabled = flag['abTestEnabled'] ?? false;
      _abTestVariants = List<Map<String, dynamic>>.from(flag['abTestVariants'] ?? []);
    });
    _showFlagDialog();
  }

  Future<void> _deleteFlag(String flagId, String flagName) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Feature Flag'),
        content: Text('Are you sure you want to delete "$flagName"?'),
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
        await _adminService.deleteFeatureFlag(flagId);
        _loadFlags();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Feature flag deleted')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to delete flag: $e')),
          );
        }
      }
    }
  }

  void _addVariant() {
    if (_variantNameController.text.trim().isEmpty || _variantValueController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Variant name and value are required')),
      );
      return;
    }

    setState(() {
      _abTestVariants.add({
        'name': _variantNameController.text.trim(),
        'value': _variantValueController.text.trim(),
      });
      _variantNameController.clear();
      _variantValueController.clear();
    });
  }

  void _removeVariant(int index) {
    setState(() {
      _abTestVariants.removeAt(index);
    });
  }

  void _showFlagDialog() {
    showDialog(
      context: context,
      builder: (context) => _buildFlagDialog(),
    );
  }

  Widget _buildFlagDialog() {
    final isMobile = ResponsiveUtils.isMobile(context);
    final padding = ResponsiveUtils.getResponsivePadding(context);

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
                _editingFlagId != null ? 'Edit Feature Flag' : 'Create Feature Flag',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _flagNameController,
                decoration: const InputDecoration(
                  labelText: 'Flag Name',
                  hintText: 'e.g., new_chat_ui',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _flagDescriptionController,
                decoration: const InputDecoration(
                  labelText: 'Description',
                  hintText: 'Describe what this feature flag controls',
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
              ),
              const SizedBox(height: 16),
              SwitchListTile(
                title: const Text('Enabled'),
                value: _flagEnabled,
                onChanged: (value) => setState(() => _flagEnabled = value),
              ),
              const SizedBox(height: 8),
              Text('Rollout Percentage: ${_rolloutPercentage.round()}%'),
              Slider(
                value: _rolloutPercentage,
                min: 0,
                max: 100,
                divisions: 100,
                label: '${_rolloutPercentage.round()}%',
                onChanged: (value) => setState(() => _rolloutPercentage = value),
              ),
              const SizedBox(height: 16),
              SwitchListTile(
                title: const Text('A/B Test Enabled'),
                value: _abTestEnabled,
                onChanged: (value) => setState(() => _abTestEnabled = value),
              ),
              if (_abTestEnabled) ...[
                const SizedBox(height: 16),
                const Text('A/B Test Variants:', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _variantNameController,
                        decoration: const InputDecoration(
                          labelText: 'Variant Name',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: _variantValueController,
                        decoration: const InputDecoration(
                          labelText: 'Variant Value',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.add),
                      onPressed: _addVariant,
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ..._abTestVariants.asMap().entries.map((entry) {
                  final index = entry.key;
                  final variant = entry.value;
                  return ListTile(
                    title: Text('${variant['name']}: ${variant['value']}'),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete),
                      onPressed: () => _removeVariant(index),
                    ),
                  );
                }),
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
                    onPressed: _saveFlag,
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
        title: const Text('Feature Flags & A/B Testing'),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: !isTablet && !isMobile,
          tabs: const [
            Tab(icon: Icon(Icons.flag), text: 'Flags'),
            Tab(icon: Icon(Icons.analytics), text: 'Analytics'),
            Tab(icon: Icon(Icons.science), text: 'A/B Tests'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildFlagsTab(context, isMobile, isTablet, padding, fontSize),
          _buildAnalyticsTab(context, isMobile, isTablet, padding, fontSize),
          _buildABTestsTab(context, isMobile, isTablet, padding, fontSize),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          _resetForm();
          _showFlagDialog();
        },
        child: const Icon(Icons.add),
        tooltip: 'Create Feature Flag',
      ),
    );
  }

  Widget _buildFlagsTab(BuildContext context, bool isMobile, bool isTablet, EdgeInsets padding, double fontSize) {
    if (_isLoadingFlags) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_flags.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.flag_outlined, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            Text('No feature flags', style: TextStyle(fontSize: fontSize, color: Colors.grey)),
            const SizedBox(height: 8),
            Text('Tap + to create a new feature flag', style: TextStyle(fontSize: fontSize * 0.9, color: Colors.grey)),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: padding,
      itemCount: _flags.length,
      itemBuilder: (context, index) {
        final flag = _flags[index];
        final stats = flag['usageStats'] ?? {};
        final enabledRate = (stats['totalChecks'] ?? 0) > 0
            ? ((stats['enabledChecks'] ?? 0) / (stats['totalChecks'] ?? 0)) * 100
            : 0.0;

        return Card(
          margin: EdgeInsets.only(bottom: padding.bottom),
          child: ListTile(
            leading: Icon(
              flag['enabled'] == true ? Icons.flag : Icons.flag_outlined,
              color: flag['enabled'] == true ? Colors.green : Colors.grey,
            ),
            title: Text(flag['name'] ?? 'Unknown', style: TextStyle(fontSize: fontSize)),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (flag['description'] != null && flag['description'].toString().isNotEmpty)
                  Text(flag['description'], style: TextStyle(fontSize: fontSize * 0.9)),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Chip(
                      label: Text(flag['enabled'] == true ? 'Enabled' : 'Disabled', style: TextStyle(fontSize: fontSize * 0.8)),
                      backgroundColor: flag['enabled'] == true ? Colors.green.withOpacity(0.2) : Colors.grey.withOpacity(0.2),
                    ),
                    const SizedBox(width: 8),
                    Chip(
                      label: Text('${flag['rolloutPercentage'] ?? 0}%', style: TextStyle(fontSize: fontSize * 0.8)),
                      backgroundColor: Colors.blue.withOpacity(0.2),
                    ),
                    if (flag['abTestEnabled'] == true) ...[
                      const SizedBox(width: 8),
                      Chip(
                        label: Text('A/B Test', style: TextStyle(fontSize: fontSize * 0.8)),
                        backgroundColor: Colors.purple.withOpacity(0.2),
                      ),
                    ],
                  ],
                ),
                if (stats['totalChecks'] != null && stats['totalChecks'] > 0) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Usage: ${stats['totalChecks']} checks, ${enabledRate.toStringAsFixed(1)}% enabled',
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
                  onPressed: () => _editFlag(flag),
                ),
                IconButton(
                  icon: const Icon(Icons.delete, color: Colors.red),
                  onPressed: () => _deleteFlag(flag['id'], flag['name'] ?? 'Unknown'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildAnalyticsTab(BuildContext context, bool isMobile, bool isTablet, EdgeInsets padding, double fontSize) {
    return Column(
      children: [
        Padding(
          padding: padding,
          child: Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: _selectedFlagId,
                  decoration: const InputDecoration(
                    labelText: 'Select Feature Flag',
                    border: OutlineInputBorder(),
                  ),
                  items: _flags.map((flag) {
                    return DropdownMenuItem<String>(
                      value: flag['id']?.toString(),
                      child: Text(flag['name'] ?? 'Unknown'),
                    );
                  }).toList(),
                  onChanged: (value) {
                    if (value != null) {
                      _loadAnalytics(value);
                    }
                  },
                ),
              ),
              const SizedBox(width: 16),
              DropdownButtonFormField<String>(
                value: _analyticsPeriod,
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
                  if (value != null && _selectedFlagId != null) {
                    setState(() => _analyticsPeriod = value);
                    _loadAnalytics(_selectedFlagId!);
                  }
                },
              ),
            ],
          ),
        ),
        Expanded(
          child: _isLoadingAnalytics
              ? const Center(child: CircularProgressIndicator())
              : _selectedFlagAnalytics == null
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.analytics_outlined, size: 64, color: Colors.grey),
                          const SizedBox(height: 16),
                          Text('Select a feature flag to view analytics', style: TextStyle(fontSize: fontSize, color: Colors.grey)),
                        ],
                      ),
                    )
                  : _buildAnalyticsContent(context, isMobile, isTablet, padding, fontSize),
        ),
      ],
    );
  }

  Widget _buildAnalyticsContent(BuildContext context, bool isMobile, bool isTablet, EdgeInsets padding, double fontSize) {
    if (_selectedFlagAnalytics == null) {
      return Center(
        child: Text('No analytics data', style: TextStyle(fontSize: fontSize, color: Colors.grey)),
      );
    }
    
    final stats = _selectedFlagAnalytics!['stats'] ?? {};
    final totalChecks = stats['totalChecks'] ?? 0;
    final enabledChecks = stats['enabledChecks'] ?? 0;
    final disabledChecks = stats['disabledChecks'] ?? 0;
    final enabledRate = totalChecks > 0 ? (enabledChecks / totalChecks) * 100 : 0.0;
    final flagName = _selectedFlagAnalytics!['flagName'] ?? 'Unknown';

    return SingleChildScrollView(
      padding: padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Analytics for $flagName', style: TextStyle(fontSize: fontSize * 1.2, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Total Checks', style: TextStyle(fontSize: fontSize * 0.9, color: Colors.grey)),
                        const SizedBox(height: 8),
                        Text('$totalChecks', style: TextStyle(fontSize: fontSize * 1.5, fontWeight: FontWeight.bold)),
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
                        Text('Enabled Rate', style: TextStyle(fontSize: fontSize * 0.9, color: Colors.grey)),
                        const SizedBox(height: 8),
                        Text('${enabledRate.toStringAsFixed(1)}%', style: TextStyle(fontSize: fontSize * 1.5, fontWeight: FontWeight.bold, color: Colors.green)),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Enabled Checks', style: TextStyle(fontSize: fontSize * 0.9, color: Colors.grey)),
                        const SizedBox(height: 8),
                        Text('$enabledChecks', style: TextStyle(fontSize: fontSize * 1.5, fontWeight: FontWeight.bold, color: Colors.green)),
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
                        Text('Disabled Checks', style: TextStyle(fontSize: fontSize * 0.9, color: Colors.grey)),
                        const SizedBox(height: 8),
                        Text('$disabledChecks', style: TextStyle(fontSize: fontSize * 1.5, fontWeight: FontWeight.bold, color: Colors.red)),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: 200,
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Usage Distribution', style: TextStyle(fontSize: fontSize, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 16),
                    Expanded(
                      child: PieChart(
                        PieChartData(
                          sections: [
                            PieChartSectionData(
                              value: enabledChecks.toDouble(),
                              title: '${enabledRate.toStringAsFixed(1)}%',
                              color: Colors.green,
                              radius: 80,
                            ),
                            PieChartSectionData(
                              value: disabledChecks.toDouble(),
                              title: '${(100 - enabledRate).toStringAsFixed(1)}%',
                              color: Colors.red,
                              radius: 80,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildABTestsTab(BuildContext context, bool isMobile, bool isTablet, EdgeInsets padding, double fontSize) {
    final abTestFlags = _flags.where((flag) => flag['abTestEnabled'] == true).toList();

    if (abTestFlags.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.science_outlined, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            Text('No A/B tests configured', style: TextStyle(fontSize: fontSize, color: Colors.grey)),
            const SizedBox(height: 8),
            Text('Enable A/B testing on a feature flag to see it here', style: TextStyle(fontSize: fontSize * 0.9, color: Colors.grey)),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: padding,
      itemCount: abTestFlags.length,
      itemBuilder: (context, index) {
        final flag = abTestFlags[index];
        final variants = List<Map<String, dynamic>>.from(flag['abTestVariants'] ?? []);

        return Card(
          margin: EdgeInsets.only(bottom: padding.bottom),
          child: ExpansionTile(
            leading: Icon(Icons.science, color: Colors.purple),
            title: Text(flag['name'] ?? 'Unknown', style: TextStyle(fontSize: fontSize)),
            subtitle: Text('${variants.length} variants', style: TextStyle(fontSize: fontSize * 0.9)),
            children: [
              Padding(
                padding: padding,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('A/B Test Variants:', style: TextStyle(fontSize: fontSize, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    ...variants.map((variant) {
                      return ListTile(
                        leading: const Icon(Icons.label),
                        title: Text(variant['name'] ?? 'Unknown', style: TextStyle(fontSize: fontSize)),
                        subtitle: Text('Value: ${variant['value']}', style: TextStyle(fontSize: fontSize * 0.9)),
                      );
                    }),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

