// =============================================================================
// GROUP CHAT NAMING UTILITY
// =============================================================================
// Utility functions to help debug and ensure proper group chat naming

import '../services/logger_service.dart';

class GroupChatNamingUtility {
  /// Get the display name for a chat with enhanced debugging
  static String getChatDisplayName(Map<String, dynamic> chat, {String? currentUserId}) {
    Log.i('Getting chat display name for chat: ${chat.toString()}', 'GROUP_CHAT_NAMING');
    
    // More robust group detection - check multiple possible fields
    final bool isGroup = chat['type'] == 'group' || 
                        (chat['isGroup'] == true) || 
                        (chat['isGroupChat'] == true) ||
                        (chat['members'] != null && (chat['members'] as List).length > 2);
    
    Log.i('Group detection result: $isGroup', 'GROUP_CHAT_NAMING');
    
    // For group chats, always return the group name
    if (isGroup) {
      final groupName = chat['name']?.toString() ?? '';
      Log.i('Group name from chat: "$groupName"', 'GROUP_CHAT_NAMING');
      
      if (groupName.isNotEmpty) {
        Log.i('Using group name: "$groupName"', 'GROUP_CHAT_NAMING');
        return groupName;
      }
      
      // Fallback: generate a group name from members if no name is set
      final members = List<String>.from(chat['members'] ?? []);
      Log.i('Group has ${members.length} members', 'GROUP_CHAT_NAMING');
      
      if (members.length > 2) {
        final fallbackName = 'Group Chat (${members.length} members)';
        Log.i('Using fallback group name: "$fallbackName"', 'GROUP_CHAT_NAMING');
        return fallbackName;
      }
      
      Log.i('Using default group name: "Group"', 'GROUP_CHAT_NAMING');
      return 'Group';
    }
    
    // For private chats, show the other user's name
    final List<String> members = List<String>.from(chat['members'] ?? []);
    Log.i('Private chat with ${members.length} members', 'GROUP_CHAT_NAMING');
    
    if (currentUserId == null || members.isEmpty) {
      final chatName = chat['name']?.toString() ?? 'Chat';
      Log.i('Using chat name (no current user): "$chatName"', 'GROUP_CHAT_NAMING');
      return chatName;
    }
    
    String? otherId;
    for (final id in members) {
      if (id.toString() != currentUserId) {
        otherId = id.toString();
        break;
      }
    }
    
    if (otherId == null) {
      final chatName = chat['name']?.toString() ?? 'Chat';
      Log.i('Using chat name (no other user found): "$chatName"', 'GROUP_CHAT_NAMING');
      return chatName;
    }
    
    Log.i('Found other user ID: $otherId', 'GROUP_CHAT_NAMING');
    // For now, return a placeholder - in real implementation, you'd fetch the user name
    final chatName = chat['name']?.toString() ?? 'Chat';
    Log.i('Using chat name (other user): "$chatName"', 'GROUP_CHAT_NAMING');
    return chatName;
  }

  /// Validate that a group chat has proper naming
  static bool validateGroupChatNaming(Map<String, dynamic> chat) {
    final bool isGroup = chat['type'] == 'group' || 
                        (chat['isGroup'] == true) || 
                        (chat['isGroupChat'] == true) ||
                        (chat['members'] != null && (chat['members'] as List).length > 2);
    
    if (!isGroup) {
      Log.w('Chat is not detected as group chat', 'GROUP_CHAT_NAMING');
      return false;
    }
    
    final groupName = chat['name']?.toString() ?? '';
    if (groupName.isEmpty) {
      Log.w('Group chat has empty name', 'GROUP_CHAT_NAMING');
      return false;
    }
    
    Log.i('Group chat naming validation passed: "$groupName"', 'GROUP_CHAT_NAMING');
    return true;
  }

  /// Debug group chat data structure
  static void debugGroupChatData(Map<String, dynamic> chat) {
    Log.i('=== GROUP CHAT DEBUG INFO ===', 'GROUP_CHAT_NAMING');
    Log.i('Chat ID: ${chat['_id'] ?? chat['id']}', 'GROUP_CHAT_NAMING');
    Log.i('Chat Name: "${chat['name']}"', 'GROUP_CHAT_NAMING');
    Log.i('Chat Type: "${chat['type']}"', 'GROUP_CHAT_NAMING');
    Log.i('Is Group: ${chat['isGroup']}', 'GROUP_CHAT_NAMING');
    Log.i('Is Group Chat: ${chat['isGroupChat']}', 'GROUP_CHAT_NAMING');
    Log.i('Members: ${chat['members']}', 'GROUP_CHAT_NAMING');
    Log.i('Members Count: ${(chat['members'] as List?)?.length ?? 0}', 'GROUP_CHAT_NAMING');
    Log.i('Created At: ${chat['createdAt']}', 'GROUP_CHAT_NAMING');
    Log.i('Updated At: ${chat['updatedAt']}', 'GROUP_CHAT_NAMING');
    Log.i('=============================', 'GROUP_CHAT_NAMING');
  }

  /// Get group chat display name with debugging
  static String getGroupChatDisplayNameWithDebug(Map<String, dynamic> chat) {
    debugGroupChatData(chat);
    return getChatDisplayName(chat);
  }
}
