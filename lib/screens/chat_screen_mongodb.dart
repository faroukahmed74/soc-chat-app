// =============================================================================
// CHAT SCREEN - MONGODB VERSION
// =============================================================================
// This screen displays individual chat conversations using MongoDB
// It handles message sending, media uploads, and real-time updates

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'dart:async';
import 'dart:typed_data';
import '../services/theme_service.dart';
import '../services/mongodb_chat_service.dart';
import '../services/logger_service.dart';
import '../services/physical_auth_service.dart';
import '../widgets/enhanced_media_sender.dart';
import '../widgets/enhanced_chat_input.dart';
import '../widgets/full_screen_media_preview.dart';
import '../services/realtime_service.dart';
import '../services/active_chat_service.dart';

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
    return (n ?? 'Unknown').toString();
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
        // Mark messages as read for those not sent by current user
        await _markMessagesAsRead(_messages);
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
              backgroundColor: _themeService.isDarkMode ? Colors.grey[700] : Colors.grey[300],
              child: Text(
                senderName.isNotEmpty ? senderName[0].toUpperCase() : 'U',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: isCurrentUser
                    ? (_themeService.isDarkMode ? Colors.blue[700] : Colors.blue[500])
                    : (_themeService.isDarkMode ? Colors.grey[800] : Colors.grey[200]),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (!isCurrentUser && widget.isGroupChat)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text(
                        senderName,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: isCurrentUser
                              ? Colors.white70
                              : (_themeService.isDarkMode ? Colors.white70 : Colors.black54),
                        ),
                      ),
                    ),
                  if (messageType == 'text')
                    Text(
                      content,
                      style: TextStyle(
                        color: isCurrentUser
                            ? Colors.white
                            : (_themeService.isDarkMode ? Colors.white : Colors.black87),
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
                            child: Image.network(
                              mediaUrl,
                              width: 200,
                              height: 200,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) {
                                return Container(
                                  width: 200,
                                  height: 200,
                                  color: Colors.grey[300],
                                  child: const Icon(Icons.broken_image),
                                );
                              },
                            ),
                          ),
                        ),
                        if (content.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                              content,
                              style: TextStyle(
                                color: isCurrentUser
                                    ? Colors.white
                                    : (_themeService.isDarkMode ? Colors.white : Colors.black87),
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
                              color: Colors.black,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Stack(
                              children: [
                                // Video thumbnail placeholder
                                Container(
                                  width: 200,
                                  height: 150,
                                  decoration: BoxDecoration(
                                    color: Colors.grey[800],
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Icon(
                                    Icons.videocam,
                                    color: Colors.white54,
                                    size: 40,
                                  ),
                                ),
                                // Play button overlay
                                const Center(
                                  child: Icon(
                                    Icons.play_circle_filled,
                                    color: Colors.white,
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
                              style: TextStyle(
                                color: isCurrentUser
                                    ? Colors.white
                                    : (_themeService.isDarkMode ? Colors.white : Colors.black87),
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
                                  ? Colors.blue[600]
                                  : (_themeService.isDarkMode ? Colors.grey[700] : Colors.grey[300]),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              children: [
                                const SizedBox(width: 12),
                                Icon(
                                  messageType == 'voice' ? Icons.mic : Icons.music_note,
                                  color: isCurrentUser ? Colors.white : Colors.grey[600],
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
                                        style: TextStyle(
                                          color: isCurrentUser ? Colors.white : Colors.black87,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        'Tap to play',
                                        style: TextStyle(
                                          color: isCurrentUser ? Colors.white70 : Colors.grey[600],
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Icon(
                                  Icons.play_circle_filled,
                                  color: isCurrentUser ? Colors.white : Colors.grey[600],
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
                              style: TextStyle(
                                color: isCurrentUser
                                    ? Colors.white
                                    : (_themeService.isDarkMode ? Colors.white : Colors.black87),
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
                                  ? Colors.orange[600]
                                  : (_themeService.isDarkMode ? Colors.grey[700] : Colors.grey[300]),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              children: [
                                const SizedBox(width: 12),
                                const Icon(
                                  Icons.description,
                                  color: Colors.white,
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
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w500,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 4),
                                      const Text(
                                        'Tap to open',
                                        style: TextStyle(
                                          color: Colors.white70,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 12),
                                const Icon(
                                  Icons.download,
                                  color: Colors.white70,
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
                      style: TextStyle(
                        color: isCurrentUser
                            ? Colors.white
                            : (_themeService.isDarkMode ? Colors.white : Colors.black87),
                      ),
                    ),
                  const SizedBox(height: 4),
                  Text(
                    _formatTimestamp(timestamp),
                    style: TextStyle(
                      fontSize: 10,
                      color: isCurrentUser
                          ? Colors.white70
                          : (_themeService.isDarkMode ? Colors.white54 : Colors.black54),
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
              backgroundColor: _themeService.isDarkMode ? Colors.blue[700] : Colors.blue[500],
              child: Text(
                _currentUserName?.isNotEmpty == true ? _currentUserName![0].toUpperCase() : 'U',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
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
        title: Text(widget.chatName),
        backgroundColor: _themeService.isDarkMode ? Colors.grey[900] : Colors.blue,
        foregroundColor: Colors.white,
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
                          style: TextStyle(
                            color: _themeService.isDarkMode ? Colors.white54 : Colors.black54,
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
}
