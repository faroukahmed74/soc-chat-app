// lib/screens/chat_screen_web.dart
// Web-specific chat screen implementation

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'chat_screen_mongodb.dart';

class ChatScreenWeb extends StatelessWidget {
  final String chatId;
  final String chatName;
  final bool isGroupChat;
  final String? groupKey;

  const ChatScreenWeb({
    Key? key,
    required this.chatId,
    required this.chatName,
    this.isGroupChat = false,
    this.groupKey,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (kIsWeb) {
      return ChatScreenMongoDB(
        chatId: chatId,
        chatName: chatName,
        isGroupChat: isGroupChat,
        groupKey: groupKey,
      );
    } else {
      return const Scaffold(
        body: Center(
          child: Text('Web chat screen not available on this platform'),
        ),
      );
    }
  }
}
