// =============================================================================
// MODERN MESSAGE BUBBLE WIDGET
// =============================================================================
// A modern, animated message bubble with support for different message types
// and platform-specific styling

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import '../services/theme_service.dart';

class ModernMessageBubble extends StatefulWidget {
  final Map<String, dynamic> message;
  final bool isCurrentUser;
  final bool isGroupChat;
  final Function(String mediaUrl, String type, String caption) onMediaTap;
  final String Function(DateTime timestamp) formatTimestamp;

  const ModernMessageBubble({
    Key? key,
    required this.message,
    required this.isCurrentUser,
    required this.isGroupChat,
    required this.onMediaTap,
    required this.formatTimestamp,
  }) : super(key: key);

  @override
  State<ModernMessageBubble> createState() => _ModernMessageBubbleState();
}

class _ModernMessageBubbleState extends State<ModernMessageBubble>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;
  final ThemeService _themeService = ThemeService();

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
                          _buildTimestamp(timestamp, isDark),
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
          ),
        );
    }
  }

  Widget _buildImageMessage(String content, String? mediaUrl, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (mediaUrl != null && mediaUrl.isNotEmpty)
          GestureDetector(
            onTap: () => widget.onMediaTap(mediaUrl, 'image', content),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.network(
                mediaUrl,
                width: 200,
                height: 200,
                fit: BoxFit.cover,
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) return child;
                  return Container(
                    width: 200,
                    height: 200,
                    color: isDark ? Colors.grey[800] : Colors.grey[200],
                    child: Center(
                      child: CircularProgressIndicator(
                        value: loadingProgress.expectedTotalBytes != null
                            ? loadingProgress.cumulativeBytesLoaded /
                                loadingProgress.expectedTotalBytes!
                            : null,
                      ),
                    ),
                  );
                },
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    width: 200,
                    height: 200,
                    color: isDark ? Colors.grey[800] : Colors.grey[200],
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.broken_image,
                          color: isDark ? Colors.grey[400] : Colors.grey[600],
                          size: 32,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Failed to load image',
                          style: TextStyle(
                            color: isDark ? Colors.grey[400] : Colors.grey[600],
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
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
                color: widget.isCurrentUser
                    ? Colors.white
                    : (isDark ? Colors.white : Colors.black87),
                fontSize: 16,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildVideoMessage(String content, String? mediaUrl, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (mediaUrl != null && mediaUrl.isNotEmpty)
          GestureDetector(
            onTap: () => widget.onMediaTap(mediaUrl, 'video', content),
            child: Container(
              width: 200,
              height: 150,
              decoration: BoxDecoration(
                color: isDark ? Colors.grey[800] : Colors.grey[200],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Stack(
                children: [
                  Center(
                    child: Icon(
                      Icons.play_circle_filled,
                      size: 48,
                      color: widget.isCurrentUser
                          ? Colors.white70
                          : (isDark ? Colors.white70 : Colors.black54),
                    ),
                  ),
                  Positioned(
                    bottom: 8,
                    right: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text(
                        'VIDEO',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
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
                color: widget.isCurrentUser
                    ? Colors.white
                    : (isDark ? Colors.white : Colors.black87),
                fontSize: 16,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildAudioMessage(String content, String? mediaUrl, bool isDark) {
    return Row(
      children: [
        Icon(
          Icons.audiotrack,
          color: widget.isCurrentUser
              ? Colors.white70
              : (isDark ? Colors.white70 : Colors.black54),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            content.isNotEmpty ? content : 'Audio message',
            style: TextStyle(
              color: widget.isCurrentUser
                  ? Colors.white
                  : (isDark ? Colors.white : Colors.black87),
              fontSize: 16,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDocumentMessage(String content, String? mediaUrl, bool isDark) {
    return Row(
      children: [
        Icon(
          Icons.insert_drive_file,
          color: widget.isCurrentUser
              ? Colors.white70
              : (isDark ? Colors.white70 : Colors.black54),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            content.isNotEmpty ? content : 'Document',
            style: TextStyle(
              color: widget.isCurrentUser
                  ? Colors.white
                  : (isDark ? Colors.white : Colors.black87),
              fontSize: 16,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTimestamp(DateTime timestamp, bool isDark) {
    return Text(
      widget.formatTimestamp(timestamp),
      style: TextStyle(
        fontSize: 11,
        color: isDark ? Colors.grey[500] : Colors.grey[600],
      ),
    );
  }
}
