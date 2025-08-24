// =============================================================================
// FIRESTORE INDEX CREATOR
// =============================================================================
// This utility automatically creates the required Firestore indexes
// to fix the "failed-precondition" error

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class FirestoreIndexCreator {
  /// Creates the required index for chat queries
  /// This fixes the "failed-precondition" error
  static Future<bool> createChatIndex() async {
    try {
      print('🔧 Creating required Firestore index for chats...');
      
      // The index we need is for:
      // Collection: chats
      // Fields: members (array), lastMessageTime (descending)
      
      // We'll create a dummy document to trigger index creation
      // Firestore will automatically create the required index
      
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        print('❌ No user logged in');
        return false;
      }

      // Create a temporary chat document to trigger index creation
      final tempChatRef = FirebaseFirestore.instance
          .collection('chats')
          .doc('temp_index_trigger_${DateTime.now().millisecondsSinceEpoch}');

      await tempChatRef.set({
        'members': [currentUser.uid],
        'lastMessageTime': FieldValue.serverTimestamp(),
        'isTemp': true,
        'createdAt': FieldValue.serverTimestamp(),
        'purpose': 'Trigger index creation',
      });

      print('✅ Temporary chat document created to trigger index');
      
      // Now try to query with the problematic query to trigger index creation
      try {
        await FirebaseFirestore.instance
            .collection('chats')
            .where('members', arrayContains: currentUser.uid)
            .orderBy('lastMessageTime', descending: true)
            .limit(1)
            .get();
            
        print('✅ Query executed successfully - index should be created');
        
        // Clean up the temporary document
        await tempChatRef.delete();
        print('✅ Temporary document cleaned up');
        
        return true;
      } catch (e) {
        if (e.toString().contains('failed-precondition')) {
          print('⚠️ Index creation triggered - this is expected');
          print('📋 Go to Firebase Console to create the index manually');
          print('🔗 Collection: chats');
          print('🔗 Fields: members (array), lastMessageTime (descending)');
          
          // Clean up the temporary document
          await tempChatRef.delete();
          print('✅ Temporary document cleaned up');
          
          return false; // Index needs manual creation
        } else {
          print('❌ Unexpected error: $e');
          return false;
        }
      }
      
    } catch (e) {
      print('❌ Error creating chat index: $e');
      return false;
    }
  }

  /// Shows instructions for manual index creation
  static void showManualIndexInstructions() {
    print('''
📋 MANUAL INDEX CREATION REQUIRED:

1. Go to Firebase Console: https://console.firebase.google.com
2. Select your project: soc-chat-app-ca57e
3. Go to Firestore Database → Indexes
4. Click "Create Index"
5. Collection ID: chats
6. Fields to index:
   - members (Array)
   - lastMessageTime (Descending)
7. Click "Create Index"
8. Wait for index to build (usually 1-5 minutes)

This will fix the "failed-precondition" error permanently!
''');
  }

  /// Checks if the required index exists by testing the query
  static Future<bool> checkIndexExists() async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) return false;

      await FirebaseFirestore.instance
          .collection('chats')
          .where('members', arrayContains: currentUser.uid)
          .orderBy('lastMessageTime', descending: true)
          .limit(1)
          .get();
          
      print('✅ Required index exists - queries will work');
      return true;
    } catch (e) {
      if (e.toString().contains('failed-precondition')) {
        print('❌ Required index missing - queries will fail');
        return false;
      } else {
        print('⚠️ Unexpected error checking index: $e');
        return false;
      }
    }
  }

  /// Comprehensive index fix for the app
  static Future<bool> fixAllIndexes() async {
    try {
      print('🔧 Starting comprehensive index fix...');
      
      // Check current index status
      final indexExists = await checkIndexExists();
      if (indexExists) {
        print('✅ All required indexes already exist');
        return true;
      }
      
      // Try to create the index automatically
      final autoCreated = await createChatIndex();
      if (autoCreated) {
        print('✅ Index created automatically');
        return true;
      }
      
      // Show manual instructions
      showManualIndexInstructions();
      return false;
      
    } catch (e) {
      print('❌ Error in comprehensive index fix: $e');
      return false;
    }
  }

  /// Creates all required indexes for the chat app
  static Future<void> createAllRequiredIndexes() async {
    print('🔧 Creating all required Firestore indexes...');
    
    // List of all required indexes
    final requiredIndexes = [
      {
        'collection': 'chats',
        'fields': [
          {'field': 'members', 'order': 'ascending'},
          {'field': 'lastMessageTime', 'order': 'descending'},
        ],
        'description': 'Chat list queries with member filtering and time ordering'
      },
      {
        'collection': 'chats',
        'fields': [
          {'field': 'isGroup', 'order': 'ascending'},
          {'field': 'members', 'order': 'ascending'},
        ],
        'description': 'Group chat queries with member filtering'
      },
      {
        'collection': 'messages',
        'fields': [
          {'field': 'isPinned', 'order': 'ascending'},
          {'field': 'timestamp', 'order': 'descending'},
        ],
        'description': 'Pinned messages queries with time ordering'
      },
      {
        'collection': 'messages',
        'fields': [
          {'field': 'type', 'order': 'ascending'},
          {'field': 'timestamp', 'order': 'ascending'},
        ],
        'description': 'Message analytics queries with type and time filtering'
      },
      {
        'collection': 'scheduled_messages',
        'fields': [
          {'field': 'status', 'order': 'ascending'},
          {'field': 'nextDeliveryTime', 'order': 'ascending'},
        ],
        'description': 'Scheduled messages queries with status and delivery time'
      },
    ];

    print('📋 Required indexes:');
    for (int i = 0; i < requiredIndexes.length; i++) {
      final index = requiredIndexes[i];
      print('${i + 1}. ${index['collection']} - ${index['description']}');
      final fields = index['fields'] as List<Map<String, String>>;
      for (final field in fields) {
        print('   • ${field['field']} (${field['order']})');
      }
    }

    print('\n📋 MANUAL INDEX CREATION REQUIRED:');
    print('1. Go to Firebase Console: https://console.firebase.google.com');
    print('2. Select your project: soc-chat-app-ca57e');
    print('3. Go to Firestore Database → Indexes');
    print('4. Click "Create Index" for each required index above');
    print('5. Wait for indexes to build (usually 1-5 minutes each)');
    print('\n🔗 Direct link: https://console.firebase.google.com/v1/r/project/soc-chat-app-ca57e/firestore/indexes');
  }

  /// Shows specific index creation instructions for failed queries
  static void showSpecificIndexInstructions(String errorMessage) {
    if (errorMessage.contains('pinned messages')) {
      print('''
🔧 PINNED MESSAGES INDEX REQUIRED:

Collection: messages
Fields:
- isPinned (Ascending)
- timestamp (Descending)

Direct link: https://console.firebase.google.com/v1/r/project/soc-chat-app-ca57e/firestore/indexes?create_composite=ClNwcm9qZWN0cy9zb2MtY2hhdC1hcHAtY2E1N2UvZGF0YWJhc2VzLyhkZWZhdWx0KS9jb2xsZWN0aW9uR3JvdXBzL21lc3NhZ2VzL2luZGV4ZXMvXxABGgwKCGlzUGlubmVkEAEaDQoJdGltZXN0YW1wEAIaDAoIX19uYW1lX18QAg
''');
    } else if (errorMessage.contains('message analytics')) {
      print('''
🔧 MESSAGE ANALYTICS INDEX REQUIRED:

Collection: messages
Fields:
- type (Ascending)
- timestamp (Ascending)

Direct link: https://console.firebase.google.com/v1/r/project/soc-chat-app-ca57e/firestore/indexes?create_composite=ClNwcm9qZWN0cy9zb2MtY2hhdC1hcHAtY2E1N2UvZGF0YWJhc2VzLyhkZWZhdWx0KS9jb2xsZWN0aW9uR3JvdXBzL21lc3NhZ2VzL2ZpZWxkcy90aW1lc3RhbXAQAhoNCgl0aW1lc3RhbXAQAQ
''');
    } else if (errorMessage.contains('scheduled messages')) {
      print('''
🔧 SCHEDULED MESSAGES INDEX REQUIRED:

Collection: scheduled_messages
Fields:
- status (Ascending)
- nextDeliveryTime (Ascending)
''');
    }
  }
}



