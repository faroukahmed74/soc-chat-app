import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../widgets/emoji_picker.dart';
import '../widgets/enhanced_media_sender.dart';

/// Enhanced chat input widget with emoji picker and media attachment
class EnhancedChatInput extends StatefulWidget {
  final TextEditingController controller;
  final Future<void> Function(String) onSendMessage;
  final Future<void> Function(String, String, {String? content}) onSendMedia;
  final String chatId;
  final bool isEnabled;

  const EnhancedChatInput({
    super.key,
    required this.controller,
    required this.onSendMessage,
    required this.onSendMedia,
    required this.chatId,
    this.isEnabled = true,
  });

  @override
  State<EnhancedChatInput> createState() => _EnhancedChatInputState();
}

class _EnhancedChatInputState extends State<EnhancedChatInput> {
  bool _showEmojiPicker = false;
  bool _showMediaSender = false;
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(() {
      if (_focusNode.hasFocus) {
        setState(() {
          _showEmojiPicker = false;
        });
      }
    });
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  void _toggleEmojiPicker() {
    setState(() {
      _showEmojiPicker = !_showEmojiPicker;
      _showMediaSender = false;
    });
    
    if (_showEmojiPicker) {
      _focusNode.unfocus();
    } else {
      _focusNode.requestFocus();
    }
  }

  void _toggleMediaSender() {
    setState(() {
      _showMediaSender = !_showMediaSender;
      _showEmojiPicker = false;
    });
    
    if (_showMediaSender) {
      _focusNode.unfocus();
    } else {
      _focusNode.requestFocus();
    }
  }

  void _onEmojiSelected(String emoji) {
    final currentText = widget.controller.text;
    final cursorPosition = widget.controller.selection.baseOffset;
    
    final newText = currentText.substring(0, cursorPosition) + 
                   emoji + 
                   currentText.substring(cursorPosition);
    
    widget.controller.text = newText;
    widget.controller.selection = TextSelection.fromPosition(
      TextPosition(offset: cursorPosition + emoji.length),
    );
    
    HapticFeedback.lightImpact();
  }

  void _sendMessage() {
    final text = widget.controller.text.trim();
    if (text.isNotEmpty && widget.isEnabled) {
      widget.onSendMessage(text);
      widget.controller.clear();
      HapticFeedback.mediumImpact();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Column(
      children: [
        // Media sender overlay
        if (_showMediaSender)
          Container(
            height: 300,
            child: EnhancedMediaSender(
              chatId: widget.chatId,
              onMediaSent: (mediaUrl, type, text) {
                widget.onSendMedia(mediaUrl, type, content: text);
                setState(() {
                  _showMediaSender = false;
                });
                _focusNode.requestFocus();
              },
              onClose: () {
                setState(() {
                  _showMediaSender = false;
                });
                _focusNode.requestFocus();
              },
            ),
          ),

        // Emoji picker overlay
        if (_showEmojiPicker)
          EmojiPicker(
            onEmojiSelected: _onEmojiSelected,
            onClose: () {
              setState(() {
                _showEmojiPicker = false;
              });
              _focusNode.requestFocus();
            },
          ),

        // Main input area
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: isDark ? Colors.grey[900] : Colors.white,
            border: Border(
              top: BorderSide(
                color: isDark ? Colors.grey[700]! : Colors.grey[300]!,
                width: 1,
              ),
            ),
          ),
          child: SafeArea(
            child: Row(
              children: [
                // Emoji button
                IconButton(
                  onPressed: _toggleEmojiPicker,
                  icon: Icon(
                    _showEmojiPicker ? Icons.keyboard : Icons.emoji_emotions_outlined,
                    color: _showEmojiPicker 
                        ? theme.primaryColor 
                        : (isDark ? Colors.grey[400] : Colors.grey[600]),
                  ),
                ),

                // Attachment button
                IconButton(
                  onPressed: _toggleMediaSender,
                  icon: Icon(
                    _showMediaSender ? Icons.close : Icons.attach_file,
                    color: _showMediaSender 
                        ? theme.primaryColor 
                        : (isDark ? Colors.grey[400] : Colors.grey[600]),
                  ),
                ),

                // Text input
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: isDark ? Colors.grey[800] : Colors.grey[100],
                      borderRadius: BorderRadius.circular(25),
                    ),
                    child: TextField(
                      controller: widget.controller,
                      focusNode: _focusNode,
                      enabled: widget.isEnabled,
                      maxLines: null,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: InputDecoration(
                        hintText: 'Type a message...',
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        hintStyle: TextStyle(
                          color: isDark ? Colors.grey[500] : Colors.grey[600],
                        ),
                      ),
                      style: TextStyle(
                        color: isDark ? Colors.white : Colors.black87,
                        fontSize: 16,
                      ),
                      onSubmitted: (_) => _sendMessage(),
                    ),
                  ),
                ),

                const SizedBox(width: 8),

                // Send button
                Container(
                  decoration: BoxDecoration(
                    color: widget.controller.text.trim().isNotEmpty && widget.isEnabled
                        ? theme.primaryColor
                        : Colors.grey[400],
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    onPressed: widget.controller.text.trim().isNotEmpty && widget.isEnabled
                        ? _sendMessage
                        : null,
                    icon: const Icon(
                      Icons.send,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
