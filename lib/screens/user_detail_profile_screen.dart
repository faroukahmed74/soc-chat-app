// =============================================================================
// USER DETAIL PROFILE SCREEN
// =============================================================================
// This screen provides a comprehensive view of a user's profile with tabs for:
// - Profile information
// - Activity timeline
// - Messages
// - Chats
// - Devices
// - Violations

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/mongodb_admin_service.dart';
import '../services/theme_service.dart';
import '../services/logger_service.dart';
import '../utils/responsive_utils.dart';

class UserDetailProfileScreen extends StatefulWidget {
  final String userId;
  
  const UserDetailProfileScreen({
    Key? key,
    required this.userId,
  }) : super(key: key);

  @override
  State<UserDetailProfileScreen> createState() => _UserDetailProfileScreenState();
}

class _UserDetailProfileScreenState extends State<UserDetailProfileScreen> with SingleTickerProviderStateMixin {
  final MongoDBAdminService _adminService = MongoDBAdminService();
  final ThemeService _themeService = ThemeService();
  late TabController _tabController;
  
  Map<String, dynamic>? _userData;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 6, vsync: this);
    _loadUserDetails();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadUserDetails() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final data = await _adminService.getUserDetails(widget.userId);
      setState(() {
        _userData = data;
        _isLoading = false;
      });
    } catch (e) {
      Log.e('Error loading user details', 'USER_DETAIL_PROFILE', e);
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = ResponsiveUtils.isMobile(context);
    
    return Scaffold(
      appBar: AppBar(
        title: Text(_userData?['displayName'] ?? 'User Details'),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: isMobile,
          tabs: [
            if (isMobile)
              const Tab(icon: Icon(Icons.person))
            else
              const Tab(icon: Icon(Icons.person), text: 'Profile'),
            if (isMobile)
              const Tab(icon: Icon(Icons.history))
            else
              const Tab(icon: Icon(Icons.history), text: 'Activity'),
            if (isMobile)
              const Tab(icon: Icon(Icons.message))
            else
              const Tab(icon: Icon(Icons.message), text: 'Messages'),
            if (isMobile)
              const Tab(icon: Icon(Icons.chat))
            else
              const Tab(icon: Icon(Icons.chat), text: 'Chats'),
            if (isMobile)
              const Tab(icon: Icon(Icons.devices))
            else
              const Tab(icon: Icon(Icons.devices), text: 'Devices'),
            if (isMobile)
              const Tab(icon: Icon(Icons.warning))
            else
              const Tab(icon: Icon(Icons.warning), text: 'Violations'),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadUserDetails,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.error_outline,
                        size: ResponsiveUtils.getResponsiveValue(
                          context,
                          mobile: 48.0,
                          tablet: 56.0,
                          desktop: 64.0,
                        ),
                        color: Colors.red,
                      ),
                      SizedBox(height: ResponsiveUtils.getResponsiveSpacing(context)),
                      Text(
                        'Error loading user details',
                        style: ResponsiveUtils.getResponsiveBodyStyle(context),
                      ),
                      SizedBox(height: ResponsiveUtils.getResponsiveSpacing(context) * 0.5),
                      Text(
                        _error!,
                        style: ResponsiveUtils.getResponsiveCaptionStyle(context),
                        textAlign: TextAlign.center,
                      ),
                      SizedBox(height: ResponsiveUtils.getResponsiveSpacing(context)),
                      ElevatedButton(
                        onPressed: _loadUserDetails,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : _userData == null
                  ? const Center(child: Text('No user data available'))
                  : TabBarView(
                      controller: _tabController,
                      children: [
                        _buildProfileTab(),
                        _buildActivityTab(),
                        _buildMessagesTab(),
                        _buildChatsTab(),
                        _buildDevicesTab(),
                        _buildViolationsTab(),
                      ],
                    ),
    );
  }

  Widget _buildProfileTab() {
    final padding = ResponsiveUtils.getResponsivePadding(context);
    final isMobile = ResponsiveUtils.isMobile(context);
    final insights = _userData!['insights'] as Map<String, dynamic>? ?? {};
    final stats = _userData!['stats'] as Map<String, dynamic>? ?? {};
    
    return SingleChildScrollView(
      padding: padding,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final maxWidth = ResponsiveUtils.getResponsiveValue(
            context,
            mobile: double.infinity,
            tablet: 800.0,
            desktop: 1000.0,
          );
          
          return Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: maxWidth),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // User Header
                  _buildUserHeader(),
                  SizedBox(height: ResponsiveUtils.getResponsiveSpacing(context) * 2),
                  
                  // Insights Cards
                  _buildInsightsSection(insights, isMobile),
                  SizedBox(height: ResponsiveUtils.getResponsiveSpacing(context) * 2),
                  
                  // Statistics
                  _buildStatisticsSection(stats, isMobile),
                  SizedBox(height: ResponsiveUtils.getResponsiveSpacing(context) * 2),
                  
                  // User Information
                  _buildUserInfoSection(),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildUserHeader() {
    return Card(
      child: Padding(
        padding: ResponsiveUtils.getResponsivePadding(context),
        child: Row(
          children: [
            CircleAvatar(
              radius: ResponsiveUtils.getResponsiveAvatarRadius(context),
              backgroundColor: Colors.blue,
              child: Text(
                (_userData!['displayName'] ?? 'U')[0].toUpperCase(),
                style: TextStyle(
                  fontSize: ResponsiveUtils.getResponsiveFontSize(context, baseSize: 24),
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
            SizedBox(width: ResponsiveUtils.getResponsiveSpacing(context)),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _userData!['displayName'] ?? 'Unknown',
                    style: ResponsiveUtils.getResponsiveHeadingStyle(context),
                  ),
                  SizedBox(height: ResponsiveUtils.getResponsiveSpacing(context) * 0.25),
                  Text(
                    _userData!['email'] ?? '',
                    style: ResponsiveUtils.getResponsiveBodyStyle(
                      context,
                      color: Colors.grey[600],
                    ),
                  ),
                  SizedBox(height: ResponsiveUtils.getResponsiveSpacing(context) * 0.25),
                  Row(
                    children: [
                      _buildStatusChip(_userData!['status'] ?? 'offline'),
                      SizedBox(width: ResponsiveUtils.getResponsiveSpacing(context) * 0.5),
                      _buildRoleChip(_userData!['role'] ?? 'user'),
                      if (_userData!['isLocked'] == true) ...[
                        SizedBox(width: ResponsiveUtils.getResponsiveSpacing(context) * 0.5),
                        Chip(
                          label: const Text('Locked'),
                          backgroundColor: Colors.red[100],
                          labelStyle: const TextStyle(color: Colors.red),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusChip(String status) {
    Color color;
    switch (status.toLowerCase()) {
      case 'online':
        color = Colors.green;
        break;
      case 'offline':
        color = Colors.grey;
        break;
      default:
        color = Colors.orange;
    }
    
    return Chip(
      label: Text(status.toUpperCase()),
      backgroundColor: color.withOpacity(0.1),
      labelStyle: TextStyle(color: color, fontSize: ResponsiveUtils.getResponsiveFontSize(context, baseSize: 10)),
    );
  }

  Widget _buildRoleChip(String role) {
    return Chip(
      label: Text(role.toUpperCase()),
      backgroundColor: role == 'admin' ? Colors.purple[100] : Colors.blue[100],
      labelStyle: TextStyle(
        color: role == 'admin' ? Colors.purple : Colors.blue,
        fontSize: ResponsiveUtils.getResponsiveFontSize(context, baseSize: 10),
      ),
    );
  }

  Widget _buildInsightsSection(Map<String, dynamic> insights, bool isMobile) {
    final riskScore = insights['riskScore'] ?? 0;
    final riskLevel = insights['riskLevel'] ?? 'low';
    final activityScore = insights['activityScore'] ?? 0;
    final engagementLevel = insights['engagementLevel'] ?? 'low';
    
    return Card(
      child: Padding(
        padding: ResponsiveUtils.getResponsivePadding(context),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'User Insights',
              style: ResponsiveUtils.getResponsiveHeadingStyle(context),
            ),
            SizedBox(height: ResponsiveUtils.getResponsiveSpacing(context)),
            if (isMobile) ...[
              _buildInsightCard('Risk Score', riskScore, riskLevel, Colors.red),
              SizedBox(height: ResponsiveUtils.getResponsiveSpacing(context)),
              _buildInsightCard('Activity Score', activityScore, engagementLevel, Colors.blue),
            ] else ...[
              Row(
                children: [
                  Expanded(child: _buildInsightCard('Risk Score', riskScore, riskLevel, Colors.red)),
                  SizedBox(width: ResponsiveUtils.getResponsiveSpacing(context)),
                  Expanded(child: _buildInsightCard('Activity Score', activityScore, engagementLevel, Colors.blue)),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildInsightCard(String title, int score, String level, Color color) {
    return Container(
      padding: EdgeInsets.all(ResponsiveUtils.getResponsiveSpacing(context)),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: ResponsiveUtils.getResponsiveCaptionStyle(context),
          ),
          SizedBox(height: ResponsiveUtils.getResponsiveSpacing(context) * 0.5),
          Text(
            '$score',
            style: TextStyle(
              fontSize: ResponsiveUtils.getResponsiveFontSize(context, baseSize: 32),
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            level.toUpperCase(),
            style: ResponsiveUtils.getResponsiveCaptionStyle(
              context,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatisticsSection(Map<String, dynamic> stats, bool isMobile) {
    return Card(
      child: Padding(
        padding: ResponsiveUtils.getResponsivePadding(context),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Statistics',
              style: ResponsiveUtils.getResponsiveHeadingStyle(context),
            ),
            SizedBox(height: ResponsiveUtils.getResponsiveSpacing(context)),
            Wrap(
              spacing: ResponsiveUtils.getResponsiveSpacing(context),
              runSpacing: ResponsiveUtils.getResponsiveSpacing(context),
              children: [
                _buildStatCard('Messages', '${stats['messageCount'] ?? 0}', Icons.message),
                _buildStatCard('Chats', '${stats['chatCount'] ?? 0}', Icons.chat),
                _buildStatCard('Devices', '${stats['deviceCount'] ?? 0}', Icons.devices),
                _buildStatCard('Account Age', '${stats['accountAgeDays'] ?? 0} days', Icons.calendar_today),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon) {
    return Container(
      padding: EdgeInsets.all(ResponsiveUtils.getResponsiveSpacing(context)),
      decoration: BoxDecoration(
        color: _themeService.isDarkMode ? Colors.grey[800] : Colors.grey[100],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Icon(icon, size: ResponsiveUtils.getResponsiveIconSize(context)),
          SizedBox(height: ResponsiveUtils.getResponsiveSpacing(context) * 0.5),
          Text(
            value,
            style: ResponsiveUtils.getResponsiveBodyStyle(
              context,
              weight: FontWeight.bold,
            ),
          ),
          Text(
            label,
            style: ResponsiveUtils.getResponsiveCaptionStyle(context),
          ),
        ],
      ),
    );
  }

  Widget _buildUserInfoSection() {
    return Card(
      child: Padding(
        padding: ResponsiveUtils.getResponsivePadding(context),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'User Information',
              style: ResponsiveUtils.getResponsiveHeadingStyle(context),
            ),
            SizedBox(height: ResponsiveUtils.getResponsiveSpacing(context)),
            _buildInfoRow('Email', _userData!['email'] ?? 'N/A'),
            _buildInfoRow('Phone', _userData!['phoneNumber'] ?? 'N/A'),
            _buildInfoRow('Created', _formatDate(_userData!['createdAt'])),
            _buildInfoRow('Last Login', _formatDate(_userData!['lastLoginAt'])),
            _buildInfoRow('Last Activity', _formatDate(_userData!['lastActivity'])),
            if (_userData!['isLocked'] == true) ...[
              _buildInfoRow('Locked At', _formatDate(_userData!['lockedAt'])),
              _buildInfoRow('Lock Reason', _userData!['lockedReason'] ?? 'N/A'),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: ResponsiveUtils.getResponsiveSpacing(context) * 0.5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: ResponsiveUtils.getResponsiveBodyStyle(
                context,
                color: Colors.grey[600],
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: ResponsiveUtils.getResponsiveBodyStyle(context),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(dynamic date) {
    if (date == null) return 'Never';
    try {
      final dateTime = date is String ? DateTime.parse(date) : date as DateTime;
      return DateFormat('MMM d, yyyy HH:mm').format(dateTime);
    } catch (e) {
      return date.toString();
    }
  }

  Widget _buildActivityTab() {
    final activities = _userData!['recentActivity'] as List<dynamic>? ?? [];
    
    if (activities.isEmpty) {
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
              'No activity found',
              style: ResponsiveUtils.getResponsiveBodyStyle(context),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: ResponsiveUtils.getResponsivePadding(context),
      itemCount: activities.length,
      itemBuilder: (context, index) {
        final activity = activities[index] as Map<String, dynamic>;
        return Card(
          margin: EdgeInsets.only(
            bottom: ResponsiveUtils.getResponsiveSpacing(context) * 0.5,
          ),
          child: ListTile(
            leading: Icon(
              Icons.history,
              color: Colors.blue,
              size: ResponsiveUtils.getResponsiveIconSize(context),
            ),
            title: Text(
              activity['action'] ?? 'Unknown action',
              style: ResponsiveUtils.getResponsiveBodyStyle(context),
            ),
            subtitle: Text(
              _formatDate(activity['timestamp']),
              style: ResponsiveUtils.getResponsiveCaptionStyle(context),
            ),
          ),
        );
      },
    );
  }

  Widget _buildMessagesTab() {
    final messages = _userData!['recentMessages'] as List<dynamic>? ?? [];
    
    if (messages.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.message,
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
              'No messages found',
              style: ResponsiveUtils.getResponsiveBodyStyle(context),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: ResponsiveUtils.getResponsivePadding(context),
      itemCount: messages.length,
      itemBuilder: (context, index) {
        final message = messages[index] as Map<String, dynamic>;
        return Card(
          margin: EdgeInsets.only(
            bottom: ResponsiveUtils.getResponsiveSpacing(context) * 0.5,
          ),
          child: ListTile(
            leading: Icon(
              Icons.message,
              color: Colors.blue,
              size: ResponsiveUtils.getResponsiveIconSize(context),
            ),
            title: Text(
              message['content'] ?? 'No content',
              style: ResponsiveUtils.getResponsiveBodyStyle(context),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: Text(
              _formatDate(message['createdAt']),
              style: ResponsiveUtils.getResponsiveCaptionStyle(context),
            ),
          ),
        );
      },
    );
  }

  Widget _buildChatsTab() {
    final chats = _userData!['chats'] as List<dynamic>? ?? [];
    
    if (chats.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.chat,
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
              'No chats found',
              style: ResponsiveUtils.getResponsiveBodyStyle(context),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: ResponsiveUtils.getResponsivePadding(context),
      itemCount: chats.length,
      itemBuilder: (context, index) {
        final chat = chats[index] as Map<String, dynamic>;
        return Card(
          margin: EdgeInsets.only(
            bottom: ResponsiveUtils.getResponsiveSpacing(context) * 0.5,
          ),
          child: ListTile(
            leading: Icon(
              Icons.chat,
              color: Colors.purple,
              size: ResponsiveUtils.getResponsiveIconSize(context),
            ),
            title: Text(
              chat['name'] ?? 'Chat',
              style: ResponsiveUtils.getResponsiveBodyStyle(context),
            ),
            subtitle: Text(
              '${chat['memberCount'] ?? 0} members • ${_formatDate(chat['updatedAt'])}',
              style: ResponsiveUtils.getResponsiveCaptionStyle(context),
            ),
          ),
        );
      },
    );
  }

  Widget _buildDevicesTab() {
    final devices = _userData!['devices'] as List<dynamic>? ?? [];
    
    if (devices.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.devices,
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
              'No devices found',
              style: ResponsiveUtils.getResponsiveBodyStyle(context),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: ResponsiveUtils.getResponsivePadding(context),
      itemCount: devices.length,
      itemBuilder: (context, index) {
        final device = devices[index] as Map<String, dynamic>;
        return Card(
          margin: EdgeInsets.only(
            bottom: ResponsiveUtils.getResponsiveSpacing(context) * 0.5,
          ),
          child: ListTile(
            leading: Icon(
              _getDeviceIcon(device['platform'] ?? ''),
              color: Colors.orange,
              size: ResponsiveUtils.getResponsiveIconSize(context),
            ),
            title: Text(
              '${device['deviceModel'] ?? 'Unknown'} (${device['platform'] ?? 'Unknown'})',
              style: ResponsiveUtils.getResponsiveBodyStyle(context),
            ),
            subtitle: Text(
              '${device['deviceType'] ?? 'Unknown'} • Last seen: ${_formatDate(device['lastSeen'])}',
              style: ResponsiveUtils.getResponsiveCaptionStyle(context),
            ),
            trailing: device['fcmEnabled'] == true
                ? Icon(Icons.notifications_active, color: Colors.green)
                : null,
          ),
        );
      },
    );
  }

  IconData _getDeviceIcon(String platform) {
    switch (platform.toLowerCase()) {
      case 'android':
        return Icons.android;
      case 'ios':
        return Icons.phone_iphone;
      case 'web':
        return Icons.web;
      default:
        return Icons.devices;
    }
  }

  Widget _buildViolationsTab() {
    final violations = _userData!['violations'] as List<dynamic>? ?? [];
    
    if (violations.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.check_circle,
              size: ResponsiveUtils.getResponsiveValue(
                context,
                mobile: 48.0,
                tablet: 56.0,
                desktop: 64.0,
              ),
              color: Colors.green,
            ),
            SizedBox(height: ResponsiveUtils.getResponsiveSpacing(context)),
            Text(
              'No violations found',
              style: ResponsiveUtils.getResponsiveBodyStyle(context),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: ResponsiveUtils.getResponsivePadding(context),
      itemCount: violations.length,
      itemBuilder: (context, index) {
        final violation = violations[index] as Map<String, dynamic>;
        return Card(
          margin: EdgeInsets.only(
            bottom: ResponsiveUtils.getResponsiveSpacing(context) * 0.5,
          ),
          color: Colors.red[50],
          child: ListTile(
            leading: Icon(
              Icons.warning,
              color: Colors.red,
              size: ResponsiveUtils.getResponsiveIconSize(context),
            ),
            title: Text(
              violation['type'] ?? 'Unknown violation',
              style: ResponsiveUtils.getResponsiveBodyStyle(
                context,
                weight: FontWeight.bold,
              ),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  violation['reason'] ?? 'No reason provided',
                  style: ResponsiveUtils.getResponsiveBodyStyle(context),
                ),
                SizedBox(height: ResponsiveUtils.getResponsiveSpacing(context) * 0.25),
                Text(
                  'Action: ${violation['action'] ?? 'N/A'} • ${_formatDate(violation['createdAt'])}',
                  style: ResponsiveUtils.getResponsiveCaptionStyle(context),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

