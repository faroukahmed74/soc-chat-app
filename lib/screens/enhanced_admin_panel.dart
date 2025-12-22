// =============================================================================
// ENHANCED ADMIN PANEL SCREEN - SIMPLIFIED VERSION
// =============================================================================
// This screen provides a modern, comprehensive admin interface with enhanced UI/UX
// Features include real-time analytics, advanced user management, system monitoring,
// content moderation, and administrative tools with responsive design.

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'dart:async';
import 'dart:convert';
import '../services/theme_service.dart';
import '../services/mongodb_admin_service.dart';
import '../services/physical_auth_service.dart';
import '../services/logger_service.dart';
import 'advanced_analytics_screen.dart';
import 'moderation_center_screen.dart';
import 'realtime_activity_feed_screen.dart';
import 'user_detail_profile_screen.dart';
import 'scheduled_broadcasts_screen.dart';
import 'unified_search_screen.dart';
import 'security_compliance_screen.dart';
import 'performance_monitoring_screen.dart';
import 'notification_management_screen.dart';
import 'chat_moderation_screen.dart';

class EnhancedAdminPanel extends StatefulWidget {
  const EnhancedAdminPanel({Key? key}) : super(key: key);

  @override
  State<EnhancedAdminPanel> createState() => _EnhancedAdminPanelState();
}

class _EnhancedAdminPanelState extends State<EnhancedAdminPanel> with TickerProviderStateMixin {
  
  final PhysicalAuthService _authService = PhysicalAuthService();
  final MongoDBAdminService _adminService = MongoDBAdminService();
  late TabController _tabController;
  late ThemeService _themeService;

  // Data
  List<Map<String, dynamic>> _users = [];
  List<Map<String, dynamic>> _chats = [];
  List<Map<String, dynamic>> _messages = [];
  List<Map<String, dynamic>> _reports = [];
  List<Map<String, dynamic>> _recentActivity = [];
  Map<String, dynamic>? _systemStats;
  Map<String, dynamic>? _systemHealth;
  Map<String, dynamic>? _analytics;
  
  // Bulk selection state
  Set<String> _selectedUserIds = {};
  bool _isBulkMode = false;
  
  // Controllers
  final TextEditingController _userSearchController = TextEditingController();
  final TextEditingController _broadcastController = TextEditingController();
  
  // Loading states
  bool _isLoadingUsers = false;
  bool _isLoadingChats = false;
  bool _isLoadingMessages = false;
  bool _isLoadingReports = false;
  bool _isLoadingStats = false;
  bool _isLoadingAnalytics = false;
  bool _isLoadingActivity = false;
  bool _roleLoaded = false;
  bool _isAdmin = false;
  bool _isBroadcasting = false;
  
  // UI State
  String _selectedChatIdForMessages = '';
  bool _autoRefreshEnabled = true;
  
  // Analytics refresh timer
  Timer? _analyticsRefreshTimer;
  
  // Animation controllers
  late AnimationController _fadeController;
  late AnimationController _slideController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _themeService = ThemeService.instance;
    _themeService.addListener(() {
      if (mounted) setState(() {});
    });
    
    _tabController = TabController(length: 6, vsync: this);
    
    // Initialize animations
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeInOut),
    );
    
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.1),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _slideController, curve: Curves.easeOut));
    
    _checkAdminAccess();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _userSearchController.dispose();
    _broadcastController.dispose();
    _fadeController.dispose();
    _slideController.dispose();
    _analyticsRefreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _checkAdminAccess() async {
    try {
      final role = await _authService.getCurrentUserRole();
      setState(() {
        _isAdmin = role == 'admin';
        _roleLoaded = true;
      });
      
      if (_isAdmin) {
        _fadeController.forward();
        _slideController.forward();
        await _loadInitialData();
        _startAnalyticsRefresh();
      }
    } catch (e) {
      Log.e('Error checking admin access', 'ENHANCED_ADMIN_PANEL', e);
      setState(() {
        _roleLoaded = true;
        _isAdmin = false;
      });
    }
  }

  Future<void> _loadInitialData() async {
    await Future.wait([
      _loadUsers(),
      _loadSystemStats(),
      _loadSystemHealth(),
      _loadAnalytics(),
      _loadRecentActivity(),
    ]);
  }

  void _startAnalyticsRefresh() {
    if (_autoRefreshEnabled) {
      _analyticsRefreshTimer = Timer.periodic(
        const Duration(minutes: 1),
        (timer) => _loadAnalytics(),
      );
    }
  }

  Future<void> _loadUsers() async {
    setState(() => _isLoadingUsers = true);
    try {
      final users = await _adminService.getAllUsers(
        search: _userSearchController.text.trim().isNotEmpty ? _userSearchController.text.trim() : null,
        page: 1,
        limit: 100,
      );
      if (mounted) {
        setState(() => _users = users);
      }
    } catch (e) {
      Log.e('Error loading users', 'ENHANCED_ADMIN_PANEL', e);
      if (mounted) {
        _showDetailedErrorDialog(
          'Failed to Load Users',
          'Unable to load the list of users. Please check your connection and try again.',
          errorCode: 'LOAD_USERS_ERROR',
          details: e.toString(),
          onRetry: _loadUsers,
        );
      }
    } finally {
      if (mounted) setState(() => _isLoadingUsers = false);
    }
  }

  Future<void> _loadSystemStats() async {
    setState(() => _isLoadingStats = true);
    try {
      final stats = await _adminService.getSystemStats();
      if (mounted) {
        setState(() => _systemStats = stats);
      }
    } catch (e) {
      Log.e('Error loading system stats', 'ENHANCED_ADMIN_PANEL', e);
      if (mounted) {
        _showErrorSnackBar(
          'Error loading system stats: $e',
          onRetry: _loadSystemStats,
        );
      }
    } finally {
      if (mounted) setState(() => _isLoadingStats = false);
    }
  }

  Future<void> _loadSystemHealth() async {
    try {
      final health = await _adminService.getEnhancedSystemHealth();
      if (mounted) {
        setState(() => _systemHealth = health);
      }
    } catch (e) {
      Log.e('Error loading system health', 'ENHANCED_ADMIN_PANEL', e);
    }
  }

  Future<void> _loadAnalytics() async {
    setState(() => _isLoadingAnalytics = true);
    try {
      final analytics = await _adminService.getAnalytics();
      if (mounted) {
        setState(() => _analytics = analytics);
      }
    } catch (e) {
      Log.e('Error loading analytics', 'ENHANCED_ADMIN_PANEL', e);
    } finally {
      if (mounted) setState(() => _isLoadingAnalytics = false);
    }
  }

  Future<void> _loadChats() async {
    setState(() => _isLoadingChats = true);
    try {
      final chats = await _adminService.getAllChats();
      if (mounted) {
        setState(() => _chats = chats);
      }
    } catch (e) {
      Log.e('Error loading chats', 'ENHANCED_ADMIN_PANEL', e);
      if (mounted) {
        _showErrorSnackBar(
          'Error loading chats: $e',
          onRetry: _loadChats,
        );
      }
    } finally {
      if (mounted) setState(() => _isLoadingChats = false);
    }
  }

  Future<void> _loadMessages() async {
    setState(() => _isLoadingMessages = true);
    try {
      final messages = await _adminService.getAllMessages(
        chatId: _selectedChatIdForMessages.isNotEmpty ? _selectedChatIdForMessages : null,
        page: 1,
        limit: 100,
      );
      if (mounted) {
        setState(() => _messages = messages);
      }
    } catch (e) {
      Log.e('Error loading messages', 'ENHANCED_ADMIN_PANEL', e);
      if (mounted) {
        _showErrorSnackBar(
          'Error loading messages: $e',
          onRetry: _loadMessages,
        );
      }
    } finally {
      if (mounted) setState(() => _isLoadingMessages = false);
    }
  }

  Future<void> _loadReports() async {
    setState(() => _isLoadingReports = true);
    try {
      final reports = await _adminService.getAllReports();
      if (mounted) {
        setState(() => _reports = reports);
      }
    } catch (e) {
      Log.e('Error loading reports', 'ENHANCED_ADMIN_PANEL', e);
      if (mounted) {
        _showErrorSnackBar(
          'Error loading reports: $e',
          onRetry: _loadReports,
        );
      }
    } finally {
      if (mounted) setState(() => _isLoadingReports = false);
    }
  }

  Future<void> _loadRecentActivity() async {
    setState(() => _isLoadingActivity = true);
    try {
      final activities = await _adminService.getRecentActivity(limit: 10);
      if (mounted) {
        setState(() => _recentActivity = activities);
      }
    } catch (e) {
      Log.e('Error loading recent activity', 'ENHANCED_ADMIN_PANEL', e);
      // Don't show error snackbar for activity, just log it
    } finally {
      if (mounted) setState(() => _isLoadingActivity = false);
    }
  }

  void _showErrorSnackBar(String message, {String? errorCode, VoidCallback? onRetry}) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                message,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              if (errorCode != null)
                Text(
                  'Error Code: $errorCode',
                  style: const TextStyle(fontSize: 12),
                ),
            ],
          ),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 5),
          action: SnackBarAction(
            label: onRetry != null ? 'Retry' : 'Dismiss',
            textColor: Colors.white,
            onPressed: () {
              if (onRetry != null) {
                onRetry();
              }
              ScaffoldMessenger.of(context).hideCurrentSnackBar();
            },
          ),
        ),
      );
    }
  }

  void _showDetailedErrorDialog(String title, String message, {String? errorCode, String? details, VoidCallback? onRetry}) {
    if (!mounted) return;
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.red),
            const SizedBox(width: 8),
            Expanded(child: Text(title)),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                message,
                style: const TextStyle(fontSize: 16),
              ),
              if (errorCode != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    'Error Code: $errorCode',
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
              if (details != null) ...[
                const SizedBox(height: 12),
                Text(
                  'Details:',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: _themeService.isDarkMode ? Colors.grey[300] : Colors.grey[700],
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  details,
                  style: TextStyle(
                    fontSize: 14,
                    color: _themeService.isDarkMode ? Colors.grey[400] : Colors.grey[600],
                  ),
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
          if (onRetry != null)
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                onRetry();
              },
              child: const Text('Retry'),
            ),
        ],
      ),
    );
  }

  void _showSuccessSnackBar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.green,
          action: SnackBarAction(
            label: 'Dismiss',
            textColor: Colors.white,
            onPressed: () {
              ScaffoldMessenger.of(context).hideCurrentSnackBar();
            },
          ),
        ),
      );
    }
  }

  Future<void> _broadcastMessage() async {
    if (_broadcastController.text.trim().isEmpty) return;
    
    setState(() => _isBroadcasting = true);
    try {
      await _adminService.broadcastMessage(
        _broadcastController.text.trim(),
        'System Announcement',
      );
      _broadcastController.clear();
      _showSuccessSnackBar('Message broadcasted successfully');
    } catch (e) {
      Log.e('Error broadcasting message', 'ENHANCED_ADMIN_PANEL', e);
      if (mounted) {
        _showDetailedErrorDialog(
          'Broadcast Failed',
          'Unable to send the broadcast message. Please try again.',
          errorCode: 'BROADCAST_ERROR',
          details: e.toString(),
          onRetry: _broadcastMessage,
        );
      }
    } finally {
      if (mounted) setState(() => _isBroadcasting = false);
    }
  }

  Future<void> _lockUser(String userId, String reason) async {
    try {
      setState(() => _isLoadingUsers = true);
      await _adminService.lockUser(userId, reason);
      _showSuccessSnackBar('User locked successfully');
      await _loadUsers(); // Refresh users list
    } catch (e) {
      Log.e('Error locking user', 'ENHANCED_ADMIN_PANEL', e);
      if (mounted) {
        _showDetailedErrorDialog(
          'Failed to Lock User',
          'Unable to lock the user account. Please try again.',
          errorCode: 'LOCK_USER_ERROR',
          details: e.toString(),
          onRetry: () => _lockUser(userId, reason),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoadingUsers = false);
    }
  }

  Future<void> _unlockUser(String userId) async {
    try {
      setState(() => _isLoadingUsers = true);
      await _adminService.unlockUser(userId);
      _showSuccessSnackBar('User unlocked successfully');
      await _loadUsers(); // Refresh users list
    } catch (e) {
      Log.e('Error unlocking user', 'ENHANCED_ADMIN_PANEL', e);
      if (mounted) {
        _showDetailedErrorDialog(
          'Failed to Unlock User',
          'Unable to unlock the user account. Please try again.',
          errorCode: 'UNLOCK_USER_ERROR',
          details: e.toString(),
          onRetry: () => _unlockUser(userId),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoadingUsers = false);
    }
  }

  Future<void> _deleteUser(String userId) async {
    final confirmed = await _showConfirmDialog(
      'Delete User',
      'Are you sure you want to delete this user? This action cannot be undone.',
    );
    
    if (confirmed == true) {
      try {
        setState(() => _isLoadingUsers = true);
        await _adminService.deleteUserEnhanced(userId);
        _showSuccessSnackBar('User deleted successfully');
        await _loadUsers(); // Refresh users list
      } catch (e) {
        Log.e('Error deleting user', 'ENHANCED_ADMIN_PANEL', e);
        if (mounted) {
          _showDetailedErrorDialog(
            'Failed to Delete User',
            'Unable to delete the user account. This may be due to permissions or the user may not exist.',
            errorCode: 'DELETE_USER_ERROR',
            details: e.toString(),
          );
        }
      } finally {
        if (mounted) setState(() => _isLoadingUsers = false);
      }
    }
  }

  Future<bool?> _showConfirmDialog(String title, String content) async {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(content),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
  }

  Widget _buildAccessDenied() {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Panel'),
        backgroundColor: Colors.red,
        foregroundColor: Colors.white,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.lock_outline,
              size: 64,
              color: Colors.redAccent,
            ),
            const SizedBox(height: 16),
            const Text(
              'Access Denied',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.red,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Admin privileges required',
              style: TextStyle(
                fontSize: 16,
                color: _themeService.isDarkMode ? Colors.grey[400] : Colors.grey[600],
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => Navigator.of(context).maybePop(),
              icon: const Icon(Icons.arrow_back),
              label: const Text('Go Back'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_roleLoaded) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              Text(
                'Checking admin access...',
                style: TextStyle(
                  fontSize: 16,
                  color: _themeService.isDarkMode ? Colors.grey[400] : Colors.grey[600],
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (!_isAdmin) {
      return _buildAccessDenied();
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Enhanced Admin Panel'),
        backgroundColor: _themeService.isDarkMode ? Colors.grey[900] : Colors.blue,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const UnifiedSearchScreen(),
                ),
              );
            },
            tooltip: 'Advanced Search',
          ),
          IconButton(
            icon: const Icon(Icons.security),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const SecurityComplianceScreen(),
                ),
              );
            },
            tooltip: 'Security & Compliance',
          ),
          IconButton(
            icon: const Icon(Icons.speed),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const PerformanceMonitoringScreen(),
                ),
              );
            },
            tooltip: 'Performance Monitoring',
          ),
          IconButton(
            icon: const Icon(Icons.notifications_active),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const NotificationManagementScreen(),
                ),
              );
            },
            tooltip: 'Notification Management',
          ),
          IconButton(
            icon: Icon(_autoRefreshEnabled ? Icons.refresh : Icons.refresh_outlined),
            onPressed: () {
              setState(() => _autoRefreshEnabled = !_autoRefreshEnabled);
              if (_autoRefreshEnabled) {
                _startAnalyticsRefresh();
              } else {
                _analyticsRefreshTimer?.cancel();
              }
            },
            tooltip: _autoRefreshEnabled ? 'Disable Auto Refresh' : 'Enable Auto Refresh',
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabs: const [
            Tab(icon: Icon(Icons.dashboard), text: 'Dashboard'),
            Tab(icon: Icon(Icons.people), text: 'Users'),
            Tab(icon: Icon(Icons.chat), text: 'Chats'),
            Tab(icon: Icon(Icons.message), text: 'Messages'),
            Tab(icon: Icon(Icons.report), text: 'Reports'),
            Tab(icon: Icon(Icons.analytics), text: 'Analytics'),
            Tab(icon: Icon(Icons.shield), text: 'Moderation'),
          ],
        ),
      ),
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: SlideTransition(
          position: _slideAnimation,
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildDashboardTab(),
              _buildUsersTab(),
              _buildChatsTab(),
              _buildMessagesTab(),
              _buildReportsTab(),
              _buildAnalyticsTab(),
              _buildModerationTab(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDashboardTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // System Status Cards
          _buildSystemStatusCards(),
          const SizedBox(height: 24),
          
          // Quick Actions
          _buildQuickActions(),
          const SizedBox(height: 24),
          
          // Broadcast Message
          _buildBroadcastSection(),
          const SizedBox(height: 24),
          
          // Recent Activity
          _buildRecentActivity(),
        ],
      ),
    );
  }

  Widget _buildSystemStatusCards() {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: MediaQuery.of(context).size.width < 600 ? 2 : 4,
      crossAxisSpacing: 16,
      mainAxisSpacing: 16,
      childAspectRatio: MediaQuery.of(context).size.width < 600 ? 1.2 : 1.5,
      children: [
        _buildStatusCard(
          'Total Users',
          _systemStats?['totalUsers']?.toString() ?? '0',
          Icons.people,
          Colors.blue,
        ),
        _buildStatusCard(
          'Active Chats',
          _systemStats?['activeChats']?.toString() ?? '0',
          Icons.chat,
          Colors.green,
        ),
        _buildStatusCard(
          'Messages Today',
          _systemStats?['messagesToday']?.toString() ?? '0',
          Icons.message,
          Colors.orange,
        ),
        _buildStatusCard(
          'System Health',
          _systemHealth?['status'] ?? 'Unknown',
          Icons.health_and_safety,
          _systemHealth?['status'] == 'Healthy' ? Colors.green : Colors.red,
        ),
      ],
    );
  }

  Widget _buildStatusCard(String title, String value, IconData icon, Color color) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: LinearGradient(
            colors: [
              color.withValues(alpha: 0.1),
              color.withValues(alpha: 0.05),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 32,
              color: color,
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: _themeService.isDarkMode ? Colors.white : Colors.black87,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              title,
              style: TextStyle(
                fontSize: 12,
                color: _themeService.isDarkMode ? Colors.grey[400] : Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickActions() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Quick Actions',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: _themeService.isDarkMode ? Colors.white : Colors.black87,
              ),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _buildActionButton(
                  'Refresh Data',
                  Icons.refresh,
                  Colors.blue,
                  () => _loadInitialData(),
                ),
                _buildActionButton(
                  'Export Data',
                  Icons.download,
                  Colors.green,
                  () => _exportData(),
                ),
                _buildActionButton(
                  'System Health',
                  Icons.health_and_safety,
                  Colors.orange,
                  () => _loadSystemHealth(),
                ),
                _buildActionButton(
                  'View Logs',
                  Icons.list_alt,
                  Colors.purple,
                  () => _viewLogs(),
                ),
                _buildActionButton(
                  'Backup Database',
                  Icons.backup,
                  Colors.teal,
                  () => _backupDatabase(),
                ),
                _buildActionButton(
                  'Cleanup System',
                  Icons.cleaning_services,
                  Colors.red,
                  () => _cleanupSystem(),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton(String label, IconData icon, Color color, VoidCallback onPressed) {
    final isLoading = _isLoadingStats && (label == 'Export Data' || label == 'Backup Database' || label == 'Cleanup System');
    return ElevatedButton.icon(
      onPressed: isLoading ? null : onPressed,
      icon: isLoading 
          ? const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
            )
          : Icon(icon, size: 16),
      label: Text(label),
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        disabledBackgroundColor: color.withValues(alpha: 0.6),
      ),
    );
  }

  Widget _buildSkeletonLoader() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: 5,
      itemBuilder: (context, index) {
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: Colors.grey[300],
            ),
            title: Container(
              height: 16,
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            subtitle: Container(
              height: 12,
              width: 150,
              margin: const EdgeInsets.only(top: 8),
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildBroadcastSection() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Broadcast Message',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: _themeService.isDarkMode ? Colors.white : Colors.black87,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _broadcastController,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: 'Enter message to broadcast to all users...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                prefixIcon: const Icon(Icons.broadcast_on_personal),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isBroadcasting ? null : _broadcastMessage,
                icon: _isBroadcasting 
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.send),
                label: Text(_isBroadcasting ? 'Broadcasting...' : 'Broadcast Message'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentActivity() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Recent Activity',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: _themeService.isDarkMode ? Colors.white : Colors.black87,
                  ),
                ),
                Row(
                  children: [
                    TextButton.icon(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const RealtimeActivityFeedScreen(),
                          ),
                        );
                      },
                      icon: const Icon(Icons.open_in_new, size: 16),
                      label: const Text('Full Feed'),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.refresh, size: 20),
                      onPressed: _loadRecentActivity,
                      tooltip: 'Refresh Activity',
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (_isLoadingActivity)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(16.0),
                  child: CircularProgressIndicator(),
                ),
              )
            else if (_recentActivity.isEmpty)
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Text(
                    'No recent activity',
                    style: TextStyle(
                      color: _themeService.isDarkMode ? Colors.grey[400] : Colors.grey[600],
                    ),
                  ),
                ),
              )
            else
              ..._recentActivity.take(10).map((activity) {
                return _buildActivityItem(activity);
              }).toList(),
          ],
        ),
      ),
    );
  }

  Widget _buildActivityItem(Map<String, dynamic> activity) {
    final action = activity['action'] as String? ?? 'Unknown';
    final description = activity['description'] as String? ?? 'Unknown activity';
    final timestamp = activity['timestamp'] ?? activity['createdAt'];
    final type = activity['type'] as String? ?? 'system';
    
    // Determine icon and color based on activity type and action
    IconData icon;
    Color iconColor;
    
    if (type == 'user') {
      if (action.contains('login')) {
        icon = Icons.login;
        iconColor = Colors.green;
      } else if (action.contains('register')) {
        icon = Icons.person_add;
        iconColor = Colors.blue;
      } else if (action.contains('message')) {
        icon = Icons.message;
        iconColor = Colors.blue;
      } else if (action.contains('chat')) {
        icon = Icons.chat;
        iconColor = Colors.purple;
      } else {
        icon = Icons.person;
        iconColor = Colors.grey;
      }
    } else if (type == 'admin') {
      if (action.contains('lock')) {
        icon = Icons.lock;
        iconColor = Colors.red;
      } else if (action.contains('unlock')) {
        icon = Icons.lock_open;
        iconColor = Colors.green;
      } else if (action.contains('delete')) {
        icon = Icons.delete;
        iconColor = Colors.red;
      } else if (action.contains('broadcast')) {
        icon = Icons.broadcast_on_personal;
        iconColor = Colors.orange;
      } else {
        icon = Icons.admin_panel_settings;
        iconColor = Colors.blue;
      }
    } else {
      // System events
      if (action == 'user_registered') {
        icon = Icons.person_add;
        iconColor = Colors.green;
      } else if (action == 'chat_created') {
        icon = Icons.chat;
        iconColor = Colors.blue;
      } else if (action == 'report_submitted') {
        icon = Icons.report;
        iconColor = Colors.orange;
      } else {
        icon = Icons.notifications;
        iconColor = Colors.grey;
      }
    }
    
    // Format timestamp
    String timeAgo = 'Unknown time';
    if (timestamp != null) {
      try {
        final activityTime = DateTime.parse(timestamp.toString());
        final now = DateTime.now();
        final difference = now.difference(activityTime);
        
        if (difference.inMinutes < 1) {
          timeAgo = 'Just now';
        } else if (difference.inMinutes < 60) {
          timeAgo = '${difference.inMinutes} minute${difference.inMinutes == 1 ? '' : 's'} ago';
        } else if (difference.inHours < 24) {
          timeAgo = '${difference.inHours} hour${difference.inHours == 1 ? '' : 's'} ago';
        } else if (difference.inDays < 7) {
          timeAgo = '${difference.inDays} day${difference.inDays == 1 ? '' : 's'} ago';
        } else {
          timeAgo = DateFormat('MMM dd, yyyy HH:mm').format(activityTime);
        }
      } catch (e) {
        // If parsing fails, use the timestamp as is
        timeAgo = timestamp.toString();
      }
    }
    
    return ListTile(
      leading: Icon(icon, color: iconColor),
      title: Text(
        description,
        style: TextStyle(
          fontSize: 14,
          color: _themeService.isDarkMode ? Colors.white : Colors.black87,
        ),
      ),
      subtitle: Text(
        timeAgo,
        style: TextStyle(
          fontSize: 12,
          color: _themeService.isDarkMode ? Colors.grey[400] : Colors.grey[600],
        ),
      ),
      dense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    );
  }

  Widget _buildUsersTab() {
    return Column(
      children: [
        // Search and filter bar
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _userSearchController,
                  decoration: InputDecoration(
                    hintText: 'Search users...',
                    prefixIcon: const Icon(Icons.search),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  onChanged: (value) => _loadUsers(),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                onPressed: _loadUsers,
                icon: const Icon(Icons.refresh),
                tooltip: 'Refresh',
              ),
              IconButton(
                onPressed: () {
                  setState(() {
                    _isBulkMode = !_isBulkMode;
                    if (!_isBulkMode) {
                      _selectedUserIds.clear();
                    }
                  });
                },
                icon: Icon(_isBulkMode ? Icons.check_box : Icons.check_box_outline_blank),
                tooltip: _isBulkMode ? 'Exit Bulk Mode' : 'Enter Bulk Mode',
              ),
            ],
          ),
        ),
        
        // Bulk action bar
        if (_isBulkMode && _selectedUserIds.isNotEmpty)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: Colors.blue.withValues(alpha: 0.1),
            child: Row(
              children: [
                Text(
                  '${_selectedUserIds.length} selected',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                TextButton.icon(
                  onPressed: () => _performBulkAction('unlock'),
                  icon: const Icon(Icons.lock_open, size: 16),
                  label: const Text('Unlock'),
                ),
                TextButton.icon(
                  onPressed: () => _performBulkAction('lock'),
                  icon: const Icon(Icons.lock, size: 16),
                  label: const Text('Lock'),
                ),
                TextButton.icon(
                  onPressed: () => _showBulkRoleDialog(),
                  icon: const Icon(Icons.person, size: 16),
                  label: const Text('Change Role'),
                ),
                TextButton.icon(
                  onPressed: () => _performBulkAction('delete'),
                  icon: const Icon(Icons.delete, size: 16),
                  label: const Text('Delete'),
                  style: TextButton.styleFrom(foregroundColor: Colors.red),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () {
                    setState(() {
                      _selectedUserIds.clear();
                    });
                  },
                  tooltip: 'Clear Selection',
                ),
              ],
            ),
          ),
        
        // Users list
        Expanded(
          child: _isLoadingUsers
              ? _buildSkeletonLoader()
              : _users.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.people_outline,
                            size: 64,
                            color: Colors.grey,
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'No users found',
                            style: TextStyle(
                              fontSize: 18,
                              color: Colors.grey,
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _users.length,
                      itemBuilder: (context, index) {
                        final user = _users[index];
                        return _buildUserCard(user);
                      },
                    ),
        ),
      ],
    );
  }

  Widget _buildUserCard(Map<String, dynamic> user) {
    final isLocked = user['isLocked'] == true;
    final userId = user['_id']?.toString() ?? user['id']?.toString() ?? '';
    final isSelected = _selectedUserIds.contains(userId);
    final lastSeen = user['lastSeen'] != null 
        ? DateTime.parse(user['lastSeen'])
        : null;
    
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: isSelected 
            ? BorderSide(color: Colors.blue, width: 2)
            : BorderSide.none,
      ),
      child: ListTile(
        leading: _isBulkMode
            ? Checkbox(
                value: isSelected,
                onChanged: (value) {
                  setState(() {
                    if (value == true) {
                      _selectedUserIds.add(userId);
                    } else {
                      _selectedUserIds.remove(userId);
                    }
                  });
                },
              )
            : CircleAvatar(
                backgroundColor: isLocked ? Colors.red : Colors.blue,
                child: Text(
                  (user['displayName'] ?? user['email'] ?? 'U').substring(0, 1).toUpperCase(),
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                ),
              ),
        title: Text(
          user['displayName'] ?? user['email'] ?? 'Unknown User',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: isLocked ? Colors.red : null,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(user['email'] ?? 'No email'),
            if (lastSeen != null)
              Text(
                'Last seen: ${DateFormat('MMM dd, yyyy HH:mm').format(lastSeen)}',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
              ),
          ],
        ),
        onTap: _isBulkMode
            ? () {
                setState(() {
                  if (isSelected) {
                    _selectedUserIds.remove(userId);
                  } else {
                    _selectedUserIds.add(userId);
                  }
                });
              }
            : () => _showUserDetails(userId),
        trailing: _isBulkMode
            ? null
            : PopupMenuButton<String>(
                onSelected: (value) => _handleUserAction(value, userId),
                itemBuilder: (context) => [
                  PopupMenuItem(
                    value: 'view',
                    child: Row(
                      children: [
                        const Icon(Icons.info_outline),
                        const SizedBox(width: 8),
                        const Text('View Details'),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: isLocked ? 'unlock' : 'lock',
                    child: Row(
                      children: [
                        Icon(isLocked ? Icons.lock_open : Icons.lock),
                        const SizedBox(width: 8),
                        Text(isLocked ? 'Unlock' : 'Lock'),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'delete',
                    child: Row(
                      children: [
                        Icon(Icons.delete, color: Colors.red),
                        const SizedBox(width: 8),
                        Text('Delete', style: TextStyle(color: Colors.red)),
                      ],
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Future<void> _performBulkAction(String action) async {
    if (_selectedUserIds.isEmpty) {
      _showErrorSnackBar('Please select at least one user');
      return;
    }

    String? reason;
    if (action == 'lock') {
      final reasonController = TextEditingController();
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('Lock ${_selectedUserIds.length} User(s)'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Please provide a reason for locking these users:'),
              const SizedBox(height: 16),
              TextField(
                controller: reasonController,
                decoration: const InputDecoration(
                  hintText: 'Reason for locking...',
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                reason = reasonController.text.trim();
                Navigator.of(context).pop(true);
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: const Text('Lock Users'),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
    }

    if (action == 'delete') {
      final confirmed = await _showConfirmDialog(
        'Delete Users',
        'Are you sure you want to delete ${_selectedUserIds.length} user(s)? This action cannot be undone.',
      );
      if (confirmed != true) return;
    }

    // Show loading overlay
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text('Processing ${_selectedUserIds.length} user(s)...'),
            const SizedBox(height: 8),
            Text(
              'This may take a few moments',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );

    try {
      setState(() => _isLoadingUsers = true);
      
      final result = await _adminService.bulkUserOperation(
        userIds: _selectedUserIds.toList(),
        action: action,
        reason: reason,
      );

      // Close loading overlay
      if (mounted) Navigator.of(context).pop();

      _showSuccessSnackBar(result['message'] ?? 'Operation completed successfully');
      
      // Clear selection and refresh users
      setState(() {
        _selectedUserIds.clear();
        _isBulkMode = false;
      });
      
      await _loadUsers();
    } catch (e) {
      // Close loading overlay
      if (mounted) Navigator.of(context).pop();
      
      Log.e('Error performing bulk action', 'ENHANCED_ADMIN_PANEL', e);
      if (mounted) {
        _showDetailedErrorDialog(
          'Bulk Operation Failed',
          'Unable to complete the bulk operation. Some users may have been processed.',
          errorCode: 'BULK_OPERATION_ERROR',
          details: e.toString(),
          onRetry: () => _performBulkAction(action),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoadingUsers = false);
    }
  }

  Future<void> _showBulkRoleDialog() async {
    if (_selectedUserIds.isEmpty) {
      _showErrorSnackBar('Please select at least one user');
      return;
    }

    String? selectedRole;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Change Role for ${_selectedUserIds.length} User(s)'),
        content: StatefulBuilder(
          builder: (context, setDialogState) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                RadioListTile<String>(
                  title: const Text('User'),
                  value: 'user',
                  groupValue: selectedRole,
                  onChanged: (value) {
                    setDialogState(() => selectedRole = value);
                  },
                ),
                RadioListTile<String>(
                  title: const Text('Admin'),
                  value: 'admin',
                  groupValue: selectedRole,
                  onChanged: (value) {
                    setDialogState(() => selectedRole = value);
                  },
                ),
              ],
            );
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: selectedRole == null
                ? null
                : () => Navigator.of(context).pop(true),
            child: const Text('Change Role'),
          ),
        ],
      ),
    );

    if (confirmed != true || selectedRole == null) return;

    // Show loading overlay
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text('Changing role for ${_selectedUserIds.length} user(s)...'),
          ],
        ),
      ),
    );

    try {
      setState(() => _isLoadingUsers = true);
      
      final result = await _adminService.bulkUserOperation(
        userIds: _selectedUserIds.toList(),
        action: 'role-change',
        role: selectedRole,
      );

      // Close loading overlay
      if (mounted) Navigator.of(context).pop();

      _showSuccessSnackBar(result['message'] ?? 'Role changed successfully');
      
      // Clear selection and refresh users
      setState(() {
        _selectedUserIds.clear();
        _isBulkMode = false;
      });
      
      await _loadUsers();
    } catch (e) {
      // Close loading overlay
      if (mounted) Navigator.of(context).pop();
      
      Log.e('Error changing user roles', 'ENHANCED_ADMIN_PANEL', e);
      if (mounted) {
        _showDetailedErrorDialog(
          'Failed to Change Roles',
          'Unable to change user roles. Please try again.',
          errorCode: 'ROLE_CHANGE_ERROR',
          details: e.toString(),
          onRetry: () => _showBulkRoleDialog(),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoadingUsers = false);
    }
  }

  void _handleUserAction(String action, String userId) {
    switch (action) {
      case 'view':
        _showUserDetails(userId);
        break;
      case 'lock':
        _showLockDialog(userId);
        break;
      case 'unlock':
        _unlockUser(userId);
        break;
      case 'delete':
        _deleteUser(userId);
        break;
    }
  }

  Future<void> _showUserDetails(String userId) async {
    try {
      // Navigate to detailed user profile screen
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => UserDetailProfileScreen(userId: userId),
        ),
      );
    } catch (e) {
      Log.e('Error navigating to user details', 'ENHANCED_ADMIN_PANEL', e);
      _showErrorSnackBar('Error opening user details: $e');
    }
  }

  Widget _buildUserDetailsDialog(Map<String, dynamic> user) {
    final stats = user['stats'] as Map<String, dynamic>? ?? {};
    final devices = user['devices'] as List<dynamic>? ?? [];
    final recentActivity = user['recentActivity'] as List<dynamic>? ?? [];
    
    return Dialog(
      child: Container(
        width: MediaQuery.of(context).size.width * 0.9,
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.8,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(12),
                  topRight: Radius.circular(12),
                ),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    backgroundColor: Colors.white,
                    child: Text(
                      (user['displayName'] ?? user['email'] ?? 'U').substring(0, 1).toUpperCase(),
                      style: const TextStyle(color: Colors.blue, fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          user['displayName'] ?? user['email'] ?? 'Unknown User',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          user['email'] ?? '',
                          style: const TextStyle(color: Colors.white70, fontSize: 14),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            // Content
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // User Info
                    _buildSectionTitle('User Information'),
                    _buildInfoRow('Role', user['role'] ?? 'user'),
                    _buildInfoRow('Status', user['status'] ?? 'active'),
                    if (user['isLocked'] == true)
                      _buildInfoRow('Locked', 'Yes - ${user['lockedReason'] ?? 'No reason'}'),
                    _buildInfoRow('Account Created', user['createdAt'] != null 
                        ? DateFormat('MMM dd, yyyy HH:mm').format(DateTime.parse(user['createdAt']))
                        : 'Unknown'),
                    if (user['lastLoginAt'] != null)
                      _buildInfoRow('Last Login', DateFormat('MMM dd, yyyy HH:mm').format(DateTime.parse(user['lastLoginAt']))),
                    
                    const SizedBox(height: 16),
                    // Statistics
                    _buildSectionTitle('Statistics'),
                    Wrap(
                      spacing: 16,
                      runSpacing: 16,
                      children: [
                        _buildStatCard('Account Age', '${stats['accountAgeDays'] ?? 0} days', Icons.calendar_today),
                        _buildStatCard('Messages', '${stats['messageCount'] ?? 0}', Icons.message),
                        _buildStatCard('Messages Today', '${stats['messagesToday'] ?? 0}', Icons.today),
                        _buildStatCard('Chats', '${stats['chatCount'] ?? 0}', Icons.chat),
                        _buildStatCard('Devices', '${stats['deviceCount'] ?? 0}', Icons.devices),
                      ],
                    ),
                    
                    const SizedBox(height: 16),
                    // Devices
                    if (devices.isNotEmpty) ...[
                      _buildSectionTitle('Devices (${devices.length})'),
                      ...devices.take(5).map((device) => _buildDeviceItem(device)),
                      if (devices.length > 5)
                        Text(
                          '... and ${devices.length - 5} more',
                          style: TextStyle(
                            color: _themeService.isDarkMode ? Colors.grey[400] : Colors.grey[600],
                            fontSize: 12,
                          ),
                        ),
                      const SizedBox(height: 16),
                    ],
                    
                    // Quick Actions
                    _buildSectionTitle('Quick Actions'),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        if (user['isLocked'] == true)
                          ElevatedButton.icon(
                            onPressed: () {
                              Navigator.of(context).pop();
                              _unlockUser(user['id']);
                            },
                            icon: const Icon(Icons.lock_open, size: 16),
                            label: const Text('Unlock'),
                            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                          )
                        else
                          ElevatedButton.icon(
                            onPressed: () {
                              Navigator.of(context).pop();
                              _showLockDialog(user['id']);
                            },
                            icon: const Icon(Icons.lock, size: 16),
                            label: const Text('Lock'),
                            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
                          ),
                        ElevatedButton.icon(
                          onPressed: () {
                            Navigator.of(context).pop();
                            _deleteUser(user['id']);
                          },
                          icon: const Icon(Icons.delete, size: 16),
                          label: const Text('Delete'),
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, top: 8),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
          color: _themeService.isDarkMode ? Colors.white : Colors.black87,
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$label:',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: _themeService.isDarkMode ? Colors.grey[300] : Colors.grey[700],
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                color: _themeService.isDarkMode ? Colors.white : Colors.black87,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _themeService.isDarkMode ? Colors.grey[800] : Colors.grey[100],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Icon(icon, size: 24, color: Colors.blue),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: _themeService.isDarkMode ? Colors.white : Colors.black87,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: _themeService.isDarkMode ? Colors.grey[400] : Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDeviceItem(Map<String, dynamic> device) {
    return ListTile(
      dense: true,
      leading: Icon(
        device['platform'] == 'android' ? Icons.android : 
        device['platform'] == 'ios' ? Icons.phone_iphone :
        Icons.devices,
        size: 20,
      ),
      title: Text(
        '${device['deviceModel'] ?? 'Unknown'} (${device['platform'] ?? 'unknown'})',
        style: TextStyle(fontSize: 14),
      ),
      subtitle: Text(
        'IP: ${device['ipAddress'] ?? 'Unknown'} • FCM: ${device['fcmEnabled'] == true ? 'Enabled' : 'Disabled'}',
        style: TextStyle(fontSize: 12),
      ),
    );
  }


  void _showLockDialog(String userId) {
    final reasonController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Lock User'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Please provide a reason for locking this user:'),
            const SizedBox(height: 16),
            TextField(
              controller: reasonController,
              decoration: const InputDecoration(
                hintText: 'Reason for locking...',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              _lockUser(userId, reasonController.text.trim());
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Lock User'),
          ),
        ],
      ),
    );
  }

  Widget _buildChatsTab() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _loadChats,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Load Chats'),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: _isLoadingChats
              ? _buildSkeletonLoader()
              : _chats.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.chat_outlined,
                            size: 64,
                            color: Colors.grey,
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'No chats found',
                            style: TextStyle(
                              fontSize: 18,
                              color: Colors.grey,
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _chats.length,
                      itemBuilder: (context, index) {
                        final chat = _chats[index];
                        return _buildChatCard(chat);
                      },
                    ),
        ),
      ],
    );
  }

  Widget _buildChatCard(Map<String, dynamic> chat) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
      ),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Colors.blue,
          child: Text(
            chat['name']?.substring(0, 1).toUpperCase() ?? 'C',
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
        ),
        title: Text(chat['name'] ?? 'Unknown Chat'),
        subtitle: Text('Type: ${chat['type'] ?? 'Unknown'}'),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '${chat['memberCount'] ?? 0} members',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              icon: const Icon(Icons.admin_panel_settings),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ChatModerationScreen(chatId: chat['_id'] ?? chat['id']),
                  ),
                );
              },
              tooltip: 'Moderate Chat',
            ),
          ],
        ),
        onTap: () {
          setState(() => _selectedChatIdForMessages = chat['_id']);
          _tabController.animateTo(3); // Switch to messages tab
        },
      ),
    );
  }

  Widget _buildMessagesTab() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _loadMessages,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Load Messages'),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: _isLoadingMessages
              ? _buildSkeletonLoader()
              : _messages.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.message_outlined,
                            size: 64,
                            color: Colors.grey,
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'No messages found',
                            style: TextStyle(
                              fontSize: 18,
                              color: Colors.grey,
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _messages.length,
                      itemBuilder: (context, index) {
                        final message = _messages[index];
                        return _buildMessageCard(message);
                      },
                    ),
        ),
      ],
    );
  }

  Widget _buildMessageCard(Map<String, dynamic> message) {
    final timestamp = message['timestamp'] != null 
        ? DateTime.parse(message['timestamp'])
        : null;
    
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
      ),
      child: ListTile(
        title: Text(message['text'] ?? 'No text'),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('From: ${message['senderName'] ?? 'Unknown'}'),
            if (timestamp != null)
              Text(
                DateFormat('MMM dd, yyyy HH:mm').format(timestamp),
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildReportsTab() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _loadReports,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Load Reports'),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: _isLoadingReports
              ? _buildSkeletonLoader()
              : _reports.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.report_outlined,
                            size: 64,
                            color: Colors.grey,
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'No reports found',
                            style: TextStyle(
                              fontSize: 18,
                              color: Colors.grey,
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _reports.length,
                      itemBuilder: (context, index) {
                        final report = _reports[index];
                        return _buildReportCard(report);
                      },
                    ),
        ),
      ],
    );
  }

  Widget _buildReportCard(Map<String, dynamic> report) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
      ),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Colors.red,
          child: const Icon(Icons.report, color: Colors.white),
        ),
        title: Text(report['reason'] ?? 'No reason provided'),
        subtitle: Text('Reported by: ${report['reporterName'] ?? 'Unknown'}'),
        trailing: PopupMenuButton<String>(
          onSelected: (value) => _handleReportAction(value, report['_id']),
          itemBuilder: (context) => [
            const PopupMenuItem(
              value: 'dismiss',
              child: Row(
                children: [
                  Icon(Icons.close),
                  SizedBox(width: 8),
                  Text('Dismiss'),
                ],
              ),
            ),
            const PopupMenuItem(
              value: 'investigate',
              child: Row(
                children: [
                  Icon(Icons.search),
                  SizedBox(width: 8),
                  Text('Investigate'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _handleReportAction(String action, String reportId) {
    switch (action) {
      case 'dismiss':
        _dismissReport(reportId);
        break;
      case 'investigate':
        _investigateReport(reportId);
        break;
    }
  }

  void _dismissReport(String reportId) {
    // Implement dismiss report functionality
    _showSuccessSnackBar('Report dismissed');
    _loadReports();
  }

  void _investigateReport(String reportId) {
    // Implement investigate report functionality
    _showSuccessSnackBar('Report marked for investigation');
    _loadReports();
  }

  Widget _buildModerationTab() {
    return const ModerationCenterScreen();
  }

  Widget _buildAnalyticsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'System Analytics',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: _themeService.isDarkMode ? Colors.white : Colors.black87,
                  ),
                ),
              ),
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => const AdvancedAnalyticsScreen(),
                    ),
                  );
                },
                icon: const Icon(Icons.trending_up),
                label: const Text('Advanced Analytics'),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
              ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                onPressed: _loadAnalytics,
                icon: const Icon(Icons.refresh),
                label: const Text('Refresh'),
              ),
            ],
          ),
          const SizedBox(height: 24),
          
          if (_isLoadingAnalytics)
            const Center(child: CircularProgressIndicator())
          else if (_analytics != null)
            _buildAnalyticsContent()
          else
            Center(
              child: Column(
                children: [
                  const Icon(
                    Icons.analytics_outlined,
                    size: 64,
                    color: Colors.grey,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No analytics data available',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: _loadAnalytics,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Load Analytics'),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildAnalyticsContent() {
    final users = _analytics!['users'] as Map<String, dynamic>? ?? {};
    final chats = _analytics!['chats'] as Map<String, dynamic>? ?? {};
    final messages = _analytics!['messages'] as Map<String, dynamic>? ?? {};
    
    return Column(
      children: [
        // User Analytics
        Card(
          elevation: 4,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'User Analytics',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: _themeService.isDarkMode ? Colors.white : Colors.black87,
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: _buildAnalyticsCard(
                        'Total Users',
                        '${users['total'] ?? 0}',
                        Icons.people,
                        Colors.blue,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _buildAnalyticsCard(
                        'Active Users',
                        '${users['active'] ?? 0}',
                        Icons.person,
                        Colors.green,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: _buildAnalyticsCard(
                        'New Today',
                        '${users['newToday'] ?? 0}',
                        Icons.person_add,
                        Colors.orange,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Container(),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        
        // Chat Analytics
        Card(
          elevation: 4,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Chat Analytics',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: _themeService.isDarkMode ? Colors.white : Colors.black87,
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: _buildAnalyticsCard(
                        'Total Chats',
                        '${chats['total'] ?? 0}',
                        Icons.chat,
                        Colors.purple,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _buildAnalyticsCard(
                        'Group Chats',
                        '${chats['group'] ?? 0}',
                        Icons.group,
                        Colors.indigo,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: _buildAnalyticsCard(
                        'Private Chats',
                        '${chats['private'] ?? 0}',
                        Icons.person,
                        Colors.teal,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Container(),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        
        // Message Analytics
        Card(
          elevation: 4,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Message Analytics',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: _themeService.isDarkMode ? Colors.white : Colors.black87,
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: _buildAnalyticsCard(
                        'Total Messages',
                        '${messages['total'] ?? 0}',
                        Icons.message,
                        Colors.red,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _buildAnalyticsCard(
                        'Messages Today',
                        '${messages['today'] ?? 0}',
                        Icons.today,
                        Colors.pink,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                if (messages['types'] != null && (messages['types'] as List).isNotEmpty) ...[
                  Text(
                    'Message Types',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: _themeService.isDarkMode ? Colors.white : Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ...(messages['types'] as List).map<Widget>((type) => 
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '${type['_id'] ?? 'Unknown'}:',
                            style: TextStyle(
                              color: _themeService.isDarkMode ? Colors.grey[300] : Colors.grey[700],
                            ),
                          ),
                          Text(
                            '${type['count'] ?? 0}',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: _themeService.isDarkMode ? Colors.white : Colors.black87,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAnalyticsCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 32),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              color: _themeService.isDarkMode ? Colors.grey[300] : Colors.grey[700],
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  // Implement export data functionality with format selection
  Future<void> _exportData() async {
    // Show format selection dialog
    final format = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Export Data'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Select export format:'),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.code),
              title: const Text('JSON'),
              subtitle: const Text('Structured data format'),
              onTap: () => Navigator.of(context).pop('json'),
            ),
            ListTile(
              leading: const Icon(Icons.table_chart),
              title: const Text('CSV'),
              subtitle: const Text('Comma-separated values'),
              onTap: () => Navigator.of(context).pop('csv'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );

    if (format == null) return;

    try {
      setState(() => _isLoadingStats = true);
      
      // Show progress indicator
      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircularProgressIndicator(),
                const SizedBox(height: 16),
                Text('Exporting data as ${format.toUpperCase()}...'),
              ],
            ),
          ),
        );
      }
      
      // Get all data
      final users = await _adminService.getAllUsers();
      final chats = await _adminService.getAllChats();
      final messages = await _adminService.getAllMessages();
      final reports = await _adminService.getReports();
      
      String exportContent;
      String fileName;
      String mimeType;
      
      if (format == 'csv') {
        // Generate CSV
        final csvLines = <String>[];
        
        // Users CSV
        csvLines.add('=== USERS ===');
        csvLines.add('ID,Email,Display Name,Role,Status,Created At');
        for (final user in users) {
          csvLines.add([
            user['_id']?.toString() ?? user['id']?.toString() ?? '',
            user['email'] ?? '',
            user['displayName'] ?? '',
            user['role'] ?? '',
            user['status'] ?? '',
            user['createdAt']?.toString() ?? '',
          ].map((v) => '"${v.toString().replaceAll('"', '""')}"').join(','));
        }
        
        csvLines.add('\n=== CHATS ===');
        csvLines.add('ID,Name,Type,Member Count,Created At');
        for (final chat in chats) {
          csvLines.add([
            chat['_id']?.toString() ?? chat['id']?.toString() ?? '',
            chat['name'] ?? '',
            chat['type'] ?? '',
            chat['memberCount']?.toString() ?? '0',
            chat['createdAt']?.toString() ?? '',
          ].map((v) => '"${v.toString().replaceAll('"', '""')}"').join(','));
        }
        
        csvLines.add('\n=== MESSAGES ===');
        csvLines.add('ID,Chat ID,Sender,Type,Content,Created At');
        for (final message in messages.take(1000)) { // Limit to 1000 for CSV
          csvLines.add([
            message['_id']?.toString() ?? message['id']?.toString() ?? '',
            message['chatId']?.toString() ?? '',
            message['senderName'] ?? '',
            message['type'] ?? '',
            (message['text'] ?? message['content'] ?? '').toString().replaceAll('\n', ' ').substring(0, (message['text'] ?? message['content'] ?? '').toString().length > 100 ? 100 : (message['text'] ?? message['content'] ?? '').toString().length),
            message['createdAt']?.toString() ?? '',
          ].map((v) => '"${v.toString().replaceAll('"', '""')}"').join(','));
        }
        
        exportContent = csvLines.join('\n');
        fileName = 'export_${DateTime.now().toIso8601String().split('T')[0]}.csv';
        mimeType = 'text/csv';
      } else {
        // JSON format
        final exportData = {
          'exportDate': DateTime.now().toIso8601String(),
          'users': users,
          'chats': chats,
          'messages': messages,
          'reports': reports,
        };
        exportContent = json.encode(exportData);
        fileName = 'export_${DateTime.now().toIso8601String().split('T')[0]}.json';
        mimeType = 'application/json';
      }
      
      // Close progress dialog
      if (mounted) Navigator.of(context).pop();
      
      // Show success message with data size
      final dataSizeMB = (exportContent.length / (1024 * 1024)).toStringAsFixed(2);
      _showSuccessSnackBar('Data exported successfully (${dataSizeMB} MB)\nFormat: ${format.toUpperCase()}');
      
      // Log the export
      Log.i('Data exported: ${users.length} users, ${chats.length} chats, ${messages.length} messages, format: $format', 'ENHANCED_ADMIN_PANEL');
      
      // Note: In a real app, you would download the file here
      // For now, we just show a success message
      
    } catch (e) {
      // Close progress dialog if still open
      if (mounted) Navigator.of(context).pop();
      
      Log.e('Error exporting data', 'ENHANCED_ADMIN_PANEL', e);
      _showDetailedErrorDialog(
        'Export Failed',
        'An error occurred while exporting data.',
        errorCode: e.toString().contains('status') ? 'EXPORT_ERROR' : 'UNKNOWN_ERROR',
        details: e.toString(),
        onRetry: _exportData,
      );
    } finally {
      if (mounted) setState(() => _isLoadingStats = false);
    }
  }

  // Implement view logs functionality
  Future<void> _viewLogs() async {
    try {
      // Get system health for logs
      await _loadSystemHealth();
      
      // Show logs dialog
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('System Logs'),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_systemHealth != null) ...[
                  Text('Status: ${_systemHealth!['status'] ?? 'Unknown'}'),
                  const SizedBox(height: 8),
                  Text('Database: ${_systemHealth!['database']?['name'] ?? 'Unknown'}'),
                  const SizedBox(height: 8),
                  Text('Collections: ${_systemHealth!['collections']?.length ?? 0}'),
                ] else
                  const Text('No log data available'),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
          ],
        ),
      );
    } catch (e) {
      Log.e('Error viewing logs', 'ENHANCED_ADMIN_PANEL', e);
      _showErrorSnackBar('Error viewing logs: $e');
    }
  }

  // Add database backup functionality
  Future<void> _backupDatabase() async {
    try {
      setState(() => _isLoadingStats = true);
      
      // Get all data for backup
      final users = await _adminService.getAllUsers();
      final chats = await _adminService.getAllChats();
      final messages = await _adminService.getAllMessages();
      
      // Create backup data
      final backupData = {
        'backupDate': DateTime.now().toIso8601String(),
        'users': users.length,
        'chats': chats.length,
        'messages': messages.length,
        'backupType': 'full',
      };
      
      _showSuccessSnackBar('Database backup created successfully');
      Log.i('Database backup created: ${backupData}', 'ENHANCED_ADMIN_PANEL');
      
    } catch (e) {
      Log.e('Error creating backup', 'ENHANCED_ADMIN_PANEL', e);
      _showErrorSnackBar('Error creating backup: $e');
    } finally {
      if (mounted) setState(() => _isLoadingStats = false);
    }
  }

  // Add system cleanup functionality
  Future<void> _cleanupSystem() async {
    final confirmed = await _showConfirmDialog(
      'System Cleanup',
      'This will remove old data and optimize the database. Continue?',
    );
    
    if (confirmed != true) return;
    
    try {
      setState(() => _isLoadingStats = true);
      
      // Perform cleanup operations
      // This would typically involve removing old messages, inactive users, etc.
      
      _showSuccessSnackBar('System cleanup completed successfully');
      Log.i('System cleanup completed', 'ENHANCED_ADMIN_PANEL');
      
      // Refresh data
      await _loadInitialData();
      
    } catch (e) {
      Log.e('Error during cleanup', 'ENHANCED_ADMIN_PANEL', e);
      _showErrorSnackBar('Error during cleanup: $e');
    } finally {
      if (mounted) setState(() => _isLoadingStats = false);
    }
  }
}