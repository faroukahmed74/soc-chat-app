// =============================================================================
// ROLE UPDATER UTILITY
// =============================================================================
// This utility helps update existing users who don't have a role field
// Run this once to fix users created before the role field was added

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class RoleUpdater {
  /// Updates the current user's role field if it's missing
  static Future<bool> updateCurrentUserRole() async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        print('No user logged in');
        return false;
      }

      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.uid)
          .get();

      if (!userDoc.exists) {
        print('User document not found');
        return false;
      }

      final userData = userDoc.data() as Map<String, dynamic>;
      
      // Check if user already has a role field
      if (userData.containsKey('role')) {
        print('User already has role: ${userData['role']}');
        return true;
      }

      // Add role field
      await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.uid)
          .update({
        'role': 'admin', // Set as admin since you're the developer
        'roleUpdatedAt': FieldValue.serverTimestamp(),
      });

      print('User role updated to: admin');
      return true;
    } catch (e) {
      print('Error updating user role: $e');
      return false;
    }
  }

  /// Updates all existing users with missing role fields
  static Future<void> updateAllUsersWithRole() async {
    try {
      final usersSnapshot = await FirebaseFirestore.instance.collection('users').get();
      int updatedCount = 0;
      
      for (final doc in usersSnapshot.docs) {
        final userData = doc.data();
        
        // Check if user doesn't have a role field
        if (!userData.containsKey('role')) {
          print('Updating user ${doc.id} with missing role field');
          
          // Add default role field
          await FirebaseFirestore.instance
              .collection('users')
              .doc(doc.id)
              .update({
            'role': 'user', // Default role for existing users
            'roleUpdatedAt': FieldValue.serverTimestamp(),
          });
          
          updatedCount++;
          print('User ${doc.id} updated with role: user');
        }
      }
      
      print('Updated $updatedCount users with role field');
    } catch (e) {
      print('Error updating all users with role: $e');
    }
  }

  /// Sets a specific user as admin
  static Future<bool> setUserAsAdmin(String userId) async {
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .update({
        'role': 'admin',
        'roleUpdatedAt': FieldValue.serverTimestamp(),
      });

      print('User $userId set as admin');
      return true;
    } catch (e) {
      print('Error setting user as admin: $e');
      return false;
    }
  }

  /// Gets current user's role
  static Future<String?> getCurrentUserRole() async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) return null;

      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.uid)
          .get();

      if (!userDoc.exists) return null;

      final userData = userDoc.data() as Map<String, dynamic>;
      return userData['role'];
    } catch (e) {
      print('Error getting user role: $e');
      return null;
    }
  }
}



