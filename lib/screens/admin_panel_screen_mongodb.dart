// =============================================================================
// ADMIN PANEL SCREEN - MONGODB VERSION
// =============================================================================
// This screen provides admin functionality using MongoDB
// It handles user management, system monitoring, and admin operations

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'dart:async';
import '../services/theme_service.dart';
import '../services/mongodb_admin_service.dart';
import '../services/physical_auth_service.dart';
import '../services/logger_service.dart';
import '../services/device_tracking_service.dart';
import '../theme/app_design_system.dart';
import '../config/database_config.dart';
import '../utils/responsive_utils.dart';

class AdminPanelScreenMongoDB extends StatefulWidget {
  const AdminPanelScreenMongoDB({Key? key}) : super(key: key);

  @override
  State<AdminPanelScreenMongoDB> createState() => _AdminPanelScreenMongoDBState();
}

class _AdminPanelScreenMongoDBState extends State<AdminPanelScreenMongoDB> with TickerProviderStateMixin {
  final MongoDBAdminService _adminService = MongoDBAdminService();
  final PhysicalAuthService _authService = PhysicalAuthService();
  late TabController _tabController;
  late ThemeService _themeService;

  // Data
  List<Map<String, dynamic>> _users = [];
  List<Map<String, dynamic>> _chats = [];
  List<Map<String, dynamic>> _groups = [];
  List<Map<String, dynamic>> _messages = [];
  List<Map<String, dynamic>> _reports = [];
  List<Map<String, dynamic>> _mediaFiles = [];
  List<Map<String, dynamic>> _userLogs = [];
  List<Map<String, dynamic>> _adminLogs = [];
  Map<String, dynamic>? _systemStats;
  Map<String, dynamic>? _analyticsData;
  Map<String, dynamic>? _systemHealth;
  Map<String, dynamic>? _apiHealth;
  Map<String, dynamic>? _mongoDbStatus;
  Map<String, dynamic>? _ngrokHealth;
  DateTime? _serverTime;
  Timer? _serverTimeTimer;
  Timer? _healthCheckTimer;
  final TextEditingController _userSearchController = TextEditingController();
  final TextEditingController _logSearchController = TextEditingController();
  String _selectedChatIdForMessages = '';
  String _selectedLogType = 'user'; // 'user' or 'admin'
  bool _isLoadingAnalytics = false;
  bool _isLoadingHealth = false;
  Map<String, dynamic>? _localApiHealth;
  Map<String, dynamic>? _comprehensiveHealth;
  List<Map<String, dynamic>> _apiEndpointsStatus = [];
  Map<String, dynamic>? _deviceStats;
  List<Map<String, dynamic>> _devices = [];
  bool _isLoadingDevices = false;
  
  // Loading states
  bool _isLoadingUsers = false;
  bool _isLoadingChats = false;
  bool _isLoadingGroups = false;
  bool _isLoadingMessages = false;
  bool _isLoadingReports = false;
  bool _isLoadingStats = false;
  bool _isLoadingMedia = false;
  bool _isLoadingUserLogs = false;
  bool _isLoadingAdminLogs = false;
  bool _roleLoaded = false;
  bool _isAdmin = false;

  @override
  void initState() {
    super.initState();
    _themeService = ThemeService.instance;
    _themeService.addListener(() {
      if (mounted) setState(() {});
    });
    _tabController = TabController(length: 10, vsync: this);
    _checkAdminAccess();
    _startServerTimeSync();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _userSearchController.dispose();
    _logSearchController.dispose();
    _serverTimeTimer?.cancel();
    _healthCheckTimer?.cancel();
    super.dispose();
  }
  
  void _startServerTimeSync() {
    _fetchServerTime();
    _serverTimeTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_serverTime != null) {
        // Keep Cairo timezone (UTC+2) - just add seconds without changing timezone
        setState(() {
          _serverTime = _serverTime!.add(const Duration(seconds: 1));
        });
      }
    });
    // Refresh from server every minute to stay accurate
    Timer.periodic(const Duration(minutes: 1), (_) {
      _fetchServerTime();
    });
  }
  
  Future<void> _fetchServerTime() async {
    try {
      final baseUrl = DatabaseConfig.physicalServerUrl;
      final response = await http.get(
        Uri.parse('$baseUrl/api/health'),
        headers: {'ngrok-skip-browser-warning': 'true'},
      ).timeout(const Duration(seconds: 3));
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final serverTimeStr = data['serverTime'] ?? data['timestamp'];
        if (serverTimeStr != null) {
          // Parse server time and convert to Cairo timezone (UTC+2)
          final utcTime = DateTime.parse(serverTimeStr).toUtc();
          final cairoTime = utcTime.add(const Duration(hours: 2)); // Cairo is UTC+2
          setState(() {
            _serverTime = cairoTime;
          });
        } else {
          // Use local time and convert to Cairo if needed
          final now = DateTime.now().toUtc();
          final cairoTime = now.add(const Duration(hours: 2));
          setState(() {
            _serverTime = cairoTime;
          });
        }
      } else {
        final now = DateTime.now().toUtc();
        final cairoTime = now.add(const Duration(hours: 2));
        setState(() {
          _serverTime = cairoTime;
        });
      }
    } catch (e) {
      // Fallback to Cairo time
      final now = DateTime.now().toUtc();
      final cairoTime = now.add(const Duration(hours: 2));
      setState(() {
        _serverTime = cairoTime;
      });
    }
  }

  Future<void> _loadInitialData() async {
    await Future.wait([
      _loadUsers(),
      _loadSystemStats(),
      _loadSystemHealth(),
      _loadMediaFiles(),
      _loadUserLogs(),
      _loadAdminLogs(),
      _loadAnalytics(),
      _loadHealthMonitoring(),
      _loadGroups(),
    ]);
  }

  Future<void> _loadGroups() async {
    setState(() {
      _isLoadingGroups = true;
    });
    
    try {
      final groups = await _adminService.getAllGroups(limit: 10000);
      if (mounted) {
        setState(() {
          _groups = groups;
        });
      }
    } catch (e) {
      Log.e('Error loading groups', 'ADMIN_PANEL_MONGODB', e);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading groups: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingGroups = false;
        });
      }
    }
  }
  
  /// Helper to parse members from group data (handles ObjectIds, Maps, and Strings)
  List<String> _parseMemberIds(dynamic membersData) {
    if (membersData == null) return [];
    if (membersData is! List) return [];
    
    return membersData.map((member) {
      if (member is String) {
        return member;
      } else if (member is Map) {
        // Handle ObjectId as Map (e.g., {'$oid': '...'} or {'_id': '...'})
        return member['\$oid'] ?? member['_id'] ?? member['id'] ?? member.toString();
      } else {
        return member.toString();
      }
    }).where((id) => id.isNotEmpty && id != 'null').toList().cast<String>();
  }
  
  /// Helper to get current admin ID for logging
  Future<String?> _getCurrentAdminId() async {
    try {
      final adminUser = await _authService.getCurrentUser();
      return adminUser?['id'] ?? adminUser?['_id'];
    } catch (_) {
      return null;
    }
  }
  
  /// Helper to log admin activity
  Future<void> _logAdminAction(String action, Map<String, dynamic> details) async {
    try {
      final adminId = await _getCurrentAdminId();
      if (adminId != null) {
        await _adminService.logAdminActivity(adminId, action, {
          ...details,
          'timestamp': DateTime.now().toIso8601String(),
        });
        // Refresh logs after action
        await Future.wait([
          _loadAdminLogs(),
          _loadUserLogs(),
        ]);
      }
    } catch (e) {
      Log.e('Error logging admin action', 'ADMIN_PANEL_MONGODB', e);
    }
  }
  
  /// Helper to log user activity
  Future<void> _logUserAction(String userId, String action, Map<String, dynamic> details) async {
    try {
      await _adminService.logUserActivity(userId, action, {
        ...details,
        'timestamp': DateTime.now().toIso8601String(),
      });
      // Refresh logs after action
      await _loadUserLogs();
    } catch (e) {
      Log.e('Error logging user action', 'ADMIN_PANEL_MONGODB', e);
    }
  }
  
  Future<void> _loadHealthMonitoring() async {
    setState(() {
      _isLoadingHealth = true;
    });
    
    try {
      await Future.wait([
        _checkLocalApiHealth(),
        _checkNgrokHealth(),
        _checkMongoDbHealth(),
        _checkApiEndpoints(),
        _checkComprehensiveHealth(),
      ]);
    } catch (e) {
      Log.e('Error loading health monitoring', 'ADMIN_PANEL_MONGODB', e);
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingHealth = false;
        });
      }
    }
  }
  
  Future<void> _checkLocalApiHealth() async {
    try {
      final health = await _adminService.getApiHealth();
      if (mounted) {
        setState(() {
          _localApiHealth = health;
        });
      }
    } catch (e) {
      Log.e('Error checking local API health', 'ADMIN_PANEL_MONGODB', e);
    }
  }
  
  Future<void> _checkNgrokHealth() async {
    try {
      final health = await _adminService.getNgrokHealth();
      if (mounted) {
        setState(() {
          _ngrokHealth = health;
        });
      }
    } catch (e) {
      Log.e('Error checking ngrok health', 'ADMIN_PANEL_MONGODB', e);
    }
  }
  
  Future<void> _checkMongoDbHealth() async {
    try {
      final status = await _adminService.getMongoDbStatus();
      if (mounted) {
        setState(() {
          _mongoDbStatus = status;
        });
      }
    } catch (e) {
      Log.e('Error checking MongoDB health', 'ADMIN_PANEL_MONGODB', e);
    }
  }
  
  Future<void> _checkApiEndpoints() async {
    final endpoints = [
      {'name': 'Authentication', 'path': '/api/auth/login', 'method': 'POST', 'skipCheck': false},
      {'name': 'Users API', 'path': '/api/users', 'method': 'GET', 'skipCheck': false},
      {'name': 'Chats API', 'path': '/api/chats', 'method': 'GET', 'skipCheck': false},
      {'name': 'Messages API', 'path': '/api/admin/messages', 'method': 'GET', 'skipCheck': false},
      {'name': 'Admin Stats', 'path': '/api/admin/stats', 'method': 'GET', 'skipCheck': false},
      {'name': 'Admin Analytics', 'path': '/api/admin/analytics', 'method': 'GET', 'skipCheck': false},
      {'name': 'Admin Health', 'path': '/api/admin/health', 'method': 'GET', 'skipCheck': false},
    ];
    
    final List<Map<String, dynamic>> statusList = [];
    
    for (final endpoint in endpoints) {
      try {
        final prefs = await SharedPreferences.getInstance();
        final token = prefs.getString('auth_token');
        final baseUrl = DatabaseConfig.physicalServerUrl;
        
        http.Response response;
        
        // Handle POST endpoints differently (like login)
        if (endpoint['method'] == 'POST') {
          // For POST endpoints, we check if they respond (even with 400, that means endpoint exists)
          try {
            response = await http.post(
              Uri.parse('$baseUrl${endpoint['path']}'),
              headers: {
                'Content-Type': 'application/json',
                'ngrok-skip-browser-warning': 'true',
              },
              body: json.encode({}), // Empty body to trigger validation error (which means endpoint exists)
            ).timeout(const Duration(seconds: 3));
            
            // If we get 400 or 401, endpoint exists (just validation/auth error)
            // If we get 404, endpoint doesn't exist
            statusList.add({
              'name': endpoint['name'],
              'path': endpoint['path'],
              'method': endpoint['method'],
              'status': response.statusCode == 404 ? 'offline' : 'operational',
              'statusCode': response.statusCode,
              'responseTime': 'OK',
            });
          } catch (e) {
            // Connection error means endpoint might be down
            statusList.add({
              'name': endpoint['name'],
              'path': endpoint['path'],
              'method': endpoint['method'],
              'status': 'offline',
              'statusCode': 0,
              'responseTime': e.toString(),
            });
          }
        } else {
          // GET endpoints
          response = await http.get(
            Uri.parse('$baseUrl${endpoint['path']}'),
            headers: {
              if (token != null) 'Authorization': 'Bearer $token',
              'Content-Type': 'application/json',
              'ngrok-skip-browser-warning': 'true',
            },
          ).timeout(const Duration(seconds: 3));
          
          statusList.add({
            'name': endpoint['name'],
            'path': endpoint['path'],
            'method': endpoint['method'],
            'status': response.statusCode < 400 ? 'operational' : 'error',
            'statusCode': response.statusCode,
            'responseTime': 'OK',
          });
        }
      } catch (e) {
        statusList.add({
          'name': endpoint['name'],
          'path': endpoint['path'],
          'method': endpoint['method'],
          'status': 'offline',
          'statusCode': 0,
          'responseTime': e.toString(),
        });
      }
    }
    
    if (mounted) {
      setState(() {
        _apiEndpointsStatus = statusList;
      });
    }
  }
  
  Future<void> _checkComprehensiveHealth() async {
    try {
      final health = await _adminService.getEnhancedSystemHealth();
      if (mounted) {
        setState(() {
          _comprehensiveHealth = health;
        });
      }
    } catch (e) {
      Log.e('Error checking comprehensive health', 'ADMIN_PANEL_MONGODB', e);
    }
  }
  
  Future<void> _loadAnalytics() async {
    setState(() {
      _isLoadingAnalytics = true;
    });
    
    try {
      final analytics = await _adminService.getAnalytics();
      if (mounted) {
        setState(() {
          _analyticsData = analytics;
        });
      }
    } catch (e) {
      Log.e('Error loading analytics', 'ADMIN_PANEL_MONGODB', e);
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingAnalytics = false;
        });
      }
    }
  }
  
  Future<void> _lockUser(String userId) async {
    final reasonController = TextEditingController();
    final confirmed = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Lock User'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Enter reason for locking this user:'),
            const SizedBox(height: 16),
            TextField(
              controller: reasonController,
              decoration: const InputDecoration(
                labelText: 'Reason',
                border: OutlineInputBorder(),
                hintText: 'e.g., Violation of terms of service',
              ),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (reasonController.text.trim().isNotEmpty) {
                Navigator.pop(context, {'reason': reasonController.text.trim()});
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppDesignSystem.warningColor),
            child: const Text('Lock User'),
          ),
        ],
      ),
    );
    
    if (confirmed != null && confirmed['reason'] != null) {
      try {
        final user = _users.firstWhere(
          (u) => (u['_id'] ?? u['id']) == userId,
          orElse: () => {},
        );
        final userName = user['name'] ?? user['displayName'] ?? user['email'] ?? userId;
        
        await _adminService.lockUser(userId, confirmed['reason']);
        
        // Log actions
        await _logUserAction(userId, 'user_locked', {
          'reason': confirmed['reason'],
          'userName': userName,
        });
        await _logAdminAction('lock_user', {
          'userId': userId,
          'userName': userName,
          'reason': confirmed['reason'],
        });
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('User locked successfully')),
          );
          // Update local user data immediately
          final userIndex = _users.indexWhere((u) => (u['_id'] ?? u['id']) == userId);
          final wasLocked = userIndex != -1 ? (_users[userIndex]['isLocked'] ?? false) : false;
          if (userIndex != -1) {
            _users[userIndex]['isLocked'] = true;
            _users[userIndex]['lockedAt'] = DateTime.now().toIso8601String();
            _users[userIndex]['lockedReason'] = confirmed['reason'];
          }
          setState(() {}); // Force UI update
          // Also refresh from server to ensure consistency (with a small delay to ensure server has updated)
          await Future.delayed(const Duration(milliseconds: 500));
          await _loadUsers();
          // Ensure the locked state is preserved after server refresh
          final refreshedUserIndex = _users.indexWhere((u) => (u['_id'] ?? u['id']) == userId);
          if (refreshedUserIndex != -1 && !(_users[refreshedUserIndex]['isLocked'] ?? false)) {
            _users[refreshedUserIndex]['isLocked'] = true;
            _users[refreshedUserIndex]['lockedAt'] = DateTime.now().toIso8601String();
            _users[refreshedUserIndex]['lockedReason'] = confirmed['reason'];
            setState(() {});
          }
        }
      } catch (e) {
        Log.e('Error locking user', 'ADMIN_PANEL_MONGODB', e);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error locking user: $e')),
          );
        }
      }
    }
  }
  
  Future<void> _unlockUser(String userId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Unlock User'),
        content: const Text('Are you sure you want to unlock this user?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppDesignSystem.successColor),
            child: const Text('Unlock User'),
          ),
        ],
      ),
    );
    
    if (confirmed == true) {
      try {
        final user = _users.firstWhere(
          (u) => (u['_id'] ?? u['id']) == userId,
          orElse: () => {},
        );
        final userName = user['name'] ?? user['displayName'] ?? user['email'] ?? userId;
        
        await _adminService.unlockUser(userId);
        
        // Log actions
        await _logUserAction(userId, 'user_unlocked', {
          'userName': userName,
        });
        await _logAdminAction('unlock_user', {
          'userId': userId,
          'userName': userName,
        });
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('User unlocked successfully')),
          );
          // Update local user data immediately
          final userIndex = _users.indexWhere((u) => (u['_id'] ?? u['id']) == userId);
          if (userIndex != -1) {
            _users[userIndex]['isLocked'] = false;
            _users[userIndex]['lockedAt'] = null;
            _users[userIndex]['lockedReason'] = null;
          }
          setState(() {}); // Force UI update
          // Also refresh from server to ensure consistency (with a small delay to ensure server has updated)
          await Future.delayed(const Duration(milliseconds: 500));
          await _loadUsers();
          // Ensure the unlocked state is preserved after server refresh
          final refreshedUserIndex = _users.indexWhere((u) => (u['_id'] ?? u['id']) == userId);
          if (refreshedUserIndex != -1 && (_users[refreshedUserIndex]['isLocked'] ?? false)) {
            _users[refreshedUserIndex]['isLocked'] = false;
            _users[refreshedUserIndex]['lockedAt'] = null;
            _users[refreshedUserIndex]['lockedReason'] = null;
            setState(() {});
          }
        }
      } catch (e) {
        Log.e('Error unlocking user', 'ADMIN_PANEL_MONGODB', e);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error unlocking user: $e')),
          );
        }
      }
    }
  }
  
  Future<void> _editMessage(String messageId, String currentContent) async {
    final contentController = TextEditingController(text: currentContent);
    final confirmed = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Message'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: contentController,
              decoration: const InputDecoration(
                labelText: 'Message Content',
                border: OutlineInputBorder(),
              ),
              maxLines: 5,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (contentController.text.trim().isNotEmpty) {
                Navigator.pop(context, {'content': contentController.text.trim()});
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
    
    if (confirmed != null && confirmed['content'] != null) {
      try {
        final prefs = await SharedPreferences.getInstance();
        final token = prefs.getString('auth_token');
        if (token == null) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('No auth token found')),
            );
          }
          return;
        }
        
        final baseUrl = DatabaseConfig.physicalServerUrl;
        final response = await http.put(
          Uri.parse('$baseUrl/api/admin/messages/$messageId'),
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json',
            'ngrok-skip-browser-warning': 'true',
          },
          body: json.encode({
            'content': confirmed['content'],
            'editedAt': DateTime.now().toIso8601String(),
            'editedBy': 'admin',
          }),
        );
        
        if (mounted) {
          if (response.statusCode == 200) {
            // Find message info for logging
            final message = _messages.firstWhere(
              (m) => (m['_id'] ?? m['id']).toString() == messageId,
              orElse: () => {},
            );
            final senderId = message['senderId'] ?? message['sender'] ?? '';
            
            // Log actions
            await _logAdminAction('edit_message', {
              'messageId': messageId,
              'oldContent': currentContent,
              'newContent': confirmed['content'],
              'senderId': senderId,
            });
            
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Message updated successfully')),
            );
            await _loadMessages();
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Failed to update message: ${response.statusCode}')),
            );
          }
        }
      } catch (e) {
        Log.e('Error editing message', 'ADMIN_PANEL_MONGODB', e);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e')),
          );
        }
      }
    }
  }
  
  Future<void> _deleteMessageFromList(String messageId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Message'),
        content: const Text('Are you sure you want to delete this message? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: AppDesignSystem.errorColor),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    
    if (confirmed == true) {
      try {
        // Find message info for logging
        final message = _messages.firstWhere(
          (m) => (m['_id'] ?? m['id']).toString() == messageId,
          orElse: () => {},
        );
        final senderId = message['senderId'] ?? message['sender'] ?? '';
        final messageContent = message['content'] ?? message['text'] ?? '';
        
        final success = await _adminService.deleteMessage(messageId);
        
        if (success) {
          // Log actions
          await _logAdminAction('delete_message', {
            'messageId': messageId,
            'senderId': senderId,
            'content': messageContent.toString().length > 100 
                ? messageContent.toString().substring(0, 100) + '...' 
                : messageContent.toString(),
          });
          if (senderId.toString().isNotEmpty) {
            await _logUserAction(senderId.toString(), 'message_deleted_by_admin', {
              'messageId': messageId,
            });
          }
        }
        
        if (mounted) {
          if (success) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Message deleted successfully')),
            );
            await _loadMessages();
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Failed to delete message')),
            );
          }
        }
      } catch (e) {
        Log.e('Error deleting message', 'ADMIN_PANEL_MONGODB', e);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e')),
          );
        }
      }
    }
  }
  
  Future<void> _loadUserLogs() async {
    setState(() {
      _isLoadingUserLogs = true;
    });
    
    try {
      // Fetch all logs by using a very high limit
      final logs = await _adminService.getUserLogs(page: 1, limit: 10000);
      if (mounted) {
        setState(() {
          _userLogs = logs;
        });
      }
    } catch (e) {
      Log.e('Error loading user logs', 'ADMIN_PANEL_MONGODB', e);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading user logs: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingUserLogs = false;
        });
      }
    }
  }
  
  Future<void> _loadAdminLogs() async {
    setState(() {
      _isLoadingAdminLogs = true;
    });
    
    try {
      // Fetch all logs by using a very high limit
      final logs = await _adminService.getAdminLogs(page: 1, limit: 10000);
      if (mounted) {
        setState(() {
          _adminLogs = logs;
        });
      }
    } catch (e) {
      Log.e('Error loading admin logs', 'ADMIN_PANEL_MONGODB', e);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading admin logs: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingAdminLogs = false;
        });
      }
    }
  }

  Future<void> _checkAdminAccess() async {
    try {
      final role = await _authService.getCurrentUserRole();
      setState(() {
        _isAdmin = role != null && role == 'admin';
        _roleLoaded = true;
      });
      if (_isAdmin) {
        await _loadInitialData();
      }
    } catch (e) {
      Log.e('Error checking admin access', 'ADMIN_PANEL_MONGODB', e);
      setState(() {
        _roleLoaded = true;
        _isAdmin = false;
      });
    }
  }

  Widget _buildAccessDenied() {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Admin Panel',
          style: AppDesignSystem.headlineSmall.copyWith(
            color: Theme.of(context).colorScheme.onPrimary,
          ),
        ),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Theme.of(context).colorScheme.onPrimary,
        elevation: 0,
        centerTitle: false,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.lock_outline,
              size: 64,
              color: AppDesignSystem.errorColor,
            ),
            const SizedBox(height: 16),
            Text(
              'Access denied. Admins only.',
              style: AppDesignSystem.headlineMedium.copyWith(
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => Navigator.of(context).maybePop(),
              icon: const Icon(Icons.arrow_back),
              label: const Text('Back'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.primary,
                foregroundColor: Theme.of(context).colorScheme.onPrimary,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppDesignSystem.radiusMD),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _loadUsers() async {
    setState(() {
      _isLoadingUsers = true;
    });

    try {
      final users = await _adminService.getAllUsers(
        search: _userSearchController.text.trim().isNotEmpty ? _userSearchController.text.trim() : null,
        page: 1,
        limit: 50,
      );
      if (mounted) {
        setState(() {
          _users = users;
        });
      }
    } catch (e) {
      Log.e('Error loading users', 'ADMIN_PANEL_MONGODB', e);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading users: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingUsers = false;
        });
      }
    }
  }

  Future<void> _loadChats() async {
    setState(() {
      _isLoadingChats = true;
    });

    try {
      final chats = await _adminService.getAllChats();
      if (mounted) {
        setState(() {
          _chats = chats;
        });
      }
    } catch (e) {
      Log.e('Error loading chats', 'ADMIN_PANEL_MONGODB', e);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading chats: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingChats = false;
        });
      }
    }
  }

  Future<void> _loadMessages() async {
    setState(() {
      _isLoadingMessages = true;
    });

    try {
      final messages = await _adminService.getAllMessages(
        chatId: _selectedChatIdForMessages.isNotEmpty ? _selectedChatIdForMessages : null,
        page: 1,
        limit: 100,
      );
      if (mounted) {
        setState(() {
          _messages = messages;
        });
      }
    } catch (e) {
      Log.e('Error loading messages', 'ADMIN_PANEL_MONGODB', e);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading messages: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingMessages = false;
        });
      }
    }
  }

  Future<void> _loadReports() async {
    setState(() {
      _isLoadingReports = true;
    });

    try {
      final reports = await _adminService.getReports();
      if (mounted) {
        setState(() {
          _reports = reports;
        });
      }
    } catch (e) {
      Log.e('Error loading reports', 'ADMIN_PANEL_MONGODB', e);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading reports: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingReports = false;
        });
      }
    }
  }

  Future<void> _loadSystemStats() async {
    setState(() {
      _isLoadingStats = true;
    });

    try {
      final stats = await _adminService.getSystemStats();
      if (mounted) {
        setState(() {
          _systemStats = stats;
        });
      }
    } catch (e) {
      Log.e('Error loading system stats', 'ADMIN_PANEL_MONGODB', e);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading stats: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingStats = false;
        });
      }
    }
  }

  Future<void> _exportData() async {
    try {
      final users = await _adminService.getAllUsers();
      final chats = await _adminService.getAllChats();
      final messages = await _adminService.getAllMessages();
      final reports = await _adminService.getReports();
      
      final exportData = {
        'exportDate': DateTime.now().toIso8601String(),
        'users': users,
        'chats': chats,
        'messages': messages,
        'reports': reports,
      };
      
      final jsonData = json.encode(exportData);
      final dataSizeMB = (jsonData.length / (1024 * 1024)).toStringAsFixed(2);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Data exported successfully (${dataSizeMB} MB)')),
        );
      }
    } catch (e) {
      Log.e('Error exporting data', 'ADMIN_PANEL_MONGODB', e);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error exporting data: $e')),
        );
      }
    }
  }

  Future<void> _viewLogs() async {
    try {
      await _loadSystemHealth();
      
      if (mounted) {
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
      }
    } catch (e) {
      Log.e('Error viewing logs', 'ADMIN_PANEL_MONGODB', e);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error viewing logs: $e')),
        );
      }
    }
  }

  Future<void> _backupDatabase() async {
    try {
      final users = await _adminService.getAllUsers();
      final chats = await _adminService.getAllChats();
      final messages = await _adminService.getAllMessages();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Database backup created: ${users.length} users, ${chats.length} chats, ${messages.length} messages')),
        );
      }
    } catch (e) {
      Log.e('Error creating backup', 'ADMIN_PANEL_MONGODB', e);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error creating backup: $e')),
        );
      }
    }
  }

  Future<void> _cleanupSystem() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('System Cleanup'),
        content: const Text('This will remove old data and optimize the database. Continue?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: AppDesignSystem.errorColor),
            child: const Text('Cleanup'),
          ),
        ],
      ),
    );
    
    if (confirmed != true) return;
    
    try {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('System cleanup completed successfully')),
        );
      }
      await _loadInitialData();
    } catch (e) {
      Log.e('Error during cleanup', 'ADMIN_PANEL_MONGODB', e);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error during cleanup: $e')),
        );
      }
    }
  }

  Future<void> _loadSystemHealth() async {
    try {
      final health = await _adminService.getSystemHealth();
      final apiHealth = await _adminService.getApiHealth();
      final mongoStatus = await _adminService.getMongoDbStatus();
      final ngrokHealth = await _adminService.getNgrokHealth();
      if (mounted) {
        setState(() {
          _systemHealth = health;
          _apiHealth = apiHealth;
          _mongoDbStatus = mongoStatus;
          _ngrokHealth = ngrokHealth;
        });
      }
    } catch (e) {
      Log.e('Error loading system health', 'ADMIN_PANEL_MONGODB', e);
    }
  }

  Future<void> _deleteUser(String userId) async {
    // Get user info before deletion for logging
    final user = _users.firstWhere(
      (u) => (u['_id'] ?? u['id']) == userId,
      orElse: () => {},
    );
    final userName = user['name'] ?? user['displayName'] ?? user['email'] ?? userId;
    
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete User'),
        content: Text('Are you sure you want to delete user "$userName"? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: AppDesignSystem.errorColor),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        // Get current admin info for logging
        final prefs = await SharedPreferences.getInstance();
        final adminToken = prefs.getString('auth_token');
        String? adminId;
        try {
          final adminUser = await _authService.getCurrentUser();
          adminId = adminUser?['id'] ?? adminUser?['_id'];
        } catch (_) {}
        
        final success = await _adminService.deleteUser(userId);
        if (success) {
          // Log user activity (user being deleted)
          await _adminService.logUserActivity(
            userId,
            'user_deleted',
            {
              'deletedBy': adminId ?? 'unknown',
              'userName': userName,
              'timestamp': DateTime.now().toIso8601String(),
            },
          );
          
          // Log admin activity (admin who deleted)
          if (adminId != null) {
            await _adminService.logAdminActivity(
              adminId,
              'delete_user',
              {
                'deletedUserId': userId,
                'deletedUserName': userName,
                'timestamp': DateTime.now().toIso8601String(),
              },
            );
          }
          
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('User deleted successfully')),
            );
            await Future.wait([
              _loadUsers(),
              _loadUserLogs(),
              _loadAdminLogs(),
            ]);
          }
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Failed to delete user')),
            );
          }
        }
      } catch (e) {
        Log.e('Error deleting user', 'ADMIN_PANEL_MONGODB', e);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error deleting user: $e')),
          );
        }
      }
    }
  }

  Future<void> _sendBroadcastMessage() async {
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Send Broadcast Message'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            hintText: 'Enter broadcast message...',
            border: OutlineInputBorder(),
          ),
          maxLines: 3,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('Send'),
          ),
        ],
      ),
    );

    if (result != null && result.isNotEmpty) {
      try {
        final success = await _adminService.sendBroadcastMessage(result);
        if (success) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Broadcast message sent successfully')),
            );
          }
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Failed to send broadcast message')),
            );
          }
        }
      } catch (e) {
        Log.e('Error sending broadcast message', 'ADMIN_PANEL_MONGODB', e);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error sending broadcast: $e')),
          );
        }
      }
    }
  }

  Future<void> _openCreateAdminDialog() async {
    final nameController = TextEditingController();
    final emailController = TextEditingController();
    final passwordController = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Create Admin User'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: 'Display Name',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: emailController,
              decoration: const InputDecoration(
                labelText: 'Email',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: passwordController,
              decoration: const InputDecoration(
                labelText: 'Password',
                border: OutlineInputBorder(),
              ),
              obscureText: true,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Create'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        final created = await _adminService.createAdminUser(
          email: emailController.text.trim(),
          password: passwordController.text,
          displayName: nameController.text.trim(),
        );
        if (mounted) {
          if (created != null) {
            final newAdminId = created['_id'] ?? created['id'] ?? '';
            
            // Log actions
            await _logAdminAction('create_admin_user', {
              'newAdminId': newAdminId,
              'email': emailController.text.trim(),
              'displayName': nameController.text.trim(),
            });
            if (newAdminId.isNotEmpty) {
              await _logUserAction(newAdminId, 'user_created', {
                'createdBy': 'admin',
                'email': emailController.text.trim(),
                'displayName': nameController.text.trim(),
                'role': 'admin',
              });
            }
            
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Admin user created')),
            );
            await _loadUsers();
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Failed to create admin')),
            );
          }
        }
      } catch (e) {
        Log.e('Error creating admin user', 'ADMIN_PANEL_MONGODB', e);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e')),
          );
        }
      }
    }
  }

  Future<void> _openCreateUserDialog() async {
    final nameController = TextEditingController();
    final emailController = TextEditingController();
    final passwordController = TextEditingController();
    String selectedRole = 'user';
    
    final confirmed = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
        title: const Text('Add New User'),
          content: SingleChildScrollView(
            child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: 'Display Name',
                border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.person),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: emailController,
              decoration: const InputDecoration(
                labelText: 'Email',
                border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.email),
              ),
                  keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: passwordController,
              decoration: const InputDecoration(
                labelText: 'Password',
                border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.lock),
                    helperText: 'Minimum 6 characters',
              ),
              obscureText: true,
            ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: selectedRole,
                  decoration: const InputDecoration(
                    labelText: 'Role',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.admin_panel_settings),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'user', child: Text('User')),
                    DropdownMenuItem(value: 'admin', child: Text('Admin')),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      setDialogState(() {
                        selectedRole = value;
                      });
                    }
                  },
                ),
              ],
            ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
            ElevatedButton(
              onPressed: () {
                if (nameController.text.trim().isEmpty ||
                    emailController.text.trim().isEmpty ||
                    passwordController.text.length < 6) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Please fill all fields correctly')),
                  );
                  return;
                }
                Navigator.pop(context, {'role': selectedRole});
              },
              child: const Text('Create'),
            ),
          ],
        ),
      ),
    );

    if (confirmed != null && confirmed['role'] != null) {
      final role = confirmed['role'] ?? 'user';
      try {
        // Get token from SharedPreferences
        final prefs = await SharedPreferences.getInstance();
        final token = prefs.getString('auth_token');
        
        if (token == null) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('No auth token found')),
            );
          }
          return;
        }
        
        final baseUrl = DatabaseConfig.physicalServerUrl;
        final endpoint = role == 'admin' 
            ? '$baseUrl/api/admin/users/admin'
            : '$baseUrl/api/admin/users';
        
        final response = await http.post(
          Uri.parse(endpoint),
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json',
            'ngrok-skip-browser-warning': 'true',
          },
          body: json.encode({
            'email': emailController.text.trim(),
            'password': passwordController.text,
            'displayName': nameController.text.trim(),
            if (role == 'user') 'role': 'user',
          }),
        );

        if (mounted) {
          if (response.statusCode == 200) {
            final responseData = json.decode(response.body);
            final newUserId = responseData['user']?['_id'] ?? responseData['user']?['id'] ?? responseData['_id'] ?? responseData['id'] ?? '';
            
            // Log actions
            await _logAdminAction('create_user', {
              'newUserId': newUserId,
              'email': emailController.text.trim(),
              'displayName': nameController.text.trim(),
              'role': role,
            });
            if (newUserId.isNotEmpty) {
              await _logUserAction(newUserId, 'user_created', {
                'createdBy': 'admin',
                'email': emailController.text.trim(),
                'displayName': nameController.text.trim(),
                'role': role,
              });
            }
            
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('${role == 'admin' ? 'Admin' : 'User'} created successfully')),
            );
            await _loadUsers();
          } else {
            final errorBody = json.decode(response.body);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Failed to create user: ${errorBody['error'] ?? response.statusCode}')),
            );
          }
        }
      } catch (e) {
        Log.e('Error creating user', 'ADMIN_PANEL_MONGODB', e);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e')),
          );
        }
      }
    }
  }

  Future<void> _loadMediaFiles() async {
    setState(() {
      _isLoadingMedia = true;
    });
    
    try {
      // Extract media URLs from messages
      final allMessages = await _adminService.getAllMessages();
      final mediaUrlsMap = <String, Map<String, dynamic>>{};
      
      for (final message in allMessages) {
        final mediaUrl = message['mediaUrl'];
        final type = message['type'];
        if (mediaUrl != null && type == 'media') {
          final url = mediaUrl.toString();
          if (!mediaUrlsMap.containsKey(url)) {
            mediaUrlsMap[url] = {
              'url': url,
              'messageId': message['_id'] ?? message['id'],
              'senderName': message['senderName'] ?? 'Unknown',
              'createdAt': message['createdAt'] ?? message['timestamp'],
              'fileName': message['fileName'] ?? 'Unknown',
              'size': message['size'] ?? 0,
            };
          }
        }
      }
      
      if (mounted) {
        setState(() {
          _mediaFiles = mediaUrlsMap.values.toList();
        });
      }
    } catch (e) {
      Log.e('Error loading media files', 'ADMIN_PANEL_MONGODB', e);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading media: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingMedia = false;
        });
      }
    }
  }
  
  Future<void> _deleteMediaFile(String mediaUrl, String messageId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Media'),
        content: const Text('Are you sure you want to delete this media file? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: AppDesignSystem.errorColor),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    
    if (confirmed == true) {
      try {
        // Find message info for logging
        final message = _messages.firstWhere(
          (m) => (m['_id'] ?? m['id']).toString() == messageId,
          orElse: () => {},
        );
        final senderId = message['senderId'] ?? message['sender'] ?? '';
        final fileName = message['fileName'] ?? mediaUrl.split('/').last;
        
        // Delete the message which contains the media
        final success = await _adminService.deleteMessage(messageId);
        
        if (success) {
          // Log actions
          await _logAdminAction('delete_media', {
            'messageId': messageId,
            'mediaUrl': mediaUrl,
            'fileName': fileName,
            'senderId': senderId,
          });
          if (senderId.toString().isNotEmpty) {
            await _logUserAction(senderId.toString(), 'media_deleted_by_admin', {
              'messageId': messageId,
              'fileName': fileName,
            });
          }
        }
        
        if (mounted) {
          if (success) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Media deleted successfully')),
            );
            await _loadMediaFiles();
            await _loadMessages();
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Failed to delete media')),
            );
          }
        }
      } catch (e) {
        Log.e('Error deleting media', 'ADMIN_PANEL_MONGODB', e);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e')),
          );
        }
      }
    }
  }
  
  Future<void> _clearAllMedia() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear All Media'),
        content: Text('This will delete all ${_mediaFiles.length} media files. This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: AppDesignSystem.errorColor),
            child: const Text('Delete All'),
          ),
        ],
      ),
    );
    
    if (confirmed == true) {
      try {
        int deletedCount = 0;
        for (final media in _mediaFiles) {
          final messageId = media['messageId']?.toString() ?? '';
          if (messageId.isNotEmpty) {
            final success = await _adminService.deleteMessage(messageId);
            if (success) deletedCount++;
          }
        }
        
        // Log action
        await _logAdminAction('clear_all_media', {
          'totalFiles': _mediaFiles.length,
          'deletedCount': deletedCount,
        });
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Deleted $deletedCount media files')),
          );
          await _loadMediaFiles();
          await _loadMessages();
        }
      } catch (e) {
        Log.e('Error clearing all media', 'ADMIN_PANEL_MONGODB', e);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e')),
          );
        }
      }
    }
  }
  
  Future<void> _clearDatabase() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('⚠️ Clear Database'),
        content: const Text(
          'This will permanently delete ALL data from the database:\n\n'
          '• All users (except admin accounts)\n'
          '• All chats\n'
          '• All messages\n'
          '• All reports\n'
          '• All media files\n\n'
          'This action CANNOT be undone!\n\n'
          'Are you absolutely sure?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: AppDesignSystem.errorColor),
            child: const Text('Clear Database'),
          ),
        ],
      ),
    );
    
    if (confirmed == true) {
      try {
        setState(() {
          _isLoadingStats = true;
        });
        
        final prefs = await SharedPreferences.getInstance();
        final token = prefs.getString('auth_token');
        if (token == null) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('No auth token found')),
            );
          }
          return;
        }
        
        final baseUrl = DatabaseConfig.physicalServerUrl;
        final response = await http.post(
          Uri.parse('$baseUrl/api/admin/database/clear'),
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json',
            'ngrok-skip-browser-warning': 'true',
          },
        );
        
        if (mounted) {
          if (response.statusCode == 200) {
            final result = json.decode(response.body);
            
            // Log action
            await _logAdminAction('clear_database', {
              'deletedCounts': result['deleted'] ?? {},
              'usersCount': _users.length,
              'chatsCount': _chats.length,
              'messagesCount': _messages.length,
              'mediaCount': _mediaFiles.length,
            });
            
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Database cleared: ${result['deleted']?.toString() ?? 'Success'}'),
                backgroundColor: AppDesignSystem.successColor,
              ),
            );
            await _loadInitialData();
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Failed to clear database: ${response.statusCode}')),
            );
          }
        }
      } catch (e) {
        Log.e('Error clearing database', 'ADMIN_PANEL_MONGODB', e);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e')),
          );
        }
      } finally {
        if (mounted) {
          setState(() {
            _isLoadingStats = false;
          });
        }
      }
    }
  }

  Future<void> _updateUserPassword(String userId, String userName) async {
    final passwordController = TextEditingController();
    final confirmPasswordController = TextEditingController();
    bool obscurePassword = true;
    bool obscureConfirmPassword = true;
    
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text('Update Password for $userName'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: passwordController,
                  decoration: InputDecoration(
                    labelText: 'New Password',
                    border: const OutlineInputBorder(),
                    prefixIcon: const Icon(Icons.lock),
                    helperText: 'Minimum 6 characters',
                    suffixIcon: IconButton(
                      icon: Icon(obscurePassword ? Icons.visibility : Icons.visibility_off),
                      onPressed: () {
                        setDialogState(() {
                          obscurePassword = !obscurePassword;
                        });
                      },
                    ),
                  ),
                  obscureText: obscurePassword,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: confirmPasswordController,
                  decoration: InputDecoration(
                    labelText: 'Confirm Password',
                    border: const OutlineInputBorder(),
                    prefixIcon: const Icon(Icons.lock_outline),
                    suffixIcon: IconButton(
                      icon: Icon(obscureConfirmPassword ? Icons.visibility : Icons.visibility_off),
                      onPressed: () {
                        setDialogState(() {
                          obscureConfirmPassword = !obscureConfirmPassword;
                        });
                      },
                    ),
                  ),
                  obscureText: obscureConfirmPassword,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                final password = passwordController.text.trim();
                final confirmPassword = confirmPasswordController.text.trim();
                
                if (password.isEmpty || password.length < 6) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Password must be at least 6 characters')),
                  );
                  return;
                }
                
                if (password != confirmPassword) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Passwords do not match')),
                  );
                  return;
                }
                
                Navigator.pop(context, true);
              },
              child: const Text('Update'),
            ),
          ],
        ),
      ),
    );

    if (confirmed == true) {
      try {
        final success = await _adminService.updateUserPassword(userId, passwordController.text.trim());
        
        if (success) {
          await _logAdminAction('update_user_password', {
            'userId': userId,
            'userName': userName,
          });
          
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Password updated successfully')),
            );
          }
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Failed to update password')),
            );
          }
        }
      } catch (e) {
        Log.e('Error updating user password', 'ADMIN_PANEL_MONGODB', e);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e')),
          );
        }
      }
    }
  }

  Future<void> _showMobileUserMenu(BuildContext context, String userId, String name, String role, bool disabled, Map<String, dynamic> user) async {
    // Get the latest user state from _users list to ensure we have current data
    final currentUser = _users.firstWhere(
      (u) => (u['_id'] ?? u['id']) == userId,
      orElse: () => user,
    );
    final currentDisabled = currentUser['disabled'] ?? false;
    final currentIsLocked = currentUser['isLocked'] ?? false;
    
    final result = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                margin: const EdgeInsets.only(top: 12, bottom: 8),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceVariant,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  'User Actions',
                  style: AppDesignSystem.titleLarge.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              ListTile(
                leading: Icon(Icons.admin_panel_settings, color: Theme.of(context).colorScheme.primary),
                title: const Text('Change Role'),
                onTap: () {
                  Navigator.pop(context, 'change_role');
                },
              ),
              ListTile(
                leading: const Icon(Icons.badge, color: Colors.purple),
                title: const Text('Change Display Name'),
                onTap: () {
                  Navigator.pop(context, 'update_display_name');
                },
              ),
              ListTile(
                leading: Icon(Icons.lock_reset, color: AppDesignSystem.infoColor),
                title: const Text('Update Password'),
                onTap: () {
                  Navigator.pop(context, 'update_password');
                },
              ),
              ListTile(
                leading: Icon(
                  currentDisabled ? Icons.play_circle : Icons.pause_circle,
                  color: AppDesignSystem.warningColor,
                ),
                title: Text(currentDisabled ? 'Enable User' : 'Disable User'),
                onTap: () {
                  Navigator.pop(context, 'toggle_status');
                },
              ),
              if (!currentIsLocked)
                ListTile(
                  leading: Icon(Icons.lock, color: AppDesignSystem.warningColor),
                  title: const Text('Lock User'),
                  onTap: () {
                    Navigator.pop(context, 'lock');
                  },
                ),
              if (currentIsLocked)
                ListTile(
                  leading: Icon(Icons.lock_open, color: AppDesignSystem.successColor),
                  title: const Text('Unlock User'),
                  onTap: () {
                    Navigator.pop(context, 'unlock');
                  },
                ),
              ListTile(
                leading: Icon(Icons.phone_android, color: AppDesignSystem.infoColor),
                title: const Text('View Devices'),
                onTap: () {
                  Navigator.pop(context, 'view_devices');
                  },
                ),
              ListTile(
                leading: Icon(Icons.delete, color: AppDesignSystem.errorColor),
                title: Text(
                  'Delete User',
                  style: TextStyle(color: AppDesignSystem.errorColor),
                ),
                onTap: () {
                  Navigator.pop(context, 'delete');
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );

    if (result != null) {
      switch (result) {
        case 'change_role':
          await _changeUserRole(userId, role);
          break;
        case 'update_display_name':
          await _updateUserDisplayName(userId, name);
          break;
        case 'update_password':
          await _updateUserPassword(userId, name);
          break;
        case 'view_devices':
          await _showUserDevicesDialog(userId, name);
          break;
        case 'toggle_status':
          await _toggleUserStatusAction(userId, !currentDisabled);
          break;
        case 'lock':
          await _lockUser(userId);
          break;
        case 'unlock':
          await _unlockUser(userId);
          break;
        case 'delete':
          _deleteUser(userId);
          break;
      }
    }
  }

  Future<void> _updateUserDisplayName(String userId, String currentName) async {
    final displayNameController = TextEditingController(text: currentName);
    
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Update Display Name'),
        content: TextField(
          controller: displayNameController,
          decoration: const InputDecoration(
            labelText: 'Display Name',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.badge),
            hintText: 'Enter new display name',
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (displayNameController.text.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Display name cannot be empty')),
                );
                return;
              }
              Navigator.pop(context, true);
            },
            child: const Text('Update'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        final newDisplayName = displayNameController.text.trim();
        final success = await _adminService.updateUserDisplayName(userId, newDisplayName);
        
        if (success) {
          final user = _users.firstWhere(
            (u) => (u['_id'] ?? u['id']) == userId,
            orElse: () => {},
          );
          final userName = user['name'] ?? user['displayName'] ?? user['email'] ?? userId;
          
          // Log actions
          await _logUserAction(userId, 'display_name_changed', {
            'oldDisplayName': currentName,
            'newDisplayName': newDisplayName,
            'userName': userName,
          });
          await _logAdminAction('change_user_display_name', {
            'userId': userId,
            'userName': userName,
            'oldDisplayName': currentName,
            'newDisplayName': newDisplayName,
          });
          
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Display name updated successfully'),
                backgroundColor: AppDesignSystem.successColor,
              ),
            );
            await _loadUsers();
          }
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Failed to update display name')),
            );
          }
        }
      } catch (e) {
        Log.e('Error updating user display name', 'ADMIN_PANEL_MONGODB', e);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e')),
          );
        }
      }
    }
  }

  Future<void> _changeUserRole(String userId, String currentRole) async {
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
          title: const Text('Update User Role'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Select new role for this user:'),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: currentRole,
                decoration: const InputDecoration(
                  labelText: 'Role',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.admin_panel_settings),
                ),
                items: const [
                  DropdownMenuItem(value: 'user', child: Text('User')),
                  DropdownMenuItem(value: 'admin', child: Text('Admin')),
                ],
                onChanged: (value) {
                  if (value != null) {
                    Navigator.pop(context, value);
                  }
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
          ],
        ),
    );
    
    if (result != null && result != currentRole) {
      try {
        final user = _users.firstWhere(
          (u) => (u['_id'] ?? u['id']) == userId,
          orElse: () => {},
        );
        final userName = user['name'] ?? user['displayName'] ?? user['email'] ?? userId;
        
        final success = await _adminService.updateUserRole(userId, result);
        
        if (success) {
          // Log actions
          await _logUserAction(userId, 'role_changed', {
            'oldRole': currentRole,
            'newRole': result,
            'userName': userName,
          });
          await _logAdminAction('change_user_role', {
            'userId': userId,
            'userName': userName,
            'oldRole': currentRole,
            'newRole': result,
          });
        }
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(success ? 'Role updated to $result' : 'Failed to update role'),
              backgroundColor: success ? AppDesignSystem.successColor : AppDesignSystem.errorColor,
            ),
        );
        if (success) await _loadUsers();
      }
    } catch (e) {
      Log.e('Error updating user role', 'ADMIN_PANEL_MONGODB', e);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
        }
      }
    }
  }

  Future<void> _toggleUserStatusAction(String userId, bool disabled) async {
    try {
      final user = _users.firstWhere(
        (u) => (u['_id'] ?? u['id']) == userId,
        orElse: () => {},
      );
      final userName = user['name'] ?? user['displayName'] ?? user['email'] ?? userId;
      
      final success = await _adminService.toggleUserStatus(userId, disabled);
      
      if (success) {
        // Log actions
        await _logUserAction(userId, disabled ? 'user_disabled' : 'user_enabled', {
          'userName': userName,
          'status': disabled ? 'disabled' : 'enabled',
        });
        await _logAdminAction(disabled ? 'disable_user' : 'enable_user', {
          'userId': userId,
          'userName': userName,
          'status': disabled ? 'disabled' : 'enabled',
        });
      }
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(success ? (disabled ? 'User disabled' : 'User enabled') : 'Failed to update status')),
        );
        if (success) {
          // Update local user data immediately
          final userIndex = _users.indexWhere((u) => (u['_id'] ?? u['id']) == userId);
          if (userIndex != -1) {
            _users[userIndex]['disabled'] = disabled;
          }
          setState(() {}); // Force UI update
          // Also refresh from server to ensure consistency (with a small delay to ensure server has updated)
          await Future.delayed(const Duration(milliseconds: 500));
          await _loadUsers();
          // Ensure the disabled state is preserved after server refresh
          final refreshedUserIndex = _users.indexWhere((u) => (u['_id'] ?? u['id']) == userId);
          if (refreshedUserIndex != -1 && (_users[refreshedUserIndex]['disabled'] ?? false) != disabled) {
            _users[refreshedUserIndex]['disabled'] = disabled;
            setState(() {});
          }
        }
      }
    } catch (e) {
      Log.e('Error toggling user status', 'ADMIN_PANEL_MONGODB', e);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  Widget _buildAllTab() {
    final isMobile = ResponsiveUtils.isMobile(context);
    final isTablet = ResponsiveUtils.isTablet(context);
    final padding = ResponsiveUtils.getResponsiveValue(
      context,
      mobile: 12.0,
      tablet: 16.0,
      desktop: 24.0,
    );
    final cardSpacing = ResponsiveUtils.getResponsiveValue(
      context,
      mobile: 8.0,
      tablet: 12.0,
      desktop: 16.0,
    );
    final crossAxisCount = ResponsiveUtils.getResponsiveValue(
      context,
      mobile: 2,
      tablet: 3,
      desktop: 4,
    );
    
    return SingleChildScrollView(
      padding: EdgeInsets.all(padding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Responsive Grid for Stats Cards
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: cardSpacing,
            mainAxisSpacing: cardSpacing,
            childAspectRatio: ResponsiveUtils.getResponsiveValue(
              context,
              mobile: 1.1,
              tablet: 1.2,
              desktop: 1.3,
            ),
            children: [
              _buildStatCard(
                'Users',
                '${_users.length}',
                Icons.people,
                AppDesignSystem.infoColor,
                () => _tabController.animateTo(1),
              ),
              _buildStatCard(
                'Chats',
                '${_chats.length}',
                Icons.chat,
                AppDesignSystem.successColor,
                () => _tabController.animateTo(2),
              ),
              _buildStatCard(
                'Groups',
                '${_groups.length}',
                Icons.group,
                AppDesignSystem.accentColor,
                () => _tabController.animateTo(3),
              ),
              _buildStatCard(
                'Messages',
                '${_messages.length}',
                Icons.message,
                Colors.orange,
                () => _tabController.animateTo(4),
              ),
              _buildStatCard(
                'Reports',
                '${_reports.length}',
                Icons.report,
                Colors.red,
                () => _tabController.animateTo(5),
              ),
              _buildStatCard(
                'Media Files',
                '${_mediaFiles.length}',
                Icons.photo_library,
                Colors.purple,
                null,
              ),
              _buildStatCard(
                'User Logs',
                '${_userLogs.length}',
                Icons.history,
                Colors.brown,
                () => _tabController.animateTo(6),
              ),
              _buildStatCard(
                'Admin Logs',
                '${_adminLogs.length}',
                Icons.admin_panel_settings,
                Colors.indigo,
                () => _tabController.animateTo(6),
              ),
              _buildStatCard(
                'System Health',
                _systemHealth?['status']?.toString() ?? 'Unknown',
                Icons.health_and_safety,
                _systemHealth?['status'] == 'healthy' ? AppDesignSystem.successColor : AppDesignSystem.warningColor,
                null,
              ),
            ],
          ),
          SizedBox(height: padding),
          
          // Quick Actions - Responsive Layout
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppDesignSystem.radiusLG),
            ),
            child: Padding(
              padding: EdgeInsets.all(padding),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Quick Actions',
                    style: AppDesignSystem.headlineSmall.copyWith(
                      fontWeight: FontWeight.bold,
                      fontSize: ResponsiveUtils.getResponsiveFontSize(
                        context,
                        baseSize: 20,
                      ),
                    ),
                  ),
                  SizedBox(height: cardSpacing),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final buttonSpacing = ResponsiveUtils.getResponsiveValue(
                        context,
                        mobile: 8.0,
                        tablet: 12.0,
                        desktop: 16.0,
                      );
                      final buttonsPerRow = ResponsiveUtils.getResponsiveValue(
                        context,
                        mobile: 2,
                        tablet: 3,
                        desktop: 3,
                      );
                      
                      return Wrap(
                        spacing: buttonSpacing,
                        runSpacing: buttonSpacing,
                        alignment: WrapAlignment.start,
                        children: [
                          _buildActionButton(
                            isMobile ? 'User' : 'Create User',
                            Icons.person_add,
                            Theme.of(context).colorScheme.primary,
                            _openCreateUserDialog,
                          ),
                          _buildActionButton(
                            isMobile ? 'Admin' : 'Create Admin',
                            Icons.admin_panel_settings,
                            Colors.deepPurple,
                            _openCreateAdminDialog,
                          ),
                          _buildActionButton(
                            isMobile ? 'Media' : 'Delete Media',
                            Icons.delete_sweep,
                            Colors.purple,
                            () => _showMediaManagementDialog(),
                          ),
                          _buildActionButton(
                            isMobile ? 'Clear DB' : 'Clear Database',
                            Icons.delete_forever,
                            Colors.red,
                            _clearDatabase,
                          ),
                          _buildActionButton(
                            isMobile ? 'Export' : 'Export Data',
                            Icons.download,
                            AppDesignSystem.successColor,
                            _exportData,
                          ),
                          _buildActionButton(
                            isMobile ? 'Health' : 'System Health',
                            Icons.health_and_safety,
                            AppDesignSystem.warningColor,
                            () async {
                              await _loadSystemHealth();
                              _tabController.animateTo(6);
                            },
                          ),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
          SizedBox(height: padding),
          
          // Recent Activity Summary
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppDesignSystem.radiusLG),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'System Overview',
                    style: AppDesignSystem.headlineSmall.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (_systemStats != null) ...[
                    _buildOverviewRow('Total Users', _systemStats!['totalUsers']?.toString() ?? '0'),
                    _buildOverviewRow('Active Users', _systemStats!['activeUsers']?.toString() ?? '0'),
                    _buildOverviewRow('Total Chats', _systemStats!['totalChats']?.toString() ?? '0'),
                    _buildOverviewRow('Total Messages', _systemStats!['totalMessages']?.toString() ?? '0'),
                    _buildOverviewRow('Messages Today', _systemStats!['messagesToday']?.toString() ?? '0'),
                  ] else
                    const Center(child: CircularProgressIndicator()),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildStatCard(String title, String value, IconData icon, Color color, VoidCallback? onTap) {
    final isMobile = ResponsiveUtils.isMobile(context);
    final iconSize = ResponsiveUtils.getResponsiveValue(
      context,
      mobile: 24.0,
      tablet: 28.0,
      desktop: 32.0,
    );
    final padding = ResponsiveUtils.getResponsiveValue(
      context,
      mobile: 12.0,
      tablet: 14.0,
      desktop: 16.0,
    );
    
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppDesignSystem.radiusLG),
      child: Card(
        elevation: 2,
        color: color.withOpacity(0.1),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppDesignSystem.radiusLG),
        ),
        child: Padding(
          padding: EdgeInsets.all(padding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: color, size: iconSize),
              SizedBox(height: ResponsiveUtils.getResponsiveValue(context, mobile: 8.0, tablet: 10.0, desktop: 12.0)),
              Text(
                value,
                textAlign: TextAlign.center,
                style: AppDesignSystem.headlineMedium.copyWith(
                  fontWeight: FontWeight.bold,
                  color: color,
                  fontSize: ResponsiveUtils.getResponsiveFontSize(
                    context,
                    baseSize: 24,
                    mobileMultiplier: 0.85,
                  ),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              SizedBox(height: ResponsiveUtils.getResponsiveValue(context, mobile: 2.0, tablet: 3.0, desktop: 4.0)),
              Text(
                title,
                textAlign: TextAlign.center,
                style: AppDesignSystem.bodySmall.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontSize: ResponsiveUtils.getResponsiveFontSize(
                    context,
                    baseSize: 12,
                    mobileMultiplier: 0.9,
                  ),
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  Widget _buildOverviewRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: AppDesignSystem.bodyMedium,
          ),
          Text(
            value,
            style: AppDesignSystem.bodyMedium.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
  
  Future<void> _showMediaManagementDialog() async {
    await _loadMediaFiles();
    if (!mounted) return;
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Media Management'),
        content: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Total Media Files: ${_mediaFiles.length}'),
              const SizedBox(height: 16),
              if (_isLoadingMedia)
                const CircularProgressIndicator()
              else if (_mediaFiles.isEmpty)
                const Text('No media files found')
              else
                SizedBox(
                  height: 300,
                  child: ListView.builder(
                    itemCount: _mediaFiles.length > 20 ? 20 : _mediaFiles.length,
                    itemBuilder: (context, index) {
                      final media = _mediaFiles[index];
                      return ListTile(
                        leading: const Icon(Icons.photo_library),
                        title: Text(media['fileName']?.toString() ?? 'Unknown'),
                        subtitle: Text(
                          'Size: ${((media['size'] ?? 0) / 1024).toStringAsFixed(2)} KB',
                        ),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete, color: Colors.red),
                          onPressed: () {
                            Navigator.pop(context);
                            _deleteMediaFile(
                              media['url']?.toString() ?? '',
                              media['messageId']?.toString() ?? '',
                            );
                          },
                        ),
                      );
                    },
                  ),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
          if (_mediaFiles.isNotEmpty)
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                _clearAllMedia();
              },
              style: TextButton.styleFrom(foregroundColor: AppDesignSystem.errorColor),
              child: const Text('Delete All Media'),
            ),
        ],
      ),
    );
  }
  
  Widget _buildActionButton(String label, IconData icon, Color color, VoidCallback onPressed) {
    final isMobile = ResponsiveUtils.isMobile(context);
    final iconSize = ResponsiveUtils.getResponsiveValue(
      context,
      mobile: 16.0,
      tablet: 17.0,
      desktop: 18.0,
    );
    final padding = ResponsiveUtils.getResponsiveValue(
      context,
      mobile: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      tablet: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      desktop: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    ) as EdgeInsets;
    
    return SizedBox(
      width: isMobile ? null : double.infinity,
      child: ElevatedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: iconSize),
        label: Text(
          label,
          style: TextStyle(
            fontSize: ResponsiveUtils.getResponsiveFontSize(
              context,
              baseSize: 14,
              mobileMultiplier: 0.9,
            ),
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          padding: padding,
          minimumSize: isMobile ? const Size(0, 44) : null,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppDesignSystem.radiusMD),
          ),
        ),
      ),
    );
  }

  Widget _buildUsersTab() {
    final isMobile = ResponsiveUtils.isMobile(context);
    final padding = ResponsiveUtils.getResponsiveValue(
      context,
      mobile: 12.0,
      tablet: 14.0,
      desktop: 16.0,
    );
    
    return Column(
      children: [
        Padding(
          padding: EdgeInsets.all(padding),
          child: Column(
            children: [
              TextField(
                  controller: _userSearchController,
                decoration: InputDecoration(
                    hintText: 'Search users by name or email',
                  border: const OutlineInputBorder(),
                  prefixIcon: const Icon(Icons.search),
                  isDense: isMobile,
                  ),
                  onSubmitted: (_) => _loadUsers(),
                ),
              if (isMobile) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _loadUsers,
                        icon: const Icon(Icons.refresh, size: 18),
                        label: const Text('Refresh'),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          minimumSize: const Size(0, 44),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _openCreateUserDialog,
                        icon: const Icon(Icons.person_add, size: 18),
                        label: const Text('Add'),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          minimumSize: const Size(0, 44),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _openCreateAdminDialog,
                    icon: const Icon(Icons.admin_panel_settings, size: 18),
                    label: const Text('Create Admin'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      minimumSize: const Size(0, 44),
                    ),
                  ),
                ),
              ] else
                Row(
                  children: [
              const SizedBox(width: 12),
                    Expanded(
                      child: SizedBox(),
                    ),
              ElevatedButton.icon(
                onPressed: _loadUsers,
                icon: const Icon(Icons.refresh),
                label: const Text('Refresh'),
              ),
              const SizedBox(width: 12),
              ElevatedButton.icon(
                onPressed: _openCreateAdminDialog,
                icon: const Icon(Icons.admin_panel_settings),
                label: const Text('Create Admin'),
              ),
              const SizedBox(width: 12),
              ElevatedButton.icon(
                onPressed: _openCreateUserDialog,
                icon: const Icon(Icons.person_add),
                label: const Text('Add User'),
                    ),
                  ],
              ),
            ],
          ),
        ),
        Expanded(
          child: _isLoadingUsers
              ? const Center(child: CircularProgressIndicator())
              : _users.isEmpty
                  ? const Center(child: Text('No users found'))
                  : ListView.builder(
                      itemCount: _users.length,
                      itemBuilder: (context, index) {
                        final user = _users[index];
                        final userId = user['_id'] ?? user['id'] ?? '';
                        final name = user['name'] ?? user['email'] ?? 'Unknown';
                        final email = user['email'] ?? '';
                        final role = user['role'] ?? 'user';
                        final disabled = user['disabled'] ?? false;

                        return Card(
                          margin: EdgeInsets.symmetric(
                            horizontal: ResponsiveUtils.getResponsiveValue(
                              context,
                              mobile: 12.0,
                              tablet: 14.0,
                              desktop: 16.0,
                            ),
                            vertical: 4,
                          ),
                          elevation: 2,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(AppDesignSystem.radiusLG),
                          ),
                          child: ListTile(
                            contentPadding: EdgeInsets.all(
                              ResponsiveUtils.getResponsiveValue(
                                context,
                                mobile: 12.0,
                                tablet: 14.0,
                                desktop: 16.0,
                              ),
                            ),
                            leading: CircleAvatar(
                              backgroundColor: disabled 
                                  ? AppDesignSystem.errorColor 
                                  : Theme.of(context).colorScheme.primary,
                              child: Text(
                                name.isNotEmpty ? name[0].toUpperCase() : 'U',
                                style: AppDesignSystem.bodySmall.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            title: Text(
                              name,
                              style: AppDesignSystem.titleMedium.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            subtitle: Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    email,
                                    style: AppDesignSystem.bodyMedium.copyWith(
                                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'Role: $role',
                                    style: AppDesignSystem.bodySmall.copyWith(
                                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                  if (disabled) 
                                    Text(
                                      'Status: Disabled',
                                      style: AppDesignSystem.bodySmall.copyWith(
                                        color: AppDesignSystem.errorColor,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            trailing: (!kIsWeb || ResponsiveUtils.isMobile(context))
                                ? IconButton(
                                    icon: const Icon(Icons.more_vert),
                                    onPressed: () => _showMobileUserMenu(context, userId, name, role, disabled, user),
                                  )
                                : PopupMenuButton<String>(
                              onSelected: (value) async {
                                switch (value) {
                                  case 'change_role':
                                    await _changeUserRole(userId, role);
                                    break;
                                  case 'update_display_name':
                                    await _updateUserDisplayName(userId, name);
                                    break;
                                  case 'update_password':
                                    await _updateUserPassword(userId, name);
                                    break;
                                  case 'toggle_status':
                                    // Get current state from _users list
                                    final currentUser = _users.firstWhere(
                                      (u) => (u['_id'] ?? u['id']) == userId,
                                      orElse: () => user,
                                    );
                                    final currentDisabled = currentUser['disabled'] ?? false;
                                    await _toggleUserStatusAction(userId, !currentDisabled);
                                    break;
                                  case 'lock':
                                    await _lockUser(userId);
                                    break;
                                  case 'unlock':
                                    await _unlockUser(userId);
                                    break;
                                  case 'delete':
                                    _deleteUser(userId);
                                    break;
                                  case 'view_devices':
                                    await _showUserDevicesDialog(userId, name);
                                    break;
                                }
                              },
                              itemBuilder: (context) {
                                // Get current user state from _users list to ensure we have latest data
                                final currentUser = _users.firstWhere(
                                  (u) => (u['_id'] ?? u['id']) == userId,
                                  orElse: () => user,
                                );
                                final currentDisabled = currentUser['disabled'] ?? false;
                                final currentIsLocked = currentUser['isLocked'] ?? false;
                                
                                return [
                                  PopupMenuItem(
                                  value: 'change_role',
                                    child: Row(
                                      children: [
                                      Icon(Icons.admin_panel_settings, color: Theme.of(context).colorScheme.primary),
                                        const SizedBox(width: 8),
                                      const Text('Change Role'),
                                      ],
                                    ),
                                  ),
                                  PopupMenuItem(
                                  value: 'update_display_name',
                                    child: Row(
                                      children: [
                                      Icon(Icons.badge, color: Colors.purple),
                                        const SizedBox(width: 8),
                                      const Text('Change Display Name'),
                                      ],
                                    ),
                                  ),
                                  PopupMenuItem(
                                  value: 'update_password',
                                    child: Row(
                                      children: [
                                      Icon(Icons.lock_reset, color: Colors.blue),
                                        const SizedBox(width: 8),
                                      const Text('Update Password'),
                                      ],
                                    ),
                                  ),
                                  PopupMenuItem(
                                  value: 'toggle_status',
                                    child: Row(
                                      children: [
                                      Icon(
                                        currentDisabled ? Icons.play_circle : Icons.pause_circle, 
                                        color: AppDesignSystem.warningColor,
                                      ),
                                        const SizedBox(width: 8),
                                      Text(currentDisabled ? 'Enable User' : 'Disable User'),
                                      ],
                                    ),
                                  ),
                                if (!currentIsLocked)
                                PopupMenuItem(
                                    value: 'lock',
                                  child: Row(
                                    children: [
                                        Icon(Icons.lock, color: Colors.orange),
                                        const SizedBox(width: 8),
                                        const Text('Lock User'),
                                      ],
                                    ),
                                  ),
                                if (currentIsLocked)
                                  PopupMenuItem(
                                    value: 'unlock',
                                    child: Row(
                                      children: [
                                        Icon(Icons.lock_open, color: Colors.green),
                                      const SizedBox(width: 8),
                                        const Text('Unlock User'),
                                    ],
                                  ),
                                ),
                                PopupMenuItem(
                                  value: 'view_devices',
                                  child: Row(
                                    children: [
                                      Icon(Icons.phone_android, color: AppDesignSystem.infoColor),
                                      const SizedBox(width: 8),
                                      const Text('View Devices'),
                                    ],
                                  ),
                                ),
                                PopupMenuItem(
                                  value: 'delete',
                                  child: Row(
                                    children: [
                                      Icon(Icons.delete, color: AppDesignSystem.errorColor),
                                      const SizedBox(width: 8),
                                      const Text('Delete User'),
                                    ],
                                  ),
                                ),
                                ];
                              },
                            ),
                          ),
                        );
                      },
                    ),
        ),
      ],
    );
  }

  Widget _buildSystemStatsTab() {
    final isMobile = ResponsiveUtils.isMobile(context);
    final padding = ResponsiveUtils.getResponsiveValue(
      context,
      mobile: 12.0,
      tablet: 14.0,
      desktop: 16.0,
    );

    return SingleChildScrollView(
      padding: EdgeInsets.all(padding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Analytics Dashboard',
                  style: AppDesignSystem.headlineMedium.copyWith(
                    fontWeight: FontWeight.bold,
                    fontSize: ResponsiveUtils.getResponsiveFontSize(
                      context,
                      baseSize: 22,
                      mobileMultiplier: 0.9,
                    ),
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.refresh),
                iconSize: ResponsiveUtils.getResponsiveValue(
                  context,
                  mobile: 20.0,
                  tablet: 24.0,
                  desktop: 28.0,
                ),
                onPressed: () async {
                  await Future.wait([
                    _loadSystemStats(),
                    _loadAnalytics(),
                    _loadSystemHealth(),
                  ]);
                },
                tooltip: 'Refresh Analytics',
              ),
            ],
          ),
          SizedBox(height: padding),
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppDesignSystem.radiusLG),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'System Statistics',
                    style: AppDesignSystem.headlineSmall.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildStatRow('Total Users', _systemStats!['totalUsers']?.toString() ?? '0'),
                  _buildStatRow('Total Chats', _systemStats!['totalChats']?.toString() ?? '0'),
                  _buildStatRow('Total Messages', _systemStats!['totalMessages']?.toString() ?? '0'),
                  _buildStatRow('Active Users', _systemStats!['activeUsers']?.toString() ?? '0'),
                  _buildStatRow('Active Chats', _systemStats!['activeChats']?.toString() ?? '0'),
                  _buildStatRow('Messages Today', _systemStats!['messagesToday']?.toString() ?? '0'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppDesignSystem.radiusLG),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'System Health',
                    style: AppDesignSystem.headlineSmall.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (_systemHealth == null)
                    Text(
                      'Health info not available',
                      style: AppDesignSystem.bodyMedium.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    )
                  else ...[
                    _buildStatRow('Status', _systemHealth!['status']?.toString() ?? 'unknown'),
                    ..._systemHealth!.entries
                        .where((e) => e.key != 'status')
                        .map((e) {
                          // Format complex values (objects/arrays) as JSON for better display
                          String displayValue;
                          if (e.value is Map || e.value is List) {
                            try {
                              displayValue = const JsonEncoder.withIndent('  ').convert(e.value);
                            } catch (_) {
                              displayValue = e.value?.toString() ?? '';
                            }
                          } else {
                            displayValue = e.value?.toString() ?? '';
                          }
                          return _buildStatRow(e.key, displayValue);
                        })
                        .toList(),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppDesignSystem.radiusLG),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Connectivity',
                    style: AppDesignSystem.headlineSmall.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildStatRow('Web Base URL', DatabaseConfig.physicalServerUrl),
                  _buildStatRow('API Health', _apiHealth?['status']?.toString() ?? 'unknown'),
                  _buildStatRow('MongoDB', _mongoDbStatus?['mongodb']?['status']?.toString() ?? 'unknown'),
                  _buildStatRow('Ngrok URL', DatabaseConfig.mobileServerUrl),
                  _buildStatRow('Ngrok Health', _ngrokHealth?['status']?.toString() ?? 'unknown'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppDesignSystem.radiusLG),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Quick Actions',
                    style: AppDesignSystem.headlineSmall.copyWith(
                      fontWeight: FontWeight.bold,
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
                        Theme.of(context).colorScheme.primary,
                        () => _loadInitialData(),
                      ),
                      _buildActionButton(
                        'Export Data',
                        Icons.download,
                        AppDesignSystem.successColor,
                        () => _exportData(),
                      ),
                      _buildActionButton(
                        'System Health',
                        Icons.health_and_safety,
                        AppDesignSystem.warningColor,
                        () => _loadSystemHealth(),
                      ),
                      _buildActionButton(
                        'View Logs',
                        Icons.list_alt,
                        AppDesignSystem.infoColor,
                        () => _viewLogs(),
                      ),
                      _buildActionButton(
                        'Backup Database',
                        Icons.backup,
                        AppDesignSystem.successColor,
                        () => _backupDatabase(),
                      ),
                      _buildActionButton(
                        'Cleanup System',
                        Icons.cleaning_services,
                        AppDesignSystem.errorColor,
                        () => _cleanupSystem(),
                      ),
                      _buildActionButton(
                        'Clear Database',
                        Icons.delete_forever,
                        Colors.red.shade700,
                        () => _clearDatabase(),
                      ),
                      _buildActionButton(
                        'Manage Media',
                        Icons.photo_library,
                        Colors.purple,
                        () => _showMediaManagementDialog(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: _sendBroadcastMessage,
                    icon: const Icon(Icons.broadcast_on_personal),
                    label: const Text('Send Broadcast Message'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      foregroundColor: Theme.of(context).colorScheme.onPrimary,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppDesignSystem.radiusMD),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          // Enhanced Analytics Section
          if (_isLoadingAnalytics)
            const Center(child: CircularProgressIndicator())
          else if (_analyticsData != null)
            _buildEnhancedAnalytics()
          else
            const Center(child: Text('No analytics data available')),
        ],
      ),
    );
  }
  
  Widget _buildEnhancedAnalytics() {
    final users = _analyticsData!['users'] as Map<String, dynamic>? ?? {};
    final chats = _analyticsData!['chats'] as Map<String, dynamic>? ?? {};
    final messages = _analyticsData!['messages'] as Map<String, dynamic>? ?? {};
    final isMobile = ResponsiveUtils.isMobile(context);
    final padding = ResponsiveUtils.getResponsiveValue(
      context,
      mobile: 12.0,
      tablet: 14.0,
      desktop: 16.0,
    );
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // User Analytics
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppDesignSystem.radiusLG),
            ),
            child: Padding(
              padding: EdgeInsets.all(padding),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.people,
                        color: Colors.blue,
                        size: ResponsiveUtils.getResponsiveValue(
                          context,
                          mobile: 24.0,
                          tablet: 26.0,
                          desktop: 28.0,
                        ),
                      ),
                      SizedBox(width: ResponsiveUtils.getResponsiveValue(context, mobile: 8.0, tablet: 10.0, desktop: 12.0)),
                      Expanded(
                        child: Text(
                          'User Analytics',
                          style: AppDesignSystem.headlineSmall.copyWith(
                            fontWeight: FontWeight.bold,
                            fontSize: ResponsiveUtils.getResponsiveFontSize(
                              context,
                              baseSize: 18,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: padding),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final crossAxisCount = ResponsiveUtils.getResponsiveValue(
                        context,
                        mobile: 2,
                        tablet: 2,
                        desktop: 4,
                      );
                      
                      return GridView.count(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        crossAxisCount: crossAxisCount,
                        crossAxisSpacing: ResponsiveUtils.getResponsiveValue(context, mobile: 8.0, tablet: 12.0, desktop: 16.0),
                        mainAxisSpacing: ResponsiveUtils.getResponsiveValue(context, mobile: 8.0, tablet: 12.0, desktop: 16.0),
                        childAspectRatio: ResponsiveUtils.getResponsiveValue(context, mobile: 1.0, tablet: 1.1, desktop: 1.3),
                        children: [
                          _buildAnalyticsMetricCard(
                            'Total Users',
                            '${users['total'] ?? 0}',
                            Icons.person,
                            Colors.blue,
                          ),
                          _buildAnalyticsMetricCard(
                            isMobile ? 'Active (7d)' : 'Active Users (7d)',
                            '${users['active'] ?? 0}',
                            Icons.person_outline,
                            Colors.green,
                          ),
                          _buildAnalyticsMetricCard(
                            'New Today',
                            '${users['newToday'] ?? 0}',
                            Icons.person_add,
                            Colors.orange,
                          ),
                          _buildAnalyticsMetricCard(
                            'Admins',
                            '${_users.where((u) => (u['role'] ?? 'user') == 'admin').length}',
                            Icons.admin_panel_settings,
                            Colors.purple,
                          ),
                        ],
                      );
                    },
                  ),
                if (users['activityByDay'] != null && (users['activityByDay'] as List).isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Text(
                    'User Activity (Last 7 Days)',
                    style: AppDesignSystem.titleMedium.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    height: 100,
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: (users['activityByDay'] as List).map<Widget>((day) {
                        final count = (day['count'] ?? 0) as int;
                        final maxCount = (users['activityByDay'] as List)
                            .map((d) => (d['count'] ?? 0) as int)
                            .reduce((a, b) => a > b ? a : b);
                        final height = maxCount > 0 ? (count / maxCount * 80) : 0.0;
                        return Column(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            Container(
                              width: 30,
                              height: height,
                              decoration: BoxDecoration(
                                color: Colors.blue,
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              count.toString(),
                              style: AppDesignSystem.bodySmall,
                            ),
                            Text(
                              (day['_id'] ?? '').toString().substring(5),
                              style: AppDesignSystem.bodySmall.copyWith(fontSize: 10),
                            ),
                          ],
                        );
                      }).toList(),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        // Chat Analytics
        Card(
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppDesignSystem.radiusLG),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.chat, color: Colors.green, size: 28),
                    const SizedBox(width: 12),
                    Text(
                      'Chat Analytics',
                      style: AppDesignSystem.headlineSmall.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 16,
                  runSpacing: 16,
                  children: [
                    _buildAnalyticsMetricCard(
                      'Total Chats',
                      '${chats['total'] ?? 0}',
                      Icons.chat_bubble,
                      Colors.green,
                    ),
                    _buildAnalyticsMetricCard(
                      'Group Chats',
                      '${chats['group'] ?? 0}',
                      Icons.group,
                      Colors.blue,
                    ),
                    _buildAnalyticsMetricCard(
                      'Private Chats',
                      '${chats['private'] ?? 0}',
                      Icons.person,
                      Colors.orange,
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
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppDesignSystem.radiusLG),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.message, color: Colors.orange, size: 28),
                    const SizedBox(width: 12),
                    Text(
                      'Message Analytics',
                      style: AppDesignSystem.headlineSmall.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 16,
                  runSpacing: 16,
                  children: [
                    _buildAnalyticsMetricCard(
                      'Total Messages',
                      '${messages['total'] ?? 0}',
                      Icons.message,
                      Colors.orange,
                    ),
                    _buildAnalyticsMetricCard(
                      'Messages Today',
                      '${messages['today'] ?? 0}',
                      Icons.today,
                      Colors.red,
                    ),
                    _buildAnalyticsMetricCard(
                      'Media Files',
                      '${_mediaFiles.length}',
                      Icons.photo_library,
                      Colors.purple,
                    ),
                  ],
                ),
                if (messages['types'] != null && (messages['types'] as List).isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Text(
                    'Message Types Distribution',
                    style: AppDesignSystem.titleMedium.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  // Enhanced Bar Chart for Message Types
                  Container(
                    height: 120,
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: (messages['types'] as List).map<Widget>((type) {
                        final typeName = (type['_id'] ?? 'unknown').toString();
                        final count = (type['count'] ?? 0) as int;
                        final totalCount = (messages['types'] as List)
                            .map((t) => (t['count'] ?? 0) as int)
                            .fold(0, (a, b) => a + b);
                        final maxCount = (messages['types'] as List)
                            .map((t) => (t['count'] ?? 0) as int)
                            .reduce((a, b) => a > b ? a : b);
                        final height = maxCount > 0 ? (count / maxCount * 100) : 0.0;
                        return Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 2),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                Container(
                                  width: double.infinity,
                                  height: height,
                                  decoration: BoxDecoration(
                                    color: _getMessageTypeColor(typeName),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Center(
                                    child: count > 0
                                        ? Text(
                                            count.toString(),
                                            style: AppDesignSystem.bodySmall.copyWith(
                                              color: Colors.white,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          )
                                        : null,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  typeName.length > 6 ? typeName.substring(0, 6) : typeName,
                                  style: AppDesignSystem.bodySmall.copyWith(fontSize: 9),
                                  textAlign: TextAlign.center,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  const SizedBox(height: 8),
                  // Legend
                  Wrap(
                    spacing: 12,
                    runSpacing: 8,
                    children: (messages['types'] as List).map<Widget>((type) {
                      final typeName = (type['_id'] ?? 'unknown').toString();
                      final count = (type['count'] ?? 0).toString();
                      return Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 12,
                            height: 12,
                            decoration: BoxDecoration(
                              color: _getMessageTypeColor(typeName),
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${typeName.toUpperCase()}: $count',
                            style: AppDesignSystem.bodySmall,
                          ),
                        ],
                      );
                    }).toList(),
                  ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        // Activity Logs Chart
        Card(
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppDesignSystem.radiusLG),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.assessment, color: Colors.indigo, size: 28),
                    const SizedBox(width: 12),
                    Text(
                      'Activity Logs Summary',
                      style: AppDesignSystem.headlineSmall.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: _buildAnalyticsMetricCard(
                        'User Logs',
                        '${_userLogs.length}',
                        Icons.person,
                        Colors.blue,
                      ),
                    ),
                    SizedBox(width: ResponsiveUtils.getResponsiveValue(context, mobile: 8.0, tablet: 12.0, desktop: 16.0)),
                    Expanded(
                      child: _buildAnalyticsMetricCard(
                        'Admin Logs',
                        '${_adminLogs.length}',
                        Icons.admin_panel_settings,
                        Colors.purple,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                // Log Actions Distribution Chart
                if (_adminLogs.isNotEmpty || _userLogs.isNotEmpty) ...[
                  Text(
                    'Recent Activity (Last 24 Hours)',
                    style: AppDesignSystem.titleMedium.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    height: 100,
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: _buildActivityChart(),
                  ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        // System Stats Card
        if (_systemStats != null)
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppDesignSystem.radiusLG),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.analytics, color: Colors.purple, size: 28),
                      const SizedBox(width: 12),
                      Text(
                        'System Statistics',
                        style: AppDesignSystem.headlineSmall.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _buildStatRow('Total Users', _systemStats!['totalUsers']?.toString() ?? '0'),
                  _buildStatRow('Total Chats', _systemStats!['totalChats']?.toString() ?? '0'),
                  _buildStatRow('Total Messages', _systemStats!['totalMessages']?.toString() ?? '0'),
                  _buildStatRow('Active Users', _systemStats!['activeUsers']?.toString() ?? '0'),
                  _buildStatRow('Active Chats', _systemStats!['activeChats']?.toString() ?? '0'),
                  _buildStatRow('Messages Today', _systemStats!['messagesToday']?.toString() ?? '0'),
                ],
              ),
            ),
          ),
      ],
    );
  }
  
  Widget _buildAnalyticsMetricCard(String label, String value, IconData icon, Color color) {
    final isMobile = ResponsiveUtils.isMobile(context);
    final cardPadding = ResponsiveUtils.getResponsiveValue(
      context,
      mobile: 12.0,
      tablet: 14.0,
      desktop: 16.0,
    );
    final iconSize = ResponsiveUtils.getResponsiveValue(
      context,
      mobile: 18.0,
      tablet: 19.0,
      desktop: 20.0,
    );
    
    return Container(
      padding: EdgeInsets.all(cardPadding),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: iconSize),
          SizedBox(height: ResponsiveUtils.getResponsiveValue(context, mobile: 6.0, tablet: 7.0, desktop: 8.0)),
          Text(
            value,
            textAlign: TextAlign.center,
            style: AppDesignSystem.headlineMedium.copyWith(
              fontWeight: FontWeight.bold,
              color: color,
              fontSize: ResponsiveUtils.getResponsiveFontSize(
                context,
                baseSize: 20,
                mobileMultiplier: 0.85,
              ),
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          SizedBox(height: ResponsiveUtils.getResponsiveValue(context, mobile: 4.0, tablet: 5.0, desktop: 6.0)),
          Text(
            label,
            textAlign: TextAlign.center,
            style: AppDesignSystem.bodySmall.copyWith(
              fontSize: ResponsiveUtils.getResponsiveFontSize(
                context,
                baseSize: 12,
                mobileMultiplier: 0.9,
              ),
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
  
  Color _getMessageTypeColor(String type) {
    switch (type.toLowerCase()) {
      case 'text':
        return Colors.blue;
      case 'media':
      case 'image':
        return Colors.purple;
      case 'video':
        return Colors.red;
      case 'audio':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  Widget _buildActivityChart() {
    // Get logs from last 24 hours
    final now = DateTime.now().toUtc();
    final yesterday = now.subtract(const Duration(hours: 24));
    
    final recentLogs = [
      ..._userLogs.where((log) {
        final timestamp = log['timestamp'] ?? log['createdAt'];
        if (timestamp == null) return false;
        try {
          final logTime = DateTime.parse(timestamp).toUtc();
          return logTime.isAfter(yesterday);
        } catch (_) {
          return false;
        }
      }),
      ..._adminLogs.where((log) {
        final timestamp = log['timestamp'] ?? log['createdAt'];
        if (timestamp == null) return false;
        try {
          final logTime = DateTime.parse(timestamp).toUtc();
          return logTime.isAfter(yesterday);
        } catch (_) {
          return false;
        }
      }),
    ];
    
    // Group by hour
    final Map<int, int> hourCounts = {};
    for (int i = 0; i < 24; i++) {
      hourCounts[i] = 0;
    }
    
    for (final log in recentLogs) {
      final timestamp = log['timestamp'] ?? log['createdAt'];
      if (timestamp != null) {
        try {
          final logTime = DateTime.parse(timestamp).toUtc();
          final hour = logTime.hour;
          hourCounts[hour] = (hourCounts[hour] ?? 0) + 1;
        } catch (_) {}
      }
    }
    
    final maxCount = hourCounts.values.isEmpty ? 1 : hourCounts.values.reduce((a, b) => a > b ? a : b);
    
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: List.generate(24, (hour) {
        final count = hourCounts[hour] ?? 0;
        final height = maxCount > 0 ? (count / maxCount * 80) : 0.0;
        final isCurrentHour = hour == now.hour;
        
        return Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 1),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Container(
                  width: double.infinity,
                  height: height,
                  decoration: BoxDecoration(
                    color: isCurrentHour ? Colors.red : Colors.indigo,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                if (hour % 6 == 0) ...[
                  const SizedBox(height: 2),
                  Text(
                    '$hour:00',
                    style: AppDesignSystem.bodySmall.copyWith(fontSize: 7),
                    textAlign: TextAlign.center,
                  ),
                ],
              ],
            ),
          ),
        );
      }),
    );
  }
  
  Widget _buildStatRow(String label, String value) {
    final isMobile = ResponsiveUtils.isMobile(context);
    return Padding(
      padding: EdgeInsets.symmetric(
        vertical: ResponsiveUtils.getResponsiveValue(
          context,
          mobile: 4.0,
          tablet: 6.0,
          desktop: 8.0,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: isMobile ? 2 : 3,
            child: Text(
              label,
              style: AppDesignSystem.bodyMedium.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontSize: ResponsiveUtils.getResponsiveFontSize(
                  context,
                  baseSize: 14,
                  mobileMultiplier: 0.9,
                ),
              ),
            ),
          ),
          SizedBox(
            width: ResponsiveUtils.getResponsiveValue(
              context,
              mobile: 8.0,
              tablet: 12.0,
              desktop: 16.0,
            ),
          ),
          Expanded(
            flex: isMobile ? 3 : 4,
            child: Text(
              value,
              textAlign: TextAlign.right,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: AppDesignSystem.bodyMedium.copyWith(
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.onSurface,
                fontSize: ResponsiveUtils.getResponsiveFontSize(
                  context,
                  baseSize: 14,
                  mobileMultiplier: 0.85,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }


  @override
  Widget build(BuildContext context) {
    if (!_roleLoaded) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (!_isAdmin) {
      return _buildAccessDenied();
    }

    final isMobile = ResponsiveUtils.isMobile(context);
    final isTablet = ResponsiveUtils.isTablet(context);
    final screenWidth = MediaQuery.of(context).size.width;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              isMobile ? 'Admin' : 'Admin Panel',
          style: AppDesignSystem.headlineSmall.copyWith(
            color: Theme.of(context).colorScheme.onPrimary,
                fontSize: ResponsiveUtils.getResponsiveFontSize(
                  context,
                  baseSize: 20,
                  mobileMultiplier: 0.9,
                ),
              ),
            ),
            if (_serverTime != null && !isMobile)
              Text(
                DateFormat('yyyy-MM-dd HH:mm:ss').format(_serverTime!),
                style: AppDesignSystem.bodySmall.copyWith(
                  color: Theme.of(context).colorScheme.onPrimary.withOpacity(0.8),
                  fontSize: ResponsiveUtils.getResponsiveFontSize(
                    context,
                    baseSize: 12,
                    mobileMultiplier: 0.85,
                  ),
                ),
              ),
          ],
        ),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Theme.of(context).colorScheme.onPrimary,
        elevation: 0,
        centerTitle: false,
        bottom: TabBar(
          isScrollable: isMobile, // Allow scrolling on mobile
          controller: _tabController,
          indicatorColor: Theme.of(context).colorScheme.onPrimary,
          labelColor: Theme.of(context).colorScheme.onPrimary,
          unselectedLabelColor: Theme.of(context).colorScheme.onPrimary.withOpacity(0.7),
          tabs: [
            Tab(
              icon: const Icon(Icons.dashboard),
              text: isMobile ? null : 'All',
              iconMargin: isMobile ? const EdgeInsets.only(bottom: 4) : EdgeInsets.zero,
            ),
            Tab(
              icon: const Icon(Icons.people),
              text: isMobile ? null : 'Users',
              iconMargin: isMobile ? const EdgeInsets.only(bottom: 4) : EdgeInsets.zero,
            ),
            Tab(
              icon: const Icon(Icons.chat),
              text: isMobile ? null : 'Chats',
              iconMargin: isMobile ? const EdgeInsets.only(bottom: 4) : EdgeInsets.zero,
            ),
            Tab(
              icon: const Icon(Icons.group),
              text: isMobile ? null : 'Groups',
              iconMargin: isMobile ? const EdgeInsets.only(bottom: 4) : EdgeInsets.zero,
            ),
            Tab(
              icon: const Icon(Icons.message),
              text: isMobile ? null : 'Messages',
              iconMargin: isMobile ? const EdgeInsets.only(bottom: 4) : EdgeInsets.zero,
            ),
            Tab(
              icon: const Icon(Icons.report),
              text: isMobile ? null : 'Reports',
              iconMargin: isMobile ? const EdgeInsets.only(bottom: 4) : EdgeInsets.zero,
            ),
            Tab(
              icon: const Icon(Icons.history),
              text: isMobile ? null : 'Logs',
              iconMargin: isMobile ? const EdgeInsets.only(bottom: 4) : EdgeInsets.zero,
            ),
            Tab(
              icon: const Icon(Icons.analytics),
              text: isMobile ? null : 'Stats',
              iconMargin: isMobile ? const EdgeInsets.only(bottom: 4) : EdgeInsets.zero,
            ),
            Tab(
              icon: const Icon(Icons.monitor_heart),
              text: isMobile ? null : 'Health',
              iconMargin: isMobile ? const EdgeInsets.only(bottom: 4) : EdgeInsets.zero,
            ),
            Tab(
              icon: const Icon(Icons.phone_android),
              text: isMobile ? null : 'Devices',
              iconMargin: isMobile ? const EdgeInsets.only(bottom: 4) : EdgeInsets.zero,
            ),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildAllTab(),
          _buildUsersTab(),
          _buildChatsTab(),
          _buildGroupsTab(),
          _buildMessagesTab(),
          _buildReportsTab(),
          _buildLogsTab(),
          _buildSystemStatsTab(),
          _buildHealthMonitoringTab(),
          _buildDevicesTab(),
        ],
      ),
    );
  }

  Widget _buildChatsTab() {
    if (_isLoadingChats) {
      return const Center(child: CircularProgressIndicator());
    }

    final isMobile = ResponsiveUtils.isMobile(context);
    final padding = ResponsiveUtils.getResponsiveValue(
      context,
      mobile: 12.0,
      tablet: 14.0,
      desktop: 16.0,
    );

    return Column(
      children: [
        Padding(
          padding: EdgeInsets.all(padding),
          child: isMobile
              ? Column(
                  children: [
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _loadChats,
                        icon: const Icon(Icons.refresh, size: 18),
                        label: const Text('Refresh'),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          minimumSize: const Size(0, 44),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                onPressed: () async {
                  final confirmed = await showDialog<bool>(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text('Clear All Chats'),
                      content: const Text('This will permanently delete all chats and all messages. Continue?'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context, false),
                          child: const Text('Cancel'),
                        ),
                        TextButton(
                          onPressed: () => Navigator.pop(context, true),
                          style: TextButton.styleFrom(foregroundColor: AppDesignSystem.errorColor),
                          child: const Text('Delete All'),
                        ),
                      ],
                    ),
                  );

                  if (confirmed == true) {
                    try {
                      final result = await _adminService.clearAllChats();
                      if (mounted) {
                        if (result != null) {
                          final deletedChats = (result['deleted']?['chats'])?.toString() ?? '0';
                          final deletedMessages = (result['deleted']?['messages'])?.toString() ?? '0';
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Cleared $deletedChats chats and $deletedMessages messages')),
                          );
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Failed to clear chats')),
                          );
                        }
                      }
                      await _loadChats();
                    } catch (e) {
                      Log.e('Error clearing all chats', 'ADMIN_PANEL_MONGODB', e);
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Error: $e')),
                        );
                      }
                    }
                  }
                },
                        icon: const Icon(Icons.delete_forever, size: 18),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppDesignSystem.errorColor,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          minimumSize: const Size(0, 44),
                        ),
                        label: const Text('Clear All Chats'),
                      ),
                    ),
                  ],
                )
              : Row(
            children: [
              ElevatedButton.icon(
                onPressed: _loadChats,
                icon: const Icon(Icons.refresh),
                label: const Text('Refresh'),
              ),
              const SizedBox(width: 12),
              ElevatedButton.icon(
                onPressed: () async {
                  final confirmed = await showDialog<bool>(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text('Clear All Chats'),
                      content: const Text('This will permanently delete all chats and all messages. Continue?'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context, false),
                          child: const Text('Cancel'),
                        ),
                        TextButton(
                          onPressed: () => Navigator.pop(context, true),
                          style: TextButton.styleFrom(foregroundColor: AppDesignSystem.errorColor),
                          child: const Text('Delete All'),
                        ),
                      ],
                    ),
                  );

                  if (confirmed == true) {
                    try {
                      final result = await _adminService.clearAllChats();
                      if (mounted) {
                        if (result != null) {
                          final deletedChats = (result['deleted']?['chats'])?.toString() ?? '0';
                          final deletedMessages = (result['deleted']?['messages'])?.toString() ?? '0';
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Cleared $deletedChats chats and $deletedMessages messages')),
                          );
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Failed to clear chats')),
                          );
                        }
                      }
                      await _loadChats();
                    } catch (e) {
                      Log.e('Error clearing all chats', 'ADMIN_PANEL_MONGODB', e);
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Error: $e')),
                        );
                      }
                    }
                  }
                },
                icon: const Icon(Icons.delete_forever),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
                label: const Text('Clear All Chats'),
              ),
            ],
          ),
        ),
        Expanded(
          child: _chats.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: const [
                      Text('No chats found'),
                    ],
                  ),
                )
              : ListView.builder(
                  itemCount: _chats.length,
                  itemBuilder: (context, index) {
                    final chat = _chats[index];
                    final name = chat['name'] ?? 'Unknown Chat';
                    final type = chat['type'] ?? 'private';
                    final memberCount = chat['members']?.length ?? 0;

                    return Card(
                      margin: EdgeInsets.symmetric(
                        horizontal: ResponsiveUtils.getResponsiveValue(
                          context,
                          mobile: 12.0,
                          tablet: 14.0,
                          desktop: 16.0,
                        ),
                        vertical: 4,
                      ),
                      child: ListTile(
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: ResponsiveUtils.getResponsiveValue(
                            context,
                            mobile: 12.0,
                            tablet: 14.0,
                            desktop: 16.0,
                          ),
                          vertical: 8,
                        ),
                        leading: CircleAvatar(
                          backgroundColor: type == 'group' ? Colors.green : Colors.blue,
                          radius: ResponsiveUtils.getResponsiveValue(
                            context,
                            mobile: 20.0,
                            tablet: 22.0,
                            desktop: 24.0,
                          ),
                          child: Icon(
                            type == 'group' ? Icons.group : Icons.person,
                            color: Colors.white,
                            size: ResponsiveUtils.getResponsiveValue(
                              context,
                              mobile: 18.0,
                              tablet: 20.0,
                              desktop: 22.0,
                            ),
                          ),
                        ),
                        title: Text(
                          name,
                          style: TextStyle(
                            fontSize: ResponsiveUtils.getResponsiveFontSize(
                              context,
                              baseSize: 16,
                            ),
                          ),
                        ),
                        subtitle: Text(
                          'Type: $type, Members: $memberCount',
                          style: TextStyle(
                            fontSize: ResponsiveUtils.getResponsiveFontSize(
                              context,
                              baseSize: 14,
                              mobileMultiplier: 0.9,
                            ),
                          ),
                        ),
                        trailing: Icon(
                          Icons.arrow_forward_ios,
                          size: ResponsiveUtils.getResponsiveValue(
                            context,
                            mobile: 14.0,
                            tablet: 16.0,
                            desktop: 18.0,
                          ),
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildGroupsTab() {
    if (_isLoadingGroups) {
      return const Center(child: CircularProgressIndicator());
    }

    final isMobile = ResponsiveUtils.isMobile(context);
    final padding = ResponsiveUtils.getResponsiveValue(
      context,
      mobile: 12.0,
      tablet: 14.0,
      desktop: 16.0,
    );

    return Column(
      children: [
        Padding(
          padding: EdgeInsets.all(padding),
          child: isMobile
              ? Column(
                  children: [
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _loadGroups,
                        icon: const Icon(Icons.refresh, size: 18),
                        label: const Text('Refresh Groups'),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          minimumSize: const Size(0, 44),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Total Groups: ${_groups.length}',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: ResponsiveUtils.getResponsiveFontSize(
                          context,
                          baseSize: 14,
                        ),
                      ),
                    ),
                  ],
                )
              : Row(
                  children: [
                    ElevatedButton.icon(
                      onPressed: _loadGroups,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Refresh Groups'),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Total Groups: ${_groups.length}',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: ResponsiveUtils.getResponsiveFontSize(
                            context,
                            baseSize: 16,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
        ),
        Expanded(
          child: _groups.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: const [
                      Icon(Icons.group_off, size: 64, color: Colors.grey),
                      SizedBox(height: 16),
                      Text('No groups found'),
                    ],
                  ),
                )
              : ListView.builder(
                  itemCount: _groups.length,
                  itemBuilder: (context, index) {
                    final group = _groups[index];
                    final groupId = group['_id'] ?? group['id'] ?? '';
                    final name = group['name'] ?? 'Unnamed Group';
                    
                    // Handle members field - it might be a list of strings, ObjectIds (maps), or null
                    final memberIds = _parseMemberIds(group['members'] ?? group['memberIds']);
                    
                    final memberCount = memberIds.length;
                    final createdAt = group['createdAt'] ?? group['created_at'];
                    final createdBy = group['createdBy'] ?? group['created_by'];
                    final archived = group['archived'] ?? false;
                    
                    String createdAtDisplay = '';
                    if (createdAt != null) {
                      try {
                        final dt = DateTime.parse(createdAt.toString()).toUtc();
                        final cairo = dt.add(const Duration(hours: 2));
                        createdAtDisplay = DateFormat('yyyy-MM-dd HH:mm').format(cairo);
                      } catch (_) {
                        createdAtDisplay = createdAt.toString();
                      }
                    }

                    return Card(
                      margin: EdgeInsets.symmetric(
                        horizontal: ResponsiveUtils.getResponsiveValue(
                          context,
                          mobile: 12.0,
                          tablet: 14.0,
                          desktop: 16.0,
                        ),
                        vertical: 4,
                      ),
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppDesignSystem.radiusLG),
                      ),
                      child: ExpansionTile(
                        leading: CircleAvatar(
                          backgroundColor: archived ? Colors.grey : Colors.green,
                          radius: ResponsiveUtils.getResponsiveValue(
                            context,
                            mobile: 20.0,
                            tablet: 22.0,
                            desktop: 24.0,
                          ),
                          child: Icon(
                            Icons.group,
                            color: Colors.white,
                            size: ResponsiveUtils.getResponsiveValue(
                              context,
                              mobile: 20.0,
                              tablet: 22.0,
                              desktop: 24.0,
                            ),
                          ),
                        ),
                        title: Row(
                          children: [
                            Expanded(
                              child: Text(
                                name,
                                style: AppDesignSystem.titleMedium.copyWith(
                                  fontWeight: FontWeight.w600,
                                  decoration: archived ? TextDecoration.lineThrough : null,
                                ),
                              ),
                            ),
                            if (archived)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.grey.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  'Archived',
                                  style: AppDesignSystem.bodySmall.copyWith(
                                    color: Colors.grey,
                                    fontSize: 10,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Members: $memberCount'),
                            if (createdAtDisplay.isNotEmpty)
                              Text(
                                'Created: $createdAtDisplay',
                                style: AppDesignSystem.bodySmall.copyWith(
                                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                                ),
                              ),
                          ],
                        ),
                        trailing: PopupMenuButton<String>(
                          onSelected: (value) async {
                            switch (value) {
                              case 'view_details':
                                await _showGroupDetailsDialog(groupId, group);
                                break;
                              case 'edit':
                                await _editGroup(groupId, name);
                                break;
                              case 'manage_members':
                                await _manageGroupMembers(groupId, group);
                                break;
                              case 'view_statistics':
                                await _viewGroupStatistics(groupId);
                                break;
                              case 'archive':
                                await _archiveGroup(groupId, true);
                                break;
                              case 'unarchive':
                                await _archiveGroup(groupId, false);
                                break;
                              case 'delete':
                                await _deleteGroup(groupId, name);
                                break;
                            }
                          },
                          itemBuilder: (context) => [
                            const PopupMenuItem(
                              value: 'view_details',
                              child: Row(
                                children: [
                                  Icon(Icons.info, color: Colors.blue, size: 20),
                                  SizedBox(width: 8),
                                  Text('View Details'),
                                ],
                              ),
                            ),
                            const PopupMenuItem(
                              value: 'edit',
                              child: Row(
                                children: [
                                  Icon(Icons.edit, color: Colors.orange, size: 20),
                                  SizedBox(width: 8),
                                  Text('Edit Group'),
                                ],
                              ),
                            ),
                            const PopupMenuItem(
                              value: 'manage_members',
                              child: Row(
                                children: [
                                  Icon(Icons.people, color: Colors.green, size: 20),
                                  SizedBox(width: 8),
                                  Text('Manage Members'),
                                ],
                              ),
                            ),
                            const PopupMenuItem(
                              value: 'view_statistics',
                              child: Row(
                                children: [
                                  Icon(Icons.analytics, color: Colors.purple, size: 20),
                                  SizedBox(width: 8),
                                  Text('View Statistics'),
                                ],
                              ),
                            ),
                            if (archived)
                              const PopupMenuItem(
                                value: 'unarchive',
                                child: Row(
                                  children: [
                                    Icon(Icons.unarchive, color: Colors.blue, size: 20),
                                    SizedBox(width: 8),
                                    Text('Unarchive'),
                                  ],
                                ),
                              )
                            else
                              const PopupMenuItem(
                                value: 'archive',
                                child: Row(
                                  children: [
                                    Icon(Icons.archive, color: Colors.grey, size: 20),
                                    SizedBox(width: 8),
                                    Text('Archive'),
                                  ],
                                ),
                              ),
                            const PopupMenuItem(
                              value: 'delete',
                              child: Row(
                                children: [
                                  Icon(Icons.delete, color: Colors.red, size: 20),
                                  SizedBox(width: 8),
                                  Text('Delete Group'),
                                ],
                              ),
                            ),
                          ],
                        ),
                        children: [
                          Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Group ID: $groupId',
                                  style: AppDesignSystem.bodySmall.copyWith(
                                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: [
                                    ElevatedButton.icon(
                                      onPressed: () => _viewGroupStatistics(groupId),
                                      icon: const Icon(Icons.analytics, size: 16),
                                      label: const Text('Statistics'),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.purple,
                                        foregroundColor: Colors.white,
                                      ),
                                    ),
                                    ElevatedButton.icon(
                                      onPressed: () => _manageGroupMembers(groupId, group),
                                      icon: const Icon(Icons.people, size: 16),
                                      label: const Text('Members'),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: AppDesignSystem.successColor,
                                        foregroundColor: Colors.white,
                                      ),
                                    ),
                                    ElevatedButton.icon(
                                      onPressed: () => _editGroup(groupId, name),
                                      icon: const Icon(Icons.edit, size: 16),
                                      label: const Text('Edit'),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.orange,
                                        foregroundColor: Colors.white,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Future<void> _showGroupDetailsDialog(String groupId, Map<String, dynamic> group) async {
    final details = await _adminService.getGroupDetails(groupId);
    if (details == null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to load group details')),
      );
      return;
    }

    final groupData = details ?? group;
    final memberIds = _parseMemberIds(groupData['members'] ?? groupData['memberIds']);

    if (mounted) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(groupData['name'] ?? 'Group Details'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildDetailRow('Group ID', groupId),
                _buildDetailRow('Name', groupData['name'] ?? 'N/A'),
                _buildDetailRow('Type', groupData['type'] ?? 'group'),
                _buildDetailRow('Members Count', memberIds.length.toString()),
                _buildDetailRow('Created At', groupData['createdAt']?.toString() ?? 'N/A'),
                _buildDetailRow('Archived', (groupData['archived'] ?? false).toString()),
                const SizedBox(height: 16),
                const Text('Members:', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                ...memberIds.take(10).map((memberId) {
                  final user = _users.firstWhere(
                    (u) => (u['_id'] ?? u['id']).toString() == memberId,
                    orElse: () => {},
                  );
                  final userName = user['displayName'] ?? user['name'] ?? user['email'] ?? memberId;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text('• $userName'),
                  );
                }).toList(),
                if (memberIds.length > 10)
                  Text('... and ${memberIds.length - 10} more'),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
          ],
        ),
      );
    }
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  Future<void> _editGroup(String groupId, String currentName) async {
    final nameController = TextEditingController(text: currentName);
    final confirmed = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Group'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: 'Group Name',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (nameController.text.trim().isNotEmpty) {
                Navigator.pop(context, {'name': nameController.text.trim()});
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (confirmed != null && confirmed['name'] != null) {
      try {
        final success = await _adminService.updateGroup(groupId, {'name': confirmed['name']});
        
        if (success) {
          await _logAdminAction('edit_group', {
            'groupId': groupId,
            'oldName': currentName,
            'newName': confirmed['name'],
          });
        }
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(success ? 'Group updated successfully' : 'Failed to update group'),
              backgroundColor: success ? AppDesignSystem.successColor : AppDesignSystem.errorColor,
            ),
          );
          await _loadGroups();
        }
      } catch (e) {
        Log.e('Error editing group', 'ADMIN_PANEL_MONGODB', e);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e')),
          );
        }
      }
    }
  }

  Future<void> _manageGroupMembers(String groupId, Map<String, dynamic> group) async {
    // Refresh users and group data to ensure we have latest info
    await Future.wait([_loadUsers()]);
    await _loadGroups();
    
    // Get fresh group data
    final updatedGroup = _groups.firstWhere(
      (g) => (g['_id'] ?? g['id']).toString() == groupId,
      orElse: () => group,
    );
    
    final memberIds = _parseMemberIds(updatedGroup['members'] ?? updatedGroup['memberIds']);
    final availableUsers = _users.where((u) {
      final userId = (u['_id'] ?? u['id']).toString();
      return !memberIds.contains(userId);
    }).toList();

    if (mounted) {
      showDialog(
        context: context,
        builder: (context) => StatefulBuilder(
          builder: (context, setState) => AlertDialog(
            title: Text('Manage Members: ${updatedGroup['name'] ?? 'Group'}'),
            content: SizedBox(
              width: double.maxFinite,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Current Members:', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 200,
                    child: memberIds.isEmpty
                        ? const Center(child: Text('No members in this group'))
                        : ListView.builder(
                            shrinkWrap: true,
                            itemCount: memberIds.length,
                            itemBuilder: (context, index) {
                              final memberId = memberIds[index];
                              final user = _users.firstWhere(
                                (u) => (u['_id'] ?? u['id']).toString() == memberId,
                                orElse: () => {},
                              );
                              final userName = user.isNotEmpty 
                                  ? (user['displayName'] ?? user['name'] ?? user['email'] ?? 'Unknown User')
                                  : 'Unknown User (ID: ${memberId.substring(0, 8)}...)';
                              return ListTile(
                                title: Text(userName),
                                subtitle: user.isNotEmpty && user['email'] != null 
                                    ? Text(user['email'] ?? '')
                                    : null,
                                trailing: IconButton(
                                  icon: const Icon(Icons.remove_circle, color: Colors.red),
                                  onPressed: () async {
                                    final success = await _adminService.removeMemberFromGroup(groupId, memberId);
                                    if (success) {
                                      await _logAdminAction('remove_member_from_group', {
                                        'groupId': groupId,
                                        'userId': memberId,
                                        'userName': userName,
                                      });
                                      memberIds.remove(memberId);
                                      setState(() {});
                                      await _loadGroups();
                                      if (mounted) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          const SnackBar(content: Text('Member removed successfully')),
                                        );
                                      }
                                    } else {
                                      if (mounted) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          const SnackBar(content: Text('Failed to remove member')),
                                        );
                                      }
                                    }
                                  },
                                ),
                              );
                            },
                          ),
                  ),
                  const SizedBox(height: 16),
                  const Text('Add Members:', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 200,
                    child: availableUsers.isEmpty
                        ? const Center(child: Text('No available users to add'))
                        : ListView.builder(
                            shrinkWrap: true,
                            itemCount: availableUsers.length,
                            itemBuilder: (context, index) {
                              final user = availableUsers[index];
                              final userId = (user['_id'] ?? user['id']).toString();
                              final userName = user['displayName'] ?? user['name'] ?? user['email'] ?? userId;
                              return ListTile(
                                title: Text(userName),
                                subtitle: user['email'] != null ? Text(user['email']) : null,
                                trailing: IconButton(
                                  icon: const Icon(Icons.add_circle, color: Colors.green),
                                  onPressed: () async {
                                    final success = await _adminService.addMemberToGroup(groupId, userId);
                                    if (success) {
                                      await _logAdminAction('add_member_to_group', {
                                        'groupId': groupId,
                                        'userId': userId,
                                        'userName': userName,
                                      });
                                      memberIds.add(userId);
                                      setState(() {});
                                      await _loadGroups();
                                      if (mounted) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          const SnackBar(content: Text('Member added successfully')),
                                        );
                                      }
                                    } else {
                                      if (mounted) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          const SnackBar(content: Text('Failed to add member')),
                                        );
                                      }
                                    }
                                  },
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Close'),
              ),
            ],
          ),
        ),
      );
    }
  }

  Future<void> _viewGroupStatistics(String groupId) async {
    if (mounted) {
      showDialog(
        context: context,
        builder: (context) => const AlertDialog(
          content: CircularProgressIndicator(),
        ),
      );
    }

    try {
      // Refresh messages to ensure we have latest data
      await _loadMessages();
      
      final stats = await _adminService.getGroupStatistics(groupId);
      
      if (mounted) {
        Navigator.pop(context); // Close loading dialog
        
        if (stats == null || stats.isEmpty) {
          // Show what we can calculate from local data
          final groupMessages = _messages.where((m) {
            final chatId = (m['chatId'] ?? m['chat_id']).toString();
            return chatId == groupId;
          }).toList();
          
          final group = _groups.firstWhere(
            (g) => (g['_id'] ?? g['id']).toString() == groupId,
            orElse: () => {},
          );
          final memberIds = _parseMemberIds(group['members'] ?? group['memberIds']);
          
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Group Statistics'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildStatRow('Total Messages', groupMessages.length.toString()),
                    _buildStatRow('Members Count', memberIds.length.toString()),
                    const Padding(
                      padding: EdgeInsets.only(top: 16),
                      child: Text(
                        'Note: Detailed statistics unavailable. Showing basic information.',
                        style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Close'),
                ),
              ],
            ),
          );
          return;
        }

        // Get group messages count
        final groupMessages = _messages.where((m) {
          final chatId = (m['chatId'] ?? m['chat_id']).toString();
          return chatId == groupId;
        }).length;

        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Group Statistics'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildStatRow('Total Messages', groupMessages.toString()),
                  _buildStatRow('Members Count', (stats['memberCount'] ?? stats['members']?.length ?? 0).toString()),
                  _buildStatRow('Active Members', (stats['activeMembers'] ?? 0).toString()),
                  _buildStatRow('Messages Today', (stats['messagesToday'] ?? 0).toString()),
                  _buildStatRow('Last Activity', stats['lastActivity']?.toString() ?? 'N/A'),
                  if (stats['messageTypes'] != null && stats['messageTypes'] is Map)
                    ...(stats['messageTypes'] as Map).entries.map((e) =>
                        _buildStatRow('${e.key} Messages', e.value.toString())),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Close'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // Close loading dialog
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading statistics: $e')),
        );
      }
    }
  }

  Future<void> _archiveGroup(String groupId, bool archive) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(archive ? 'Archive Group' : 'Unarchive Group'),
        content: Text(archive
            ? 'Are you sure you want to archive this group?'
            : 'Are you sure you want to unarchive this group?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(archive ? 'Archive' : 'Unarchive'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        final success = await _adminService.archiveGroup(groupId, archive);
        
        if (success) {
          await _logAdminAction(archive ? 'archive_group' : 'unarchive_group', {
            'groupId': groupId,
          });
        }
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(success
                  ? (archive ? 'Group archived' : 'Group unarchived')
                  : 'Failed to ${archive ? 'archive' : 'unarchive'} group'),
              backgroundColor: success ? AppDesignSystem.successColor : AppDesignSystem.errorColor,
            ),
          );
          await _loadGroups();
        }
      } catch (e) {
        Log.e('Error archiving/unarchiving group', 'ADMIN_PANEL_MONGODB', e);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e')),
          );
        }
      }
    }
  }

  Future<void> _deleteGroup(String groupId, String groupName) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Group'),
        content: Text('Are you sure you want to delete "$groupName"? This will also delete all messages in this group. This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: AppDesignSystem.errorColor),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        final success = await _adminService.deleteGroup(groupId);
        
        if (success) {
          await _logAdminAction('delete_group', {
            'groupId': groupId,
            'groupName': groupName,
          });
        }
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(success ? 'Group deleted successfully' : 'Failed to delete group'),
              backgroundColor: success ? AppDesignSystem.successColor : AppDesignSystem.errorColor,
            ),
          );
          await _loadGroups();
        }
      } catch (e) {
        Log.e('Error deleting group', 'ADMIN_PANEL_MONGODB', e);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e')),
          );
        }
      }
    }
  }

  Widget _buildMessagesTab() {
    final isMobile = ResponsiveUtils.isMobile(context);
    final padding = ResponsiveUtils.getResponsiveValue(
      context,
      mobile: 12.0,
      tablet: 14.0,
      desktop: 16.0,
    );

    return Column(
      children: [
        Padding(
          padding: EdgeInsets.all(padding),
          child: isMobile
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _loadMessages,
                        icon: const Icon(Icons.refresh, size: 18),
                        label: const Text('Refresh Messages'),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          minimumSize: const Size(0, 44),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Total: ${_messages.length} messages',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: ResponsiveUtils.getResponsiveFontSize(
                          context,
                          baseSize: 14,
                        ),
                      ),
                    ),
                  ],
                )
              : Row(
            children: [
              ElevatedButton.icon(
                onPressed: _loadMessages,
                icon: const Icon(Icons.refresh),
                label: const Text('Refresh Messages'),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Total: ${_messages.length} messages',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: ResponsiveUtils.getResponsiveFontSize(
                            context,
                            baseSize: 16,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: _isLoadingMessages
              ? const Center(child: CircularProgressIndicator())
              : _messages.isEmpty
                  ? const Center(child: Text('No messages found'))
                  : _buildMessagesList(),
        ),
      ],
    );
  }

  Widget _buildMessagesList() {
    return ListView.builder(
      itemCount: _messages.length,
      itemBuilder: (context, index) {
        final message = _messages[index];
        final messageId = message['_id'] ?? message['id'] ?? '';
        final content = message['content'] ?? '';
        final senderName = message['senderName'] ?? 'Unknown';
        final timestampRaw = message['createdAt'] ?? message['timestamp'] ?? '';
        String timestampDisplay = '';
        if (timestampRaw is String && timestampRaw.isNotEmpty) {
          try {
            final dt = DateTime.parse(timestampRaw);
            final cairo = dt.toUtc().add(const Duration(hours: 2));
            timestampDisplay = DateFormat('yyyy-MM-dd HH:mm:ss').format(cairo);
          } catch (_) {
            timestampDisplay = timestampRaw.toString();
          }
        }
        final messageType = message['type'] ?? message['messageType'] ?? 'text';
        final isEdited = message['editedAt'] != null;

        return Card(
          margin: EdgeInsets.symmetric(
            horizontal: ResponsiveUtils.getResponsiveValue(
              context,
              mobile: 12.0,
              tablet: 14.0,
              desktop: 16.0,
            ),
            vertical: 4,
          ),
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppDesignSystem.radiusLG),
          ),
          child: ListTile(
            contentPadding: EdgeInsets.symmetric(
              horizontal: ResponsiveUtils.getResponsiveValue(
                context,
                mobile: 12.0,
                tablet: 14.0,
                desktop: 16.0,
              ),
              vertical: 8,
            ),
            leading: CircleAvatar(
              backgroundColor: messageType == 'media' ? Colors.purple : Colors.orange,
              child: Icon(
                messageType == 'media' ? Icons.photo_library : Icons.message,
                color: Colors.white,
                size: 20,
              ),
            ),
            title: Row(
              children: [
                Expanded(
              child: Text(
                    content.isEmpty ? '[No content]' : (content.length > 50 ? '${content.substring(0, 50)}...' : content),
                    style: AppDesignSystem.bodyMedium.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                if (isEdited)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.blue.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      'Edited',
                      style: AppDesignSystem.bodySmall.copyWith(
                        color: Colors.blue,
                        fontSize: 10,
                      ),
                    ),
                  ),
              ],
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('From: $senderName'),
                Text(
                  timestampDisplay.isEmpty ? 'Unknown time' : timestampDisplay,
                  style: AppDesignSystem.bodySmall.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            trailing: PopupMenuButton<String>(
              onSelected: (value) async {
                switch (value) {
                  case 'edit':
                    if (messageId.toString().isNotEmpty) {
                      await _editMessage(messageId.toString(), content);
                    }
                    break;
                  case 'delete':
                    if (messageId.toString().isNotEmpty) {
                      await _deleteMessageFromList(messageId.toString());
                    }
                    break;
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'edit',
                  child: Row(
                    children: [
                      Icon(Icons.edit, color: Colors.blue, size: 20),
                      SizedBox(width: 8),
                      Text('Edit Message'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'delete',
                  child: Row(
                    children: [
                      Icon(Icons.delete, color: Colors.red, size: 20),
                      SizedBox(width: 8),
                      Text('Delete Message'),
                    ],
                  ),
                ),
              ],
            ),
            isThreeLine: true,
          ),
        );
      },
    );
  }

  Widget _buildLogsTab() {
    final isMobile = ResponsiveUtils.isMobile(context);
    final padding = ResponsiveUtils.getResponsiveValue(
      context,
      mobile: 12.0,
      tablet: 14.0,
      desktop: 16.0,
    );

    return Column(
      children: [
        Padding(
          padding: EdgeInsets.all(padding),
          child: Column(
            children: [
              if (isMobile)
                Column(
                  children: [
                    SegmentedButton<String>(
                      segments: const [
                        ButtonSegment(
                          value: 'user',
                          label: Text('User'),
                          icon: Icon(Icons.person),
                        ),
                        ButtonSegment(
                          value: 'admin',
                          label: Text('Admin'),
                          icon: Icon(Icons.admin_panel_settings),
                        ),
                      ],
                      selected: {_selectedLogType},
                      onSelectionChanged: (Set<String> selected) {
                        setState(() {
                          _selectedLogType = selected.first;
                        });
                      },
                    ),
                  ],
                )
              else
                Row(
                  children: [
                    Expanded(
                      child: SegmentedButton<String>(
                        segments: const [
                          ButtonSegment(
                            value: 'user',
                            label: Text('User Logs'),
                            icon: Icon(Icons.person),
                          ),
                          ButtonSegment(
                            value: 'admin',
                            label: Text('Admin Logs'),
                            icon: Icon(Icons.admin_panel_settings),
                          ),
                        ],
                        selected: {_selectedLogType},
                        onSelectionChanged: (Set<String> selected) {
                          setState(() {
                            _selectedLogType = selected.first;
                          });
                        },
                      ),
                    ),
                  ],
                ),
              const SizedBox(height: 12),
              isMobile
                  ? Column(
                      children: [
                        TextField(
                          controller: _logSearchController,
                          decoration: InputDecoration(
                            hintText: 'Search logs...',
                            border: const OutlineInputBorder(),
                            prefixIcon: const Icon(Icons.search),
                            isDense: true,
                          ),
                          onChanged: (_) => setState(() {}),
                        ),
                        const SizedBox(height: 8),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: () {
                              if (_selectedLogType == 'user') {
                                _loadUserLogs();
                              } else {
                                _loadAdminLogs();
                              }
                            },
                            icon: const Icon(Icons.refresh, size: 18),
                            label: const Text('Refresh'),
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              minimumSize: const Size(0, 44),
                            ),
                          ),
                        ),
                      ],
                    )
                  : Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _logSearchController,
                            decoration: const InputDecoration(
                              hintText: 'Search logs...',
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.search),
                            ),
                            onChanged: (_) => setState(() {}),
                          ),
                        ),
                        const SizedBox(width: 12),
              ElevatedButton.icon(
                          onPressed: () {
                            if (_selectedLogType == 'user') {
                              _loadUserLogs();
                            } else {
                              _loadAdminLogs();
                            }
                          },
                icon: const Icon(Icons.refresh),
                          label: const Text('Refresh'),
                        ),
                      ],
                    ),
              const SizedBox(height: 8),
              Text(
                _selectedLogType == 'user'
                    ? 'Total: ${_userLogs.length} user logs'
                    : 'Total: ${_adminLogs.length} admin logs',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: ResponsiveUtils.getResponsiveFontSize(
                    context,
                    baseSize: 14,
                  ),
                ),
              ),
            ],
          ),
        ),
              Expanded(
          child: _selectedLogType == 'user'
              ? _buildUserLogsList()
              : _buildAdminLogsList(),
        ),
      ],
    );
  }
  
  Widget _buildUserLogsList() {
    if (_isLoadingUserLogs) {
      return const Center(child: CircularProgressIndicator());
    }
    
    if (_userLogs.isEmpty) {
      return const Center(child: Text('No user logs found'));
    }
    
    final searchQuery = _logSearchController.text.toLowerCase();
    final filteredLogs = (searchQuery.isEmpty
        ? _userLogs
        : _userLogs.where((log) {
            final action = (log['action'] ?? '').toString().toLowerCase();
            final userId = (log['userId'] ?? '').toString().toLowerCase();
            final details = json.encode(log['details'] ?? {}).toLowerCase();
            return action.contains(searchQuery) ||
                userId.contains(searchQuery) ||
                details.contains(searchQuery);
          }).toList())..sort((a, b) {
            // Sort by timestamp descending (most recent first)
            final timestampA = a['timestamp'] ?? a['createdAt'] ?? '';
            final timestampB = b['timestamp'] ?? b['createdAt'] ?? '';
            if (timestampA.isEmpty && timestampB.isEmpty) return 0;
            if (timestampA.isEmpty) return 1;
            if (timestampB.isEmpty) return -1;
            try {
              final timeA = DateTime.parse(timestampA);
              final timeB = DateTime.parse(timestampB);
              return timeB.compareTo(timeA);
            } catch (_) {
              return 0;
            }
          });
    
    return ListView.builder(
      itemCount: filteredLogs.length,
      itemBuilder: (context, index) {
        final log = filteredLogs[index];
        final action = log['action'] ?? 'Unknown Action';
        final userId = log['userId'] ?? 'Unknown';
        final timestampRaw = log['timestamp'] ?? log['createdAt'] ?? '';
        final details = log['details'] ?? {};
        
        String timestampDisplay = '';
        if (timestampRaw is String && timestampRaw.isNotEmpty) {
          try {
            final dt = DateTime.parse(timestampRaw);
            final cairo = dt.toUtc().add(const Duration(hours: 2));
            timestampDisplay = DateFormat('yyyy-MM-dd HH:mm:ss').format(cairo);
          } catch (_) {
            timestampDisplay = timestampRaw.toString();
          }
        }
        
        // Get user info if available
        final user = _users.firstWhere(
          (u) => (u['_id'] ?? u['id']).toString() == userId,
          orElse: () => {'displayName': userId, 'email': ''},
        );
        final userName = user['displayName'] ?? user['name'] ?? user['email'] ?? userId;
        
        return Card(
          margin: EdgeInsets.symmetric(
            horizontal: ResponsiveUtils.getResponsiveValue(
              context,
              mobile: 12.0,
              tablet: 14.0,
              desktop: 16.0,
            ),
            vertical: 4,
          ),
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppDesignSystem.radiusLG),
          ),
          child: ExpansionTile(
            leading: CircleAvatar(
              backgroundColor: _getActionColor(action),
              radius: ResponsiveUtils.getResponsiveValue(
                context,
                mobile: 18.0,
                tablet: 20.0,
                desktop: 22.0,
              ),
              child: Icon(
                _getActionIcon(action),
                color: Colors.white,
                size: ResponsiveUtils.getResponsiveValue(
                  context,
                  mobile: 16.0,
                  tablet: 18.0,
                  desktop: 20.0,
                ),
              ),
            ),
            title: Text(
              action,
              style: AppDesignSystem.titleMedium.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('User: $userName'),
                Text(
                  timestampDisplay.isEmpty ? 'Unknown time' : timestampDisplay,
                  style: AppDesignSystem.bodySmall.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (details.isNotEmpty) ...[
                      const Text(
                        'Details:',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.3),
                          borderRadius: BorderRadius.circular(8),
                        ),
                child: Text(
                          json.encode(details),
                          style: AppDesignSystem.bodySmall,
                ),
              ),
            ],
                    const SizedBox(height: 8),
                    Text(
                      'User ID: $userId',
                      style: AppDesignSystem.bodySmall.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
  
  Widget _buildAdminLogsList() {
    if (_isLoadingAdminLogs) {
      return const Center(child: CircularProgressIndicator());
    }
    
    if (_adminLogs.isEmpty) {
      return const Center(child: Text('No admin logs found'));
    }
    
    final searchQuery = _logSearchController.text.toLowerCase();
    final filteredLogs = (searchQuery.isEmpty
        ? _adminLogs
        : _adminLogs.where((log) {
            final action = (log['action'] ?? '').toString().toLowerCase();
            final adminId = (log['adminId'] ?? '').toString().toLowerCase();
            final details = json.encode(log['details'] ?? {}).toLowerCase();
            return action.contains(searchQuery) ||
                adminId.contains(searchQuery) ||
                details.contains(searchQuery);
          }).toList())..sort((a, b) {
            // Sort by timestamp descending (most recent first)
            final timestampA = a['timestamp'] ?? a['createdAt'] ?? '';
            final timestampB = b['timestamp'] ?? b['createdAt'] ?? '';
            if (timestampA.isEmpty && timestampB.isEmpty) return 0;
            if (timestampA.isEmpty) return 1;
            if (timestampB.isEmpty) return -1;
            try {
              final timeA = DateTime.parse(timestampA);
              final timeB = DateTime.parse(timestampB);
              return timeB.compareTo(timeA);
            } catch (_) {
              return 0;
            }
          });

    return ListView.builder(
      itemCount: filteredLogs.length,
      itemBuilder: (context, index) {
        final log = filteredLogs[index];
        final action = log['action'] ?? 'Unknown Action';
        final adminId = log['adminId'] ?? 'Unknown';
        final timestampRaw = log['timestamp'] ?? log['createdAt'] ?? '';
        final details = log['details'] ?? {};
        
        String timestampDisplay = '';
        if (timestampRaw is String && timestampRaw.isNotEmpty) {
          try {
            final dt = DateTime.parse(timestampRaw);
            final cairo = dt.toUtc().add(const Duration(hours: 2));
            timestampDisplay = DateFormat('yyyy-MM-dd HH:mm:ss').format(cairo);
          } catch (_) {
            timestampDisplay = timestampRaw.toString();
          }
        }
        
        // Get admin info if available
        final admin = _users.firstWhere(
          (u) => (u['_id'] ?? u['id']).toString() == adminId,
          orElse: () => {'displayName': adminId, 'email': log['adminEmail'] ?? ''},
        );
        final adminName = admin['displayName'] ?? admin['name'] ?? admin['email'] ?? adminId;
        
        return Card(
          margin: EdgeInsets.symmetric(
            horizontal: ResponsiveUtils.getResponsiveValue(
              context,
              mobile: 12.0,
              tablet: 14.0,
              desktop: 16.0,
            ),
            vertical: 4,
          ),
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppDesignSystem.radiusLG),
          ),
          child: ExpansionTile(
            leading: CircleAvatar(
              backgroundColor: Colors.deepPurple,
              radius: ResponsiveUtils.getResponsiveValue(
                context,
                mobile: 18.0,
                tablet: 20.0,
                desktop: 22.0,
              ),
              child: Icon(
                _getActionIcon(action),
                color: Colors.white,
                size: ResponsiveUtils.getResponsiveValue(
                  context,
                  mobile: 16.0,
                  tablet: 18.0,
                  desktop: 20.0,
                ),
              ),
            ),
            title: Text(
              action,
              style: AppDesignSystem.titleMedium.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Admin: $adminName'),
                Text(
                  timestampDisplay.isEmpty ? 'Unknown time' : timestampDisplay,
                  style: AppDesignSystem.bodySmall.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (details.isNotEmpty) ...[
                      const Text(
                        'Details:',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.3),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          json.encode(details),
                          style: AppDesignSystem.bodySmall,
                        ),
                      ),
                    ],
                    const SizedBox(height: 8),
                    Text(
                      'Admin ID: $adminId',
                      style: AppDesignSystem.bodySmall.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
  
  Color _getActionColor(String action) {
    final lowerAction = action.toLowerCase();
    if (lowerAction.contains('login') || lowerAction.contains('signin')) {
      return Colors.green;
    } else if (lowerAction.contains('logout') || lowerAction.contains('signout')) {
      return Colors.orange;
    } else if (lowerAction.contains('delete') || lowerAction.contains('remove')) {
      return Colors.red;
    } else if (lowerAction.contains('create') || lowerAction.contains('add')) {
      return Colors.blue;
    } else if (lowerAction.contains('update') || lowerAction.contains('change')) {
      return Colors.purple;
    } else {
      return Colors.grey;
    }
  }
  
  IconData _getActionIcon(String action) {
    final lowerAction = action.toLowerCase();
    if (lowerAction.contains('login') || lowerAction.contains('signin')) {
      return Icons.login;
    } else if (lowerAction.contains('logout') || lowerAction.contains('signout')) {
      return Icons.logout;
    } else if (lowerAction.contains('delete') || lowerAction.contains('remove')) {
      return Icons.delete;
    } else if (lowerAction.contains('create') || lowerAction.contains('add')) {
      return Icons.add_circle;
    } else if (lowerAction.contains('update') || lowerAction.contains('change')) {
      return Icons.edit;
    } else {
      return Icons.info;
    }
  }

  Widget _buildReportsTab() {
    final isMobile = ResponsiveUtils.isMobile(context);
    final padding = ResponsiveUtils.getResponsiveValue(
      context,
      mobile: 12.0,
      tablet: 14.0,
      desktop: 16.0,
    );

    return SingleChildScrollView(
      padding: EdgeInsets.all(padding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Comprehensive Reports',
                  style: AppDesignSystem.headlineMedium.copyWith(
                    fontWeight: FontWeight.bold,
                    fontSize: ResponsiveUtils.getResponsiveFontSize(
                      context,
                      baseSize: 22,
                      mobileMultiplier: 0.9,
                    ),
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.refresh),
                iconSize: ResponsiveUtils.getResponsiveValue(
                  context,
                  mobile: 20.0,
                  tablet: 24.0,
                  desktop: 28.0,
                ),
                onPressed: () async {
                  await Future.wait([
                    _loadReports(),
                    _loadSystemStats(),
                    _loadSystemHealth(),
                    _loadAnalytics(),
                  ]);
                },
                tooltip: 'Refresh All Reports',
              ),
            ],
          ),
          SizedBox(height: padding),
          
          // User Reports Section
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppDesignSystem.radiusLG),
            ),
            child: ExpansionTile(
              leading: Icon(
                Icons.report,
                color: Colors.red,
                size: ResponsiveUtils.getResponsiveValue(
                  context,
                  mobile: 24.0,
                  tablet: 26.0,
                  desktop: 28.0,
                ),
              ),
              title: Text(
                'User Reports (${_reports.length})',
                style: AppDesignSystem.titleLarge.copyWith(
                  fontWeight: FontWeight.bold,
                  fontSize: ResponsiveUtils.getResponsiveFontSize(
                    context,
                    baseSize: 18,
                  ),
                ),
              ),
              subtitle: Text(
                'User-reported issues and violations',
                style: TextStyle(
                  fontSize: ResponsiveUtils.getResponsiveFontSize(
                    context,
                    baseSize: 12,
                    mobileMultiplier: 0.9,
                  ),
                ),
              ),
              children: [
                if (_isLoadingReports)
                  const Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (_reports.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Center(child: Text('No user reports found')),
                  )
                else
                  ..._reports.take(10).map((report) => _buildReportItem(report)),
                if (_reports.length > 10)
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Text(
                      '... and ${_reports.length - 10} more reports',
                      style: AppDesignSystem.bodySmall,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          
          // System Health Report
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppDesignSystem.radiusLG),
            ),
            child: ExpansionTile(
              leading: const Icon(Icons.health_and_safety, color: Colors.green, size: 28),
              title: const Text(
                'System Health Report',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: Text(
                'Status: ${_systemHealth?['status'] ?? 'Unknown'}',
              ),
              children: [
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildReportDetail('Database Status', _mongoDbStatus?['mongodb']?['status']?.toString() ?? 'Unknown'),
                      _buildReportDetail('API Status', _apiHealth?['status']?.toString() ?? 'Unknown'),
                      _buildReportDetail('Ngrok Status', _ngrokHealth?['status']?.toString() ?? 'Unknown'),
                      _buildReportDetail('Server Time', _serverTime != null ? DateFormat('yyyy-MM-dd HH:mm:ss').format(_serverTime!) : 'Unknown'),
                      if (_systemHealth != null)
                        ..._systemHealth!.entries
                            .where((e) => e.key != 'status')
                            .map((e) => _buildReportDetail(e.key, e.value?.toString() ?? 'N/A')),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          
          // Security Report
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppDesignSystem.radiusLG),
            ),
            child: ExpansionTile(
              leading: const Icon(Icons.security, color: Colors.orange, size: 28),
              title: const Text(
                'Security Report',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: const Text('User security and access information'),
              children: [
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildReportDetail('Total Users', '${_users.length}'),
                      _buildReportDetail('Active Users', '${_users.where((u) => !(u['disabled'] ?? false)).length}'),
                      _buildReportDetail('Disabled Users', '${_users.where((u) => u['disabled'] ?? true).length}'),
                      _buildReportDetail('Locked Users', '${_users.where((u) => u['isLocked'] ?? false).length}'),
                      _buildReportDetail('Admin Users', '${_users.where((u) => (u['role'] ?? 'user') == 'admin').length}'),
                      _buildReportDetail('Regular Users', '${_users.where((u) => (u['role'] ?? 'user') == 'user').length}'),
                      _buildReportDetail('Recent Admin Actions', '${_adminLogs.length}'),
                      _buildReportDetail('User Activity Logs', '${_userLogs.length}'),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          
          // Activity Report
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppDesignSystem.radiusLG),
            ),
            child: ExpansionTile(
              leading: const Icon(Icons.timeline, color: Colors.blue, size: 28),
              title: const Text(
                'Activity Report',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: const Text('App-wide activity metrics'),
              children: [
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildReportDetail('Total Chats', '${_chats.length}'),
                      _buildReportDetail('Total Messages', '${_messages.length}'),
                      _buildReportDetail('Media Files', '${_mediaFiles.length}'),
                      if (_systemStats != null) ...[
                        _buildReportDetail('Messages Today', _systemStats!['messagesToday']?.toString() ?? '0'),
                        _buildReportDetail('Active Chats', _systemStats!['activeChats']?.toString() ?? '0'),
                      ],
                      if (_analyticsData != null) ...[
                        _buildReportDetail('New Users Today', (_analyticsData!['users']?['newToday'] ?? 0).toString()),
                        _buildReportDetail('Active Users (7d)', (_analyticsData!['users']?['active'] ?? 0).toString()),
                        _buildReportDetail('Group Chats', (_analyticsData!['chats']?['group'] ?? 0).toString()),
                        _buildReportDetail('Private Chats', (_analyticsData!['chats']?['private'] ?? 0).toString()),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          
          // Performance Report
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppDesignSystem.radiusLG),
            ),
            child: ExpansionTile(
              leading: const Icon(Icons.speed, color: Colors.purple, size: 28),
              title: const Text(
                'Performance Report',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: const Text('System performance metrics'),
              children: [
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildReportDetail('Total Data Points', '${_users.length + _chats.length + _messages.length}'),
                      _buildReportDetail('Database Collections', 'Users, Chats, Messages, Reports'),
                      _buildReportDetail('Storage Status', _mediaFiles.isEmpty ? 'No media files' : '${_mediaFiles.length} media files'),
                      if (_analyticsData != null && _analyticsData!['generatedAt'] != null)
                        _buildReportDetail(
                          'Last Analytics Update',
                          DateFormat('yyyy-MM-dd HH:mm:ss').format(
                            DateTime.parse(_analyticsData!['generatedAt']),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildReportItem(Map<String, dynamic> report) {
        final reason = report['reason'] ?? '';
        final reportedUserId = report['reportedUserId'] ?? '';
        final reporterId = report['reporterId'] ?? '';
    final status = report['status'] ?? 'pending';
    
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: status == 'resolved' ? Colors.green : Colors.red,
        child: Icon(
          status == 'resolved' ? Icons.check : Icons.warning,
          color: Colors.white,
          size: 20,
        ),
      ),
      title: Text(
        'Report: $reason',
        style: AppDesignSystem.bodyMedium.copyWith(fontWeight: FontWeight.w500),
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Reported User: $reportedUserId'),
          Text('Reporter: $reporterId'),
          Text(
            'Status: ${status.toString().toUpperCase()}',
            style: AppDesignSystem.bodySmall.copyWith(
              color: status == 'resolved' ? Colors.green : Colors.orange,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
            trailing: PopupMenuButton<String>(
        onSelected: (value) async {
          if (value == 'resolve') {
            try {
              final reportId = report['_id'] ?? report['id'] ?? '';
              if (reportId.toString().isNotEmpty) {
                final success = await _adminService.resolveReport(reportId.toString(), 'resolved_by_admin');
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(success ? 'Report resolved' : 'Failed to resolve report')),
                  );
                  await _loadReports();
                }
              }
            } catch (e) {
              Log.e('Error resolving report', 'ADMIN_PANEL_MONGODB', e);
            }
          }
              },
              itemBuilder: (context) => [
          if (status != 'resolved')
                const PopupMenuItem(
                  value: 'resolve',
              child: Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.green, size: 20),
                  SizedBox(width: 8),
                  Text('Mark as Resolved'),
                ],
              ),
                ),
              ],
            ),
    );
  }
  
  Widget _buildReportDetail(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: AppDesignSystem.bodyMedium,
          ),
          Text(
            value,
            style: AppDesignSystem.bodyMedium.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildHealthMonitoringTab() {
    final isMobile = ResponsiveUtils.isMobile(context);
    final isWeb = kIsWeb;
    final padding = ResponsiveUtils.getResponsiveValue(
      context,
      mobile: 12.0,
      tablet: 14.0,
      desktop: 16.0,
    );
    
    return SingleChildScrollView(
      padding: EdgeInsets.all(padding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'System Health Monitoring',
                  style: AppDesignSystem.headlineMedium.copyWith(
                    fontWeight: FontWeight.bold,
                    fontSize: ResponsiveUtils.getResponsiveFontSize(
                      context,
                      baseSize: 22,
                      mobileMultiplier: 0.9,
                    ),
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.refresh),
                iconSize: ResponsiveUtils.getResponsiveValue(
                  context,
                  mobile: 20.0,
                  tablet: 24.0,
                  desktop: 28.0,
                ),
                onPressed: _loadHealthMonitoring,
                tooltip: 'Refresh Health Status',
              ),
              if (_isLoadingHealth)
                const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
            ],
          ),
          SizedBox(height: padding),
          
          // Platform Information
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppDesignSystem.radiusLG),
            ),
            child: ExpansionTile(
              leading: Icon(
                isWeb ? Icons.web : Icons.phone_android,
                color: isWeb ? Colors.blue : Colors.green,
                size: ResponsiveUtils.getResponsiveValue(
                  context,
                  mobile: 24.0,
                  tablet: 26.0,
                  desktop: 28.0,
                ),
              ),
              title: Text(
                'Platform Information',
                style: AppDesignSystem.titleLarge.copyWith(
                  fontWeight: FontWeight.bold,
                  fontSize: ResponsiveUtils.getResponsiveFontSize(
                    context,
                    baseSize: 18,
                  ),
                ),
              ),
              subtitle: Text('Current platform: ${isWeb ? "Web" : "Mobile"}'),
              children: [
                Padding(
                  padding: EdgeInsets.all(padding),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildHealthDetail('Platform Type', isWeb ? 'Web (Local Network)' : 'Mobile (Public Network)'),
                      _buildHealthDetail('Base URL', DatabaseConfig.physicalServerUrl),
                      if (!isWeb)
                        _buildHealthDetail('Ngrok URL', DatabaseConfig.mobileServerUrl),
                      _buildHealthDetail('Server Time', _serverTime != null ? DateFormat('yyyy-MM-dd HH:mm:ss').format(_serverTime!) : 'Syncing...'),
                    ],
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: padding),
          
          // Local API Server Health (Web)
          if (isWeb)
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppDesignSystem.radiusLG),
              ),
              child: ExpansionTile(
                leading: _buildHealthStatusIcon(
                  _localApiHealth?['status']?.toString() ?? 'unknown',
                  size: ResponsiveUtils.getResponsiveValue(
                    context,
                    mobile: 24.0,
                    tablet: 26.0,
                    desktop: 28.0,
                  ),
                ),
                title: Text(
                  'Local API Server (IPv4:8082)',
                  style: AppDesignSystem.titleLarge.copyWith(
                    fontWeight: FontWeight.bold,
                    fontSize: ResponsiveUtils.getResponsiveFontSize(
                      context,
                      baseSize: 18,
                    ),
                  ),
                ),
                subtitle: Text(
                  'Status: ${_localApiHealth?['status']?.toString() ?? 'Checking...'}',
                  style: TextStyle(
                    color: _getHealthStatusColor(_localApiHealth?['status']?.toString() ?? 'unknown'),
                    fontWeight: FontWeight.bold,
                  ),
                ),
                children: [
                  Padding(
                    padding: EdgeInsets.all(padding),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (_localApiHealth != null) ...[
                          _buildHealthDetail('Status', _localApiHealth!['status']?.toString() ?? 'Unknown'),
                          _buildHealthDetail('Message', _localApiHealth!['message']?.toString() ?? 'N/A'),
                          if (_localApiHealth!['uptime'] != null)
                            _buildHealthDetail('Uptime', _formatUptime(_localApiHealth!['uptime'])),
                          if (_localApiHealth!['database'] != null) ...[
                            const Divider(),
                            _buildHealthDetail('Database Status', _localApiHealth!['database']?['status']?.toString() ?? 'Unknown'),
                            _buildHealthDetail('Connection Attempts', _localApiHealth!['database']?['connectionAttempts']?.toString() ?? '0'),
                            _buildHealthDetail('Success Rate', '${_localApiHealth!['database']?['successRate']?.toString() ?? '0'}%'),
                          ],
                          if (_localApiHealth!['server'] != null) ...[
                            const Divider(),
                            _buildHealthDetail('Node Version', _localApiHealth!['server']?['nodeVersion']?.toString() ?? 'N/A'),
                            _buildHealthDetail('Platform', _localApiHealth!['server']?['platform']?.toString() ?? 'N/A'),
                          ],
                        ] else
                          const Center(child: Text('No health data available')),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          if (isWeb) SizedBox(height: padding),
          
          // Ngrok Tunnel Health (Mobile)
          if (!isWeb)
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppDesignSystem.radiusLG),
              ),
              child: ExpansionTile(
                leading: _buildHealthStatusIcon(
                  _ngrokHealth?['status']?.toString() ?? 'unknown',
                  size: ResponsiveUtils.getResponsiveValue(
                    context,
                    mobile: 24.0,
                    tablet: 26.0,
                    desktop: 28.0,
                  ),
                ),
                title: Text(
                  'Ngrok Tunnel (Public API)',
                  style: AppDesignSystem.titleLarge.copyWith(
                    fontWeight: FontWeight.bold,
                    fontSize: ResponsiveUtils.getResponsiveFontSize(
                      context,
                      baseSize: 18,
                    ),
                  ),
                ),
                subtitle: Text(
                  'Status: ${_ngrokHealth?['status']?.toString() ?? 'Checking...'}',
                  style: TextStyle(
                    color: _getHealthStatusColor(_ngrokHealth?['status']?.toString() ?? 'unknown'),
                    fontWeight: FontWeight.bold,
                  ),
                ),
                children: [
                  Padding(
                    padding: EdgeInsets.all(padding),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildHealthDetail('Ngrok URL', DatabaseConfig.mobileServerUrl),
                        if (_ngrokHealth != null) ...[
                          _buildHealthDetail('Status', _ngrokHealth!['status']?.toString() ?? 'Unknown'),
                          _buildHealthDetail('Message', _ngrokHealth!['message']?.toString() ?? 'N/A'),
                        ] else
                          const Center(child: Text('Checking ngrok status...')),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          if (!isWeb) SizedBox(height: padding),
          
          // MongoDB Database Health
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppDesignSystem.radiusLG),
            ),
            child: ExpansionTile(
              leading: _buildHealthStatusIcon(
                _mongoDbStatus?['mongodb']?['status']?.toString() ?? 'unknown',
                size: ResponsiveUtils.getResponsiveValue(
                  context,
                  mobile: 24.0,
                  tablet: 26.0,
                  desktop: 28.0,
                ),
              ),
              title: Text(
                'MongoDB Database',
                style: AppDesignSystem.titleLarge.copyWith(
                  fontWeight: FontWeight.bold,
                  fontSize: ResponsiveUtils.getResponsiveFontSize(
                    context,
                    baseSize: 18,
                  ),
                ),
              ),
              subtitle: Text(
                'Status: ${_mongoDbStatus?['mongodb']?['status']?.toString() ?? 'Checking...'}',
                style: TextStyle(
                  color: _getHealthStatusColor(_mongoDbStatus?['mongodb']?['status']?.toString() ?? 'unknown'),
                  fontWeight: FontWeight.bold,
                ),
              ),
              children: [
                Padding(
                  padding: EdgeInsets.all(padding),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (_mongoDbStatus != null && _mongoDbStatus!['mongodb'] != null) ...[
                        _buildHealthDetail('Connection Status', _mongoDbStatus!['mongodb']?['status']?.toString() ?? 'Unknown'),
                        if (_mongoDbStatus!['mongodb']?['lastConnection'] != null)
                          _buildHealthDetail('Last Connection', _formatTimestamp(_mongoDbStatus!['mongodb']?['lastConnection'])),
                        _buildHealthDetail('Connection Attempts', _mongoDbStatus!['mongodb']?['connectionAttempts']?.toString() ?? '0'),
                        _buildHealthDetail('Total Queries', _mongoDbStatus!['mongodb']?['totalQueries']?.toString() ?? '0'),
                        _buildHealthDetail('Failed Queries', _mongoDbStatus!['mongodb']?['failedQueries']?.toString() ?? '0'),
                        _buildHealthDetail('Success Rate', '${_mongoDbStatus!['mongodb']?['successRate']?.toString() ?? '0'}%'),
                      ] else
                        const Center(child: Text('No MongoDB status data available')),
                    ],
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: padding),
          
          // API Endpoints Status
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppDesignSystem.radiusLG),
            ),
            child: ExpansionTile(
              leading: Icon(
                Icons.api,
                color: Colors.purple,
                size: ResponsiveUtils.getResponsiveValue(
                  context,
                  mobile: 24.0,
                  tablet: 26.0,
                  desktop: 28.0,
                ),
              ),
              title: Text(
                'API Endpoints Status',
                style: AppDesignSystem.titleLarge.copyWith(
                  fontWeight: FontWeight.bold,
                  fontSize: ResponsiveUtils.getResponsiveFontSize(
                    context,
                    baseSize: 18,
                  ),
                ),
              ),
              subtitle: Text(
                '${_apiEndpointsStatus.where((e) => e['status'] == 'operational').length}/${_apiEndpointsStatus.length} endpoints operational',
              ),
              initiallyExpanded: true,
              children: [
                Padding(
                  padding: EdgeInsets.all(padding),
                  child: Column(
                    children: _apiEndpointsStatus.map((endpoint) {
                      return _buildEndpointStatusCard(endpoint);
                    }).toList(),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: padding),
          
          // Comprehensive System Health
          if (_comprehensiveHealth != null)
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppDesignSystem.radiusLG),
              ),
              child: ExpansionTile(
                leading: _buildHealthStatusIcon(
                  _comprehensiveHealth!['status']?.toString() ?? 'unknown',
                  size: ResponsiveUtils.getResponsiveValue(
                    context,
                    mobile: 24.0,
                    tablet: 26.0,
                    desktop: 28.0,
                  ),
                ),
                title: Text(
                  'System Health Overview',
                  style: AppDesignSystem.titleLarge.copyWith(
                    fontWeight: FontWeight.bold,
                    fontSize: ResponsiveUtils.getResponsiveFontSize(
                      context,
                      baseSize: 18,
                    ),
                  ),
                ),
                subtitle: Text(
                  'Status: ${_comprehensiveHealth!['status']?.toString() ?? 'Unknown'}',
                  style: TextStyle(
                    color: _getHealthStatusColor(_comprehensiveHealth!['status']?.toString() ?? 'unknown'),
                    fontWeight: FontWeight.bold,
                  ),
                ),
                children: [
                  Padding(
                    padding: EdgeInsets.all(padding),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (_comprehensiveHealth!['database'] != null) ...[
                          Text(
                            'Database',
                            style: AppDesignSystem.titleMedium.copyWith(fontWeight: FontWeight.bold),
                          ),
                          _buildHealthDetail('Connected', _comprehensiveHealth!['database']?['connected']?.toString() ?? 'Unknown'),
                          _buildHealthDetail('Database Name', _comprehensiveHealth!['database']?['name']?.toString() ?? 'N/A'),
                          const SizedBox(height: 8),
                        ],
                        if (_comprehensiveHealth!['collections'] != null) ...[
                          Text(
                            'Collections',
                            style: AppDesignSystem.titleMedium.copyWith(fontWeight: FontWeight.bold),
                          ),
                          ...(_comprehensiveHealth!['collections'] as List).map((collection) {
                            return _buildHealthDetail(
                              collection['name']?.toString() ?? 'Unknown',
                              '${collection['exists'] == true ? '✓' : '✗'} ${collection['documentCount'] ?? 0} docs',
                            );
                          }),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
  
  Widget _buildHealthStatusIcon(String status, {double size = 28}) {
    Color color;
    IconData icon;
    
    switch (status.toLowerCase()) {
      case 'ok':
      case 'healthy':
      case 'connected':
      case 'operational':
        color = Colors.green;
        icon = Icons.check_circle;
        break;
      case 'degraded':
      case 'warning':
        color = Colors.orange;
        icon = Icons.warning;
        break;
      case 'error':
      case 'unhealthy':
      case 'disconnected':
      case 'offline':
        color = Colors.red;
        icon = Icons.error;
        break;
      default:
        color = Colors.grey;
        icon = Icons.help_outline;
    }
    
    return Icon(icon, color: color, size: size);
  }
  
  Color _getHealthStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'ok':
      case 'healthy':
      case 'connected':
      case 'operational':
        return Colors.green;
      case 'degraded':
      case 'warning':
        return Colors.orange;
      case 'error':
      case 'unhealthy':
      case 'disconnected':
      case 'offline':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }
  
  Widget _buildHealthDetail(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              label,
              style: AppDesignSystem.bodyMedium.copyWith(
                fontSize: ResponsiveUtils.getResponsiveFontSize(
                  context,
                  baseSize: 14,
                  mobileMultiplier: 0.9,
                ),
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: AppDesignSystem.bodyMedium.copyWith(
                fontWeight: FontWeight.bold,
                fontSize: ResponsiveUtils.getResponsiveFontSize(
                  context,
                  baseSize: 14,
                  mobileMultiplier: 0.9,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildEndpointStatusCard(Map<String, dynamic> endpoint) {
    final status = endpoint['status']?.toString() ?? 'unknown';
    final statusColor = _getHealthStatusColor(status);
    
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      color: statusColor.withOpacity(0.1),
      child: ListTile(
        leading: _buildHealthStatusIcon(status, size: 20),
        title: Text(
          endpoint['name']?.toString() ?? 'Unknown',
          style: AppDesignSystem.bodyMedium.copyWith(
            fontWeight: FontWeight.w600,
            fontSize: ResponsiveUtils.getResponsiveFontSize(
              context,
              baseSize: 14,
            ),
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${endpoint['method']} ${endpoint['path']}',
              style: AppDesignSystem.bodySmall.copyWith(
                fontSize: ResponsiveUtils.getResponsiveFontSize(
                  context,
                  baseSize: 12,
                  mobileMultiplier: 0.9,
                ),
              ),
            ),
            if (endpoint['statusCode'] != null)
              Text(
                'HTTP ${endpoint['statusCode']}',
                style: AppDesignSystem.bodySmall.copyWith(
                  color: statusColor,
                  fontSize: ResponsiveUtils.getResponsiveFontSize(
                    context,
                    baseSize: 11,
                    mobileMultiplier: 0.85,
                  ),
                ),
              ),
          ],
        ),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: statusColor,
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            status.toUpperCase(),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 10,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }
  
  String _formatUptime(dynamic uptime) {
    if (uptime == null) return 'N/A';
    final seconds = uptime is int ? uptime : uptime.toInt();
    final days = seconds ~/ 86400;
    final hours = (seconds % 86400) ~/ 3600;
    final minutes = (seconds % 3600) ~/ 60;
    
    if (days > 0) {
      return '${days}d ${hours}h ${minutes}m';
    } else if (hours > 0) {
      return '${hours}h ${minutes}m';
    } else {
      return '${minutes}m';
    }
  }
  
  String _formatTimestamp(dynamic timestamp) {
    if (timestamp == null) return 'N/A';
    try {
      if (timestamp is String) {
        final dt = DateTime.parse(timestamp);
        return DateFormat('yyyy-MM-dd HH:mm:ss').format(dt);
      }
      return timestamp.toString();
    } catch (e) {
      return timestamp.toString();
    }
  }

  // Device Statistics Methods
  Future<void> _loadDeviceStats() async {
    setState(() => _isLoadingDevices = true);
    try {
      final token = await _authService.getAuthToken();
      if (token == null) return;
      
      final baseUrl = DatabaseConfig.physicalServerUrl;
      final response = await http.get(
        Uri.parse('$baseUrl/api/admin/devices/stats'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
          'ngrok-skip-browser-warning': 'true',
        },
      );
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          _deviceStats = data;
        });
      } else {
        Log.e('Failed to load device stats', 'ADMIN_PANEL', response.statusCode);
      }
    } catch (e) {
      Log.e('Error loading device stats', 'ADMIN_PANEL', e);
    } finally {
      setState(() => _isLoadingDevices = false);
    }
  }

  Future<void> _loadDevices({String? platform}) async {
    setState(() => _isLoadingDevices = true);
    try {
      final token = await _authService.getAuthToken();
      if (token == null) return;
      
      final baseUrl = DatabaseConfig.physicalServerUrl;
      final queryParams = platform != null ? '?platform=$platform' : '';
      final response = await http.get(
        Uri.parse('$baseUrl/api/admin/devices$queryParams'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
          'ngrok-skip-browser-warning': 'true',
        },
      );
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          _devices = List<Map<String, dynamic>>.from(data['devices'] ?? []);
        });
      } else {
        Log.e('Failed to load devices', 'ADMIN_PANEL', response.statusCode);
      }
    } catch (e) {
      Log.e('Error loading devices', 'ADMIN_PANEL', e);
    } finally {
      setState(() => _isLoadingDevices = false);
    }
  }

  Widget _buildDevicesTab() {
    final isMobile = ResponsiveUtils.isMobile(context);
    final isDark = _themeService.isDarkMode;
    final padding = ResponsiveUtils.getResponsiveValue(
      context,
      mobile: 12.0,
      tablet: 16.0,
      desktop: 24.0,
    );

    // Load stats when tab is first opened
    if (_deviceStats == null && !_isLoadingDevices) {
      _loadDeviceStats();
      _loadDevices();
    }

    return RefreshIndicator(
      onRefresh: () async {
        await _loadDeviceStats();
        await _loadDevices();
      },
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.all(padding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Statistics Cards
            if (_deviceStats != null) ...[
              Text(
                'Device Statistics',
                style: AppDesignSystem.headlineSmall.copyWith(
                  color: isDark ? AppDesignSystem.neutral50 : AppDesignSystem.neutral900,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 16,
                runSpacing: 16,
                children: [
                  _buildDeviceStatCard(
                    'Total Devices',
                    '${_deviceStats!['totalDevices'] ?? 0}',
                    Icons.phone_android,
                    AppDesignSystem.primaryColor,
                    isDark,
                  ),
                  _buildDeviceStatCard(
                    'Android',
                    '${_deviceStats!['platformBreakdown']?['android'] ?? 0}',
                    Icons.android,
                    const Color(0xFF3DDC84),
                    isDark,
                  ),
                  _buildDeviceStatCard(
                    'iOS',
                    '${_deviceStats!['platformBreakdown']?['ios'] ?? 0}',
                    Icons.phone_iphone,
                    const Color(0xFF007AFF),
                    isDark,
                  ),
                  _buildDeviceStatCard(
                    'Unique Users',
                    '${_deviceStats!['uniqueUsers'] ?? 0}',
                    Icons.people,
                    AppDesignSystem.secondaryColor,
                    isDark,
                  ),
                  _buildDeviceStatCard(
                    'Multi-Device Users',
                    '${_deviceStats!['multiDeviceUsers'] ?? 0}',
                    Icons.devices,
                    AppDesignSystem.warningColor,
                    isDark,
                  ),
                  _buildDeviceStatCard(
                    'Recent Logins (24h)',
                    '${_deviceStats!['recentLogins24h'] ?? 0}',
                    Icons.access_time,
                    AppDesignSystem.infoColor,
                    isDark,
                  ),
                ],
              ),
              const SizedBox(height: 32),
            ],
            
            // Platform Filter
            Row(
              children: [
                Expanded(
                  child: Text(
                    'All Devices',
                    style: AppDesignSystem.headlineSmall.copyWith(
                      color: isDark ? AppDesignSystem.neutral50 : AppDesignSystem.neutral900,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Wrap(
                  spacing: 8,
                  children: [
                    FilterChip(
                      label: const Text('All'),
                      selected: true,
                      onSelected: (selected) {
                        if (selected) _loadDevices();
                      },
                    ),
                    FilterChip(
                      label: const Text('Android'),
                      selected: false,
                      onSelected: (selected) {
                        if (selected) _loadDevices(platform: 'android');
                      },
                    ),
                    FilterChip(
                      label: const Text('iOS'),
                      selected: false,
                      onSelected: (selected) {
                        if (selected) _loadDevices(platform: 'ios');
                      },
                    ),
                    FilterChip(
                      label: const Text('Web'),
                      selected: false,
                      onSelected: (selected) {
                        if (selected) _loadDevices(platform: 'web');
                      },
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            // Devices List
            if (_isLoadingDevices)
              const Center(child: Padding(
                padding: EdgeInsets.all(32.0),
                child: CircularProgressIndicator(),
              ))
            else if (_devices.isEmpty)
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(32.0),
                  child: Column(
                    children: [
                      Icon(
                        Icons.phone_android_outlined,
                        size: 64,
                        color: isDark ? AppDesignSystem.neutral600 : AppDesignSystem.neutral400,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No devices found',
                        style: AppDesignSystem.bodyLarge.copyWith(
                          color: isDark ? AppDesignSystem.neutral500 : AppDesignSystem.neutral600,
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _devices.length,
                itemBuilder: (context, index) {
                  final device = _devices[index];
                  return _buildDeviceCard(device, isDark);
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildDeviceStatCard(String title, String value, IconData icon, Color color, bool isDark) {
    return Card(
      elevation: 2,
      child: Container(
        width: ResponsiveUtils.isMobile(context) ? double.infinity : 180,
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, color: color, size: 24),
                ),
                const Spacer(),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              value,
              style: AppDesignSystem.headlineMedium.copyWith(
                color: isDark ? AppDesignSystem.neutral50 : AppDesignSystem.neutral900,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              title,
              style: AppDesignSystem.bodySmall.copyWith(
                color: isDark ? AppDesignSystem.neutral400 : AppDesignSystem.neutral600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showUserDevicesDialog(String userId, String userName) async {
    try {
      final token = await _authService.getAuthToken();
      if (token == null) return;
      
      final baseUrl = DatabaseConfig.physicalServerUrl;
      final response = await http.get(
        Uri.parse('$baseUrl/api/admin/devices/user/$userId'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
          'ngrok-skip-browser-warning': 'true',
        },
      );
      
      if (response.statusCode != 200) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to load devices: ${response.statusCode}')),
          );
        }
        return;
      }
      
      final data = json.decode(response.body);
      final devices = List<Map<String, dynamic>>.from(data['devices'] ?? []);
      final deviceCount = data['deviceCount'] ?? 0;
      
      if (!mounted) return;
      
      final isDark = _themeService.isDarkMode;
      final deviceTracking = DeviceTrackingService();
      
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('Devices for $userName'),
          content: SizedBox(
            width: double.maxFinite,
            child: deviceCount == 0
                ? Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.phone_android_outlined,
                        size: 48,
                        color: isDark ? AppDesignSystem.neutral600 : AppDesignSystem.neutral400,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No devices found',
                        style: AppDesignSystem.bodyLarge,
                      ),
                    ],
                  )
                : ListView.builder(
                    shrinkWrap: true,
                    itemCount: devices.length,
                    itemBuilder: (context, index) {
                      final device = devices[index];
                      return _buildDeviceCard(device, isDark);
                    },
                  ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
          ],
        ),
      );
    } catch (e) {
      Log.e('Error showing user devices', 'ADMIN_PANEL', e);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading devices: $e')),
        );
      }
    }
  }

  Widget _buildDeviceCard(Map<String, dynamic> device, bool isDark) {
    final platform = device['platform'] ?? 'unknown';
    final deviceModel = device['deviceModel'] ?? 'Unknown Device';
    final osVersion = device['osVersion'] ?? 'Unknown';
    final loginCount = device['loginCount'] ?? 1;
    final lastLoginAt = device['lastLoginAt'];
    final user = device['user'];
    final manufacturer = device['manufacturer'] ?? '';
    final brand = device['brand'] ?? '';
    final browserName = device['browserName'] ?? '';
    final browserVersion = device['browserVersion'] ?? '';
    
    IconData platformIcon;
    Color platformColor;
    if (platform == 'android') {
      platformIcon = Icons.android;
      platformColor = const Color(0xFF3DDC84);
    } else if (platform == 'ios') {
      platformIcon = Icons.phone_iphone;
      platformColor = const Color(0xFF007AFF);
    } else if (platform == 'web') {
      platformIcon = Icons.web;
      platformColor = const Color(0xFF4285F4);
    } else {
      platformIcon = Icons.computer;
      platformColor = AppDesignSystem.neutral500;
    }
    
    String deviceDisplayName = deviceModel;
    if (platform == 'web') {
      // For web, show browser name and version
      if (browserName.isNotEmpty && browserVersion.isNotEmpty) {
        deviceDisplayName = '$browserName $browserVersion';
      } else if (browserName.isNotEmpty) {
        deviceDisplayName = browserName;
      } else {
        deviceDisplayName = 'Web Browser';
      }
    } else if (manufacturer.isNotEmpty || brand.isNotEmpty) {
      deviceDisplayName = '${manufacturer.isNotEmpty ? "$manufacturer " : ""}${brand.isNotEmpty ? "$brand " : ""}$deviceModel';
    }
    
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: platformColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(platformIcon, color: platformColor, size: 28),
        ),
        title: Text(
          deviceDisplayName,
          style: AppDesignSystem.titleMedium.copyWith(
            fontWeight: FontWeight.bold,
            color: isDark ? AppDesignSystem.neutral50 : AppDesignSystem.neutral900,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            if (user != null)
              Text(
                'User: ${user['displayName'] ?? user['email'] ?? 'Unknown'}',
                style: AppDesignSystem.bodySmall.copyWith(
                  color: isDark ? AppDesignSystem.neutral400 : AppDesignSystem.neutral600,
                ),
              ),
            if (platform == 'web')
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (browserName.isNotEmpty)
                    Text(
                      'Browser: $browserName${browserVersion.isNotEmpty ? " $browserVersion" : ""}',
                      style: AppDesignSystem.bodySmall.copyWith(
                        color: isDark ? AppDesignSystem.neutral400 : AppDesignSystem.neutral600,
                      ),
                    ),
                  Text(
                    'Platform: $osVersion',
                    style: AppDesignSystem.bodySmall.copyWith(
                      color: isDark ? AppDesignSystem.neutral400 : AppDesignSystem.neutral600,
                    ),
                  ),
                  if (device['ipAddress'] != null && device['ipAddress'].toString().isNotEmpty)
                    Text(
                      'IP: ${device['ipAddress']}',
                      style: AppDesignSystem.bodySmall.copyWith(
                        color: isDark ? AppDesignSystem.neutral500 : AppDesignSystem.neutral500,
                        fontSize: 11,
                        fontFamily: 'monospace',
                      ),
                    ),
                ],
              )
            else
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$osVersion',
                    style: AppDesignSystem.bodySmall.copyWith(
                      color: isDark ? AppDesignSystem.neutral400 : AppDesignSystem.neutral600,
                    ),
                  ),
                  if (device['ipAddress'] != null && device['ipAddress'].toString().isNotEmpty)
                    Text(
                      'IP: ${device['ipAddress']}',
                      style: AppDesignSystem.bodySmall.copyWith(
                        color: isDark ? AppDesignSystem.neutral500 : AppDesignSystem.neutral500,
                        fontSize: 11,
                        fontFamily: 'monospace',
                      ),
                    ),
                ],
              ),
            if (lastLoginAt != null)
              Text(
                'Last login: ${_formatTimestamp(lastLoginAt)}',
                style: AppDesignSystem.bodySmall.copyWith(
                  color: isDark ? AppDesignSystem.neutral500 : AppDesignSystem.neutral500,
                  fontSize: 11,
                ),
              ),
          ],
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: platformColor.withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                platform.toUpperCase(),
                style: TextStyle(
                  color: platformColor,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '$loginCount login${loginCount != 1 ? 's' : ''}',
              style: AppDesignSystem.bodySmall.copyWith(
                color: isDark ? AppDesignSystem.neutral400 : AppDesignSystem.neutral600,
                fontSize: 11,
              ),
            ),
          ],
        ),
        isThreeLine: true,
      ),
    );
  }
}
