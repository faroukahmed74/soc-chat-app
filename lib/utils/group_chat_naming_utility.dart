// =============================================================================
// GROUP CHAT NAMING UTILITY
// =============================================================================
// Utility functions to help debug and ensure proper group chat naming

import '../services/logger_service.dart';
import '../services/mongodb_chat_service.dart';
import '../config/database_config.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class GroupChatNamingUtility {
  // Cache for user names to avoid repeated API calls
  static final Map<String, String> _userNameCache = {};
  static final Set<String> _userNameFetching = {};
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
    
    // Check cache first
    if (_userNameCache.containsKey(otherId)) {
      final cachedName = _userNameCache[otherId]!;
      Log.i('Using cached user name: "$cachedName"', 'GROUP_CHAT_NAMING');
      return cachedName;
    }
    
    // If not in cache, fetch asynchronously and return placeholder for now
    _fetchUserNameAsync(otherId);
    
    // Return a placeholder while fetching
    final chatName = chat['name']?.toString() ?? 'Loading...';
    Log.i('Using placeholder name while fetching: "$chatName"', 'GROUP_CHAT_NAMING');
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

  /// Fetch user name asynchronously and cache it
  static Future<void> _fetchUserNameAsync(String userId) async {
    if (_userNameCache.containsKey(userId) || _userNameFetching.contains(userId)) {
      return;
    }
    
    _userNameFetching.add(userId);
    
    try {
      String? displayName;
      
      if (DatabaseConfig.usePhysicalServer) {
        // Use MongoDB service for physical server
        final chatService = MongoDBChatService();
        final user = await chatService.getUserDetails(userId);
        displayName = user?['name'] ?? user?['displayName'] ?? user?['email'];
      } else {
        // Use Firebase for cloud server
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(userId)
            .get();
        
        if (userDoc.exists) {
          final userData = userDoc.data() as Map<String, dynamic>;
          displayName = userData['displayName'] ?? userData['name'] ?? userData['email'];
        }
      }
      
      if (displayName != null && displayName.isNotEmpty) {
        _userNameCache[userId] = displayName;
        Log.i('Cached user name for $userId: "$displayName"', 'GROUP_CHAT_NAMING');
      } else {
        _userNameCache[userId] = 'Unknown User';
        Log.w('Could not fetch user name for $userId, using "Unknown User"', 'GROUP_CHAT_NAMING');
      }
    } catch (e) {
      Log.e('Error fetching user name for $userId', 'GROUP_CHAT_NAMING', e);
      _userNameCache[userId] = 'Unknown User';
    } finally {
      _userNameFetching.remove(userId);
    }
  }

  /// Get cached user name
  static String? getCachedUserName(String userId) {
    return _userNameCache[userId];
  }

  /// Preload user names for a list of user IDs
  static Future<void> preloadUserNames(List<String> userIds) async {
    final List<Future<void>> futures = [];
    
    for (final userId in userIds) {
      if (!_userNameCache.containsKey(userId) && !_userNameFetching.contains(userId)) {
        futures.add(_fetchUserNameAsync(userId));
      }
    }
    
    await Future.wait(futures);
  }

  /// Clear user name cache
  static void clearCache() {
    _userNameCache.clear();
    _userNameFetching.clear();
  }

  /// Get enhanced chat display name with proper user name fetching
  static Future<String> getChatDisplayNameAsync(Map<String, dynamic> chat, {String? currentUserId}) async {
    // More robust group detection - check multiple possible fields
    final bool isGroup = chat['type'] == 'group' || 
                        (chat['isGroup'] == true) || 
                        (chat['isGroupChat'] == true) ||
                        (chat['members'] != null && (chat['members'] as List).length > 2);
    
    // For group chats, always return the group name
    if (isGroup) {
      final groupName = chat['name']?.toString() ?? '';
      
      if (groupName.isNotEmpty) {
        return groupName;
      }
      
      // Fallback: generate a group name from members if no name is set
      final members = List<String>.from(chat['members'] ?? []);
      
      if (members.length > 2) {
        return 'Group Chat (${members.length} members)';
      }
      
      return 'Group';
    }
    
    // For private chats, show the other user's name
    final List<String> members = List<String>.from(chat['members'] ?? []);
    
    if (currentUserId == null || members.isEmpty) {
      return chat['name']?.toString() ?? 'Chat';
    }
    
    String? otherId;
    for (final id in members) {
      if (id.toString() != currentUserId) {
        otherId = id.toString();
        break;
      }
    }
    
    if (otherId == null) {
      return chat['name']?.toString() ?? 'Chat';
    }
    
    // Check cache first
    if (_userNameCache.containsKey(otherId)) {
      return _userNameCache[otherId]!;
    }
    
    // Fetch user name synchronously
    await _fetchUserNameAsync(otherId);
    
    return _userNameCache[otherId] ?? 'Unknown User';
  }
}
