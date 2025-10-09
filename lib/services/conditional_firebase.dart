// lib/services/conditional_firebase.dart
import '../config/database_config.dart';

// Conditional Firebase imports - only import when not using physical server
import 'firebase_services.dart' if (dart.library.io) 'firebase_services_physical.dart' as firebase_services;

/// Conditional Firebase service that works in both modes
class ConditionalFirebase {
  static bool get usePhysicalServer => DatabaseConfig.usePhysicalServer;
  
  // Auth methods
  static dynamic get auth => firebase_services.getAuth();
  static String? get currentUserId => firebase_services.getCurrentUserId();
  static bool get isAuthenticated => firebase_services.isAuthenticated();
  static Future<void> signOut() => firebase_services.signOut();
  static Stream<dynamic> authStateChanges() => firebase_services.authStateChanges();
  
  // Firestore methods
  static dynamic get firestore => firebase_services.getFirestore();
  
  // Storage methods
  static dynamic get storage => firebase_services.getStorage();
  
  // User creation/login
  static Future<dynamic> createUserWithEmailAndPassword({
    required String email,
    required String password,
  }) => firebase_services.createUserWithEmailAndPassword(email: email, password: password);
  
  static Future<dynamic> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) => firebase_services.signInWithEmailAndPassword(email: email, password: password);
  
  static Future<void> sendPasswordResetEmail({required String email}) => 
      firebase_services.sendPasswordResetEmail(email: email);
}
