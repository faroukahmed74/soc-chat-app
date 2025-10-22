// =============================================================================
// CHAT SCREEN WEB - MONGODB VERSION
// =============================================================================
// This screen displays individual chat conversations using MongoDB
// It handles message sending, media uploads, and real-time updates for web

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'dart:async';
import '../services/theme_service.dart';
import '../services/mongodb_chat_service.dart';
import '../services/logger_service.dart';
import '../services/physical_auth_service.dart';
import '../widgets/enhanced_chat_input.dart';
import '../widgets/enhanced_media_preview.dart';
import '../widgets/enhanced_responsive_media_preview.dart';

class ChatScreenWebMongoDB extends StatefulWidget {
  final String chatId;
  final String chatName;
  final bool isGroupChat;
  final List<String>? userIds;

  const ChatScreenWebMongoDB({
    Key? key,
    required this.chatId,
    required this.chatName,
    this.isGroupChat = false,
    this.userIds,
  }) : super(key: key);

  @override
  State<ChatScreenWebMongoDB> createState() => _ChatScreenWebMongoDBState();
}

class _ChatScreenWebMongoDBState extends State<ChatScreenWebMongoDB> {
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

  @override
  void initState() {
    super.initState();
    _themeService = ThemeService.instance;
    _themeService.addListener(() {
      if (mounted) setState(() {});
    });
    _initializeChat();
  }

  @override
  void dispose() {
    _messagesSubscription?.cancel();
    _messageController.dispose();
    _scrollController.dispose();
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
    } catch (e) {
      Log.e('Error initializing chat', 'CHAT_SCREEN_WEB_MONGODB', e);
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
    try {
      final messages = await _chatService.getChatMessages(widget.chatId);
      if (mounted) {
        setState(() {
          _messages = messages;
        });
        _scrollToBottom();
      }
    } catch (e) {
      Log.e('Error loading messages', 'CHAT_SCREEN_WEB_MONGODB', e);
    }
  }

  void _startMessageListener() {
    _messagesSubscription = _chatService.watchChatMessages(widget.chatId).listen(
      (messages) {
        if (mounted) {
          setState(() {
            _messages = messages;
          });
          _scrollToBottom();
        }
      },
      onError: (error) {
        Log.e('Error in message stream', 'CHAT_SCREEN_WEB_MONGODB', error);
      },
    );
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

    setState(() {
      _isSending = true;
    });

    try {
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
      Log.e('Error sending message', 'CHAT_SCREEN_WEB_MONGODB', e);
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
      Log.e('Error sending media', 'CHAT_SCREEN_WEB_MONGODB', e);
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
    final isCurrentUser = message['senderId'] == _currentUserId;
    final content = message['content'] ?? '';
    final messageType = message['messageType'] ?? 'text';
    final timestamp = message['timestamp'] != null 
        ? DateTime.parse(message['timestamp'])
        : DateTime.now();
    final senderName = message['senderName'] ?? 'Unknown';

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
                          onTap: () => _showFullScreenMedia(message['mediaUrl'] ?? '', 'image', content),
                          child: Container(
                            constraints: const BoxConstraints(
                              maxWidth: 200,
                              maxHeight: 200,
                            ),
                            child: EnhancedMediaPreview(
                              mediaUrl: message['mediaUrl'] ?? '',
                              mediaType: 'image',
                              fileName: content,
                              onTap: () => _showFullScreenMedia(message['mediaUrl'] ?? '', 'image', content),
                              maxWidth: 200,
                              maxHeight: 200,
                              enableRetry: true,
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
                        Container(
                          constraints: const BoxConstraints(
                            maxWidth: 200,
                            maxHeight: 150,
                          ),
                          child: EnhancedMediaPreview(
                            mediaUrl: message['mediaUrl'] ?? '',
                            mediaType: 'video',
                            fileName: content,
                            onTap: () => _showFullScreenMedia(message['mediaUrl'] ?? '', 'video', content),
                            maxWidth: 200,
                            maxHeight: 150,
                            enableRetry: true,
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
        builder: (context) => EnhancedFullScreenMediaPreview(
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
