import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'dart:typed_data';
import 'dart:async';
import '../widgets/emoji_picker.dart';
import '../widgets/enhanced_media_sender.dart';
import '../utils/responsive_utils.dart';
import '../services/enhanced_voice_service.dart';
import '../services/web_voice_service.dart';

/// Intent class for sending messages via keyboard shortcut
class _SendMessageIntent extends Intent {
  const _SendMessageIntent();
}

/// Enhanced chat input widget with emoji picker and media attachment
class EnhancedChatInput extends StatefulWidget {
  final TextEditingController controller;
  final Future<void> Function(String) onSendMessage;
  final Future<void> Function(String, String, {String? content}) onSendMedia;
  final Future<void> Function(
    Uint8List bytes,
    String type,
    String fileName,
    String mimeType,
    String caption,
  )? onQueueOfflineMedia;
  final Future<void> Function(Map<String, dynamic> contactData)? onSendContact;
  final String chatId;
  final bool isEnabled;
  
  // Media selection state
  final Uint8List? selectedMediaBytes;
  final String? selectedMediaType;
  final String? selectedMediaFileName;
  final VoidCallback? onClearMedia;
  final Future<void> Function(Uint8List, String, String)? onSendVoice;

  const EnhancedChatInput({
    super.key,
    required this.controller,
    required this.onSendMessage,
    required this.onSendMedia,
    this.onQueueOfflineMedia,
    this.onSendContact,
    required this.chatId,
    this.isEnabled = true,
    this.selectedMediaBytes,
    this.selectedMediaType,
    this.selectedMediaFileName,
    this.onClearMedia,
    this.onSendVoice,
  });

  @override
  State<EnhancedChatInput> createState() => _EnhancedChatInputState();
}

class _EnhancedChatInputState extends State<EnhancedChatInput> {
  bool _showEmojiPicker = false;
  bool _showMediaSender = false;
  final FocusNode _focusNode = FocusNode();
  
  // Voice recording state
  bool _isRecordingVoice = false;
  Timer? _recordingTimer;
  Duration _recordingDuration = Duration.zero;

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
    _recordingTimer?.cancel();
    if (_isRecordingVoice) {
      _cancelVoiceRecording();
    }
    super.dispose();
  }
  
  Future<void> _startVoiceRecording() async {
    try {
      if (kIsWeb) {
        final started = await WebVoiceService.startRecording();
        if (!started) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Failed to start recording. Please check microphone permissions.')),
            );
          }
          return;
        }
      } else {
        final started = await EnhancedVoiceService.startRecording(context);
        if (!started) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Failed to start recording. Please check microphone permissions.')),
            );
          }
          return;
        }
      }

      setState(() {
        _isRecordingVoice = true;
        _recordingDuration = Duration.zero;
      });

      _recordingTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (mounted) {
          setState(() {
            if (kIsWeb) {
              final duration = WebVoiceService.currentRecordingDuration;
              if (duration != null) {
                _recordingDuration = duration;
              }
            } else {
              final duration = EnhancedVoiceService.currentRecordingDuration;
              if (duration != null) {
                _recordingDuration = duration;
              }
            }
          });
        }
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error starting recording: $e')),
        );
      }
    }
  }

  Future<void> _stopVoiceRecording() async {
    try {
      print('[ENHANCED_CHAT_INPUT] Stopping voice recording...');
      _recordingTimer?.cancel();
      _recordingTimer = null;

      VoiceRecordingResult? result;
      if (kIsWeb) {
        print('[ENHANCED_CHAT_INPUT] Stopping web recording...');
        result = await WebVoiceService.stopRecording();
      } else {
        print('[ENHANCED_CHAT_INPUT] Stopping mobile recording...');
        result = await EnhancedVoiceService.stopRecording();
      }

      print('[ENHANCED_CHAT_INPUT] Recording result: ${result != null ? "not null" : "null"}');
      if (result != null) {
        print('[ENHANCED_CHAT_INPUT] Recording bytes: ${result.bytes.length}, mimeType: ${result.mimeType}, duration: ${result.duration}');
      }

      setState(() {
        _isRecordingVoice = false;
        _recordingDuration = Duration.zero;
      });

      if (result == null) {
        print('[ENHANCED_CHAT_INPUT] Recording result is null');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Recording failed: No audio data captured')),
          );
        }
        return;
      }

      if (result.bytes.isEmpty) {
        print('[ENHANCED_CHAT_INPUT] Recording bytes are empty');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Recording failed: Audio file is empty')),
          );
        }
        return;
      }

      if (widget.onSendVoice == null) {
        print('[ENHANCED_CHAT_INPUT] onSendVoice callback is null!');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Error: Voice message handler not configured')),
          );
        }
        return;
      }

      print('[ENHANCED_CHAT_INPUT] Calling onSendVoice callback...');
      await widget.onSendVoice!(result.bytes, result.mimeType, '🎤 Voice Message');
      print('[ENHANCED_CHAT_INPUT] Voice message sent successfully');
    } catch (e, stackTrace) {
      print('[ENHANCED_CHAT_INPUT] Error in _stopVoiceRecording: $e');
      print('[ENHANCED_CHAT_INPUT] Stack trace: $stackTrace');
      setState(() {
        _isRecordingVoice = false;
        _recordingDuration = Duration.zero;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error stopping recording: $e')),
        );
      }
    }
  }

  Future<void> _cancelVoiceRecording() async {
    try {
      _recordingTimer?.cancel();
      _recordingTimer = null;

      if (kIsWeb) {
        await WebVoiceService.cancelRecording();
      } else {
        await EnhancedVoiceService.cancelRecording();
      }

      setState(() {
        _isRecordingVoice = false;
        _recordingDuration = Duration.zero;
      });
    } catch (e) {
      setState(() {
        _isRecordingVoice = false;
        _recordingDuration = Duration.zero;
      });
    }
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$minutes:$seconds';
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
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.6,
              minHeight: 200,
            ),
            child: EnhancedMediaSender(
              chatId: widget.chatId,
              onQueueOfflineMedia: widget.onQueueOfflineMedia,
              onMediaSent: (mediaUrl, type, text) {
                widget.onSendMedia(mediaUrl, type, content: text);
                setState(() {
                  _showMediaSender = false;
                });
                _focusNode.requestFocus();
              },
              onContactSent: widget.onSendContact != null ? (contactData) {
                widget.onSendContact!(contactData);
                setState(() {
                  _showMediaSender = false;
                });
                _focusNode.requestFocus();
              } : null,
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

        // Voice recording UI overlay
        if (_isRecordingVoice)
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.2),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
              border: Border.all(
                color: Colors.red.withOpacity(0.3),
                width: 2,
              ),
            ),
            child: Row(
              children: [
                // Recording indicator
                Container(
                  width: 12,
                  height: 12,
                  decoration: const BoxDecoration(
                    color: Colors.red,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 12),
                // Duration
                Text(
                  _formatDuration(_recordingDuration),
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                const Spacer(),
                // Cancel button
                IconButton(
                  onPressed: _cancelVoiceRecording,
                  icon: const Icon(Icons.close),
                  color: Colors.grey,
                  tooltip: 'Cancel',
                ),
                const SizedBox(width: 8),
                // Send button
                Container(
                  decoration: BoxDecoration(
                    color: theme.primaryColor,
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    onPressed: _stopVoiceRecording,
                    icon: const Icon(Icons.send),
                    color: Colors.white,
                    tooltip: 'Send',
                  ),
                ),
              ],
            ),
          ),

        // Media preview
        if (widget.selectedMediaBytes != null) ...[
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: isDark 
                    ? [Colors.grey[800]!, Colors.grey[700]!]
                    : [Colors.white, Colors.grey[50]!],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: theme.primaryColor.withValues(alpha: 0.3),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                // Media thumbnail
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.1),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: widget.selectedMediaType == 'image'
                        ? Image.memory(
                            widget.selectedMediaBytes!,
                            width: 60,
                            height: 60,
                            fit: BoxFit.cover,
                          )
                        : Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: widget.selectedMediaType == 'video'
                                    ? [Colors.red.shade400, Colors.red.shade600]
                                    : [Colors.blue.shade400, Colors.blue.shade600],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                            ),
                            child: Icon(
                              widget.selectedMediaType == 'video'
                                  ? Icons.play_circle_filled
                                  : Icons.insert_drive_file,
                              color: Colors.white,
                              size: 30,
                            ),
                          ),
                  ),
                ),
                const SizedBox(width: 16),
                
                // Media info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.selectedMediaFileName ?? 'Media',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: theme.primaryColor.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              widget.selectedMediaType?.toUpperCase() ?? 'FILE',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: theme.primaryColor,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '${(widget.selectedMediaBytes!.length / 1024).toStringAsFixed(1)} KB',
                            style: TextStyle(
                              fontSize: 12,
                              color: isDark ? Colors.grey[400] : Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                
                // Remove button
                Container(
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: IconButton(
                    onPressed: widget.onClearMedia,
                    icon: const Icon(Icons.close),
                    iconSize: 20,
                    color: Colors.red,
                    tooltip: 'Remove media',
                  ),
                ),
              ],
            ),
          ),
        ],

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

                // Microphone button
                if (widget.onSendVoice != null)
                  Container(
                    decoration: BoxDecoration(
                      color: _isRecordingVoice 
                          ? Colors.red.withOpacity(0.2)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: IconButton(
                      onPressed: _isRecordingVoice ? _stopVoiceRecording : _startVoiceRecording,
                      icon: Icon(
                        _isRecordingVoice ? Icons.stop : Icons.mic,
                        color: _isRecordingVoice 
                            ? Colors.red 
                            : (isDark ? Colors.grey[400] : Colors.grey[600]),
                      ),
                      tooltip: _isRecordingVoice ? 'Stop Recording' : 'Record Voice Message',
                    ),
                  ),

                // Text input
                Expanded(
                  child: Container(
                    constraints: BoxConstraints(
                      maxHeight: kIsWeb ? 150 : double.infinity,
                    ),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.grey[800] : Colors.grey[100],
                      borderRadius: BorderRadius.circular(25),
                    ),
                    child: kIsWeb ? Shortcuts(
                      shortcuts: {
                        const SingleActivator(LogicalKeyboardKey.enter): _SendMessageIntent(),
                      },
                      child: Actions(
                        actions: {
                          _SendMessageIntent: CallbackAction<_SendMessageIntent>(
                            onInvoke: (_) {
                              if (widget.controller.text.trim().isNotEmpty && widget.isEnabled) {
                                _sendMessage();
                              }
                              return null;
                            },
                          ),
                        },
                        child: Focus(
                          onKeyEvent: (FocusNode node, KeyEvent event) {
                            // Allow Shift+Enter to create new lines
                            if (event is KeyDownEvent && 
                                event.logicalKey == LogicalKeyboardKey.enter &&
                                HardwareKeyboard.instance.isShiftPressed) {
                              return KeyEventResult.ignored; // Let TextField handle it
                            }
                            return KeyEventResult.ignored;
                          },
                          child: TextField(
                      controller: widget.controller,
                      focusNode: _focusNode,
                      enabled: widget.isEnabled,
                      maxLines: null, // Allow multiple lines on all platforms
                      minLines: 1, // Start with single line, grow as needed
                      textCapitalization: TextCapitalization.sentences,
                      textInputAction: kIsWeb ? TextInputAction.newline : TextInputAction.send,
                      keyboardType: TextInputType.multiline,
                      decoration: InputDecoration(
                        hintText: kIsWeb 
                            ? 'Type a message... (Enter to send, Shift+Enter for new line)'
                            : 'Type a message...',
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        hintStyle: TextStyle(
                          color: isDark ? Colors.grey[500] : Colors.grey[600],
                          fontSize: kIsWeb ? 14 : 16,
                        ),
                      ),
                      style: TextStyle(
                        color: isDark ? Colors.white : Colors.black87,
                        fontSize: 16,
                        fontFamily: kIsWeb ? ResponsiveUtils.getEmojiFontFamily() : null,
                        fontFeatures: kIsWeb ? [const FontFeature.enable('liga')] : null,
                      ),
                      onSubmitted: (value) {
                        // On mobile, Enter sends the message
                        if (!kIsWeb && value.trim().isNotEmpty && widget.isEnabled) {
                          _sendMessage();
                        }
                      },
                      onChanged: (_) {
                        // Update send button state and trigger rebuild for dynamic height
                        setState(() {});
                      },
                          ),
                        ),
                      ),
                    ) : TextField(
                      controller: widget.controller,
                      focusNode: _focusNode,
                      enabled: widget.isEnabled,
                      maxLines: null,
                      minLines: 1,
                      textCapitalization: TextCapitalization.sentences,
                      textInputAction: TextInputAction.send,
                      keyboardType: TextInputType.multiline,
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
                      onSubmitted: (value) {
                        if (value.trim().isNotEmpty && widget.isEnabled) {
                          _sendMessage();
                        }
                      },
                      onChanged: (_) {
                        setState(() {});
                      },
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
