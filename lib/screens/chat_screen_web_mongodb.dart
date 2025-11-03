// =============================================================================
// CHAT SCREEN WEB - MONGODB VERSION
// =============================================================================
// This screen displays individual chat conversations using MongoDB
// It handles message sending, media uploads, and real-time updates for web

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:async';
import 'dart:typed_data';
import '../services/theme_service.dart';
import '../services/mongodb_chat_service.dart';
import '../services/logger_service.dart';
import '../services/physical_auth_service.dart';
import '../services/message_sound_service.dart';
import '../services/enhanced_unified_media_service.dart';
import '../services/document_service.dart';
import '../services/media_cache_service.dart';
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
  Timer? _statusUpdateTimer;
  late ThemeService _themeService;
  
  // User status for one-to-one chats
  bool? _otherUserIsOnline;
  DateTime? _otherUserLastSeen;
  String? _otherUserId;
  List<String>? _memberIds; // Store member IDs for status checking
  
  // Track previous message IDs for sound detection
  final Set<String> _previousMessageIds = {};
  
  // Media selection state
  Uint8List? _selectedMediaBytes;
  String? _selectedMediaType;
  String? _selectedMediaFileName;
  bool _isUploadingMedia = false;

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
    _statusUpdateTimer?.cancel();
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
    // Initialize previous message IDs from current messages
    _previousMessageIds.clear();
    _previousMessageIds.addAll(_messages.map((m) => 
      (m['_id']?.toString() ?? m['id']?.toString() ?? '')
    ).where((id) => id.isNotEmpty));
    
    _messagesSubscription = _chatService.watchChatMessages(widget.chatId).listen(
      (messages) {
        if (mounted) {
          // Check if there are NEW messages from other users (for sound notification)
          // Compare BEFORE updating state
          final hasNewMessagesFromOthers = messages.any((m) {
            final messageId = (m['_id']?.toString() ?? m['id']?.toString() ?? '');
            final senderId = m['senderId']?.toString() ?? '';
            final isNew = messageId.isNotEmpty && !_previousMessageIds.contains(messageId);
            final isFromOthers = senderId.isNotEmpty && senderId != _currentUserId?.toString();
            return isNew && isFromOthers;
          });
          
          // Update previous message IDs for next check
          _previousMessageIds.clear();
          _previousMessageIds.addAll(messages.map((m) => 
            (m['_id']?.toString() ?? m['id']?.toString() ?? '')
          ).where((id) => id.isNotEmpty));
          
          setState(() {
            _messages = messages;
          });
          
          // Play sound for new messages from others
          if (hasNewMessagesFromOthers && _currentUserId != null) {
            Log.i('🔊 New message detected, playing sound...', 'CHAT_SCREEN_WEB_MONGODB');
            MessageSoundService().playMessageSound();
          }
          
          // Mark messages as read
          _markMessagesAsRead(_messages);
          
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

  Future<void> _pickImageFromGallery() async {
    try {
      final result = await EnhancedUnifiedMediaService.pickImageFromGallery(context);
      if (result != null) {
        setState(() {
          _selectedMediaBytes = result.bytes;
          _selectedMediaType = result.type;
          _selectedMediaFileName = result.fileName;
        });
      }
    } catch (e) {
      Log.e('Error picking image from gallery', 'CHAT_SCREEN_WEB_MONGODB', e);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to pick image: $e')),
      );
    }
  }

  Future<void> _pickImageFromCamera() async {
    try {
      final result = await EnhancedUnifiedMediaService.pickImageFromCamera(context);
      if (result != null) {
        setState(() {
          _selectedMediaBytes = result.bytes;
          _selectedMediaType = result.type;
          _selectedMediaFileName = result.fileName;
        });
      }
    } catch (e) {
      Log.e('Error picking image from camera', 'CHAT_SCREEN_WEB_MONGODB', e);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to take photo: $e')),
      );
    }
  }

  Future<void> _pickVideoFromGallery() async {
    try {
      final result = await EnhancedUnifiedMediaService.pickVideoFromGallery(context);
      if (result != null) {
        setState(() {
          _selectedMediaBytes = result.bytes;
          _selectedMediaType = 'video';
          _selectedMediaFileName = result.fileName;
        });
      }
    } catch (e) {
      Log.e('Error picking video from gallery', 'CHAT_SCREEN_WEB_MONGODB', e);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to pick video: $e')),
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
          setState(() {
            _selectedMediaBytes = fileBytes;
            _selectedMediaType = 'document';
            _selectedMediaFileName = file.name;
          });
        }
      }
    } catch (e) {
      Log.e('Error picking document', 'CHAT_SCREEN_WEB_MONGODB', e);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to pick document: $e')),
      );
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

  Widget _buildMessageStatus(Map<String, dynamic> message) {
    final readBy = _extractReadBy(message);
    final status = message['status'] ?? message['messageStatus'];
    final senderId = message['senderId']?.toString() ?? '';
    
    // For group chats, show read count (exclude sender)
    if (widget.isGroupChat) {
      final readCount = readBy.where((id) => 
        id.toString() != senderId
      ).length;
      return _buildGroupStatus(readCount);
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
    
    return _buildOneToOneStatus(readBy, status, recipientId);
  }

  List<dynamic> _extractReadBy(Map<String, dynamic> message) {
    final readBy = message['readBy'] ?? [];
    if (readBy is List) {
      // Convert all to strings for consistent comparison
      return readBy.map((id) => id?.toString() ?? '').toList();
    }
    return [];
  }

  Widget _buildOneToOneStatus(List<dynamic> readBy, String? status, String? recipientId) {
    IconData icon;
    Color color;
    String? tooltip;
    
    // Check if recipient has read the message
    final isRead = recipientId != null && 
                   recipientId.isNotEmpty && 
                   readBy.any((id) => id.toString() == recipientId.toString());
    
    if (isRead || status == 'read') {
      // Read: Double check blue
      icon = Icons.done_all;
      color = Colors.blue;
      tooltip = 'Read';
    } else if (readBy.isNotEmpty && !isRead) {
      // Delivered: Double check grey (someone read it, but might not be recipient in group context)
      // For one-to-one, if readBy has items but recipient hasn't read, it's delivered
      icon = Icons.done_all;
      color = _themeService.isDarkMode ? Colors.grey[400]! : Colors.grey[600]!;
      tooltip = 'Delivered';
    } else if (status == 'delivered') {
      // Explicitly delivered status
      icon = Icons.done_all;
      color = _themeService.isDarkMode ? Colors.grey[400]! : Colors.grey[600]!;
      tooltip = 'Delivered';
    } else {
      // Sent: Single check grey
      icon = Icons.done;
      color = _themeService.isDarkMode ? Colors.grey[400]! : Colors.grey[600]!;
      tooltip = 'Sent';
    }
    
    return Tooltip(
      message: tooltip,
      child: Icon(
        icon,
        size: 14,
        color: Colors.white70,
      ),
    );
  }

  Widget _buildGroupStatus(int readCount) {
    if (readCount == 0) {
      // Sent but not read by anyone
      return Tooltip(
        message: 'Sent',
        child: Icon(
          Icons.done,
          size: 14,
          color: Colors.white70,
        ),
      );
    }
    
    // Show read count in group chats: Double check blue with count
    return Tooltip(
      message: '$readCount ${readCount == 1 ? 'person has' : 'people have'} read',
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.done_all,
            size: 14,
            color: Colors.blue,
          ),
          const SizedBox(width: 2),
          Text(
            '$readCount',
            style: TextStyle(
              color: Colors.white70,
              fontWeight: FontWeight.w500,
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _markMessagesAsRead(List<Map<String, dynamic>> messages) async {
    try {
      if (_currentUserId == null || messages.isEmpty) return;
      
      // Get unread messages (sent by others, not already read by current user)
      final unreadMessages = messages.where((m) {
        final senderId = m['senderId']?.toString() ?? '';
        final readBy = _extractReadBy(m);
        final isFromOthers = senderId != '' && senderId != _currentUserId.toString();
        final alreadyRead = readBy.any((id) => id.toString() == _currentUserId.toString());
        return isFromOthers && !alreadyRead;
      }).toList();
      
      if (unreadMessages.isEmpty) return;
      
      final messageIds = unreadMessages
          .map((m) => m['_id']?.toString() ?? m['id']?.toString())
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
      Log.e('Error marking messages as read', 'CHAT_SCREEN_WEB_MONGODB', e);
    }
  }

  Future<void> _updateUserStatus() async {
    if (_otherUserId == null || _otherUserId!.isEmpty) return;
    
    try {
      final userDetails = await _chatService.getUserDetails(_otherUserId!);
      if (userDetails != null && mounted) {
        setState(() {
          _otherUserIsOnline = userDetails['isOnline'] ?? false;
          final lastSeenStr = userDetails['lastSeen'];
          if (lastSeenStr != null) {
            if (lastSeenStr is String) {
              _otherUserLastSeen = DateTime.tryParse(lastSeenStr);
            } else if (lastSeenStr is Map && lastSeenStr['\$date'] != null) {
              final timestamp = lastSeenStr['\$date'];
              if (timestamp is int) {
                _otherUserLastSeen = DateTime.fromMillisecondsSinceEpoch(timestamp);
              }
            }
          }
        });
      }
    } catch (e) {
      Log.e('Error fetching user status', 'CHAT_SCREEN_WEB_MONGODB', e);
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
                          child: GestureDetector(
                            onTap: () => _tryPlayVideo(message['mediaUrl'] ?? '', content),
                            child: Stack(
                              children: [
                                // Video thumbnail/background
                                Container(
                                  width: 200,
                                  height: 150,
                                  decoration: BoxDecoration(
                                    color: Theme.of(context).colorScheme.surfaceVariant,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Center(
                                    child: Icon(
                                      Icons.play_circle_filled,
                                      size: 48,
                                      color: Theme.of(context).colorScheme.primary,
                                    ),
                                  ),
                                ),
                                // Play button overlay
                                Positioned(
                                  bottom: 8,
                                  right: 8,
                                  child: Container(
                                    padding: const EdgeInsets.all(6),
                                    decoration: BoxDecoration(
                                      color: Colors.black.withOpacity(0.7),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: const Icon(
                                      Icons.play_arrow,
                                      color: Colors.white,
                                      size: 20,
                                    ),
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
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Text(
                        _formatTimestamp(timestamp),
                        style: TextStyle(
                          fontSize: 10,
                          color: isCurrentUser
                              ? Colors.white70
                              : (_themeService.isDarkMode ? Colors.white54 : Colors.black54),
                        ),
                      ),
                      if (isCurrentUser) ...[
                        const SizedBox(width: 4),
                        _buildMessageStatus(message),
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
    // CRITICAL: Resolve URL to local network on web (convert ngrok to IPv4)
    final resolvedUrl = _resolveWebSameOriginUrl(mediaUrl);
    Log.d('Full Screen Media - Original: $mediaUrl, Resolved: $resolvedUrl', 'CHAT_SCREEN_WEB');
    
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => EnhancedFullScreenMediaPreview(
          mediaUrl: resolvedUrl, // Use resolved URL (local network) instead of ngrok
          mediaType: mediaType,
          fileName: fileName.isNotEmpty ? fileName : null,
        ),
      ),
    );
  }

  Future<void> _tryPlayVideo(String mediaUrl, String caption) async {
    // Try to play video in browser using HTML5 video
    try {
      // Use HTML5 video player via url_launcher
      final resolved = _resolveWebSameOriginUrl(mediaUrl);
      if (await canLaunchUrl(Uri.parse(resolved))) {
        // Try to open in external player first
        await launchUrl(Uri.parse(resolved), mode: LaunchMode.externalApplication);
      } else {
        // If that fails, show full screen preview (which will show download option if format is unsupported)
        _showFullScreenMedia(resolved, 'video', caption);
      }
    } catch (e) {
      Log.e('Error playing video', 'CHAT_SCREEN_WEB', e);
      // Fallback to full screen preview
      _showFullScreenMedia(_resolveWebSameOriginUrl(mediaUrl), 'video', caption);
    }
  }

  // Resolve media URL to same-origin on web for direct loading/downloading
  String _resolveWebSameOriginUrl(String url) {
    if (!kIsWeb) return url;
    try {
      final parsed = Uri.parse(url);
      if (parsed.scheme == 'blob' || parsed.scheme == 'data') return url;
      if (parsed.host.contains('firebasestorage.googleapis.com')) return url;
      final base = Uri.base;
      final p = parsed.path;

      // Prefer rewriting known server paths to same-origin
      if (p.startsWith('/uploads') || p.contains('/uploads/')) {
        return Uri.parse('${base.origin}$p${parsed.hasQuery ? '?${parsed.query}' : ''}').toString();
      }

      // Handle legacy /chat_media URLs by prefixing /uploads
      if (p.startsWith('/chat_media') || p.contains('/chat_media/')) {
        final adjustedPath = '/uploads' + (p.startsWith('/') ? p : '/$p');
        return Uri.parse('${base.origin}$adjustedPath${parsed.hasQuery ? '?${parsed.query}' : ''}').toString();
      }

      // Proxy API calls to same-origin
      if (p.startsWith('/api/')) {
        return Uri.parse('${base.origin}$p${parsed.hasQuery ? '?${parsed.query}' : ''}').toString();
      }

      // If already same-origin or an external URL, leave as-is
      final originUrl = '${parsed.scheme}://${parsed.host}${parsed.hasPort ? ':${parsed.port}' : ''}';
      if (originUrl == base.origin) return url;
      return url;
    } catch (_) {
      return url;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(widget.chatName),
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
                        color: Colors.white.withOpacity(0.8),
                        fontWeight: FontWeight.normal,
                      ),
                    ),
                  ] else if (_otherUserLastSeen != null) ...[
                    Text(
                      _formatLastSeen(_otherUserLastSeen),
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.white.withOpacity(0.8),
                        fontWeight: FontWeight.normal,
                      ),
                    ),
                  ] else ...[
                    Text(
                      'Loading...',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.white.withOpacity(0.8),
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
                  color: Colors.white.withOpacity(0.8),
                  fontWeight: FontWeight.normal,
                ),
              ),
            ],
          ],
        ),
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
            selectedMediaBytes: _selectedMediaBytes,
            selectedMediaType: _selectedMediaType,
            selectedMediaFileName: _selectedMediaFileName,
            onClearMedia: () {
              setState(() {
                _selectedMediaBytes = null;
                _selectedMediaType = null;
                _selectedMediaFileName = null;
              });
            },
          ),
        ],
      ),
    );
  }
}
