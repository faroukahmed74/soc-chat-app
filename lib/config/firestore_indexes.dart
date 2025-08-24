class FirestoreIndexes {
  // Collection: chats
  static const Map<String, String> chatIndexes = {
    'members_lastMessageTime': 'https://console.firebase.google.com/v1/r/project/soc-chat-app-ca57e/firestore/indexes?create_composite=ClNwcm9qZWN0cy9zb2MtY2hhdC1hcHAtY2E1N2UvZGF0YWJhc2VzLyhkZWZhdWx0KS9jb2xsZWN0aW9uR3JvdXBzL2NoYXRzL2luZGV4ZXNfXwACGggKBm1lbWJlcnMQARoNCg1sYXN0TWVzc2FnZVRpbWUQARoMCghfX25hbWVfXxAB',
    'type_timestamp': 'https://console.firebase.google.com/v1/r/project/soc-chat-app-ca57e/firestore/indexes?create_composite=ClNwcm9qZWN0cy9zb2MtY2hhdC1hcHAtY2E1N2UvZGF0YWJhc2VzLyhkZWZhdWx0KS9jb2xsZWN0aW9uR3JvdXBzL2NoYXRzL2luZGV4ZXNfXwACGggKBHR5cGUQARoNCgl0aW1lc3RhbXAQARoMCghfX25hbWVfXxAB',
  };

  // Collection: messages
  static const Map<String, String> messageIndexes = {
    'chatId_timestamp': 'https://console.firebase.google.com/v1/r/project/soc-chat-app-ca57e/firestore/indexes?create_composite=ClNwcm9qZWN0cy9zb2MtY2hhdC1hcHAtY2E1N2UvZGF0YWJhc2VzLyhkZWZhdWx0KS9jb2xsZWN0aW9uR3JvdXBzL21lc3NhZ2VzL2luZGV4ZXNfXwACGggKB2NoYXRJZBAAGg0KCXRpbWVzdGFtcBABGgwKCF9fbmFtZV9fEAE',
    'collection_group_timestamp': 'https://console.firebase.google.com/v1/r/project/soc-chat-app-ca57e/firestore/indexes?create_exemption=Clpwcm9qZWN0cy9zb2MtY2hhdC1hcHAtY2E1N2UvZGF0YWJhc2VzLyhkZWZhdWx0KS9jb2xsZWN0aW9uR3JvdXBzL21lc3NhZ2VzL2ZpZWxkcy90aW1lc3RhbXAQAhoNCgl0aW1lc3RhbXAQARoMCghfX25hbWVfXxAB',
  };

  // Collection: scheduled_messages
  static const Map<String, String> scheduledMessageIndexes = {
    'userId_scheduledTime': 'https://console.firebase.google.com/v1/r/project/soc-chat-app-ca57e/firestore/indexes?create_composite=ClNwcm9qZWN0cy9zb2MtY2hhdC1hcHAtY2E1N2UvZGF0YWJhc2VzLyhkZWZhdWx0KS9jb2xsZWN0aW9uR3JvdXBzL3NjaGVkdWxlZF9tZXNzYWdlcy9pbmRleGVzX18aAhoMCgd1c2VySWQQARoNCgtzY2hlZHVsZWRUaW1lEAEaDAoIX19uYW1lX18QAQ',
    'status_scheduledTime': 'https://console.firebase.google.com/v1/r/project/soc-chat-app-ca57e/firestore/indexes?create_composite=ClNwcm9qZWN0cy9zb2MtY2hhdC1hcHAtY2E1N2UvZGF0YWJhc2VzLyhkZWZhdWx0KS9jb2xsZWN0aW9uR3JvdXBzL3NjaGVkdWxlZF9tZXNzYWdlcy9pbmRleGVzX18aAhoMCgZzdGF0dXMQARoNCgtzY2hlZHVsZWRUaW1lEAEaDAoIX19uYW1lX18QAQ',
  };

  // Collection: users
  static const Map<String, String> userIndexes = {
    'role_status': 'https://console.firebase.google.com/v1/r/project/soc-chat-app-ca57e/firestore/indexes?create_composite=ClNwcm9qZWN0cy9zb2MtY2hhdC1hcHAtY2E1N2UvZGF0YWJhc2VzLyhkZWZhdWx0KS9jb2xsZWN0aW9uR3JvdXBzL3VzZXJzL2luZGV4ZXNfXwACGggKBHJvbGUQARoMCgZzdGF0dXMQARoMCghfX25hbWVfXxAB',
    'lastSeen_status': 'https://console.firebase.google.com/v1/r/project/soc-chat-app-ca57e/firestore/indexes?create_composite=ClNwcm9qZWN0cy9zb2MtY2hhdC1hcHAtY2E1N2UvZGF0YWJhc2VzLyhkZWZhdWx0KS9jb2xsZWN0aW9uR3JvdXBzL3VzZXJzL2luZGV4ZXNfXwACGggKCWxhc3RTZWVuEAEaDAoGc3RhdHVzEAEaDAoIX19uYW1lX18QAQ',
  };

  // Collection: admin_actions
  static const Map<String, String> adminActionIndexes = {
    'actionType_timestamp': 'https://console.firebase.google.com/v1/r/project/soc-chat-app-ca57e/firestore/indexes?create_composite=ClNwcm9qZWN0cy9zb2MtY2hhdC1hcHAtY2E1N2UvZGF0YWJhc2VzLyhkZWZhdWx0KS9jb2xsZWN0aW9uR3JvdXBzL2FkbWluX2FjdGlvbnMvaW5kZXhlc19fGgIaDAoKYWN0aW9uVHlwZRABGg0KCXRpbWVzdGFtcBABGgwKCF9fbmFtZV9fEAE',
    'adminId_timestamp': 'https://console.firebase.google.com/v1/r/project/soc-chat-app-ca57e/firestore/indexes?create_composite=ClNwcm9qZWN0cy9zb2MtY2hhdC1hcHAtY2E1N2UvZGF0YWJhc2VzLyhkZWZhdWx0KS9jb2xsZWN0aW9uR3JvdXBzL2FkbWluX2FjdGlvbnMvaW5kZXhlc19fGgIaDAoHYWRtaW5JZBAAGg0KCXRpbWVzdGFtcBABGgwKCF9fbmFtZV9fEAE',
  };

  // Get all required indexes
  static Map<String, Map<String, String>> getAllIndexes() {
    return {
      'chats': chatIndexes,
      'messages': messageIndexes,
      'scheduled_messages': scheduledMessageIndexes,
      'users': userIndexes,
      'admin_actions': adminActionIndexes,
    };
  }

  // Get index creation instructions
  static String getIndexInstructions() {
    return '''
📋 FIRESTORE INDEX CREATION INSTRUCTIONS:

To fix "failed-precondition" errors, you need to create the following indexes in Firebase Console:

1. Go to: https://console.firebase.google.com/v1/r/project/soc-chat-app-ca57e/firestore/indexes

2. Create the following indexes:

CHATS COLLECTION:
- members (Array) + lastMessageTime (Descending)
- type + timestamp (Descending)

MESSAGES COLLECTION:
- chatId + timestamp (Descending)
- Collection Group: messages + timestamp (Ascending)

SCHEDULED MESSAGES COLLECTION:
- userId + scheduledTime (Ascending)
- status + scheduledTime (Ascending)

USERS COLLECTION:
- role + status
- lastSeen + status

ADMIN ACTIONS COLLECTION:
- actionType + timestamp (Descending)
- adminId + timestamp (Descending)

3. Wait for indexes to build (usually 1-5 minutes)
4. Restart your app

Note: These indexes are required for optimal query performance and to avoid "failed-precondition" errors.
''';
  }
}
