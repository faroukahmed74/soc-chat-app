// =============================================================================
// ADMIN PANEL SCREEN - MONGODB VERSION
// =============================================================================
// This screen provides admin functionality using MongoDB
// It handles user management, system monitoring, and admin operations

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/theme_service.dart';
import '../services/mongodb_admin_service.dart';
import '../services/physical_auth_service.dart';
import '../services/logger_service.dart';

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
  
  // Loading states
  bool _isLoadingUsers = false;
  bool _isLoadingChats = false;
  bool _isLoadingMessages = false;
  bool _isLoadingReports = false;
  bool _isLoadingStats = false;

  @override
  void initState() {
    super.initState();
    _themeService = ThemeService.instance;
    _themeService.addListener(() {
      if (mounted) setState(() {});
    });
    _tabController = TabController(length: 5, vsync: this);
    _loadInitialData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadInitialData() async {
    await Future.wait([
      _loadUsers(),
      _loadSystemStats(),
    ]);
  }

  Future<void> _loadUsers() async {
    setState(() {
      _isLoadingUsers = true;
    });

    try {
      final users = await _adminService.getAllUsers();
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
      final messages = await _adminService.getAllMessages();
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
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingStats = false;
        });
      }
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

  Widget _buildUsersTab() {
    if (_isLoadingUsers) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_users.isEmpty) {
      return const Center(child: Text('No users found'));
    }

    return ListView.builder(
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
              onSelected: (value) {
                switch (value) {
                  case 'delete':
                    _deleteUser(userId);
                    break;
                }
              },
              itemBuilder: (context) => [
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
                    'Admin Actions',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: _sendBroadcastMessage,
                    icon: const Icon(Icons.broadcast_on_personal),
                    label: const Text('Send Broadcast Message'),
                  ),
                  const SizedBox(height: 8),
                  ElevatedButton.icon(
                    onPressed: () {
                      _loadInitialData();
                    },
                    icon: const Icon(Icons.refresh),
                    label: const Text('Refresh Data'),
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

  @override
  Widget build(BuildContext context) {
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

    if (_chats.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('No chats found'),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadChats,
              child: const Text('Load Chats'),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: _chats.length,
      itemBuilder: (context, index) {
        final chat = _chats[index];
        final chatId = chat['_id'] ?? chat['id'] ?? '';
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
    );
  }

  Widget _buildMessagesTab() {
    if (_isLoadingMessages) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_messages.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('No messages found'),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadMessages,
              child: const Text('Load Messages'),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: _messages.length,
      itemBuilder: (context, index) {
        final message = _messages[index];
        final content = message['content'] ?? '';
        final senderId = message['senderId'] ?? '';
        final timestamp = message['timestamp'] ?? '';
        final messageType = message['messageType'] ?? 'text';

        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: Colors.orange,
              child: Text(
                messageType[0].toUpperCase(),
                style: const TextStyle(color: Colors.white),
              ),
            ),
            title: Text(content.length > 50 ? '${content.substring(0, 50)}...' : content),
            subtitle: Text('From: $senderId, Time: $timestamp'),
          ),
        );
      },
    );
  }

  Widget _buildReportsTab() {
    if (_isLoadingReports) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_reports.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('No reports found'),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadReports,
              child: const Text('Load Reports'),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: _reports.length,
      itemBuilder: (context, index) {
        final report = _reports[index];
        final reportId = report['_id'] ?? report['id'] ?? '';
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
