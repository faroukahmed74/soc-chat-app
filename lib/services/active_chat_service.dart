import 'package:flutter/foundation.dart';

class ActiveChatService extends ChangeNotifier {
  static final ActiveChatService instance = ActiveChatService._internal();
  ActiveChatService._internal();

  String? _activeChatId;

  String? get activeChatId => _activeChatId;

  bool isActive(String chatId) => _activeChatId == chatId;

  void setActiveChat(String chatId) {
    if (_activeChatId == chatId) return;
    _activeChatId = chatId;
    notifyListeners();
  }

  void clearActiveChat(String chatId) {
    if (_activeChatId == chatId) {
      _activeChatId = null;
      notifyListeners();
    }
  }
}


