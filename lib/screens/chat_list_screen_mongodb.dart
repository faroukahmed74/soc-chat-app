// =============================================================================
// CHAT LIST SCREEN - UNIFIED FOR ALL PLATFORMS
// =============================================================================
// This screen displays the list of chats using MongoDB
// It handles chat loading, search, and navigation
//
// PLATFORM SUPPORT:
// - Web: Responsive layout with wide-screen optimizations (local network routes)
// - Android/iOS: Mobile-optimized layout (ngrok API routes)
// - All platforms use the same screen with responsive design
//
// ROUTING:
// - Web: Uses local network routes (same-origin proxy)
// - Mobile: Uses ngrok API routes (handled by DatabaseConfig)

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'dart:async';
import 'dart:io';
import '../services/theme_service.dart';
import '../services/mongodb_chat_service.dart';
import '../services/physical_auth_service.dart';
import '../services/logger_service.dart';
import '../services/message_sound_service.dart';
import '../services/active_chat_service.dart';
import '../utils/group_chat_naming_utility.dart';
// Unified chat screen for all platforms (web, Android, iOS)
import 'chat_screen_mongodb.dart';
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
  
  // Track last message timestamps to detect new messages for sound
  final Map<String, DateTime> _lastMessageTimes = {};

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
        // Sort chats by newest message first
        final sortedChats = _sortChatsByNewestMessage(chats);
        setState(() {
          _chats = sortedChats;
          _filteredChats = sortedChats;
        });
      }
    } catch (e) {
      Log.e('Error loading chats', 'CHAT_LIST_MONGODB', e);
    }
  }

  void _startChatListener() {
    // Initialize last message times from current chats
    for (final chat in _chats) {
      final chatId = (chat['_id'] ?? chat['id'] ?? '').toString();
      if (chatId.isEmpty) continue;
      
      DateTime? messageTime;
      
      // Try lastMessageTime first
      final lastMessageTime = chat['lastMessageTime'];
      if (lastMessageTime != null) {
        if (lastMessageTime is DateTime) {
          messageTime = lastMessageTime;
        } else if (lastMessageTime is String) {
          messageTime = DateTime.tryParse(lastMessageTime);
        }
      }
      
      // Fallback to lastMessage.timestamp or lastMessage.createdAt
      if (messageTime == null) {
        final lastMessageObj = chat['lastMessage'];
        if (lastMessageObj is Map<String, dynamic>) {
          final msgTimestamp = lastMessageObj['timestamp'] ?? lastMessageObj['createdAt'];
          if (msgTimestamp != null) {
            if (msgTimestamp is DateTime) {
              messageTime = msgTimestamp;
            } else if (msgTimestamp is String) {
              messageTime = DateTime.tryParse(msgTimestamp);
            }
          }
        }
      }
      
      if (messageTime != null) {
        _lastMessageTimes[chatId] = messageTime;
      }
    }
    
    _chatsSubscription = _chatService.watchUserChats().listen(
      (chats) {
        if (mounted) {
          // Check for new messages and play sound
          _checkForNewMessages(chats);
          
          // Sort chats by newest message first
          final sortedChats = _sortChatsByNewestMessage(chats);
          
          setState(() {
            _chats = sortedChats;
            _filteredChats = sortedChats;
          });
        }
      },
      onError: (error) {
        Log.e('Error in chat stream', 'CHAT_LIST_MONGODB', error);
      },
    );
  }
  
  void _checkForNewMessages(List<Map<String, dynamic>> chats) {
    if (_currentUserId == null) return;
    
    for (final chat in chats) {
      final chatId = (chat['_id'] ?? chat['id'] ?? '').toString();
      if (chatId.isEmpty) continue;
      
      final lastMessageObj = chat['lastMessage'];
      final lastMessageTime = chat['lastMessageTime'];
      
      // Skip if this chat is currently active (sound already played in chat screen)
      if (ActiveChatService.instance.isActive(chatId)) {
        // Update timestamp but don't play sound
        if (lastMessageTime != null) {
          DateTime? messageTime;
          if (lastMessageTime is DateTime) {
            messageTime = lastMessageTime;
          } else if (lastMessageTime is String) {
            messageTime = DateTime.tryParse(lastMessageTime);
          }
          if (messageTime != null) {
            _lastMessageTimes[chatId] = messageTime;
          }
        }
        continue;
      }
      
      // Get sender ID from last message
      String? senderId;
      if (lastMessageObj is Map<String, dynamic>) {
        senderId = lastMessageObj['senderId']?.toString();
      }
      
      // Skip messages from current user
      if (senderId == null || senderId == _currentUserId) {
        continue;
      }
      
      // Check if this is a new message (timestamp changed)
      DateTime? currentMessageTime;
      
      // Try lastMessageTime first
      if (lastMessageTime != null) {
        if (lastMessageTime is DateTime) {
          currentMessageTime = lastMessageTime;
        } else if (lastMessageTime is String) {
          currentMessageTime = DateTime.tryParse(lastMessageTime);
        }
      }
      
      // Fallback to lastMessage.timestamp or lastMessage.createdAt
      if (currentMessageTime == null && lastMessageObj is Map<String, dynamic>) {
        final msgTimestamp = lastMessageObj['timestamp'] ?? lastMessageObj['createdAt'];
        if (msgTimestamp != null) {
          if (msgTimestamp is DateTime) {
            currentMessageTime = msgTimestamp;
          } else if (msgTimestamp is String) {
            currentMessageTime = DateTime.tryParse(msgTimestamp);
          }
        }
      }
      
      if (currentMessageTime != null) {
        final previousTime = _lastMessageTimes[chatId];
        
        // If timestamp is newer, it's a new message
        if (previousTime == null || currentMessageTime.isAfter(previousTime)) {
          // Play sound for new message
          Log.i('🔊 New message detected in chat list, playing sound...', 'CHAT_LIST_MONGODB');
          MessageSoundService().playMessageSound();
          
          // Update timestamp
          _lastMessageTimes[chatId] = currentMessageTime;
        }
      }
    }
  }

  List<Map<String, dynamic>> _sortChatsByNewestMessage(List<Map<String, dynamic>> chats) {
    // Sort chats by lastMessageTime descending (newest first)
    final sorted = List<Map<String, dynamic>>.from(chats);
    sorted.sort((a, b) {
      DateTime? timeA = _getLastMessageTime(a);
      DateTime? timeB = _getLastMessageTime(b);
      
      // Chats with messages come first
      if (timeA == null && timeB == null) return 0;
      if (timeA == null) return 1; // No message goes to end
      if (timeB == null) return -1; // Has message goes to front
      
      // Sort by newest first (descending)
      return timeB.compareTo(timeA);
    });
    return sorted;
  }

  DateTime? _getLastMessageTime(Map<String, dynamic> chat) {
    // Try lastMessageTime first
    final lastMessageTime = chat['lastMessageTime'];
    if (lastMessageTime != null) {
      if (lastMessageTime is DateTime) {
        return lastMessageTime;
      } else if (lastMessageTime is String) {
        return DateTime.tryParse(lastMessageTime);
      }
    }
    
    // Fallback to updatedAt
    final updatedAt = chat['updatedAt'];
    if (updatedAt != null) {
      if (updatedAt is DateTime) {
        return updatedAt;
      } else if (updatedAt is String) {
        return DateTime.tryParse(updatedAt);
      }
    }
    
    // Fallback to lastMessage.timestamp
    final lastMsgObj = chat['lastMessage'];
    if (lastMsgObj is Map<String, dynamic>) {
      final timestamp = lastMsgObj['timestamp'] ?? lastMsgObj['createdAt'];
      if (timestamp != null) {
        if (timestamp is DateTime) {
          return timestamp;
        } else if (timestamp is String) {
          return DateTime.tryParse(timestamp);
        }
      }
    }
    
    return null;
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
          final lastMessage = (chat['lastMessage'] ?? '').toString().toLowerCase();
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

    // Today - just show time
    if (difference.inDays == 0) {
      return '${cairo.hour.toString().padLeft(2, '0')}:${cairo.minute.toString().padLeft(2, '0')}';
    }
    // Yesterday
    else if (difference.inDays == 1) {
      return 'Yesterday ${cairo.hour.toString().padLeft(2, '0')}:${cairo.minute.toString().padLeft(2, '0')}';
    }
    // Within a week - show day name
    else if (difference.inDays < 7) {
      final dayNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
      return '${dayNames[cairo.weekday - 1]} ${cairo.hour.toString().padLeft(2, '0')}:${cairo.minute.toString().padLeft(2, '0')}';
    }
    // Older - show date and time
    else {
      return '${cairo.day}/${cairo.month}/${cairo.year.toString().substring(2)} ${cairo.hour.toString().padLeft(2, '0')}:${cairo.minute.toString().padLeft(2, '0')}';
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

  Widget _buildChatTile(Map<String, dynamic> chat, bool isWideScreen) {
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
    
    // Try multiple sources for timestamp
    String? lastMessageTimeStr = chat['lastMessageTime'] ?? 
        chat['updatedAt'] ?? 
        (lastMsgObj is Map<String, dynamic> ? (lastMsgObj['timestamp'] ?? lastMsgObj['createdAt']) : null);
    
    DateTime? lastMessageTime;
    if (lastMessageTimeStr is String && lastMessageTimeStr.isNotEmpty) {
      try {
        lastMessageTime = DateTime.parse(lastMessageTimeStr);
      } catch (_) {
        lastMessageTime = null;
      }
    }
    
    // Also handle DateTime objects directly
    if (lastMessageTime == null && chat['lastMessageTime'] is DateTime) {
      lastMessageTime = chat['lastMessageTime'];
    }
    if (lastMessageTime == null && chat['updatedAt'] is DateTime) {
      lastMessageTime = chat['updatedAt'];
    }
    
    // Get unread count for current user (supports both old format and new per-user format)
    int unreadCount = 0;
    bool unreadCountFieldExists = false;
    final unreadCountObj = chat['unreadCount'];
    
    if (unreadCountObj != null) {
      unreadCountFieldExists = true;
      if (unreadCountObj is Map<String, dynamic>) {
        // New format: unreadCount.USER_ID
        // Try multiple formats to ensure we find the value
        final userIdStr = _currentUserId?.toString() ?? '';
        dynamic countValue;
        
        // Try string format first
        if (userIdStr.isNotEmpty) {
          countValue = unreadCountObj[userIdStr];
        }
        
        // Try ObjectId format if string format didn't work
        if (countValue == null && _currentUserId != null) {
          countValue = unreadCountObj[_currentUserId];
        }
        
        // Try all keys to find a match (in case of format mismatch)
        if (countValue == null) {
          for (final key in unreadCountObj.keys) {
            if (key.toString() == userIdStr || key.toString() == _currentUserId?.toString()) {
              countValue = unreadCountObj[key];
              break;
            }
          }
        }
        
        if (countValue != null) {
          if (countValue is int) {
            unreadCount = countValue;
          } else if (countValue is num) {
            unreadCount = countValue.toInt();
          }
        } else {
          // Map exists but user's entry is missing - means 0 unread (was reset)
          unreadCount = 0;
        }
      } else if (unreadCountObj is int || unreadCountObj is num) {
        // Old format: just a number
        unreadCount = unreadCountObj is int ? unreadCountObj : unreadCountObj.toInt();
      }
    }
    
    // Determine if there are unread messages
    // Primary strategy: Use unreadCount if the field exists
    // If unreadCount field exists, trust it (0 = no unread, >0 = has unread)
    // Fallback: Only check last message if unreadCount field doesn't exist at all
    bool hasUnreadMessage = false;
    
    if (unreadCountFieldExists) {
      // If unreadCount field exists, use it as the primary indicator
      // unreadCount of 0 means no unread messages (chat was read)
      // unreadCount > 0 means there are unread messages
      // This will be false when user opens the chat and unreadCount is reset to 0
      hasUnreadMessage = unreadCount > 0;
    } else if (_currentUserId != null) {
      // Fallback: Only use this if unreadCount field doesn't exist at all
      // Check if last message is from someone else and not read
      final lastMsgObj = chat['lastMessage'];
      if (lastMsgObj is Map<String, dynamic>) {
        final senderId = lastMsgObj['senderId']?.toString();
        // Only consider unread if message is from someone else
        if (senderId != null && senderId != _currentUserId.toString()) {
          // Check if message was read by checking readBy array
          final readBy = lastMsgObj['readBy'] ?? [];
          final readByList = readBy is List 
              ? readBy.map((e) => e?.toString()).where((e) => e != null && e.isNotEmpty).cast<String>().toList() 
              : <String>[];
          final currentUserIdStr = _currentUserId.toString();
          // Message is unread if current user is not in readBy list
          hasUnreadMessage = !readByList.any((id) => id == currentUserIdStr);
        }
      }
    }

    // Responsive margins for web and mobile
    final horizontalMargin = isWideScreen ? 24.0 : 16.0;
    
    return Card(
      margin: EdgeInsets.symmetric(horizontal: horizontalMargin, vertical: 4),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppDesignSystem.radiusLG),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: Stack(
          clipBehavior: Clip.none,
          children: [
            CircleAvatar(
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
            // Unread indicator dot on avatar
            if (hasUnreadMessage)
              Positioned(
                right: -2,
                top: -2,
                child: Container(
                  width: 14,
                  height: 14,
                  decoration: BoxDecoration(
                    color: AppDesignSystem.errorColor,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Theme.of(context).scaffoldBackgroundColor,
                      width: 2,
                    ),
                  ),
                ),
              ),
            // Unread count badge beside the red dot
            if (hasUnreadMessage && unreadCount > 0)
              Positioned(
                right: 8, // Position to the right of the red dot
                top: -6,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                  decoration: BoxDecoration(
                    color: AppDesignSystem.errorColor,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: Theme.of(context).scaffoldBackgroundColor,
                      width: 1.5,
                    ),
                  ),
                  constraints: const BoxConstraints(
                    minWidth: 18,
                    minHeight: 18,
                  ),
                  child: Center(
                    child: Text(
                      unreadCount > 99 ? '99+' : unreadCount.toString(),
                      style: AppDesignSystem.labelSmall.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 10,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              ),
          ],
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                name,
                style: AppDesignSystem.titleMedium.copyWith(
                  fontWeight: hasUnreadMessage ? FontWeight.bold : FontWeight.w600,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            // Unread icon indicator
            if (hasUnreadMessage) ...[
              SizedBox(width: 4),
              Icon(
                Icons.circle,
                size: 8,
                color: AppDesignSystem.errorColor,
              ),
            ],
            if (isGroup) ...[
              SizedBox(width: 4),
              Icon(
                Icons.group,
                size: 16,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ],
          ],
        ),
        subtitle: Text(
          lastMessage.isNotEmpty ? lastMessage : 'No messages yet',
          overflow: TextOverflow.ellipsis,
          style: AppDesignSystem.bodyMedium.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
            fontWeight: hasUnreadMessage ? FontWeight.bold : FontWeight.normal,
          ),
          maxLines: 1,
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            if (lastMessageTime != null)
              Text(
                _formatTimestamp(lastMessageTime),
                style: AppDesignSystem.bodySmall.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant.withOpacity(0.7),
                  fontSize: 11,
                ),
              ),
            // Unread count is now shown beside the red dot on avatar, not here
          ],
        ),
        onTap: () async {
          // Navigate to chat screen and wait for return
          await Navigator.push(
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
          // Refresh chat list when returning from chat screen
          // The stream should handle this automatically, but this ensures immediate update
          // Add a longer delay to allow server to update unread count
          if (mounted) {
            await Future.delayed(const Duration(milliseconds: 500));
            await _loadChats();
            // Force a rebuild to ensure UI updates
            if (mounted) {
              setState(() {});
              // Additional rebuild after a short delay to catch any late updates
              Future.delayed(const Duration(milliseconds: 200), () {
                if (mounted) {
                  setState(() {});
                }
              });
            }
          }
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
    // Responsive layout for web and mobile
    final screenWidth = MediaQuery.of(context).size.width;
    final isWideScreen = kIsWeb && screenWidth > 800;
    
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
            padding: EdgeInsets.all(isWideScreen ? 24.0 : 16.0),
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
                        padding: EdgeInsets.symmetric(
                          horizontal: isWideScreen ? 8.0 : 0.0,
                          vertical: 8.0,
                        ),
                        itemCount: _filteredChats.length,
                        itemBuilder: (context, index) {
                          return _buildChatTile(_filteredChats[index], isWideScreen);
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
                    try {
                      final uri = Uri.parse(url);
                      // Try external application first (browser)
                      if (await canLaunchUrl(uri)) {
                        // On Android 13+, use platformDefault for better compatibility
                        final launchMode = Platform.isAndroid 
                            ? LaunchMode.platformDefault 
                            : LaunchMode.externalApplication;
                        final launched = await launchUrl(uri, mode: launchMode);
                        if (!launched && mounted) {
                          // Fallback: try external browser
                          await launchUrl(uri, mode: LaunchMode.externalApplication);
                        }
                      } else if (mounted) {
                        ScaffoldMessenger.of(ctx).showSnackBar(
                          const SnackBar(content: Text('Cannot open download URL')),
                        );
                      }
                    } catch (e) {
                      if (mounted) {
                        ScaffoldMessenger.of(ctx).showSnackBar(
                          SnackBar(content: Text('Error opening download: $e')),
                        );
                      }
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
                    try {
                      final uri = Uri.parse(url);
                      // Try external application first (browser)
                      if (await canLaunchUrl(uri)) {
                        // On Android 13+, use platformDefault for better compatibility
                        final launchMode = Platform.isAndroid 
                            ? LaunchMode.platformDefault 
                            : LaunchMode.externalApplication;
                        final launched = await launchUrl(uri, mode: launchMode);
                        if (!launched && mounted) {
                          // Fallback: try external browser
                          await launchUrl(uri, mode: LaunchMode.externalApplication);
                        }
                      } else if (mounted) {
                        ScaffoldMessenger.of(ctx).showSnackBar(
                          const SnackBar(content: Text('Cannot open download URL')),
                        );
                      }
                    } catch (e) {
                      if (mounted) {
                        ScaffoldMessenger.of(ctx).showSnackBar(
                          SnackBar(content: Text('Error opening download: $e')),
                        );
                      }
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

