import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'logger_service.dart';

class AdminGroupService {
  static final AdminGroupService _instance = AdminGroupService._internal();
  factory AdminGroupService() => _instance;
  AdminGroupService._internal();

  // Check if current user is an admin
  Future<bool> isCurrentUserAdmin() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return false;

      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (!userDoc.exists) return false;

      final userData = userDoc.data() as Map<String, dynamic>;
      return userData['role'] == 'admin';
    } catch (e) {
      Log.e('Error checking admin status', 'ADMIN_GROUP', e);
      return false;
    }
  }

  // Get current user's role
  Future<String> getCurrentUserRole() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return 'user';

      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (!userDoc.exists) return 'user';

      final userData = userDoc.data() as Map<String, dynamic>;
      return userData['role'] ?? 'user';
    } catch (e) {
      Log.e('Error getting current user role', 'ADMIN_GROUP', e);
      return 'user';
    }
  }

  // Check if user is admin of a specific group
  Future<bool> isUserGroupAdmin(String groupId, String userId) async {
    try {
      final groupDoc = await FirebaseFirestore.instance
          .collection('chats')
          .doc(groupId)
          .get();

      if (!groupDoc.exists) return false;

      final groupData = groupDoc.data() as Map<String, dynamic>;
      return groupData['adminId'] == userId;
    } catch (e) {
      Log.e('Error checking group admin status', 'ADMIN_GROUP', e);
      return false;
    }
  }

  // Lock a user account
  Future<bool> lockUserAccount(String userId, String reason) async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) return false;

      await FirebaseFirestore.instance.collection('users').doc(userId).update({
        'disabled': true,
        'lockReason': reason,
        'lockedAt': FieldValue.serverTimestamp(),
        'lockedBy': currentUser.email ?? currentUser.uid,
      });
      return true;
    } catch (e) {
      Log.e('Error locking user account', 'ADMIN_GROUP', e);
      return false;
    }
  }

  // Unlock a user account
  Future<bool> unlockUserAccount(String userId) async {
    try {
      await FirebaseFirestore.instance.collection('users').doc(userId).update({
        'disabled': false,
        'lockReason': null,
        'lockedAt': null,
        'lockedBy': null,
      });
      return true;
    } catch (e) {
      Log.e('Error unlocking user account', 'ADMIN_GROUP', e);
      return false;
    }
  }

  // Check if a user account is locked
  Future<bool> isUserAccountLocked(String userId) async {
    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .get();

      if (!userDoc.exists) return false;

      final userData = userDoc.data() as Map<String, dynamic>;
      return userData['disabled'] == true;
    } catch (e) {
      Log.e('Error checking if user account is locked', 'ADMIN_GROUP', e);
      return false;
    }
  }

  // Get account lock information
  Future<Map<String, dynamic>?> getAccountLockInfo(String userId) async {
    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .get();

      if (!userDoc.exists) return null;

      final userData = userDoc.data() as Map<String, dynamic>;
      if (userData['disabled'] != true) return null;

      return {
        'lockReason': userData['lockReason'] ?? 'No reason provided',
        'lockedAt': userData['lockedAt'],
        'lockedBy': userData['lockedBy'] ?? 'Unknown',
      };
    } catch (e) {
      Log.e('Error getting account lock info', 'ADMIN_GROUP', e);
      return null;
    }
  }

  // Delete a group (admin only)
  Future<bool> deleteGroup(String groupId) async {
    try {
      // Check if current user is admin
      if (!await isCurrentUserAdmin()) {
        Log.w('User is not admin, cannot delete group', 'ADMIN_GROUP');
        return false;
      }

      Log.i('Deleting group: $groupId', 'ADMIN_GROUP');

      // Get group data first
      final groupDoc = await FirebaseFirestore.instance
          .collection('chats')
          .doc(groupId)
          .get();

      if (!groupDoc.exists) {
        Log.w('Group does not exist', 'ADMIN_GROUP');
        return false;
      }

      final groupData = groupDoc.data() as Map<String, dynamic>;
      final isGroup = groupData['isGroup'] ?? false;

      if (!isGroup) {
        Log.w('Cannot delete individual chat', 'ADMIN_GROUP');
        return false;
      }

      // Delete all messages in the group
      final messagesQuery = await FirebaseFirestore.instance
          .collection('chats')
          .doc(groupId)
          .collection('messages')
          .get();

      final batch = FirebaseFirestore.instance.batch();
      
      // Delete all messages
      for (final doc in messagesQuery.docs) {
        batch.delete(doc.reference);
      }

      // Delete the group document
      batch.delete(groupDoc.reference);

      // Commit the batch
      await batch.commit();

      // Delete group media from Firebase Storage
      try {
        final storageRef = FirebaseStorage.instance.ref().child('chat_media/$groupId');
        await storageRef.delete();
        Log.i('Group media deleted from storage', 'ADMIN_GROUP');
      } catch (e) {
        Log.e('Error deleting group media', 'ADMIN_GROUP', e);
        // Continue even if storage deletion fails
      }

      Log.i('Group deleted successfully', 'ADMIN_GROUP');
      return true;
    } catch (e) {
      Log.e('Error deleting group', 'ADMIN_GROUP', e);
      return false;
    }
  }

  // Remove member from group (admin only)
  Future<bool> removeMemberFromGroup(String groupId, String memberId) async {
    try {
      // Check if current user is admin
      if (!await isCurrentUserAdmin()) {
        Log.w('User is not admin, cannot remove members', 'ADMIN_GROUP');
        return false;
      }

      Log.i('AdminGroupService: Removing member $memberId from group $groupId', 'ADMIN_GROUP');

      // Get group data
      final groupDoc = await FirebaseFirestore.instance
          .collection('chats')
          .doc(groupId)
          .get();

      if (!groupDoc.exists) {
        Log.w('Group does not exist', 'ADMIN_GROUP');
        return false;
      }

      final groupData = groupDoc.data() as Map<String, dynamic>;
      final isGroup = groupData['isGroup'] ?? false;
      final members = List<String>.from(groupData['members'] ?? []);
      final adminId = groupData['adminId'] ?? '';

      if (!isGroup) {
        Log.w('Cannot remove members from individual chat', 'ADMIN_GROUP');
        return false;
      }

      // Check if trying to remove admin
      if (memberId == adminId) {
        Log.w('Cannot remove admin from group', 'ADMIN_GROUP');
        return false;
      }

      // Check if member exists in group
      if (!members.contains(memberId)) {
        Log.w('Member not in group', 'ADMIN_GROUP');
        return false;
      }

      // Remove member from group
      members.remove(memberId);

      // Update group document
      await FirebaseFirestore.instance
          .collection('chats')
          .doc(groupId)
          .update({
        'members': members,
        'lastMessage': '👤 Member removed by admin',
        'lastMessageTime': FieldValue.serverTimestamp(),
      });

      // Add system message about member removal
      await FirebaseFirestore.instance
          .collection('chats')
          .doc(groupId)
          .collection('messages')
          .add({
        'senderId': 'system',
        'text': '👤 Member removed by admin',
        'mediaUrl': '',
        'mediaType': 'text',
        'fileName': '',
        'duration': 0,
        'timestamp': FieldValue.serverTimestamp(),
        'encrypted': false,
        'readBy': [],
        'status': 'sent',
        'reactions': {},
        'replyTo': null,
        'forwarded': false,
        'edited': false,
        'expiresAt': Timestamp.fromDate(DateTime.now().add(const Duration(days: 30))),
      });

      Log.i('Member removed successfully', 'ADMIN_GROUP');
      return true;
    } catch (e) {
      Log.e('Error removing member', 'ADMIN_GROUP', e);
      return false;
    }
  }

  // Get all groups for admin management
  Future<List<Map<String, dynamic>>> getAllGroups() async {
    try {
      if (!await isCurrentUserAdmin()) {
        Log.w('User is not admin, cannot access all groups', 'ADMIN_GROUP');
        return [];
      }

      final groupsQuery = await FirebaseFirestore.instance
          .collection('chats')
          .where('isGroup', isEqualTo: true)
          .get();

      final groups = <Map<String, dynamic>>[];
      
      for (final doc in groupsQuery.docs) {
        final data = doc.data();
        data['id'] = doc.id;
        groups.add(data);
      }

      return groups;
    } catch (e) {
      Log.e('Error getting all groups', 'ADMIN_GROUP', e);
      return [];
    }
  }

  // Get group members with user details
  Future<List<Map<String, dynamic>>> getGroupMembers(String groupId) async {
    try {
      if (!await isCurrentUserAdmin()) {
        Log.w('User is not admin, cannot access group members', 'ADMIN_GROUP');
        return [];
      }

      final groupDoc = await FirebaseFirestore.instance
          .collection('chats')
          .doc(groupId)
          .get();

      if (!groupDoc.exists) return [];

      final groupData = groupDoc.data() as Map<String, dynamic>;
      final members = List<String>.from(groupData['members'] ?? []);
      final adminId = groupData['adminId'] ?? '';

      if (members.isEmpty) return [];

      // Get user details for all members
      final usersQuery = await FirebaseFirestore.instance
          .collection('users')
          .where(FieldPath.documentId, whereIn: members)
          .get();

      final membersList = <Map<String, dynamic>>[];
      
      for (final doc in usersQuery.docs) {
        final userData = doc.data();
        userData['id'] = doc.id;
        userData['isAdmin'] = doc.id == adminId;
        membersList.add(userData);
      }

      return membersList;
    } catch (e) {
      Log.e('Error getting group members', 'ADMIN_GROUP', e);
      return [];
    }
  }

  // Transfer group admin to another member
  Future<bool> transferGroupAdmin(String groupId, String newAdminId) async {
    try {
      if (!await isCurrentUserAdmin()) {
        Log.w('User is not admin, cannot transfer admin', 'ADMIN_GROUP');
        return false;
      }

      Log.i('Transferring admin to $newAdminId in group $groupId', 'ADMIN_GROUP');

      // Get group data
      final groupDoc = await FirebaseFirestore.instance
          .collection('chats')
          .doc(groupId)
          .get();

      if (!groupDoc.exists) {
        Log.w('Group does not exist', 'ADMIN_GROUP');
        return false;
      }

      final groupData = groupDoc.data() as Map<String, dynamic>;
      final members = List<String>.from(groupData['members'] ?? []);

      // Check if new admin is a member
      if (!members.contains(newAdminId)) {
        Log.w('New admin is not a member of the group', 'ADMIN_GROUP');
        return false;
      }

      // Update group admin
      await FirebaseFirestore.instance
          .collection('chats')
          .doc(groupId)
          .update({
        'adminId': newAdminId,
        'lastMessage': '👑 Admin transferred',
        'lastMessageTime': FieldValue.serverTimestamp(),
      });

      // Add system message about admin transfer
      await FirebaseFirestore.instance
          .collection('chats')
          .doc(groupId)
          .collection('messages')
          .add({
        'senderId': 'system',
        'text': '👑 Admin transferred',
        'mediaUrl': '',
        'mediaType': 'text',
        'fileName': '',
        'duration': 0,
        'timestamp': FieldValue.serverTimestamp(),
        'encrypted': false,
        'readBy': [],
        'status': 'sent',
        'reactions': {},
        'replyTo': null,
        'forwarded': false,
        'edited': false,
        'expiresAt': Timestamp.fromDate(DateTime.now().add(const Duration(days: 30))),
      });

      Log.i('Admin transferred successfully', 'ADMIN_GROUP');
      return true;
    } catch (e) {
      Log.e('Error transferring admin', 'ADMIN_GROUP', e);
      return false;
    }
  }

  // Enhanced Analytics Methods
  static Future<Map<String, dynamic>> getUserAnalytics() async {
    try {
      final usersSnapshot = await FirebaseFirestore.instance.collection('users').get();
      final chatsSnapshot = await FirebaseFirestore.instance.collection('chats').get();
      
      // User statistics
      final totalUsers = usersSnapshot.docs.length;
      final activeUsers = usersSnapshot.docs.where((doc) => doc.data()['isOnline'] == true).length;
      final lockedUsers = usersSnapshot.docs.where((doc) => doc.data()['disabled'] == true).length;
      final adminUsers = usersSnapshot.docs.where((doc) => doc.data()['role'] == 'admin').length;
      
      // Chat statistics
      final totalChats = chatsSnapshot.docs.length;
      final groupChats = chatsSnapshot.docs.where((doc) => doc.data()['type'] == 'group').length;
      final privateChats = totalChats - groupChats;
      
      // Message statistics
      int totalMessages = 0;
      int totalMediaMessages = 0;
      for (final chatDoc in chatsSnapshot.docs) {
        final messagesSnapshot = await FirebaseFirestore.instance
            .collection('chats')
            .doc(chatDoc.id)
            .collection('messages')
            .get();
        
        totalMessages += messagesSnapshot.docs.length;
        totalMediaMessages += messagesSnapshot.docs.where((msg) {
          final data = msg.data();
          return data['type'] == 'image' || data['type'] == 'video' || data['type'] == 'audio' || data['type'] == 'file';
        }).length;
      }
      
      // User activity analysis
      final now = DateTime.now();
      final thirtyDaysAgo = now.subtract(const Duration(days: 30));
      final sevenDaysAgo = now.subtract(const Duration(days: 7));
      
      int activeLast30Days = 0;
      int activeLast7Days = 0;
      int newUsersLast30Days = 0;
      int newUsersLast7Days = 0;
      
      for (final userDoc in usersSnapshot.docs) {
        final data = userDoc.data();
        final lastSeen = data['lastSeen'] as Timestamp?;
        final createdAt = data['createdAt'] as Timestamp?;
        
        if (lastSeen != null) {
          final lastSeenDate = lastSeen.toDate();
          if (lastSeenDate.isAfter(thirtyDaysAgo)) activeLast30Days++;
          if (lastSeenDate.isAfter(sevenDaysAgo)) activeLast7Days++;
        }
        
        if (createdAt != null) {
          final createdDate = createdAt.toDate();
          if (createdDate.isAfter(thirtyDaysAgo)) newUsersLast30Days++;
          if (createdDate.isAfter(sevenDaysAgo)) newUsersLast7Days++;
        }
      }
      
      return {
        'users': {
          'total': totalUsers,
          'active': activeUsers,
          'locked': lockedUsers,
          'admins': adminUsers,
          'activeLast30Days': activeLast30Days,
          'activeLast7Days': activeLast7Days,
          'newLast30Days': newUsersLast30Days,
          'newLast7Days': newUsersLast7Days,
        },
        'chats': {
          'total': totalChats,
          'groups': groupChats,
          'private': privateChats,
        },
        'messages': {
          'total': totalMessages,
          'media': totalMediaMessages,
          'text': totalMessages - totalMediaMessages,
        },
        'generatedAt': FieldValue.serverTimestamp(),
      };
    } catch (e) {
      Log.e('Error getting user analytics', 'ADMIN_GROUP', e);
      return {};
    }
  }

  // Content Moderation Methods
  static Future<bool> flagMessage(String messageId, String chatId, String reason, String reportedBy) async {
    try {
      await FirebaseFirestore.instance.collection('flagged_messages').add({
        'messageId': messageId,
        'chatId': chatId,
        'reason': reason,
        'reportedBy': reportedBy,
        'status': 'pending',
        'flaggedAt': FieldValue.serverTimestamp(),
        'reviewedBy': null,
        'reviewedAt': null,
        'action': null,
      });
      return true;
    } catch (e) {
      Log.e('Error flagging message', 'ADMIN_GROUP', e);
      return false;
    }
  }

  static Future<bool> reviewFlaggedMessage(String flagId, String action, String reviewedBy) async {
    try {
      await FirebaseFirestore.instance.collection('flagged_messages').doc(flagId).update({
        'status': 'reviewed',
        'action': action,
        'reviewedBy': reviewedBy,
        'reviewedAt': FieldValue.serverTimestamp(),
      });
      return true;
    } catch (e) {
      Log.e('Error reviewing flagged message', 'ADMIN_GROUP', e);
      return false;
    }
  }

  static Future<List<Map<String, dynamic>>> getFlaggedMessages() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('flagged_messages')
          .orderBy('flaggedAt', descending: true)
          .get();
      
      return snapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          ...data,
        };
      }).toList();
    } catch (e) {
      Log.e('Error getting flagged messages', 'ADMIN_GROUP', e);
      return [];
    }
  }

  // System Monitoring Methods
  static Future<Map<String, dynamic>> getSystemHealth() async {
    try {
      final now = DateTime.now();
      final healthChecks = <String, dynamic>{};
      
      // Database connectivity check
      try {
        await FirebaseFirestore.instance.collection('health_check').doc('ping').get();
        healthChecks['database'] = {
          'status': 'connected',
          'latency': 'low',
          'lastCheck': now,
        };
      } catch (e) {
        healthChecks['database'] = {
          'status': 'disconnected',
          'error': e.toString(),
          'lastCheck': now,
        };
      }
      
      // User activity check
      try {
        final activeUsersSnapshot = await FirebaseFirestore.instance
            .collection('users')
            .where('isOnline', isEqualTo: true)
            .get();
        healthChecks['userActivity'] = {
          'status': 'active',
          'activeUsers': activeUsersSnapshot.docs.length,
          'lastCheck': now,
        };
      } catch (e) {
        healthChecks['userActivity'] = {
          'status': 'error',
          'error': e.toString(),
          'lastCheck': now,
        };
      }
      
      // Storage check (approximate)
      try {
        final chatsSnapshot = await FirebaseFirestore.instance.collection('chats').get();
        int totalMessages = 0;
        for (final chatDoc in chatsSnapshot.docs) {
          final messagesSnapshot = await FirebaseFirestore.instance
              .collection('chats')
              .doc(chatDoc.id)
              .collection('messages')
              .get();
          totalMessages += messagesSnapshot.docs.length;
        }
        
        healthChecks['storage'] = {
          'status': 'available',
          'totalChats': chatsSnapshot.docs.length,
          'totalMessages': totalMessages,
          'lastCheck': now,
        };
      } catch (e) {
        healthChecks['storage'] = {
          'status': 'error',
          'error': e.toString(),
          'lastCheck': now,
        };
      }
      
      // Authentication check
      try {
        final currentUser = FirebaseAuth.instance.currentUser;
        healthChecks['authentication'] = {
          'status': currentUser != null ? 'active' : 'inactive',
          'currentUser': currentUser?.email ?? 'none',
          'lastCheck': now,
        };
      } catch (e) {
        healthChecks['authentication'] = {
          'status': 'error',
          'error': e.toString(),
          'lastCheck': now,
        };
      }
      
      return healthChecks;
    } catch (e) {
      Log.e('Error getting system health', 'ADMIN_GROUP', e);
      return {};
    }
  }

  // Backup and Export Methods
  static Future<Map<String, dynamic>> exportUserData() async {
    try {
      final usersSnapshot = await FirebaseFirestore.instance.collection('users').get();
      final userData = usersSnapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'userId': doc.id,
          'username': data['username'] ?? '',
          'email': data['email'] ?? '',
          'role': data['role'] ?? 'user',
          'createdAt': data['createdAt']?.toDate().toString() ?? '',
          'lastSeen': data['lastSeen']?.toDate().toString() ?? '',
          'isOnline': data['isOnline'] ?? false,
          'disabled': data['disabled'] ?? false,
          'lockReason': data['lockReason'] ?? '',
          'settings': data['settings'] ?? {},
        };
      }).toList();
      
      return {
        'exportType': 'user_data',
        'exportedAt': DateTime.now().toIso8601String(),
        'totalRecords': userData.length,
        'data': userData,
      };
    } catch (e) {
      Log.e('Error exporting user data', 'ADMIN_GROUP', e);
      return {};
    }
  }

  static Future<Map<String, dynamic>> exportChatData() async {
    try {
      final chatsSnapshot = await FirebaseFirestore.instance.collection('chats').get();
      final chatDataList = <Map<String, dynamic>>[];
      
      for (final chatDoc in chatsSnapshot.docs) {
        final chatDocData = chatDoc.data();
        final messagesSnapshot = await FirebaseFirestore.instance
            .collection('chats')
            .doc(chatDoc.id)
            .collection('messages')
            .orderBy('timestamp', descending: true)
            .limit(100) // Limit to last 100 messages per chat
            .get();
        
        final messages = messagesSnapshot.docs.map((msg) {
          final msgData = msg.data();
          return {
            'messageId': msg.id,
            'text': msgData['text'] ?? '',
            'type': msgData['type'] ?? 'text',
            'senderId': msgData['senderId'] ?? '',
            'timestamp': msgData['timestamp']?.toDate().toString() ?? '',
          };
        }).toList();
        
        chatDataList.add({
          'chatId': chatDoc.id,
          'type': chatDocData['type'] ?? 'private',
          'members': chatDocData['members'] ?? [],
          'createdAt': chatDocData['createdAt']?.toDate().toString() ?? '',
          'lastMessage': chatDocData['lastMessage'] ?? '',
          'messageCount': messages.length,
          'messages': messages,
        });
      }
      
      return {
        'exportType': 'chat_data',
        'exportedAt': DateTime.now().toIso8601String(),
        'totalChats': chatDataList.length,
        'data': chatDataList,
      };
    } catch (e) {
      Log.e('Error exporting chat data', 'ADMIN_GROUP', e);
      return {};
    }
  }

  // Data Cleanup Methods
  static Future<int> cleanupOldNotifications(int daysOld) async {
    try {
      final cutoffDate = DateTime.now().subtract(Duration(days: daysOld));
      int cleanedCount = 0;
      
      final usersSnapshot = await FirebaseFirestore.instance.collection('users').get();
      for (final userDoc in usersSnapshot.docs) {
        final notificationsSnapshot = await FirebaseFirestore.instance
            .collection('users')
            .doc(userDoc.id)
            .collection('notifications')
            .where('timestamp', isLessThan: Timestamp.fromDate(cutoffDate))
            .get();
        
        for (final notification in notificationsSnapshot.docs) {
          await notification.reference.delete();
          cleanedCount++;
        }
      }
      
      return cleanedCount;
    } catch (e) {
      Log.e('Error cleaning up old notifications', 'ADMIN_GROUP', e);
      return 0;
    }
  }

  static Future<int> cleanupOldMessages(int daysOld) async {
    try {
      final cutoffDate = DateTime.now().subtract(Duration(days: daysOld));
      int cleanedCount = 0;
      
      final chatsSnapshot = await FirebaseFirestore.instance.collection('chats').get();
      for (final chatDoc in chatsSnapshot.docs) {
        final messagesSnapshot = await FirebaseFirestore.instance
            .collection('chats')
            .doc(chatDoc.id)
            .collection('messages')
            .where('timestamp', isLessThan: Timestamp.fromDate(cutoffDate))
            .get();
        
        for (final message in messagesSnapshot.docs) {
          await message.reference.delete();
          cleanedCount++;
        }
      }
      
      return cleanedCount;
    } catch (e) {
      Log.e('Error cleaning up old messages', 'ADMIN_GROUP', e);
      return 0;
    }
  }

  // Make a user an admin of a specific group
  Future<bool> makeUserAdmin(String groupId, String userId) async {
    try {
      // Check if current user is admin
      if (!await isCurrentUserAdmin()) {
        Log.w('Only admins can make other users admin', 'ADMIN_GROUP');
        return false;
      }

      // Update the group document to set the new admin
      await FirebaseFirestore.instance
          .collection('chats')
          .doc(groupId)
          .update({
        'adminId': userId,
        'adminUpdatedAt': FieldValue.serverTimestamp(),
        'adminUpdatedBy': FirebaseAuth.instance.currentUser?.uid,
      });

      // Log the admin action
      await logAdminAction('make_user_admin', userId, 'Made user admin of group: $groupId');
      
      return true;
    } catch (e) {
      Log.e('Error making user admin', 'ADMIN_GROUP', e);
      return false;
    }
  }

  // Get all users with their roles
  Future<List<Map<String, dynamic>>> getAllUsers() async {
    try {
      if (!await isCurrentUserAdmin()) {
        Log.w('Only admins can view all users', 'ADMIN_GROUP');
        return [];
      }
      
      final usersSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .get();
      
      return usersSnapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          'email': data['email'] ?? 'No email',
          'displayName': data['displayName'] ?? 'No name',
          'role': data['role'] ?? 'user',
        };
      }).toList();
    } catch (e) {
      Log.e('Error getting all users', 'ADMIN_GROUP', e);
      return [];
    }
  }

  // Make a user admin by email
  Future<bool> makeUserAdminByEmail(String email, String role) async {
    try {
      if (!await isCurrentUserAdmin()) {
        Log.w('Only admins can make other users admin', 'ADMIN_GROUP');
        return false;
      }
      
      // Find user by email
      final userQuery = await FirebaseFirestore.instance
          .collection('users')
          .where('email', isEqualTo: email)
          .get();
      
      if (userQuery.docs.isEmpty) {
        Log.w('User not found with email: $email', 'ADMIN_GROUP');
        return false;
      }
      
      final userId = userQuery.docs.first.id;
      
      // Update user role
      await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .update({'role': role});
      
      await logAdminAction('make_user_admin_by_email', userId, 'Made user admin by email: $email');
      return true;
    } catch (e) {
      Log.e('Error making user admin by email', 'ADMIN_GROUP', e);
      return false;
    }
  }

  // =============================================================================
  // ENHANCED GROUP MANAGEMENT METHODS
  // =============================================================================

  /// Add a member to a group (admin only)
  Future<bool> addMemberToGroup(String groupId, String userId) async {
    try {
      if (!await isCurrentUserAdmin()) {
        Log.w('Only admins can add members to groups', 'ADMIN_GROUP');
        return false;
      }

      Log.i('AdminGroupService: Adding member $userId to group $groupId', 'ADMIN_GROUP');

      // Get group data
      final groupDoc = await FirebaseFirestore.instance
          .collection('chats')
          .doc(groupId)
          .get();

      if (!groupDoc.exists) {
        Log.w('Group does not exist', 'ADMIN_GROUP');
        return false;
      }

      final groupData = groupDoc.data() as Map<String, dynamic>;
      final isGroup = groupData['isGroup'] ?? false;

      if (!isGroup) {
        Log.w('Cannot add members to individual chat', 'ADMIN_GROUP');
        return false;
      }

      // Check if user is already a member
      final members = List<String>.from(groupData['members'] ?? []);
      if (members.contains(userId)) {
        Log.w('User is already a member of this group', 'ADMIN_GROUP');
        return false;
      }

      // Add member to group
      members.add(userId);

      // Update group document
      await FirebaseFirestore.instance
          .collection('chats')
          .doc(groupId)
          .update({
        'members': members,
        'lastMessage': '👤 Member added by admin',
        'lastMessageTime': FieldValue.serverTimestamp(),
      });

      // Add system message about member addition
      await FirebaseFirestore.instance
          .collection('chats')
          .doc(groupId)
          .collection('messages')
          .add({
        'senderId': 'system',
        'text': '👤 Member added by admin',
        'mediaUrl': '',
        'mediaType': 'text',
        'fileName': '',
        'duration': 0,
        'timestamp': FieldValue.serverTimestamp(),
        'encrypted': false,
        'readBy': [],
        'status': 'sent',
        'reactions': {},
        'replyTo': null,
        'forwarded': false,
        'edited': false,
        'expiresAt': Timestamp.fromDate(DateTime.now().add(const Duration(days: 30))),
      });

      Log.i('Member added successfully', 'ADMIN_GROUP');
      return true;
    } catch (e) {
      Log.e('Error adding member', 'ADMIN_GROUP', e);
      return false;
    }
  }

  /// Get group analytics and statistics
  Future<Map<String, dynamic>> getGroupAnalytics(String groupId) async {
    try {
      if (!await isCurrentUserAdmin()) {
        Log.w('Only admins can access group analytics', 'ADMIN_GROUP');
        return {};
      }

      // Get group data
      final groupDoc = await FirebaseFirestore.instance
          .collection('chats')
          .doc(groupId)
          .get();

      if (!groupDoc.exists) return {};

      final groupData = groupDoc.data() as Map<String, dynamic>;
      final members = List<String>.from(groupData['members'] ?? []);
      final createdAt = groupData['createdAt'] as Timestamp?;

      // Get message statistics
      final messagesSnapshot = await FirebaseFirestore.instance
          .collection('chats')
          .doc(groupId)
          .collection('messages')
          .get();

      final totalMessages = messagesSnapshot.docs.length;
      final messageTypes = <String, int>{};
      final userMessageCounts = <String, int>{};
      final dailyActivity = <String, int>{};

      for (final doc in messagesSnapshot.docs) {
        final data = doc.data();
        final type = data['type'] ?? 'text';
        final senderId = data['senderId'] ?? '';
        final timestamp = data['timestamp'] as Timestamp?;

        // Count message types
        messageTypes[type] = (messageTypes[type] ?? 0) + 1;

        // Count messages per user
        if (senderId != 'system') {
          userMessageCounts[senderId] = (userMessageCounts[senderId] ?? 0) + 1;
        }

        // Count daily activity
        if (timestamp != null) {
          final date = timestamp.toDate().toIso8601String().split('T')[0];
          dailyActivity[date] = (dailyActivity[date] ?? 0) + 1;
        }
      }

      // Get user details for top contributors
      final topContributors = <Map<String, dynamic>>[];
      final sortedUsers = userMessageCounts.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));

      for (int i = 0; i < sortedUsers.length && i < 5; i++) {
        final entry = sortedUsers[i];
        try {
          final userDoc = await FirebaseFirestore.instance
              .collection('users')
              .doc(entry.key)
              .get();
          
          if (userDoc.exists) {
            final userData = userDoc.data() as Map<String, dynamic>;
            topContributors.add({
              'userId': entry.key,
              'displayName': userData['displayName'] ?? 'Unknown User',
              'messageCount': entry.value,
            });
          }
        } catch (e) {
          Log.e('Error getting user data for ${entry.key}', 'ADMIN_GROUP', e);
        }
      }

      // Calculate activity metrics
      final now = DateTime.now();
      final weekAgo = now.subtract(const Duration(days: 7));
      final monthAgo = now.subtract(const Duration(days: 30));

      int messagesThisWeek = 0;
      int messagesThisMonth = 0;

      for (final doc in messagesSnapshot.docs) {
        final timestamp = doc.data()['timestamp'] as Timestamp?;
        if (timestamp != null) {
          final messageDate = timestamp.toDate();
          if (messageDate.isAfter(weekAgo)) messagesThisWeek++;
          if (messageDate.isAfter(monthAgo)) messagesThisMonth++;
        }
      }

      return {
        'groupId': groupId,
        'groupName': groupData['name'] ?? 'Unnamed Group',
        'totalMembers': members.length,
        'totalMessages': totalMessages,
        'messageTypes': messageTypes,
        'topContributors': topContributors,
        'dailyActivity': dailyActivity,
        'messagesThisWeek': messagesThisWeek,
        'messagesThisMonth': messagesThisMonth,
        'createdAt': createdAt?.toDate().toIso8601String(),
        'averageMessagesPerDay': totalMessages > 0 && createdAt != null
            ? (totalMessages / now.difference(createdAt.toDate()).inDays).toStringAsFixed(1)
            : '0',
        'mostActiveDay': dailyActivity.isNotEmpty
            ? dailyActivity.entries.reduce((a, b) => a.value > b.value ? a : b).key
            : 'No activity',
      };
    } catch (e) {
      Log.e('Error getting group analytics', 'ADMIN_GROUP', e);
      return {};
    }
  }

  /// Get comprehensive group information
  Future<Map<String, dynamic>?> getGroupInfo(String groupId) async {
    try {
      if (!await isCurrentUserAdmin()) {
        Log.w('Only admins can access group info', 'ADMIN_GROUP');
        return null;
      }

      // Get group data
      final groupDoc = await FirebaseFirestore.instance
          .collection('chats')
          .doc(groupId)
          .get();

      if (!groupDoc.exists) return null;

      final groupData = groupDoc.data() as Map<String, dynamic>;
      final members = List<String>.from(groupData['members'] ?? []);

      // Get member details
      final memberDetails = <Map<String, dynamic>>[];
      for (final memberId in members) {
        try {
          final userDoc = await FirebaseFirestore.instance
              .collection('users')
              .doc(memberId)
              .get();
          
          if (userDoc.exists) {
            final userData = userDoc.data() as Map<String, dynamic>;
            memberDetails.add({
              'userId': memberId,
              'displayName': userData['displayName'] ?? 'Unknown User',
              'email': userData['email'] ?? 'No email',
              'isOnline': userData['isOnline'] ?? false,
              'lastSeen': userData['lastSeen'],
              'isAdmin': memberId == groupData['adminId'],
            });
          }
        } catch (e) {
          Log.e('Error getting member data for $memberId', 'ADMIN_GROUP', e);
        }
      }

      // Get recent messages count
      final recentMessagesSnapshot = await FirebaseFirestore.instance
          .collection('chats')
          .doc(groupId)
          .collection('messages')
          .where('timestamp', isGreaterThan: Timestamp.fromDate(DateTime.now().subtract(const Duration(days: 7))))
          .get();

      return {
        'groupId': groupId,
        'name': groupData['name'] ?? 'Unnamed Group',
        'description': groupData['description'] ?? 'No description',
        'adminId': groupData['adminId'] ?? '',
        'members': memberDetails,
        'totalMembers': members.length,
        'createdAt': groupData['createdAt'],
        'lastMessageTime': groupData['lastMessageTime'],
        'lastMessage': groupData['lastMessage'] ?? 'No messages yet',
        'messagesThisWeek': recentMessagesSnapshot.docs.length,
        'isGroup': groupData['isGroup'] ?? false,
        'settings': groupData['settings'] ?? {},
      };
    } catch (e) {
      Log.e('Error getting group info', 'ADMIN_GROUP', e);
      return null;
    }
  }

  /// Update group settings
  Future<bool> updateGroupSettings(String groupId, Map<String, dynamic> settings) async {
    try {
      if (!await isCurrentUserAdmin()) {
        Log.w('Only admins can update group settings', 'ADMIN_GROUP');
        return false;
      }

      await FirebaseFirestore.instance
          .collection('chats')
          .doc(groupId)
          .update({
        ...settings,
        'updatedAt': FieldValue.serverTimestamp(),
        'updatedBy': FirebaseAuth.instance.currentUser?.uid,
      });

      await logAdminAction('update_group_settings', groupId, 'Updated group settings: ${settings.keys.join(', ')}');
      return true;
    } catch (e) {
      Log.e('Error updating group settings', 'ADMIN_GROUP', e);
      return false;
    }
  }

  /// Archive a group (make it read-only)
  Future<bool> archiveGroup(String groupId) async {
    try {
      if (!await isCurrentUserAdmin()) {
        Log.w('Only admins can archive groups', 'ADMIN_GROUP');
        return false;
      }

      await FirebaseFirestore.instance
          .collection('chats')
          .doc(groupId)
          .update({
        'archived': true,
        'archivedAt': FieldValue.serverTimestamp(),
        'archivedBy': FirebaseAuth.instance.currentUser?.uid,
      });

      await logAdminAction('archive_group', groupId, 'Group archived');
      return true;
    } catch (e) {
      Log.e('Error archiving group', 'ADMIN_GROUP', e);
      return false;
    }
  }

  /// Unarchive a group
  Future<bool> unarchiveGroup(String groupId) async {
    try {
      if (!await isCurrentUserAdmin()) {
        Log.w('Only admins can unarchive groups', 'ADMIN_GROUP');
        return false;
      }

      await FirebaseFirestore.instance
          .collection('chats')
          .doc(groupId)
          .update({
        'archived': false,
        'archivedAt': null,
        'archivedBy': null,
      });

      await logAdminAction('unarchive_group', groupId, 'Group unarchived');
      return true;
    } catch (e) {
      Log.e('Error unarchiving group', 'ADMIN_GROUP', e);
      return false;
    }
  }

  /// Get all archived groups
  Future<List<Map<String, dynamic>>> getArchivedGroups() async {
    try {
      if (!await isCurrentUserAdmin()) {
        Log.w('Only admins can access archived groups', 'ADMIN_GROUP');
        return [];
      }

      final archivedGroupsQuery = await FirebaseFirestore.instance
          .collection('chats')
          .where('isGroup', isEqualTo: true)
          .where('archived', isEqualTo: true)
          .get();

      return archivedGroupsQuery.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return data;
      }).toList();
    } catch (e) {
      Log.e('Error getting archived groups', 'ADMIN_GROUP', e);
      return [];
    }
  }

  /// Get group activity timeline
  Future<List<Map<String, dynamic>>> getGroupActivityTimeline(String groupId, {int limit = 50}) async {
    try {
      if (!await isCurrentUserAdmin()) {
        Log.w('Only admins can access group activity', 'ADMIN_GROUP');
        return [];
      }

      final messagesSnapshot = await FirebaseFirestore.instance
          .collection('chats')
          .doc(groupId)
          .collection('messages')
          .orderBy('timestamp', descending: true)
          .limit(limit)
          .get();

      final activities = <Map<String, dynamic>>[];
      
      for (final doc in messagesSnapshot.docs) {
        final data = doc.data();
        final timestamp = data['timestamp'] as Timestamp?;
        
        if (timestamp != null) {
          activities.add({
            'messageId': doc.id,
            'type': data['type'] ?? 'text',
            'text': data['text'] ?? '',
            'senderId': data['senderId'] ?? '',
            'timestamp': timestamp,
            'mediaUrl': data['mediaUrl'] ?? '',
            'fileName': data['fileName'] ?? '',
          });
        }
      }

      return activities;
    } catch (e) {
      Log.e('Error getting group activity', 'ADMIN_GROUP', e);
      return [];
    }
  }

  /// Get groups by activity level
  Future<Map<String, List<Map<String, dynamic>>>> getGroupsByActivity() async {
    try {
      if (!await isCurrentUserAdmin()) {
        Log.w('Only admins can access group activity analysis', 'ADMIN_GROUP');
        return {};
      }

      final groupsSnapshot = await FirebaseFirestore.instance
          .collection('chats')
          .where('isGroup', isEqualTo: true)
          .get();

      final now = DateTime.now();
      final weekAgo = now.subtract(const Duration(days: 7));
      final monthAgo = now.subtract(const Duration(days: 30));

      final activeGroups = <Map<String, dynamic>>[];
      final inactiveGroups = <Map<String, dynamic>>[];
      final newGroups = <Map<String, dynamic>>[];

      for (final doc in groupsSnapshot.docs) {
        final data = doc.data();
        final lastMessageTime = data['lastMessageTime'] as Timestamp?;
        final createdAt = data['createdAt'] as Timestamp?;
        
        final groupInfo = {
          'id': doc.id,
          'name': data['name'] ?? 'Unnamed Group',
          'members': data['members'] ?? [],
          'lastMessageTime': lastMessageTime,
          'createdAt': createdAt,
        };

        if (lastMessageTime != null) {
          final lastActivity = lastMessageTime.toDate();
          if (lastActivity.isAfter(weekAgo)) {
            activeGroups.add(groupInfo);
          } else if (lastActivity.isBefore(monthAgo)) {
            inactiveGroups.add(groupInfo);
          }
        }

        if (createdAt != null && createdAt.toDate().isAfter(monthAgo)) {
          newGroups.add(groupInfo);
        }
      }

      return {
        'active': activeGroups,
        'inactive': inactiveGroups,
        'new': newGroups,
      };
    } catch (e) {
      Log.e('Error getting groups by activity', 'ADMIN_GROUP', e);
      return {};
    }
  }

  // Audit Logging
  static Future<bool> logAdminAction(String action, String targetId, String details) async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) return false;
      
      await FirebaseFirestore.instance.collection('admin_logs').add({
        'action': action,
        'targetId': targetId,
        'details': details,
        'adminId': currentUser.uid,
        'adminEmail': currentUser.email ?? 'unknown',
        'timestamp': FieldValue.serverTimestamp(),
        'ipAddress': 'unknown', // Could be enhanced with actual IP tracking
      });
      return true;
    } catch (e) {
      Log.e('Error logging admin action', 'ADMIN_GROUP', e);
      return false;
    }
  }

  static Future<List<Map<String, dynamic>>> getAdminLogs({int limit = 100}) async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('admin_logs')
          .orderBy('timestamp', descending: true)
          .limit(limit)
          .get();
      
      return snapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          ...data,
        };
      }).toList();
    } catch (e) {
      Log.e('Error getting admin logs', 'ADMIN_GROUP', e);
      return [];
    }
  }
}

