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
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../utils/cairo_time_utils.dart';
import '../services/theme_service.dart';
import '../services/mongodb_chat_service.dart';
import '../services/physical_auth_service.dart';
import '../services/logger_service.dart';
import '../services/message_sound_service.dart';
import '../services/active_chat_service.dart';
import '../utils/group_chat_naming_utility.dart';
import '../utils/responsive_utils.dart';
// Unified chat screen for all platforms (web, Android, iOS)
import 'chat_screen_mongodb.dart';
import '../services/version_check_service.dart';
import '../services/fixed_version_check_service.dart';
import '../services/realtime_service.dart';
// import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../config/version_config.dart';
import '../config/database_config.dart';
import '../theme/app_design_system.dart';
import '../widgets/update_dialog.dart';
import '../services/ai_chat_service.dart';

class ChatListScreenMongoDB extends StatefulWidget {
  const ChatListScreenMongoDB({Key? key}) : super(key: key);

  @override
  State<ChatListScreenMongoDB> createState() => _ChatListScreenMongoDBState();
}

class _ChatListScreenMongoDBState extends State<ChatListScreenMongoDB> with SingleTickerProviderStateMixin {
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
  final RealtimeService _realtime = RealtimeService.instance;
  
  // Tab controller for All Chats / Groups tabs
  late TabController _tabController;
  int _selectedTabIndex = 0; // 0 = All Chats, 1 = Groups

  // Track last message timestamps to detect new messages for sound
  final Map<String, DateTime> _lastMessageTimes = {};

  // AI Chat state
  Map<String, dynamic>? _aiStatus;
  bool _isLoadingAIStatus = false;
  bool _isOpeningAIChat = false;
  Timer? _aiStatusTimer;

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

  @override
  void initState() {
    super.initState();
    _themeService = ThemeService.instance;
    _themeService.addListener(() {
      if (mounted) setState(() {});
    });
    // Initialize tab controller with 2 tabs (All Chats, Groups)
    _tabController = TabController(length: 2, vsync: this, initialIndex: 0);
    _tabController.addListener(_onTabChanged);
    _initializeChatList();
    _loadUserRole();
    _searchController.addListener(_onSearchChanged);
    _maybeAutoCheckUpdate();
    _checkAIStatus();
    // Poll AI status every 30 seconds to check for model installation
    _aiStatusTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      _checkAIStatus();
    });
  }
  
  void _onTabChanged() {
    if (_tabController.indexIsChanging) return;
    setState(() {
      _selectedTabIndex = _tabController.index;
      _filteredChats = _applySearchFilter(_getChatsForCurrentTab());
    });
  }
  
  /// Get chats for the currently selected tab
  List<Map<String, dynamic>> _getChatsForCurrentTab() {
    if (_selectedTabIndex == 0) {
      // All Chats tab - return all chats
      return _chats;
    } else {
      // Groups tab - return only group chats
      return _filterGroupChats(_chats);
    }
  }
  
  /// Filter to get only group chats
  List<Map<String, dynamic>> _filterGroupChats(List<Map<String, dynamic>> chats) {
    return chats.where((chat) {
      // More robust group detection - check multiple possible fields
      final bool isGroup = chat['type'] == 'group' || 
                          (chat['isGroup'] == true) || 
                          (chat['isGroupChat'] == true) ||
                          (chat['members'] != null && (chat['members'] as List).length > 2);
      return isGroup;
    }).toList();
  }

  @override
  void dispose() {
    _chatsSubscription?.cancel();
    _searchController.dispose();
    _tabController.dispose();
    _aiStatusTimer?.cancel();
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

      // Ensure chatbot chat exists for this user (works on all platforms including iOS)
      await _ensureChatbotChatExists();

      // Connect to realtime service for instant updates
      await _realtime.connect();
      
      // Listen for new messages to update unread count and sorting immediately
      // This handles BOTH received messages AND messages sent by current user
      _realtime.onNewMessage((msg) {
        final chatId = (msg['chatId'] ?? msg['chat_id'] ?? '').toString();
        if (chatId.isEmpty) {
          Log.w('Received new message with empty chatId', 'CHAT_LIST_MONGODB');
          return;
        }
        
        final isFromCurrentUser = msg['senderId']?.toString() == _currentUserId?.toString();
        Log.i('📨 Real-time new message received for chat: $chatId (from ${isFromCurrentUser ? "current user" : "other user"})', 'CHAT_LIST_MONGODB');
        
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
              Log.i('📅 Using createdAt from message: ${messageTime.toIso8601String()}', 'CHAT_LIST_MONGODB');
            }
          }
          
          // Priority 2: Try timestamp field
          if (messageTime == null && msg['timestamp'] != null) {
            messageTime = _parseChatTimestamp(msg['timestamp']);
            if (messageTime != null) {
              Log.i('📅 Using timestamp from message: ${messageTime.toIso8601String()}', 'CHAT_LIST_MONGODB');
            }
          }
          
          // Priority 3: Try created_at (alternative field name)
          if (messageTime == null && msg['created_at'] != null) {
            messageTime = _parseChatTimestamp(msg['created_at']);
            if (messageTime != null) {
              Log.i('📅 Using created_at from message: ${messageTime.toIso8601String()}', 'CHAT_LIST_MONGODB');
            }
          }
          
          // CRITICAL: Only use DateTime.now() as absolute last resort - log warning
          if (messageTime == null) {
            Log.w('⚠️ No valid timestamp found in message, using current time. Message: ${msg.toString()}', 'CHAT_LIST_MONGODB');
            messageTime = DateTime.now();
          }
          
          // Log the final timestamp being used
          Log.i('📅 Final messageTime for chat $chatId: ${messageTime.toIso8601String()}', 'CHAT_LIST_MONGODB');
          
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
          
          // Update last message time tracking
          _lastMessageTimes[chatId] = messageTime;
          
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
          
          Log.i('🔄 Re-sorting chats after real-time update. New top chat: ${sortedChats.isNotEmpty ? sortedChats[0]['name'] : "none"} (${sortedChats.isNotEmpty ? (sortedChats[0]['type'] ?? 'individual') : "none"})', 'CHAT_LIST_MONGODB');
          
          // Update state with sorted chats immediately
          if (mounted) {
            setState(() {
              _chats = sortedChats;
              _filteredChats = _applySearchFilter(_getChatsForCurrentTab());
            });
            // Force a rebuild to ensure timestamp display updates
            Log.i('🔄 UI updated for chat $chatId. New timestamp: ${messageTime.toIso8601String()}', 'CHAT_LIST_MONGODB');
          }
        } else {
          // Chat not in list, reload all chats to get the new chat
          Log.w('Chat $chatId not found in list, reloading all chats', 'CHAT_LIST_MONGODB');
          _loadChats();
        }
      });
      
      // Start listening for chat updates
      _startChatListener();

      // Check for pending navigation from FCM notification
      await _checkPendingNavigation();
      await _checkPendingCallData();
    } catch (e) {
      Log.e('Error initializing chat list', 'CHAT_LIST_MONGODB', e);
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
        // ALWAYS sort chats by newest message first (for both individual and group chats)
        final sortedChats = _sortChatsByNewestMessage(chats);
        setState(() {
          _chats = sortedChats;
          _filteredChats = _applySearchFilter(_getChatsForCurrentTab());
        });
        Log.i('✅ Loaded and sorted ${sortedChats.length} chats. Top chat: ${sortedChats.isNotEmpty ? sortedChats[0]['name'] : "none"}', 'CHAT_LIST_MONGODB');
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

      DateTime? messageTime = _parseChatTimestamp(chat['lastMessageTime']);

      if (messageTime == null) {
        final lastMessageObj = chat['lastMessage'];
        if (lastMessageObj is Map<String, dynamic>) {
          messageTime = _parseChatTimestamp(
            lastMessageObj['timestamp'] ??
                lastMessageObj['createdAt'] ??
                lastMessageObj['time'],
          );
        } else {
          messageTime = _parseChatTimestamp(lastMessageObj);
        }
      }

      messageTime ??= _parseChatTimestamp(chat['updatedAt']);
      messageTime ??= _parseChatTimestamp(chat['createdAt']);

      if (messageTime != null) {
        _lastMessageTimes[chatId] = messageTime;
      }
    }

    _chatsSubscription = _chatService.watchUserChats().listen(
      (chats) {
        if (mounted) {
          // Check for new messages and play sound
          _checkForNewMessages(chats);

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
                  Log.i('🔄 Preserving recent real-time timestamp for chat $chatId: ${realtimeTime.toIso8601String()} (${timeDiff.inSeconds}s ago)', 'CHAT_LIST_MONGODB');
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

          Log.i('📊 Stream update: Merged ${mergedChatsList.length} chats, sorted. Top chat: ${sortedChats.isNotEmpty ? sortedChats[0]['name'] : "none"}', 'CHAT_LIST_MONGODB');

          setState(() {
            _chats = sortedChats;
            _filteredChats = _applySearchFilter(_getChatsForCurrentTab());
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
        final messageTime =
            _parseChatTimestamp(lastMessageTime) ??
            (lastMessageObj is Map<String, dynamic>
                ? _parseChatTimestamp(
                    lastMessageObj['timestamp'] ??
                        lastMessageObj['createdAt'] ??
                        lastMessageObj['time'],
                  )
                : _parseChatTimestamp(lastMessageObj)) ??
            _parseChatTimestamp(chat['updatedAt']) ??
            _parseChatTimestamp(chat['createdAt']);
        if (messageTime != null) {
          _lastMessageTimes[chatId] = messageTime;
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
      DateTime? currentMessageTime =
          _parseChatTimestamp(lastMessageTime) ??
          (lastMessageObj is Map<String, dynamic>
              ? _parseChatTimestamp(
                  lastMessageObj['timestamp'] ??
                      lastMessageObj['createdAt'] ??
                      lastMessageObj['time'],
                )
              : _parseChatTimestamp(lastMessageObj)) ??
          _parseChatTimestamp(chat['updatedAt']) ??
          _parseChatTimestamp(chat['createdAt']);

      if (currentMessageTime != null) {
        final previousTime = _lastMessageTimes[chatId];

        // If timestamp is newer, it's a new message
        if (previousTime == null || currentMessageTime.isAfter(previousTime)) {
          // Don't play sound here - let device notification sound handle it
          // MessageSoundService().playMessageSound(); // Removed - use device notification sound

          // Update timestamp
          _lastMessageTimes[chatId] = currentMessageTime;
        }
      }
    }
  }

  List<Map<String, dynamic>> _sortChatsByNewestMessage(
    List<Map<String, dynamic>> chats,
  ) {
    // Sort chats by lastMessageTime descending (newest first)
    // This applies to BOTH individual and group chats
    // Works for messages sent by current user AND messages received from others
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
        return updatedB.compareTo(updatedA); // Newest first
      }
      if (timeA == null) return 1; // No message goes to end
      if (timeB == null) return -1; // Has message goes to front

      // Sort by newest first (descending) - this works for both sent and received messages
      // timeB.compareTo(timeA) means: if timeB > timeA, return positive (B comes first)
      final comparison = timeB.compareTo(timeA);

      // If times are equal, use fallback time for secondary sort
      if (comparison == 0) {
        final updatedA = _getFallbackTime(a);
        final updatedB = _getFallbackTime(b);
        if (updatedA == null && updatedB == null) return 0;
        if (updatedA == null) return 1;
        if (updatedB == null) return -1;
        return updatedB.compareTo(updatedA); // Newest first
      }
      return comparison;
    });

    // Debug: Log first few sorted chats to verify sorting
    if (sorted.isNotEmpty) {
      Log.i('📋 Sorted ${sorted.length} chats. Top 3:', 'CHAT_LIST_MONGODB');
      for (int i = 0; i < sorted.length && i < 3; i++) {
        final chat = sorted[i];
        final chatId = (chat['_id'] ?? chat['id'] ?? '').toString();
        final chatName = chat['name'] ?? 'Unknown';
        final chatType = chat['type'] ?? 'unknown';
        final lastMsgTime = _getLastMessageTime(chat);
        Log.i(
          '  ${i + 1}. $chatName ($chatType) - Last message: ${lastMsgTime?.toIso8601String() ?? "none"}',
          'CHAT_LIST_MONGODB',
        );
      }
    }

    return sorted;
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

  /// Apply search filter to chats
  List<Map<String, dynamic>> _applySearchFilter(List<Map<String, dynamic>> chats) {
    final query = _searchQuery.toLowerCase();
    if (query.isEmpty) {
      return chats;
    } else {
      final filtered = chats.where((chat) {
        final name = (chat['name'] ?? '').toString().toLowerCase();
        final lastMessageObj = chat['lastMessage'];
        String lastMessage = '';
        if (lastMessageObj is Map) {
          lastMessage = (lastMessageObj['content'] ?? '').toString().toLowerCase();
        } else {
          lastMessage = lastMessageObj.toString().toLowerCase();
        }
        return name.contains(query) || lastMessage.contains(query);
      }).toList();
      // Maintain sort order for filtered results
      return _sortChatsByNewestMessage(filtered);
    }
  }

  void _onSearchChanged() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _searchQuery = query;
      _filteredChats = _applySearchFilter(_getChatsForCurrentTab());
    });
  }

  String _formatTimestamp(DateTime? timestamp) {
    if (timestamp == null) return '';
    final cairo = CairoTimeUtils.toCairo(timestamp);
    final nowCairo = CairoTimeUtils.now();
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
    final DateTime? lastMessageTime = _getLastMessageTime(chat);

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
            if (key.toString() == userIdStr ||
                key.toString() == _currentUserId?.toString()) {
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
        unreadCount = unreadCountObj is int
            ? unreadCountObj
            : unreadCountObj.toInt();
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
              ? readBy
                    .map((e) => e?.toString())
                    .where((e) => e != null && e.isNotEmpty)
                    .cast<String>()
                    .toList()
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
            // Unread indicator red dot on avatar
            if (hasUnreadMessage)
              Positioned(
                right: -2,
                top: -2,
                child: Container(
                  width: 16,
                  height: 16,
                  decoration: BoxDecoration(
                    color: Colors.red,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Theme.of(context).scaffoldBackgroundColor,
                      width: 2.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.red.withOpacity(0.5),
                        blurRadius: 4,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                ),
              ),
            // Unread count badge beside the red dot
            if (hasUnreadMessage && unreadCount > 0)
              Positioned(
                right: 8, // Position to the right of the red dot
                top: -6,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 5,
                    vertical: 1,
                  ),
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
                  fontWeight: hasUnreadMessage
                      ? FontWeight.bold
                      : FontWeight.w600,
                  color: Theme.of(context).brightness == Brightness.dark 
                      ? Colors.white 
                      : Colors.black87, // White in dark mode, dark in light mode
                  fontFamily: kIsWeb ? 'NotoNaskhArabic' : null,
                  fontFamilyFallback: kIsWeb
                      ? const [
                          'NotoSansArabic',
                          'Apple Color Emoji',
                          'Segoe UI Emoji',
                          'Segoe UI Symbol',
                          'Noto Color Emoji',
                          'Android Emoji',
                          'EmojiSymbols',
                          'EmojiOne Mozilla',
                          'Twemoji Mozilla',
                          'Segoe UI Historic',
                          'Arial',
                          'Helvetica',
                          'Segoe UI',
                          'Tahoma',
                          'sans-serif'
                        ]
                      : null,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (isGroup) ...[
              SizedBox(width: 4),
              Icon(
                Icons.group,
                size: 16,
                color: Theme.of(context).brightness == Brightness.dark 
                    ? Colors.white70 
                    : Colors.black54, // White in dark mode, dark in light mode
              ),
            ],
          ],
        ),
        subtitle: Text(
          lastMessage.isNotEmpty ? lastMessage : 'No messages yet',
          overflow: TextOverflow.ellipsis,
          style: AppDesignSystem.bodyMedium.copyWith(
            color: Theme.of(context).brightness == Brightness.dark 
                ? Colors.white 
                : Colors.black87, // White in dark mode, dark in light mode
            fontWeight: hasUnreadMessage ? FontWeight.bold : FontWeight.normal,
            fontSize: hasUnreadMessage ? 14 : 13,
            fontFamily: kIsWeb ? 'NotoNaskhArabic' : null,
            fontFamilyFallback: kIsWeb
                ? const [
                    'NotoSansArabic',
                    'Apple Color Emoji',
                    'Segoe UI Emoji',
                    'Segoe UI Symbol',
                    'Noto Color Emoji',
                    'Android Emoji',
                    'EmojiSymbols',
                    'EmojiOne Mozilla',
                    'Twemoji Mozilla',
                    'Segoe UI Historic',
                    'Arial',
                    'Helvetica',
                    'Segoe UI',
                    'Tahoma',
                    'sans-serif'
                  ]
                : null,
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
                  color: Theme.of(context).colorScheme.onSurfaceVariant.withOpacity(0.7), // Use theme color
                  fontSize: 11,
                ),
                key: ValueKey('timestamp_${chatId}_${lastMessageTime.millisecondsSinceEpoch}'), // Force rebuild on timestamp change
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
          // This ensures the unread count is cleared and UI updates immediately
          if (mounted) {
            // Small delay to allow server to process the unread count reset
            await Future.delayed(const Duration(milliseconds: 300));
            // Reload chats to get updated unread counts
            await _loadChats();
            // Force immediate UI update
            if (mounted) {
              setState(() {});
            }
          }
        },
      ),
    );
  }

  /// Check for pending navigation from FCM notification
  Future<void> _checkPendingNavigation() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final pendingChatId = prefs.getString('pending_chat_navigation');

      if (pendingChatId != null && pendingChatId.isNotEmpty) {
        // Clear the pending navigation
        await prefs.remove('pending_chat_navigation');

        // Wait a bit for the UI to be ready
        await Future.delayed(const Duration(milliseconds: 500));

        if (!mounted) return;

        // Get chat details
        try {
          final chatDetails = await _chatService.getChatDetails(pendingChatId);
          if (chatDetails != null) {
            final chat = chatDetails['chat'] ?? chatDetails;
            final chatName = chat['name']?.toString() ?? 'Chat';
            final isGroupChat =
                chat['type']?.toString() == 'group' ||
                ((chat['members'] as List?)?.length ?? 0) > 2;
            final members = chat['members'] as List?;

            if (mounted) {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ChatScreenMongoDB(
                    chatId: pendingChatId,
                    chatName: chatName,
                    isGroupChat: isGroupChat,
                    userIds: members != null
                        ? members.map((m) => m.toString()).toList()
                        : null,
                  ),
                ),
              );
              Log.i(
                '✅ Navigated to pending chat: $pendingChatId',
                'CHAT_LIST_MONGODB',
              );
            }
          }
        } catch (e) {
          Log.e('Error navigating to pending chat', 'CHAT_LIST_MONGODB', e);
        }
      }
    } catch (e) {
      Log.e('Error checking pending navigation', 'CHAT_LIST_MONGODB', e);
    }
  }

  /// Check for pending call data from FCM notification (when app was closed)
  Future<void> _checkPendingCallData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final pendingCallDataStr = prefs.getString('pending_call_data');

      if (pendingCallDataStr != null && pendingCallDataStr.isNotEmpty) {
        // Clear the pending call data
        await prefs.remove('pending_call_data');

        // Wait a bit for the UI to be ready
        await Future.delayed(const Duration(milliseconds: 1000));

        if (!mounted) return;

        try {
          final data = jsonDecode(pendingCallDataStr) as Map<String, dynamic>;
          final callId = data['callId']?.toString();
          final chatId = data['chatId']?.toString();
          final chatName = data['chatName']?.toString() ?? 'Unknown';
          final callTypeStr = data['callType']?.toString() ?? 'video';
          final isGroupChat = data['isGroupChat']?.toString() == 'true';

          if (callId != null && callId.isNotEmpty && chatId != null && chatId.isNotEmpty) {
            Log.i(
              '📞 Navigating to pending call: callId=$callId, chatId=$chatId',
              'CHAT_LIST_MONGODB',
            );

            if (mounted) {
              Navigator.pushNamed(
                context,
                '/call',
                arguments: {
                  'chatId': chatId,
                  'chatName': chatName,
                  'isGroupChat': isGroupChat,
                  'callType': callTypeStr,
                  'direction': 'incoming',
                  'callId': callId,
                },
              );
              Log.i(
                '✅ Navigated to pending call: $callId',
                'CHAT_LIST_MONGODB',
              );
            }
          }
        } catch (e) {
          Log.e('Error navigating to pending call', 'CHAT_LIST_MONGODB', e);
        }
      }
    } catch (e) {
      Log.e('Error checking pending call data', 'CHAT_LIST_MONGODB', e);
    }
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
            fontFamily: kIsWeb ? 'NotoNaskhArabic' : null,
            fontFamilyFallback: kIsWeb
                ? const [
                    'NotoSansArabic',
                    'Apple Color Emoji',
                    'Segoe UI Emoji',
                    'Segoe UI Symbol',
                    'Noto Color Emoji',
                    'Android Emoji',
                    'EmojiSymbols',
                    'EmojiOne Mozilla',
                    'Twemoji Mozilla',
                    'Segoe UI Historic',
                    'Arial',
                    'Helvetica',
                    'Segoe UI',
                    'Tahoma',
                    'sans-serif'
                  ]
                : null,
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
              PopupMenuItem(
                value: 'search',
                child: Row(
                  children: [
                    Icon(
                      Icons.person_add,
                      color: Theme.of(context).colorScheme.primary,
                    ),
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
                      fontFamily: kIsWeb ? 'NotoNaskhArabic' : null,
                      fontFamilyFallback: kIsWeb
                          ? const [
                              'NotoSansArabic',
                              'Apple Color Emoji',
                              'Segoe UI Emoji',
                              'Segoe UI Symbol',
                              'Noto Color Emoji',
                              'Android Emoji',
                              'EmojiSymbols',
                              'EmojiOne Mozilla',
                              'Twemoji Mozilla',
                              'Segoe UI Historic',
                              'Arial',
                              'Helvetica',
                              'Segoe UI',
                              'Tahoma',
                              'sans-serif'
                            ]
                          : null,
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
              leading: Icon(Icons.logout, color: AppDesignSystem.errorColor),
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
          // Tab Bar for All Chats / Groups
          Container(
            color: Theme.of(context).colorScheme.surface,
            child: TabBar(
              controller: _tabController,
              labelColor: Theme.of(context).colorScheme.primary,
              unselectedLabelColor: Theme.of(context).colorScheme.onSurfaceVariant,
              indicatorColor: Theme.of(context).colorScheme.primary,
              indicatorWeight: 3,
              labelStyle: AppDesignSystem.titleSmall.copyWith(
                fontWeight: FontWeight.bold,
              ),
              unselectedLabelStyle: AppDesignSystem.titleSmall,
              tabs: [
                Tab(
                  icon: Icon(Icons.chat, size: isWideScreen ? 24 : 20),
                  text: 'All Chats',
                ),
                Tab(
                  icon: Icon(Icons.group, size: isWideScreen ? 24 : 20),
                  text: 'Groups',
                ),
              ],
            ),
          ),
          Padding(
            padding: EdgeInsets.all(isWideScreen ? 24.0 : 16.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: _selectedTabIndex == 0 
                    ? 'Search chats...' 
                    : 'Search groups...',
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
                          _selectedTabIndex == 0 
                              ? Icons.chat_bubble_outline 
                              : Icons.group_outlined,
                          size: 64,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _searchQuery.isNotEmpty
                              ? (_selectedTabIndex == 0
                                  ? 'No chats found matching "$_searchQuery"'
                                  : 'No groups found matching "$_searchQuery"')
                              : (_selectedTabIndex == 0
                                  ? 'No chats yet. Start a conversation!'
                                  : 'No groups yet. Create a group to get started!'),
                          style: AppDesignSystem.bodyLarge.copyWith(
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurfaceVariant,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        if (_selectedTabIndex == 0)
                          ElevatedButton.icon(
                            onPressed: () {
                              Navigator.pushNamed(context, '/search');
                            },
                            icon: const Icon(Icons.person_add),
                            label: const Text('Search Users'),
                          )
                        else
                          ElevatedButton.icon(
                            onPressed: () {
                              Navigator.pushNamed(context, '/create_group');
                            },
                            icon: const Icon(Icons.group_add),
                            label: const Text('Create Group'),
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
                      return _buildChatTile(
                        _filteredChats[index],
                        isWideScreen,
                      );
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: _buildFloatingActionButtons(),
    );
  }

  Future<void> _checkForUpdate() async {
    if (_isCheckingUpdate) return;
    setState(() => _isCheckingUpdate = true);
    try {
      // Use FixedVersionCheckService for enhanced update checking
      final info = await FixedVersionCheckService.checkForUpdates();
      if (info == null) {
        if (mounted) {
          showDialog(
            context: context,
            builder: (ctx) => AlertDialog(
              title: Text(
                'Update Check',
                style: ResponsiveUtils.getResponsiveHeadingStyle(ctx),
              ),
              content: Container(
                width: ResponsiveUtils.getResponsiveValue(
                  ctx,
                  mobile: MediaQuery.of(ctx).size.width * 0.9,
                  tablet: 400.0,
                  desktop: 500.0,
                ),
                child: Text(
                  'Unable to check for updates right now.',
                  style: ResponsiveUtils.getResponsiveBodyStyle(ctx),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: Text(
                    'OK',
                    style: ResponsiveUtils.getResponsiveBodyStyle(ctx),
                  ),
                ),
              ],
            ),
          );
        }
        return;
      }

      if (info['hasUpdate'] == true) {
        // Get app name
        final appName = await FixedVersionCheckService.getAppName();
        
        // Prepare update info for UpdateDialog
        final updateInfo = {
          'appName': appName,
          'currentVersion': info['currentVersion'] ?? '1.0.0',
          'currentBuildNumber': info['currentBuildNumber'] ?? '1',
          'latestVersion': info['latestVersion'] ?? '1.0.0',
          'latestBuildNumber': info['latestBuildNumber'] ?? '1',
          'downloadUrl': info['downloadUrl'] ?? '',
          'releaseNotes': info['releaseNotes'] ?? 'Bug fixes and improvements',
          'forceUpdate': info['forceUpdate'] ?? false,
        };
        
        if (!mounted) return;
        
        // Show enhanced UpdateDialog with download progress support
        showDialog(
          context: context,
          builder: (ctx) => UpdateDialog(
            updateInfo: updateInfo,
            onDismiss: () {
              // Optional: Handle dismiss callback if needed
            },
          ),
        );
      } else {
        // No update available
        if (!mounted) return;
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Text(
              'You are up to date',
              style: ResponsiveUtils.getResponsiveHeadingStyle(ctx),
            ),
            content: Container(
              width: ResponsiveUtils.getResponsiveValue(
                ctx,
                mobile: MediaQuery.of(ctx).size.width * 0.9,
                tablet: 400.0,
                desktop: 500.0,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.check_circle_outline,
                    color: Colors.green,
                    size: ResponsiveUtils.getResponsiveIconSize(ctx) * 2,
                  ),
                  SizedBox(height: ResponsiveUtils.getResponsiveSpacing(ctx)),
                  Text(
                    'No new updates are available.\nYou are using the latest version.',
                    style: ResponsiveUtils.getResponsiveBodyStyle(ctx),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: ResponsiveUtils.getResponsiveSpacing(ctx) * 0.5),
                  Text(
                    'Current version: ${info['currentVersion'] ?? '1.0.0'} (${info['currentBuildNumber'] ?? '1'})',
                    style: ResponsiveUtils.getResponsiveBodyStyle(ctx),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text(
                  'OK',
                  style: ResponsiveUtils.getResponsiveBodyStyle(ctx),
                ),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Text(
              'Update Check Failed',
              style: ResponsiveUtils.getResponsiveHeadingStyle(ctx),
            ),
            content: Container(
              width: ResponsiveUtils.getResponsiveValue(
                ctx,
                mobile: MediaQuery.of(ctx).size.width * 0.9,
                tablet: 400.0,
                desktop: 500.0,
              ),
              child: Text(
                'Error: $e',
                style: ResponsiveUtils.getResponsiveBodyStyle(ctx),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text(
                  'OK',
                  style: ResponsiveUtils.getResponsiveBodyStyle(ctx),
                ),
              ),
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
      final intervalMs = Duration(
        hours: VersionConfig.updateCheckIntervalHours,
      ).inMilliseconds;
      if (nowMs - lastMs < intervalMs) return;
      await prefs.setInt('last_update_check_ms', nowMs);

      // Use FixedVersionCheckService for enhanced update checking
      final info = await FixedVersionCheckService.checkForUpdates();
      if (info == null) return;
      if (info['hasUpdate'] == true) {
        // Get app name
        final appName = await FixedVersionCheckService.getAppName();
        
        // Prepare update info for UpdateDialog
        final updateInfo = {
          'appName': appName,
          'currentVersion': info['currentVersion'] ?? '1.0.0',
          'currentBuildNumber': info['currentBuildNumber'] ?? '1',
          'latestVersion': info['latestVersion'] ?? '1.0.0',
          'latestBuildNumber': info['latestBuildNumber'] ?? '1',
          'downloadUrl': info['downloadUrl'] ?? '',
          'releaseNotes': info['releaseNotes'] ?? 'Bug fixes and improvements',
          'forceUpdate': info['forceUpdate'] ?? false,
        };
        
        if (!mounted) return;
        
        // Show enhanced UpdateDialog with download progress support
        showDialog(
          context: context,
          builder: (ctx) => UpdateDialog(
            updateInfo: updateInfo,
            onDismiss: () {
              // Optional: Handle dismiss callback if needed
            },
          ),
        );
      }
    } catch (e) {
      // Silently fail for automatic checks - don't show error to user
      Log.w('Automatic update check failed: $e', 'CHAT_LIST_MONGODB');
    }
  }
  
  /// Ensure chatbot chat exists for the current user (works on all platforms including iOS)
  /// This method checks if a chatbot user exists and creates a chat with it if needed
  Future<void> _ensureChatbotChatExists() async {
    try {
      if (_currentUserId == null || _currentUserId!.isEmpty) {
        Log.w('Cannot ensure chatbot chat: current user ID is null', 'CHAT_LIST_MONGODB');
        return;
      }

      // Check if chatbot chat already exists in current chats
      final hasChatbotChat = _chats.any((chat) {
        final name = (chat['name'] ?? '').toString().toLowerCase();
        final members = List<String>.from(chat['members'] ?? []);
        // Check if chat name contains "bot" or "assistant" or has chatbot email
        return name.contains('bot') || 
               name.contains('assistant') || 
               name.contains('ai') ||
               members.any((id) => id.toString().contains('bot') || id.toString().contains('assistant'));
      });

      if (hasChatbotChat) {
        Log.i('Chatbot chat already exists in chat list', 'CHAT_LIST_MONGODB');
        return;
      }

      // Try to find chatbot user by searching for common chatbot identifiers
      final token = await _authService.getAuthToken();
      if (token == null) {
        Log.w('Cannot ensure chatbot chat: no auth token', 'CHAT_LIST_MONGODB');
        return;
      }

      final baseUrl = DatabaseConfig.physicalServerUrl;
      
      // Search for chatbot user by fetching all users and filtering
      String? chatbotUserId;
      
      try {
        final response = await http.get(
          Uri.parse('$baseUrl/api/users'),
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json',
            'ngrok-skip-browser-warning': 'true',
          },
        );

        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          final users = data is List ? data : (data['users'] is List ? data['users'] : []);
          
          // Search for chatbot user by email, displayName, or role
          for (final user in users) {
            final email = (user['email'] ?? '').toString().toLowerCase();
            final displayName = (user['displayName'] ?? user['name'] ?? '').toString().toLowerCase();
            final role = (user['role'] ?? '').toString().toLowerCase();
            
            // Check if this is a chatbot user
            if (email.contains('bot') || 
                email.contains('assistant') || 
                email.contains('ai') ||
                displayName.contains('bot') || 
                displayName.contains('assistant') || 
                displayName.contains('ai') ||
                role == 'bot' || 
                role == 'assistant') {
              chatbotUserId = user['_id'] ?? user['id'];
              Log.i('Found chatbot user: $chatbotUserId (email: $email, name: $displayName)', 'CHAT_LIST_MONGODB');
              break;
            }
          }
        }
      } catch (e) {
        Log.w('Error fetching users to find chatbot: $e', 'CHAT_LIST_MONGODB');
      }

      if (chatbotUserId == null || chatbotUserId.isEmpty) {
        Log.w('Chatbot user not found - chatbot chat will not be created automatically', 'CHAT_LIST_MONGODB');
        Log.w('To enable chatbot, create a user with email containing "bot" or "assistant"', 'CHAT_LIST_MONGODB');
        return;
      }

      // Check if chat already exists (might not be in current list if it has no messages)
      final existingChat = await _chatService.findExistingChat(_currentUserId!, chatbotUserId);
      if (existingChat != null) {
        Log.i('Chatbot chat already exists (found via findExistingChat)', 'CHAT_LIST_MONGODB');
        // Add it to the chat list if not already there
        final chatId = existingChat['_id'] ?? existingChat['id'];
        final chatExists = _chats.any((c) => 
          (c['_id'] ?? c['id'] ?? '').toString() == chatId.toString()
        );
        if (!chatExists && mounted) {
          setState(() {
            _chats.add(existingChat);
            _filteredChats = _applySearchFilter(_getChatsForCurrentTab());
          });
        }
        return;
      }

      // Create chatbot chat
      Log.i('Creating chatbot chat for user: $_currentUserId', 'CHAT_LIST_MONGODB');
      final chatbotChat = await _chatService.findOrCreateChat(
        'private',
        'Chatbot Assistant',
        [_currentUserId!, chatbotUserId],
      );

      if (chatbotChat != null && mounted) {
        Log.i('✅ Chatbot chat created successfully', 'CHAT_LIST_MONGODB');
        // Reload chats to include the new chatbot chat
        await _loadChats();
      } else {
        Log.w('Failed to create chatbot chat', 'CHAT_LIST_MONGODB');
      }
    } catch (e, stackTrace) {
      // Don't show error to user - this is a background operation
      Log.e('Error ensuring chatbot chat exists', 'CHAT_LIST_MONGODB', e, stackTrace);
    }
  }

  /// Check AI status (Ollama availability, models, etc.)
  Future<void> _checkAIStatus() async {
    if (_isLoadingAIStatus) return;
    
    setState(() => _isLoadingAIStatus = true);
    try {
      final status = await AIChatService.getAIStatus();
      if (mounted) {
        setState(() {
          _aiStatus = status;
          _isLoadingAIStatus = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingAIStatus = false);
      }
      Log.w('Failed to check AI status: $e', 'CHAT_LIST_MONGODB');
    }
  }

  /// Open or create AI chat
  Future<void> _openAIChat() async {
    if (_isOpeningAIChat) return;
    
    setState(() => _isOpeningAIChat = true);
    try {
      // Re-check status on tap (handles stale/failed initial check)
      await _checkAIStatus();
      if (!mounted) return;
      
      // Check if AI is available
      if (_aiStatus == null || _aiStatus!['enabled'] != true) {
        final String message;
        if (_aiStatus == null) {
          message = 'Cannot reach server. Check your connection and server URL.';
        } else {
          // enabled is false = AI bot user not in MongoDB
          message = 'AI bot not configured. Run create-ai-bot.js on the server.';
        }
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(message),
              duration: const Duration(seconds: 4),
            ),
          );
        }
        setState(() => _isOpeningAIChat = false);
        return;
      }

      // Get or create AI chat
      final aiChatData = await AIChatService.getOrCreateAIChat();
      
      if (aiChatData != null && aiChatData['chatId'] != null) {
        final chatId = aiChatData['chatId'] as String;
        final chat = aiChatData['chat'] as Map<String, dynamic>;
        
        if (mounted) {
          // Navigate to AI chat and refresh list when returning
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ChatScreenMongoDB(
                chatId: chatId,
                chatName: chat['name'] ?? 'AI Assistant',
                isGroupChat: false,
                userIds: List<String>.from(chat['members'] ?? []),
              ),
            ),
          );
          
          // Refresh chat list when returning from AI chat
          if (mounted) {
            await _loadChats();
          }
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to open AI chat. Please try again.'),
              duration: Duration(seconds: 3),
            ),
          );
        }
      }
    } catch (e) {
      Log.e('Error opening AI chat', 'CHAT_LIST_MONGODB', e);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isOpeningAIChat = false);
      }
    }
  }

  /// Build floating action buttons (AI chat + Search users)
  Widget _buildFloatingActionButtons() {
    final isDesktop = ResponsiveUtils.isDesktop(context);
    final spacing = isDesktop ? 16.0 : 12.0;
    
    // Determine AI button state
    final bool aiEnabled = _aiStatus?['enabled'] == true;
    final bool ollamaAvailable = _aiStatus?['ollamaAvailable'] == true;
    final bool isInstalling = !ollamaAvailable && _aiStatus != null; // Ollama not available but status was checked
    
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        // AI Chat Button
        FloatingActionButton(
          heroTag: 'fab_ai_chat',
          onPressed: _isOpeningAIChat ? null : _openAIChat,
          backgroundColor: _isOpeningAIChat 
              ? Colors.grey 
              : (aiEnabled && ollamaAvailable 
                  ? Colors.purple 
                  : Colors.orange),
          foregroundColor: Colors.white,
          child: _isOpeningAIChat
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
              : Stack(
                  alignment: Alignment.center,
                  children: [
                    const Icon(Icons.smart_toy),
                    if (isInstalling)
                      Positioned(
                        right: 0,
                        top: 0,
                        child: Container(
                          width: 12,
                          height: 12,
                          decoration: const BoxDecoration(
                            color: Colors.orange,
                            shape: BoxShape.circle,
                          ),
                          child: const Center(
                            child: SizedBox(
                              width: 8,
                              height: 8,
                              child: CircularProgressIndicator(
                                strokeWidth: 1.5,
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
          tooltip: isInstalling
              ? 'AI Assistant - Installing models...'
              : (aiEnabled && ollamaAvailable
                  ? 'Chat with AI Assistant'
                  : 'AI Assistant - Not ready'),
        ),
        SizedBox(height: spacing),
        // Search Users Button
        FloatingActionButton(
          heroTag: 'fab_search',
          onPressed: () {
            Navigator.pushNamed(context, '/search');
          },
          backgroundColor: Theme.of(context).colorScheme.primary,
          foregroundColor: Theme.of(context).colorScheme.onPrimary,
          child: const Icon(Icons.person_add),
          tooltip: 'Search Users',
        ),
      ],
    );
  }
}
