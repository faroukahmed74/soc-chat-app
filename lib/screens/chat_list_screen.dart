// =============================================================================
// CHAT LIST SCREEN
// =============================================================================
// This screen displays a list of all user chats and group conversations.
// It serves as the main navigation hub after user authentication.
// The screen includes search functionality, theme/language toggles, and navigation.
//
// KEY FEATURES:
// - List of all user chats and groups
// - Real-time chat updates and last message display
// - Search functionality for finding specific chats
// - Navigation to other app sections (profile, admin, etc.)
// - Theme and language switching
// - Responsive design for different screen sizes
//
// ARCHITECTURE:
// - Uses StreamBuilder for real-time chat list updates
// - Implements search filtering with real-time results
// - Delegates to various services for different functionalities
// - Supports both private chats and group conversations
//
// PLATFORM SUPPORT:
// - Web: Full functionality with responsive design
// - Mobile: Native navigation and touch interactions
// - Cross-platform: Unified interface for all platforms

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
// Unified chat screen for all platforms (web, Android, iOS)
import 'chat_screen_mongodb.dart';
import '../services/admin_group_service.dart';
import '../services/theme_service.dart';
// Firebase services removed - using MongoDB/ngrok API only
import '../services/logger_service.dart'; // Added import for logging
import '../config/database_config.dart';
import '../services/local_auth_service.dart';
import '../services/version_check_service.dart';
import '../utils/responsive_utils.dart';
import '../utils/group_chat_naming_utility.dart';
// Firebase imports removed - using MongoDB/ngrok API only
 


class ChatListScreen extends StatefulWidget {
  const ChatListScreen({super.key});

  @override
  State<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen> {

  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  final FCMNotificationService _fcmService = FCMNotificationService();
  bool _isFCMHealthy = false;
  late ThemeService _themeService;
  late VoidCallback _themeListener;
  String? _currentUserId;
  Map<String, dynamic>? _localUser;
  bool _isLoadingLocalUser = true;
  
  // User role management
  String _userRole = 'user';
  bool _isLoadingRole = true;

  @override
  void initState() {
    super.initState();
    _themeService = ThemeService.instance;
    _themeListener = () {
      if (mounted) {
        setState(() {});
      }
    };
    _themeService.addListener(_themeListener);
    
    // When using the physical server, avoid any Firebase calls to prevent runtime errors.
    if (DatabaseConfig.usePhysicalServer) {
      // Default role state to non-loading and standard user
      _isLoadingRole = false;
      _userRole = 'user';
      // Skip Firebase-dependent health checks and migrations
      // Load local user data instead
      LocalAuthService.getCurrentUser().then((userData) {
        if (mounted) {
          setState(() {
            _localUser = userData;
            _currentUserId = userData?['id'];
            _isLoadingLocalUser = false;
          });
        }
      });
    } else {
      // Run migration to fix missing user names in existing chats
      _runChatMigration();
      
      // Load user role for access control
      _loadUserRole();
      
      // Check FCM service health
      _checkFCMHealth();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Refresh chat list when returning from other screens
    setState(() {});
  }
  
  /// Runs migration to fix missing user names in existing chats
  Future<void> _runChatMigration() async {
    try {
      await ChatManagementService.fixMissingUserNames();
    } catch (e) {
      Log.e('Error during chat migration', 'CHAT_LIST', e);
    }
  }

  

  /// Loads the current user's role for access control
  Future<void> _loadUserRole() async {
    try {
      final role = await AdminGroupService().getCurrentUserRole();
      if (mounted) {
        setState(() {
          _userRole = role;
          _isLoadingRole = false;
        });
      }
    } catch (e) {
      Log.e('Error loading user role', 'CHAT_LIST', e);
      if (mounted) {
        setState(() {
          _userRole = 'user';
          _isLoadingRole = false;
        });
      }
    }
  }

  /// Check FCM service health
  Future<void> _checkFCMHealth() async {
    try {
      final isHealthy = await _fcmService.checkFCMServerHealth();
      if (mounted) {
        setState(() {
          _isFCMHealthy = isHealthy;
        });
      }
      Log.i('FCM health check: ${isHealthy ? "healthy" : "unhealthy"}', 'CHAT_LIST');
    } catch (e) {
      Log.e('Error checking FCM health', 'CHAT_LIST', e);
      if (mounted) {
        setState(() {
          _isFCMHealthy = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _themeService.removeListener(_themeListener);
    super.dispose();
  }

  

  

  @override
  Widget build(BuildContext context) {
    final isLocalServer = DatabaseConfig.usePhysicalServer;
    // Access FirebaseAuth only when not using the physical server to avoid core/no-app
    final firebaseUser = isLocalServer ? null : FirebaseAuth.instance.currentUser;
    if (!isLocalServer && firebaseUser == null) {
      return const Scaffold(
        body: Center(
          child: Text('User not authenticated'),
        ),
      );
    }
    if (isLocalServer && _isLoadingLocalUser) {
      // Still loading local user data
      return const Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Loading user data...'),
            ],
          ),
        ),
      );
    }
    
    if (isLocalServer && _localUser == null) {
      // In physical server mode, if local user is missing, redirect to login.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
        }
      });
      return const Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Redirecting to login...'),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Chats'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
        actions: [
          // FCM Status Indicator
          if (!isLocalServer)
            IconButton(
              onPressed: () => Navigator.pushNamed(context, '/startup-diagnostics'),
              icon: Icon(
                _isFCMHealthy ? Icons.notifications_active : Icons.notifications_off,
                color: _isFCMHealthy ? Colors.green : Colors.orange,
              ),
              tooltip: _isFCMHealthy ? 'FCM Service Healthy' : 'FCM Service Issues',
            ),
          IconButton(
            onPressed: () => _themeService.toggleTheme(),
            icon: Icon(
              _themeService.isDarkMode ? Icons.light_mode : Icons.dark_mode,
              color: Colors.white,
            ),
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: (value) async {
              switch (value) {
                case 'search_users':
                  Navigator.pushNamed(context, '/search');
                  break;
                case 'create_group':
                  Navigator.pushNamed(context, '/create_group');
                  break;
                case 'profile':
                  Navigator.pushNamed(context, '/profile');
                  break;
                case 'admin':
                  // Double-check admin access before navigation
                  if (_userRole == 'admin') {
                    Navigator.pushNamed(context, '/admin');
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Access denied. Admin privileges required.'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                  break;
                case 'logout':
                  final navigator = Navigator.of(context);
                  if (DatabaseConfig.usePhysicalServer) {
                    await LocalAuthService.logout();
                  } else {
                    await FirebaseAuth.instance.signOut();
                  }
                  if (mounted) {
                    navigator.pushReplacementNamed('/login');
                  }
                  break;
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'search_users',
                child: Row(
                  children: [
                    Icon(Icons.search),
                    SizedBox(width: 8),
                    Text('Search Users'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'create_group',
                child: Row(
                  children: [
                    Icon(Icons.group_add),
                    SizedBox(width: 8),
                    Text('Create Group'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'profile',
                child: Row(
                  children: [
                    Icon(Icons.person),
                    SizedBox(width: 8),
                    Text('Profile'),
                  ],
                ),
              ),
              // Only show admin panel for admin users (when role is loaded)
              if (!_isLoadingRole && _userRole == 'admin')
                const PopupMenuItem(
                  value: 'admin',
                  child: Row(
                    children: [
                      Icon(Icons.admin_panel_settings),
                      SizedBox(width: 8),
                      Text('Admin Panel'),
                    ],
                  ),
                ),
              const PopupMenuItem(
                value: 'logout',
                child: Row(
                  children: [
                    Icon(Icons.logout),
                    SizedBox(width: 8),
                    Text('Logout'),
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
            // User Profile Header
            DrawerHeader(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircleAvatar(
                    radius: 25,
                    backgroundColor: Colors.white,
                    child: Text(
                      (() {
                        final email = isLocalServer
                            ? (_localUser?['email'] as String? ?? '')
                            : (firebaseUser?.email ?? '');
                        return email.isNotEmpty
                            ? email.substring(0, 1).toUpperCase()
                            : 'U';
                      })(),
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    (() {
                      final email = isLocalServer
                          ? (_localUser?['email'] as String? ?? '')
                          : (firebaseUser?.email ?? '');
                      return email.isNotEmpty ? email : 'User';
                    })(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Online',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.8),
                      fontSize: 14,
                    ),
                  ),
                  if (_isLoadingRole)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox(
                            width: 12,
                            height: 12,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Colors.white.withValues(alpha: 0.6),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Loading...',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.6),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  // Debug: Show current user role (remove in production)
                  if (!_isLoadingRole)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        'Role: $_userRole',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.6),
                          fontSize: 12,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            
            // Navigation Items
            ListTile(
              leading: const Icon(Icons.chat),
              title: const Text('Chats'),
              selected: true,
              onTap: () {
                Navigator.pop(context);
              },
            ),
            
            ListTile(
              leading: const Icon(Icons.person),
              title: const Text('Profile'),
              onTap: () {
                Navigator.pop(context);
                Navigator.pushNamed(context, '/profile');
              },
            ),
            
            ListTile(
              leading: const Icon(Icons.search),
              title: const Text('Search Users'),
              onTap: () {
                Navigator.pop(context);
                Navigator.pushNamed(context, '/search');
              },
            ),
            
            ListTile(
              leading: const Icon(Icons.group_add),
              title: const Text('Create Group'),
              onTap: () {
                Navigator.pop(context);
                Navigator.pushNamed(context, '/create_group');
              },
            ),
            
            // Only show admin panel for admin users (when role is loaded)
            if (!_isLoadingRole && _userRole == 'admin')
              ListTile(
                leading: const Icon(Icons.admin_panel_settings),
                title: const Text('Admin Panel'),
                onTap: () {
                  Navigator.pop(context);
                  // Double-check admin access before navigation
                  if (_userRole == 'admin') {
                    Navigator.pushNamed(context, '/admin');
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Access denied. Admin privileges required.'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                },
              ),
            
            ListTile(
              leading: const Icon(Icons.settings),
              title: const Text('Settings'),
              onTap: () {
                Navigator.pop(context);
                Navigator.pushNamed(context, '/settings');
              },
            ),
            
            ListTile(
              leading: const Icon(Icons.help),
              title: const Text('Help & Support'),
              onTap: () {
                Navigator.pop(context);
                Navigator.pushNamed(context, '/help');
              },
            ),
            
            const Divider(),
            
            // Theme Toggle
            ListTile(
              leading: Icon(
                _themeService.isDarkMode ? Icons.light_mode : Icons.dark_mode,
              ),
              title: Text(_themeService.isDarkMode ? 'Light Mode' : 'Dark Mode'),
              onTap: () {
                _themeService.toggleTheme();
                Navigator.pop(context);
              },
            ),
            
            const Divider(),
            
            // Logout
            ListTile(
              leading: const Icon(Icons.logout, color: Colors.red),
              title: const Text('Logout', style: TextStyle(color: Colors.red)),
              onTap: () async {
                Navigator.pop(context);
                if (DatabaseConfig.usePhysicalServer) {
                  await LocalAuthService.logout();
                } else {
                  await FirebaseAuth.instance.signOut();
                }
                if (mounted) {
                  Navigator.pushReplacementNamed(context, '/login');
                }
              },
            ),
            
            const Divider(),
            
            // Developer Credit
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  const Divider(),
                  const SizedBox(height: 8),
                  Text(
                    'Developed by نقيب // احمد فاروق',
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                      fontWeight: FontWeight.w400,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 4),
                  FutureBuilder<String>(
                    future: VersionCheckService.getCurrentVersion(),
                    builder: (context, snapshot) {
                      return Text(
                        'Version ${snapshot.data ?? '1.0.3'}',
                        style: TextStyle(
                          fontSize: 11,
                          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                          fontWeight: FontWeight.w300,
                        ),
                        textAlign: TextAlign.center,
                      );
                    },
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          // Search Bar
          Padding(
            padding: ResponsiveUtils.getResponsivePadding(context),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search chats...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: Theme.of(context).colorScheme.surface,
              ),
              onChanged: (value) {
                setState(() {
                  _searchQuery = value;
                });
              },
            ),
          ),
          
          // Chats List
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async {
                setState(() {});
              },
              child: DatabaseConfig.usePhysicalServer
                  ? _buildLocalChatList((_localUser?['id'] ?? '') as String)
                  : _buildFirebaseChatList(firebaseUser!.uid),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.pushNamed(context, '/search');
        },
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
        child: const Icon(Icons.person_add),
        tooltip: 'Search Users',
      ),
    );
  }
  
  
  
  

  

  

  
  
  
  
  

  Widget _buildFirebaseChatList(String userId) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('chats')
          .where('members', arrayContains: userId)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        
        if (snapshot.hasError) {
          final error = snapshot.error.toString();
          if (error.contains('failed-precondition')) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.storage,
                    size: 64,
                    color: Colors.orange.shade400,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Database Index Required',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'You need to create a Firestore index.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.grey.shade600,
                    ),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: () {
                      // Open Firebase Console in browser
                      launchUrl(Uri.parse('https://console.firebase.google.com/project/soc-chat-app-ca57e/firestore/indexes'));
                    },
                    icon: const Icon(Icons.open_in_browser),
                    label: const Text('Open Firebase Console'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ],
              ),
            );
          } else {
            return Center(
              child: Text('Error: $error'),
            );
          }
        }
        
        final chats = snapshot.data?.docs ?? [];
        return _buildChatListView(chats);
      },
    );
  }

  Widget _buildLocalChatList(String userId) {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _localChatsStream(userId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        
        if (snapshot.hasError) {
          return Center(
            child: Text('Error: ${snapshot.error}'),
          );
        }
        
        final chats = snapshot.data ?? [];
        return _buildLocalChatListView(chats);
      },
    );
  }

  Stream<List<Map<String, dynamic>>> _localChatsStream(String userId) {
    // Poll server periodically for updated chat list when using physical server
    return Stream.periodic(const Duration(seconds: 3))
        .asyncMap((_) => _getLocalChats(userId));
  }

  Future<List<Map<String, dynamic>>> _getLocalChats(String userId) async {
    try {
      final databaseService = await DatabaseConfig.getDatabaseService();
      final docs = await databaseService.getUserChats(userId);
      return docs.map((doc) => (doc.data() as Map<String, dynamic>)).toList();
    } catch (e) {
      Log.e('Error fetching local chats', 'CHAT_LIST', e);
      return [];
    }
  }

  Widget _buildLocalChatListView(List<Map<String, dynamic>> chats) {
    if (chats.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.chat_bubble_outline,
              size: 64,
              color: Colors.grey,
            ),
            SizedBox(height: 16),
            Text(
              'No chats yet',
              style: TextStyle(
                fontSize: 18,
                color: Colors.grey,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Start a conversation with someone!',
              style: TextStyle(
                color: Colors.grey,
              ),
            ),
          ],
        ),
      );
    }

    // Filter chats based on search query
    final filteredChats = chats.where((chat) {
      if (_searchQuery.isEmpty) return true;
      
      final chatName = chat['name']?.toString().toLowerCase() ?? '';
      final lastMessage = chat['lastMessage']?.toString().toLowerCase() ?? '';
      
      return chatName.contains(_searchQuery.toLowerCase()) ||
             lastMessage.contains(_searchQuery.toLowerCase());
    }).toList();

    // Preload user names for better performance
    _preloadUserNamesForChats(filteredChats);

    return ListView.builder(
      itemCount: filteredChats.length,
      itemBuilder: (context, index) {
        final chat = filteredChats[index];
        return _buildLocalChatTile(chat);
      },
    );
  }

  void _preloadUserNamesForChats(List<Map<String, dynamic>> chats) {
    try {
      final List<String> userIds = <String>[];
      
      // Collect all user IDs from chats
      for (final chat in chats) {
        final members = List<String>.from(chat['members'] ?? chat['memberIds'] ?? []);
        for (final memberId in members) {
          if (memberId != _currentUserId && !userIds.contains(memberId)) {
            userIds.add(memberId);
          }
        }
      }
      
      if (userIds.isNotEmpty) {
        // Preload user names asynchronously
        GroupChatNamingUtility.preloadUserNames(userIds);
      }
    } catch (e) {
      Log.e('Error preloading user names', 'CHAT_LIST_SCREEN', e);
    }
  }

  Widget _buildLocalChatTile(Map<String, dynamic> chat) {
    final dynamic time = chat['lastMessageTime'] ?? chat['updatedAt'] ?? chat['createdAt'];
    // More robust group detection - check multiple possible fields
    final bool isGroup = (chat['isGroup'] == true) || 
                        (chat['type'] == 'group') || 
                        (chat['isGroupChat'] == true) ||
                        (chat['members'] != null && (chat['members'] as List).length > 2);
    
    // Use enhanced naming utility for consistent display names
    String displayName = GroupChatNamingUtility.getChatDisplayName(chat, currentUserId: _currentUserId);
    
    final String chatId = (chat['id']?.toString() ?? chat['_id']?.toString() ?? '');
    final List<String> memberIds = List<String>.from(chat['members'] ?? chat['memberIds'] ?? []);

    return ListTile(
      leading: CircleAvatar(
        backgroundColor: Theme.of(context).colorScheme.primary,
        child: Text(
          displayName.isNotEmpty ? displayName[0].toUpperCase() : 'C',
          style: const TextStyle(color: Colors.white),
        ),
      ),
      title: Text(
        displayName,
        style: const TextStyle(fontWeight: FontWeight.bold),
      ),
      subtitle: Text(
        chat['lastMessage']?.toString() ?? 'No messages yet',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: time != null
          ? Text(
              _formatTimestamp(time),
              style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: 12,
              ),
            )
          : null,
      onTap: () {
        // Use unified MongoDB chat screen for all platforms (web, Android, iOS)
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ChatScreenMongoDB(
              chatId: chatId,
              chatName: displayName,
              isGroupChat: isGroup,
              userIds: memberIds,
            ),
          ),
        );
      },
    );
  }

  Widget _buildChatListView(List<QueryDocumentSnapshot> chats) {
    // Filter chats based on search query
    final List<QueryDocumentSnapshot> filtered = _searchQuery.isEmpty
        ? chats
        : chats.where((chat) {
            final data = chat.data() as Map<String, dynamic>;
            final chatName = (data['name']?.toString() ?? '').toLowerCase();
            final lastMessage = (data['lastMessage']?.toString() ?? '').toLowerCase();
            final q = _searchQuery.toLowerCase();
            return chatName.contains(q) || lastMessage.contains(q);
          }).toList();

    return ListView.builder(
      itemCount: filtered.length,
      itemBuilder: (context, index) {
        final chat = filtered[index];
        final data = chat.data() as Map<String, dynamic>;
        final dynamic time = data['lastMessageTime'];
        // More robust group detection - check multiple possible fields
        final bool isGroup = (data['isGroup'] == true) || 
                            (data['type'] == 'group') || 
                            (data['isGroupChat'] == true) ||
                            (data['members'] != null && (data['members'] as List).length > 2);
        
        // Use enhanced naming utility for consistent display names
        String displayName = GroupChatNamingUtility.getChatDisplayName(data, currentUserId: _currentUserId);

        return ListTile(
          leading: CircleAvatar(
            backgroundColor: Theme.of(context).colorScheme.primary,
            child: Text(
              displayName.isNotEmpty ? displayName[0].toUpperCase() : 'C',
              style: const TextStyle(color: Colors.white),
            ),
          ),
          title: Text(displayName, style: const TextStyle(fontWeight: FontWeight.bold)),
          subtitle: Text(
            data['lastMessage']?.toString() ?? 'No messages',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          trailing: time != null
              ? Text(
                  _formatTimestamp(time),
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                )
              : null,
          onTap: () {
            // Use unified MongoDB chat screen for all platforms (web, Android, iOS)
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => ChatScreenMongoDB(
                  chatId: chat.id,
                  chatName: displayName,
                  isGroupChat: isGroup,
                  userIds: List<String>.from(data['members'] ?? []),
                ),
              ),
            );
          },
        );
      },
    );
  }

  String _formatTimestamp(dynamic timestamp) {
    if (timestamp == null) return '';
    
    try {
      DateTime dateTime;
      if (timestamp is String) {
        dateTime = DateTime.parse(timestamp);
      } else if (timestamp is int) {
        dateTime = DateTime.fromMillisecondsSinceEpoch(timestamp);
      } else if (timestamp is Timestamp) {
        dateTime = timestamp.toDate();
      } else {
        return '';
      }
      
      final now = DateTime.now();
      final difference = now.difference(dateTime);
      
      if (difference.inDays > 0) {
        return '${difference.inDays}d';
      } else if (difference.inHours > 0) {
        return '${difference.inHours}h';
      } else if (difference.inMinutes > 0) {
        return '${difference.inMinutes}m';
      } else {
        return 'now';
      }
    } catch (e) {
      return '';
    }
  }
}