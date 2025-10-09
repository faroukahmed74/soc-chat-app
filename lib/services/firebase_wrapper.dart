// lib/services/firebase_wrapper.dart
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../config/database_config.dart';
import 'local_auth_service.dart';

/// Firebase wrapper that handles both Firebase and physical server modes
class FirebaseWrapper {
  static bool get _usePhysicalServer => DatabaseConfig.usePhysicalServer;
  
  // Firebase Auth wrapper
  static FirebaseAuth get auth {
    if (_usePhysicalServer) {
      throw UnsupportedError('Firebase Auth is not available in physical server mode. Use LocalAuthService instead.');
    }
    return FirebaseAuth.instance;
  }
  
  // Firebase Firestore wrapper
  static FirebaseFirestore get firestore {
    if (_usePhysicalServer) {
      throw UnsupportedError('Firebase Firestore is not available in physical server mode. Use local API instead.');
    }
    return FirebaseFirestore.instance;
  }
  
  // Firebase Storage wrapper
  static FirebaseStorage get storage {
    if (_usePhysicalServer) {
      throw UnsupportedError('Firebase Storage is not available in physical server mode. Use local API instead.');
    }
    return FirebaseStorage.instance;
  }
  
  // Get current user (works in both modes)
  static User? get currentUser {
    if (_usePhysicalServer) {
      // Return null in physical server mode - use LocalAuthService instead
      return null;
    }
    return FirebaseAuth.instance.currentUser;
  }
  
  // Get current user ID (works in both modes)
  static String? get currentUserId {
    if (_usePhysicalServer) {
      // Get user ID from LocalAuthService
      return LocalAuthService.getCurrentUserId();
    }
    return FirebaseAuth.instance.currentUser?.uid;
  }
  
  // Check if user is authenticated (works in both modes)
  static bool get isAuthenticated {
    if (_usePhysicalServer) {
      return LocalAuthService.isLoggedIn();
    }
    return FirebaseAuth.instance.currentUser != null;
  }
  
  // Sign out (works in both modes)
  static Future<void> signOut() async {
    if (_usePhysicalServer) {
      await LocalAuthService.logout();
    } else {
      await FirebaseAuth.instance.signOut();
    }
  }
  
  // Auth state changes stream (works in both modes)
  static Stream<User?> authStateChanges() {
    if (_usePhysicalServer) {
      // Return a stream that emits null (no auth state changes in physical server mode)
      return Stream.value(null);
    }
    return FirebaseAuth.instance.authStateChanges();
  }
  
  // Create user with email and password (works in both modes)
  static Future<UserCredential?> createUserWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    if (_usePhysicalServer) {
      // Use LocalAuthService for registration
      final result = await LocalAuthService.register(
        email: email,
        password: password,
        displayName: email.split('@')[0], // Use email prefix as display name
      );
      if (result) {
        // Return a mock UserCredential for compatibility
        return null; // Or create a mock UserCredential if needed
      }
      return null;
    }
    return await FirebaseAuth.instance.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
  }
  
  // Sign in with email and password (works in both modes)
  static Future<UserCredential?> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    if (_usePhysicalServer) {
      // Use LocalAuthService for login
      final result = await LocalAuthService.login(email: email, password: password);
      if (result) {
        // Return a mock UserCredential for compatibility
        return null; // Or create a mock UserCredential if needed
      }
      return null;
    }
    return await FirebaseAuth.instance.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
  }
  
  // Send password reset email (works in both modes)
  static Future<void> sendPasswordResetEmail({required String email}) async {
    if (_usePhysicalServer) {
      // Password reset not implemented in physical server mode
      throw UnsupportedError('Password reset is not available in physical server mode');
    }
    return await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
  }
  
  // Check if Firebase is available
  static bool get isFirebaseAvailable => !_usePhysicalServer;
  
  // Check if physical server is being used
  static bool get isPhysicalServerMode => _usePhysicalServer;
}
