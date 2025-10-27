// =============================================================================
// CHAT SCREEN - MONGODB VERSION
// =============================================================================
// This screen displays individual chat conversations using MongoDB
// It handles message sending, media uploads, and real-time updates

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'dart:async';
import 'dart:io';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../services/theme_service.dart';
import '../services/mongodb_chat_service.dart';
import '../services/logger_service.dart';
import '../services/physical_auth_service.dart';
import '../services/media_cache_service.dart';
import '../utils/group_chat_naming_utility.dart';
import '../widgets/enhanced_chat_input.dart';
import '../widgets/enhanced_media_preview.dart';
import '../widgets/full_screen_media_preview.dart';
import '../services/realtime_service.dart';
import '../services/active_chat_service.dart';
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
  late ThemeService _themeService;
  final RealtimeService _realtime = RealtimeService.instance;
  final ActiveChatService _activeChat = ActiveChatService.instance;
  
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
  }

  @override
  void dispose() {
    _messagesSubscription?.cancel();
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
        
        _scrollToBottom();
      }
    } catch (e) {
      Log.e('Error loading messages', 'CHAT_SCREEN_MONGODB', e);
    }
  }

  void _startMessageListener() {
    _messagesSubscription = _chatService.watchChatMessages(widget.chatId).listen(
      (messages) {
        if (mounted) {
          setState(() {
            _messages = messages;
          });
          // Mark incoming messages as read when viewing the chat
          _markMessagesAsRead(_messages);
          _scrollToBottom();
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
      final messageIds = messages
          .where((m) => _extractSenderId(m) != _currentUserId)
          .map((m) => _extractMessageId(m))
          .whereType<String>()
          .toList();
      if (messageIds.isEmpty) return;
      await _chatService.markMessagesAsRead(widget.chatId, messageIds);
    } catch (e) {
      Log.e('Error marking messages as read', 'CHAT_SCREEN_MONGODB', e);
    }
  }

  Future<void> _resetUnreadCount() async {
    try {
      if (_currentUserId == null) return;
      
      // Call API to reset unread count for this chat
      final token = await _authService.getToken();
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

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
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
      if (result == null) {
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

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
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
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        GestureDetector(
                          onTap: () => _showFullScreenMedia(mediaUrl, 'document', content),
                          child: Container(
                            width: 200,
                            height: 80,
                            decoration: BoxDecoration(
                              color: isCurrentUser
                                  ? AppDesignSystem.warningColor
                                  : Theme.of(context).colorScheme.surfaceVariant,
                              borderRadius: BorderRadius.circular(AppDesignSystem.radiusMD),
                            ),
                            child: Row(
                              children: [
                                const SizedBox(width: 12),
                                Icon(
                                  Icons.description,
                                  color: isCurrentUser 
                                      ? Colors.white 
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
                                        content.isNotEmpty ? content : 'Document',
                                        style: AppDesignSystem.bodyMedium.copyWith(
                                          color: isCurrentUser 
                                              ? Colors.white 
                                              : Theme.of(context).colorScheme.onSurface,
                                          fontWeight: FontWeight.w500,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        'Tap to open',
                                        style: AppDesignSystem.bodySmall.copyWith(
                                          color: isCurrentUser 
                                              ? Colors.white70 
                                              : Theme.of(context).colorScheme.onSurfaceVariant,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Icon(
                                  Icons.download,
                                  color: isCurrentUser 
                                      ? Colors.white70 
                                      : Theme.of(context).colorScheme.onSurfaceVariant,
                                  size: 20,
                                ),
                                const SizedBox(width: 12),
                              ],
                            ),
                          ),
                        ),
                      ],
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
                  Text(
                    _formatTimestamp(timestamp),
                    style: AppDesignSystem.bodySmall.copyWith(
                      color: isCurrentUser
                          ? Theme.of(context).colorScheme.onPrimary.withOpacity(0.7)
                          : Theme.of(context).colorScheme.onSurfaceVariant,
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

  void _showFullScreenMedia(String mediaUrl, String mediaType, String fileName) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => FullScreenMediaPreview(
          mediaUrl: mediaUrl,
          mediaType: mediaType,
          fileName: fileName.isNotEmpty ? fileName : null,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.chatName,
          style: AppDesignSystem.headlineSmall.copyWith(
            color: Theme.of(context).colorScheme.onPrimary,
          ),
        ),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Theme.of(context).colorScheme.onPrimary,
        elevation: 0,
        centerTitle: false,
        actions: [
          if (widget.isGroupChat)
            IconButton(
              icon: const Icon(Icons.group),
              onPressed: () {
                // TODO: Show group info
              },
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
    // Use EnhancedMediaPreview for consistent media handling across platforms
    return GestureDetector(
      onTap: () => _showFullScreenMedia(mediaUrl, 'image', 'Image'),
      child: Container(
        constraints: const BoxConstraints(
          maxWidth: 250,
          maxHeight: 250,
        ),
        child: EnhancedMediaPreview(
          mediaUrl: mediaUrl,
          mediaType: 'image',
          onTap: () => _showFullScreenMedia(mediaUrl, 'image', 'Image'),
          maxWidth: 250,
          maxHeight: 200,
          enableRetry: true,
        ),
      ),
    );
  }
}
