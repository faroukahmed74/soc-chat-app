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
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import 'chat_screen.dart';
import '../services/admin_group_service.dart';
import '../services/theme_service.dart';
import '../services/chat_management_service.dart';
import '../services/logger_service.dart'; // Added import for logging
import '../widgets/version_display_widget.dart';


class ChatListScreen extends StatefulWidget {
  const ChatListScreen({super.key});

  @override
  State<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen> {

  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  late ThemeService _themeService;
  late VoidCallback _themeListener;
  
  // Cache for user display names to avoid repeated Firestore calls
  final Map<String, String> _userDisplayNameCache = {};
  
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
    
    // Run migration to fix missing user names in existing chats
    _runChatMigration();
    
    // Load user role for access control
    _loadUserRole();
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

  @override
  void dispose() {
    _searchController.dispose();
    _themeService.removeListener(_themeListener);
    super.dispose();
  }

  /// Fetches user display name from Firestore with caching
  Future<String> _getUserDisplayName(String userId) async {
    // Check cache first
    if (_userDisplayNameCache.containsKey(userId)) {
      return _userDisplayNameCache[userId]!;
    }
    
    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .get();
      
      if (userDoc.exists) {
        final userData = userDoc.data() as Map<String, dynamic>;
        
        // Debug: Log what we're getting
        Log.i('User data for $userId: $userData', 'CHAT_LIST');
        
        // Prioritize displayName, then username, then email as fallback
        String displayName = 'Unknown User';
        
        if (userData['displayName'] != null && userData['displayName'].toString().isNotEmpty) {
          displayName = userData['displayName'].toString();
          Log.i('Using displayName: $displayName', 'CHAT_LIST');
        } else if (userData['username'] != null && userData['username'].toString().isNotEmpty) {
          displayName = userData['username'].toString();
          Log.i('Using username: $displayName', 'CHAT_LIST');
        } else if (userData['email'] != null && userData['email'].toString().isNotEmpty) {
          // Only use email if it's not the current user's email
          final currentUser = FirebaseAuth.instance.currentUser;
          if (currentUser != null && userData['email'] != currentUser.email) {
            displayName = userData['email'].toString();
            Log.i('Using email: $displayName', 'CHAT_LIST');
          } else {
            displayName = 'Unknown User';
            Log.i('Email matches current user, using Unknown User', 'CHAT_LIST');
          }
        }
        
        // Cache the result
        _userDisplayNameCache[userId] = displayName;
        Log.i('Final display name for $userId: $displayName', 'CHAT_LIST');
        return displayName;
      }
      
      Log.i('User document does not exist for $userId', 'CHAT_LIST');
      return 'Unknown User';
    } catch (e) {
      Log.e('Error fetching user display name', 'CHAT_LIST', e);
      return 'Unknown User';
    }
  }

  /// Resolves chat name from members with proper user name fetching
  Future<String> _resolveChatNameFromMembers(Map<String, dynamic> chatData, String currentUserId) async {
    try {
      final members = List<String>.from(chatData['members'] ?? []);
      Log.i('Resolving chat name. Members: $members, Current user: $currentUserId', 'CHAT_LIST');
      
      if (members.length == 2) {
        // This is a private chat, get the other user's name
        final otherUserId = members.firstWhere((id) => id != currentUserId);
        Log.i('Private chat. Other user ID: $otherUserId', 'CHAT_LIST');
        final displayName = await _getUserDisplayName(otherUserId);
        Log.i('Resolved display name: $displayName', 'CHAT_LIST');
        return displayName;
      } else if (members.length > 2) {
        // This is a group chat
        final groupName = chatData['groupName'] ?? 'Group Chat';
        Log.i('Group chat. Group name: $groupName', 'CHAT_LIST');
        return groupName;
      }
    } catch (e) {
      Log.e('Error resolving chat name', 'CHAT_LIST', e);
    }
    return 'Chat';
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const Scaffold(
        body: Center(
          child: Text('User not authenticated'),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Chats'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
        actions: [
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
                  await FirebaseAuth.instance.signOut();
                  if (mounted) {
                    navigator.pushReplacementNamed('/login');
                  }
                  break;
              }
            },
            itemBuilder: (context) => [
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
                      user.email?.substring(0, 1).toUpperCase() ?? 'U',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    user.email ?? 'User',
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
                await FirebaseAuth.instance.signOut();
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
                    'Developed by نقيب \\ احمد فاروق',
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                      fontWeight: FontWeight.w400,
                    ),
                    textAlign: TextAlign.center,
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
            padding: const EdgeInsets.all(16.0),
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
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('chats')
                    .where('members', arrayContains: user.uid)
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
                          const SizedBox(height: 16),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.blue.shade50,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.blue.shade200),
                            ),
                            child: Column(
                              children: [
                                Text(
                                  '📋 Steps to Fix:',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.blue,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  '1. Click "Open Firebase Console"\n'
                                  '2. Go to Firestore → Indexes\n'
                                  '3. Create index: chats collection\n'
                                  '4. Fields: members (Array), lastMessageTime (Descending)\n'
                                  '5. Wait 1-5 minutes for build',
                                  style: TextStyle(fontSize: 12),
                                  textAlign: TextAlign.left,
                                ),
                              ],
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
                
                // Sort chats: those with lastMessageTime first (most recent), then by creation time
                final sortedChats = List<QueryDocumentSnapshot>.from(chats);
                sortedChats.sort((a, b) {
                  final aData = a.data() as Map<String, dynamic>;
                  final bData = b.data() as Map<String, dynamic>;
                  
                  final aLastMessageTime = aData['lastMessageTime'] as Timestamp?;
                  final bLastMessageTime = bData['lastMessageTime'] as Timestamp?;
                  
                  // If both have lastMessageTime, sort by most recent
                  if (aLastMessageTime != null && bLastMessageTime != null) {
                    return bLastMessageTime.compareTo(aLastMessageTime);
                  }
                  
                  // If only one has lastMessageTime, prioritize it
                  if (aLastMessageTime != null && bLastMessageTime == null) {
                    return -1;
                  }
                  if (aLastMessageTime == null && bLastMessageTime != null) {
                    return 1;
                  }
                  
                  // If neither has lastMessageTime, sort by creation time (most recent first)
                  final aCreatedAt = aData['createdAt'] as Timestamp?;
                  final bCreatedAt = bData['createdAt'] as Timestamp?;
                  
                  if (aCreatedAt != null && bCreatedAt != null) {
                    return bCreatedAt.compareTo(aCreatedAt);
                  }
                  
                  // If only one has createdAt, prioritize it
                  if (aCreatedAt != null && bCreatedAt == null) {
                    return -1;
                  }
                  if (aCreatedAt == null && bCreatedAt != null) {
                    return 1;
                  }
                  
                  // Fallback: keep original order
                  return 0;
                });
                
                if (sortedChats.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.chat_bubble_outline,
                          size: 64,
                          color: Colors.grey.shade400,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No chats yet',
                          style: TextStyle(
                            fontSize: 18,
                            color: Colors.grey.shade600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Start a conversation with someone!',
                          style: TextStyle(
                            color: Colors.grey.shade500,
                          ),
                        ),
                      ],
                    ),
                  );
                }
                
                // Filter chats based on search query
                final filteredChats = sortedChats.where((chat) {
                  final data = chat.data() as Map<String, dynamic>;
                  final chatName = data['groupName'] ?? '';
                  final lastMessage = data['lastMessage'] ?? '';
                  final query = _searchQuery.toLowerCase();
                  
                  return chatName.toLowerCase().contains(query) ||
                         lastMessage.toLowerCase().contains(query);
                }).toList();
                
                return ListView.builder(
                  itemCount: filteredChats.length,
                  itemBuilder: (context, index) {
                    final chat = filteredChats[index];
                    final data = chat.data() as Map<String, dynamic>;
                    final lastMessage = data['lastMessage'] ?? '';
                    final lastMessageTime = data['lastMessageTime'] as Timestamp?;
                    
                    // Always use FutureBuilder to resolve user names from members
                    // This ensures we get the correct display names, not cached emails
                    return FutureBuilder<String>(
                      future: _resolveChatNameFromMembers(data, user.uid),
                      builder: (context, snapshot) {
                        final resolvedName = snapshot.data ?? 'Loading...';
                        return _buildChatTile(chat, data, lastMessage, lastMessageTime, resolvedName);
                      },
                    );
                  },
                );
              },
            ),
          ),
        ),
      
  
          // Version display widget (Android only)
          const VersionDisplayWidget(
            showUpdateButton: true,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.pushNamed(context, '/search'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
        child: const Icon(Icons.add),
      ),
    );
  }

  /// Builds a chat tile with the given data
  Widget _buildChatTile(DocumentSnapshot chat, Map<String, dynamic> data, String lastMessage, Timestamp? lastMessageTime, String displayName) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Theme.of(context).colorScheme.primary,
          child: Text(
            displayName.isNotEmpty 
              ? displayName[0].toUpperCase() 
              : 'C',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        title: Text(
          displayName.isNotEmpty ? displayName : 'Chat',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (lastMessage.isNotEmpty) ...[
              Text(
                lastMessage,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 14,
                  color: Colors.black87,
                ),
              ),
              if (lastMessageTime != null) ...[
                const SizedBox(height: 2),
                Text(
                  '${_formatTime(lastMessageTime.toDate())} • ${data['lastMessageSender'] ?? 'Unknown'}',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ] else ...[
              Text(
                'New chat - tap to start conversation',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.blue.shade600,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ],
        ),
        trailing: _buildStatusBadge(data, lastMessageTime),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ChatScreen(
                chatId: chat.id,
                isGroupChat: data['isGroup'] ?? false,
                chatName: displayName,
                userIds: data['members']?.cast<String>(),
              ),
            ),
          );
        },
      ),
    );
  }
  
  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final difference = now.difference(time);
    
    if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }
  
  /// Builds the status badge for a chat tile
  Widget _buildStatusBadge(Map<String, dynamic> data, Timestamp? lastMessageTime) {
    if (lastMessageTime == null) {
      // New chat - no messages yet
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.blue.shade100,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          'New',
          style: TextStyle(
            color: Colors.blue.shade700,
            fontSize: 10,
            fontWeight: FontWeight.w500,
          ),
        ),
      );
    }
    
    // Check if this is a group chat
    final isGroup = data['isGroup'] ?? false;
    
    if (isGroup) {
      // For group chats, show "Active" if there are recent messages
      final messageAge = DateTime.now().difference(lastMessageTime.toDate());
      if (messageAge.inHours < 24) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.green.shade100,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            'Active',
            style: TextStyle(
              color: Colors.green.shade700,
              fontSize: 10,
              fontWeight: FontWeight.w500,
            ),
          ),
        );
      } else {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            'Recent',
            style: TextStyle(
              color: Colors.grey.shade700,
              fontSize: 10,
              fontWeight: FontWeight.w500,
            ),
          ),
        );
      }
    } else {
              // For private chats, check user presence
        final otherUserId = _getOtherUserId(data);
        if (otherUserId != null) {
          return StreamBuilder<DocumentSnapshot>(
            stream: FirebaseFirestore.instance.collection('users').doc(otherUserId).snapshots(),
            builder: (context, snapshot) {
            if (snapshot.hasData && snapshot.data != null) {
              final userData = snapshot.data!.data() as Map<String, dynamic>?;
              final isOnline = userData?['isOnline'] ?? false;
              final lastSeen = userData?['lastSeen'] as Timestamp?;
              
                             if (isOnline) {
                 return Container(
                   padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                   decoration: BoxDecoration(
                     color: Colors.green.shade100,
                     borderRadius: BorderRadius.circular(12),
                   ),
                   child: Row(
                     mainAxisSize: MainAxisSize.min,
                     children: [
                       Container(
                         width: 6,
                         height: 6,
                         decoration: BoxDecoration(
                           color: Colors.green.shade600,
                           shape: BoxShape.circle,
                         ),
                       ),
                       const SizedBox(width: 4),
                       Text(
                         'Online',
                         style: TextStyle(
                           color: Colors.green.shade700,
                           fontSize: 10,
                           fontWeight: FontWeight.w500,
                         ),
                       ),
                     ],
                   ),
                 );
              } else if (lastSeen != null) {
                final lastSeenAge = DateTime.now().difference(lastSeen.toDate());
                if (lastSeenAge.inMinutes < 5) {
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade100,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      'Just now',
                      style: TextStyle(
                        color: Colors.orange.shade700,
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  );
                } else if (lastSeenAge.inHours < 1) {
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade100,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${lastSeenAge.inMinutes}m ago',
                      style: TextStyle(
                        color: Colors.orange.shade700,
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  );
                } else {
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      'Offline',
                      style: TextStyle(
                        color: Colors.grey.shade700,
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  );
                }
              } else {
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    'Offline',
                    style: TextStyle(
                      color: Colors.grey.shade700,
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                );
              }
            }
            
            // Loading state
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '...',
                style: TextStyle(
                  color: Colors.grey.shade700,
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                ),
              ),
            );
          },
        );
      }
    }
    
    // Fallback for unknown cases
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        'Chat',
        style: TextStyle(
          color: Colors.grey.shade700,
          fontSize: 10,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
  
  /// Gets the other user ID from a private chat
  String? _getOtherUserId(Map<String, dynamic> data) {
    final members = List<String>.from(data['members'] ?? []);
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    
    if (currentUserId != null && members.length == 2) {
      return members.firstWhere((id) => id != currentUserId);
    }
    return null;
  }
} 