// =============================================================================
// CHAT SCREEN - UNIFIED FOR ALL PLATFORMS
// =============================================================================
// This screen displays individual chat conversations using MongoDB
// It handles message sending, media uploads, and real-time updates
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
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:characters/characters.dart';
import '../services/theme_service.dart';
import '../services/mongodb_chat_service.dart';
import '../services/logger_service.dart';
import '../services/physical_auth_service.dart';
import '../utils/group_chat_naming_utility.dart';
import '../widgets/enhanced_chat_input.dart';
import '../widgets/enhanced_media_preview.dart';
import '../widgets/full_screen_media_preview.dart';
import '../services/realtime_service.dart';
import '../services/active_chat_service.dart';
import '../services/message_sound_service.dart';
import '../theme/app_design_system.dart';
import '../config/database_config.dart';
import '../widgets/chat_media_gallery.dart';
import '../utils/responsive_utils.dart';
import '../utils/cairo_time_utils.dart';
import 'call_screen.dart';
import '../services/call_types.dart';
import '../services/webrtc_call_service.dart';
import '../services/local_auth_service.dart';
import '../main.dart'; // For ActiveCallTracker

class ChatScreenMongoDB extends StatefulWidget {
  final String chatId;
  final String chatName;
  final bool isGroupChat;
  final List<String>? userIds;

  const ChatScreenMongoDB({
    Key? key,
    required this.chatId,
    required this.chatName,
    this.isGroupChat = false,
    this.userIds,
  }) : super(key: key);

  @override
  State<ChatScreenMongoDB> createState() => _ChatScreenMongoDBState();
}

class _ChatScreenMongoDBState extends State<ChatScreenMongoDB> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final MongoDBChatService _chatService = MongoDBChatService();
  final PhysicalAuthService _authService = PhysicalAuthService();
  
  List<Map<String, dynamic>> _messages = [];
  bool _isLoading = false;
  bool _isSending = false;
  String? _currentUserId;
  String? _currentUserName;
  StreamSubscription? _messagesSubscription;
  Timer? _statusUpdateTimer;
  late ThemeService _themeService;
  final RealtimeService _realtime = RealtimeService.instance;
  final ActiveChatService _activeChat = ActiveChatService.instance;
  
  // Reply and reaction state
  Map<String, dynamic>? _replyingToMessage;
  final Map<String, Map<String, List<String>>> _messageReactions = {}; // messageId -> {emoji: [userId1, userId2]}
  bool _isProcessingMessageAction = false;
  
  // Offline reactions cache key (for web platform)
  String get _reactionsCacheKey => 'reactions_cache_${widget.chatId}';
  
  // User status for one-to-one chats
  bool? _otherUserIsOnline;
  DateTime? _otherUserLastSeen;
  String? _otherUserId;
  List<String>? _memberIds; // Store member IDs for status checking
  double _dynamicTitleFontSize(TextStyle baseStyle) {
    final baseSize = baseStyle.fontSize ?? 18.0;
    final nameLength = widget.chatName.characters.length;
    if (nameLength > 40) return baseSize * 0.72;
    if (nameLength > 30) return baseSize * 0.8;
    if (nameLength > 22) return baseSize * 0.9;
    return baseSize;
  }
  
  // Track previous message IDs for sound detection
  final Set<String> _previousMessageIds = {};
  
  String? _extractMessageId(Map<String, dynamic> m) {
    final id = m['_id'] ?? m['id'];
    return id?.toString();
  }

  String? _extractSenderId(Map<String, dynamic> m) {
    var v = m['senderId'] ?? m['sender_id'];
    if (v == null) {
      final s = m['sender'];
      if (s is Map) {
        v = s['id'] ?? s['_id'];
      } else if (s != null) {
        v = s.toString();
      }
    }
    return v?.toString();
  }

  Map<String, dynamic> _safeStringMap(dynamic value) {
    if (value is Map<String, dynamic>) {
      return value;
    }
    if (value is Map) {
      return value.map((key, val) => MapEntry(key.toString(), val));
    }
    return {};
  }

  String _extractSenderName(Map<String, dynamic> m) {
    var n = m['senderName'] ?? m['sender_name'];
    if (n == null) {
      final s = m['sender'];
      if (s is Map) {
        n = s['name'] ?? s['username'] ?? s['email'];
      }
    }
    
    // If no name found in message, try to get from cache
    if (n == null) {
      final senderId = _extractSenderId(m);
      if (senderId != null) {
        final cachedName = GroupChatNamingUtility.getCachedUserName(senderId);
        if (cachedName != null) {
          return cachedName;
        }
        // Fetch asynchronously for next time
        GroupChatNamingUtility.fetchUserNameAsync(senderId);
      }
    }
    
    return (n ?? 'Loading...').toString();
  }

  String _extractContent(Map<String, dynamic> m) {
    return (m['content'] ?? m['text'] ?? m['body'] ?? '').toString();
  }

  String _extractType(Map<String, dynamic> m) {
    return (m['messageType'] ?? m['type'] ?? 'text').toString();
  }

  String? _extractMediaUrl(Map<String, dynamic> m) {
    final url = m['mediaUrl'] ?? m['media_url'] ?? m['url'];
    return url?.toString();
  }

  DateTime _extractTimestamp(Map<String, dynamic> m) {
    final t = m['timestamp'] ?? m['createdAt'] ?? m['created_at'];
    if (t is String && t.isNotEmpty) {
      try {
        return DateTime.parse(t);
      } catch (_) {}
    } else if (t is int) {
      try {
        return DateTime.fromMillisecondsSinceEpoch(t);
      } catch (_) {}
    }
    return DateTime.now();
  }

  @override
  void initState() {
    super.initState();
    _themeService = ThemeService.instance;
    _themeService.addListener(() {
      if (mounted) setState(() {});
    });
    _initializeChat();
    _activeChat.setActiveChat(widget.chatId);
    
    // Determine other user ID for one-to-one chats
    if (!widget.isGroupChat && widget.userIds != null && widget.userIds!.length == 2) {
      // Will be set after we get current user ID
    }
  }

  @override
  void dispose() {
    _messagesSubscription?.cancel();
    _statusUpdateTimer?.cancel();
    _messageController.dispose();
    _scrollController.dispose();
    _realtime.leaveChat(widget.chatId);
    _activeChat.clearActiveChat(widget.chatId);
    super.dispose();
  }

  Future<void> _initializeChat() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Get current user info
      var user = await _authService.getCurrentUser();
      
      // If getCurrentUser returns null, try alternative methods
      if (user == null) {
        print('🔵 getCurrentUser returned null in chat screen, trying alternatives...');
        final userId = await LocalAuthService.getCurrentUserIdAsync();
        if (userId != null) {
          print('🔵 Found user ID via getCurrentUserIdAsync: $userId');
          user = {
            'id': userId,
            'name': 'User',
            'email': '',
          };
        } else {
          // Try getting from SharedPreferences directly
          final prefs = await SharedPreferences.getInstance();
          final userId = prefs.getString('user_id');
          if (userId != null) {
            print('🔵 Found user ID from SharedPreferences: $userId');
            user = {
              'id': userId,
              'name': prefs.getString('user_name') ?? 'User',
              'email': prefs.getString('user_email') ?? '',
            };
          }
        }
      }
      
      if (user != null) {
        _currentUserId = user['id'];
        _currentUserName = user['name'] ?? user['email'];
        
        // Determine other user ID for one-to-one chats
        // Try widget.userIds first, then fetch from chat details
        List<String>? memberIds = widget.userIds;
        if (memberIds == null || memberIds.isEmpty) {
          // Fetch chat details to get members
          final chatDetails = await _chatService.getChatDetails(widget.chatId);
          if (chatDetails != null) {
            final chat = chatDetails['chat'] ?? chatDetails;
            final members = chat['members'];
            if (members is List) {
              memberIds = members.map((m) => m.toString()).toList();
            }
          }
        }
        
        // Store member IDs for later use in status checking
        _memberIds = memberIds;
        
        if (!widget.isGroupChat && memberIds != null && memberIds.length == 2) {
          _otherUserId = memberIds.firstWhere(
            (id) => id.toString() != _currentUserId.toString(),
            orElse: () => '',
          );
          if (_otherUserId != null && _otherUserId!.isNotEmpty) {
            // Fetch initial user status
            await _updateUserStatus();
            // Start periodic status updates
            _startStatusUpdates();
          }
        }
      }

      // Load cached reactions from local storage (for offline support on web)
      if (kIsWeb) {
        await _loadCachedReactions();
      }

      // Load initial messages
      await _loadMessages();

      // Start listening for new messages
      _startMessageListener();

      // Realtime: connect and join chat room, update on incoming events
      await _realtime.connect();
      _realtime.joinChat(widget.chatId);
      _realtime.onNewMessage((msg) {
        final chatId = (msg['chatId'] ?? msg['chat_id'] ?? '').toString();
        if (chatId == widget.chatId) {
          // Add the new message directly to the list to preserve reply info
          final messageId = (msg['id'] ?? msg['_id'] ?? '').toString();
          if (messageId.isNotEmpty) {
            setState(() {
              // Check if message already exists
              final existingIndex = _messages.indexWhere((m) => _extractMessageId(m) == messageId);
              if (existingIndex == -1) {
                // Add new message with all fields including reply info
                _messages.add({
                  'id': messageId,
                  '_id': messageId,
                  'chatId': chatId,
                  'senderId': msg['senderId'] ?? msg['sender_id'],
                  'senderName': msg['senderName'] ?? msg['sender_name'],
                  'content': msg['content'] ?? '',
                  'messageType': msg['messageType'] ?? msg['type'] ?? 'text',
                  'mediaUrl': msg['mediaUrl'] ?? msg['media_url'],
                  'createdAt': msg['createdAt'] ?? msg['created_at'],
                  'replyTo': msg['replyTo'] ?? msg['reply_to'],
                  'replyToContent': msg['replyToContent'] ?? msg['reply_to_content'],
                  'replyToSenderName': msg['replyToSenderName'] ?? msg['reply_to_sender_name'],
                  'readBy': msg['readBy'] ?? msg['read_by'] ?? [],
                  'status': msg['status'] ?? 'sent',
                  'reactions': msg['reactions'] ?? {},
                });
                // Sort messages by timestamp
                _messages.sort((a, b) {
                  final aTime = _extractTimestamp(a);
                  final bTime = _extractTimestamp(b);
                  if (aTime == null || bTime == null) return 0;
                  return aTime.compareTo(bTime);
                });
              } else {
                // Update existing message with latest data (preserve reply info)
                _messages[existingIndex] = {
                  ..._messages[existingIndex],
                  'content': msg['content'] ?? _messages[existingIndex]['content'],
                  'replyTo': msg['replyTo'] ?? msg['reply_to'] ?? _messages[existingIndex]['replyTo'],
                  'replyToContent': msg['replyToContent'] ?? msg['reply_to_content'] ?? _messages[existingIndex]['replyToContent'],
                  'replyToSenderName': msg['replyToSenderName'] ?? msg['reply_to_sender_name'] ?? _messages[existingIndex]['replyToSenderName'],
                  'reactions': msg['reactions'] ?? _messages[existingIndex]['reactions'] ?? {},
                };
              }
            });
            // Also reload to ensure consistency
            _loadMessages();
          } else {
            // Fallback to full reload if message ID is missing
            _loadMessages();
          }
        }
      });
      
      // Listen for message reactions
      _realtime.onMessageReaction((data) {
        final messageId = data['messageId']?.toString();
        if (messageId != null) {
          final reactions = _safeStringMap(data['reactions']);
          setState(() {
            // Update reactions map
            _messageReactions[messageId] = Map<String, List<String>>.from(
              reactions.map((key, value) => MapEntry(
                key,
                List<String>.from(value as List? ?? []),
              )),
            );
            // Also update the message in _messages array to ensure reactions are visible immediately
            final messageIndex = _messages.indexWhere((m) => _extractMessageId(m) == messageId);
            if (messageIndex != -1) {
              _messages[messageIndex] = {
                ..._messages[messageIndex],
                'reactions': reactions,
              };
            }
          });
          // Save reactions to cache (for offline support on web)
          if (kIsWeb) {
            _saveReactionsToCache();
          }
          // Don't reload messages here - the state update above is sufficient
          // Reloading would cause flickering and might overwrite the reactions
        }
      });

      _realtime.onMessageUpdated((data) {
        final chatId = (data['chatId'] ?? data['chat_id'] ?? '').toString();
        if (chatId != widget.chatId) return;
        final messageId = (data['id'] ?? data['_id'] ?? data['messageId'])?.toString();
        if (messageId == null) return;
        if (!mounted) return;

        setState(() {
          final index = _messages.indexWhere((m) => _extractMessageId(m) == messageId);
          final normalized = {
            ...data,
            'id': messageId,
            '_id': messageId,
            'chatId': chatId,
          };
          if (index != -1) {
            _messages[index] = {
              ..._messages[index],
              ...normalized,
            };
          }
        });
      });

      _realtime.onMessageDeleted((data) {
        final chatId = (data['chatId'] ?? data['chat_id'] ?? '').toString();
        if (chatId != widget.chatId) return;
        final messageId = (data['id'] ?? data['messageId'])?.toString();
        if (messageId == null) return;
        final scope = (data['scope'] ?? 'everyone').toString();
        if (scope != 'everyone' || !mounted) return;

        setState(() {
          final index = _messages.indexWhere((m) => _extractMessageId(m) == messageId);
          if (index != -1) {
            _messages[index] = {
              ..._messages[index],
              'content': '',
              'mediaUrl': '',
              'isDeletedForEveryone': true,
              'deletedAt': data['deletedAt'] ?? DateTime.now().toIso8601String(),
              'deletedBy': data['deletedBy'] ?? '',
            };
          }
        });
      });

      // NOTE: Call invitations are handled by the global listener in main.dart
      // This local listener has been REMOVED to prevent duplicate call screens
      // The global listener in main.dart handles all call invitations and uses ActiveCallTracker to prevent duplicates
      // No need to register a listener here - it would be redundant and could cause race conditions
    } catch (e) {
      Log.e('Error initializing chat', 'CHAT_SCREEN_MONGODB', e);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading chat: $e')),
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

  Future<void> _loadMessages() async {
    // Validate chat ID before making API call
    if (widget.chatId.isEmpty) {
      Log.e('Cannot load messages: chat ID is empty', 'CHAT_SCREEN_MONGODB');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error: Invalid chat ID')),
        );
      }
      return;
    }
    
    try {
      Log.i('Loading messages for chat ID: ${widget.chatId}', 'CHAT_SCREEN_MONGODB');
      final messages = await _chatService.getChatMessages(widget.chatId);
      if (mounted) {
        setState(() {
          _messages = messages;
        });
        
        // Preload user names for group chats
        if (widget.isGroupChat && _currentUserId != null) {
          final userIds = messages
              .map((m) => _extractSenderId(m))
              .whereType<String>()
              .where((id) => id != _currentUserId)
              .toSet()
              .toList();
          if (userIds.isNotEmpty) {
            await GroupChatNamingUtility.preloadUserNames(userIds);
            setState(() {
              // Trigger rebuild to show updated names
            });
          }
        }
        
        // Extract and merge reactions from messages
        // Server reactions take precedence, but we merge with cached reactions for offline support
        for (final message in messages) {
          final messageId = _extractMessageId(message);
          if (messageId != null) {
            final serverReactions = _safeStringMap(message['reactions']);
            if (serverReactions.isNotEmpty) {
              // Server has reactions, use them
              _messageReactions[messageId] = Map<String, List<String>>.from(
                serverReactions.map((key, value) => MapEntry(
                  key,
                  List<String>.from(value as List? ?? []),
                )),
              );
            } else if (kIsWeb && _messageReactions[messageId] == null) {
              // No server reactions, but we might have cached reactions
              // They should already be loaded from _loadCachedReactions
            }
          }
        }
        
        // Save updated reactions to cache (for offline support on web)
        if (kIsWeb) {
          _saveReactionsToCache();
        }
        
        // Mark messages as read for those not sent by current user
        await _markMessagesAsRead(_messages);
        
        // Reset unread count for this chat when opened
        await _resetUnreadCount();
        
        _scrollToBottom(force: true); // Force scroll on initial load
      }
    } catch (e) {
      Log.e('Error loading messages', 'CHAT_SCREEN_MONGODB', e);
      // On error, still try to use cached reactions if available (offline mode)
      if (kIsWeb && _messageReactions.isNotEmpty) {
        Log.i('Using cached reactions due to network error', 'CHAT_SCREEN_MONGODB');
        if (mounted) {
          setState(() {
            // Reactions are already loaded from cache, just trigger rebuild
          });
        }
      }
    }
  }

  /// Load cached reactions from local storage (for offline support on web)
  Future<void> _loadCachedReactions() async {
    if (!kIsWeb) return;
    
    try {
      final prefs = await SharedPreferences.getInstance();
      final cachedJson = prefs.getString(_reactionsCacheKey);
      
      if (cachedJson != null) {
        final cached = json.decode(cachedJson) as Map<String, dynamic>;
        setState(() {
          _messageReactions.clear();
          cached.forEach((messageId, reactionsData) {
            if (reactionsData is Map) {
              _messageReactions[messageId] = Map<String, List<String>>.from(
                (reactionsData as Map).map((key, value) => MapEntry(
                  key.toString(),
                  List<String>.from((value as List?)?.map((e) => e.toString()) ?? []),
                )),
              );
            }
          });
        });
        Log.i('Loaded ${_messageReactions.length} cached reactions for chat ${widget.chatId}', 'CHAT_SCREEN_MONGODB');
      }
    } catch (e) {
      Log.e('Error loading cached reactions', 'CHAT_SCREEN_MONGODB', e);
    }
  }

  /// Save reactions to local storage (for offline support on web)
  Future<void> _saveReactionsToCache() async {
    if (!kIsWeb) return;
    
    try {
      final prefs = await SharedPreferences.getInstance();
      final reactionsJson = json.encode(
        _messageReactions.map((messageId, reactions) => MapEntry(
          messageId,
          reactions.map((emoji, userIds) => MapEntry(emoji, userIds)),
        )),
      );
      await prefs.setString(_reactionsCacheKey, reactionsJson);
      Log.d('Saved ${_messageReactions.length} reactions to cache for chat ${widget.chatId}', 'CHAT_SCREEN_MONGODB');
    } catch (e) {
      Log.e('Error saving reactions to cache', 'CHAT_SCREEN_MONGODB', e);
    }
  }

  void _startMessageListener() {
    // Initialize previous message IDs from current messages
    _previousMessageIds.clear();
    _previousMessageIds.addAll(_messages.map((m) => _extractMessageId(m)).whereType<String>());
    
    _messagesSubscription = _chatService.watchChatMessages(widget.chatId).listen(
      (messages) {
        if (mounted) {
          // Check if user is near bottom before updating
          final wasNearBottom = _scrollController.hasClients
              ? (_scrollController.position.maxScrollExtent - 
                 _scrollController.position.pixels) <= 200.0
              : true;
          
          // Check if there are NEW messages from other users (for sound notification)
          // Compare BEFORE updating state
          final hasNewMessagesFromOthers = messages.any((m) {
            final messageId = _extractMessageId(m);
            final senderId = _extractSenderId(m);
            final isNew = messageId != null && !_previousMessageIds.contains(messageId);
            final isFromOthers = senderId != null && senderId.toString() != _currentUserId?.toString();
            return isNew && isFromOthers;
          });
          
          // Update previous message IDs for next check
          _previousMessageIds.clear();
          _previousMessageIds.addAll(messages.map((m) => _extractMessageId(m)).whereType<String>());
          
          setState(() {
            _messages = messages;
          });
          
          // Extract and update reactions from messages (for offline support)
          for (final message in messages) {
            final messageId = _extractMessageId(message);
            if (messageId != null) {
              final serverReactions = _safeStringMap(message['reactions']);
              if (serverReactions.isNotEmpty) {
                _messageReactions[messageId] = Map<String, List<String>>.from(
                  serverReactions.map((key, value) => MapEntry(
                    key,
                    List<String>.from(value as List? ?? []),
                  )),
                );
              }
            }
          }
          
          // Save reactions to cache (for offline support on web)
          if (kIsWeb) {
            _saveReactionsToCache();
          }
          
          // Play sound for new messages from others
          if (hasNewMessagesFromOthers && _currentUserId != null) {
            Log.i('🔊 New message detected, playing sound...', 'CHAT_SCREEN_MONGODB');
            MessageSoundService().playMessageSound();
          }
          
          // Mark incoming messages as read when viewing the chat
          _markMessagesAsRead(_messages);
          
          // Only auto-scroll if user was already near the bottom
          // This prevents interrupting users who are scrolling up to read old messages
          if (wasNearBottom) {
            _scrollToBottom();
          }
        }
      },
      onError: (error) {
        Log.e('Error in message stream', 'CHAT_SCREEN_MONGODB', error);
      },
    );
  }

  Future<void> _markMessagesAsRead(List<Map<String, dynamic>> messages) async {
    try {
      if (_currentUserId == null || messages.isEmpty) return;
      
      // Get unread messages (sent by others, not already read by current user)
      final unreadMessages = messages.where((m) {
        final senderId = _extractSenderId(m);
        final readBy = _extractReadBy(m);
        final isFromOthers = senderId != null && senderId.toString() != _currentUserId.toString();
        final alreadyRead = readBy.any((id) => id.toString() == _currentUserId.toString());
        return isFromOthers && !alreadyRead;
      }).toList();
      
      if (unreadMessages.isEmpty) return;
      
      final messageIds = unreadMessages
          .map((m) => _extractMessageId(m))
          .whereType<String>()
          .toList();
      
      if (messageIds.isEmpty) return;
      
      await _chatService.markMessagesAsRead(widget.chatId, messageIds);
      
      // Reload messages to get updated readBy status
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) {
          _loadMessages();
        }
      });
    } catch (e) {
      Log.e('Error marking messages as read', 'CHAT_SCREEN_MONGODB', e);
    }
  }

  Future<void> _resetUnreadCount() async {
    try {
      if (_currentUserId == null) return;
      
      // Call API to reset unread count for this chat
      final token = await _authService.getAuthToken();
      if (token == null) return;
      
      final baseUrl = DatabaseConfig.physicalServerUrl;
      final response = await http.patch(
        Uri.parse('$baseUrl/api/chats/${widget.chatId}/read'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
          'ngrok-skip-browser-warning': 'true',
        },
        body: json.encode({}), // Server gets userId from auth token
      );
      
      if (response.statusCode == 200) {
        Log.i('✅ Unread count reset for chat ${widget.chatId}', 'CHAT_SCREEN_MONGODB');
      } else {
        Log.w('⚠️ Failed to reset unread count: ${response.statusCode}', 'CHAT_SCREEN_MONGODB');
      }
    } catch (e) {
      Log.e('Error resetting unread count', 'CHAT_SCREEN_MONGODB', e);
    }
  }

  void _scrollToBottom({bool force = false}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        final position = _scrollController.position;
        final maxScroll = position.maxScrollExtent;
        final currentScroll = position.pixels;
        final scrollThreshold = 200.0; // 200px threshold
        
        // Only scroll to bottom if:
        // 1. Forced (e.g., on initial load or user sends a message)
        // 2. User is already near the bottom (within threshold)
        final isNearBottom = (maxScroll - currentScroll) <= scrollThreshold;
        
        if (force || isNearBottom) {
          _scrollController.animateTo(
            maxScroll,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      }
    });
  }

  Future<void> _sendMessage(String content) async {
    if (content.isEmpty || _isSending) return;
    
    // Validate chat ID before sending message
    if (widget.chatId.isEmpty) {
      Log.e('Cannot send message: chat ID is empty', 'CHAT_SCREEN_MONGODB');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error: Invalid chat ID')),
        );
      }
      return;
    }

    setState(() {
      _isSending = true;
    });

    try {
      Log.i('Sending message to chat ID: ${widget.chatId}', 'CHAT_SCREEN_MONGODB');
      
      // Check if this is a reply
      if (_replyingToMessage != null) {
        final messageId = _extractMessageId(_replyingToMessage!);
        if (messageId != null) {
          final result = await _chatService.replyToMessage(messageId, content);
          if (result != null) {
            _messageController.clear();
            setState(() {
              _replyingToMessage = null;
            });
            _scrollToBottom(force: true);
            await _loadMessages(); // Reload to show the reply
            return;
          }
        }
      }
      
      // Regular message
      final result = await _chatService.sendTextMessage(widget.chatId, content);
      if (result != null) {
        _messageController.clear();
        setState(() {
          _replyingToMessage = null;
        });
        // Force scroll to bottom when user sends their own message
        _scrollToBottom(force: true);
        // Message will be added via the stream listener
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to send message')),
          );
        }
      }
    } catch (e) {
      Log.e('Error sending message', 'CHAT_SCREEN_MONGODB', e);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error sending message: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSending = false;
        });
      }
    }
  }

  /// Reply to a message
  Future<void> _replyToMessage(Map<String, dynamic> message) async {
    setState(() {
      _replyingToMessage = message;
    });
    // Focus on message input
    _messageController.selection = TextSelection.fromPosition(
      TextPosition(offset: _messageController.text.length),
    );
  }

  /// Start a call (voice or video)
  Future<void> _startCall(CallType callType) async {
    try {
      print('🔵 _startCall called with type: $callType');
      Log.i('🔵 _startCall called with type: $callType', 'CHAT_SCREEN_MONGODB');
      
      if (_currentUserId == null || _currentUserName == null) {
        print('❌ User information not available');
        Log.e('User information not available', 'CHAT_SCREEN_MONGODB');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('User information not available')),
        );
        return;
      }

      // Get participant information
      List<String> participantIds = widget.userIds ?? [];

      if (participantIds.isEmpty && _memberIds != null) {
        participantIds = _memberIds!.where((id) => id != _currentUserId).toList();
      }

      // If still empty, try to get from chat members
      if (participantIds.isEmpty && widget.isGroupChat && _memberIds != null) {
        participantIds = _memberIds!.where((id) => id != _currentUserId).toList();
      }

      // For individual chats, get the other user's ID
      if (participantIds.isEmpty && !widget.isGroupChat) {
        if (widget.userIds != null && widget.userIds!.isNotEmpty) {
          participantIds = widget.userIds!.where((id) => id != _currentUserId).toList();
        } else if (_memberIds != null && _memberIds!.isNotEmpty) {
          participantIds = _memberIds!.where((id) => id != _currentUserId).toList();
        }
      }

      print('🔵 Starting call - Participant IDs: ${participantIds.join(", ")}');
      Log.i('Starting call - Participant IDs: ${participantIds.join(", ")}', 'CHAT_SCREEN_MONGODB');

      if (participantIds.isEmpty) {
        print('❌ No participants found for call');
        Log.e('No participants found for call', 'CHAT_SCREEN_MONGODB');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No participants found. Cannot start call.')),
          );
        }
        return;
      }

      // Get participant names if available
      List<String> participantNames = [];
      if (participantIds.isNotEmpty) {
        participantNames = List.filled(participantIds.length, 'User');
      }

      print('🔵 Navigating to call screen with ${participantIds.length} participants');
      Log.i('📞 Navigating to call screen with ${participantIds.length} participants', 'CHAT_SCREEN_MONGODB');
      
      try {
      // Navigate to call screen
        print('🔵 About to push CallScreen route');
        final result = await Navigator.of(context).push(
        MaterialPageRoute(
            builder: (context) {
              print('🔵 Building CallScreen widget');
              return CallScreen(
            chatId: widget.chatId,
            chatName: widget.chatName,
            isGroupChat: widget.isGroupChat,
            participantIds: participantIds,
            participantNames: participantNames,
            callType: callType,
                direction: CallDirection.outgoing,
              );
            },
          ),
        );
        print('🔵 Call screen closed, result: $result');
        Log.i('📞 Call screen closed', 'CHAT_SCREEN_MONGODB');
      } catch (e, stackTrace) {
        print('❌ Error navigating to call screen: $e');
        print('❌ Stack trace: $stackTrace');
        Log.e('Error navigating to call screen', 'CHAT_SCREEN_MONGODB', e, stackTrace);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error starting call: $e')),
      );
        }
      }
    } catch (e, stackTrace) {
      Log.e('Error starting call: $e', 'CHAT_SCREEN_MONGODB', e);
      Log.e('Stack trace: $stackTrace', 'CHAT_SCREEN_MONGODB');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to start call: $e')),
        );
      }
    }
  }

  /// React to a message
  Future<void> _reactToMessage(String messageId, String emoji) async {
    try {
      final result = await _chatService.reactToMessage(messageId, emoji);
      if (result != null) {
        // Update local reactions cache immediately
        final reactions = _safeStringMap(result['reactions']);
        setState(() {
          _messageReactions[messageId] = Map<String, List<String>>.from(
            reactions.map((key, value) => MapEntry(
              key,
              List<String>.from(value as List? ?? []),
            )),
          );
          // Also update the message in _messages array immediately
          final messageIndex = _messages.indexWhere((m) => _extractMessageId(m) == messageId);
          if (messageIndex != -1) {
            _messages[messageIndex] = {
              ..._messages[messageIndex],
              'reactions': reactions,
            };
          }
        });
        // Save reactions to cache (for offline support on web)
        if (kIsWeb) {
          _saveReactionsToCache();
        }
        // Don't reload messages - the socket will notify other users
        // and the state update above is sufficient for the current user
      }
    } catch (e) {
      Log.e('Error reacting to message', 'CHAT_SCREEN_MONGODB', e);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to react: $e')),
        );
      }
    }
  }

  /// Show reaction picker
  void _showReactionPicker(String messageId) {
    final commonEmojis = ['👍', '❤️', '😂', '😮', '😢', '🙏', '🔥', '👏'];
    
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Wrap(
          spacing: 16,
          runSpacing: 16,
          alignment: WrapAlignment.center,
          children: commonEmojis.map((emoji) {
            return InkWell(
              onTap: () {
                Navigator.pop(context);
                _reactToMessage(messageId, emoji);
              },
              child: Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceVariant,
                  borderRadius: BorderRadius.circular(25),
                ),
                child: Center(
                  child: Text(
                    emoji,
                    style: const TextStyle(fontSize: 28),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  bool _isMessageDeletedForEveryone(Map<String, dynamic> message) {
    return message['isDeletedForEveryone'] == true ||
        message['deletedForEveryone'] == true ||
        message['status'] == 'deleted_for_everyone';
  }

  Future<void> _deleteMessageForSelf(Map<String, dynamic> message) async {
    final messageId = _extractMessageId(message);
    if (messageId == null) return;
    if (_isProcessingMessageAction) return;

    setState(() {
      _isProcessingMessageAction = true;
    });

    try {
      final success = await _chatService.deleteMessage(
        widget.chatId,
        messageId,
        deleteForEveryone: false,
      );
      if (success && mounted) {
        setState(() {
          _messages.removeWhere((m) => _extractMessageId(m) == messageId);
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Message removed for you')),
        );
      }
    } catch (e) {
      Log.e('Delete message (self) failed', 'CHAT_SCREEN_MONGODB', e);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to delete message: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isProcessingMessageAction = false;
        });
      }
    }
  }

  Future<void> _deleteMessageForEveryone(Map<String, dynamic> message) async {
    final messageId = _extractMessageId(message);
    if (messageId == null) return;
    if (_isProcessingMessageAction) return;

    setState(() {
      _isProcessingMessageAction = true;
    });

    try {
      final success = await _chatService.deleteMessage(
        widget.chatId,
        messageId,
        deleteForEveryone: true,
      );
      if (success && mounted) {
        setState(() {
          final index = _messages.indexWhere((m) => _extractMessageId(m) == messageId);
          if (index != -1) {
            _messages[index] = {
              ..._messages[index],
              'content': '',
              'mediaUrl': '',
              'isDeletedForEveryone': true,
              'deletedAt': DateTime.now().toIso8601String(),
              'deletedBy': _currentUserId,
            };
          }
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Message deleted for everyone')),
        );
      }
    } catch (e) {
      Log.e('Delete message (everyone) failed', 'CHAT_SCREEN_MONGODB', e);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to delete message: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isProcessingMessageAction = false;
        });
      }
    }
  }

  void _showEditMessageDialog(Map<String, dynamic> message) {
    final messageId = _extractMessageId(message);
    if (messageId == null) return;
    final controller = TextEditingController(text: _extractContent(message));

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit message'),
        content: TextField(
          controller: controller,
          minLines: 1,
          maxLines: 5,
          decoration: const InputDecoration(
            hintText: 'Update your message',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final newContent = controller.text.trim();
              if (newContent.isEmpty) return;
              Navigator.pop(context);
              setState(() {
                _isProcessingMessageAction = true;
              });
              try {
                final success = await _chatService.updateMessage(
                  widget.chatId,
                  messageId,
                  newContent,
                );
                if (success && mounted) {
                  setState(() {
                    final index = _messages.indexWhere((m) => _extractMessageId(m) == messageId);
                    if (index != -1) {
                      _messages[index] = {
                        ..._messages[index],
                        'content': newContent,
                        'edited': true,
                        'updatedAt': DateTime.now().toIso8601String(),
                      };
                    }
                  });
                }
              } catch (e) {
                Log.e('Edit message failed', 'CHAT_SCREEN_MONGODB', e);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Failed to edit message: $e')),
                  );
                }
              } finally {
                if (mounted) {
                  setState(() {
                    _isProcessingMessageAction = false;
                  });
                }
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteChatForMe() async {
    if (_isProcessingMessageAction) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete chat for me?'),
        content: const Text('This will remove the conversation from your chat list. Others will still see it.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    setState(() {
      _isProcessingMessageAction = true;
    });

    try {
      final success = await _chatService.hideChat(widget.chatId, hide: true);
      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Chat deleted for you')),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      Log.e('Delete chat failed', 'CHAT_SCREEN_MONGODB', e);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to delete chat: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isProcessingMessageAction = false;
        });
      }
    }
  }

  /// Show message options menu
  void _showMessageOptions(Map<String, dynamic> message) {
    final messageId = _extractMessageId(message);
    if (messageId == null) return;
    final senderId = _extractSenderId(message);
    final isCurrentUser = senderId == _currentUserId;
    final isDeleted = _isMessageDeletedForEveryone(message);
    final messageType = _extractType(message);

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.reply),
              title: const Text('Reply'),
              onTap: () {
                Navigator.pop(context);
                _replyToMessage(message);
              },
            ),
            ListTile(
              leading: const Icon(Icons.add_reaction),
              title: const Text('Add Reaction'),
              onTap: () {
                Navigator.pop(context);
                _showReactionPicker(messageId);
              },
            ),
            if (!isDeleted && isCurrentUser && messageType == 'text')
              ListTile(
                leading: const Icon(Icons.edit),
                title: const Text('Edit message'),
                onTap: () {
                  Navigator.pop(context);
                  _showEditMessageDialog(message);
                },
              ),
            if (message['replies'] != null && (message['replies'] as List).isNotEmpty)
              ListTile(
                leading: const Icon(Icons.chat_bubble_outline),
                title: Text('View Replies (${(message['replies'] as List).length})'),
                onTap: () {
                  Navigator.pop(context);
                  _showReplies(messageId);
                },
              ),
            ListTile(
              leading: const Icon(Icons.delete_outline),
              title: const Text('Delete for me'),
              onTap: () {
                Navigator.pop(context);
                _deleteMessageForSelf(message);
              },
            ),
            if (isCurrentUser && !isDeleted)
              ListTile(
                leading: const Icon(Icons.delete_forever),
                title: const Text('Delete for everyone'),
                onTap: () async {
                  Navigator.pop(context);
                  final confirm = await showDialog<bool>(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text('Delete for everyone?'),
                      content: const Text('This will remove the message for all participants.'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context, false),
                          child: const Text('Cancel'),
                        ),
                        ElevatedButton(
                          onPressed: () => Navigator.pop(context, true),
                          child: const Text('Delete'),
                        ),
                      ],
                    ),
                  );
                  if (confirm == true) {
                    _deleteMessageForEveryone(message);
                  }
                },
              ),
          ],
        ),
      ),
    );
  }

  /// Show replies for a message
  void _showReplies(String messageId) async {
    try {
      final replies = await _chatService.getMessageReplies(messageId);
      if (!mounted) return;

      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        builder: (context) => DraggableScrollableSheet(
          initialChildSize: 0.7,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          expand: false,
          builder: (context, scrollController) => Column(
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: Theme.of(context).dividerColor,
                      width: 1,
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    const Text(
                      'Replies',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: replies.isEmpty
                    ? Center(
                        child: Text(
                          'No replies yet',
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                        ),
                      )
                    : ListView.builder(
                        controller: scrollController,
                        padding: const EdgeInsets.all(16),
                        itemCount: replies.length,
                        itemBuilder: (context, index) {
                          final reply = replies[index];
                          return _buildReplyBubble(reply);
                        },
                      ),
              ),
            ],
          ),
        ),
      );
    } catch (e) {
      Log.e('Error showing replies', 'CHAT_SCREEN_MONGODB', e);
    }
  }

  /// Build reply bubble widget
  Widget _buildReplyBubble(Map<String, dynamic> reply) {
    final senderId = reply['senderId']?.toString();
    final isCurrentUser = senderId == _currentUserId;
    final content = reply['content']?.toString() ?? '';
    final senderName = reply['senderName']?.toString() ?? 'Unknown';
    final timestamp = reply['createdAt'];

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment:
            isCurrentUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isCurrentUser) ...[
            CircleAvatar(
              radius: 16,
              backgroundColor: Theme.of(context).colorScheme.primary,
              child: Text(
                senderName.isNotEmpty ? senderName[0].toUpperCase() : 'U',
                style: const TextStyle(fontSize: 12, color: Colors.white),
              ),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: isCurrentUser
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(context).colorScheme.surfaceVariant,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (!isCurrentUser)
                    Text(
                      senderName,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: isCurrentUser
                            ? Theme.of(context).colorScheme.onPrimary.withOpacity(0.7)
                            : Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  Text(
                    content,
                    style: TextStyle(
                      color: isCurrentUser
                          ? Theme.of(context).colorScheme.onPrimary
                          : Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (isCurrentUser) ...[
            const SizedBox(width: 8),
            CircleAvatar(
              radius: 16,
              backgroundColor: Theme.of(context).colorScheme.primary,
              child: Text(
                _currentUserName?.isNotEmpty == true
                    ? _currentUserName![0].toUpperCase()
                    : 'U',
                style: const TextStyle(fontSize: 12, color: Colors.white),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _sendMediaMessage(String mediaUrl, String messageType, {String? content}) async {
    print('[CHAT_SCREEN_MONGODB] _sendMediaMessage called with mediaUrl: $mediaUrl, type: $messageType');
    
    if (_isSending) {
      print('[CHAT_SCREEN_MONGODB] Already sending media, returning...');
      return;
    }

    setState(() {
      _isSending = true;
    });

    try {
      print('[CHAT_SCREEN_MONGODB] Calling _chatService.sendMediaMessage...');
      final result = await _chatService.sendMediaMessage(
        widget.chatId,
        mediaUrl,
        messageType,
        content: (content != null && content.isNotEmpty) ? content : null,
      );
      print('[CHAT_SCREEN_MONGODB] sendMediaMessage result: ${result != null ? "success" : "null"}');
      if (result != null) {
        print('[CHAT_SCREEN_MONGODB] Media message sent successfully, scrolling to bottom...');
        // Force scroll to bottom when user sends their own media
        _scrollToBottom(force: true);
        // Message will be added via the stream listener
      } else {
        print('[CHAT_SCREEN_MONGODB] ERROR: sendMediaMessage returned null');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to send media')),
          );
        }
      }
    } catch (e, stackTrace) {
      Log.e('Error sending media', 'CHAT_SCREEN_MONGODB', e);
      print('[CHAT_SCREEN_MONGODB] Error sending media: $e');
      print('[CHAT_SCREEN_MONGODB] Stack trace: $stackTrace');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error sending media: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSending = false;
        });
        print('[CHAT_SCREEN_MONGODB] _isSending set to false');
      }
    }
  }

  Future<void> _sendVoiceMessage(Uint8List audioBytes, String mimeType, String content) async {
    print('[CHAT_SCREEN_MONGODB] _sendVoiceMessage called with ${audioBytes.length} bytes, mimeType: $mimeType');
    
    if (_isSending) {
      print('[CHAT_SCREEN_MONGODB] Already sending, returning...');
      return;
    }

    try {
      Log.i('Starting voice message upload, size: ${audioBytes.length} bytes, mimeType: $mimeType', 'CHAT_SCREEN_MONGODB');
      print('[CHAT_SCREEN_MONGODB] Starting voice message upload...');
      
      // Upload voice message first
      final baseUrl = DatabaseConfig.physicalServerUrl;
      final token = await DatabaseConfig.getStoredAuthToken();
      
      Log.i('Uploading to: $baseUrl/api/media/upload', 'CHAT_SCREEN_MONGODB');
      print('[CHAT_SCREEN_MONGODB] Uploading to: $baseUrl/api/media/upload');
      
      final dio = Dio(BaseOptions(
        baseUrl: baseUrl,
        headers: {
          if (token.isNotEmpty) 'Authorization': 'Bearer $token',
          'ngrok-skip-browser-warning': 'true',
        },
        connectTimeout: const Duration(seconds: 30),
        receiveTimeout: const Duration(seconds: 120),
        sendTimeout: const Duration(seconds: 120),
      ));

      // Determine file extension from mimeType
      String extension = 'm4a';
      if (mimeType.contains('webm')) {
        extension = 'webm';
      } else if (mimeType.contains('wav')) {
        extension = 'wav';
      } else if (mimeType.contains('mp3')) {
        extension = 'mp3';
      } else if (mimeType.contains('aac')) {
        extension = 'aac';
      }
      
      final fileName = 'voice_message_${DateTime.now().millisecondsSinceEpoch}.$extension';
      
      Log.i('Creating form data with fileName: $fileName, chatId: ${widget.chatId}', 'CHAT_SCREEN_MONGODB');
      print('[CHAT_SCREEN_MONGODB] Creating form data with fileName: $fileName');
      
      final formData = FormData.fromMap({
        'chatId': widget.chatId,
        'type': 'voice',
        'file': MultipartFile.fromBytes(
          audioBytes,
          filename: fileName,
        ),
        if (content.isNotEmpty) 'caption': content,
      });

      Log.i('Sending upload request...', 'CHAT_SCREEN_MONGODB');
      print('[CHAT_SCREEN_MONGODB] Sending upload request...');
      
      final response = await dio.post(
        '/api/media/upload',
        data: formData,
        onSendProgress: (sent, total) {
          if (total > 0) {
            final progress = (sent / total * 100).toStringAsFixed(1);
            Log.i('Upload progress: $progress%', 'CHAT_SCREEN_MONGODB');
            print('[CHAT_SCREEN_MONGODB] Upload progress: $progress%');
          }
        },
      );

      Log.i('Upload response: status=${response.statusCode}, data=${response.data}', 'CHAT_SCREEN_MONGODB');
      print('[CHAT_SCREEN_MONGODB] Upload response: status=${response.statusCode}');

      if (response.statusCode == 201 || response.statusCode == 200) {
        dynamic responseData = response.data;
        if (responseData is Map) {
          final mediaUrl = responseData['mediaUrl'] as String?;
          if (mediaUrl != null && mediaUrl.isNotEmpty) {
            Log.i('Upload successful, mediaUrl: $mediaUrl', 'CHAT_SCREEN_MONGODB');
            print('[CHAT_SCREEN_MONGODB] Upload successful! mediaUrl: $mediaUrl');
            print('[CHAT_SCREEN_MONGODB] Calling _sendMediaMessage...');
            // Send the voice message - don't set _isSending here, let _sendMediaMessage handle it
            await _sendMediaMessage(mediaUrl, 'voice', content: content);
            print('[CHAT_SCREEN_MONGODB] _sendMediaMessage completed');
          } else {
            Log.e('No media URL in response', 'CHAT_SCREEN_MONGODB', null);
            print('[CHAT_SCREEN_MONGODB] ERROR: No media URL in response: ${response.data}');
            throw Exception('No media URL returned from upload. Response: ${response.data}');
          }
        } else {
          Log.e('Invalid response format', 'CHAT_SCREEN_MONGODB', null);
          print('[CHAT_SCREEN_MONGODB] ERROR: Invalid response format: ${response.data}');
          throw Exception('Invalid response format: ${response.data}');
        }
      } else {
        Log.e('Upload failed with status code', 'CHAT_SCREEN_MONGODB', null);
        print('[CHAT_SCREEN_MONGODB] ERROR: Upload failed with status ${response.statusCode}');
        throw Exception('Upload failed: Status ${response.statusCode}, Response: ${response.data}');
      }
    } on DioException catch (e) {
      Log.e('DioException sending voice message', 'CHAT_SCREEN_MONGODB', e);
      print('[CHAT_SCREEN_MONGODB] DioException: ${e.message}');
      if (e.response != null) {
        print('[CHAT_SCREEN_MONGODB] Response status: ${e.response?.statusCode}, data: ${e.response?.data}');
      }
      String errorMessage = 'Error sending voice message';
      if (e.response != null) {
        errorMessage += ': ${e.response?.statusCode} - ${e.response?.data}';
      } else if (e.message != null) {
        errorMessage += ': ${e.message}';
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(errorMessage)),
        );
      }
    } catch (e, stackTrace) {
      Log.e('Error sending voice message', 'CHAT_SCREEN_MONGODB', e);
      print('[CHAT_SCREEN_MONGODB] Error: $e');
      print('[CHAT_SCREEN_MONGODB] Stack trace: $stackTrace');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error sending voice message: $e')),
        );
      }
    }
  }

  Widget _buildMessageStatus(Map<String, dynamic> message, bool isDark) {
    final readBy = _extractReadBy(message);
    final status = message['status'] ?? message['messageStatus'];
    final senderId = message['senderId']?.toString() ?? '';
    
    // For group chats, show read count (exclude sender from read count)
    if (widget.isGroupChat) {
      final readCount = readBy.where((id) => 
        id.toString() != senderId
      ).length;
      return _buildGroupStatus(readCount, isDark);
    }
    
    // For one-to-one chats, show status indicator
    // Get recipient ID (the other member in the chat)
    // Use stored _memberIds or fallback to widget.userIds
    String? recipientId;
    List<String>? memberIds = _memberIds ?? widget.userIds;
    if (memberIds != null && memberIds.length == 2) {
      recipientId = memberIds.firstWhere(
        (id) => id.toString() != _currentUserId?.toString(),
        orElse: () => '',
      );
    }
    // Fallback: use _otherUserId if available
    if ((recipientId == null || recipientId.isEmpty) && _otherUserId != null && _otherUserId!.isNotEmpty) {
      recipientId = _otherUserId;
    }
    
    return _buildOneToOneStatus(readBy, status, recipientId, isDark);
  }

  List<dynamic> _extractReadBy(Map<String, dynamic> message) {
    final readBy = message['readBy'] ?? [];
    if (readBy is List) {
      // Convert all to strings for comparison
      return readBy.map((id) => id?.toString() ?? '').toList();
    }
    return [];
  }

  Widget _buildOneToOneStatus(List<dynamic> readBy, String? status, String? recipientId, bool isDark) {
    IconData icon;
    String? tooltip;
    
    // Check if recipient has read the message
    final isRead = recipientId != null && 
                   recipientId.isNotEmpty && 
                   readBy.any((id) => id.toString() == recipientId.toString());
    
    if (isRead || status == 'read') {
      // Read: Double check blue
      icon = Icons.done_all;
      tooltip = 'Read';
    } else if (readBy.isNotEmpty && !isRead) {
      // Delivered: Double check grey (someone read it, but might not be recipient in group context)
      // For one-to-one, if readBy has items but recipient hasn't read, it's delivered
      icon = Icons.done_all;
      tooltip = 'Delivered';
    } else if (status == 'delivered') {
      // Explicitly delivered status
      icon = Icons.done_all;
      tooltip = 'Delivered';
    } else {
      // Sent: Single check grey
      icon = Icons.done;
      tooltip = 'Sent';
    }
    
    return Tooltip(
      message: tooltip,
      child: Icon(
        icon,
        size: 14,
        color: Theme.of(context).colorScheme.onPrimary.withOpacity(0.7),
      ),
    );
  }

  Widget _buildGroupStatus(int readCount, bool isDark) {
    if (readCount == 0) {
      return Tooltip(
        message: 'Sent',
        child: Icon(
          Icons.done,
          size: 14,
          color: Theme.of(context).colorScheme.onPrimary.withOpacity(0.7),
        ),
      );
    }
    
    return Tooltip(
      message: '$readCount ${readCount == 1 ? 'person has' : 'people have'} read',
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.done_all,
            size: 14,
            color: Colors.blue[300]!,
          ),
          const SizedBox(width: 2),
          Text(
            '$readCount',
            style: AppDesignSystem.bodySmall.copyWith(
              color: Theme.of(context).colorScheme.onPrimary.withOpacity(0.7),
              fontWeight: FontWeight.w500,
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _updateUserStatus() async {
    if (_otherUserId == null || _otherUserId!.isEmpty) return;
    
    try {
      final userDetails = await _chatService.getUserDetails(_otherUserId!);
      if (userDetails != null && mounted) {
        setState(() {
          // Parse isOnline - handle boolean, string, or null
          if (userDetails['isOnline'] is bool) {
            _otherUserIsOnline = userDetails['isOnline'] as bool;
          } else if (userDetails['isOnline'] == 'true' || userDetails['isOnline'] == true) {
            _otherUserIsOnline = true;
          } else {
            _otherUserIsOnline = false;
          }
          
          // Parse lastSeen - handle various formats
          final lastSeenStr = userDetails['lastSeen'];
          if (lastSeenStr != null) {
            if (lastSeenStr is String) {
              _otherUserLastSeen = DateTime.tryParse(lastSeenStr);
            } else if (lastSeenStr is DateTime) {
              _otherUserLastSeen = lastSeenStr;
            } else if (lastSeenStr is Map) {
              // MongoDB extended JSON format
              if (lastSeenStr['\$date'] != null) {
                final timestamp = lastSeenStr['\$date'];
                if (timestamp is int) {
                  _otherUserLastSeen = DateTime.fromMillisecondsSinceEpoch(timestamp);
                } else if (timestamp is String) {
                  _otherUserLastSeen = DateTime.tryParse(timestamp);
                }
              }
            } else if (lastSeenStr is int) {
              // Timestamp in milliseconds
              _otherUserLastSeen = DateTime.fromMillisecondsSinceEpoch(lastSeenStr);
            }
          } else {
            // If lastSeen is not provided, use updatedAt or current time
            final updatedAtStr = userDetails['updatedAt'];
            if (updatedAtStr != null) {
              if (updatedAtStr is String) {
                _otherUserLastSeen = DateTime.tryParse(updatedAtStr);
              } else if (updatedAtStr is DateTime) {
                _otherUserLastSeen = updatedAtStr;
              }
            }
          }
          
          // Ensure we have a value to avoid showing "Loading..."
          if (_otherUserIsOnline == null && _otherUserLastSeen == null) {
            _otherUserIsOnline = false;
            _otherUserLastSeen = DateTime.now();
          }
        });
      } else {
        // If userDetails is null, set defaults
        if (mounted) {
          setState(() {
            _otherUserIsOnline = false;
            _otherUserLastSeen = DateTime.now();
          });
        }
      }
    } catch (e) {
      Log.e('Error fetching user status', 'CHAT_SCREEN_MONGODB', e);
      // On error, set defaults to avoid showing "Loading..." forever
      if (mounted) {
        setState(() {
          _otherUserIsOnline = false;
          _otherUserLastSeen = DateTime.now();
        });
      }
    }
  }

  void _startStatusUpdates() {
    // Update status every 10 seconds
    _statusUpdateTimer?.cancel();
    _statusUpdateTimer = Timer.periodic(const Duration(seconds: 10), (timer) {
      if (mounted && !widget.isGroupChat && _otherUserId != null) {
        _updateUserStatus();
      } else {
        timer.cancel();
      }
    });
  }

  String _formatLastSeen(DateTime? lastSeen) {
    if (lastSeen == null) return 'Last seen recently';
    
    final cairoLastSeen = CairoTimeUtils.toCairo(lastSeen);
    final difference = CairoTimeUtils.now().difference(cairoLastSeen);
    
    if (difference.inMinutes < 1) {
      return 'Last seen just now';
    } else if (difference.inMinutes < 60) {
      return 'Last seen ${difference.inMinutes} ${difference.inMinutes == 1 ? 'minute' : 'minutes'} ago';
    } else if (difference.inHours < 24) {
      return 'Last seen ${difference.inHours} ${difference.inHours == 1 ? 'hour' : 'hours'} ago';
    } else if (difference.inDays < 7) {
      return 'Last seen ${difference.inDays} ${difference.inDays == 1 ? 'day' : 'days'} ago';
    } else {
      // Format date: "Jan 15, 2024"
      final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
      final month = months[cairoLastSeen.month - 1];
      return 'Last seen $month ${cairoLastSeen.day}, ${cairoLastSeen.year}';
    }
  }

  String _formatTimestamp(DateTime timestamp) {
    final cairo = CairoTimeUtils.toCairo(timestamp);
    final nowCairo = CairoTimeUtils.now();
    final difference = nowCairo.difference(cairo);

    if (difference.inDays > 0) {
      return '${cairo.day}/${cairo.month}/${cairo.year}';
    } else if (difference.inHours > 0) {
      return '${cairo.hour}:${cairo.minute.toString().padLeft(2, '0')}';
    } else {
      return '${cairo.hour}:${cairo.minute.toString().padLeft(2, '0')}';
    }
  }

  Widget _buildMessageBubble(Map<String, dynamic> message) {
    final senderId = _extractSenderId(message);
    final isCurrentUser = senderId == _currentUserId;
    final content = _extractContent(message);
    final messageType = _extractType(message);
    final timestamp = _extractTimestamp(message);
    final senderName = _extractSenderName(message);
    final mediaUrl = _extractMediaUrl(message) ?? '';
    final isDeletedForEveryone = _isMessageDeletedForEveryone(message);
    final displayContent = isDeletedForEveryone
        ? (isCurrentUser ? 'You deleted this message' : 'This message was deleted')
        : content;
    final isEdited = message['edited'] == true;
    
    // Responsive values
    final avatarRadius = ResponsiveUtils.getResponsiveValue(
      context,
      mobile: 14.0,
      tablet: 16.0,
      desktop: 18.0,
    );
    final avatarFontSize = ResponsiveUtils.getResponsiveFontSize(
      context,
      baseSize: 12.0,
      mobileMultiplier: 0.9,
      tabletMultiplier: 1.0,
      desktopMultiplier: 1.1,
    );
    final messagePadding = ResponsiveUtils.getResponsiveValue(
      context,
      mobile: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      tablet: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
      desktop: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
    );
    final messageMargin = ResponsiveUtils.getResponsiveValue(
      context,
      mobile: const EdgeInsets.symmetric(vertical: 3, horizontal: 6),
      tablet: const EdgeInsets.symmetric(vertical: 4, horizontal: 7),
      desktop: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
    );
    final borderRadius = ResponsiveUtils.getResponsiveValue(
      context,
      mobile: 16.0,
      tablet: 17.0,
      desktop: 18.0,
    );
    final spacing = ResponsiveUtils.getResponsiveSpacing(context);
    final maxBubbleWidth = ResponsiveUtils.getResponsiveValue(
      context,
      mobile: 0.75,
      tablet: 0.65,
      desktop: 0.55,
    );

    // Extract reply info
    final replyTo = message['replyTo'];
    final replyToContent = message['replyToContent']?.toString() ?? '';
    final replyToSenderName = message['replyToSenderName']?.toString() ?? '';
    
    // Extract reactions
    final serverReactions = _safeStringMap(message['reactions']);
    final messageId = _extractMessageId(message);
    
    // Determine which reactions to use: prefer server, fallback to cached (for offline support)
    Map<String, List<String>> reactionsToDisplay = {};
    if (messageId != null) {
      final serverReactionsMap = Map<String, List<String>>.from(
        serverReactions.map((key, value) => MapEntry(
          key,
          List<String>.from(value as List? ?? []),
        )),
      );
      
      // Always use server reactions if available, otherwise use cached
      if (serverReactionsMap.isNotEmpty) {
        _messageReactions[messageId] = serverReactionsMap;
        reactionsToDisplay = serverReactionsMap;
      } else if (_messageReactions[messageId] != null) {
        // Use cached reactions (for offline mode or when server hasn't synced yet)
        reactionsToDisplay = _messageReactions[messageId]!;
      }
    }

    return GestureDetector(
      onLongPress: () => _showMessageOptions(message),
      child: Container(
        margin: messageMargin,
        child: Row(
          mainAxisAlignment: isCurrentUser ? MainAxisAlignment.end : MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            if (!isCurrentUser) ...[
              CircleAvatar(
                radius: avatarRadius,
                backgroundColor: Theme.of(context).colorScheme.surfaceVariant,
                child: Text(
                  senderName.isNotEmpty ? senderName[0].toUpperCase() : 'U',
                  style: TextStyle(
                    fontSize: avatarFontSize,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              SizedBox(width: spacing * 0.67),
            ],
            Flexible(
              child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * maxBubbleWidth,
              ),
              child: Container(
                padding: messagePadding,
                decoration: BoxDecoration(
                  color: isCurrentUser
                      ? Theme.of(context).colorScheme.primary
                      : Theme.of(context).colorScheme.surfaceVariant,
                  borderRadius: BorderRadius.circular(borderRadius),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                  // Show reply preview if this is a reply and message isn't deleted
                  if (!isDeletedForEveryone && replyTo != null && replyToContent.isNotEmpty)
                    Container(
                      margin: EdgeInsets.only(bottom: spacing * 0.5),
                      padding: EdgeInsets.all(spacing * 0.5),
                      decoration: BoxDecoration(
                        color: isCurrentUser
                            ? Theme.of(context).colorScheme.onPrimary.withOpacity(0.2)
                            : Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.5),
                        borderRadius: BorderRadius.circular(8),
                        border: Border(
                          left: BorderSide(
                            color: isCurrentUser
                                ? Theme.of(context).colorScheme.onPrimary
                                : Theme.of(context).colorScheme.primary,
                            width: 3,
                          ),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            replyToSenderName.isNotEmpty ? replyToSenderName : 'Unknown',
                            style: ResponsiveUtils.getResponsiveCaptionStyle(
                              context,
                              color: isCurrentUser
                                  ? Theme.of(context).colorScheme.onPrimary.withOpacity(0.8)
                                  : Theme.of(context).colorScheme.primary,
                              weight: FontWeight.bold,
                            ).copyWith(
                              fontFamily: kIsWeb ? 'NotoNaskhArabic' : null,
                              fontFamilyFallback: kIsWeb
                                  ? const [
                                      'NotoColorEmoji',
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
                          SizedBox(height: spacing * 0.25),
                          Text(
                            replyToContent.length > 50
                                ? '${replyToContent.substring(0, 50)}...'
                                : replyToContent,
                            style: ResponsiveUtils.getResponsiveCaptionStyle(
                              context,
                              color: isCurrentUser
                                  ? Theme.of(context).colorScheme.onPrimary.withOpacity(0.7)
                                  : Theme.of(context).colorScheme.onSurfaceVariant,
                            ).copyWith(
                              fontFamily: kIsWeb ? 'NotoNaskhArabic' : null,
                              fontFamilyFallback: kIsWeb
                                  ? const [
                                      'NotoColorEmoji',
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
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  if (!isCurrentUser && widget.isGroupChat)
                    Padding(
                      padding: EdgeInsets.only(bottom: spacing * 0.33),
                      child: Text(
                        senderName,
                        style: ResponsiveUtils.getResponsiveCaptionStyle(
                          context,
                          color: isCurrentUser
                              ? Theme.of(context).colorScheme.onPrimary.withOpacity(0.7)
                              : Theme.of(context).colorScheme.onSurfaceVariant,
                          weight: FontWeight.bold,
                        ).copyWith(
                          fontFamily: kIsWeb ? 'NotoNaskhArabic' : null,
                          fontFamilyFallback: kIsWeb
                              ? const [
                                  'NotoColorEmoji',
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
                    ),
                  if (isDeletedForEveryone)
                    Text(
                      displayContent,
                      style: ResponsiveUtils.getResponsiveBodyStyle(
                        context,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ).copyWith(
                        fontStyle: FontStyle.italic,
                        fontFamily: kIsWeb ? 'NotoNaskhArabic' : null,
                        fontFamilyFallback: kIsWeb
                            ? const [
                                'NotoColorEmoji',
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
                    )
                  else if (messageType == 'text')
                    Text(
                      displayContent,
                      style: ResponsiveUtils.getResponsiveBodyStyle(
                        context,
                        color: isCurrentUser
                            ? Theme.of(context).colorScheme.onPrimary
                            : Theme.of(context).colorScheme.onSurface,
                      ).copyWith(
                        fontFamily: kIsWeb ? 'NotoNaskhArabic' : null,
                        fontFamilyFallback: kIsWeb
                            ? const [
                                'NotoColorEmoji',
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
                    )
                  else if (messageType == 'image')
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          constraints: BoxConstraints(
                            maxWidth: ResponsiveUtils.getResponsiveValue(
                              context,
                              mobile: 180.0,
                              tablet: 200.0,
                              desktop: 250.0,
                            ),
                            maxHeight: ResponsiveUtils.getResponsiveValue(
                              context,
                              mobile: 180.0,
                              tablet: 200.0,
                              desktop: 250.0,
                            ),
                          ),
                          child: EnhancedMediaPreview(
                            mediaUrl: mediaUrl ?? '',
                            mediaType: 'image',
                            fileName: message['fileName'] ?? content.isNotEmpty ? content : 'Image',
                            fileSize: message['fileSize'] as String?,
                            onTap: () => _showFullScreenMedia(mediaUrl ?? '', 'image', content),
                            maxWidth: ResponsiveUtils.getResponsiveValue(
                              context,
                              mobile: 180.0,
                              tablet: 200.0,
                              desktop: 250.0,
                            ),
                            maxHeight: ResponsiveUtils.getResponsiveValue(
                              context,
                              mobile: 180.0,
                              tablet: 200.0,
                              desktop: 250.0,
                            ),
                            enableRetry: true,
                          ),
                        ),
                        if (content.isNotEmpty)
                          Padding(
                            padding: EdgeInsets.only(top: spacing * 0.67),
                            child: Text(
                              displayContent,
                              style: ResponsiveUtils.getResponsiveCaptionStyle(
                                context,
                                color: isCurrentUser
                                    ? Theme.of(context).colorScheme.onPrimary
                                    : Theme.of(context).colorScheme.onSurface,
                              ),
                            ),
                          ),
                      ],
                    )
                  else if (messageType == 'video')
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                                Container(
                          constraints: BoxConstraints(
                            maxWidth: ResponsiveUtils.getResponsiveValue(
                              context,
                              mobile: 200.0,
                              tablet: 225.0,
                              desktop: 250.0,
                            ),
                            maxHeight: ResponsiveUtils.getResponsiveValue(
                              context,
                              mobile: 150.0,
                              tablet: 175.0,
                              desktop: 200.0,
                            ),
                          ),
                          child: EnhancedMediaPreview(
                            mediaUrl: mediaUrl ?? '',
                            mediaType: 'video',
                            fileName: message['fileName'] ?? content.isNotEmpty ? content : 'Video',
                            fileSize: message['fileSize'] as String?,
                            onTap: () => _showFullScreenMedia(mediaUrl ?? '', 'video', content),
                            maxWidth: ResponsiveUtils.getResponsiveValue(
                              context,
                              mobile: 200.0,
                              tablet: 225.0,
                              desktop: 250.0,
                            ),
                            maxHeight: ResponsiveUtils.getResponsiveValue(
                              context,
                              mobile: 150.0,
                              tablet: 175.0,
                              desktop: 200.0,
                            ),
                            enableRetry: true,
                          ),
                        ),
                        if (content.isNotEmpty)
                          Padding(
                            padding: EdgeInsets.only(top: spacing * 0.67),
                            child: Text(
                              displayContent,
                              style: ResponsiveUtils.getResponsiveCaptionStyle(
                                context,
                                color: isCurrentUser
                                    ? Theme.of(context).colorScheme.onPrimary
                                    : Theme.of(context).colorScheme.onSurface,
                              ),
                            ),
                          ),
                      ],
                    )
                  else if (messageType == 'audio' || messageType == 'voice')
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        ConstrainedBox(
                          constraints: BoxConstraints(
                            maxWidth: ResponsiveUtils.getResponsiveValue(
                              context,
                              mobile: 250.0,
                              tablet: 280.0,
                              desktop: 300.0,
                            ),
                            maxHeight: ResponsiveUtils.getResponsiveValue(
                              context,
                              mobile: 60.0,
                              tablet: 65.0,
                              desktop: 70.0,
                            ),
                          ),
                          child: EnhancedMediaPreview(
                            mediaUrl: mediaUrl ?? '',
                            mediaType: messageType == 'voice' ? 'voice' : 'audio',
                            fileName: content.isNotEmpty ? content : (messageType == 'voice' ? 'Voice Message' : 'Audio Message'),
                            fileSize: message['fileSize'] as String? ?? message['duration']?.toString(),
                            onTap: () => _showFullScreenMedia(mediaUrl ?? '', messageType, content),
                            maxWidth: ResponsiveUtils.getResponsiveValue(
                              context,
                              mobile: 250.0,
                              tablet: 280.0,
                              desktop: 300.0,
                            ),
                            maxHeight: ResponsiveUtils.getResponsiveValue(
                              context,
                              mobile: 60.0,
                              tablet: 65.0,
                              desktop: 70.0,
                            ),
                            enableRetry: true,
                          ),
                        ),
                        if (content.isNotEmpty && !content.contains('Voice Message') && !content.contains('Audio Message'))
                          Padding(
                            padding: EdgeInsets.only(top: spacing * 0.5),
                            child: Text(
                              displayContent,
                              style: ResponsiveUtils.getResponsiveCaptionStyle(
                                context,
                                color: isCurrentUser
                                    ? Theme.of(context).colorScheme.onPrimary
                                    : Theme.of(context).colorScheme.onSurface,
                              ),
                            ),
                          ),
                      ],
                    )
                  else if (messageType == 'document')
                    Container(
                      constraints: BoxConstraints(
                        maxWidth: ResponsiveUtils.getResponsiveValue(
                          context,
                          mobile: 200.0,
                          tablet: 225.0,
                          desktop: 250.0,
                        ),
                        maxHeight: ResponsiveUtils.getResponsiveValue(
                          context,
                          mobile: 140.0,
                          tablet: 160.0,
                          desktop: 180.0,
                        ),
                      ),
                      child: EnhancedMediaPreview(
                        mediaUrl: mediaUrl ?? '',
                        mediaType: 'document',
                        fileName: displayContent.isNotEmpty ? displayContent : 'Document',
                        fileSize: message['fileSize'] as String?,
                        isCurrentUser: isCurrentUser,
                        onTap: () {
                          _showFullScreenMedia(mediaUrl ?? '', 'document', displayContent, fileSize: message['fileSize'] as String?);
                        },
                        maxWidth: ResponsiveUtils.getResponsiveValue(
                          context,
                          mobile: 200.0,
                          tablet: 225.0,
                          desktop: 250.0,
                        ),
                        maxHeight: ResponsiveUtils.getResponsiveValue(
                          context,
                          mobile: 140.0,
                          tablet: 160.0,
                          desktop: 180.0,
                        ),
                        enableRetry: true,
                      ),
                    )
                  else
                    Text(
                      'Unsupported message type: $messageType',
                      style: ResponsiveUtils.getResponsiveBodyStyle(
                        context,
                        color: isCurrentUser
                            ? Theme.of(context).colorScheme.onPrimary
                            : Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                  SizedBox(height: spacing * 0.33),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Text(
                        '${_formatTimestamp(timestamp)}${isEdited && !isDeletedForEveryone ? ' • Edited' : ''}',
                        style: TextStyle(
                          fontSize: ResponsiveUtils.getResponsiveFontSize(
                            context,
                            baseSize: 10.0,
                            mobileMultiplier: 0.9,
                            tabletMultiplier: 1.0,
                            desktopMultiplier: 1.0,
                          ),
                          color: isCurrentUser
                              ? Theme.of(context).colorScheme.onPrimary.withOpacity(0.7)
                              : Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                      if (isCurrentUser) ...[
                        SizedBox(width: spacing * 0.33),
                        _buildMessageStatus(message, Theme.of(context).brightness == Brightness.dark),
                      ],
                    ],
                  ),
                  // Show reactions if any (use server reactions, fallback to cached)
                  Builder(
                    builder: (context) {
                      // Priority: 1) reactionsToDisplay (from server), 2) _messageReactions cache
                      final displayReactions = isDeletedForEveryone
                          ? <String, List<String>>{}
                          : (reactionsToDisplay.isNotEmpty
                              ? reactionsToDisplay
                              : (messageId != null && _messageReactions[messageId] != null
                                  ? _messageReactions[messageId]!
                                  : <String, List<String>>{}));
                      if (displayReactions.isEmpty) return const SizedBox.shrink();
                      return Padding(
                        padding: EdgeInsets.only(top: spacing * 0.33),
                        child: Wrap(
                        spacing: 4,
                        runSpacing: 4,
                        children: displayReactions.entries.map((entry) {
                          final emoji = entry.key;
                          final userIds = entry.value as List? ?? [];
                          final hasUserReacted = messageId != null && 
                              _currentUserId != null &&
                              userIds.contains(_currentUserId);
                          
                          return GestureDetector(
                            onTap: () => _reactToMessage(messageId ?? '', emoji),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: hasUserReacted
                                    ? Theme.of(context).colorScheme.primary.withOpacity(0.2)
                                    : Theme.of(context).colorScheme.surfaceVariant,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: hasUserReacted
                                      ? Theme.of(context).colorScheme.primary
                                      : Theme.of(context).colorScheme.outline.withOpacity(0.3),
                                  width: 1,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    emoji,
                                    style: const TextStyle(fontSize: 14),
                                  ),
                                  if (userIds.isNotEmpty) ...[
                                    const SizedBox(width: 4),
                                    Text(
                                      '${userIds.length}',
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                        color: hasUserReacted
                                            ? Theme.of(context).colorScheme.primary
                                            : Theme.of(context).colorScheme.onSurfaceVariant,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    );
                    },
                  ),
                  // Show reply count if any
                  if (message['replies'] != null && (message['replies'] as List).isNotEmpty)
                    Padding(
                      padding: EdgeInsets.only(top: spacing * 0.25),
                      child: GestureDetector(
                        onTap: () => _showReplies(messageId ?? ''),
                        child: Text(
                          '${(message['replies'] as List).length} ${(message['replies'] as List).length == 1 ? 'reply' : 'replies'}',
                          style: TextStyle(
                            fontSize: 11,
                            color: isCurrentUser
                                ? Theme.of(context).colorScheme.onPrimary.withOpacity(0.7)
                                : Theme.of(context).colorScheme.primary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
            if (isCurrentUser) ...[
              SizedBox(width: spacing * 0.67),
              CircleAvatar(
                radius: avatarRadius,
                backgroundColor: Theme.of(context).colorScheme.primary,
                child: Text(
                  _currentUserName?.isNotEmpty == true ? _currentUserName![0].toUpperCase() : 'U',
                  style: TextStyle(
                    fontSize: avatarFontSize,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.onPrimary,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _showFullScreenMedia(String mediaUrl, String mediaType, String fileName, {String? fileSize}) {
    // CRITICAL: Resolve URL to local network on web (convert ngrok to IPv4)
    final resolvedUrl = _resolveWebSameOriginUrl(mediaUrl);
    Log.d('Full Screen Media - Original: $mediaUrl, Resolved: $resolvedUrl', 'CHAT_SCREEN_MONGODB');
    
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => FullScreenMediaPreview(
          mediaUrl: resolvedUrl, // Use resolved URL (local network) instead of ngrok
          mediaType: mediaType,
          fileName: fileName.isNotEmpty ? fileName : null,
          fileSize: fileSize,
        ),
      ),
    );
  }
  
  // Resolve media URL to same-origin on web for direct loading/downloading
  String _resolveWebSameOriginUrl(String url) {
    if (!kIsWeb) return url; // Mobile: return as-is (ngrok URLs preserved)
    try {
      final parsed = Uri.parse(url);
      if (parsed.scheme == 'blob' || parsed.scheme == 'data') return url;
      if (parsed.host.contains('firebasestorage.googleapis.com')) return url;
      
      final base = Uri.base;
      final p = parsed.path;

      // On web, convert ngrok URLs to local network URLs
      if (parsed.host.contains('ngrok') || parsed.host.contains('ngrok-free.app') || parsed.host.contains('ngrok.app')) {
        // Extract the path and convert to same-origin (local network)
        return Uri.parse('${base.origin}$p${parsed.hasQuery ? '?${parsed.query}' : ''}').toString();
      }

      // Prefer rewriting known server paths to same-origin (local network)
      if (p.startsWith('/uploads') || p.contains('/uploads/')) {
        return Uri.parse('${base.origin}$p${parsed.hasQuery ? '?${parsed.query}' : ''}').toString();
      }

      // Handle legacy /chat_media URLs by prefixing /uploads
      if (p.startsWith('/chat_media') || p.contains('/chat_media/')) {
        final adjustedPath = '/uploads' + (p.startsWith('/') ? p : '/$p');
        return Uri.parse('${base.origin}$adjustedPath${parsed.hasQuery ? '?${parsed.query}' : ''}').toString();
      }

      // Proxy API calls to same-origin (local network)
      if (p.startsWith('/api/')) {
        return Uri.parse('${base.origin}$p${parsed.hasQuery ? '?${parsed.query}' : ''}').toString();
      }

      // If already same-origin (local network), leave as-is
      final originUrl = '${parsed.scheme}://${parsed.host}${parsed.hasPort ? ':${parsed.port}' : ''}';
      if (originUrl == base.origin) return url;
      
      // For external URLs that aren't ngrok or same-origin, leave as-is
      return url;
    } catch (_) {
      return url;
    }
  }

  Future<void> _showGroupInfo() async {
    if (!widget.isGroupChat || _currentUserId == null) return;
    
    try {
      // Fetch chat details to get member roles
      final chatDetails = await _chatService.getChatDetails(widget.chatId);
      if (chatDetails == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to load group information')),
          );
        }
        return;
      }
      
      final chat = chatDetails['chat'] ?? chatDetails;
      final members = chat['members'] as List? ?? [];
      final memberRoles = chat['memberRoles'] as Map<String, dynamic>? ?? {};
      final createdBy = chat['createdBy']?.toString();
      final isCreator = createdBy == _currentUserId;
      
      // Get current user's role in the group (group admin is different from app admin)
      final currentUserRole = memberRoles[_currentUserId] ?? 'member';
      final isGroupAdmin = currentUserRole == 'admin' || isCreator; // Group admin, not app admin
      final isGroupManager = currentUserRole == 'manager' || isGroupAdmin;
      
      // Fetch all users for adding members
      final databaseService = await DatabaseConfig.getDatabaseService();
      final allUsers = await databaseService.getAllUsers();
      
      // Filter out users who are already members
      final memberIds = members.map((m) => m.toString()).toList();
      final availableUsers = allUsers.where((user) => !memberIds.contains(user.id)).toList();
      
      if (!mounted) return;
      
      showDialog(
        context: context,
        builder: (context) => StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
            title: Text('Group Info: ${widget.chatName}'),
            content: SizedBox(
              width: double.maxFinite,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Members list
                    const Text(
                      'Members',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    const SizedBox(height: 8),
                    ...members.map<Widget>((memberId) {
                      final memberIdStr = memberId.toString();
                      final role = memberRoles[memberIdStr] ?? 'member';
                      final isMemberCreator = memberIdStr == createdBy;
                      final displayRole = isMemberCreator ? 'Admin (Creator)' : 
                                        role == 'admin' ? 'Admin' :
                                        role == 'manager' ? 'Manager' : 'Member';
                      
                      // Find user info
                      final userDoc = allUsers.firstWhere(
                        (u) => u.id == memberIdStr,
                        orElse: () => allUsers.first,
                      );
                      final userData = userDoc.data();
                      final userName = userData['displayName'] ?? 
                                      userData['username'] ?? 
                                      userData['email'] ?? 
                                      'Unknown User';
                      
                      return ListTile(
                        dense: true,
                        leading: CircleAvatar(
                          backgroundImage: (userData['photoUrl'] as String?)?.isNotEmpty == true
                              ? NetworkImage(userData['photoUrl'])
                              : null,
                          child: (userData['photoUrl'] as String?)?.isEmpty != false
                              ? const Icon(Icons.person, size: 20)
                              : null,
                        ),
                        title: Text(userName),
                        subtitle: Text(displayRole),
                        trailing: isCreator && memberIdStr != _currentUserId
                            ? PopupMenuButton<String>(
                                icon: const Icon(Icons.more_vert, size: 18),
                                onSelected: (value) async {
                                  if (value == 'make_manager') {
                                    try {
                                      await databaseService.updateMemberRole(
                                        widget.chatId,
                                        memberIdStr,
                                        'manager',
                                      );
                                      setDialogState(() {});
                                      if (mounted) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          const SnackBar(content: Text('Role updated to Manager')),
                                        );
                                      }
                                      // Refresh dialog
                                      Navigator.pop(context);
                                      _showGroupInfo();
                                    } catch (e) {
                                      if (mounted) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(content: Text('Error: $e')),
                                        );
                                      }
                                    }
                                  } else if (value == 'make_member') {
                                    try {
                                      await databaseService.updateMemberRole(
                                        widget.chatId,
                                        memberIdStr,
                                        'member',
                                      );
                                      setDialogState(() {});
                                      if (mounted) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          const SnackBar(content: Text('Role updated to Member')),
                                        );
                                      }
                                      // Refresh dialog
                                      Navigator.pop(context);
                                      _showGroupInfo();
                                    } catch (e) {
                                      if (mounted) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(content: Text('Error: $e')),
                                        );
                                      }
                                    }
                                  }
                                },
                                itemBuilder: (context) {
                                  // Show "Make Manager" only if member is not already a manager or admin
                                  // Show "Make Member" only if member is a manager (not admin/creator)
                                  final isMemberManager = role == 'manager';
                                  final isMemberAdmin = role == 'admin' || isMemberCreator;
                                  
                                  final menuItems = <PopupMenuEntry<String>>[];
                                  
                                  // Only show "Make Manager" if member is not already manager/admin
                                  if (!isMemberManager && !isMemberAdmin) {
                                    menuItems.add(
                                      const PopupMenuItem(
                                        value: 'make_manager',
                                        child: Row(
                                          children: [
                                            Icon(Icons.admin_panel_settings, size: 18),
                                            SizedBox(width: 8),
                                            Text('Make Manager'),
                                          ],
                                        ),
                                      ),
                                    );
                                  }
                                  
                                  // Only show "Make Member" if member is currently a manager
                                  if (isMemberManager) {
                                    menuItems.add(
                                      const PopupMenuItem(
                                        value: 'make_member',
                                        child: Row(
                                          children: [
                                            Icon(Icons.person, size: 18),
                                            SizedBox(width: 8),
                                            Text('Make Member'),
                                          ],
                                        ),
                                      ),
                                    );
                                  }
                                  
                                  return menuItems;
                                },
                              )
                            : null,
                      );
                    }).toList(),
                    
                    // Add members section (for group admins and group managers only)
                    if (isGroupManager) ...[
                      const SizedBox(height: 24),
                      const Text(
                        'Add Members',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      const SizedBox(height: 8),
                      if (availableUsers.isEmpty)
                        const Padding(
                          padding: EdgeInsets.all(8.0),
                          child: Text('No users available to add'),
                        )
                      else
                        SizedBox(
                          height: 200,
                          child: ListView.builder(
                            shrinkWrap: true,
                            itemCount: availableUsers.length,
                            itemBuilder: (context, index) {
                              final user = availableUsers[index];
                              final userData = user.data();
                              final userName = userData['displayName'] ?? 
                                              userData['username'] ?? 
                                              userData['email'] ?? 
                                              'Unknown User';
                              
                              return ListTile(
                                dense: true,
                                leading: CircleAvatar(
                                  backgroundImage: (userData['photoUrl'] as String?)?.isNotEmpty == true
                                      ? NetworkImage(userData['photoUrl'])
                                      : null,
                                  child: (userData['photoUrl'] as String?)?.isEmpty != false
                                      ? const Icon(Icons.person, size: 20)
                                      : null,
                                ),
                                title: Text(userName),
                                trailing: IconButton(
                                  icon: const Icon(Icons.add_circle, color: Colors.green),
                                  onPressed: () async {
                                    try {
                                      await databaseService.addUserToChat(widget.chatId, user.id);
                                      setDialogState(() {});
                                      if (mounted) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          const SnackBar(content: Text('Member added successfully')),
                                        );
                                      }
                                      // Refresh dialog
                                      Navigator.pop(context);
                                      _showGroupInfo();
                                    } catch (e) {
                                      if (mounted) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(content: Text('Error: $e')),
                                        );
                                      }
                                    }
                                  },
                                ),
                              );
                            },
                          ),
                        ),
                    ],
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Close'),
              ),
            ],
          ),
        ),
      );
    } catch (e) {
      Log.e('Error showing group info', 'CHAT_SCREEN_MONGODB', e);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading group info: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Responsive layout for web and mobile
    final spacing = ResponsiveUtils.getResponsiveSpacing(context);
    
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Builder(
              builder: (context) {
                final baseStyle = ResponsiveUtils.getResponsiveHeadingStyle(
                  context,
                  color: Theme.of(context).colorScheme.onPrimary,
                  weight: FontWeight.bold,
                );
                return Text(
                  widget.chatName,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: baseStyle.copyWith(
                    fontSize: _dynamicTitleFontSize(baseStyle),
                    fontFamily: kIsWeb ? 'NotoNaskhArabic' : null,
                    fontFamilyFallback: kIsWeb
                        ? const [
                            'NotoColorEmoji',
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
                );
              },
            ),
            if (!widget.isGroupChat) ...[
              SizedBox(height: spacing * 0.17),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_otherUserIsOnline == true) ...[
                    Container(
                      width: ResponsiveUtils.getResponsiveValue(
                        context,
                        mobile: 7.0,
                        tablet: 8.0,
                        desktop: 8.0,
                      ),
                      height: ResponsiveUtils.getResponsiveValue(
                        context,
                        mobile: 7.0,
                        tablet: 8.0,
                        desktop: 8.0,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.green,
                        shape: BoxShape.circle,
                      ),
                    ),
                    SizedBox(width: spacing * 0.5),
                    Text(
                      'Online',
                      style: ResponsiveUtils.getResponsiveCaptionStyle(
                        context,
                        color: Theme.of(context).colorScheme.onPrimary.withOpacity(0.8),
                      ),
                    ),
                  ] else if (_otherUserLastSeen != null) ...[
                    Text(
                      _formatLastSeen(_otherUserLastSeen),
                      style: ResponsiveUtils.getResponsiveCaptionStyle(
                        context,
                        color: Theme.of(context).colorScheme.onPrimary.withOpacity(0.8),
                      ),
                    ),
                  ] else ...[
                    Text(
                      'Loading...',
                      style: ResponsiveUtils.getResponsiveCaptionStyle(
                        context,
                        color: Theme.of(context).colorScheme.onPrimary.withOpacity(0.8),
                      ),
                    ),
                  ],
                ],
              ),
            ] else ...[
              SizedBox(height: spacing * 0.17),
              Text(
                'Group Chat',
                style: ResponsiveUtils.getResponsiveCaptionStyle(
                  context,
                  color: Theme.of(context).colorScheme.onPrimary.withOpacity(0.8),
                ),
              ),
            ],
          ],
        ),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Theme.of(context).colorScheme.onPrimary,
        elevation: 0,
        centerTitle: false,
        actions: [
          // Voice call button
          IconButton(
            tooltip: 'Voice Call',
            icon: const Icon(Icons.phone),
            onPressed: () {
              print('🔵 CALL BUTTON PRESSED: Voice Call');
              Log.i('🔵 CALL BUTTON PRESSED: Voice Call', 'CHAT_SCREEN_MONGODB');
              _startCall(CallType.voice);
            },
          ),
          // Video call button
          IconButton(
            tooltip: 'Video Call',
            icon: const Icon(Icons.videocam),
            onPressed: () {
              print('🔵 CALL BUTTON PRESSED: Video Call');
              Log.i('🔵 CALL BUTTON PRESSED: Video Call', 'CHAT_SCREEN_MONGODB');
              _startCall(CallType.video);
            },
          ),
          IconButton(
            tooltip: 'Media',
            icon: const Icon(Icons.perm_media_outlined),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => ChatMediaGallery(
                    chatId: widget.chatId,
                    chatName: widget.chatName,
                  ),
                ),
              );
            },
          ),
          if (widget.isGroupChat)
            IconButton(
              icon: const Icon(Icons.group),
              onPressed: () => _showGroupInfo(),
            ),
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'delete_chat') {
                _deleteChatForMe();
              }
            },
            itemBuilder: (context) => const [
              PopupMenuItem(
                value: 'delete_chat',
                child: Row(
                  children: [
                    Icon(Icons.delete_outline, size: 18),
                    SizedBox(width: 8),
                    Text('Delete chat for me'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _messages.isEmpty
                    ? Center(
                        child: Text(
                          'No messages yet. Start the conversation!',
                          style: AppDesignSystem.bodyLarge.copyWith(
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                        ),
                      )
                    : ListView.builder(
                        controller: _scrollController,
                        itemCount: _messages.length,
                        padding: EdgeInsets.symmetric(
                          horizontal: ResponsiveUtils.getResponsiveValue(
                            context,
                            mobile: 0.0,
                            tablet: 12.0,
                            desktop: 24.0,
                          ),
                          vertical: 8.0,
                        ),
                        itemBuilder: (context, index) {
                          return _buildMessageBubble(_messages[index]);
                        },
                      ),
          ),
          // Show reply preview if replying
          if (_replyingToMessage != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceVariant,
                border: Border(
                  top: BorderSide(
                    color: Theme.of(context).dividerColor,
                    width: 1,
                  ),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 3,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primary,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Replying to ${_extractSenderName(_replyingToMessage!)}',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _extractContent(_replyingToMessage!).length > 50
                              ? '${_extractContent(_replyingToMessage!).substring(0, 50)}...'
                              : _extractContent(_replyingToMessage!),
                          style: TextStyle(
                            fontSize: 11,
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () {
                      setState(() {
                        _replyingToMessage = null;
                      });
                    },
                    iconSize: 20,
                  ),
                ],
              ),
            ),
          // Enhanced chat input with emoji picker and media attachment
          EnhancedChatInput(
            controller: _messageController,
            onSendMessage: _sendMessage,
            onSendMedia: _sendMediaMessage,
            onSendVoice: _sendVoiceMessage,
            chatId: widget.chatId,
            isEnabled: !_isSending,
          ),
        ],
      ),
    );
  }

  /// Build cached image widget with fallback to network
  Widget _buildCachedImage(String mediaUrl) {
    // Responsive image sizing for web and mobile
    final screenWidth = MediaQuery.of(context).size.width;
    final isWideScreen = kIsWeb && screenWidth > 800;
    final maxWidth = isWideScreen ? 400.0 : 250.0;
    final maxHeight = isWideScreen ? 300.0 : 250.0;
    
    // Use EnhancedMediaPreview for consistent media handling across platforms
    return GestureDetector(
      onTap: () => _showFullScreenMedia(mediaUrl, 'image', 'Image'),
      child: Container(
        constraints: BoxConstraints(
          maxWidth: maxWidth,
          maxHeight: maxHeight,
        ),
        child: EnhancedMediaPreview(
          mediaUrl: mediaUrl,
          mediaType: 'image',
          onTap: () => _showFullScreenMedia(mediaUrl, 'image', 'Image'),
          maxWidth: maxWidth,
          maxHeight: maxHeight,
          enableRetry: true,
        ),
      ),
    );
  }
}
