// =============================================================================
// ROLE FIX TEST SCRIPT
// =============================================================================
// This is a simple test script to fix your user role issue immediately
// You can run this from your app to add the missing role field

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class RoleFixTest {
  /// Immediately fixes the current user's missing role field
  static Future<void> fixCurrentUserRole() async {
    try {
      print('🔧 Starting role fix for current user...');
      
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        print('❌ No user logged in');
        return;
      }

      print('👤 Current user: ${currentUser.email} (${currentUser.uid})');

      // Check current user document
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.uid)
          .get();

      if (!userDoc.exists) {
        print('❌ User document not found');
        return;
      }

      final userData = userDoc.data() as Map<String, dynamic>;
      print('📄 Current user data: ${userData.keys.toList()}');
      
      // Check if user already has a role field
      if (userData.containsKey('role')) {
        print('✅ User already has role: ${userData['role']}');
        return;
      }

      print('⚠️ User missing role field - adding it now...');

      // Add role field
      await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.uid)
          .update({
        'role': 'admin', // Set as admin since you're the developer
        'roleUpdatedAt': FieldValue.serverTimestamp(),
        'roleUpdateReason': 'Added missing role field via test script',
      });

      print('✅ User role updated successfully to: admin');
      print('🎉 Your account now has admin privileges!');
      
    } catch (e) {
      print('❌ Error fixing user role: $e');
    }
  }

  /// Shows current user's role status
  static Future<void> showCurrentUserStatus() async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        print('❌ No user logged in');
        return;
      }

      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.uid)
          .get();

      if (!userDoc.exists) {
        print('❌ User document not found');
        return;
      }

      final userData = userDoc.data() as Map<String, dynamic>;
      
      print('👤 User: ${currentUser.email}');
      print('🆔 UID: ${currentUser.uid}');
      print('📄 Document fields: ${userData.keys.toList()}');
      
      if (userData.containsKey('role')) {
        print('✅ Role: ${userData['role']}');
        print('🎯 Status: ${userData['role'] == 'admin' ? 'ADMIN' : 'USER'}');
      } else {
        print('❌ Role: MISSING');
        print('⚠️ You need to fix this!');
      }
      
    } catch (e) {
      print('❌ Error checking user status: $e');
    }
  }
}



