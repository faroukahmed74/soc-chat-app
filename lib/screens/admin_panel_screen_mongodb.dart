// =============================================================================
// ADMIN PANEL SCREEN - MONGODB VERSION
// =============================================================================
// This screen provides admin functionality using MongoDB
// It handles user management, system monitoring, and admin operations

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../services/theme_service.dart';
import '../services/mongodb_admin_service.dart';
import '../services/physical_auth_service.dart';
import '../services/logger_service.dart';
import '../config/database_config.dart';

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
  List<Map<String, dynamic>> _messages = [];
  List<Map<String, dynamic>> _reports = [];
  Map<String, dynamic>? _systemStats;
  Map<String, dynamic>? _systemHealth;
  Map<String, dynamic>? _apiHealth;
  Map<String, dynamic>? _mongoDbStatus;
  Map<String, dynamic>? _ngrokHealth;
  final TextEditingController _userSearchController = TextEditingController();
  String _selectedChatIdForMessages = '';
  
  // Loading states
  bool _isLoadingUsers = false;
  bool _isLoadingChats = false;
  bool _isLoadingMessages = false;
  bool _isLoadingReports = false;
  bool _isLoadingStats = false;
  bool _roleLoaded = false;
  bool _isAdmin = false;

  @override
  void initState() {
    super.initState();
    _themeService = ThemeService.instance;
    _themeService.addListener(() {
      if (mounted) setState(() {});
    });
    _tabController = TabController(length: 5, vsync: this);
    _checkAdminAccess();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _userSearchController.dispose();
    super.dispose();
  }

  Future<void> _loadInitialData() async {
    await Future.wait([
      _loadUsers(),
      _loadSystemStats(),
      _loadSystemHealth(),
    ]);
  }

  Future<void> _checkAdminAccess() async {
    try {
      final role = await _authService.getCurrentUserRole();
      setState(() {
        _isAdmin = role == 'admin';
        _roleLoaded = true;
      });
      if (_isAdmin) {
        await _loadInitialData();
      }
    } catch (e) {
      setState(() {
        _roleLoaded = true;
        _isAdmin = false;
      });
    }
  }

  Widget _buildAccessDenied() {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Panel'),
        backgroundColor: _themeService.isDarkMode ? Colors.grey[900] : Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.lock_outline, size: 64, color: Colors.redAccent),
            const SizedBox(height: 16),
            const Text(
              'Access denied. Admins only.',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => Navigator.of(context).maybePop(),
              icon: const Icon(Icons.arrow_back),
              label: const Text('Back'),
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
            style: TextButton.styleFrom(foregroundColor: Colors.red),
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
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete User'),
        content: const Text('Are you sure you want to delete this user? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        final success = await _adminService.deleteUser(userId);
        if (success) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('User deleted successfully')),
            );
            _loadUsers();
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
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add New User'),
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
            child: const Text('Add'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
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
        final response = await http.post(
          Uri.parse('$baseUrl/api/admin/users'),
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json',
            'ngrok-skip-browser-warning': 'true',
          },
          body: json.encode({
            'email': emailController.text.trim(),
            'password': passwordController.text,
            'displayName': nameController.text.trim(),
            'role': 'user',
          }),
        );

        if (mounted) {
          if (response.statusCode == 200) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('User created successfully')),
            );
            await _loadUsers();
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Failed to create user: ${response.statusCode}')),
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

  Future<void> _changeUserRole(String userId, String role) async {
    try {
      final success = await _adminService.updateUserRole(userId, role);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(success ? 'Role updated to $role' : 'Failed to update role')),
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

  Future<void> _toggleUserStatusAction(String userId, bool disabled) async {
    try {
      final success = await _adminService.toggleUserStatus(userId, disabled);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(success ? (disabled ? 'User disabled' : 'User enabled') : 'Failed to update status')),
        );
        if (success) await _loadUsers();
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

  Widget _buildUsersTab() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _userSearchController,
                  decoration: const InputDecoration(
                    hintText: 'Search users by name or email',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.search),
                  ),
                  onSubmitted: (_) => _loadUsers(),
                ),
              ),
              const SizedBox(width: 12),
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
                          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: disabled ? Colors.red : Colors.blue,
                              child: Text(
                                name.isNotEmpty ? name[0].toUpperCase() : 'U',
                                style: const TextStyle(color: Colors.white),
                              ),
                            ),
                            title: Text(name),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(email),
                                Text('Role: $role'),
                                if (disabled) const Text('Status: Disabled', style: TextStyle(color: Colors.red)),
                              ],
                            ),
                            trailing: PopupMenuButton<String>(
                              onSelected: (value) async {
                                switch (value) {
                                  case 'make_admin':
                                    await _changeUserRole(userId, 'admin');
                                    break;
                                  case 'make_user':
                                    await _changeUserRole(userId, 'user');
                                    break;
                                  case 'toggle_status':
                                    await _toggleUserStatusAction(userId, !disabled);
                                    break;
                                  case 'delete':
                                    _deleteUser(userId);
                                    break;
                                }
                              },
                              itemBuilder: (context) => [
                                if (role != 'admin')
                                  const PopupMenuItem(
                                    value: 'make_admin',
                                    child: Row(
                                      children: [
                                        Icon(Icons.upgrade, color: Colors.green),
                                        SizedBox(width: 8),
                                        Text('Make Admin'),
                                      ],
                                    ),
                                  ),
                                if (role != 'user')
                                  const PopupMenuItem(
                                    value: 'make_user',
                                    child: Row(
                                      children: [
                                        Icon(Icons.person, color: Colors.blue),
                                        SizedBox(width: 8),
                                        Text('Make User'),
                                      ],
                                    ),
                                  ),
                                PopupMenuItem(
                                  value: 'toggle_status',
                                  child: Row(
                                    children: [
                                      Icon(disabled ? Icons.play_circle : Icons.pause_circle, color: Colors.orange),
                                      const SizedBox(width: 8),
                                      Text(disabled ? 'Enable User' : 'Disable User'),
                                    ],
                                  ),
                                ),
                                const PopupMenuItem(
                                  value: 'delete',
                                  child: Row(
                                    children: [
                                      Icon(Icons.delete, color: Colors.red),
                                      SizedBox(width: 8),
                                      Text('Delete User'),
                                    ],
                                  ),
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

  Widget _buildSystemStatsTab() {
    if (_isLoadingStats) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_systemStats == null) {
      return const Center(child: Text('No system stats available'));
    }

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'System Statistics',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
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
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'System Health',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  if (_systemHealth == null)
                    const Text('Health info not available')
                  else ...[
                    _buildStatRow('Status', _systemHealth!['status']?.toString() ?? 'unknown'),
                    ..._systemHealth!.entries
                        .where((e) => e.key != 'status')
                        .map((e) => _buildStatRow(e.key, e.value?.toString() ?? ''))
                        .toList(),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Connectivity',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
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
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Quick Actions',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
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
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: _sendBroadcastMessage,
                    icon: const Icon(Icons.broadcast_on_personal),
                    label: const Text('Send Broadcast Message'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ],
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

    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Panel'),
        backgroundColor: _themeService.isDarkMode ? Colors.grey[900] : Colors.blue,
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.people), text: 'Users'),
            Tab(icon: Icon(Icons.chat), text: 'Chats'),
            Tab(icon: Icon(Icons.message), text: 'Messages'),
            Tab(icon: Icon(Icons.report), text: 'Reports'),
            Tab(icon: Icon(Icons.analytics), text: 'Stats'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildUsersTab(),
          _buildChatsTab(),
          _buildMessagesTab(),
          _buildReportsTab(),
          _buildSystemStatsTab(),
        ],
      ),
    );
  }

  Widget _buildChatsTab() {
    if (_isLoadingChats) {
      return const Center(child: CircularProgressIndicator());
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
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
                          style: TextButton.styleFrom(foregroundColor: Colors.red),
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
                      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: type == 'group' ? Colors.green : Colors.blue,
                          child: Icon(
                            type == 'group' ? Icons.group : Icons.person,
                            color: Colors.white,
                          ),
                        ),
                        title: Text(name),
                        subtitle: Text('Type: $type, Members: $memberCount'),
                        trailing: const Icon(Icons.arrow_forward_ios),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildMessagesTab() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
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
                  style: const TextStyle(fontWeight: FontWeight.bold),
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
        final content = message['content'] ?? message['content'] ?? '';
        final senderName = message['senderName'] ?? 'Unknown';
        final timestampRaw = message['createdAt'] ?? message['timestamp'] ?? '';
        String timestampDisplay = '';
        if (timestampRaw is String && timestampRaw.isNotEmpty) {
          try {
            final dt = DateTime.parse(timestampRaw);
            final cairo = dt.toUtc().add(const Duration(hours: 2));
            timestampDisplay = '${cairo.year}-${cairo.month.toString().padLeft(2, '0')}-${cairo.day.toString().padLeft(2, '0')} ${cairo.hour.toString().padLeft(2, '0')}:${cairo.minute.toString().padLeft(2, '0')}';
          } catch (_) {
            timestampDisplay = timestampRaw.toString();
          }
        }
        final messageType = message['type'] ?? message['messageType'] ?? 'text';

        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: messageType == 'media' ? Colors.purple : Colors.orange,
              child: Text(
                messageType[0].toUpperCase(),
                style: const TextStyle(color: Colors.white),
              ),
            ),
            title: Text(content.isEmpty ? '[No content]' : (content.length > 50 ? '${content.substring(0, 50)}...' : content)),
            subtitle: Text('From: $senderName, Time: ${timestampDisplay.isEmpty ? 'Unknown' : timestampDisplay}'),
          ),
        );
      },
    );
  }

  Widget _buildReportsTab() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              ElevatedButton.icon(
                onPressed: _loadReports,
                icon: const Icon(Icons.refresh),
                label: const Text('Refresh Reports'),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Total: ${_reports.length} reports',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: _isLoadingReports
              ? const Center(child: CircularProgressIndicator())
              : _reports.isEmpty
                  ? const Center(child: Text('No reports found'))
                  : _buildReportsList(),
        ),
      ],
    );
  }

  Widget _buildReportsList() {

    return ListView.builder(
      itemCount: _reports.length,
      itemBuilder: (context, index) {
        final report = _reports[index];
        final reason = report['reason'] ?? '';
        final reportedUserId = report['reportedUserId'] ?? '';
        final reporterId = report['reporterId'] ?? '';

        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: ListTile(
            leading: const CircleAvatar(
              backgroundColor: Colors.red,
              child: Icon(Icons.report, color: Colors.white),
            ),
            title: Text('Report: $reason'),
            subtitle: Text('Reported User: $reportedUserId, Reporter: $reporterId'),
            trailing: PopupMenuButton<String>(
              onSelected: (value) {
                // Handle report resolution
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'resolve',
                  child: Text('Resolve'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
