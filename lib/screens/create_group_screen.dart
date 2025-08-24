// =============================================================================
// CREATE GROUP SCREEN
// =============================================================================
// This screen allows users to create new chat groups and select members.
// It includes group creation, member selection, and responsive design
// for different screen sizes.
//
// KEY FEATURES:
// - Group name input and validation
// - Member selection from user list
// - Responsive design with adaptive layouts
// - Real-time user search and filtering
// - Group creation with encryption
//
// ARCHITECTURE:
// - Uses StreamBuilder for real-time user list updates
// - Implements responsive design with MediaQuery
// - Provides group creation with member management
// - Supports user blocking and reporting
//
// PLATFORM SUPPORT:
// - Web: Full functionality with responsive design
// - Mobile: Touch-optimized interface
// - Cross-platform: Unified group creation experience

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:encrypt/encrypt.dart' as encrypt_lib;

import '../services/theme_service.dart';
import '../services/logger_service.dart'; // Added import for logging
import 'chat_screen.dart';

class CreateGroupScreen extends StatefulWidget {
  const CreateGroupScreen({Key? key}) : super(key: key);

  @override
  State<CreateGroupScreen> createState() => _CreateGroupScreenState();
}

class _CreateGroupScreenState extends State<CreateGroupScreen> {
  final TextEditingController _groupNameController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();
  List<String> _selectedUserIds = [];
  bool _isLoading = false;
  String? _error;
  List<QueryDocumentSnapshot>? _allUsers;
  List<QueryDocumentSnapshot>? _filteredUsers;
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
    _searchController.addListener(_filterUsers);
  }

  Future<void> _fetchAllUsers() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;
    final usersSnap = await FirebaseFirestore.instance.collection('users').get();
    setState(() {
      _allUsers = usersSnap.docs.where((doc) => doc.id != currentUser.uid).toList();
      _filteredUsers = _allUsers;
    });
  }

  void _filterUsers() {
    final query = _searchController.text.trim().toLowerCase();
    if (_allUsers == null) return;
    if (query.isEmpty) {
      setState(() {
        _filteredUsers = _allUsers;
      });
    } else {
      setState(() {
        _filteredUsers = _allUsers!.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          final username = (data['username'] ?? '').toString().toLowerCase();
          final email = (data['email'] ?? '').toString().toLowerCase();
          return username.contains(query) || email.contains(query);
        }).toList();
      });
    }
  }

  Future<void> _createGroup() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null || _groupNameController.text.trim().isEmpty || _selectedUserIds.isEmpty) {
      setState(() {
        _error = 'Please enter a group name and select members.';
      });
      return;
    }
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final members = [currentUser.uid, ..._selectedUserIds];
      final chatDoc = await FirebaseFirestore.instance.collection('chats').add({
        'isGroup': true,
        'groupName': _groupNameController.text.trim(),
        'members': members,
        'adminId': currentUser.uid,
        'createdAt': FieldValue.serverTimestamp(),
        'lastMessage': '',
        'lastMessageTime': FieldValue.serverTimestamp(),
      });
      final chatId = chatDoc.id;
      // Generate a 32-byte AES key
      final key = encrypt_lib.Key.fromSecureRandom(32);
      final iv = encrypt_lib.IV.fromLength(16);
      
      // Use a proper 32-byte key for AES-256
      final staticAppKey = encrypt_lib.Key.fromSecureRandom(32);
      final staticEncrypter = encrypt_lib.Encrypter(encrypt_lib.AES(staticAppKey));
      final encryptedKey = staticEncrypter.encryptBytes(key.bytes, iv: iv).base64;
      
      // Store for all members
      for (final uid in members) {
        await FirebaseFirestore.instance
            .collection('chats')
            .doc(chatId)
            .collection('keys')
            .doc(uid)
            .set({'encryptedKey': encryptedKey});
      }
      // Double-check all members have a key
      await _ensureAllMembersHaveKey(chatId, members);
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => ChatScreen(
            chatId: chatId,
            isGroupChat: true,
            chatName: _groupNameController.text.trim(),
          )),
        );
      }
    } catch (e) {
      setState(() {
        _error = 'Failed to create group: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _ensureAllMembersHaveKey(String chatId, List<String> members) async {
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
          Log.i('Healed missing key for $uid', 'CREATE_GROUP');
        }
      }
    }
  }

  // Migration function to fix existing group chats with missing keys
  Future<void> migrateFixMissingGroupKeys() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;
    final chatsSnap = await FirebaseFirestore.instance.collection('chats')
      .where('isGroup', isEqualTo: true)
      .where('members', arrayContains: currentUser.uid)
      .get();
    for (final chatDoc in chatsSnap.docs) {
      final members = List<String>.from(chatDoc['members'] ?? []);
      await _ensureAllMembersHaveKey(chatDoc.id, members);
    }
          Log.i('Migration complete: missing group keys fixed', 'CREATE_GROUP');
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
        _filteredUsers = _filteredUsers?.where((doc) => doc.id != userId).toList();
        _allUsers = _allUsers?.where((doc) => doc.id != userId).toList();
        _selectedUserIds.remove(userId);
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
        title: const Text('Create Group'),
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
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Group Name', style: TextStyle(fontWeight: FontWeight.bold)),
            TextField(
              controller: _groupNameController,
              decoration: const InputDecoration(
                hintText: 'Enter group name',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            const Text('Select Members', style: TextStyle(fontWeight: FontWeight.bold)),
            TextField(
              controller: _searchController,
              decoration: const InputDecoration(
                hintText: 'Search users by username or email',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: _filteredUsers == null
                  ? const Center(child: CircularProgressIndicator())
                  : _filteredUsers!.isEmpty
                      ? const Center(child: Text('No users found.'))
                      : FutureBuilder<QuerySnapshot>(
                          future: FirebaseFirestore.instance
                              .collection('users')
                              .doc(currentUser!.uid)
                              .collection('blocked')
                              .get(),
                          builder: (context, blockedSnapshot) {
                            final blockedIds = blockedSnapshot.hasData
                                ? blockedSnapshot.data!.docs.map((d) => d.id).toSet()
                                : <String>{};
                            final visibleUsers = _filteredUsers!.where((doc) => !blockedIds.contains(doc.id)).toList();
                            return ListView.builder(
                              itemCount: visibleUsers.length,
                              itemBuilder: (context, index) {
                                final doc = visibleUsers[index];
                                final data = doc.data() as Map<String, dynamic>;
                                final userId = doc.id;
                                final currentUser = FirebaseAuth.instance.currentUser;
                                final isFriend = data['friends'] != null && (data['friends'] as List).contains(currentUser?.uid);
                                
                                return Card(
                                  margin: const EdgeInsets.symmetric(vertical: 4),
                                  child: ListTile(
                                    leading: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Checkbox(
                                          value: _selectedUserIds.contains(userId),
                                          onChanged: (selected) {
                                            setState(() {
                                              if (selected == true) {
                                                _selectedUserIds.add(userId);
                                              } else {
                                                _selectedUserIds.remove(userId);
                                              }
                                            });
                                          },
                                        ),
                                        CircleAvatar(
                                          backgroundImage: (data['photoUrl'] ?? '').isNotEmpty
                                              ? NetworkImage(data['photoUrl'])
                                              : null,
                                          child: (data['photoUrl'] ?? '').isEmpty
                                              ? const Icon(Icons.person)
                                              : null,
                                        ),
                                      ],
                                    ),
                                    title: Text(
                                      data['username'] ?? '',
                                      style: const TextStyle(fontWeight: FontWeight.w500),
                                    ),
                                    subtitle: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(data['email'] ?? ''),
                                        if (isFriend)
                                          const Text(
                                            'Friend',
                                            style: TextStyle(
                                              color: Colors.green,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                      ],
                                    ),
                                    trailing: isWideScreen
                                        ? Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              IconButton(
                                                icon: const Icon(Icons.block),
                                                tooltip: 'Block',
                                                onPressed: () => _blockUser(userId, data),
                                              ),
                                              IconButton(
                                                icon: const Icon(Icons.report),
                                                tooltip: 'Report',
                                                onPressed: () => _reportUser(userId, data),
                                              ),
                                            ],
                                          )
                                        : PopupMenuButton<String>(
                                            icon: const Icon(Icons.more_vert),
                                            onSelected: (value) {
                                              switch (value) {
                                                case 'block':
                                                  _blockUser(userId, data);
                                                  break;
                                                case 'report':
                                                  _reportUser(userId, data);
                                                  break;
                                              }
                                            },
                                            itemBuilder: (context) => [
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
            if (_error != null)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  border: Border.all(color: Colors.red.shade300),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _error!,
                  style: TextStyle(color: Colors.red.shade700),
                  textAlign: TextAlign.center,
                ),
              ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _createGroup,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: _isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text('Create Group'),
              ),
            ),
          ],
        ),
      ),
    );
  }
} 