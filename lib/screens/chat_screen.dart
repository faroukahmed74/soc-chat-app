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
import '../services/theme_service.dart';
import '../services/unified_media_service.dart';
import '../services/document_service.dart';
import '../services/logger_service.dart';
import '../services/chat_management_service.dart';
import '../services/production_notification_service.dart';
import '../utils/responsive_utils.dart';

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
  bool _isRecordingVoice = false;
  Timer? _recordingTimer;
  int _recordingDuration = 0;
  
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
    _recordingTimer?.cancel();
    _messagesSubscription?.cancel();
    
    // Dispose animation controllers
    _fadeController.dispose();
    _slideController.dispose();
    _scaleController.dispose();
    
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
      await ProductionNotificationService().subscribeToChatTopic(widget.chatId);
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
              backgroundColor: theme.colorScheme.primary.withOpacity(0.2),
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
                          color: Colors.black.withOpacity(0.1),
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
                                  color: Colors.orange.withOpacity(0.1),
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
                                  color: Colors.orange.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(15),
                                  border: Border.all(
                                    color: Colors.orange.withOpacity(0.3),
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
                                      color: theme.colorScheme.primary.withOpacity(0.1),
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
                                        color: theme.colorScheme.primary.withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(isMobile ? 20 : 25),
                                        border: Border.all(
                                          color: theme.colorScheme.primary.withOpacity(0.3),
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
                      itemCount: messages.length + (_hasMoreMessages ? 1 : 0),
                      itemBuilder: (context, index) {
                        if (index == messages.length) {
                          return _buildLoadMoreIndicator();
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
                      color: Colors.black.withOpacity(0.1),
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
                                    SizedBox(width: buttonSpacing),
                                    _buildResponsiveMediaButton(
                                      onPressed: () => _toggleVoiceRecording(),
                                      icon: _isRecordingVoice ? Icons.stop : Icons.mic,
                                      label: _isRecordingVoice ? 'Stop' : 'Voice',
                                      color: _isRecordingVoice ? Colors.red : Colors.teal,
                                      tooltip: _isRecordingVoice ? 'Stop Recording' : 'Voice Message',
                                      isMobile: isMobile,
                                      padding: buttonPadding,
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                          
                          // Recording status - moved to separate row for better responsiveness
                          if (_isRecordingVoice) ...[
                            const SizedBox(height: 8),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: Colors.red.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(15),
                                    border: Border.all(color: Colors.red.withOpacity(0.3)),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.fiber_manual_record,
                                        color: Colors.red,
                                        size: 16,
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        '${_recordingDuration}s',
                                        style: const TextStyle(
                                          color: Colors.red,
                                          fontWeight: FontWeight.w600,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                    
                                        Container(
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                        borderRadius: BorderRadius.circular(isMobile ? 20 : 25),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
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
                                      color: theme.colorScheme.primary.withOpacity(0.3),
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
            backgroundColor: Theme.of(context).colorScheme.primary.withOpacity(0.1),
            foregroundColor: Theme.of(context).colorScheme.primary,
            elevation: 0,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(25),
              side: BorderSide(
                color: Theme.of(context).colorScheme.primary.withOpacity(0.3),
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
                  backgroundColor: theme.colorScheme.primary.withOpacity(0.2),
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
                        color: Colors.black.withOpacity(0.1),
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
                    ],
                  ),
                ),
              ),
              if (isCurrentUser) ...[
                const SizedBox(width: 10),
                CircleAvatar(
                  radius: 18,
                  backgroundColor: theme.colorScheme.primary.withOpacity(0.2),
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
          Container(
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
                        color: Colors.black.withOpacity(0.6),
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
                  Container(
                    width: 250,
                    height: 200,
                    color: Colors.black,
                    child: const Icon(
                      Icons.video_file,
                      color: Colors.white,
                      size: 50,
                    ),
                  ),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.5),
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      onPressed: () => _playVideo(mediaUrl),
                      icon: const Icon(
                        Icons.play_arrow,
                        color: Colors.white,
                        size: 40,
                      ),
                    ),
                  ),
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

  Widget _buildAudioContent(Map<String, dynamic> data, bool isCurrentUser) {
    final mediaUrl = data['mediaUrl'] as String?;
    final text = data['text'] ?? '🎵 Voice Message';
    
    return GestureDetector(
      onTap: () => _playVoiceMessage(mediaUrl),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isCurrentUser ? Colors.blue.withOpacity(0.1) : Colors.grey.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isCurrentUser ? Colors.blue : Colors.grey,
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.play_circle_filled,
              color: isCurrentUser ? Colors.white : Colors.black87,
              size: 32,
            ),
            const SizedBox(width: 12),
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
                Text(
                  'Tap to play',
                  style: TextStyle(
                    color: isCurrentUser ? Colors.white70 : Colors.black54,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ],
        ),
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
          _openDocument(mediaUrl, fileName);
        }
      },
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isCurrentUser ? Colors.blue.withOpacity(0.1) : Colors.grey.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: fileColor.withOpacity(0.3),
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

      await FirebaseFirestore.instance
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

      _messageController.clear();
      
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          0,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }

      // Show success feedback
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                const Text('Message sent successfully'),
              ],
            ),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 1),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }
    } catch (e) {
      Log.e('Error sending message', 'CHAT_SCREEN', e);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.error, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                Text('Error sending message: $e'),
              ],
            ),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }
    }
  }

  Future<void> _pickImageFromGallery() async {
    try {
      final imageBytes = await UnifiedMediaService.pickImageFromGallery(context);
      if (imageBytes != null) {
        await _uploadAndSendMedia(imageBytes, 'image', '📷 Image from gallery');
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
      final imageBytes = await UnifiedMediaService.pickImageFromCamera(context);
      if (imageBytes != null) {
        await _uploadAndSendMedia(imageBytes, 'image', '📷 Photo from camera');
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
    try {
      final fileName = '${DateTime.now().millisecondsSinceEpoch}_${type}_${extension ?? 'file'}';
      final ref = FirebaseStorage.instance
          .ref()
          .child('chat_media')
          .child(widget.chatId)
          .child(fileName);
      
      await ref.putData(bytes);
      final downloadUrl = await ref.getDownloadURL();
      
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
    } catch (e) {
      Log.e('Error uploading media', 'CHAT_SCREEN', e);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error uploading media: $e')),
      );
    }
  }

  void _toggleVoiceRecording() {
    if (_isRecordingVoice) {
      _stopVoiceRecording();
    } else {
      _startVoiceRecording();
    }
  }

  void _startVoiceRecording() {
    setState(() {
      _isRecordingVoice = true;
      _recordingDuration = 0;
    });
    
    _recordingTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          _recordingDuration++;
        });
      }
    });
  }

  void _stopVoiceRecording() {
    _recordingTimer?.cancel();
    
    setState(() {
      _isRecordingVoice = false;
    });
  }

  Future<void> _playVoiceMessage(String? mediaUrl) async {
    if (mediaUrl == null) return;
    
    try {
      Log.i('Playing voice message from: $mediaUrl', 'CHAT_SCREEN');
      
      // Check if it's a Firebase Storage URL
      if (mediaUrl.contains('firebasestorage.googleapis.com')) {
        // Get download URL from Firebase Storage
        try {
          final ref = FirebaseStorage.instance.refFromURL(mediaUrl);
          final downloadUrl = await ref.getDownloadURL();
          Log.i('Got voice download URL: $downloadUrl', 'CHAT_SCREEN');
          
          // For now, show a message that voice playback is working
          // TODO: Implement actual audio playback using just_audio or audioplayers package
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Voice message ready to play: ${mediaUrl.split('/').last}'),
                action: SnackBarAction(
                  label: 'Download',
                  onPressed: () async {
                    try {
                      final success = await DocumentService.openDocument(downloadUrl, 'voice_message.mp3');
                      if (success) {
                        Log.i('Voice message opened successfully', 'CHAT_SCREEN');
                      }
                    } catch (e) {
                      Log.e('Error opening voice message', 'CHAT_SCREEN', e);
                    }
                  },
                ),
              ),
            );
          }
        } catch (e) {
          Log.e('Error getting voice download URL', 'CHAT_SCREEN', e);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Error accessing voice message: $e')),
            );
          }
        }
      } else {
        // Direct URL
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Voice message ready to play: ${mediaUrl.split('/').last}'),
              action: SnackBarAction(
                label: 'Play',
                onPressed: () async {
                  try {
                    final success = await DocumentService.openDocument(mediaUrl, 'voice_message.mp3');
                    if (success) {
                      Log.i('Voice message opened successfully', 'CHAT_SCREEN');
                    }
                  } catch (e) {
                    Log.e('Error opening voice message', 'CHAT_SCREEN', e);
                  }
                },
              ),
            ),
          );
        }
      }
    } catch (e) {
      Log.e('Error playing voice message', 'CHAT_SCREEN', e);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error playing voice message: $e')),
        );
      }
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
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Group info not yet implemented')),
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
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withOpacity(0.3)),
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
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(isMobile ? 8 : 12),
            border: Border.all(color: color.withOpacity(0.3)),
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
                      _toggleVoiceRecording();
                    },
                    icon: Icons.mic,
                    label: 'Voice',
                    color: Colors.teal,
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
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.3)),
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
      final videoBytes = await UnifiedMediaService.pickVideoFromGallery(context);
      if (videoBytes != null) {
        await _uploadAndSendMedia(videoBytes, 'video', '🎥 Video from gallery');
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
      final videoBytes = await UnifiedMediaService.pickVideoFromCamera(context);
      if (videoBytes != null) {
        await _uploadAndSendMedia(videoBytes, 'video', '🎥 Video from camera');
      }
    } catch (e) {
      Log.e('Error picking video from camera', 'CHAT_SCREEN', e);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to record video: $e')),
      );
    }
  }

  Future<void> _playVideo(String? mediaUrl) async {
    if (mediaUrl == null) return;

    try {
      Log.i('Playing video message from: $mediaUrl', 'CHAT_SCREEN');

      // Check if it's a Firebase Storage URL
      if (mediaUrl.contains('firebasestorage.googleapis.com')) {
        // Get download URL from Firebase Storage
        try {
          final ref = FirebaseStorage.instance.refFromURL(mediaUrl);
          final downloadUrl = await ref.getDownloadURL();
          Log.i('Got video download URL: $downloadUrl', 'CHAT_SCREEN');

          // For now, show a message that video playback is working
          // TODO: Implement actual video playback using just_audio or audioplayers package
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Video message ready to play: ${mediaUrl.split('/').last}'),
                action: SnackBarAction(
                  label: 'Download',
                  onPressed: () async {
                    try {
                      final success = await DocumentService.openDocument(downloadUrl, 'video_message.mp4');
                      if (success) {
                        Log.i('Video message opened successfully', 'CHAT_SCREEN');
                      }
                    } catch (e) {
                      Log.e('Error opening video message', 'CHAT_SCREEN', e);
                    }
                  },
                ),
              ),
            );
          }
        } catch (e) {
          Log.e('Error getting video download URL', 'CHAT_SCREEN', e);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Error accessing video message: $e')),
            );
          }
        }
      } else {
        // Direct URL
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Video message ready to play: ${mediaUrl.split('/').last}'),
              action: SnackBarAction(
                label: 'Play',
                onPressed: () async {
                  try {
                    final success = await DocumentService.openDocument(mediaUrl, 'video_message.mp4');
                    if (success) {
                      Log.i('Video message opened successfully', 'CHAT_SCREEN');
                    }
                  } catch (e) {
                    Log.e('Error opening video message', 'CHAT_SCREEN', e);
                  }
                },
              ),
            ),
          );
        }
      }
    } catch (e) {
      Log.e('Error playing video message', 'CHAT_SCREEN', e);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error playing video message: $e')),
        );
      }
    }
  }
} 