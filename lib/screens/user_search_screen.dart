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
// - User blocking and reporting
// - Responsive design with adaptive layouts
//
// ARCHITECTURE:
// - Uses StreamBuilder for real-time search results
// - Implements responsive design with MediaQuery
// - Provides user interaction capabilities
// - Supports user management actions
//
// PLATFORM SUPPORT:
// - Web: Full functionality with responsive design
// - Mobile: Touch-optimized interface
// - Cross-platform: Unified search experience

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'chat_screen.dart';



import '../services/theme_service.dart';
import '../services/logger_service.dart'; // Added import for logging

class UserSearchScreen extends StatefulWidget {
  const UserSearchScreen({Key? key}) : super(key: key);

  @override
  State<UserSearchScreen> createState() => _UserSearchScreenState();
}

class _UserSearchScreenState extends State<UserSearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  List<QueryDocumentSnapshot>? _allUsers;
  String _searchQuery = '';
  bool _isLoading = false;
  late ThemeService _themeService;

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
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;
    final usersSnap = await FirebaseFirestore.instance.collection('users').get();
    setState(() {
      _allUsers = usersSnap.docs.where((doc) => doc.id != currentUser.uid).toList();
      _isLoading = false;
    });
  }

  List<QueryDocumentSnapshot> _getVisibleUsers(Set<String> blockedIds) {
    if (_allUsers == null) return [];
    final visible = _allUsers!.where((doc) => !blockedIds.contains(doc.id)).toList();
    if (_searchQuery.isEmpty) return visible;
    final matches = <QueryDocumentSnapshot>[];
    final rest = <QueryDocumentSnapshot>[];
    for (final doc in visible) {
      final data = doc.data() as Map<String, dynamic>;
      final username = (data['username'] ?? '').toString().toLowerCase();
      final email = (data['email'] ?? '').toString().toLowerCase();
      if (username.contains(_searchQuery) || email.contains(_searchQuery)) {
        matches.add(doc);
      } else {
        rest.add(doc);
      }
    }
    return [...matches, ...rest];
  }

  Future<void> _startChat(String otherUserId) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;
    
    // Get user data for the other user
    final userDoc = await FirebaseFirestore.instance.collection('users').doc(otherUserId).get();
    final userData = userDoc.data() ?? {};
    
    final members = [currentUser.uid, otherUserId]..sort();
          Log.i('Attempting to start chat between: ${members.join(", ")}', 'USER_SEARCH');
    final chatQuery = await FirebaseFirestore.instance
        .collection('chats')
        .where('isGroup', isEqualTo: false)
        .where('members', isEqualTo: members)
        .get();
    String chatId;
    if (chatQuery.docs.isNotEmpty) {
      chatId = chatQuery.docs.first.id;
              Log.i('Existing chat found: $chatId', 'USER_SEARCH');
      // No key logic needed
    } else {
      final chatDoc = await FirebaseFirestore.instance.collection('chats').add({
        'isGroup': false,
        'members': members,
        'createdAt': FieldValue.serverTimestamp(),
        'otherUserName': userData['username'] ?? userData['email'] ?? 'Unknown User',
        'otherUserId': otherUserId,
      });
      chatId = chatDoc.id;
              Log.i('New chat created: $chatId', 'USER_SEARCH');
      // No key logic needed
    }
    await Future.delayed(Duration(milliseconds: 300));
    if (mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => ChatScreen(
          chatId: chatId,
          isGroupChat: false,
          chatName: userData['username'] ?? userData['email'] ?? 'Unknown User',
        )),
      );
    }
  }

  Future<void> _ensureBothUsersHaveKey(String chatId, List<String> members) async {
    final keysCol = FirebaseFirestore.instance.collection('chats').doc(chatId).collection('keys');
    String? foundKey;
    for (final uid in members) {
      final doc = await keysCol.doc(uid).get();
      if (doc.exists && doc.data()?['encryptedKey'] != null) {
        foundKey = doc.data()!['encryptedKey'];
        break;
      }
    }
    if (foundKey != null) {
      for (final uid in members) {
        final doc = await keysCol.doc(uid).get();
        if (!doc.exists || doc.data()?['encryptedKey'] == null) {
          await keysCol.doc(uid).set({'encryptedKey': foundKey});
          Log.i('Healed missing key for $uid', 'USER_SEARCH');
        }
      }
    }
  }

  // Migration function to fix existing chats with missing keys
  Future<void> migrateFixMissingKeys() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;
    final chatsSnap = await FirebaseFirestore.instance.collection('chats')
      .where('isGroup', isEqualTo: false)
      .where('members', arrayContains: currentUser.uid)
      .get();
    for (final chatDoc in chatsSnap.docs) {
      final members = List<String>.from(chatDoc['members'] ?? []);
      await _ensureBothUsersHaveKey(chatDoc.id, members);
    }
          Log.i('Migration complete: missing keys fixed', 'USER_SEARCH');
  }
  
  // Migration function to fix existing chats with missing user names
  Future<void> migrateFixMissingUserNames() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;
    
          Log.i('Starting migration to fix missing user names', 'USER_SEARCH');
    
    final chatsSnap = await FirebaseFirestore.instance.collection('chats')
      .where('isGroup', isEqualTo: false)
      .where('members', arrayContains: currentUser.uid)
      .get();
    
    int updatedCount = 0;
    for (final chatDoc in chatsSnap.docs) {
      final data = chatDoc.data();
      final members = List<String>.from(data['members'] ?? []);
      
      // Skip if already has otherUserName
      if (data['otherUserName'] != null) continue;
      
      // Get the other user's ID
      final otherUserId = members.firstWhere((id) => id != currentUser.uid);
      
      try {
        // Fetch the other user's data
        final userDoc = await FirebaseFirestore.instance.collection('users').doc(otherUserId).get();
        if (userDoc.exists) {
          final userData = userDoc.data()!;
          final otherUserName = userData['username'] ?? userData['email'] ?? 'Unknown User';
          
          // Update the chat document
          await FirebaseFirestore.instance.collection('chats').doc(chatDoc.id).update({
            'otherUserName': otherUserName,
            'otherUserId': otherUserId,
          });
          
          updatedCount++;
          Log.i('Updated chat ${chatDoc.id} with user name: $otherUserName', 'USER_SEARCH');
        }
      } catch (e) {
                  Log.e('Error updating chat ${chatDoc.id}', 'USER_SEARCH', e);
      }
    }
    
          Log.i('Migration complete: updated $updatedCount chats with user names', 'USER_SEARCH');
  }

  Future<void> _blockUser(String userId, Map<String, dynamic> userData) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;
    
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    String? reason;
    
    await showDialog(
      context: context,
      builder: (context) {
        final reasonController = TextEditingController();
        return AlertDialog(
          title: Text('Block ${userData['username'] ?? ''}?'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('You will not see messages or invites from this user.'),
              TextField(
                controller: reasonController,
                decoration: const InputDecoration(hintText: 'Reason (optional)'),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            TextButton(
              onPressed: () {
                reason = reasonController.text.trim();
                Navigator.pop(context);
              },
              child: const Text('Block'),
            ),
          ],
        );
      },
    );
    if (reason != null) {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.uid)
          .collection('blocked')
          .doc(userId)
          .set({
        'username': userData['username'],
        'email': userData['email'],
        'timestamp': FieldValue.serverTimestamp(),
        'reason': reason,
      });
      setState(() {
        _allUsers = _allUsers?.where((doc) => doc.id != userId).toList();
      });
      scaffoldMessenger.showSnackBar(
        SnackBar(content: Text('User blocked.')),
      );
    }
  }

  Future<void> _reportUser(String userId, Map<String, dynamic> userData) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;
    
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    String? reason;
    String? details;
    
    await showDialog(
      context: context,
      builder: (context) {
        final reasonController = TextEditingController();
        final detailsController = TextEditingController();
        return AlertDialog(
          title: Text('Report ${userData['username'] ?? ''}?'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: reasonController,
                decoration: const InputDecoration(hintText: 'Reason (required)'),
              ),
              TextField(
                controller: detailsController,
                decoration: const InputDecoration(hintText: 'Details (optional)'),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            TextButton(
              onPressed: () {
                reason = reasonController.text.trim();
                details = detailsController.text.trim();
                Navigator.pop(context);
              },
              child: const Text('Report'),
            ),
          ],
        );
      },
    );
    if (reason != null && reason!.isNotEmpty) {
      await FirebaseFirestore.instance.collection('reports').add({
        'reporterId': currentUser.uid,
        'reportedUserId': userId,
        'reason': reason,
        'details': details,
        'timestamp': FieldValue.serverTimestamp(),
        'reportedUsername': userData['username'],
        'reportedEmail': userData['email'],
      });
      scaffoldMessenger.showSnackBar(
        SnackBar(content: Text('User reported.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;
    final screenWidth = MediaQuery.of(context).size.width;
    final isWideScreen = screenWidth > 600;
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('User Search'),
        actions: [
          // Theme Toggle Button
          IconButton(
            icon: Icon(
              _themeService.isDarkMode ? Icons.light_mode : Icons.dark_mode,
              color: Colors.white,
            ),
            onPressed: () {
              _themeService.toggleTheme();
            },
            tooltip: _themeService.isDarkMode ? 'Switch to Light Mode' : 'Switch to Dark Mode',
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
                decoration: const InputDecoration(
                  labelText: 'Search users by username or email',
                  prefixIcon: Icon(Icons.search),
                  border: OutlineInputBorder(),
                ),
              ),
            ),
            if (_isLoading)
              const Expanded(child: Center(child: CircularProgressIndicator())),
            if (!_isLoading && _allUsers != null)
              Expanded(
                child: FutureBuilder<QuerySnapshot>(
                  future: FirebaseFirestore.instance
                      .collection('users')
                      .doc(currentUser!.uid)
                      .collection('blocked')
                      .get(),
                  builder: (context, blockedSnapshot) {
                    final blockedIds = blockedSnapshot.hasData
                        ? blockedSnapshot.data!.docs.map((d) => d.id).toSet()
                        : <String>{};
                    final visibleUsers = _getVisibleUsers(blockedIds);
                    if (visibleUsers.isEmpty) {
                      return const Center(child: Text('No users found.'));
                    }
                    return ListView.builder(
                      itemCount: visibleUsers.length,
                      itemBuilder: (context, index) {
                        final doc = visibleUsers[index];
                        final userData = doc.data() as Map<String, dynamic>;
                        final userId = doc.id;
                        if (userId == currentUser.uid) {
                          return const SizedBox.shrink();
                        }
                        
                        return Card(
                          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundImage: (userData['photoUrl'] ?? '').isNotEmpty
                                  ? NetworkImage(userData['photoUrl'])
                                  : null,
                              child: (userData['photoUrl'] ?? '').isEmpty
                                  ? const Icon(Icons.person)
                                  : null,
                            ),
                            title: Text(
                              userData['username'] ?? '',
                              style: const TextStyle(fontWeight: FontWeight.w500),
                            ),
                            subtitle: Text(userData['email'] ?? ''),
                            trailing: isWideScreen
                                ? Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      ElevatedButton.icon(
                                        icon: const Icon(Icons.chat, size: 16),
                                        label: const Text('Chat'),
                                        style: ElevatedButton.styleFrom(
                                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                        ),
                                        onPressed: () => _startChat(userId),
                                      ),
                                      const SizedBox(width: 8),
                                      IconButton(
                                        icon: const Icon(Icons.block),
                                        tooltip: 'Block',
                                        onPressed: () => _blockUser(userId, userData),
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.report),
                                        tooltip: 'Report',
                                        onPressed: () => _reportUser(userId, userData),
                                      ),
                                    ],
                                  )
                                : PopupMenuButton<String>(
                                    icon: const Icon(Icons.more_vert),
                                    onSelected: (value) {
                                      switch (value) {
                                        case 'chat':
                                          _startChat(userId);
                                          break;
                                        case 'block':
                                          _blockUser(userId, userData);
                                          break;
                                        case 'report':
                                          _reportUser(userId, userData);
                                          break;
                                      }
                                    },
                                    itemBuilder: (context) => [
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
                                      const PopupMenuItem(
                                        value: 'block',
                                        child: Row(
                                          children: [
                                            Icon(Icons.block, color: Colors.orange),
                                            SizedBox(width: 8),
                                            Text('Block'),
                                          ],
                                        ),
                                      ),
                                      const PopupMenuItem(
                                        value: 'report',
                                        child: Row(
                                          children: [
                                            Icon(Icons.report, color: Colors.red),
                                            SizedBox(width: 8),
                                            Text('Report'),
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