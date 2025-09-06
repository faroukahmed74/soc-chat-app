// =============================================================================
// CHAT SCREEN
// =============================================================================
// This screen displays individual chat conversations between users or groups.
// It handles message sending, media uploads, real-time updates, and group management.

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:async';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import '../services/theme_service.dart';

import '../services/enhanced_media_service.dart';
import '../services/document_service.dart';
import '../services/logger_service.dart';
import '../services/chat_management_service.dart';
import '../services/fcm_notification_service.dart';
import '../utils/responsive_utils.dart';
import '../widgets/enhanced_media_preview.dart';
import '../widgets/voice_message_player.dart';



import '../services/upload_progress_service.dart';
import '../widgets/upload_progress_manager.dart';
import 'upload_progress_demo_screen.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:audioplayers/src/source.dart';
import 'package:path_provider/path_provider.dart';

import 'dart:io';
import 'package:flutter/foundation.dart';
import 'dart:math';
import 'package:url_launcher/url_launcher.dart';
import '../widgets/in_app_video_player.dart';


class ChatScreen extends StatefulWidget {
  final String chatId;
  final bool isGroupChat;
  final String chatName;
  final List<String>? userIds;

  const ChatScreen({
    super.key,
    required this.chatId,
    required this.isGroupChat,
    required this.chatName,
    this.userIds,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> with TickerProviderStateMixin {
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  final _searchController = TextEditingController();
  
  bool _isTyping = false;
  
  // Voice messaging - Independent players for each message
  final Map<String, AudioPlayer> _audioPlayers = {};
  final Map<String, bool> _isPlayingMap = {};
  final Map<String, Duration> _positionMap = {};
  final Map<String, Duration> _durationMap = {};
  
  bool _isSearching = false;
  String _searchQuery = '';
  List<QueryDocumentSnapshot> _searchResults = [];
  
  bool _isLoadingMoreMessages = false;
  int _messageLimit = 20;
  bool _hasMoreMessages = true;
  DocumentSnapshot? _lastMessage;
  
  late String _currentUserId;
  String? _currentUserDisplayName;
  bool _isAdmin = false;
  String? _groupKey;
  
  late ThemeService _themeService;
  final Map<String, String> _messageStatuses = {};
  final Map<String, Map<String, dynamic>> _messageCache = {};
  StreamSubscription<QuerySnapshot>? _messagesSubscription;
  
  // FCM Notification Service
  final FCMNotificationService _fcmService = FCMNotificationService();
  
  // Sending indicators
  final Map<String, bool> _sendingMessages = {};
  final Map<String, String> _sendingMessageIds = {};
  
  // Animation controllers for enhanced UI
  late AnimationController _fadeController;
  late AnimationController _slideController;
  late AnimationController _scaleController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _themeService = ThemeService.instance;
    _currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';
    
    // Initialize animation controllers
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );
    _scaleController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeInOut),
    );
    _slideAnimation = Tween<Offset>(begin: const Offset(0, 0.3), end: Offset.zero).animate(
      CurvedAnimation(parent: _slideController, curve: Curves.easeOutCubic),
    );
    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _scaleController, curve: Curves.elasticOut),
    );
    
    _initializeChat();
    _scrollController.addListener(_onScroll);
    
    // Subscribe to chat topic for notifications
    _subscribeToChatTopic();
    
    // Start animations
    _fadeController.forward();
    _slideController.forward();
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    _searchController.dispose();

    _messagesSubscription?.cancel();
    
    // Dispose animation controllers
    _fadeController.dispose();
    _slideController.dispose();
    _scaleController.dispose();
    _audioPlayers.values.forEach((player) => player.dispose());
    
    super.dispose();
  }

  Future<void> _initializeChat() async {
    try {
      _loadCurrentUserInfo();
      if (widget.isGroupChat && widget.userIds != null) {
        _loadGroupInfo();
      }
      _startMessageStream();
    } catch (e) {
      Log.e('Error initializing chat', 'CHAT_SCREEN', e);
    }
  }

  Future<void> _loadCurrentUserInfo() async {
    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(_currentUserId)
          .get();
      
      if (userDoc.exists && mounted) {
        final userData = userDoc.data() as Map<String, dynamic>;
        setState(() {
          _currentUserDisplayName = userData['displayName'] ?? 'User';
        });
      }
    } catch (e) {
      Log.e('Error loading current user info', 'CHAT_SCREEN', e);
    }
  }

  Future<void> _loadGroupInfo() async {
    try {
      final groupDoc = await FirebaseFirestore.instance
          .collection('groups')
          .doc(widget.chatId)
          .get();
      
      if (groupDoc.exists && mounted) {
        final groupData = groupDoc.data() as Map<String, dynamic>;
        setState(() {
          _isAdmin = groupData['adminIds']?.contains(_currentUserId) ?? false;
          _groupKey = groupData['groupKey'];
        });
      }
    } catch (e) {
      Log.e('Error loading group info', 'CHAT_SCREEN', e);
    }
  }

  /// Subscribe to chat topic for FCM notifications
  Future<void> _subscribeToChatTopic() async {
    try {
              // FCM topic subscription will be handled by FCMNotificationService
      Log.i('Subscribed to chat topic: ${widget.chatId}', 'CHAT_SCREEN');
    } catch (e) {
      Log.e('Error subscribing to chat topic', 'CHAT_SCREEN', e);
    }
  }

  void _startMessageStream() {
    _messagesSubscription?.cancel();
    
    final query = FirebaseFirestore.instance
        .collection('chats')
        .doc(widget.chatId)
        .collection('messages')
        .orderBy('timestamp', descending: true)
        .limit(_messageLimit);
    
    _messagesSubscription = query.snapshots().listen(
      (snapshot) {
        if (mounted) {
          setState(() {
            if (snapshot.docs.isNotEmpty) {
              _lastMessage = snapshot.docs.last;
            }
            _hasMoreMessages = snapshot.docs.length >= _messageLimit;
          });
          
          if (snapshot.docs.isNotEmpty) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _markMessagesAsRead(snapshot.docs);
            });
          }
        }
      },
      onError: (error) {
        Log.e('Error in message stream', 'CHAT_SCREEN', error);
      },
    );
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= 
        _scrollController.position.maxScrollExtent - 200) {
      _loadMoreMessages();
    }
  }

  Future<void> _loadMoreMessages() async {
    if (_isLoadingMoreMessages || !_hasMoreMessages || _lastMessage == null) {
      return;
    }

    setState(() {
      _isLoadingMoreMessages = true;
    });

    try {
      final query = FirebaseFirestore.instance
          .collection('chats')
          .doc(widget.chatId)
          .collection('messages')
          .orderBy('timestamp', descending: true)
          .startAfterDocument(_lastMessage!)
          .limit(_messageLimit);

      final snapshot = await query.get();
      
      if (mounted) {
        setState(() {
          _hasMoreMessages = snapshot.docs.length >= _messageLimit;
          if (snapshot.docs.length > 0) {
            _lastMessage = snapshot.docs.last;
          }
          _isLoadingMoreMessages = false;
        });
      }
    } catch (e) {
      Log.e('Error loading more messages', 'CHAT_SCREEN', e);
      if (mounted) {
        setState(() {
          _isLoadingMoreMessages = false;
        });
      }
    }
  }

  Future<String> _getUserDisplayName(String userId) async {
    try {
      if (_messageCache.containsKey(userId)) {
        return _messageCache[userId]!['displayName'] ?? 'Unknown User';
      }
      
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .get();
      
      if (userDoc.exists) {
        final userData = userDoc.data() as Map<String, dynamic>;
        final displayName = userData['displayName'] ?? 'Unknown User';
        
        _messageCache[userId] = {'displayName': displayName};
        return displayName;
      }
      
      return 'Unknown User';
    } catch (e) {
      Log.e('Error fetching user display name', 'CHAT_SCREEN', e);
      return 'Unknown User';
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = _themeService.isDarkMode;
    final isMobile = ResponsiveUtils.isMobile(context);
    final isTablet = ResponsiveUtils.isTablet(context);
    
    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF121212) : const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.2),
              child: Icon(
                widget.isGroupChat ? Icons.group : Icons.person,
                color: theme.colorScheme.primary,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    widget.chatName,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (widget.isGroupChat)
                    Text(
                      'Group Chat',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.white70,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
        backgroundColor: theme.colorScheme.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            bottom: Radius.circular(20),
          ),
        ),
        actions: [
          IconButton(
            onPressed: () => _themeService.toggleTheme(),
            icon: AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: Icon(
                _themeService.isDarkMode ? Icons.light_mode : Icons.dark_mode,
                key: ValueKey(_themeService.isDarkMode),
                color: Colors.white,
              ),
            ),
            tooltip: 'Toggle Theme',
          ),
          if (widget.isGroupChat) ...[
            IconButton(
              onPressed: _showGroupInfo,
              icon: const Icon(Icons.info_outline),
              tooltip: 'Group Info',
            ),
          ],
          IconButton(
            onPressed: () {
              setState(() {
                _isSearching = !_isSearching;
                if (!_isSearching) {
                  _searchQuery = '';
                  _searchResults = [];
                }
              });
            },
            icon: Icon(_isSearching ? Icons.close : Icons.search),
            tooltip: _isSearching ? 'Close Search' : 'Search Messages',
          ),
        ],
      ),
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              children: [
                // Add keyboard-aware spacing
                SizedBox(height: MediaQuery.of(context).viewInsets.bottom > 0 ? 8 : 0),
              if (_isSearching) ...[
                SlideTransition(
                  position: _slideAnimation,
                  child: Container(
                    margin: EdgeInsets.all(isMobile ? 12 : 16),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                      borderRadius: BorderRadius.circular(isMobile ? 20 : 25),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.1),
                          blurRadius: isMobile ? 8 : 10,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: TextField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        hintText: 'Search messages...',
                        hintStyle: TextStyle(
                          color: isDark ? Colors.white60 : Colors.grey[600],
                          fontSize: isMobile ? 14 : 16,
                        ),
                        prefixIcon: Icon(
                          Icons.search,
                          color: theme.colorScheme.primary,
                          size: isMobile ? 20 : 24,
                        ),
                        suffixIcon: IconButton(
                          onPressed: () {
                            setState(() {
                              _isSearching = false;
                              _searchQuery = '';
                              _searchResults = [];
                            });
                          },
                          icon: Icon(
                            Icons.close,
                            size: isMobile ? 20 : 24,
                          ),
                          color: Colors.grey[600],
                        ),
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: isMobile ? 16 : 20,
                          vertical: isMobile ? 12 : 16,
                        ),
                      ),
                      style: TextStyle(
                        color: isDark ? Colors.white : Colors.black87,
                        fontSize: isMobile ? 14 : 16,
                      ),
                      onSubmitted: _searchMessages,
                    ),
                  ),
                ),
              ],
              
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('chats')
                      .doc(widget.chatId)
                      .collection('messages')
                      .orderBy('timestamp', descending: true)
                      .limit(_messageLimit)
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.hasError) {
                      return FadeTransition(
                        opacity: _fadeAnimation,
                        child: Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(24),
                                decoration: BoxDecoration(
                                  color: Colors.orange.withValues(alpha: 0.1),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.error_outline,
                                  size: 64,
                                  color: Colors.orange,
                                ),
                              ),
                              const SizedBox(height: 24),
                              Text(
                                'Error loading messages',
                                style: TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: isDark ? Colors.white : Colors.black87,
                                ),
                              ),
                              const SizedBox(height: 12),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                                decoration: BoxDecoration(
                                  color: Colors.orange.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(15),
                                  border: Border.all(
                                    color: Colors.orange.withValues(alpha: 0.3),
                                  ),
                                ),
                                child: Text(
                                  'Error: ${snapshot.error}',
                                  style: const TextStyle(
                                    fontSize: 14,
                                    color: Colors.orange,
                                    fontWeight: FontWeight.w500,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                              const SizedBox(height: 24),
                              ElevatedButton.icon(
                                onPressed: _retryLoading,
                                icon: const Icon(Icons.refresh),
                                label: const Text('Retry'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.orange,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(25),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }
                    
                    final messages = snapshot.data?.docs ?? [];
                    
                    if (messages.isNotEmpty) {
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        _markMessagesAsRead(messages);
                      });
                    }
                    
                    if (messages.isEmpty) {
                      return FadeTransition(
                        opacity: _fadeAnimation,
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            final availableHeight = constraints.maxHeight;
                            final isMobile = ResponsiveUtils.isMobile(context);
                            
                            // Calculate responsive sizing based on available space
                            final iconSize = availableHeight > 400 ? 64.0 : (availableHeight > 300 ? 48.0 : 32.0);
                            final iconPadding = availableHeight > 400 ? 24.0 : (availableHeight > 300 ? 16.0 : 12.0);
                            final titleFontSize = availableHeight > 400 ? 24.0 : (availableHeight > 300 ? 20.0 : 16.0);
                            final subtitleFontSize = availableHeight > 400 ? 16.0 : (availableHeight > 300 ? 14.0 : 12.0);
                            final spacing = availableHeight > 400 ? 24.0 : (availableHeight > 300 ? 16.0 : 8.0);
                            
                            return Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    padding: EdgeInsets.all(iconPadding),
                                    decoration: BoxDecoration(
                                      color: theme.colorScheme.primary.withValues(alpha: 0.1),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(
                                      Icons.chat_bubble_outline,
                                      size: iconSize,
                                      color: theme.colorScheme.primary,
                                    ),
                                  ),
                                  SizedBox(height: spacing),
                                  Text(
                                    'No messages yet',
                                    style: TextStyle(
                                      fontSize: titleFontSize,
                                      fontWeight: FontWeight.bold,
                                      color: isDark ? Colors.white : Colors.black87,
                                    ),
                                  ),
                                  SizedBox(height: spacing / 2),
                                  Text(
                                    'Start the conversation!',
                                    style: TextStyle(
                                      fontSize: subtitleFontSize,
                                      color: isDark ? Colors.white70 : Colors.grey[600],
                                    ),
                                  ),
                                  if (availableHeight > 350) ...[
                                    SizedBox(height: spacing),
                                    Container(
                                      padding: EdgeInsets.symmetric(
                                        horizontal: isMobile ? 16 : 24, 
                                        vertical: isMobile ? 8 : 12,
                                      ),
                                      decoration: BoxDecoration(
                                        color: theme.colorScheme.primary.withValues(alpha: 0.1),
                                        borderRadius: BorderRadius.circular(isMobile ? 20 : 25),
                                        border: Border.all(
                                          color: theme.colorScheme.primary.withValues(alpha: 0.3),
                                        ),
                                      ),
                                      child: Text(
                                        '👋 Say hello to get started!',
                                        style: TextStyle(
                                          fontSize: isMobile ? 12 : 14,
                                          color: theme.colorScheme.primary,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            );
                          },
                        ),
                      );
                    }
                    
                    return ListView.builder(
                      reverse: true,
                      controller: _scrollController,
                      itemCount: messages.length + _sendingMessages.length + (_hasMoreMessages ? 1 : 0),
                      itemBuilder: (context, index) {
                        if (index == messages.length + _sendingMessages.length) {
                          return _buildLoadMoreIndicator();
                        }
                        
                        if (index >= messages.length) {
                          // Show sending messages
                          final sendingIndex = index - messages.length;
                          final sendingMessageId = _sendingMessages.keys.elementAt(sendingIndex);
                          final sendingText = _sendingMessageIds[sendingMessageId] ?? '';
                          return _buildSendingMessageBubble(sendingMessageId, sendingText);
                        }
                        
                        final message = messages[index];
                        return _buildMessageBubble(message);
                      },
                    );
                  },
                ),
              ),
              
              Container(
                padding: EdgeInsets.all(isMobile ? 12 : 16),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1A1A1A) : Colors.white,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(20),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      blurRadius: isMobile ? 8 : 10,
                      offset: const Offset(0, -2),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      margin: EdgeInsets.only(bottom: isMobile ? 8 : 12),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                                                    // Media buttons row - made responsive
                          LayoutBuilder(
                            builder: (context, constraints) {
                              final isMobile = ResponsiveUtils.isMobile(context);
                              final buttonSpacing = isMobile ? 6.0 : 8.0;
                              final buttonPadding = isMobile ? 8.0 : 12.0;
                              
                              return SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                child: Row(
                                  children: [
                                    _buildResponsiveMediaButton(
                                      onPressed: () => _pickImageFromGallery(),
                                      icon: Icons.photo_library,
                                      label: 'Gallery',
                                      color: Colors.blue,
                                      tooltip: 'Add Photo from Gallery',
                                      isMobile: isMobile,
                                      padding: buttonPadding,
                                    ),
                                    SizedBox(width: buttonSpacing),
                                    _buildResponsiveMediaButton(
                                      onPressed: () => _pickImageFromCamera(),
                                      icon: Icons.camera_alt,
                                      label: 'Camera',
                                      color: Colors.green,
                                      tooltip: 'Take Photo',
                                      isMobile: isMobile,
                                      padding: buttonPadding,
                                    ),
                                    SizedBox(width: buttonSpacing),
                                    _buildResponsiveMediaButton(
                                      onPressed: () => _pickVideoFromGallery(),
                                      icon: Icons.video_library,
                                      label: 'Video',
                                      color: Colors.red,
                                      tooltip: 'Add Video from Gallery',
                                      isMobile: isMobile,
                                      padding: buttonPadding,
                                    ),
                                    SizedBox(width: buttonSpacing),
                                    _buildResponsiveMediaButton(
                                      onPressed: () => _pickVideoFromCamera(),
                                      icon: Icons.videocam,
                                      label: 'Record',
                                      color: Colors.purple,
                                      tooltip: 'Record Video',
                                      isMobile: isMobile,
                                      padding: buttonPadding,
                                    ),
                                    SizedBox(width: buttonSpacing),
                                    _buildResponsiveMediaButton(
                                      onPressed: () => _pickDocument(),
                                      icon: Icons.attach_file,
                                      label: 'File',
                                      color: Colors.orange,
                                      tooltip: 'Attach File',
                                      isMobile: isMobile,
                                      padding: buttonPadding,
                                    ),

                                  ],
                                ),
                              );
                            },
                          ),
                          

                        ],
                      ),
                    ),
                    
                                        Container(
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                        borderRadius: BorderRadius.circular(isMobile ? 20 : 25),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.1),
                            blurRadius: isMobile ? 8 : 10,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _messageController,
                              decoration: InputDecoration(
                                hintText: 'Type a message...',
                                hintStyle: TextStyle(
                                  color: isDark ? Colors.white60 : Colors.grey[600],
                                  fontSize: isMobile ? 14 : 16,
                                ),
                                border: InputBorder.none,
                                contentPadding: EdgeInsets.symmetric(
                                  horizontal: isMobile ? 16 : 20,
                                  vertical: MediaQuery.of(context).viewInsets.bottom > 0 
                                      ? (isMobile ? 8 : 12) 
                                      : (isMobile ? 12 : 16),
                                ),
                              ),
                              style: TextStyle(
                                color: isDark ? Colors.white : Colors.black87,
                                fontSize: isMobile ? 14 : 16,
                              ),
                              maxLines: null,
                              textCapitalization: TextCapitalization.sentences,
                              onSubmitted: (value) {
                                if (value.trim().isNotEmpty) {
                                  _sendMessage();
                                }
                              },
                            ),
                          ),
                          SizedBox(width: isMobile ? 6 : 8),
                          ValueListenableBuilder<TextEditingValue>(
                            valueListenable: _messageController,
                            builder: (context, value, child) {
                              final hasText = value.text.trim().isNotEmpty;
                              return Container(
                                margin: const EdgeInsets.only(right: 8),
                                decoration: BoxDecoration(
                                  color: hasText 
                                      ? theme.colorScheme.primary
                                      : Colors.grey.shade300,
                                  shape: BoxShape.circle,
                                  boxShadow: hasText ? [
                                    BoxShadow(
                                      color: theme.colorScheme.primary.withValues(alpha: 0.3),
                                      blurRadius: 8,
                                      offset: const Offset(0, 2),
                                    ),
                                  ] : null,
                                ),
                                                            child: ScaleTransition(
                              scale: _scaleAnimation,
                              child: IconButton(
                                onPressed: hasText ? _sendMessage : null,
                                icon: AnimatedSwitcher(
                                  duration: const Duration(milliseconds: 200),
                                  child: Icon(
                                    hasText ? Icons.send : Icons.send,
                                    key: ValueKey(hasText),
                                    color: hasText ? Colors.white : Colors.grey.shade600,
                                    size: 20,
                                  ),
                                ),
                                tooltip: hasText ? 'Send Message' : 'Type a message to send',
                                style: IconButton.styleFrom(
                                  padding: const EdgeInsets.all(12),
                                ),
                              ),
                            ),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          
          // Upload Progress Manager
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: UploadProgressManager(
              onUploadsComplete: () {
                // Optional: Handle when all uploads are complete
              },
            ),
          ),
          
          // Floating Action Button for quick media access
          Positioned(
            right: isMobile ? 12 : 16,
            bottom: isMobile ? 180 : 200,
            child: FloatingActionButton(
              onPressed: () {
                _showMediaOptions(context);
              },
              backgroundColor: theme.colorScheme.primary,
              foregroundColor: Colors.white,
              elevation: isMobile ? 6 : 8,
              mini: isMobile,
              child: Icon(
                Icons.add,
                size: isMobile ? 20 : 24,
              ),
              tooltip: 'Quick Media Options',
            ),
          ),
        ],
      ),
    ),
);
  }

  Widget _buildLoadMoreIndicator() {
    if (_isLoadingMoreMessages) {
      return Container(
        padding: const EdgeInsets.all(20),
        child: Center(
          child: Column(
            children: [
              const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              const SizedBox(height: 12),
              Text(
                'Loading more messages...',
                style: TextStyle(
                  fontSize: 14,
                  color: _themeService.isDarkMode ? Colors.white70 : Colors.grey[600],
                ),
              ),
            ],
          ),
        ),
      );
    }
    
    return Container(
      padding: const EdgeInsets.all(20),
      child: Center(
        child: ElevatedButton.icon(
          onPressed: _loadMoreMessages,
          icon: const Icon(Icons.expand_less, size: 18),
          label: const Text('Load More Messages'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
            foregroundColor: Theme.of(context).colorScheme.primary,
            elevation: 0,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(25),
              side: BorderSide(
                color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.3),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMessageBubble(DocumentSnapshot messageDoc) {
    final data = messageDoc.data() as Map<String, dynamic>;
    final text = data['text'] ?? '';
    final senderId = data['senderId'] ?? '';
    final senderName = data['senderName'] ?? 'Unknown User';
    final timestamp = data['timestamp'] as Timestamp?;
    final messageType = data['type'] ?? 'text';
    final isCurrentUser = senderId == _currentUserId;
    final theme = Theme.of(context);
    final isDark = _themeService.isDarkMode;
    
    return SlideTransition(
      position: _slideAnimation,
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: Container(
          margin: EdgeInsets.only(
            left: isCurrentUser ? 50 : 8,
            right: isCurrentUser ? 8 : 50,
            bottom: 12,
          ),
          child: Row(
            mainAxisAlignment: isCurrentUser ? MainAxisAlignment.end : MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!isCurrentUser) ...[
                CircleAvatar(
                  radius: 18,
                  backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.2),
                  child: Text(
                    _getInitials(senderName),
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
              ],
              Flexible(
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isCurrentUser 
                        ? theme.colorScheme.primary
                        : isDark 
                            ? const Color(0xFF2A2A2A)
                            : Colors.white,
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(20),
                      topRight: const Radius.circular(20),
                      bottomLeft: Radius.circular(isCurrentUser ? 20 : 8),
                      bottomRight: Radius.circular(isCurrentUser ? 8 : 20),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.1),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (!isCurrentUser) ...[
                        Text(
                          senderName,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: isCurrentUser ? Colors.white : theme.colorScheme.primary,
                          ),
                        ),
                        const SizedBox(height: 6),
                      ],
                      _buildMessageContent(data, messageType, isCurrentUser),
                      if (timestamp != null) ...[
                        const SizedBox(height: 8),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              _formatTime(timestamp),
                              style: TextStyle(
                                fontSize: 11,
                                color: isCurrentUser ? Colors.white70 : Colors.grey[600],
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            if (isCurrentUser) ...[
                              const SizedBox(width: 6),
                              _buildMessageStatusIcon(_getMessageStatus(messageDoc.id), isCurrentUser),
                            ],
                          ],
                        ),
                      ],
                      // Add sending indicator for current user's messages
                      if (isCurrentUser && _isMessageSending(messageDoc.id)) ...[
                        const SizedBox(height: 8),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Colors.white70,
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'Sending...',
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.white70,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              if (isCurrentUser) ...[
                const SizedBox(width: 10),
                CircleAvatar(
                  radius: 18,
                  backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.2),
                  child: Text(
                    _getInitials(_currentUserDisplayName ?? 'User'),
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMessageContent(Map<String, dynamic> data, String messageType, bool isCurrentUser) {
    // Check if this is a voice message (even if stored as text type)
    final text = data['text'] ?? '';
    final mediaUrl = data['mediaUrl'] as String?;
    final isVoiceMessage = text.contains('🎵 Voice Message') || 
                          text.contains('Voice Message') ||
                          text.contains('🎵') ||
                          (data['messageType'] == 'voice' || data['messageType'] == 'audio') ||
                          (mediaUrl != null && (mediaUrl.contains('.m4a') || mediaUrl.contains('.wav') || mediaUrl.contains('.mp3')));
    
    // If it's a voice message, use audio content builder regardless of message type
    if (isVoiceMessage && mediaUrl != null) {
      return _buildAudioContent(data, isCurrentUser);
    }
    
    switch (messageType) {
      case 'image':
        return _buildImageContent(data, isCurrentUser);
      case 'video':
        return _buildVideoContent(data, isCurrentUser);
      case 'audio':
        return _buildAudioContent(data, isCurrentUser);
      case 'document':
        return _buildDocumentContent(data, isCurrentUser);
      case 'text':
      default:
        return Text(
          data['text'] ?? '',
          style: TextStyle(
            color: isCurrentUser ? Colors.white : Colors.black87,
            fontSize: 16,
            height: 1.4,
          ),
        );
    }
  }

  Widget _buildImageContent(Map<String, dynamic> data, bool isCurrentUser) {
    final mediaUrl = data['mediaUrl'] as String?;
    final text = data['text'] ?? '📷 Image';
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (mediaUrl != null && mediaUrl.isNotEmpty) ...[
          GestureDetector(
            onTap: () => _showMediaFullScreen(mediaUrl, 'image', text),
            child: Container(
              constraints: const BoxConstraints(
                maxWidth: 250,
                maxHeight: 250,
              ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Stack(
                children: [
                  Image.network(
                    mediaUrl,
                    fit: BoxFit.cover,
                    loadingBuilder: (context, child, loadingProgress) {
                      if (loadingProgress == null) return child;
                      return Container(
                        width: 250,
                        height: 200,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              CircularProgressIndicator(
                                value: loadingProgress.expectedTotalBytes != null
                                    ? loadingProgress.cumulativeBytesLoaded / 
                                      loadingProgress.expectedTotalBytes!
                                    : null,
                                strokeWidth: 3,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Loading...',
                                style: TextStyle(
                                  color: Colors.grey[600],
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        width: 250,
                        height: 200,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.broken_image,
                              size: 50,
                              color: Colors.grey[600],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Failed to load',
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.6),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.photo,
                        color: Colors.white,
                        size: 16,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          ),
          const SizedBox(height: 8),
        ],
        Text(
          text,
          style: TextStyle(
            color: isCurrentUser ? Colors.white : Colors.black87,
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildVideoContent(Map<String, dynamic> data, bool isCurrentUser) {
    final mediaUrl = data['mediaUrl'] as String?;
    final text = data['text'] ?? '🎥 Video';
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (mediaUrl != null && mediaUrl.isNotEmpty) ...[
          Container(
            constraints: const BoxConstraints(
              maxWidth: 250,
              maxHeight: 200,
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Video thumbnail with fallback
                  Container(
                    width: 250,
                    height: 200,
                    decoration: BoxDecoration(
                      color: Colors.grey[800],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: FutureBuilder<String?>(
                      future: _generateVideoThumbnail(mediaUrl!),
                      builder: (context, snapshot) {
                        if (snapshot.hasData && snapshot.data != null) {
                          return ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.network(
                              snapshot.data!,
                              width: 250,
                              height: 200,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) {
                                return _buildVideoPlaceholder();
                              },
                            ),
                          );
                        }
                        return _buildVideoPlaceholder();
                      },
                    ),
                  ),
                  // Play button overlay
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.6),
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      onPressed: () {
                        if (mediaUrl != null) {
                          _playVideo(mediaUrl);
                        }
                      },
                      icon: const Icon(
                        Icons.play_arrow,
                        color: Colors.white,
                        size: 40,
                      ),
                    ),
                  ),
                  // Video duration indicator (if available)
                  if (data['duration'] != null) ...[
                    Positioned(
                      bottom: 8,
                      right: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.7),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          _formatDuration(Duration(seconds: data['duration'])),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w500,
                          ),
                      ),
                    ),
                  ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
        ],
        Text(
          text,
          style: TextStyle(
            color: isCurrentUser ? Colors.white : Colors.black87,
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  Widget _buildVideoPlaceholder() {
    return Container(
      width: 250,
      height: 200,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.grey[700]!,
            Colors.grey[800]!,
          ],
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.videocam,
            color: Colors.white.withValues(alpha: 0.7),
            size: 40,
          ),
          const SizedBox(height: 8),
          Text(
            'Video',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.7),
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Future<String?> _generateVideoThumbnail(String videoUrl) async {
    try {
      // For now, return null to use placeholder
      // In a production app, you would implement video thumbnail generation
      // This could be done using video_thumbnail package or server-side generation
      return null;
    } catch (e) {
      Log.e('Error generating video thumbnail', 'CHAT_SCREEN', e);
      return null;
    }
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    String twoDigitMinutes = twoDigits(duration.inMinutes.remainder(60));
    String twoDigitSeconds = twoDigits(duration.inSeconds.remainder(60));
    return "$twoDigitMinutes:$twoDigitSeconds";
  }

  Widget _buildAudioContent(Map<String, dynamic> data, bool isCurrentUser) {
    final mediaUrl = data['mediaUrl'] as String?;
    final text = data['text'] ?? '🎵 Voice Message';
    final duration = data['duration'] ?? 0;
    final messageId = data['id'] ?? '';
    
    // Since this method is called for voice messages, always show the enhanced player
    if (mediaUrl != null) {
      // Use enhanced VoiceMessagePlayer for voice messages
      return Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: isCurrentUser ? Colors.blue.withValues(alpha: 0.1) : Colors.grey.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isCurrentUser ? Colors.blue : Colors.grey,
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Play/Pause Button
            GestureDetector(
              onTap: () {
                if (mediaUrl != null) {
                  final isCurrentlyPlaying = _isPlayingMap[messageId] ?? false;
                  if (isCurrentlyPlaying) {
                    _pauseAudioPlayback(messageId);
                  } else {
                    _playVoiceMessage(mediaUrl, messageId: messageId);
                  }
                }
              },
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: isCurrentUser ? Colors.blue : Colors.grey.shade300,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  (_isPlayingMap[messageId] ?? false) ? Icons.pause : Icons.play_arrow,
                  color: isCurrentUser ? Colors.white : Colors.black87,
                  size: 20,
                ),
              ),
            ),
            const SizedBox(width: 12),
            
            // Voice Message Info
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  text,
                  style: TextStyle(
                    color: isCurrentUser ? Colors.white : Colors.black87,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(
                      Icons.mic,
                      size: 16,
                      color: isCurrentUser ? Colors.white70 : Colors.black54,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${duration}s',
                      style: TextStyle(
                        color: isCurrentUser ? Colors.white70 : Colors.black54,
                        fontSize: 12,
                      ),
                    ),
                    if (_isPlayingMap[messageId] ?? false) ...[
                      const SizedBox(width: 8),
                      Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: Colors.green,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
            
            const SizedBox(width: 8),
            
            // Stop Button (if playing)
            if (_isPlayingMap[messageId] ?? false)
              GestureDetector(
                onTap: () => _stopAudioPlayback(messageId),
                child: Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.stop,
                    color: Colors.red,
                    size: 16,
                  ),
                ),
              ),
          ],
        ),
      );
    }
    
    // Fallback to original implementation for other audio content
    final isCurrentlyPlaying = _isPlayingMap[messageId] ?? false;
    
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isCurrentUser ? Colors.blue.withValues(alpha: 0.1) : Colors.grey.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isCurrentUser ? Colors.blue : Colors.grey,
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Play/Pause Button
          GestureDetector(
            onTap: () {
              if (mediaUrl != null) {
                if (isCurrentlyPlaying) {
                  _pauseAudioPlayback(messageId);
                } else {
                  _playVoiceMessage(mediaUrl, messageId: messageId);
                }
              }
            },
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: isCurrentUser ? Colors.blue : Colors.grey.shade300,
                shape: BoxShape.circle,
              ),
            child: Icon(
                isCurrentlyPlaying ? Icons.pause : Icons.play_arrow,
              color: isCurrentUser ? Colors.white : Colors.black87,
                size: 20,
              ),
            ),
          ),
          const SizedBox(width: 12),
          
          // Voice Message Info
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                text,
                style: TextStyle(
                  color: isCurrentUser ? Colors.white : Colors.black87,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Icon(
                    Icons.mic,
                    size: 16,
                    color: isCurrentUser ? Colors.white70 : Colors.black54,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '${duration}s',
                    style: TextStyle(
                      color: isCurrentUser ? Colors.white70 : Colors.black54,
                      fontSize: 12,
                    ),
                  ),
                  if (isCurrentlyPlaying) ...[
                    const SizedBox(width: 8),
                    Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: Colors.green,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
          
          const SizedBox(width: 8),
          
          // Stop Button (if playing)
          if (isCurrentlyPlaying)
            GestureDetector(
              onTap: () => _stopAudioPlayback(messageId),
              child: Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
              child: Icon(
                  Icons.stop,
                  color: Colors.red,
                  size: 16,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildDocumentContent(Map<String, dynamic> data, bool isCurrentUser) {
    final text = data['text'] ?? '📎 Document';
    final mimeType = data['mimeType'] ?? 'application/octet-stream';
    final mediaUrl = data['mediaUrl'];
    
    String fileName = text;
    String? extension;
    String fileType = 'Document';
    String fileSize = '0 B';
    
    if (text.contains('|')) {
      final parts = text.split('|');
      if (parts.length >= 3) {
        fileName = parts[0];
        fileType = parts[1];
        fileSize = parts[2];
        
        if (fileName.contains('.')) {
          extension = fileName.split('.').last.toLowerCase();
        }
      }
    } else if (text.contains('.')) {
      extension = text.split('.').last.toLowerCase();
      fileType = DocumentService.getFileType(extension);
      
      if (data['fileSize'] != null && data['fileSize'] != '0 B') {
        fileSize = data['fileSize'];
      }
    }
    
    final fileIcon = DocumentService.getFileIcon(extension);
    final fileColor = Color(DocumentService.getFileColor(extension));
    
    return GestureDetector(
      onTap: () {
        if (mediaUrl != null) {
          _showMediaFullScreen(mediaUrl, 'document', fileName);
        }
      },
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isCurrentUser ? Colors.blue.withValues(alpha: 0.1) : Colors.grey.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: fileColor.withValues(alpha: 0.3),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              fileIcon,
              style: TextStyle(fontSize: 32),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    fileName,
                    style: TextStyle(
                      color: isCurrentUser ? Colors.white : Colors.black87,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    fileType,
                    style: TextStyle(
                      color: isCurrentUser ? Colors.white70 : Colors.black54,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    fileSize,
                    style: TextStyle(
                      color: isCurrentUser ? Colors.white60 : Colors.black45,
                      fontSize: 10,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Tap to open',
                    style: TextStyle(
                      color: fileColor,
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.open_in_new,
              color: fileColor,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  String _getInitials(String name) {
    if (name.isEmpty) return 'U';
    return name[0].toUpperCase();
  }

  String _formatTime(Timestamp timestamp) {
    try {
      final messageTime = timestamp.toDate();
      return '${messageTime.hour.toString().padLeft(2, '0')}:${messageTime.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      return '--:--';
    }
  }

  String _getMessageStatus(String messageId) {
    return _messageStatuses[messageId] ?? 'sent';
  }

  bool _isMessageSending(String messageId) {
    return _sendingMessages.containsKey(messageId);
  }

  Widget _buildSendingMessageBubble(String messageId, String text) {
    final theme = Theme.of(context);
    final isDark = _themeService.isDarkMode;
    
    return SlideTransition(
      position: _slideAnimation,
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: Container(
          margin: const EdgeInsets.only(
            left: 50,
            right: 8,
            bottom: 12,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Flexible(
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withValues(alpha: 0.8),
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(20),
                      topRight: Radius.circular(20),
                      bottomLeft: Radius.circular(20),
                      bottomRight: Radius.circular(8),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.1),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                    border: Border.all(
                      color: Colors.blue.withValues(alpha: 0.3),
                      width: 1,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        text,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Colors.blue[200]!,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Sending...',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.blue[200],
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(width: 4),
                          SizedBox(
                            width: 12,
                            height: 12,
                            child: CircularProgressIndicator(
                              strokeWidth: 1.5,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Colors.blue[100]!,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMessageStatusIcon(String status, bool isCurrentUser) {
    IconData icon;
    Color color;
    
    switch (status) {
      case 'sent':
        icon = Icons.check;
        color = Colors.grey;
        break;
      case 'delivered':
        icon = Icons.done_all;
        color = Colors.grey;
        break;
      case 'read':
        icon = Icons.done_all;
        color = Colors.blue;
        break;
      default:
        icon = Icons.schedule;
        color = Colors.grey;
    }
    
    return Icon(
      icon,
      size: 16,
      color: isCurrentUser ? Colors.white70 : color,
    );
  }

  Future<void> _markMessagesAsRead(List<DocumentSnapshot> messages) async {
    try {
      final unreadMessages = messages.where((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return data['senderId'] != _currentUserId && 
               (data['readBy'] == null || !data['readBy'].contains(_currentUserId));
      }).toList();

      if (unreadMessages.isNotEmpty) {
        final batch = FirebaseFirestore.instance.batch();
        
        for (final message in unreadMessages) {
          final messageRef = FirebaseFirestore.instance
              .collection('chats')
              .doc(widget.chatId)
              .collection('messages')
              .doc(message.id);
          
          batch.update(messageRef, {
            'readBy': FieldValue.arrayUnion([_currentUserId]),
            'status': 'read',
          });
        }
        
        await batch.commit();
      }
    } catch (e) {
      Log.e('Error marking messages as read', 'CHAT_SCREEN', e);
    }
  }

  Future<void> _sendMessage() async {
    final messageText = _messageController.text.trim();
    if (messageText.isEmpty) return;

    // Generate temporary message ID for tracking
    final tempMessageId = 'temp_${DateTime.now().millisecondsSinceEpoch}';
    
    // Add to sending messages
    setState(() {
      _sendingMessages[tempMessageId] = true;
      _sendingMessageIds[tempMessageId] = messageText;
    });

    try {
      // Trigger send animation
      _scaleController.forward().then((_) => _scaleController.reverse());

      final messageData = {
        'text': messageText,
        'senderId': _currentUserId,
        'senderName': _currentUserDisplayName ?? 'User',
        'timestamp': FieldValue.serverTimestamp(),
        'type': 'text',
        'status': 'sent',
        'readBy': [_currentUserId],
      };

      final docRef = await FirebaseFirestore.instance
          .collection('chats')
          .doc(widget.chatId)
          .collection('messages')
          .add(messageData);

      // Update chat metadata with last message information
      await ChatManagementService.updateChatMetadata(
        widget.chatId,
        messageText,
        _currentUserDisplayName ?? 'User',
      );

      // Send FCM notification to other users
      await _sendFCMNotificationForMessage(
        messageText: messageText,
        messageType: 'text',
      );

      _messageController.clear();
      
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          0,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }

      // Remove from sending messages
      setState(() {
        _sendingMessages.remove(tempMessageId);
        _sendingMessageIds.remove(tempMessageId);
      });

    } catch (e) {
      Log.e('Error sending message', 'CHAT_SCREEN', e);
      
      // Remove from sending messages on error
      setState(() {
        _sendingMessages.remove(tempMessageId);
        _sendingMessageIds.remove(tempMessageId);
      });
      
      // Show error popup only for text messages
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(
                  Icons.error,
                  color: Colors.white,
                  size: 20,
                ),
                const SizedBox(width: 12),
                Text(
                  'Error sending message: $e',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            margin: const EdgeInsets.all(16),
          ),
        );
      }
    }
  }

  /// Send FCM notification for new message
  Future<void> _sendFCMNotificationForMessage({
    required String messageText,
    required String messageType,
  }) async {
    try {
      if (widget.isGroupChat) {
        // Group chat notification
        await _fcmService.handleGroupMessage(
          senderId: _currentUserId,
          senderName: _currentUserDisplayName ?? 'User',
          message: messageText,
          groupId: widget.chatId,
          groupName: widget.chatName ?? 'Group',
          messageType: messageType,
        );
      } else {
        // One-to-one chat notification
        final recipientId = widget.userIds?.firstWhere(
          (id) => id != _currentUserId,
          orElse: () => '',
        );
        
        if (recipientId != null && recipientId.isNotEmpty) {
          await _fcmService.handleNewMessage(
            senderId: _currentUserId,
            senderName: _currentUserDisplayName ?? 'User',
            message: messageText,
            receiverId: recipientId,
            messageType: messageType,
          );
        }
      }
      
      Log.i('FCM notification sent for message', 'CHAT_SCREEN');
    } catch (e) {
      Log.e('Error sending FCM notification', 'CHAT_SCREEN', e);
    }
  }

  Future<void> _pickImageFromGallery() async {
    try {
      final result = await EnhancedMediaService.pickImageFromGallery(context);
      if (result != null) {
        await _uploadAndSendMedia(result.bytes, 'image', '📷 Image from gallery');
      }
    } catch (e) {
      Log.e('Error picking image from gallery', 'CHAT_SCREEN', e);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to pick image: $e')),
      );
    }
  }

  Future<void> _pickImageFromCamera() async {
    try {
      final result = await EnhancedMediaService.pickImageFromCamera(context);
      if (result != null) {
        await _uploadAndSendMedia(result.bytes, 'image', '📷 Photo from camera');
      }
    } catch (e) {
      Log.e('Error picking image from camera', 'CHAT_SCREEN', e);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to take photo: $e')),
      );
    }
  }

  Future<void> _pickDocument() async {
    try {
      final result = await DocumentService.pickDocument();
      if (result != null && result.files.isNotEmpty) {
        final file = result.files.first;
        final fileBytes = file.bytes;
        if (fileBytes != null) {
          await _uploadAndSendMedia(
            fileBytes, 
            'document', 
            '${file.name}|${DocumentService.getFileType(file.extension)}|${DocumentService.formatFileSize(file.size)}',
            extension: file.extension,
            mimeType: file.extension != null ? DocumentService.mimeTypes[file.extension!.toLowerCase()] : null,
          );
        }
      }
    } catch (e) {
      Log.e('Error picking document', 'CHAT_SCREEN', e);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to pick document: $e')),
      );
    }
  }

  Future<void> _uploadAndSendMedia(
    Uint8List bytes, 
    String type, 
    String text, {
    String? extension,
    String? mimeType,
  }) async {
    // Generate temporary message ID for tracking
    final tempMessageId = 'temp_${DateTime.now().millisecondsSinceEpoch}';
    
    // Add to sending messages
    setState(() {
      _sendingMessages[tempMessageId] = true;
      _sendingMessageIds[tempMessageId] = text;
    });

    // Show "waiting while sending" popup
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'Waiting while sending the message...',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          backgroundColor: Colors.orange,
          duration: const Duration(seconds: 10),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          margin: const EdgeInsets.all(16),
        ),
      );
    }

    try {
      final fileName = '${DateTime.now().millisecondsSinceEpoch}_${type}_${extension ?? 'file'}';
      final uploadId = '${DateTime.now().millisecondsSinceEpoch}_${type}';
      
      // Start progress tracking
      final ref = FirebaseStorage.instance
          .ref()
          .child('chat_media')
          .child(widget.chatId)
          .child(fileName);
      
      // Create upload task with progress tracking
      final uploadTask = ref.putData(bytes);
      final progressTask = ProgressTrackingUploadTask(
        uploadId: uploadId,
        uploadTask: uploadTask,
      );
      
      // Start monitoring progress
      progressTask.startMonitoring();
      
      // Wait for upload to complete
      await uploadTask;
      final downloadUrl = await ref.getDownloadURL();
      
      // Mark upload as completed
      UploadProgressService.markCompleted(uploadId);
      
      final messageData = {
        'text': text,
        'senderId': _currentUserId,
        'senderName': _currentUserDisplayName ?? 'User',
        'timestamp': FieldValue.serverTimestamp(),
        'type': type,
        'mediaUrl': downloadUrl,
        'status': 'sent',
        'readBy': [_currentUserId],
        if (extension != null) 'extension': extension,
        if (mimeType != null) 'mimeType': mimeType,
      };

      await FirebaseFirestore.instance
          .collection('chats')
          .doc(widget.chatId)
          .collection('messages')
          .add(messageData);

      // Update chat metadata with last message information
      await ChatManagementService.updateChatMetadata(
        widget.chatId,
        text,
        _currentUserDisplayName ?? 'User',
      );
      
      // Clean up progress tracking
      progressTask.dispose();
      
      // Remove from sending messages
      setState(() {
        _sendingMessages.remove(tempMessageId);
        _sendingMessageIds.remove(tempMessageId);
      });
      
      // Show "Send successfully" popup
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(
                  Icons.check_circle,
                  color: Colors.white,
                  size: 20,
                ),
                const SizedBox(width: 12),
                const Text(
                  'Send successfully',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            margin: const EdgeInsets.all(16),
          ),
        );
      }
      
    } catch (e) {
      Log.e('Error uploading media', 'CHAT_SCREEN', e);
      
      // Remove from sending messages on error
      setState(() {
        _sendingMessages.remove(tempMessageId);
        _sendingMessageIds.remove(tempMessageId);
      });
      
      // Show error popup
      if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(
                  Icons.error,
                  color: Colors.white,
                  size: 20,
                ),
                const SizedBox(width: 12),
                Text(
                  'Error sending message: $e',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            margin: const EdgeInsets.all(16),
          ),
        );
      }
    }
  }



  List<int> _generateSimulatedAudioData(int durationSeconds) {
    // Generate a more realistic voice-like audio file
    final List<int> audioData = [];
    
    final sampleRate = 44100;
    final channels = 1;
    final bitsPerSample = 16;
    final byteRate = sampleRate * channels * bitsPerSample ~/ 8;
    final blockAlign = channels * bitsPerSample ~/ 8;
    final dataSize = durationSeconds * sampleRate * channels * (bitsPerSample ~/ 8);
    final fileSize = 36 + dataSize;
    
    // WAV file header
    // RIFF header
    audioData.addAll([0x52, 0x49, 0x46, 0x46]); // "RIFF"
    audioData.addAll(_intToBytes(fileSize, 4)); // File size
    audioData.addAll([0x57, 0x41, 0x56, 0x45]); // "WAVE"
    
    // fmt chunk
    audioData.addAll([0x66, 0x6D, 0x74, 0x20]); // "fmt "
    audioData.addAll(_intToBytes(16, 4)); // Chunk size
    audioData.addAll(_intToBytes(1, 2)); // Audio format (PCM)
    audioData.addAll(_intToBytes(channels, 2)); // Channels
    audioData.addAll(_intToBytes(sampleRate, 4)); // Sample rate
    audioData.addAll(_intToBytes(byteRate, 4)); // Byte rate
    audioData.addAll(_intToBytes(blockAlign, 2)); // Block align
    audioData.addAll(_intToBytes(bitsPerSample, 2)); // Bits per sample
    
    // data chunk
    audioData.addAll([0x64, 0x61, 0x74, 0x61]); // "data"
    audioData.addAll(_intToBytes(dataSize, 4)); // Data size
    
    // Generate more realistic voice-like audio data
    // Use multiple frequencies and varying amplitudes to simulate human speech
    final List<double> frequencies = [150.0, 300.0, 450.0, 600.0, 750.0]; // Voice frequency range
    final List<double> amplitudes = [0.4, 0.3, 0.2, 0.15, 0.1]; // Varying amplitudes
    
    for (int i = 0; i < dataSize; i += 2) {
      double sample = 0.0;
      final time = i / sampleRate;
      
      // Combine multiple frequencies with different phases
      for (int j = 0; j < frequencies.length; j++) {
        final frequency = frequencies[j];
        final amplitude = amplitudes[j];
        final phase = j * pi / 3; // Different phase for each frequency
        
        sample += amplitude * sin(2 * pi * frequency * time + phase);
      }
      
      // Add some variation to make it more realistic
      final variation = 0.1 * sin(2 * pi * 2.0 * time); // Slow variation
      sample += variation;
      
      // Apply envelope to simulate speech patterns
      final envelope = sin(pi * time / durationSeconds) * 0.5 + 0.5;
      sample *= envelope;
      
      // Convert to 16-bit integer
      final intSample = (32767 * 0.25 * sample).toInt();
      audioData.addAll(_intToBytes(intSample, 2));
    }
    
    return audioData;
  }

  List<int> _intToBytes(int value, int length) {
    final bytes = <int>[];
    for (int i = 0; i < length; i++) {
      bytes.add((value >> (i * 8)) & 0xFF);
    }
    return bytes;
  }



  Future<void> _playVoiceMessage(String? mediaUrl, {String? messageId}) async {
    if (mediaUrl == null) return;
    
    try {
      Log.i('Playing voice message from: $mediaUrl', 'CHAT_SCREEN');
      
      // Stop any currently playing audio
      for (String id in _isPlayingMap.keys) {
        if (_isPlayingMap[id] == true) {
          await _stopAudioPlayback(id);
        }
      }
      
      // Initialize audio player if needed
      _audioPlayers.putIfAbsent(messageId ?? '', () => AudioPlayer());
      
      // Set up audio player event listeners
      _audioPlayers[messageId ?? '']!.onPlayerStateChanged.listen((state) {
        if (mounted) {
      setState(() {
            _isPlayingMap[messageId ?? ''] = state == PlayerState.playing;
          });
        }
      });
      
      _audioPlayers[messageId ?? '']!.onPlayerComplete.listen((_) {
        if (mounted) {
          setState(() {
            _isPlayingMap[messageId ?? ''] = false;
            _positionMap[messageId ?? ''] = Duration.zero;
            _durationMap[messageId ?? ''] = Duration.zero;
          });
        }
      });

      // Platform-aware voice message playback
      if (kIsWeb) {
        // Web platform - use URL directly
        await _playVoiceMessageWeb(mediaUrl, messageId);
      } else {
        // Mobile platforms (Android/iOS) - download and play locally
        await _playVoiceMessageMobile(mediaUrl, messageId);
      }
      
    } catch (e) {
      Log.e('Error playing voice message', 'CHAT_SCREEN', e);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error playing voice message: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _playVoiceMessageWeb(String mediaUrl, String? messageId) async {
    try {
      Log.i('Playing voice message on Web: $mediaUrl', 'CHAT_SCREEN');
      
      // For web, try different approaches
      try {
        // Try direct URL first
        await _audioPlayers.putIfAbsent(messageId ?? '', () => AudioPlayer()).play(UrlSource(mediaUrl));
      } catch (e) {
        Log.w('Direct URL failed on web, trying alternative: $e', 'CHAT_SCREEN');
        
        // If it's a Firebase URL, try to get a clean download URL
        if (mediaUrl.contains('firebasestorage.googleapis.com')) {
          try {
            final ref = FirebaseStorage.instance.refFromURL(mediaUrl);
            final cleanUrl = await ref.getDownloadURL();
            await _audioPlayers.putIfAbsent(messageId ?? '', () => AudioPlayer()).play(UrlSource(cleanUrl));
          } catch (firebaseError) {
            Log.e('Firebase URL also failed: $firebaseError', 'CHAT_SCREEN');
            rethrow;
          }
        } else {
          rethrow;
        }
      }
      
      setState(() {
        _isPlayingMap[messageId ?? ''] = true;
        _positionMap[messageId ?? ''] = Duration.zero;
        _durationMap[messageId ?? ''] = Duration.zero;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('🎵 Playing voice message...'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      Log.e('Error playing voice message on Web', 'CHAT_SCREEN', e);
      rethrow;
    }
  }

  Future<void> _playVoiceMessageMobile(String mediaUrl, String? messageId) async {
    try {
      Log.i('Playing voice message on Mobile: $mediaUrl', 'CHAT_SCREEN');
      
      String downloadUrl = mediaUrl;
      
      // Check if it's a Firebase Storage URL
      if (mediaUrl.contains('firebasestorage.googleapis.com')) {
        try {
          final ref = FirebaseStorage.instance.refFromURL(mediaUrl);
          downloadUrl = await ref.getDownloadURL();
          Log.i('Got voice download URL: $downloadUrl', 'CHAT_SCREEN');
        } catch (e) {
          Log.e('Error getting Firebase download URL', 'CHAT_SCREEN', e);
          rethrow;
        }
      }
      
      // Try direct URL playback first (most reliable)
      try {
        Log.i('Attempting direct URL playback: $downloadUrl', 'CHAT_SCREEN');
        await _audioPlayers.putIfAbsent(messageId ?? '', () => AudioPlayer()).play(UrlSource(downloadUrl));
        
        setState(() {
          _isPlayingMap[messageId ?? ''] = true;
          _positionMap[messageId ?? ''] = Duration.zero;
          _durationMap[messageId ?? ''] = Duration.zero;
        });
        
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('🎵 Playing voice message...'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 2),
            ),
          );
        }
        
        Log.i('Direct URL playback successful', 'CHAT_SCREEN');
        return; // Success, exit early
        
      } catch (directError) {
        Log.w('Direct URL playback failed, trying local download: $directError', 'CHAT_SCREEN');
        
        // Fallback: Download and play locally
        final response = await http.get(Uri.parse(downloadUrl));
        if (response.statusCode == 200) {
          // Validate the audio file before playing
          if (!_isValidAudioFile(response.bodyBytes)) {
            Log.w('Invalid audio file, creating fallback audio', 'CHAT_SCREEN');
            // Create a fallback audio file
            await _playFallbackAudio(messageId);
            return;
          }
          
          // Platform-specific file handling
          if (Platform.isAndroid || Platform.isIOS) {
            final tempDir = await getTemporaryDirectory();
            final tempFile = File('${tempDir.path}/voice_message_${DateTime.now().millisecondsSinceEpoch}.wav');
            await tempFile.writeAsBytes(response.bodyBytes);
            
            Log.i('Downloaded voice message to: ${tempFile.path}', 'CHAT_SCREEN');
            
            // Try playing the local file
            try {
              await _audioPlayers.putIfAbsent(messageId ?? '', () => AudioPlayer()).play(DeviceFileSource(tempFile.path));
            } catch (localError) {
              Log.w('Local file playback failed, trying fallback: $localError', 'CHAT_SCREEN');
              // If local file fails, try fallback audio
              await _playFallbackAudio(messageId);
        return;
      }

            setState(() {
              _isPlayingMap[messageId ?? ''] = true;
              _positionMap[messageId ?? ''] = Duration.zero;
              _durationMap[messageId ?? ''] = Duration.zero;
            });
            
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
                  content: Text('🎵 Playing voice message...'),
                  backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      }
          } else {
            // For other platforms, try URL source as fallback
            await _audioPlayers.putIfAbsent(messageId ?? '', () => AudioPlayer()).play(UrlSource(downloadUrl));
            
            setState(() {
              _isPlayingMap[messageId ?? ''] = true;
              _positionMap[messageId ?? ''] = Duration.zero;
              _durationMap[messageId ?? ''] = Duration.zero;
            });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
                  content: Text('🎵 Playing voice message...'),
            backgroundColor: Colors.green,
                  duration: Duration(seconds: 2),
          ),
        );
      }
          }
        } else {
          throw Exception('Failed to download audio file: ${response.statusCode}');
        }
      }
      
    } catch (e) {
      Log.e('Error playing voice message on Mobile', 'CHAT_SCREEN', e);
      // Try fallback audio as last resort
      await _playFallbackAudio(messageId);
    }
  }

  Future<void> _playFallbackAudio(String? messageId) async {
    try {
      Log.i('Playing fallback audio', 'CHAT_SCREEN');
      
      // Create a simple beep sound
      final audioData = _generateSimulatedAudioData(2); // 2 seconds
      final tempDir = await getTemporaryDirectory();
      final tempFile = File('${tempDir.path}/fallback_audio_${DateTime.now().millisecondsSinceEpoch}.wav');
      await tempFile.writeAsBytes(audioData);
      
      await _audioPlayers.putIfAbsent(messageId ?? '', () => AudioPlayer()).play(DeviceFileSource(tempFile.path));
          
          setState(() {
        _isPlayingMap[messageId ?? ''] = true;
        _positionMap[messageId ?? ''] = Duration.zero;
        _durationMap[messageId ?? ''] = Duration.zero;
          });
          
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
            content: Text('🎵 Playing voice message (fallback)...'),
            backgroundColor: Colors.orange,
                duration: Duration(seconds: 2),
              ),
            );
          }
          
        } catch (e) {
      Log.e('Error playing fallback audio', 'CHAT_SCREEN', e);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Unable to play voice message'),
                backgroundColor: Colors.red,
              ),
            );
          }
        }
  }

  bool _isValidAudioFile(List<int> bytes) {
    try {
      // Check if it's a valid audio file by looking for common audio headers
      if (bytes.length < 12) return false;
      
      // Check for WAV header (most reliable for our generated files)
      if (bytes.length >= 12 && 
          bytes[0] == 0x52 && bytes[1] == 0x49 && bytes[2] == 0x46 && bytes[3] == 0x46 &&
          bytes[8] == 0x57 && bytes[9] == 0x41 && bytes[10] == 0x56 && bytes[11] == 0x45) {
        return true; // WAV file
      }
      
      // Check for M4A header
      if (bytes.length >= 8 && 
          bytes[4] == 0x66 && bytes[5] == 0x74 && bytes[6] == 0x79 && bytes[7] == 0x70) {
        return true; // M4A file
      }
      
      // Check for MP3 header
      if (bytes.length >= 3 && 
          bytes[0] == 0x49 && bytes[1] == 0x44 && bytes[2] == 0x33) {
        return true; // MP3 file
      }
      
      // For our generated files, also check if it has reasonable size and structure
      if (bytes.length > 1000 && bytes.length < 10000000) { // Between 1KB and 10MB
        return true; // Assume valid if reasonable size
      }
      
      return false;
    } catch (e) {
      Log.e('Error validating audio file', 'CHAT_SCREEN', e);
      return false;
    }
  }

  Future<void> _stopAudioPlayback(String messageId) async {
    try {
      if (_audioPlayers.containsKey(messageId)) {
        await _audioPlayers[messageId]!.stop();
        setState(() {
          _isPlayingMap[messageId] = false;
          _positionMap[messageId] = Duration.zero;
          _durationMap[messageId] = Duration.zero;
        });
      }
    } catch (e) {
      Log.e('Error stopping audio playback', 'CHAT_SCREEN', e);
    }
  }

  Future<void> _pauseAudioPlayback(String messageId) async {
    try {
      if (_audioPlayers.containsKey(messageId)) {
        await _audioPlayers[messageId]!.pause();
        setState(() {
          _isPlayingMap[messageId] = false;
        });
      }
    } catch (e) {
      Log.e('Error pausing audio playback', 'CHAT_SCREEN', e);
    }
  }

  Future<Uint8List> _getAudioBytes(String mediaUrl) async {
    try {
      Log.i('Fetching audio bytes from: $mediaUrl', 'CHAT_SCREEN');
      
      // Check if it's a Firebase Storage URL
      if (mediaUrl.contains('firebasestorage.googleapis.com')) {
        final ref = FirebaseStorage.instance.refFromURL(mediaUrl);
        final downloadUrl = await ref.getDownloadURL();
        Log.i('Got audio download URL: $downloadUrl', 'CHAT_SCREEN');
        
        // Download the audio file
        final response = await http.get(Uri.parse(downloadUrl));
        if (response.statusCode == 200) {
          return response.bodyBytes;
        } else {
          throw Exception('Failed to download audio: ${response.statusCode}');
        }
      } else {
        // Direct URL
        final response = await http.get(Uri.parse(mediaUrl));
        if (response.statusCode == 200) {
          return response.bodyBytes;
        } else {
          throw Exception('Failed to download audio: ${response.statusCode}');
        }
      }
    } catch (e) {
      Log.e('Error fetching audio bytes', 'CHAT_SCREEN', e);
      rethrow;
    }
  }

  Future<void> _resumeAudioPlayback(String messageId) async {
    try {
      if (_audioPlayers.containsKey(messageId)) {
        await _audioPlayers[messageId]!.resume();
        setState(() {
          _isPlayingMap[messageId] = true;
        });
      }
    } catch (e) {
      Log.e('Error resuming audio playback', 'CHAT_SCREEN', e);
    }
  }

  Future<void> _openDocument(String mediaUrl, String fileName) async {
    try {
      Log.i('Opening document: $fileName from URL: $mediaUrl', 'CHAT_SCREEN');
      
      // Check if it's a Firebase Storage URL
      if (mediaUrl.contains('firebasestorage.googleapis.com')) {
        // Get download URL from Firebase Storage
        try {
          final ref = FirebaseStorage.instance.refFromURL(mediaUrl);
          final downloadUrl = await ref.getDownloadURL();
          Log.i('Got download URL: $downloadUrl', 'CHAT_SCREEN');
          
          final success = await DocumentService.openDocument(downloadUrl, fileName);
          if (!success) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Could not open document. Please check if you have the appropriate app installed.')),
              );
            }
          }
        } catch (e) {
          Log.e('Error getting download URL', 'CHAT_SCREEN', e);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Error accessing document: $e')),
            );
          }
        }
      } else {
        // Direct URL, try to open directly
        final success = await DocumentService.openDocument(mediaUrl, fileName);
        if (!success) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Could not open document. Please check if you have the appropriate app installed.')),
            );
          }
        }
      }
    } catch (e) {
      Log.e('Error opening document', 'CHAT_SCREEN', e);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error opening document: $e')),
        );
      }
    }
  }

  Future<void> _searchMessages(String query) async {
    if (query.trim().isEmpty) return;
    
    try {
      setState(() {
        _isSearching = true;
        _searchQuery = query;
      });
      
      final querySnapshot = await FirebaseFirestore.instance
          .collection('chats')
          .doc(widget.chatId)
          .collection('messages')
          .where('text', isGreaterThanOrEqualTo: query)
          .where('text', isLessThan: query + '\uf8ff')
          .limit(20)
          .get();
      
      setState(() {
        _searchResults = querySnapshot.docs;
      });
    } catch (e) {
      Log.e('Error searching messages', 'CHAT_SCREEN', e);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error searching messages: $e')),
      );
    }
  }

  void _showGroupInfo() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Group Information'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Group ID: ${widget.chatId}'),
            const SizedBox(height: 8),
            const Text('Group Type: Chat Group'),
            const SizedBox(height: 8),
            const Text('Members: Multiple users'),
            const SizedBox(height: 8),
            const Text('Created: Recently'),
            const SizedBox(height: 8),
            const Text('Status: Active'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              // TODO: Implement group settings
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Group settings coming soon!')),
              );
            },
            child: const Text('Settings'),
          ),
        ],
      ),
    );
  }

  void _retryLoading() {
    _startMessageStream();
  }

  Widget _buildMediaButton({
    required VoidCallback onPressed,
    required IconData icon,
    required String label,
    required Color color,
    required String tooltip,
  }) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withValues(alpha: 0.3)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  color: color,
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Responsive media button that adapts to screen size
  Widget _buildResponsiveMediaButton({
    required VoidCallback onPressed,
    required IconData icon,
    required String label,
    required Color color,
    required String tooltip,
    required bool isMobile,
    required double padding,
  }) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(isMobile ? 8 : 12),
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: padding,
            vertical: isMobile ? 6 : 8,
          ),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(isMobile ? 8 : 12),
            border: Border.all(color: color.withValues(alpha: 0.3)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon, 
                color: color, 
                size: isMobile ? 18 : 20,
              ),
              SizedBox(height: isMobile ? 2 : 4),
              Text(
                label,
                style: TextStyle(
                  color: color,
                  fontSize: isMobile ? 9 : 10,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showMediaOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: _themeService.isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              margin: const EdgeInsets.only(top: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[400],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Choose Media Type',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: _themeService.isDarkMode ? Colors.white : Colors.black87,
              ),
            ),
            const SizedBox(height: 20),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildQuickMediaButton(
                    onPressed: () {
                      Navigator.pop(context);
                      _pickImageFromGallery();
                    },
                    icon: Icons.photo_library,
                    label: 'Gallery',
                    color: Colors.blue,
                  ),
                  _buildQuickMediaButton(
                    onPressed: () {
                      Navigator.pop(context);
                      _pickImageFromCamera();
                    },
                    icon: Icons.camera_alt,
                    label: 'Camera',
                    color: Colors.green,
                  ),
                  _buildQuickMediaButton(
                    onPressed: () {
                      Navigator.pop(context);
                      _pickVideoFromGallery();
                    },
                    icon: Icons.video_library,
                    label: 'Video',
                    color: Colors.red,
                  ),
                  _buildQuickMediaButton(
                    onPressed: () {
                      Navigator.pop(context);
                      _pickVideoFromCamera();
                    },
                    icon: Icons.videocam,
                    label: 'Record',
                    color: Colors.purple,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildQuickMediaButton(
                    onPressed: () {
                      Navigator.pop(context);
                      _pickDocument();
                    },
                    icon: Icons.attach_file,
                    label: 'File',
                    color: Colors.orange,
                  ),

                  _buildQuickMediaButton(
                    onPressed: () {
                      Navigator.pop(context);
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) => const UploadProgressDemoScreen(),
                        ),
                      );
                    },
                    icon: Icons.cloud_upload,
                    label: 'Progress',
                    color: Colors.indigo,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickMediaButton({
    required VoidCallback onPressed,
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: 70,
        height: 70,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickVideoFromGallery() async {
    try {
      final result = await EnhancedMediaService.pickVideoFromGallery(context);
      if (result != null) {
        await _uploadAndSendMedia(result.bytes, 'video', '🎥 Video from gallery');
      }
    } catch (e) {
      Log.e('Error picking video from gallery', 'CHAT_SCREEN', e);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to pick video: $e')),
      );
    }
  }

  Future<void> _pickVideoFromCamera() async {
    try {
      final result = await EnhancedMediaService.recordVideo(context);
      if (result != null) {
        await _uploadAndSendMedia(result.bytes, 'video', '🎥 Video from camera');
      }
    } catch (e) {
      Log.e('Error recording video', 'CHAT_SCREEN', e);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to record video: $e')),
      );
    }
  }

  Future<void> _playVideo(String? mediaUrl) async {
    if (mediaUrl == null) return;

    try {
      Log.i('Playing video message from: $mediaUrl', 'CHAT_SCREEN');

      // Get the actual download URL if it's a Firebase Storage URL
      String finalUrl = mediaUrl;
      if (mediaUrl.contains('firebasestorage.googleapis.com')) {
        try {
          final ref = FirebaseStorage.instance.refFromURL(mediaUrl);
          finalUrl = await ref.getDownloadURL();
          Log.i('Got video download URL: $finalUrl', 'CHAT_SCREEN');
        } catch (e) {
          Log.e('Error getting video download URL', 'CHAT_SCREEN', e);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Error accessing video message: $e')),
            );
          }
          return;
        }
      }

      // Open video in in-app player
      if (mounted) {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => InAppVideoPlayer(
              videoUrl: finalUrl,
              videoTitle: 'Video Message',
              ),
            ),
          );
      }
    } catch (e) {
      Log.e('Error playing video message', 'CHAT_SCREEN', e);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error playing video message: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showMediaFullScreen(String mediaUrl, String type, String text) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => EnhancedMediaPreview(
          mediaUrl: mediaUrl,
          mediaType: type,
          fileName: text,
        ),
      ),
    );
  }
} 