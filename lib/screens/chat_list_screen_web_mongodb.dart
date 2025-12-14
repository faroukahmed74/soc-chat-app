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
import '../services/realtime_service.dart';
import '../utils/group_chat_naming_utility.dart';
import '../utils/cairo_time_utils.dart';
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
  final RealtimeService _realtime = RealtimeService.instance;

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
      
      // Try parsing as ISO 8601 string first (most common format from server)
      final parsed = DateTime.tryParse(trimmed);
      if (parsed != null && parsed.isAfter(DateTime(2000))) {
        // Valid date after year 2000
        return parsed;
      }
      
      // Try parsing as epoch milliseconds
      final numeric = int.tryParse(trimmed);
      if (numeric != null) {
        // If it's a large number (likely milliseconds), use it
        if (numeric > 946684800000) { // Year 2000 in milliseconds
          return DateTime.fromMillisecondsSinceEpoch(numeric);
        }
        // Otherwise treat as seconds
        return _dateTimeFromEpoch(numeric);
      }
      
      // Try parsing as epoch seconds (if it's a number string)
      final doubleNumeric = double.tryParse(trimmed);
      if (doubleNumeric != null) {
        final intValue = doubleNumeric.toInt();
        if (intValue > 946684800) { // Year 2000 in seconds
          return DateTime.fromMillisecondsSinceEpoch(intValue * 1000);
        }
        return _dateTimeFromEpoch(intValue);
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

      // Connect to realtime service for instant updates
      await _realtime.connect();
      
      // Listen for new messages to update unread count and sorting immediately
      // This handles BOTH received messages AND messages sent by current user
      _realtime.onNewMessage((msg) {
        final chatId = (msg['chatId'] ?? msg['chat_id'] ?? '').toString();
        if (chatId.isEmpty) {
          Log.w('Received new message with empty chatId', 'CHAT_LIST_WEB_MONGODB');
          return;
        }
        
        final isFromCurrentUser = msg['senderId']?.toString() == _currentUserId?.toString();
        Log.i('📨 Real-time new message received for chat: $chatId (from ${isFromCurrentUser ? "current user" : "other user"})', 'CHAT_LIST_WEB_MONGODB');
        
        // Update the chat in the list immediately (for both sent and received messages)
        final chatIndex = _chats.indexWhere((c) => 
          (c['_id'] ?? c['id'] ?? '').toString() == chatId
        );
        
        if (chatIndex != -1) {
          // Update lastMessage and lastMessageTime
          final chat = Map<String, dynamic>.from(_chats[chatIndex]);
          
          // Parse the timestamp properly - CRITICAL: Use the actual message timestamp from server
          DateTime? messageTime;
          
          // Priority 1: Try createdAt from message (most reliable - comes from server)
          if (msg['createdAt'] != null) {
            messageTime = _parseChatTimestamp(msg['createdAt']);
            if (messageTime != null) {
              Log.i('📅 Using createdAt from message: ${messageTime.toIso8601String()}', 'CHAT_LIST_WEB_MONGODB');
            }
          }
          
          // Priority 2: Try timestamp field
          if (messageTime == null && msg['timestamp'] != null) {
            messageTime = _parseChatTimestamp(msg['timestamp']);
            if (messageTime != null) {
              Log.i('📅 Using timestamp from message: ${messageTime.toIso8601String()}', 'CHAT_LIST_WEB_MONGODB');
            }
          }
          
          // Priority 3: Try created_at (alternative field name)
          if (messageTime == null && msg['created_at'] != null) {
            messageTime = _parseChatTimestamp(msg['created_at']);
            if (messageTime != null) {
              Log.i('📅 Using created_at from message: ${messageTime.toIso8601String()}', 'CHAT_LIST_WEB_MONGODB');
            }
          }
          
          // CRITICAL: Only use DateTime.now() as absolute last resort - log warning
          if (messageTime == null) {
            Log.w('⚠️ No valid timestamp found in message, using current time. Message: ${msg.toString()}', 'CHAT_LIST_WEB_MONGODB');
            messageTime = DateTime.now();
          }
          
          // Log the final timestamp being used
          Log.i('📅 Final messageTime for chat $chatId: ${messageTime.toIso8601String()}', 'CHAT_LIST_WEB_MONGODB');
          
          // Always update lastMessage and lastMessageTime (for both sent and received)
          chat['lastMessage'] = {
            'content': msg['content'] ?? '',
            'senderId': msg['senderId'] ?? msg['sender_id'],
            'senderName': msg['senderName'] ?? msg['sender_name'] ?? '',
            'timestamp': messageTime.toIso8601String(),
            'createdAt': messageTime.toIso8601String(),
          };
          chat['lastMessageTime'] = messageTime.toIso8601String();
          chat['updatedAt'] = messageTime.toIso8601String();
          
          // Increment unreadCount ONLY if message is from someone else
          if (!isFromCurrentUser) {
            final unreadCountObj = chat['unreadCount'] ?? {};
            final unreadCountMap = unreadCountObj is Map 
                ? Map<String, dynamic>.from(unreadCountObj)
                : <String, dynamic>{};
            final userIdStr = _currentUserId?.toString() ?? '';
            if (userIdStr.isNotEmpty) {
              final currentCount = (unreadCountMap[userIdStr] as int?) ?? 0;
              unreadCountMap[userIdStr] = currentCount + 1;
              chat['unreadCount'] = unreadCountMap;
            }
          }
          
          // Update the chat in the list
          _chats[chatIndex] = chat;
          
          // ALWAYS re-sort chats by newest message first (for both individual and group chats)
          final sortedChats = _sortChatsByNewestMessage(_chats);
          
          Log.i('🔄 Re-sorting chats after real-time update. New top chat: ${sortedChats.isNotEmpty ? sortedChats[0]['name'] : "none"} (${sortedChats.isNotEmpty ? (sortedChats[0]['type'] ?? 'individual') : "none"})', 'CHAT_LIST_WEB_MONGODB');
          
          // Update state with sorted chats immediately
          if (mounted) {
            setState(() {
              _chats = sortedChats;
              _filteredChats = _searchQuery.isEmpty ? sortedChats : sortedChats.where((chat) {
                final name = (chat['name'] ?? '').toString().toLowerCase();
                return name.contains(_searchQuery.toLowerCase());
              }).toList();
            });
          }
        } else {
          // Chat not in list, reload all chats to get the new chat
          Log.w('Chat $chatId not found in list, reloading all chats', 'CHAT_LIST_WEB_MONGODB');
          _loadChats();
        }
      });

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
          // Merge stream updates with any real-time updates we have
          // This ensures real-time updates aren't lost when stream fires
          final mergedChats = <String, Map<String, dynamic>>{};
          
          // First, add all chats from stream
          for (final chat in chats) {
            final chatId = (chat['_id'] ?? chat['id'] ?? '').toString();
            if (chatId.isNotEmpty) {
              mergedChats[chatId] = Map<String, dynamic>.from(chat);
            }
          }
          
          // Then, merge with any real-time updates from _chats (preserve newer data)
          // CRITICAL: Always prefer real-time updates if they're recent (within last 5 minutes)
          // This prevents stream from overwriting real-time timestamp updates
          final now = DateTime.now();
          for (final chat in _chats) {
            final chatId = (chat['_id'] ?? chat['id'] ?? '').toString();
            if (chatId.isEmpty) continue;
            
            final streamChat = mergedChats[chatId];
            final realtimeTime = _getLastMessageTime(chat);
            
            if (streamChat != null) {
              final streamTime = _getLastMessageTime(streamChat);
              
              // CRITICAL: If real-time timestamp is recent (within 5 minutes), ALWAYS use it
              // This ensures that real-time updates aren't overwritten by stale stream data
              if (realtimeTime != null) {
                final timeDiff = now.difference(realtimeTime).abs();
                if (timeDiff.inMinutes < 5) {
                  // Real-time timestamp is recent, prefer it over stream
                  Log.i('🔄 Preserving recent real-time timestamp for chat $chatId: ${realtimeTime.toIso8601String()} (${timeDiff.inSeconds}s ago)', 'CHAT_LIST_WEB_MONGODB');
                  mergedChats[chatId] = Map<String, dynamic>.from(chat);
                } else if (streamTime != null && realtimeTime.isAfter(streamTime)) {
                  // Real-time is older but still newer than stream, use it
                  mergedChats[chatId] = Map<String, dynamic>.from(chat);
                }
              } else if (streamTime == null && realtimeTime != null) {
                // Real-time has time but stream doesn't, use real-time
                mergedChats[chatId] = Map<String, dynamic>.from(chat);
              }
            } else {
              // Chat exists in real-time but not in stream, add it
              mergedChats[chatId] = Map<String, dynamic>.from(chat);
            }
          }
          
          // Convert merged map back to list
          final mergedChatsList = mergedChats.values.toList();
          
          // Sort chats by newest message first
          final sortedChats = _sortChatsByNewestMessage(mergedChatsList);
          
          Log.i('📊 Stream update: Merged ${mergedChatsList.length} chats, sorted. Top chat: ${sortedChats.isNotEmpty ? sortedChats[0]['name'] : "none"}', 'CHAT_LIST_WEB_MONGODB');
          
          if (mounted) {
            setState(() {
              _chats = sortedChats;
              _filteredChats = _searchQuery.isEmpty ? sortedChats : sortedChats.where((chat) {
                final name = (chat['name'] ?? '').toString().toLowerCase();
                return name.contains(_searchQuery.toLowerCase());
              }).toList();
            });
          }
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
    final cairo = CairoTimeUtils.toCairo(timestamp);
    final nowCairo = CairoTimeUtils.now();
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
                style: TextStyle(
                  fontWeight: FontWeight.w500,
                  color: _themeService.isDarkMode ? Colors.white : Colors.black87, // White in dark mode, dark in light mode
                  fontFamilyFallback: kIsWeb ? const ['NotoNaskhArabic', 'NotoSansArabic'] : null,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (isGroup)
              Icon(
                Icons.group,
                size: 16,
                color: _themeService.isDarkMode ? Colors.white70 : Colors.black54, // White in dark mode, dark in light mode
              ),
          ],
        ),
        subtitle: Text(
          lastMessage,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: _themeService.isDarkMode ? Colors.white : Colors.black87, // White in dark mode, dark in light mode
            fontFamilyFallback: kIsWeb ? const ['NotoNaskhArabic', 'NotoSansArabic'] : null,
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
                color: Theme.of(context).colorScheme.onSurfaceVariant.withOpacity(0.7), // Use theme color
              ),
              key: ValueKey('timestamp_${chatId}_${lastMessageTime.millisecondsSinceEpoch}'), // Force rebuild on timestamp change
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
        title: Text(
          'SOC Chat App - Web',
          style: TextStyle(
            fontFamilyFallback: kIsWeb ? const ['NotoNaskhArabic', 'NotoSansArabic'] : null,
          ),
        ),
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
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      fontFamilyFallback: kIsWeb ? const ['NotoNaskhArabic', 'NotoSansArabic'] : null,
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
