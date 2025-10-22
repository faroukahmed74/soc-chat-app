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
import '../services/theme_service.dart';
import '../services/mongodb_admin_service.dart';
import '../services/physical_auth_service.dart';
import '../services/logger_service.dart';

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
  Map<String, dynamic>? _systemStats;
  Map<String, dynamic>? _systemHealth;
  Map<String, dynamic>? _analytics;
  
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
      _showErrorSnackBar('Error loading users: $e');
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
      _showErrorSnackBar('Error loading system stats: $e');
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
      _showErrorSnackBar('Error loading chats: $e');
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
      _showErrorSnackBar('Error loading messages: $e');
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
      _showErrorSnackBar('Error loading reports: $e');
    } finally {
      if (mounted) setState(() => _isLoadingReports = false);
    }
  }

  void _showErrorSnackBar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.red,
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
      _showErrorSnackBar('Error broadcasting message: $e');
    } finally {
      if (mounted) setState(() => _isBroadcasting = false);
    }
  }

  Future<void> _lockUser(String userId, String reason) async {
    try {
      await _adminService.lockUser(userId, reason);
      _showSuccessSnackBar('User locked successfully');
      _loadUsers(); // Refresh users list
    } catch (e) {
      Log.e('Error locking user', 'ENHANCED_ADMIN_PANEL', e);
      _showErrorSnackBar('Error locking user: $e');
    }
  }

  Future<void> _unlockUser(String userId) async {
    try {
      await _adminService.unlockUser(userId);
      _showSuccessSnackBar('User unlocked successfully');
      _loadUsers(); // Refresh users list
    } catch (e) {
      Log.e('Error unlocking user', 'ENHANCED_ADMIN_PANEL', e);
      _showErrorSnackBar('Error unlocking user: $e');
    }
  }

  Future<void> _deleteUser(String userId) async {
    final confirmed = await _showConfirmDialog(
      'Delete User',
      'Are you sure you want to delete this user? This action cannot be undone.',
    );
    
    if (confirmed == true) {
      try {
        await _adminService.deleteUserEnhanced(userId);
        _showSuccessSnackBar('User deleted successfully');
        _loadUsers(); // Refresh users list
      } catch (e) {
        Log.e('Error deleting user', 'ENHANCED_ADMIN_PANEL', e);
        _showErrorSnackBar('Error deleting user: $e');
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
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton(String label, IconData icon, Color color, VoidCallback onPressed) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 16),
      label: Text(label),
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
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
            Text(
              'Recent Activity',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: _themeService.isDarkMode ? Colors.white : Colors.black87,
              ),
            ),
            const SizedBox(height: 16),
            // This would be populated with actual recent activity data
            const ListTile(
              leading: Icon(Icons.person_add, color: Colors.green),
              title: Text('New user registered'),
              subtitle: Text('2 minutes ago'),
            ),
            const ListTile(
              leading: Icon(Icons.chat, color: Colors.blue),
              title: Text('New chat created'),
              subtitle: Text('5 minutes ago'),
            ),
            const ListTile(
              leading: Icon(Icons.report, color: Colors.orange),
              title: Text('Report submitted'),
              subtitle: Text('10 minutes ago'),
            ),
          ],
        ),
      ),
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
            ],
          ),
        ),
        
        // Users list
        Expanded(
          child: _isLoadingUsers
              ? const Center(child: CircularProgressIndicator())
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
    final lastSeen = user['lastSeen'] != null 
        ? DateTime.parse(user['lastSeen'])
        : null;
    
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
      ),
      child: ListTile(
        leading: CircleAvatar(
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
        trailing: PopupMenuButton<String>(
          onSelected: (value) => _handleUserAction(value, user['_id']),
          itemBuilder: (context) => [
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

  void _handleUserAction(String action, String userId) {
    switch (action) {
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
              ? const Center(child: CircularProgressIndicator())
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
        trailing: Text(
          '${chat['memberCount'] ?? 0} members',
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
          ),
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
              ? const Center(child: CircularProgressIndicator())
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
              ? const Center(child: CircularProgressIndicator())
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

  // Placeholder methods for future implementation
  void _exportData() {
    _showSuccessSnackBar('Data export functionality coming soon');
  }

  void _viewLogs() {
    _showSuccessSnackBar('Log viewer functionality coming soon');
  }
}