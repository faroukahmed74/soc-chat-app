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
import 'package:http/http.dart' as http;
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
  
  // User status for one-to-one chats
  bool? _otherUserIsOnline;
  DateTime? _otherUserLastSeen;
  String? _otherUserId;
  List<String>? _memberIds; // Store member IDs for status checking
  
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
      final user = await _authService.getCurrentUser();
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
          _loadMessages();
        }
      });
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
        
        // Mark messages as read for those not sent by current user
        await _markMessagesAsRead(_messages);
        
        // Reset unread count for this chat when opened
        await _resetUnreadCount();
        
        _scrollToBottom(force: true); // Force scroll on initial load
      }
    } catch (e) {
      Log.e('Error loading messages', 'CHAT_SCREEN_MONGODB', e);
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
        body: json.encode({'userId': _currentUserId}),
      );
      
      if (response.statusCode == 200) {
        Log.i('Unread count reset for chat ${widget.chatId}', 'CHAT_SCREEN_MONGODB');
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
      final result = await _chatService.sendTextMessage(widget.chatId, content);
      if (result != null) {
        _messageController.clear();
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

  Future<void> _sendMediaMessage(String mediaUrl, String messageType, {String? content}) async {
    if (_isSending) return;

    setState(() {
      _isSending = true;
    });

    try {
      final result = await _chatService.sendMediaMessage(
        widget.chatId,
        mediaUrl,
        messageType,
        content: (content != null && content.isNotEmpty) ? content : null,
      );
      if (result != null) {
        // Force scroll to bottom when user sends their own media
        _scrollToBottom(force: true);
        // Message will be added via the stream listener
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to send media')),
          );
        }
      }
    } catch (e) {
      Log.e('Error sending media', 'CHAT_SCREEN_MONGODB', e);
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
    
    final now = DateTime.now();
    final difference = now.difference(lastSeen);
    
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
      final month = months[lastSeen.month - 1];
      return 'Last seen $month ${lastSeen.day}, ${lastSeen.year}';
    }
  }

  String _formatTimestamp(DateTime timestamp) {
    // Convert to Cairo time (UTC+2)
    final cairo = timestamp.toUtc().add(const Duration(hours: 2));
    final nowCairo = DateTime.now().toUtc().add(const Duration(hours: 2));
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
    
    // Responsive margins for web and mobile
    final screenWidth = MediaQuery.of(context).size.width;
    final isWideScreen = kIsWeb && screenWidth > 800;
    final horizontalMargin = isWideScreen ? 16.0 : 8.0;

    return Container(
      margin: EdgeInsets.symmetric(vertical: 4, horizontal: horizontalMargin),
      child: Row(
        mainAxisAlignment: isCurrentUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isCurrentUser) ...[
            CircleAvatar(
              radius: 16,
              backgroundColor: Theme.of(context).colorScheme.surfaceVariant,
              child: Text(
                senderName.isNotEmpty ? senderName[0].toUpperCase() : 'U',
                style: AppDesignSystem.bodySmall.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              constraints: BoxConstraints(
                maxWidth: isWideScreen ? 600 : double.infinity,
              ),
              decoration: BoxDecoration(
                color: isCurrentUser
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(context).colorScheme.surfaceVariant,
                borderRadius: BorderRadius.circular(AppDesignSystem.radiusLG),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (!isCurrentUser && widget.isGroupChat)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text(
                        senderName,
                        style: AppDesignSystem.bodySmall.copyWith(
                          fontWeight: FontWeight.bold,
                          color: isCurrentUser
                              ? Theme.of(context).colorScheme.onPrimary.withOpacity(0.7)
                              : Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  if (messageType == 'text')
                    Text(
                      content,
                      style: AppDesignSystem.bodyMedium.copyWith(
                        color: isCurrentUser
                            ? Theme.of(context).colorScheme.onPrimary
                            : Theme.of(context).colorScheme.onSurface,
                      ),
                    )
                  else if (messageType == 'image')
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        GestureDetector(
                          onTap: () => _showFullScreenMedia(mediaUrl, 'image', content),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: _buildCachedImage(mediaUrl),
                          ),
                        ),
                        if (content.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                              content,
                              style: AppDesignSystem.bodyMedium.copyWith(
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
                        GestureDetector(
                          onTap: () => _showFullScreenMedia(mediaUrl, 'video', content),
                          child: Container(
                            width: 200,
                            height: 150,
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.surfaceVariant,
                              borderRadius: BorderRadius.circular(AppDesignSystem.radiusMD),
                            ),
                            child: Stack(
                              children: [
                                // Video thumbnail placeholder
                                Container(
                                  width: 200,
                                  height: 150,
                                  decoration: BoxDecoration(
                                    color: Theme.of(context).colorScheme.surfaceVariant,
                                    borderRadius: BorderRadius.circular(AppDesignSystem.radiusMD),
                                  ),
                                  child: Icon(
                                    Icons.videocam,
                                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                                    size: 40,
                                  ),
                                ),
                                // Play button overlay
                                Center(
                                  child: Icon(
                                    Icons.play_circle_filled,
                                    color: Theme.of(context).colorScheme.primary,
                                    size: 50,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        if (content.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                              content,
                              style: AppDesignSystem.bodyMedium.copyWith(
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
                      children: [
                        GestureDetector(
                          onTap: () => _showFullScreenMedia(mediaUrl, messageType, content),
                          child: Container(
                            width: 200,
                            height: 80,
                            decoration: BoxDecoration(
                              color: isCurrentUser
                                  ? Theme.of(context).colorScheme.primary
                                  : Theme.of(context).colorScheme.surfaceVariant,
                              borderRadius: BorderRadius.circular(AppDesignSystem.radiusMD),
                            ),
                            child: Row(
                              children: [
                                const SizedBox(width: 12),
                                Icon(
                                  messageType == 'voice' ? Icons.mic : Icons.music_note,
                                  color: isCurrentUser 
                                      ? Theme.of(context).colorScheme.onPrimary 
                                      : Theme.of(context).colorScheme.onSurfaceVariant,
                                  size: 24,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        messageType == 'voice' ? 'Voice Message' : 'Audio Message',
                                        style: AppDesignSystem.bodyMedium.copyWith(
                                          color: isCurrentUser 
                                              ? Theme.of(context).colorScheme.onPrimary 
                                              : Theme.of(context).colorScheme.onSurface,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        'Tap to play',
                                        style: AppDesignSystem.bodySmall.copyWith(
                                          color: isCurrentUser 
                                              ? Theme.of(context).colorScheme.onPrimary.withOpacity(0.7)
                                              : Theme.of(context).colorScheme.onSurfaceVariant,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Icon(
                                  Icons.play_circle_filled,
                                  color: isCurrentUser 
                                      ? Theme.of(context).colorScheme.onPrimary 
                                      : Theme.of(context).colorScheme.onSurfaceVariant,
                                  size: 32,
                                ),
                                const SizedBox(width: 12),
                              ],
                            ),
                          ),
                        ),
                        if (content.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                              content,
                              style: AppDesignSystem.bodyMedium.copyWith(
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
                      constraints: const BoxConstraints(
                        maxWidth: 250,
                        maxHeight: 150,
                      ),
                      child: EnhancedMediaPreview(
                        mediaUrl: mediaUrl ?? '',
                        mediaType: 'document',
                        fileName: content.isNotEmpty ? content : 'Document',
                        fileSize: message['fileSize'] as String?,
                        isCurrentUser: isCurrentUser,
                        onTap: () {
                          _showFullScreenMedia(mediaUrl ?? '', 'document', content, fileSize: message['fileSize'] as String?);
                        },
                        maxWidth: 250,
                        maxHeight: 150,
                        enableRetry: true,
                      ),
                    )
                  else
                    Text(
                      'Unsupported message type: $messageType',
                      style: AppDesignSystem.bodyMedium.copyWith(
                        color: isCurrentUser
                            ? Theme.of(context).colorScheme.onPrimary
                            : Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Text(
                        _formatTimestamp(timestamp),
                        style: AppDesignSystem.bodySmall.copyWith(
                          color: isCurrentUser
                              ? Theme.of(context).colorScheme.onPrimary.withOpacity(0.7)
                              : Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                      if (isCurrentUser) ...[
                        const SizedBox(width: 4),
                        _buildMessageStatus(message, Theme.of(context).brightness == Brightness.dark),
                      ],
                    ],
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
                _currentUserName?.isNotEmpty == true ? _currentUserName![0].toUpperCase() : 'U',
                style: AppDesignSystem.bodySmall.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.onPrimary,
                ),
              ),
            ),
          ],
        ],
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
    final isWeb = kIsWeb;
    final screenWidth = MediaQuery.of(context).size.width;
    final isWideScreen = isWeb && screenWidth > 800;
    
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              widget.chatName,
              style: AppDesignSystem.headlineSmall.copyWith(
                color: Theme.of(context).colorScheme.onPrimary,
              ),
            ),
            if (!widget.isGroupChat) ...[
              const SizedBox(height: 2),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_otherUserIsOnline == true) ...[
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: Colors.green,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Online',
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).colorScheme.onPrimary.withOpacity(0.8),
                        fontWeight: FontWeight.normal,
                      ),
                    ),
                  ] else if (_otherUserLastSeen != null) ...[
                    Text(
                      _formatLastSeen(_otherUserLastSeen),
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).colorScheme.onPrimary.withOpacity(0.8),
                        fontWeight: FontWeight.normal,
                      ),
                    ),
                  ] else ...[
                    Text(
                      'Loading...',
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).colorScheme.onPrimary.withOpacity(0.8),
                        fontWeight: FontWeight.normal,
                      ),
                    ),
                  ],
                ],
              ),
            ] else ...[
              const SizedBox(height: 2),
              Text(
                'Group Chat',
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.onPrimary.withOpacity(0.8),
                  fontWeight: FontWeight.normal,
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
          if (widget.isGroupChat)
            IconButton(
              icon: const Icon(Icons.group),
              onPressed: () => _showGroupInfo(),
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
                          horizontal: isWideScreen ? 24.0 : 0.0,
                          vertical: 8.0,
                        ),
                        itemBuilder: (context, index) {
                          return _buildMessageBubble(_messages[index]);
                        },
                      ),
          ),
          // Enhanced chat input with emoji picker and media attachment
          EnhancedChatInput(
            controller: _messageController,
            onSendMessage: _sendMessage,
            onSendMedia: _sendMediaMessage,
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
