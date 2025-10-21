// =============================================================================
// ENHANCED CHAT SCREEN - MODERN UI FOR ALL PLATFORMS
// =============================================================================
// This enhanced chat screen provides a modern, responsive UI for Android, iOS, and Web
// with improved media handling, better animations, and platform-specific optimizations

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
import '../widgets/modern_message_bubble.dart';
import '../widgets/typing_indicator.dart';
import '../widgets/chat_header.dart';

class EnhancedChatScreen extends StatefulWidget {
  final String chatId;
  final String chatName;
  final bool isGroupChat;
  final List<String>? userIds;

  const EnhancedChatScreen({
    Key? key,
    required this.chatId,
    required this.chatName,
    this.isGroupChat = false,
    this.userIds,
  }) : super(key: key);

  @override
  State<EnhancedChatScreen> createState() => _EnhancedChatScreenState();
}

class _EnhancedChatScreenState extends State<EnhancedChatScreen>
    with TickerProviderStateMixin {
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _messageController = TextEditingController();
  final MongoDBChatService _chatService = MongoDBChatService();
  final ThemeService _themeService = ThemeService();
  final RealtimeService _realtimeService = RealtimeService();
  final ActiveChatService _activeChatService = ActiveChatService();

  List<Map<String, dynamic>> _messages = [];
  bool _isLoading = true;
  bool _isSending = false;
  String? _currentUserId;
  String? _currentUserDisplayName;
  StreamSubscription? _messagesSubscription;
  StreamSubscription? _typingSubscription;
  bool _isTyping = false;
  String? _typingUser;
  late AnimationController _typingAnimationController;
  late Animation<double> _typingAnimation;

  @override
  void initState() {
    super.initState();
    _initializeChat();
    _setupAnimations();
    _setupRealtimeListeners();
  }

  void _setupAnimations() {
    _typingAnimationController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    _typingAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _typingAnimationController,
      curve: Curves.easeInOut,
    ));
  }

  Future<void> _initializeChat() async {
    try {
      final authService = PhysicalAuthService();
      final user = await authService.getCurrentUser();
      if (user != null) {
        setState(() {
          _currentUserId = user['id'];
          _currentUserDisplayName = user['displayName'] ?? user['name'] ?? 'User';
        });
      }

      await _loadMessages();
      await _activeChatService.setActiveChat(widget.chatId);
    } catch (e) {
      Log.e('Error initializing chat', 'ENHANCED_CHAT_SCREEN', e);
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _setupRealtimeListeners() {
    // Listen to messages
    _messagesSubscription = _realtimeService
        .getMessagesStream(widget.chatId)
        .listen((messages) {
      if (mounted) {
        setState(() {
          _messages = messages;
        });
        _scrollToBottom();
      }
    });

    // Listen to typing indicators
    _typingSubscription = _realtimeService
        .getTypingStream(widget.chatId)
        .listen((typingData) {
      if (mounted && typingData['userId'] != _currentUserId) {
        setState(() {
          _isTyping = typingData['isTyping'] ?? false;
          _typingUser = typingData['userName'];
        });

        if (_isTyping) {
          _typingAnimationController.repeat(reverse: true);
        } else {
          _typingAnimationController.stop();
        }
      }
    });
  }

  Future<void> _loadMessages() async {
    try {
      final messages = await _chatService.getChatMessages(widget.chatId);
      setState(() {
        _messages = messages;
      });
      _scrollToBottom();
    } catch (e) {
      Log.e('Error loading messages', 'ENHANCED_CHAT_SCREEN', e);
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

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty || _isSending) return;

    setState(() {
      _isSending = true;
    });

    try {
      final result = await _chatService.sendMessage(
        widget.chatId,
        text,
      );
      
      if (result != null) {
        _messageController.clear();
        _realtimeService.stopTyping(widget.chatId, _currentUserId!);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to send message'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      Log.e('Error sending message', 'ENHANCED_CHAT_SCREEN', e);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error sending message: $e'),
            backgroundColor: Colors.red,
          ),
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
        content: content,
      );
      
      if (result == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to send media'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      Log.e('Error sending media', 'ENHANCED_CHAT_SCREEN', e);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error sending media: $e'),
            backgroundColor: Colors.red,
          ),
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

  void _onTextChanged(String text) {
    if (text.isNotEmpty) {
      _realtimeService.startTyping(widget.chatId, _currentUserId!, _currentUserDisplayName!);
    } else {
      _realtimeService.stopTyping(widget.chatId, _currentUserId!);
    }
  }

  void _showFullScreenMedia(String mediaUrl, String type, String caption) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => FullScreenMediaPreview(
          mediaUrl: mediaUrl,
          mediaType: type,
          caption: caption,
        ),
      ),
    );
  }

  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inDays > 0) {
      return '${timestamp.day}/${timestamp.month}/${timestamp.year}';
    } else if (difference.inHours > 0) {
      return '${timestamp.hour}:${timestamp.minute.toString().padLeft(2, '0')}';
    } else {
      return '${timestamp.minute.toString().padLeft(2, '0')}';
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _messageController.dispose();
    _messagesSubscription?.cancel();
    _typingSubscription?.cancel();
    _typingAnimationController.dispose();
    _activeChatService.clearActiveChat();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final screenWidth = MediaQuery.of(context).size.width;
    final isWeb = kIsWeb;
    final isMobile = !isWeb && (screenWidth < 768);

    return Scaffold(
      backgroundColor: isDark ? Colors.grey[900] : Colors.grey[50],
      body: SafeArea(
        child: Column(
          children: [
            // Enhanced Chat Header
            ChatHeader(
              chatName: widget.chatName,
              isGroupChat: widget.isGroupChat,
              onBack: () => Navigator.pop(context),
              onInfo: () => _showChatInfo(),
              onSearch: () => _showSearch(),
            ),

            // Messages List
            Expanded(
              child: _isLoading
                  ? Center(
                      child: CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(
                          theme.primaryColor,
                        ),
                      ),
                    )
                  : _messages.isEmpty
                      ? _buildEmptyState()
                      : ListView.builder(
                          controller: _scrollController,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          itemCount: _messages.length + (_isTyping ? 1 : 0),
                          itemBuilder: (context, index) {
                            if (index == _messages.length && _isTyping) {
                              return TypingIndicator(
                                userName: _typingUser,
                                animation: _typingAnimation,
                              );
                            }

                            final message = _messages[index];
                            return ModernMessageBubble(
                              message: message,
                              isCurrentUser: message['senderId'] == _currentUserId,
                              isGroupChat: widget.isGroupChat,
                              onMediaTap: _showFullScreenMedia,
                              timestamp: _formatTimestamp,
                            );
                          },
                        ),
            ),

            // Enhanced Chat Input
            EnhancedChatInput(
              controller: _messageController,
              onSendMessage: _sendMessage,
              onSendMedia: _sendMediaMessage,
              chatId: widget.chatId,
              isEnabled: !_isSending,
              onTextChanged: _onTextChanged,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.chat_bubble_outline,
            size: 64,
            color: isDark ? Colors.grey[600] : Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            'Start a conversation',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w500,
              color: isDark ? Colors.grey[300] : Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Send a message to begin chatting',
            style: TextStyle(
              fontSize: 14,
              color: isDark ? Colors.grey[500] : Colors.grey[500],
            ),
          ),
        ],
      ),
    );
  }

  void _showChatInfo() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.7,
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                widget.isGroupChat ? 'Group Info' : 'Chat Info',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Chat ID: ${widget.chatId}'),
                    Text('Chat Name: ${widget.chatName}'),
                    Text('Type: ${widget.isGroupChat ? 'Group' : 'Private'}'),
                    if (widget.userIds != null)
                      Text('Members: ${widget.userIds!.length}'),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showSearch() {
    // TODO: Implement search functionality
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Search functionality coming soon!')),
    );
  }
}
