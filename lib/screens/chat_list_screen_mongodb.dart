// =============================================================================
// CHAT LIST SCREEN - MONGODB VERSION
// =============================================================================
// This screen displays the list of chats using MongoDB
// It handles chat loading, search, and navigation

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'dart:async';
import '../services/theme_service.dart';
import '../services/mongodb_chat_service.dart';
import '../services/physical_auth_service.dart';
import '../services/logger_service.dart';
import '../utils/group_chat_naming_utility.dart';
import 'chat_screen_mongodb.dart';
import 'chat_screen_web_mongodb.dart';
import '../services/version_check_service.dart';
// import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../config/version_config.dart';
import '../theme/app_design_system.dart';

class ChatListScreenMongoDB extends StatefulWidget {
  const ChatListScreenMongoDB({Key? key}) : super(key: key);

  @override
  State<ChatListScreenMongoDB> createState() => _ChatListScreenMongoDBState();
}

class _ChatListScreenMongoDBState extends State<ChatListScreenMongoDB> {
  final MongoDBChatService _chatService = MongoDBChatService();
  final PhysicalAuthService _authService = PhysicalAuthService();
  final TextEditingController _searchController = TextEditingController();
  
  List<Map<String, dynamic>> _chats = [];
  List<Map<String, dynamic>> _filteredChats = [];
  bool _isLoading = true;
  String _searchQuery = '';
  String? _currentUserId;
  String? _currentUserName;
  String? _userRole;
  StreamSubscription? _chatsSubscription;
  late ThemeService _themeService;
  final Map<String, String> _userNameCache = {};
  final Set<String> _userNameFetching = {};
  bool _isCheckingUpdate = false;

  @override
  void initState() {
    super.initState();
    _themeService = ThemeService.instance;
    _themeService.addListener(() {
      if (mounted) setState(() {});
    });
    _initializeChatList();
    _loadUserRole();
    _searchController.addListener(_onSearchChanged);
    _maybeAutoCheckUpdate();
  }

  @override
  void dispose() {
    _chatsSubscription?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _initializeChatList() async {
    try {
      // Get current user info
      final user = await _authService.getCurrentUser();
      if (user != null) {
        _currentUserId = user['id'];
        _currentUserName = user['name'] ?? user['email'];
      }

      // Load initial chats
      await _loadChats();

      // Start listening for chat updates
      _startChatListener();
    } catch (e) {
      Log.e('Error initializing chat list', 'CHAT_LIST_MONGODB', e);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading chats: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _loadUserRole() async {
    try {
      final role = await _authService.getCurrentUserRole();
      if (mounted) {
        setState(() {
          _userRole = role;
        });
      }
    } catch (e) {
      Log.e('Error loading user role', 'CHAT_LIST_MONGODB', e);
    }
  }

  Future<void> _loadChats() async {
    try {
      final chats = await _chatService.getUserChats();
      if (mounted) {
        setState(() {
          _chats = chats;
          _filteredChats = chats;
        });
      }
    } catch (e) {
      Log.e('Error loading chats', 'CHAT_LIST_MONGODB', e);
    }
  }

  void _startChatListener() {
    _chatsSubscription = _chatService.watchUserChats().listen(
      (chats) {
        if (mounted) {
          setState(() {
            _chats = chats;
            _filteredChats = chats;
          });
        }
      },
      onError: (error) {
        Log.e('Error in chat stream', 'CHAT_LIST_MONGODB', error);
      },
    );
  }

  void _onSearchChanged() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _searchQuery = query;
      if (query.isEmpty) {
        _filteredChats = _chats;
      } else {
        _filteredChats = _chats.where((chat) {
          final name = (chat['name'] ?? '').toString().toLowerCase();
          final lastMessage = (chat['lastMessage'] ?? '').toString().toLowerCase();
          return name.contains(query) || lastMessage.contains(query);
        }).toList();
      }
    });
  }

  String _formatTimestamp(DateTime? timestamp) {
    if (timestamp == null) return '';
    // Convert to Cairo time (UTC+2)
    final cairo = timestamp.toUtc().add(const Duration(hours: 2));
    final nowCairo = DateTime.now().toUtc().add(const Duration(hours: 2));
    final difference = nowCairo.difference(cairo);

    if (difference.inDays > 0) {
      return '${cairo.day}/${cairo.month}';
    } else if (difference.inHours > 0) {
      return '${cairo.hour}:${cairo.minute.toString().padLeft(2, '0')}';
    } else {
      return '${cairo.minute.toString().padLeft(2, '0')}';
    }
  }

  String _getChatTitle(Map<String, dynamic> chat) {
    // Use the utility function for consistent naming
    return GroupChatNamingUtility.getChatDisplayName(chat, currentUserId: _currentUserId);
  }

  Future<void> _ensureUserNameCached(String userId) async {
    if (_userNameCache.containsKey(userId) || _userNameFetching.contains(userId)) return;
    _userNameFetching.add(userId);
    try {
      final user = await _chatService.getUserDetails(userId);
      final displayName = (user?['name'] ?? user?['displayName'] ?? user?['email'] ?? userId).toString();
      _userNameCache[userId] = displayName;
      if (mounted) setState(() {});
    } finally {
      _userNameFetching.remove(userId);
    }
  }

  String _buildLastMessagePreview(Map<String, dynamic> chat, {required bool isGroup}) {
    final lastMsgObj = chat['lastMessage'];
    String content;
    String? senderName;
    String? senderId;
    if (lastMsgObj is Map<String, dynamic>) {
      content = (lastMsgObj['content'] ?? '').toString();
      senderName = (lastMsgObj['senderName'] ?? '').toString();
      senderId = (lastMsgObj['senderId'] ?? '').toString();
    } else {
      content = (lastMsgObj ?? '').toString();
    }
    if (isGroup) {
      String prefix = '';
      if (senderName != null && senderName.isNotEmpty) {
        prefix = senderName;
      } else if (senderId != null && senderId.isNotEmpty) {
        final cached = _userNameCache[senderId];
        if (cached == null) _ensureUserNameCached(senderId);
        prefix = cached ?? '';
      }
      if (prefix.isNotEmpty) {
        return '$prefix: $content';
      }
    }
    return content;
  }

  Widget _buildChatTile(Map<String, dynamic> chat) {
    final chatId = chat['_id'] ?? chat['id'] ?? '';
    
    // Debug: Log chat ID to help diagnose the issue
    if (chatId.isEmpty) {
      Log.w('Empty chat ID detected: $chat', 'CHAT_LIST_MONGODB');
    }
    final bool isGroup = chat['type'] == 'group';
    final String name = _getChatTitle(chat);
    // Support nested last message object or plain string
    final lastMsgObj = chat['lastMessage'];
    final String lastMessage = _buildLastMessagePreview(chat, isGroup: isGroup);
    final lastMessageTimeStr = chat['lastMessageTime'] ?? (lastMsgObj is Map<String, dynamic> ? lastMsgObj['timestamp'] : null);
    DateTime? lastMessageTime;
    if (lastMessageTimeStr is String && lastMessageTimeStr.isNotEmpty) {
      try {
        lastMessageTime = DateTime.parse(lastMessageTimeStr);
      } catch (_) {
        lastMessageTime = null;
      }
    }
    final unreadCount = chat['unreadCount'] ?? 0;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppDesignSystem.radiusLG),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: CircleAvatar(
          radius: 24,
          backgroundColor: Theme.of(context).colorScheme.primary,
          child: Text(
            name.isNotEmpty ? name[0].toUpperCase() : 'C',
            style: AppDesignSystem.titleMedium.copyWith(
              color: Theme.of(context).colorScheme.onPrimary,
              fontWeight: FontWeight.bold,
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
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (isGroup)
              Icon(
                Icons.group,
                size: 16,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (lastMessage.isNotEmpty) ...[
              Text(
                lastMessage,
                overflow: TextOverflow.ellipsis,
                style: AppDesignSystem.bodyMedium.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                maxLines: 1,
              ),
              SizedBox(height: 2),
            ],
            if (lastMessageTime != null)
              Text(
                _formatTimestamp(lastMessageTime),
                style: AppDesignSystem.bodySmall.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant.withOpacity(0.7),
                  fontSize: 11,
                ),
              ),
          ],
        ),
        trailing: unreadCount > 0
            ? Container(
                margin: const EdgeInsets.only(top: 4),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: AppDesignSystem.errorColor,
                  borderRadius: BorderRadius.circular(AppDesignSystem.radiusMD),
                ),
                child: Text(
                  unreadCount.toString(),
                  style: AppDesignSystem.labelSmall.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              )
            : null,
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ChatScreenMongoDB(
                    chatId: chatId,
                    chatName: name,
                    isGroupChat: isGroup,
                    userIds: chat['members'] != null 
                        ? List<String>.from(chat['members'])
                        : null,
                  ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _logout() async {
    try {
      await _authService.logout();
      if (mounted) {
        Navigator.of(context).pushReplacementNamed('/login');
      }
    } catch (e) {
      Log.e('Error during logout', 'CHAT_LIST_MONGODB', e);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Chats',
          style: AppDesignSystem.headlineSmall.copyWith(
            color: Theme.of(context).colorScheme.onPrimary,
          ),
        ),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Theme.of(context).colorScheme.onPrimary,
        elevation: 0,
        centerTitle: false,
        actions: [
          if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android)
            IconButton(
              icon: const Icon(Icons.system_update_alt),
              tooltip: 'Check for update',
              onPressed: _checkForUpdate,
            ),
          IconButton(
            icon: Icon(_themeService.isDarkMode ? Icons.light_mode : Icons.dark_mode),
            onPressed: () {
              _themeService.toggleTheme();
            },
            tooltip: _themeService.isDarkMode ? 'Switch to Light Mode' : 'Switch to Dark Mode',
          ),
          PopupMenuButton<String>(
            onSelected: (value) {
              switch (value) {
                case 'search':
                  Navigator.pushNamed(context, '/search');
                  break;
                case 'create_group':
                  Navigator.pushNamed(context, '/create_group');
                  break;
                case 'logout':
                  _logout();
                  break;
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'search',
                child: Row(
                  children: [
                    Icon(Icons.person_add, color: Theme.of(context).colorScheme.primary),
                    const SizedBox(width: 8),
                    const Text('Search Users'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'create_group',
                child: Row(
                  children: [
                    Icon(Icons.group_add, color: AppDesignSystem.successColor),
                    const SizedBox(width: 8),
                    const Text('Create Group'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'logout',
                child: Row(
                  children: [
                    Icon(Icons.logout, color: AppDesignSystem.errorColor),
                    const SizedBox(width: 8),
                    const Text('Logout'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            DrawerHeader(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Theme.of(context).colorScheme.primary,
                    Theme.of(context).colorScheme.primary.withOpacity(0.8),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    radius: 30,
                    backgroundColor: Theme.of(context).colorScheme.onPrimary,
                    child: Text(
                      _currentUserName?.isNotEmpty == true 
                          ? _currentUserName![0].toUpperCase() 
                          : 'U',
                      style: AppDesignSystem.headlineMedium.copyWith(
                        color: Theme.of(context).colorScheme.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _currentUserName ?? 'User',
                    style: AppDesignSystem.titleLarge.copyWith(
                      color: Theme.of(context).colorScheme.onPrimary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            ListTile(
              leading: Icon(
                Icons.person_add,
                color: Theme.of(context).colorScheme.primary,
              ),
              title: const Text('Search Users'),
              onTap: () {
                Navigator.pop(context);
                Navigator.pushNamed(context, '/search');
              },
            ),
            ListTile(
              leading: Icon(
                Icons.group_add,
                color: AppDesignSystem.successColor,
              ),
              title: const Text('Create Group'),
              onTap: () {
                Navigator.pop(context);
                Navigator.pushNamed(context, '/create_group');
              },
            ),
            if (_userRole == 'admin')
              ListTile(
                leading: Icon(
                  Icons.admin_panel_settings,
                  color: AppDesignSystem.warningColor,
                ),
                title: const Text('Admin Panel'),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.pushNamed(context, '/admin');
                },
              ),
        ListTile(
          leading: Icon(
            Icons.person,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          title: const Text('Profile'),
          onTap: () {
            Navigator.pop(context);
            Navigator.pushNamed(context, '/profile');
          },
        ),
        ListTile(
          leading: Icon(
            Icons.settings,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          title: const Text('Settings'),
          onTap: () {
            Navigator.pop(context);
            Navigator.pushNamed(context, '/settings');
          },
        ),
            ListTile(
              leading: Icon(
                Icons.logout,
                color: AppDesignSystem.errorColor,
              ),
              title: const Text('Logout'),
              onTap: () {
                Navigator.pop(context);
                _logout();
              },
            ),
            
            const Divider(),
            
            // Version Info
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  FutureBuilder<String>(
                    future: VersionCheckService.getCurrentVersion(),
                    builder: (context, snapshot) {
                      return Text(
                        'Version ${snapshot.data ?? '1.0.3'}',
                        style: AppDesignSystem.bodySmall.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                        textAlign: TextAlign.center,
                      );
                    },
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Developed by نقيب // احمد فاروق',
                    style: AppDesignSystem.labelSmall.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search chats...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppDesignSystem.radiusMD),
                ),
              ),
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredChats.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.chat_bubble_outline,
                              size: 64,
                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              _searchQuery.isNotEmpty 
                                  ? 'No chats found matching "$_searchQuery"'
                                  : 'No chats yet. Start a conversation!',
                              style: AppDesignSystem.bodyLarge.copyWith(
                                color: Theme.of(context).colorScheme.onSurfaceVariant,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 16),
                            ElevatedButton.icon(
                              onPressed: () {
                                Navigator.pushNamed(context, '/search');
                              },
                              icon: const Icon(Icons.person_add),
                              label: const Text('Search Users'),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        itemCount: _filteredChats.length,
                        itemBuilder: (context, index) {
                          return _buildChatTile(_filteredChats[index]);
                        },
                      ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.pushNamed(context, '/search');
        },
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Theme.of(context).colorScheme.onPrimary,
        child: const Icon(Icons.person_add),
        tooltip: 'Search Users',
      ),
    );
  }

  Future<void> _checkForUpdate() async {
    if (_isCheckingUpdate) return;
    setState(() => _isCheckingUpdate = true);
    try {
      final info = await VersionCheckService.checkForUpdates();
      if (info == null) {
        if (mounted) {
          showDialog(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Text('Update Check'),
              content: const Text('Unable to check for updates right now.'),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('OK')),
              ],
            ),
          );
        }
        return;
      }

      if (info['hasUpdate'] == true) {
        final latest = (info['latestVersion'] ?? '').toString();
        final notes = (info['releaseNotes'] ?? 'Bug fixes and improvements').toString();
        final url = (info['downloadUrl'] ?? '').toString();
        if (!mounted) return;
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Text('New version available ($latest)'),
            content: SingleChildScrollView(child: Text(notes)),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Later')),
              TextButton(
                onPressed: () async {
                  Navigator.pop(ctx);
                  if (url.isNotEmpty) {
                    final uri = Uri.parse(url);
                    if (await canLaunchUrl(uri)) {
                      await launchUrl(uri, mode: LaunchMode.externalApplication);
                    }
                  }
                },
                child: const Text('Download'),
              ),
            ],
          ),
        );
      } else {
        if (!mounted) return;
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('You are up to date'),
            content: const Text('No new updates are available.'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('OK')),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Update Check Failed'),
            content: Text('Error: $e'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('OK')),
            ],
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isCheckingUpdate = false);
    }
  }

  Future<void> _maybeAutoCheckUpdate() async {
    if (kIsWeb) return;
    // Only run on Android
    if (defaultTargetPlatform != TargetPlatform.android) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final nowMs = DateTime.now().millisecondsSinceEpoch;
      final lastMs = prefs.getInt('last_update_check_ms') ?? 0;
      final intervalMs = Duration(hours: VersionConfig.updateCheckIntervalHours).inMilliseconds;
      if (nowMs - lastMs < intervalMs) return;
      await prefs.setInt('last_update_check_ms', nowMs);

      final info = await VersionCheckService.checkForUpdates();
      if (info == null) return;
      if (info['hasUpdate'] == true) {
        final latest = (info['latestVersion'] ?? '').toString();
        final notes = (info['releaseNotes'] ?? 'Bug fixes and improvements').toString();
        final url = (info['downloadUrl'] ?? '').toString();
        if (!mounted) return;
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Text('New version available ($latest)'),
            content: SingleChildScrollView(child: Text(notes)),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Later')),
              TextButton(
                onPressed: () async {
                  Navigator.pop(ctx);
                  if (url.isNotEmpty) {
                    final uri = Uri.parse(url);
                    if (await canLaunchUrl(uri)) {
                      await launchUrl(uri, mode: LaunchMode.externalApplication);
                    }
                  }
                },
                child: const Text('Download'),
              ),
            ],
          ),
        );
      }
    } catch (_) {}
  }
}
