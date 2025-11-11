// =============================================================================
// MODERN MESSAGE BUBBLE WIDGET
// =============================================================================
// A modern, animated message bubble with support for different message types
// and platform-specific styling

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import '../services/theme_service.dart';
import '../utils/responsive_utils.dart';
import 'enhanced_media_preview.dart';

class ModernMessageBubble extends StatefulWidget {
  final Map<String, dynamic> message;
  final bool isCurrentUser;
  final bool isGroupChat;
  final Function(String mediaUrl, String type, String caption) onMediaTap;
  final String Function(DateTime timestamp) formatTimestamp;
  final String? currentUserId; // Required for checking read status

  const ModernMessageBubble({
    Key? key,
    required this.message,
    required this.isCurrentUser,
    required this.isGroupChat,
    required this.onMediaTap,
    required this.formatTimestamp,
    this.currentUserId,
  }) : super(key: key);

  @override
  State<ModernMessageBubble> createState() => _ModernMessageBubbleState();
}

class _ModernMessageBubbleState extends State<ModernMessageBubble>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.elasticOut,
    ));

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeIn,
    ));

    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  String _extractContent(Map<String, dynamic> message) {
    return message['content'] ?? message['text'] ?? '';
  }

  String _extractType(Map<String, dynamic> message) {
    return message['messageType'] ?? message['type'] ?? 'text';
  }

  DateTime _extractTimestamp(Map<String, dynamic> message) {
    final timestamp = message['timestamp'] ?? message['createdAt'];
    if (timestamp is String) {
      return DateTime.parse(timestamp);
    } else if (timestamp is DateTime) {
      return timestamp;
    }
    return DateTime.now();
  }

  String _extractSenderName(Map<String, dynamic> message) {
    return message['senderName'] ?? message['sender'] ?? 'Unknown';
  }

  String? _extractMediaUrl(Map<String, dynamic> message) {
    return message['mediaUrl'] ?? message['url'];
  }

  List<dynamic> _extractReadBy(Map<String, dynamic> message) {
    final readBy = message['readBy'] ?? [];
    if (readBy is List) {
      // Convert all to strings for consistent comparison
      return readBy.map((id) => id?.toString() ?? '').toList();
    }
    return [];
  }

  String? _extractStatus(Map<String, dynamic> message) {
    return message['status'] ?? message['messageStatus'];
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final content = _extractContent(widget.message);
    final messageType = _extractType(widget.message);
    final timestamp = _extractTimestamp(widget.message);
    final senderName = _extractSenderName(widget.message);
    final mediaUrl = _extractMediaUrl(widget.message);

    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        return Transform.scale(
          scale: _scaleAnimation.value,
          child: Opacity(
            opacity: _fadeAnimation.value,
            child: Container(
              margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
              child: Row(
                mainAxisAlignment: widget.isCurrentUser 
                    ? MainAxisAlignment.end 
                    : MainAxisAlignment.start,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  if (!widget.isCurrentUser) ...[
                    _buildAvatar(senderName, isDark),
                    const SizedBox(width: 8),
                  ],
                  Flexible(
                    child: Container(
                      constraints: BoxConstraints(
                        maxWidth: MediaQuery.of(context).size.width * 0.75,
                      ),
                      child: Column(
                        crossAxisAlignment: widget.isCurrentUser 
                            ? CrossAxisAlignment.end 
                            : CrossAxisAlignment.start,
                        children: [
                          if (!widget.isCurrentUser && widget.isGroupChat)
                            _buildSenderName(senderName, isDark),
                          _buildMessageContent(
                            content, 
                            messageType, 
                            mediaUrl, 
                            isDark,
                            theme,
                          ),
                          const SizedBox(height: 4),
                          _buildTimestampRow(timestamp, isDark),
                        ],
                      ),
                    ),
                  ),
                  if (widget.isCurrentUser) ...[
                    const SizedBox(width: 8),
                    _buildAvatar(senderName, isDark),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildAvatar(String senderName, bool isDark) {
    return CircleAvatar(
      radius: 16,
      backgroundColor: widget.isCurrentUser
          ? (isDark ? Colors.blue[700] : Colors.blue[500])
          : (isDark ? Colors.grey[700] : Colors.grey[300]),
      child: Text(
        senderName.isNotEmpty ? senderName[0].toUpperCase() : 'U',
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      ),
    );
  }

  Widget _buildSenderName(String senderName, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Text(
        senderName,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: isDark ? Colors.white70 : Colors.black54,
        ),
      ),
    );
  }

  Widget _buildMessageContent(
    String content,
    String messageType,
    String? mediaUrl,
    bool isDark,
    ThemeData theme,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: widget.isCurrentUser
            ? (isDark ? Colors.blue[700] : Colors.blue[500])
            : (isDark ? Colors.grey[800] : Colors.grey[200]),
        borderRadius: BorderRadius.only(
          topLeft: const Radius.circular(18),
          topRight: const Radius.circular(18),
          bottomLeft: widget.isCurrentUser 
              ? const Radius.circular(18) 
              : const Radius.circular(4),
          bottomRight: widget.isCurrentUser 
              ? const Radius.circular(4) 
              : const Radius.circular(18),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: _buildMessageByType(content, messageType, mediaUrl, isDark),
    );
  }

  Widget _buildMessageByType(String content, String messageType, String? mediaUrl, bool isDark) {
    switch (messageType) {
      case 'text':
        return Text(
          content,
          style: TextStyle(
            color: widget.isCurrentUser
                ? Colors.white
                : (isDark ? Colors.white : Colors.black87),
            fontSize: 16,
            fontFamily: kIsWeb ? ResponsiveUtils.getEmojiFontFamily() : null,
            fontFeatures: kIsWeb ? [const FontFeature.enable('liga')] : null,
          ),
        );

      case 'image':
        return _buildImageMessage(content, mediaUrl, isDark);

      case 'video':
        return _buildVideoMessage(content, mediaUrl, isDark);

      case 'audio':
        return _buildAudioMessage(content, mediaUrl, isDark);

      case 'document':
        return _buildDocumentMessage(content, mediaUrl, isDark);

      default:
        return Text(
          content,
          style: TextStyle(
            color: widget.isCurrentUser
                ? Colors.white
                : (isDark ? Colors.white : Colors.black87),
            fontSize: 16,
            fontFamily: kIsWeb ? ResponsiveUtils.getEmojiFontFamily() : null,
            fontFeatures: kIsWeb ? [const FontFeature.enable('liga')] : null,
          ),
        );
    }
  }

  Widget _buildImageMessage(String content, String? mediaUrl, bool isDark) {
    final isMobile = ResponsiveUtils.isMobile(context);
    final isTablet = ResponsiveUtils.isTablet(context);
    final maxWidth = ResponsiveUtils.getResponsiveValue(
      context,
      mobile: 250.0,
      tablet: 300.0,
      desktop: 400.0,
    );
    final maxHeight = ResponsiveUtils.getResponsiveValue(
      context,
      mobile: 250.0,
      tablet: 300.0,
      desktop: 400.0,
    );
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (mediaUrl != null && mediaUrl.isNotEmpty)
          GestureDetector(
            onTap: () => widget.onMediaTap(mediaUrl, 'image', content),
            child: Container(
              constraints: BoxConstraints(
                maxWidth: maxWidth,
                maxHeight: maxHeight,
              ),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: EnhancedMediaPreview(
                  mediaUrl: mediaUrl,
                  mediaType: 'image',
                  fileName: content.isNotEmpty ? content : 'Image',
                  onTap: () => widget.onMediaTap(mediaUrl, 'image', content),
                  maxWidth: maxWidth,
                  maxHeight: maxHeight,
                  enableRetry: true,
                ),
              ),
            ),
          ),
        if (content.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              content,
              style: TextStyle(
                color: widget.isCurrentUser
                    ? Colors.white
                    : (isDark ? Colors.white : Colors.black87),
                fontSize: 16,
                fontFamily: kIsWeb ? ResponsiveUtils.getEmojiFontFamily() : null,
                fontFeatures: kIsWeb ? [const FontFeature.enable('liga')] : null,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildVideoMessage(String content, String? mediaUrl, bool isDark) {
    final isMobile = ResponsiveUtils.isMobile(context);
    final isTablet = ResponsiveUtils.isTablet(context);
    final maxWidth = ResponsiveUtils.getResponsiveValue(
      context,
      mobile: 250.0,
      tablet: 300.0,
      desktop: 400.0,
    );
    final maxHeight = ResponsiveUtils.getResponsiveValue(
      context,
      mobile: 180.0,
      tablet: 200.0,
      desktop: 240.0,
    );
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (mediaUrl != null && mediaUrl.isNotEmpty)
          GestureDetector(
            onTap: () => widget.onMediaTap(mediaUrl, 'video', content),
            child: Container(
              constraints: BoxConstraints(
                maxWidth: maxWidth,
                maxHeight: maxHeight,
              ),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: EnhancedMediaPreview(
                  mediaUrl: mediaUrl,
                  mediaType: 'video',
                  fileName: content.isNotEmpty ? content : 'Video',
                  onTap: () => widget.onMediaTap(mediaUrl, 'video', content),
                  maxWidth: maxWidth,
                  maxHeight: maxHeight,
                  enableRetry: true,
                ),
              ),
            ),
          ),
        if (content.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              content,
              style: TextStyle(
                color: widget.isCurrentUser
                    ? Colors.white
                    : (isDark ? Colors.white : Colors.black87),
                fontSize: 16,
                fontFamily: kIsWeb ? ResponsiveUtils.getEmojiFontFamily() : null,
                fontFeatures: kIsWeb ? [const FontFeature.enable('liga')] : null,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildAudioMessage(String content, String? mediaUrl, bool isDark) {
    return Container(
      constraints: const BoxConstraints(
        maxWidth: 200,
        maxHeight: 80,
      ),
      child: EnhancedMediaPreview(
        mediaUrl: mediaUrl ?? '',
        mediaType: 'voice',
        fileName: content.isNotEmpty ? content : 'Audio message',
        onTap: () {
          if (mediaUrl != null) {
            widget.onMediaTap(mediaUrl, 'audio', content);
          }
        },
        maxWidth: 200,
        maxHeight: 80,
        enableRetry: true,
      ),
    );
  }

  Widget _buildDocumentMessage(String content, String? mediaUrl, bool isDark) {
    final isMobile = ResponsiveUtils.isMobile(context);
    final isTablet = ResponsiveUtils.isTablet(context);
    final maxWidth = ResponsiveUtils.getResponsiveValue(
      context,
      mobile: 220.0,
      tablet: 280.0,
      desktop: 350.0,
    );
    final maxHeight = ResponsiveUtils.getResponsiveValue(
      context,
      mobile: 150.0,
      tablet: 180.0,
      desktop: 220.0,
    );
    
    return Container(
      constraints: BoxConstraints(
        maxWidth: maxWidth,
        maxHeight: maxHeight,
      ),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: EnhancedMediaPreview(
          mediaUrl: mediaUrl ?? '',
          mediaType: 'document',
          fileName: content.isNotEmpty ? content : 'Document',
          onTap: () {
            if (mediaUrl != null) {
              widget.onMediaTap(mediaUrl, 'document', content);
            }
          },
          maxWidth: maxWidth,
          maxHeight: maxHeight,
          enableRetry: true,
        ),
      ),
    );
  }

  Widget _buildTimestampRow(DateTime timestamp, bool isDark) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          widget.formatTimestamp(timestamp),
          style: TextStyle(
            fontSize: 11,
            color: isDark ? Colors.grey[500] : Colors.grey[600],
          ),
        ),
        if (widget.isCurrentUser) ...[
          const SizedBox(width: 4),
          _buildMessageStatus(isDark),
        ],
      ],
    );
  }

  Widget _buildMessageStatus(bool isDark) {
    final readBy = _extractReadBy(widget.message);
    final status = _extractStatus(widget.message);
    final senderId = _extractSenderId(widget.message);
    
    // For group chats, show read count (exclude sender)
    if (widget.isGroupChat) {
      final readCount = readBy.where((id) => 
        id.toString() != senderId.toString()
      ).length;
      return _buildGroupStatus(readCount, isDark);
    }
    
    // For one-to-one chats, show status indicator
    // We need to determine if the recipient has read it
    // Since we don't have recipient ID directly, we check:
    // - If readBy has items and status is 'read', it's read
    // - If readBy has items but status isn't 'read', it's delivered  
    // - Otherwise it's sent
    return _buildOneToOneStatus(readBy, status, isDark);
  }

  String? _extractSenderId(Map<String, dynamic> message) {
    final v = message['senderId'] ?? message['sender_id'];
    return v?.toString();
  }

  Widget _buildOneToOneStatus(List<dynamic> readBy, String? status, bool isDark) {
    IconData icon;
    Color color;
    String? tooltip;
    final senderId = _extractSenderId(widget.message);
    
    // Filter out sender from readBy (sender reading their own message doesn't count)
    final recipientReadBy = readBy.where((id) => 
      id.toString() != senderId.toString()
    ).toList();
    
    // Check if message is read by recipient
    final isRead = recipientReadBy.isNotEmpty || status == 'read';
    
    if (isRead) {
      // Read: Double check blue
      icon = Icons.done_all;
      color = widget.isCurrentUser 
          ? (isDark ? Colors.blue[300]! : Colors.blue[100]!)
          : Colors.blue;
      tooltip = 'Read';
    } else if (status == 'delivered' || readBy.isNotEmpty) {
      // Delivered: Double check grey
      icon = Icons.done_all;
      color = widget.isCurrentUser 
          ? (isDark ? Colors.white70 : Colors.white70)
          : (isDark ? Colors.grey[400]! : Colors.grey[600]!);
      tooltip = 'Delivered';
    } else {
      // Sent: Single check grey
      icon = Icons.done;
      color = widget.isCurrentUser 
          ? (isDark ? Colors.white70 : Colors.white70)
          : (isDark ? Colors.grey[400]! : Colors.grey[600]!);
      tooltip = 'Sent';
    }
    
    return Tooltip(
      message: tooltip,
      child: Icon(
        icon,
        size: 14,
        color: color,
      ),
    );
  }

  Widget _buildGroupStatus(int readCount, bool isDark) {
    if (readCount == 0) {
      // Sent but not read by anyone
      return Tooltip(
        message: 'Sent',
        child: Icon(
          Icons.done,
          size: 14,
          color: widget.isCurrentUser 
              ? (isDark ? Colors.white70 : Colors.white70)
              : (isDark ? Colors.grey[400]! : Colors.grey[600]!),
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
            color: widget.isCurrentUser 
                ? (isDark ? Colors.blue[300]! : Colors.blue[100]!)
                : Colors.blue,
          ),
          const SizedBox(width: 2),
          Text(
            '$readCount',
            style: TextStyle(
              fontSize: 10,
              color: widget.isCurrentUser 
                  ? (isDark ? Colors.white70 : Colors.white70)
                  : (isDark ? Colors.grey[400]! : Colors.grey[600]!),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
