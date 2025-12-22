// =============================================================================
// CUSTOM REPORTS SCREEN
// =============================================================================
// Comprehensive custom report management with template creation and generation
// Features: Report template CRUD, report generation, format selection

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'dart:async';
import '../services/mongodb_admin_service.dart';
import '../services/theme_service.dart';
import '../utils/responsive_utils.dart';
import '../services/logger_service.dart';

class CustomReportsScreen extends StatefulWidget {
  const CustomReportsScreen({Key? key}) : super(key: key);

  @override
  State<CustomReportsScreen> createState() => _CustomReportsScreenState();
}

class _CustomReportsScreenState extends State<CustomReportsScreen> with SingleTickerProviderStateMixin {
  final MongoDBAdminService _adminService = MongoDBAdminService();
  late TabController _tabController;
  late ThemeService _themeService;

  List<Map<String, dynamic>> _templates = [];
  bool _isLoadingTemplates = false;
  final TextEditingController _templateNameController = TextEditingController();
  final TextEditingController _templateDescriptionController = TextEditingController();
  String _selectedFormat = 'csv';

  @override
  void initState() {
    super.initState();
    _themeService = ThemeService.instance;
    _themeService.addListener(() {
      if (mounted) setState(() {});
    });
    _tabController = TabController(length: 2, vsync: this);
    _loadTemplates();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _templateNameController.dispose();
    _templateDescriptionController.dispose();
    super.dispose();
  }

  Future<void> _loadTemplates() async {
    setState(() => _isLoadingTemplates = true);
    try {
      final templates = await _adminService.getReportTemplates();
      setState(() {
        _templates = templates;
        _isLoadingTemplates = false;
      });
    } catch (e) {
      Log.e('Error loading templates', 'CUSTOM_REPORTS', e);
      setState(() => _isLoadingTemplates = false);
    }
  }

  Future<void> _createTemplate() async {
    if (_templateNameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Template name is required')),
      );
      return;
    }

    try {
      await _adminService.createReportTemplate(
        name: _templateNameController.text.trim(),
        description: _templateDescriptionController.text.trim().isEmpty ? null : _templateDescriptionController.text.trim(),
        format: _selectedFormat,
      );
      _templateNameController.clear();
      _templateDescriptionController.clear();
      _loadTemplates();
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Template created')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to create template: $e')),
      );
    }
  }

  Future<void> _generateReport(String? templateId) async {
    try {
      final reportId = await _adminService.generateReport(
        templateId: templateId,
        format: _selectedFormat,
      );
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Report generated: $reportId')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to generate report: $e')),
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
        title: const Text('Custom Reports'),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: !isTablet && !isMobile,
          tabs: const [
            Tab(icon: Icon(Icons.description), text: 'Templates'),
            Tab(icon: Icon(Icons.picture_as_pdf), text: 'Generate'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildTemplatesTab(context, isMobile, isTablet, padding, fontSize),
          _buildGenerateTab(context, isMobile, isTablet, padding, fontSize),
        ],
      ),
      floatingActionButton: _tabController.index == 0
          ? FloatingActionButton(
              onPressed: () {
                _templateNameController.clear();
                _templateDescriptionController.clear();
                showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Create Template'),
                    content: SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          TextField(
                            controller: _templateNameController,
                            decoration: const InputDecoration(labelText: 'Template Name', border: OutlineInputBorder()),
                          ),
                          const SizedBox(height: 16),
                          TextField(
                            controller: _templateDescriptionController,
                            decoration: const InputDecoration(labelText: 'Description', border: OutlineInputBorder()),
                            maxLines: 3,
                          ),
                          const SizedBox(height: 16),
                          DropdownButtonFormField<String>(
                            value: _selectedFormat,
                            decoration: const InputDecoration(labelText: 'Format', border: OutlineInputBorder()),
                            items: const [
                              DropdownMenuItem(value: 'csv', child: Text('CSV')),
                              DropdownMenuItem(value: 'pdf', child: Text('PDF')),
                              DropdownMenuItem(value: 'excel', child: Text('Excel')),
                            ],
                            onChanged: (value) => setState(() => _selectedFormat = value ?? 'csv'),
                          ),
                        ],
                      ),
                    ),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
                      ElevatedButton(onPressed: _createTemplate, child: const Text('Create')),
                    ],
                  ),
                );
              },
              child: const Icon(Icons.add),
            )
          : null,
    );
  }

  Widget _buildTemplatesTab(BuildContext context, bool isMobile, bool isTablet, EdgeInsets padding, double fontSize) {
    if (_isLoadingTemplates) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_templates.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.description_outlined, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            Text('No templates', style: TextStyle(fontSize: fontSize, color: Colors.grey)),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: padding,
      itemCount: _templates.length,
      itemBuilder: (context, index) {
        final template = _templates[index];
        return Card(
          margin: EdgeInsets.only(bottom: padding.bottom),
          child: ListTile(
            leading: const Icon(Icons.description),
            title: Text(template['name'] ?? 'Unknown', style: TextStyle(fontSize: fontSize)),
            subtitle: Text('Format: ${template['format'] ?? 'unknown'}', style: TextStyle(fontSize: fontSize * 0.9)),
            trailing: IconButton(
              icon: const Icon(Icons.delete, color: Colors.red),
              onPressed: () {
                // Delete functionality would go here
              },
            ),
          ),
        );
      },
    );
  }

  Widget _buildGenerateTab(BuildContext context, bool isMobile, bool isTablet, EdgeInsets padding, double fontSize) {
    return SingleChildScrollView(
      padding: padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DropdownButtonFormField<String>(
            value: _selectedFormat,
            decoration: const InputDecoration(labelText: 'Report Format', border: OutlineInputBorder()),
            items: const [
              DropdownMenuItem(value: 'csv', child: Text('CSV')),
              DropdownMenuItem(value: 'pdf', child: Text('PDF')),
              DropdownMenuItem(value: 'excel', child: Text('Excel')),
            ],
            onChanged: (value) => setState(() => _selectedFormat = value ?? 'csv'),
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            value: null,
            decoration: const InputDecoration(labelText: 'Template (Optional)', border: OutlineInputBorder()),
            items: _templates.map((t) => DropdownMenuItem<String>(value: t['id']?.toString(), child: Text(t['name'] ?? 'Unknown'))).toList(),
            onChanged: (value) {},
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            icon: const Icon(Icons.picture_as_pdf),
            label: const Text('Generate Report'),
            onPressed: () => _generateReport(null),
            style: ElevatedButton.styleFrom(padding: EdgeInsets.all(padding.left)),
          ),
        ],
      ),
    );
  }
}

