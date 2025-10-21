// =============================================================================
// ENHANCED CHAT INPUT WIDGET - IMPROVED VERSION
// =============================================================================
// A modern chat input with better media handling, emoji support, and animations

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import '../widgets/emoji_picker.dart';
import '../widgets/enhanced_media_sender.dart';

class EnhancedChatInput extends StatefulWidget {
  final TextEditingController controller;
  final Future<void> Function(String) onSendMessage;
  final Future<void> Function(String, String, {String? content}) onSendMedia;
  final String chatId;
  final bool isEnabled;
  final Function(String)? onTextChanged;

  const EnhancedChatInput({
    super.key,
    required this.controller,
    required this.onSendMessage,
    required this.onSendMedia,
    required this.chatId,
    this.isEnabled = true,
    this.onTextChanged,
  });

  @override
  State<EnhancedChatInput> createState() => _EnhancedChatInputState();
}

class _EnhancedChatInputState extends State<EnhancedChatInput>
    with TickerProviderStateMixin {
  bool _showEmojiPicker = false;
  bool _showMediaSender = false;
  final FocusNode _focusNode = FocusNode();
  late AnimationController _animationController;
  late Animation<double> _slideAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _setupAnimations();
    _focusNode.addListener(_onFocusChanged);
    widget.controller.addListener(_onTextChanged);
  }

  void _setupAnimations() {
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _slideAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeIn,
    ));
  }

  void _onFocusChanged() {
    if (_focusNode.hasFocus) {
      setState(() {
        _showEmojiPicker = false;
        _showMediaSender = false;
      });
    }
  }

  void _onTextChanged() {
    widget.onTextChanged?.call(widget.controller.text);
  }

  @override
  void dispose() {
    _focusNode.dispose();
    _animationController.dispose();
    super.dispose();
  }

  void _toggleEmojiPicker() {
    setState(() {
      _showEmojiPicker = !_showEmojiPicker;
      _showMediaSender = false;
    });
    
    if (_showEmojiPicker) {
      _focusNode.unfocus();
      _animationController.forward();
    } else {
      _focusNode.requestFocus();
      _animationController.reverse();
    }
  }

  void _toggleMediaSender() {
    setState(() {
      _showMediaSender = !_showMediaSender;
      _showEmojiPicker = false;
    });
    
    if (_showMediaSender) {
      _focusNode.unfocus();
      _animationController.forward();
    } else {
      _focusNode.requestFocus();
      _animationController.reverse();
    }
  }

  void _onEmojiSelected(String emoji) {
    final text = widget.controller.text;
    final selection = widget.controller.selection;
    final newText = text.replaceRange(
      selection.start,
      selection.end,
      emoji,
    );
    widget.controller.text = newText;
    widget.controller.selection = TextSelection.fromPosition(
      TextPosition(offset: selection.start + emoji.length),
    );
  }

  Future<void> _sendMessage() async {
    final text = widget.controller.text.trim();
    if (text.isEmpty || !widget.isEnabled) return;

    widget.controller.clear();
    await widget.onSendMessage(text);
  }

  void _onMediaSent(String mediaUrl, String type, String text) {
    widget.onSendMedia(mediaUrl, type, content: text);
    setState(() {
      _showMediaSender = false;
    });
    _focusNode.requestFocus();
    _animationController.reverse();
  }

  void _onEmojiPickerClose() {
    setState(() {
      _showEmojiPicker = false;
    });
    _focusNode.requestFocus();
    _animationController.reverse();
  }

  void _onMediaSenderClose() {
    setState(() {
      _showMediaSender = false;
    });
    _focusNode.requestFocus();
    _animationController.reverse();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final isWeb = kIsWeb;
    final screenWidth = MediaQuery.of(context).size.width;

    return Column(
      children: [
        // Media sender overlay
        if (_showMediaSender)
          AnimatedBuilder(
            animation: _animationController,
            builder: (context, child) {
              return Transform.translate(
                offset: Offset(0, (1 - _slideAnimation.value) * 300),
                child: Opacity(
                  opacity: _fadeAnimation.value,
                  child: Container(
                    height: 300,
                    decoration: BoxDecoration(
                      color: isDark ? Colors.grey[900] : Colors.white,
                      border: Border(
                        top: BorderSide(
                          color: isDark ? Colors.grey[700]! : Colors.grey[300]!,
                          width: 1,
                        ),
                      ),
                    ),
                    child: EnhancedMediaSender(
                      chatId: widget.chatId,
                      onMediaSent: _onMediaSent,
                      onClose: _onMediaSenderClose,
                    ),
                  ),
                ),
              );
            },
          ),

        // Emoji picker overlay
        if (_showEmojiPicker)
          AnimatedBuilder(
            animation: _animationController,
            builder: (context, child) {
              return Transform.translate(
                offset: Offset(0, (1 - _slideAnimation.value) * 300),
                child: Opacity(
                  opacity: _fadeAnimation.value,
                  child: Container(
                    height: 300,
                    decoration: BoxDecoration(
                      color: isDark ? Colors.grey[900] : Colors.white,
                      border: Border(
                        top: BorderSide(
                          color: isDark ? Colors.grey[700]! : Colors.grey[300]!,
                          width: 1,
                        ),
                      ),
                    ),
                    child: EmojiPicker(
                      onEmojiSelected: _onEmojiSelected,
                      onClose: _onEmojiPickerClose,
                    ),
                  ),
                ),
              );
            },
          ),

        // Main input area
        Container(
          decoration: BoxDecoration(
            color: isDark ? Colors.grey[900] : Colors.white,
            border: Border(
              top: BorderSide(
                color: isDark ? Colors.grey[700]! : Colors.grey[300]!,
                width: 1,
              ),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 8,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          child: SafeArea(
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: isWeb ? 24 : 16,
                vertical: 8,
              ),
              child: Row(
                children: [
                  // Emoji button
                  _buildActionButton(
                    icon: _showEmojiPicker ? Icons.keyboard : Icons.emoji_emotions_outlined,
                    isActive: _showEmojiPicker,
                    onPressed: _toggleEmojiPicker,
                    tooltip: _showEmojiPicker ? 'Hide emoji picker' : 'Show emoji picker',
                  ),

                  // Attachment button
                  _buildActionButton(
                    icon: _showMediaSender ? Icons.close : Icons.attach_file,
                    isActive: _showMediaSender,
                    onPressed: _toggleMediaSender,
                    tooltip: _showMediaSender ? 'Hide media picker' : 'Attach media',
                  ),

                  // Text input
                  Expanded(
                    child: Container(
                      constraints: BoxConstraints(
                        maxHeight: 120,
                      ),
                      decoration: BoxDecoration(
                        color: isDark ? Colors.grey[800] : Colors.grey[100],
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color: _focusNode.hasFocus
                              ? theme.primaryColor
                              : (isDark ? Colors.grey[600]! : Colors.grey[300]!),
                          width: _focusNode.hasFocus ? 2 : 1,
                        ),
                      ),
                      child: TextField(
                        controller: widget.controller,
                        focusNode: _focusNode,
                        enabled: widget.isEnabled,
                        maxLines: null,
                        textInputAction: TextInputAction.newline,
                        decoration: InputDecoration(
                          hintText: 'Type a message...',
                          hintStyle: TextStyle(
                            color: isDark ? Colors.grey[400] : Colors.grey[500],
                          ),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                        ),
                        style: TextStyle(
                          color: isDark ? Colors.white : Colors.black87,
                          fontSize: 16,
                        ),
                        onSubmitted: (value) {
                          if (value.trim().isNotEmpty) {
                            _sendMessage();
                          }
                        },
                      ),
                    ),
                  ),

                  const SizedBox(width: 8),

                  // Send button
                  _buildSendButton(theme, isDark),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required bool isActive,
    required VoidCallback onPressed,
    required String tooltip,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.only(right: 8),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: widget.isEnabled ? onPressed : null,
          borderRadius: BorderRadius.circular(20),
          child: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: isActive
                  ? theme.primaryColor.withOpacity(0.1)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Icon(
              icon,
              color: isActive
                  ? theme.primaryColor
                  : (isDark ? Colors.grey[400] : Colors.grey[600]),
              size: 20,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSendButton(ThemeData theme, bool isDark) {
    final hasText = widget.controller.text.trim().isNotEmpty;
    final canSend = widget.isEnabled && hasText;

    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: canSend ? theme.primaryColor : Colors.grey[400],
        borderRadius: BorderRadius.circular(20),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: canSend ? _sendMessage : null,
          borderRadius: BorderRadius.circular(20),
          child: Icon(
            Icons.send,
            color: Colors.white,
            size: 20,
          ),
        ),
      ),
    );
  }
}
