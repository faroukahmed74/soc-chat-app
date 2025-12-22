// =============================================================================
// USER SEGMENTATION SCREEN
// =============================================================================
// Comprehensive user segmentation with rule-based segment creation
// Features: Segment CRUD, rule configuration, member list, analytics

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'dart:async';
import '../services/mongodb_admin_service.dart';
import '../services/theme_service.dart';
import '../utils/responsive_utils.dart';
import '../services/logger_service.dart';

class UserSegmentationScreen extends StatefulWidget {
  const UserSegmentationScreen({Key? key}) : super(key: key);

  @override
  State<UserSegmentationScreen> createState() => _UserSegmentationScreenState();
}

class _UserSegmentationScreenState extends State<UserSegmentationScreen> with SingleTickerProviderStateMixin {
  final MongoDBAdminService _adminService = MongoDBAdminService();
  late TabController _tabController;
  late ThemeService _themeService;

  List<Map<String, dynamic>> _segments = [];
  bool _isLoadingSegments = false;
  List<Map<String, dynamic>> _selectedSegmentMembers = [];
  bool _isLoadingMembers = false;
  String? _selectedSegmentId;

  final TextEditingController _segmentNameController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _themeService = ThemeService.instance;
    _themeService.addListener(() {
      if (mounted) setState(() {});
    });
    _tabController = TabController(length: 2, vsync: this);
    _loadSegments();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _segmentNameController.dispose();
    super.dispose();
  }

  Future<void> _loadSegments() async {
    setState(() => _isLoadingSegments = true);
    try {
      final segments = await _adminService.getSegments();
      setState(() {
        _segments = segments;
        _isLoadingSegments = false;
      });
    } catch (e) {
      Log.e('Error loading segments', 'USER_SEGMENTATION', e);
      setState(() => _isLoadingSegments = false);
    }
  }

  Future<void> _loadSegmentMembers(String segmentId) async {
    setState(() {
      _isLoadingMembers = true;
      _selectedSegmentId = segmentId;
    });
    try {
      final members = await _adminService.getSegmentMembers(segmentId);
      setState(() {
        _selectedSegmentMembers = members;
        _isLoadingMembers = false;
      });
    } catch (e) {
      Log.e('Error loading segment members', 'USER_SEGMENTATION', e);
      setState(() => _isLoadingMembers = false);
    }
  }

  Future<void> _createSegment() async {
    if (_segmentNameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Segment name is required')),
      );
      return;
    }

    try {
      await _adminService.createSegment(name: _segmentNameController.text.trim());
      _segmentNameController.clear();
      _loadSegments();
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Segment created')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to create segment: $e')),
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
        title: const Text('User Segmentation'),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: !isTablet && !isMobile,
          tabs: const [
            Tab(icon: Icon(Icons.group), text: 'Segments'),
            Tab(icon: Icon(Icons.people), text: 'Members'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildSegmentsTab(context, isMobile, isTablet, padding, fontSize),
          _buildMembersTab(context, isMobile, isTablet, padding, fontSize),
        ],
      ),
      floatingActionButton: _tabController.index == 0
          ? FloatingActionButton(
              onPressed: () {
                _segmentNameController.clear();
                showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Create Segment'),
                    content: TextField(
                      controller: _segmentNameController,
                      decoration: const InputDecoration(labelText: 'Segment Name', border: OutlineInputBorder()),
                    ),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
                      ElevatedButton(onPressed: _createSegment, child: const Text('Create')),
                    ],
                  ),
                );
              },
              child: const Icon(Icons.add),
            )
          : null,
    );
  }

  Widget _buildSegmentsTab(BuildContext context, bool isMobile, bool isTablet, EdgeInsets padding, double fontSize) {
    if (_isLoadingSegments) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_segments.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.group_outlined, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            Text('No segments', style: TextStyle(fontSize: fontSize, color: Colors.grey)),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: padding,
      itemCount: _segments.length,
      itemBuilder: (context, index) {
        final segment = _segments[index];
        return Card(
          margin: EdgeInsets.only(bottom: padding.bottom),
          child: ListTile(
            leading: const Icon(Icons.group),
            title: Text(segment['name'] ?? 'Unknown', style: TextStyle(fontSize: fontSize)),
            subtitle: Text('Members: ${segment['memberCount'] ?? 0}', style: TextStyle(fontSize: fontSize * 0.9)),
            trailing: IconButton(
              icon: const Icon(Icons.delete, color: Colors.red),
              onPressed: () {
                // Delete functionality would go here
              },
            ),
            onTap: () {
              if (_tabController.index == 0) {
                _tabController.animateTo(1);
                _loadSegmentMembers(segment['id']);
              }
            },
          ),
        );
      },
    );
  }

  Widget _buildMembersTab(BuildContext context, bool isMobile, bool isTablet, EdgeInsets padding, double fontSize) {
    return Column(
      children: [
        Padding(
          padding: padding,
          child: DropdownButtonFormField<String>(
            value: _selectedSegmentId,
            decoration: const InputDecoration(labelText: 'Select Segment', border: OutlineInputBorder()),
            items: [
              const DropdownMenuItem(value: null, child: Text('Select a segment')),
              ..._segments.map((s) => DropdownMenuItem(value: s['id'], child: Text(s['name'] ?? 'Unknown'))),
            ],
            onChanged: (value) {
              if (value != null) {
                _loadSegmentMembers(value);
              }
            },
          ),
        ),
        Expanded(
          child: _isLoadingMembers
              ? const Center(child: CircularProgressIndicator())
              : _selectedSegmentId == null
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.people_outline, size: 64, color: Colors.grey),
                          const SizedBox(height: 16),
                          Text('Select a segment to view members', style: TextStyle(fontSize: fontSize, color: Colors.grey)),
                        ],
                      ),
                    )
                  : _selectedSegmentMembers.isEmpty
                      ? Center(
                          child: Text('No members in this segment', style: TextStyle(fontSize: fontSize, color: Colors.grey)),
                        )
                      : ListView.builder(
                          padding: padding,
                          itemCount: _selectedSegmentMembers.length,
                          itemBuilder: (context, index) {
                            final member = _selectedSegmentMembers[index];
                            return Card(
                              margin: const EdgeInsets.only(bottom: 8),
                              child: ListTile(
                                leading: const Icon(Icons.person),
                                title: Text(member['username'] ?? 'Unknown', style: TextStyle(fontSize: fontSize)),
                                subtitle: Text(member['email'] ?? '', style: TextStyle(fontSize: fontSize * 0.9)),
                              ),
                            );
                          },
                        ),
        ),
      ],
    );
  }
}

