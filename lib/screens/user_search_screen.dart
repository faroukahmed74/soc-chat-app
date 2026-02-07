// =============================================================================
// USER SEARCH SCREEN
// =============================================================================
// This screen allows users to search for other users and initiate private chats.
// It includes user search, profile viewing, and responsive design
// for different screen sizes.
//
// KEY FEATURES:
// - User search with real-time filtering
// - User profile viewing and interaction
// - Chat initiation with other users
// - Responsive design with adaptive layouts
//
// ARCHITECTURE:
// - Uses StreamBuilder for real-time search results
// - Implements responsive design with MediaQuery
// - Provides user interaction capabilities
//
// PLATFORM SUPPORT:
// - Web: Full functionality with responsive design
// - Mobile: Touch-optimized interface
// - Cross-platform: Unified search experience

import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/local_auth_service.dart';
import 'chat_screen_mongodb.dart';

import '../services/theme_service.dart';
import '../services/logger_service.dart';
import '../config/database_config.dart';
import '../services/database_service.dart';
import '../services/mongodb_chat_service.dart';

class UserSearchScreen extends StatefulWidget {
  const UserSearchScreen({Key? key}) : super(key: key);

  @override
  State<UserSearchScreen> createState() => _UserSearchScreenState();
}

class _UserSearchScreenState extends State<UserSearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  List<DocumentSnapshot>? _allUsers;
  String _searchQuery = '';
  bool _isLoading = false;
  late ThemeService _themeService;
  String? _currentUserId;

  @override
  void initState() {
    super.initState();
    _themeService = ThemeService.instance;
    _themeService.addListener(() {
      if (mounted) {
        setState(() {});
      }
    });
    _fetchAllUsers();
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.trim().toLowerCase();
      });
    });
  }

  Future<void> _fetchAllUsers() async {
    setState(() { _isLoading = true; });
    
    try {
      // Get current user ID from stored token
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');
      if (token == null || token.isEmpty) {
        if (mounted) {
          setState(() { _isLoading = false; });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Please log in to search users')),
          );
        }
        return;
      }
      // Verify token with server (handles expired/invalid tokens gracefully on web)
      final isValid = await LocalAuthService.verifyToken();
      if (!isValid) {
        await LocalAuthService.logout();
        if (mounted) {
          setState(() { _isLoading = false; });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Session expired. Please log in again.')),
          );
        }
        return;
      }
      // Resolve current user id
      final prefsUser = prefs.getString('user_data');
      if (prefsUser != null) {
        try {
          final currentUserObj = json.decode(prefsUser);
          _currentUserId = (currentUserObj['id'] ?? currentUserObj['_id'])?.toString();
        } catch (_) {}
      }
      
      // Use physical server (MongoDB)
      final databaseService = await DatabaseConfig.getDatabaseService();
      final users = await databaseService.getAllUsers();
      
      setState(() {
        _allUsers = users;
        _isLoading = false;
      });
    } catch (e) {
      Log.e('Error fetching users', 'USER_SEARCH', e);
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        final msg = e.toString();
        if (msg.contains('403')) {
          await LocalAuthService.logout();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Access denied. Please log in again.')),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error loading users: $e')),
          );
        }
      }
    }
  }

  List<DocumentSnapshot> _getVisibleUsers(Set<String> blockedIds) {
    if (_allUsers == null) return [];
    final visible = _allUsers!
        .where((user) {
          final data = user.data();
          final role = (data['role'] ?? '').toString();
          final isAIBot = data['isAIBot'] == true;
          // Exclude AI Assistant - only appears in chat list via AI button, not in Search Users
          if (role == 'ai_bot' || isAIBot) return false;
          return user.id != _currentUserId && !blockedIds.contains(user.id);
        })
        .toList();
    if (_searchQuery.isEmpty) return visible;
    final matches = <DocumentSnapshot>[];
    final rest = <DocumentSnapshot>[];
    for (final user in visible) {
      final data = user.data();
      final username = (data['username'] ?? '').toString().toLowerCase();
      final email = (data['email'] ?? '').toString().toLowerCase();
      final displayName = (data['displayName'] ?? '').toString().toLowerCase();
      
      if (username.contains(_searchQuery) || email.contains(_searchQuery) || displayName.contains(_searchQuery)) {
        matches.add(user);
      } else {
        rest.add(user);
      }
    }
    return [...matches, ...rest];
  }

  void _showUserProfile(DocumentSnapshot user) {
    final data = user.data() as Map<String, dynamic>? ?? {};
    final displayName = (data['displayName'] ?? data['name'] ?? '').toString();
    final email = (data['email'] ?? '').toString();
    final phoneNumber = (data['phoneNumber'] ?? data['phone'] ?? '').toString();
    final photoUrl = (data['photoUrl'] ?? '').toString();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: _themeService.isDarkMode ? const Color(0xFF353941) : Colors.white,
        title: Text(
          'User Profile',
          style: TextStyle(
            color: _themeService.isDarkMode ? Colors.white : Colors.black87,
          ),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Profile Picture
              Center(
                child: CircleAvatar(
                  radius: 50,
                  backgroundImage: photoUrl.isNotEmpty
                      ? NetworkImage(photoUrl)
                      : null,
                  child: photoUrl.isEmpty
                      ? const Icon(Icons.person, size: 50)
                      : null,
                ),
              ),
              const SizedBox(height: 20),
              
              // Display Name
              _buildProfileField(
                icon: Icons.person,
                label: 'Display Name',
                value: displayName.isNotEmpty ? displayName : 'Not provided',
              ),
              const SizedBox(height: 16),
              
              // Email
              _buildProfileField(
                icon: Icons.email,
                label: 'Email',
                value: email.isNotEmpty ? email : 'Not provided',
              ),
              const SizedBox(height: 16),
              
              // Phone Number
              _buildProfileField(
                icon: Icons.phone,
                label: 'Phone Number',
                value: phoneNumber.isNotEmpty ? phoneNumber : 'Not provided',
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Close',
              style: TextStyle(
                color: _themeService.isDarkMode ? Colors.white70 : Colors.black54,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _startChat(user.id);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF5F85DB),
              foregroundColor: Colors.white,
            ),
            child: const Text('Start Chat'),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileField({required IconData icon, required String label, required String value}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: _themeService.isDarkMode ? Colors.white70 : Colors.grey[700]),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: _themeService.isDarkMode ? Colors.white70 : Colors.grey[600],
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: TextStyle(
                  fontSize: 16,
                  color: _themeService.isDarkMode ? Colors.white : Colors.black87,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _startChat(String otherUserId) async {
    try {
      // Validate other user ID
      if (otherUserId.isEmpty) {
        Log.e('Cannot start chat: other user ID is empty', 'USER_SEARCH');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Invalid user selected')),
          );
        }
        return;
      }
      
      // Validate other user ID format (should be a valid MongoDB ObjectId - 24 hex characters)
      if (otherUserId.length != 24 || !RegExp(r'^[0-9a-fA-F]{24}$').hasMatch(otherUserId)) {
        Log.e('Cannot start chat: invalid other user ID format: $otherUserId', 'USER_SEARCH');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Invalid user ID format')),
          );
        }
        return;
      }
      
      // Get current user ID from stored token
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');
      if (token == null) {
        Log.e('Cannot start chat: no auth token', 'USER_SEARCH');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Please log in again')),
          );
        }
        return;
      }
      
      // Get user data for the other user
      final databaseService = await DatabaseConfig.getDatabaseService();
      final userDoc = await databaseService.getUser(otherUserId);
      final userData = userDoc?.data() ?? {};
      
      // Get chat name from user data - ensure it's not empty
      String chatName = 'Unknown User';
      if (userData['username'] != null && userData['username'].toString().trim().isNotEmpty) {
        chatName = userData['username'].toString().trim();
      } else if (userData['displayName'] != null && userData['displayName'].toString().trim().isNotEmpty) {
        chatName = userData['displayName'].toString().trim();
      } else if (userData['email'] != null && userData['email'].toString().trim().isNotEmpty) {
        chatName = userData['email'].toString().trim();
      } else if (userData['name'] != null && userData['name'].toString().trim().isNotEmpty) {
        chatName = userData['name'].toString().trim();
      }
      
      // Ensure we never send an empty string
      if (chatName.trim().isEmpty) {
        chatName = 'Unknown User';
      }
      
      Log.i('Chat name determined: "$chatName"', 'USER_SEARCH');
      
      // Create or find existing chat
      // Include both the current user and the other user
      // The server will automatically add the current user if missing
      String? currentUserId;
      final prefsUser = prefs.getString('user_data');
      if (prefsUser != null) {
        try {
          final currentUserObj = json.decode(prefsUser);
          currentUserId = currentUserObj['id'] ?? currentUserObj['_id'];
        } catch (e) {
          Log.e('Error parsing user_data', 'USER_SEARCH', e);
        }
      }
      
      // Try LocalAuthService as fallback
      if (currentUserId == null || currentUserId.isEmpty) {
        currentUserId = await LocalAuthService.getCurrentUserIdAsync();
      }
      
      final members = [
        if (currentUserId != null && currentUserId.isNotEmpty) currentUserId,
        otherUserId,
      ].where((id) => id != null && id.isNotEmpty).toList();
      
      Log.i('Attempting to start chat with: $otherUserId (members: ${members.join(", ")})', 'USER_SEARCH');
      
      // Find existing chat or create new one
      final chatService = MongoDBChatService();
      Map<String, dynamic>? chatData;
      String? errorMessage;
      
      try {
        chatData = await chatService.findOrCreateChat('private', chatName, members);
      } catch (e) {
        Log.e('Error creating chat', 'USER_SEARCH', e);
        errorMessage = e.toString();
        // Try to extract a more user-friendly error message
        if (errorMessage.contains('Failed to create chat:')) {
          final match = RegExp(r'Failed to create chat: \d+ - (.+)').firstMatch(errorMessage);
          if (match != null) {
            errorMessage = match.group(1);
          }
        }
        // Log the full error for debugging
        Log.e('Full error details: $e', 'USER_SEARCH');
      }
      
      if (chatData == null) {
        Log.e('Failed to create or find chat', 'USER_SEARCH');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(errorMessage ?? 'Failed to create or find chat. Please try again.'),
              duration: const Duration(seconds: 5),
            ),
          );
        }
        return;
      }
      
      // Extract chat ID from the response structure
      // The service now returns chat data directly
      final chatId = chatData['_id'] ?? chatData['id'] ?? '';
      
      Log.i('Chat found/created: $chatId', 'USER_SEARCH');
      
      if (chatId.isEmpty) {
        Log.e('Chat ID is empty after creation', 'USER_SEARCH');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Error: Invalid chat ID')),
          );
        }
        return;
      }
      
      await Future.delayed(const Duration(milliseconds: 300));
      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => ChatScreenMongoDB(
            chatId: chatId,
            isGroupChat: false,
            chatName: chatName,
          )),
        );
      }
    } catch (e) {
      Log.e('Error starting chat', 'USER_SEARCH', e);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error starting chat: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isWideScreen = MediaQuery.of(context).size.width > 600;
    final currentUser = null; // We'll get this from token if needed

    final isDarkMode = _themeService.isDarkMode;

    return Scaffold(
      backgroundColor: isDarkMode ? const Color(0xFF26282B) : const Color(0xFFFAFAFA),
      appBar: AppBar(
        title: Text(
          'Search Users',
          style: TextStyle(
            color: isDarkMode ? Colors.white : Colors.black87,
          ),
        ),
        backgroundColor: isDarkMode ? const Color(0xFF353941) : Colors.white,
        foregroundColor: isDarkMode ? Colors.white : Colors.black87,
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(isDarkMode ? Icons.light_mode : Icons.dark_mode),
            onPressed: () {
              _themeService.toggleTheme();
            },
            tooltip: isDarkMode ? 'Switch to Light Mode' : 'Switch to Dark Mode',
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: TextField(
                controller: _searchController,
                style: TextStyle(
                  color: isDarkMode ? Colors.white : Colors.black87,
                ),
                decoration: InputDecoration(
                  labelText: 'Search users by username or email',
                  labelStyle: TextStyle(
                    color: isDarkMode ? Colors.white70 : Colors.black54,
                  ),
                  prefixIcon: Icon(
                    Icons.search,
                    color: isDarkMode ? Colors.white70 : Colors.black54,
                  ),
                  filled: true,
                  fillColor: isDarkMode ? const Color(0xFF353941) : Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: isDarkMode ? Colors.white24 : Colors.grey.shade300,
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: isDarkMode ? Colors.white24 : Colors.grey.shade300,
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: isDarkMode ? const Color(0xFF5F85DB) : const Color(0xFF5F85DB),
                      width: 2,
                    ),
                  ),
                ),
              ),
            ),
            if (_isLoading)
              const Expanded(child: Center(child: CircularProgressIndicator())),
            if (!_isLoading && _allUsers != null)
              Expanded(
                child: FutureBuilder<QuerySnapshot>(
                  future: Future.value(QuerySnapshot(docs: [])), // Empty for now
                  builder: (context, blockedSnapshot) {
                    final blockedIds = <String>{}; // Empty for now, can be implemented later
                    final visibleUsers = _getVisibleUsers(blockedIds);
                    if (visibleUsers.isEmpty) {
                      return Center(
                        child: Text(
                          'No users found.',
                          style: TextStyle(
                            color: isDarkMode ? Colors.white70 : Colors.black54,
                          ),
                        ),
                      );
                    }
                    return ListView.builder(
                      itemCount: visibleUsers.length,
                      itemBuilder: (context, index) {
                        final user = visibleUsers[index];
                        final userId = user.id;
                        
                        // Handle both DocumentSnapshot and user objects
                        String photoUrl = '';
                        String username = '';
                        String displayName = '';
                        String email = '';
                        
                        final data = user.data();
                        photoUrl = data['photoUrl'] ?? '';
                        username = data['username'] ?? '';
                        displayName = data['displayName'] ?? '';
                        email = data['email'] ?? '';
                        
                        return Card(
                          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                          color: isDarkMode ? const Color(0xFF353941) : Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: BorderSide(
                              color: isDarkMode ? Colors.white24 : Colors.grey.shade200,
                              width: 1,
                            ),
                          ),
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: isDarkMode ? const Color(0xFF5F85DB) : const Color(0xFF5F85DB),
                              backgroundImage: photoUrl.isNotEmpty
                                  ? NetworkImage(photoUrl)
                                  : null,
                              child: photoUrl.isEmpty
                                  ? Icon(
                                      Icons.person,
                                      color: Colors.white,
                                    )
                                  : null,
                            ),
                            title: Text(
                              displayName.isNotEmpty ? displayName : (username.isNotEmpty ? username : 'Unknown User'),
                              style: TextStyle(
                                fontWeight: FontWeight.w500,
                                color: isDarkMode ? Colors.white : Colors.black87,
                              ),
                            ),
                            subtitle: Text(
                              email.isNotEmpty ? email : 'No email provided',
                              style: TextStyle(
                                fontSize: 13,
                                color: isDarkMode ? Colors.white70 : Colors.black54,
                              ),
                            ),
                            trailing: isWideScreen
                                ? Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      ElevatedButton.icon(
                                        icon: const Icon(Icons.person, size: 16),
                                        label: const Text('Profile'),
                                        style: ElevatedButton.styleFrom(
                                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                          backgroundColor: isDarkMode ? Colors.grey[700] : Colors.grey[300],
                                          foregroundColor: isDarkMode ? Colors.white : Colors.black87,
                                        ),
                                        onPressed: () => _showUserProfile(user),
                                      ),
                                      const SizedBox(width: 8),
                                      ElevatedButton.icon(
                                        icon: const Icon(Icons.chat, size: 16),
                                        label: const Text('Chat'),
                                        style: ElevatedButton.styleFrom(
                                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                          backgroundColor: isDarkMode ? const Color(0xFF5F85DB) : const Color(0xFF5F85DB),
                                          foregroundColor: Colors.white,
                                        ),
                                        onPressed: () => _startChat(userId),
                                      ),
                                    ],
                                  )
                                : PopupMenuButton<String>(
                                    icon: const Icon(Icons.more_vert),
                                    onSelected: (value) {
                                      if (value == 'chat') {
                                        _startChat(userId);
                                      } else if (value == 'profile') {
                                        _showUserProfile(user);
                                      }
                                    },
                                    itemBuilder: (context) => [
                                      const PopupMenuItem(
                                        value: 'profile',
                                        child: Row(
                                          children: [
                                            Icon(Icons.person, color: Colors.grey),
                                            SizedBox(width: 8),
                                            Text('View Profile'),
                                          ],
                                        ),
                                      ),
                                      const PopupMenuItem(
                                        value: 'chat',
                                        child: Row(
                                          children: [
                                            Icon(Icons.chat, color: Colors.blue),
                                            SizedBox(width: 8),
                                            Text('Start Chat'),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}