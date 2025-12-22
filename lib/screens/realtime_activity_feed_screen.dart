// =============================================================================
// REAL-TIME ACTIVITY FEED SCREEN
// =============================================================================
// This screen provides a real-time activity feed for admin panel
// Shows user activities, admin actions, and system events in real-time

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/admin_activity_service.dart';
import '../services/theme_service.dart';
import '../services/logger_service.dart';
import '../utils/responsive_utils.dart';

class RealtimeActivityFeedScreen extends StatefulWidget {
  const RealtimeActivityFeedScreen({Key? key}) : super(key: key);

  @override
  State<RealtimeActivityFeedScreen> createState() => _RealtimeActivityFeedScreenState();
}

class _RealtimeActivityFeedScreenState extends State<RealtimeActivityFeedScreen> {
  final AdminActivityService _activityService = AdminActivityService();
  final ThemeService _themeService = ThemeService();
  
  List<Map<String, dynamic>> _activities = [];
  bool _isLoading = true;
  String? _selectedType;
  String _searchQuery = '';
  bool _isConnected = false;
  ScrollController? _scrollController;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _initializeService();
  }

  Future<void> _initializeService() async {
    try {
      // Connect to activity service
      await _activityService.connect();
      
      // Subscribe to real-time updates
      _activityService.subscribe(_onActivityReceived);
      
      // Fetch initial activities
      await _loadActivities();
      
      setState(() {
        _isConnected = _activityService.isConnected;
        _isLoading = false;
      });
    } catch (e) {
      Log.e('Error initializing activity service', 'REALTIME_ACTIVITY', e);
      setState(() => _isLoading = false);
    }
  }

  void _onActivityReceived(Map<String, dynamic> activity) {
    setState(() {
      // Add new activity at the top
      _activities.insert(0, activity);
      
      // Limit to 200 activities
      if (_activities.length > 200) {
        _activities.removeRange(200, _activities.length);
      }
    });
  }

  Future<void> _loadActivities() async {
    setState(() => _isLoading = true);
    try {
      final activities = await _activityService.fetchRecentActivities(
        limit: 100,
        type: _selectedType,
      );
      setState(() {
        _activities = activities;
        _isLoading = false;
      });
    } catch (e) {
      Log.e('Error loading activities', 'REALTIME_ACTIVITY', e);
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load activities: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  List<Map<String, dynamic>> get _filteredActivities {
    var filtered = _activities;
    
    // Filter by type
    if (_selectedType != null && _selectedType!.isNotEmpty) {
      filtered = filtered.where((a) => a['type'] == _selectedType).toList();
    }
    
    // Filter by search query
    if (_searchQuery.isNotEmpty) {
      final query = _searchQuery.toLowerCase();
      filtered = filtered.where((a) {
        final description = (a['description'] ?? '').toString().toLowerCase();
        final action = (a['action'] ?? '').toString().toLowerCase();
        final userName = (a['userName'] ?? a['adminName'] ?? '').toString().toLowerCase();
        return description.contains(query) || 
               action.contains(query) || 
               userName.contains(query);
      }).toList();
    }
    
    return filtered;
  }

  @override
  void dispose() {
    _activityService.unsubscribe(_onActivityReceived);
    _scrollController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = ResponsiveUtils.isMobile(context);
    final padding = ResponsiveUtils.getResponsivePadding(context);
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Real-Time Activity Feed'),
        actions: [
          // Connection status indicator
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _isConnected ? Colors.green : Colors.red,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  _isConnected ? 'Live' : 'Offline',
                  style: TextStyle(
                    fontSize: ResponsiveUtils.getResponsiveFontSize(context, baseSize: 12),
                    color: _isConnected ? Colors.green : Colors.red,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadActivities,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: Column(
        children: [
          // Filters and search
          _buildFilters(padding, isMobile),
          
          // Activity list
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredActivities.isEmpty
                    ? _buildEmptyState()
                    : _buildActivityList(padding, isMobile),
          ),
        ],
      ),
    );
  }

  Widget _buildFilters(EdgeInsets padding, bool isMobile) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: _themeService.isDarkMode ? Colors.grey[900] : Colors.grey[100],
        border: Border(
          bottom: BorderSide(
            color: _themeService.isDarkMode ? Colors.grey[800]! : Colors.grey[300]!,
          ),
        ),
      ),
      child: isMobile
          ? Column(
              children: [
                _buildSearchBar(),
                SizedBox(height: ResponsiveUtils.getResponsiveSpacing(context)),
                _buildTypeFilter(),
              ],
            )
          : Row(
              children: [
                Expanded(child: _buildSearchBar()),
                SizedBox(width: ResponsiveUtils.getResponsiveSpacing(context)),
                _buildTypeFilter(),
              ],
            ),
    );
  }

  Widget _buildSearchBar() {
    return TextField(
      decoration: InputDecoration(
        hintText: 'Search activities...',
        prefixIcon: const Icon(Icons.search),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        filled: true,
        fillColor: _themeService.isDarkMode ? Colors.grey[800] : Colors.white,
        contentPadding: EdgeInsets.symmetric(
          horizontal: ResponsiveUtils.getResponsiveSpacing(context),
          vertical: ResponsiveUtils.getResponsiveValue(
            context,
            mobile: 12.0,
            tablet: 14.0,
            desktop: 16.0,
          ),
        ),
      ),
      onChanged: (value) {
        setState(() => _searchQuery = value);
      },
    );
  }

  Widget _buildTypeFilter() {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: ResponsiveUtils.getResponsiveSpacing(context) * 0.5,
      ),
      decoration: BoxDecoration(
        color: _themeService.isDarkMode ? Colors.grey[800] : Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: _themeService.isDarkMode ? Colors.grey[700]! : Colors.grey[300]!,
        ),
      ),
      child: DropdownButton<String>(
        value: _selectedType,
        hint: const Text('All Types'),
        underline: const SizedBox(),
        items: const [
          DropdownMenuItem(value: null, child: Text('All Types')),
          DropdownMenuItem(value: 'user', child: Text('User')),
          DropdownMenuItem(value: 'admin', child: Text('Admin')),
          DropdownMenuItem(value: 'system', child: Text('System')),
        ],
        onChanged: (value) {
          setState(() => _selectedType = value);
        },
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.history,
            size: ResponsiveUtils.getResponsiveValue(
              context,
              mobile: 48.0,
              tablet: 56.0,
              desktop: 64.0,
            ),
            color: Colors.grey,
          ),
          SizedBox(height: ResponsiveUtils.getResponsiveSpacing(context)),
          Text(
            'No activities found',
            style: ResponsiveUtils.getResponsiveBodyStyle(context),
          ),
        ],
      ),
    );
  }

  Widget _buildActivityList(EdgeInsets padding, bool isMobile) {
    final filtered = _filteredActivities;
    
    return ListView.builder(
      controller: _scrollController,
      padding: padding,
      itemCount: filtered.length,
      itemBuilder: (context, index) {
        final activity = filtered[index];
        return _buildActivityItem(activity, isMobile);
      },
    );
  }

  Widget _buildActivityItem(Map<String, dynamic> activity, bool isMobile) {
    final type = activity['type'] ?? 'unknown';
    final action = activity['action'] ?? 'unknown';
    final description = activity['description'] ?? 'No description';
    final timestamp = activity['timestamp'] ?? activity['createdAt'];
    
    // Get icon and color based on type
    IconData icon;
    Color color;
    switch (type) {
      case 'user':
        icon = Icons.person;
        color = Colors.blue;
        break;
      case 'admin':
        icon = Icons.admin_panel_settings;
        color = Colors.orange;
        break;
      case 'system':
        icon = Icons.settings;
        color = Colors.green;
        break;
      default:
        icon = Icons.info;
        color = Colors.grey;
    }

    // Format timestamp
    String timeText = 'Just now';
    if (timestamp != null) {
      try {
        final dateTime = timestamp is String 
            ? DateTime.parse(timestamp) 
            : timestamp as DateTime;
        final now = DateTime.now();
        final difference = now.difference(dateTime);
        
        if (difference.inSeconds < 60) {
          timeText = '${difference.inSeconds}s ago';
        } else if (difference.inMinutes < 60) {
          timeText = '${difference.inMinutes}m ago';
        } else if (difference.inHours < 24) {
          timeText = '${difference.inHours}h ago';
        } else {
          timeText = DateFormat('MMM d, yyyy HH:mm').format(dateTime);
        }
      } catch (e) {
        timeText = 'Unknown time';
      }
    }

    return Card(
      margin: EdgeInsets.only(
        bottom: ResponsiveUtils.getResponsiveSpacing(context) * 0.5,
      ),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: color.withOpacity(0.1),
          child: Icon(icon, color: color, size: ResponsiveUtils.getResponsiveIconSize(context)),
        ),
        title: Text(
          description,
          style: ResponsiveUtils.getResponsiveBodyStyle(context),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Padding(
          padding: EdgeInsets.only(
            top: ResponsiveUtils.getResponsiveSpacing(context) * 0.25,
          ),
          child: Row(
            children: [
              Text(
                action,
                style: ResponsiveUtils.getResponsiveCaptionStyle(
                  context,
                  color: Colors.grey[600],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '•',
                style: TextStyle(color: Colors.grey[400]),
              ),
              const SizedBox(width: 8),
              Text(
                timeText,
                style: ResponsiveUtils.getResponsiveCaptionStyle(
                  context,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
        ),
        isThreeLine: false,
        dense: isMobile,
      ),
    );
  }
}

