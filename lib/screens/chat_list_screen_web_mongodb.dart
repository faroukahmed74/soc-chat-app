// =============================================================================
// CHAT LIST SCREEN WEB - MONGODB VERSION
// =============================================================================
// Web-optimized version of the chat list screen using MongoDB
// Responsive design and enhanced navigation for web browsers

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'dart:async';
import '../services/theme_service.dart';
import '../services/mongodb_chat_service.dart';
import '../services/physical_auth_service.dart';
import '../services/logger_service.dart';
import '../services/version_check_service.dart';
import '../utils/group_chat_naming_utility.dart';
import 'chat_screen_mongodb.dart';

class ChatListScreenWebMongoDB extends StatefulWidget {
  const ChatListScreenWebMongoDB({Key? key}) : super(key: key);

  @override
  State<ChatListScreenWebMongoDB> createState() =>
      _ChatListScreenWebMongoDBState();
}

class _ChatListScreenWebMongoDBState extends State<ChatListScreenWebMongoDB> {
  final MongoDBChatService _chatService = MongoDBChatService();
  final PhysicalAuthService _authService = PhysicalAuthService();
  final TextEditingController _searchController = TextEditingController();

  List<Map<String, dynamic>> _chats = [];
  List<Map<String, dynamic>> _filteredChats = [];
  bool _isLoading = true;
  String _searchQuery = '';
  String? _currentUserId;
  String? _currentUserName;
  StreamSubscription? _chatsSubscription;
  late ThemeService _themeService;
  final Map<String, String> _userNameCache = {};
  final Set<String> _userNameFetching = {};

  // Timestamp parsing utilities (same as main chat list screen)
  DateTime? _parseChatTimestamp(dynamic value) {
    if (value == null) return null;

    if (value is DateTime) {
      return value;
    }

    if (value is String) {
      final trimmed = value.trim();
      if (trimmed.isEmpty ||
          trimmed.toLowerCase() == 'null' ||
          trimmed == '0') {
        return null;
      }
      final parsed = DateTime.tryParse(trimmed);
      if (parsed != null) {
        return parsed;
      }
      final numeric = int.tryParse(trimmed);
      if (numeric != null) {
        return _dateTimeFromEpoch(numeric);
      }
      return null;
    }

    if (value is int) {
      return _dateTimeFromEpoch(value);
    }

    if (value is double) {
      return _dateTimeFromEpoch(value.toInt());
    }

    if (value is BigInt) {
      return _dateTimeFromEpoch(value.toInt());
    }

    if (value is Map) {
      final map = value as Map<dynamic, dynamic>;

      if (map.containsKey(r'$date')) {
        return _parseChatTimestamp(map[r'$date']);
      }
      if (map.containsKey('date')) {
        return _parseChatTimestamp(map['date']);
      }
      if (map.containsKey('iso')) {
        return _parseChatTimestamp(map['iso']);
      }
      if (map.containsKey('timestamp')) {
        final parsedTimestamp = _parseChatTimestamp(map['timestamp']);
        if (parsedTimestamp != null) return parsedTimestamp;
      }

      final seconds = _toInt(
        map['seconds'] ?? map['_seconds'] ?? map['epochSeconds'],
      );
      final nanos = _toInt(
        map['nanoseconds'] ?? map['_nanoseconds'] ?? map['nanos'],
      );
      if (seconds != null) {
        return _dateTimeFromEpoch(
          seconds,
          nanoseconds: nanos,
          inputIsSeconds: true,
        );
      }

      final millis = _toInt(
        map['millisecondsSinceEpoch'] ??
            map['epochMillis'] ??
            map['epochMs'] ??
            map['milliseconds'] ??
            map['time'],
      );
      if (millis != null) {
        return _dateTimeFromEpoch(millis, nanoseconds: nanos);
      }

      final numberLong = _toInt(map[r'$numberLong']);
      if (numberLong != null) {
        return _dateTimeFromEpoch(numberLong, nanoseconds: nanos);
      }

      if (map.containsKey('value')) {
        return _parseChatTimestamp(map['value']);
      }
    }

    try {
      final dynamic dynamicValue = value;
      final result = dynamicValue.toDate();
      if (result is DateTime) {
        return result;
      }
    } catch (_) {
      // Ignore - value didn't have toDate()
    }

    return null;
  }

  int? _toInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is BigInt) return value.toInt();
    if (value is String) return int.tryParse(value);
    if (value is Map && value.containsKey(r'$numberLong')) {
      return int.tryParse(value[r'$numberLong']?.toString() ?? '');
    }
    return null;
  }

  DateTime? _dateTimeFromEpoch(
    int epoch, {
    int? nanoseconds,
    bool inputIsSeconds = false,
  }) {
    if (epoch == 0) return null;

    int milliseconds;
    if (inputIsSeconds) {
      milliseconds = epoch * 1000;
    } else if (epoch.abs() > 1000000000000) {
      milliseconds = epoch;
    } else if (epoch.abs() > 1000000000) {
      milliseconds = epoch * 1000;
    } else if (epoch.abs() > 1000000) {
      milliseconds = epoch ~/ 1000;
    } else {
      milliseconds = epoch;
    }

    if (nanoseconds != null && nanoseconds > 0) {
      milliseconds += nanoseconds ~/ 1000000;
    }

    try {
      return DateTime.fromMillisecondsSinceEpoch(milliseconds, isUtc: true);
    } catch (_) {
      return null;
    }
  }

  DateTime? _getLastMessageTime(Map<String, dynamic> chat) {
    // Priority 1: Try lastMessageTime field directly (most reliable)
    final direct = _parseChatTimestamp(chat['lastMessageTime']);
    if (direct != null) {
      return direct;
    }

    // Priority 2: Extract from lastMessage object
    final lastMsgObj = chat['lastMessage'];
    if (lastMsgObj is Map<String, dynamic>) {
      // Try multiple timestamp fields in lastMessage
      final fromMap = _parseChatTimestamp(
        lastMsgObj['timestamp'] ??
            lastMsgObj['createdAt'] ??
            lastMsgObj['time'] ??
            lastMsgObj['date'],
      );
      if (fromMap != null) {
        return fromMap;
      }
    } else if (lastMsgObj != null) {
      // If lastMessage is not a map, try parsing it directly
      final parsed = _parseChatTimestamp(lastMsgObj);
      if (parsed != null) {
        return parsed;
      }
    }

    // Priority 3: Fallback to updatedAt (chat was updated when message was sent)
    final updated = _parseChatTimestamp(chat['updatedAt']);
    if (updated != null) {
      return updated;
    }

    // Priority 4: Fallback to createdAt (chat creation time)
    final created = _parseChatTimestamp(chat['createdAt']);
    if (created != null) {
      return created;
    }

    // No timestamp found
    return null;
  }

  DateTime? _getFallbackTime(Map<String, dynamic> chat) {
    return _parseChatTimestamp(chat['updatedAt']) ??
        _parseChatTimestamp(chat['createdAt']);
  }

  List<Map<String, dynamic>> _sortChatsByNewestMessage(
    List<Map<String, dynamic>> chats,
  ) {
    // Sort chats by lastMessageTime descending (newest first)
    // This applies to BOTH individual and group chats
    final sorted = List<Map<String, dynamic>>.from(chats);
    sorted.sort((a, b) {
      DateTime? timeA = _getLastMessageTime(a);
      DateTime? timeB = _getLastMessageTime(b);

      // Chats with messages come first
      if (timeA == null && timeB == null) {
        // Both have no messages - sort by updatedAt or createdAt as fallback
        final updatedA = _getFallbackTime(a);
        final updatedB = _getFallbackTime(b);
        if (updatedA == null && updatedB == null) return 0;
        if (updatedA == null) return 1;
        if (updatedB == null) return -1;
        return updatedB.compareTo(updatedA);
      }
      if (timeA == null) return 1; // No message goes to end
      if (timeB == null) return -1; // Has message goes to front

      // Sort by newest first (descending) - this works for both sent and received messages
      final comparison = timeB.compareTo(timeA);

      // If times are equal, use fallback time for secondary sort
      if (comparison == 0) {
        final updatedA = _getFallbackTime(a);
        final updatedB = _getFallbackTime(b);
        if (updatedA == null && updatedB == null) return 0;
        if (updatedA == null) return 1;
        if (updatedB == null) return -1;
        return updatedB.compareTo(updatedA);
      }
      return comparison;
    });

    return sorted;
  }

  @override
  void initState() {
    super.initState();
    _themeService = ThemeService.instance;
    _themeService.addListener(() {
      if (mounted) setState(() {});
    });
    _initializeChatList();
    _searchController.addListener(_onSearchChanged);
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
      Log.e('Error initializing chat list', 'CHAT_LIST_WEB_MONGODB', e);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error loading chats: $e')));
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _loadChats() async {
    try {
      final chats = await _chatService.getUserChats();
      if (mounted) {
        // Sort chats by newest message first
        final sortedChats = _sortChatsByNewestMessage(chats);
        setState(() {
          _chats = sortedChats;
          _filteredChats = sortedChats;
        });
      }
    } catch (e) {
      Log.e('Error loading chats', 'CHAT_LIST_WEB_MONGODB', e);
    }
  }

  void _startChatListener() {
    _chatsSubscription = _chatService.watchUserChats().listen(
      (chats) {
        if (mounted) {
          // Sort chats by newest message first
          final sortedChats = _sortChatsByNewestMessage(chats);
          setState(() {
            _chats = sortedChats;
            _filteredChats = sortedChats;
          });
        }
      },
      onError: (error) {
        Log.e('Error in chat stream', 'CHAT_LIST_WEB_MONGODB', error);
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
        final filtered = _chats.where((chat) {
          final name = (chat['name'] ?? '').toString().toLowerCase();
          final lastMessage = (chat['lastMessage'] ?? '')
              .toString()
              .toLowerCase();
          return name.contains(query) || lastMessage.contains(query);
        }).toList();
        // Maintain sort order for filtered results
        _filteredChats = _sortChatsByNewestMessage(filtered);
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
    return GroupChatNamingUtility.getChatDisplayName(
      chat,
      currentUserId: _currentUserId,
    );
  }

  Future<void> _ensureUserNameCached(String userId) async {
    if (_userNameCache.containsKey(userId) ||
        _userNameFetching.contains(userId))
      return;
    _userNameFetching.add(userId);
    try {
      final user = await _chatService.getUserDetails(userId);
      final displayName =
          (user?['name'] ?? user?['displayName'] ?? user?['email'] ?? userId)
              .toString();
      _userNameCache[userId] = displayName;
      if (mounted) setState(() {});
    } finally {
      _userNameFetching.remove(userId);
    }
  }

  String _buildLastMessagePreview(
    Map<String, dynamic> chat, {
    required bool isGroup,
  }) {
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
    final String name = _getChatTitle(chat);
    final bool isGroup = chat['type'] == 'group';
    final String lastMessage = _buildLastMessagePreview(chat, isGroup: isGroup);
    final DateTime? lastMessageTime = _getLastMessageTime(chat);

    // Get unread count for current user (supports both old format and new per-user format)
    int unreadCount = 0;
    final unreadCountObj = chat['unreadCount'];
    if (unreadCountObj is Map<String, dynamic>) {
      // New format: unreadCount.USER_ID
      // Try both string and ObjectId format
      final userIdStr = _currentUserId?.toString() ?? '';
      unreadCount =
          (unreadCountObj[userIdStr] ?? unreadCountObj[_currentUserId] ?? 0)
              as int;
      // Also try as int (if server stored it as number)
      if (unreadCount == 0 && unreadCountObj[_currentUserId] is num) {
        unreadCount = (unreadCountObj[_currentUserId] as num).toInt();
      }
    } else if (unreadCountObj is int || unreadCountObj is num) {
      // Old format: just a number
      unreadCount = unreadCountObj is int
          ? unreadCountObj
          : unreadCountObj.toInt();
    }

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: _themeService.isDarkMode
              ? Colors.blue[700]
              : Colors.blue[500],
          child: Text(
            name.isNotEmpty ? name[0].toUpperCase() : 'C',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                name,
                style: const TextStyle(fontWeight: FontWeight.w500),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (isGroup)
              Icon(
                Icons.group,
                size: 16,
                color: _themeService.isDarkMode
                    ? Colors.white54
                    : Colors.black54,
              ),
          ],
        ),
        subtitle: Text(
          lastMessage,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: _themeService.isDarkMode ? Colors.white70 : Colors.black87,
          ),
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              _formatTimestamp(lastMessageTime),
              style: TextStyle(
                fontSize: 12,
                color: _themeService.isDarkMode
                    ? Colors.white54
                    : Colors.black54,
              ),
            ),
            if (unreadCount > 0)
              Container(
                margin: const EdgeInsets.only(top: 4),
                padding: const EdgeInsets.symmetric(
                  horizontal: unreadCount > 99 ? 4 : 6,
                  vertical: 2,
                ),
                decoration: BoxDecoration(
                  color: Colors.red,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  unreadCount > 99 ? '99+' : unreadCount.toString(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
          ],
        ),
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
      Log.e('Error during logout', 'CHAT_LIST_WEB_MONGODB', e);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('SOC Chat App - Web'),
        backgroundColor: _themeService.isDarkMode
            ? Colors.grey[900]
            : Colors.blue,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: Icon(
              _themeService.isDarkMode ? Icons.light_mode : Icons.dark_mode,
            ),
            onPressed: () {
              _themeService.toggleTheme();
            },
            tooltip: _themeService.isDarkMode
                ? 'Switch to Light Mode'
                : 'Switch to Dark Mode',
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
              const PopupMenuItem(
                value: 'search',
                child: Row(
                  children: [
                    Icon(Icons.person_add, color: Colors.blue),
                    SizedBox(width: 8),
                    Text('Search Users'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'create_group',
                child: Row(
                  children: [
                    Icon(Icons.group_add, color: Colors.green),
                    SizedBox(width: 8),
                    Text('Create Group'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'logout',
                child: Row(
                  children: [
                    Icon(Icons.logout, color: Colors.red),
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
            DrawerHeader(
              decoration: BoxDecoration(
                color: _themeService.isDarkMode
                    ? Colors.blue[700]
                    : Colors.blue[500],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    radius: 30,
                    backgroundColor: Colors.white,
                    child: Text(
                      _currentUserName?.isNotEmpty == true
                          ? _currentUserName![0].toUpperCase()
                          : 'U',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: _themeService.isDarkMode
                            ? Colors.blue[700]
                            : Colors.blue[500],
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _currentUserName ?? 'User',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'MongoDB Mode',
                    style: TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                ],
              ),
            ),
            ListTile(
              leading: const Icon(Icons.person_add),
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
            ListTile(
              leading: const Icon(Icons.person),
              title: const Text('Profile'),
              onTap: () {
                Navigator.pop(context);
                Navigator.pushNamed(context, '/profile');
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
              leading: const Icon(Icons.logout),
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
                        style: TextStyle(
                          fontSize: 11,
                          color: _themeService.isDarkMode
                              ? Colors.grey[500]
                              : Colors.grey[600],
                          fontWeight: FontWeight.w300,
                        ),
                        textAlign: TextAlign.center,
                      );
                    },
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Developed by نقيب // احمد فاروق',
                    style: TextStyle(
                      fontSize: 10,
                      color: _themeService.isDarkMode
                          ? Colors.grey[600]
                          : Colors.grey[700],
                      fontWeight: FontWeight.w300,
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
                  borderRadius: BorderRadius.circular(10),
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
                          color: _themeService.isDarkMode
                              ? Colors.white54
                              : Colors.black54,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _searchQuery.isNotEmpty
                              ? 'No chats found matching "$_searchQuery"'
                              : 'No chats yet. Start a conversation!',
                          style: TextStyle(
                            color: _themeService.isDarkMode
                                ? Colors.white54
                                : Colors.black54,
                          ),
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
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          FloatingActionButton(
            heroTag: 'fab_profile',
            onPressed: () {
              Navigator.pushNamed(context, '/profile');
            },
            backgroundColor: _themeService.isDarkMode
                ? Colors.blue[900]
                : Colors.blue[800],
            foregroundColor: Colors.white,
            child: const Icon(Icons.person),
            tooltip: 'My Profile',
          ),
          const SizedBox(height: 12),
          FloatingActionButton(
            heroTag: 'fab_search',
            onPressed: () {
              Navigator.pushNamed(context, '/search');
            },
            backgroundColor: _themeService.isDarkMode
                ? Colors.blue[700]
                : Colors.blue[500],
            foregroundColor: Colors.white,
            child: const Icon(Icons.person_add),
            tooltip: 'Search Users',
          ),
        ],
      ),
    );
  }
}
