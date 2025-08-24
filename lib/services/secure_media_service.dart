import 'dart:typed_data';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class SecureMediaService {
  static final FirebaseStorage _storage = FirebaseStorage.instance;
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Upload media to Firebase Storage and return download URL
  static Future<String> uploadMediaToStorage(
    Uint8List mediaBytes,
    String fileName,
    String mimeType,
    String chatId,
  ) async {
    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception('User not authenticated');

      // Create unique file path
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final filePath = 'chats/$chatId/media/$timestamp-$fileName';
      
      // Create storage reference
      final storageRef = _storage.ref().child(filePath);
      
      // Upload file
      final uploadTask = storageRef.putData(
        mediaBytes,
        SettableMetadata(contentType: mimeType),
      );
      
      // Wait for upload to complete
      final snapshot = await uploadTask;
      
      // Get download URL
      final downloadUrl = await snapshot.ref.getDownloadURL();
      
      print('[SecureMedia] Media uploaded successfully: $downloadUrl');
      return downloadUrl;
    } catch (e) {
      print('[SecureMedia] Error uploading media: $e');
      rethrow;
    }
  }

  /// Delete media from Firebase Storage
  static Future<void> deleteMediaFromStorage(String mediaUrl) async {
    try {
      if (mediaUrl.isEmpty) return;
      
      // Extract file path from URL
      final uri = Uri.parse(mediaUrl);
      final pathSegments = uri.pathSegments;
      
      if (pathSegments.length >= 3) {
        final filePath = pathSegments.sublist(1).join('/');
        final storageRef = _storage.ref().child(filePath);
        
        await storageRef.delete();
        print('[SecureMedia] Media deleted from storage: $mediaUrl');
      }
    } catch (e) {
      print('[SecureMedia] Error deleting media: $e');
      // Don't rethrow - media deletion failure shouldn't break message deletion
    }
  }

  /// Store media reference in Firestore (only metadata, not binary data)
  static Future<Map<String, dynamic>> createMediaMessageData({
    required String type,
    required String mediaUrl,
    required String mimeType,
    required String chatId,
    String? fileType,
    String? fileName,
  }) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('User not authenticated');

    return {
      'type': type,
      'mediaUrl': mediaUrl, // Store URL instead of binary data
      'mimeType': mimeType,
      'senderId': user.uid,
      'senderName': user.displayName ?? 'Unknown User',
      'timestamp': FieldValue.serverTimestamp(),
      'isPinned': false,
      'reactions': {},
      'text': type == 'image' ? '📷 Image' : 
              type == 'audio' ? '🎵 Voice Message' : 
              type == 'document' ? '📎 Document' : 'Media',
      'fileType': fileType,
      'fileName': fileName,
      'chatId': chatId,
      'expiresAt': _calculateExpirationDate(),
      'deliveryStatus': _createDeliveryStatus(chatId),
    };
  }

  /// Calculate expiration date (7 days from now)
  static DateTime _calculateExpirationDate() {
    return DateTime.now().add(const Duration(days: 7));
  }

  /// Create delivery status tracking for all recipients
  static Map<String, dynamic> _createDeliveryStatus(String chatId) {
    // This will be populated with actual recipient IDs when message is sent
    return {
      'pending': true,
      'recipients': <String, Map<String, dynamic>>{},
      'deliveredAt': null,
      'readAt': null,
    };
  }

  /// Update delivery status for a specific recipient
  static Future<void> updateDeliveryStatus(
    String messageId,
    String recipientId,
    String status, // 'delivered' or 'read'
  ) async {
    try {
      final messageRef = _firestore
          .collection('chats')
          .doc('temp') // Will be updated with actual chat ID
          .collection('messages')
          .doc(messageId);

      await messageRef.update({
        'deliveryStatus.recipients.$recipientId.$status': FieldValue.serverTimestamp(),
      });

      print('[SecureMedia] Delivery status updated: $messageId -> $recipientId: $status');
    } catch (e) {
      print('[SecureMedia] Error updating delivery status: $e');
    }
  }

  /// Check if all recipients have received the message
  static bool hasAllRecipientsReceived(Map<String, dynamic> deliveryStatus) {
    final recipients = deliveryStatus['recipients'] as Map<String, dynamic>?;
    if (recipients == null || recipients.isEmpty) return false;
    
    return recipients.values.every((status) => 
      status is Map && status['delivered'] != null
    );
  }

  /// Check if message has expired
  static bool hasMessageExpired(DateTime? expiresAt) {
    if (expiresAt == null) return false;
    return DateTime.now().isAfter(expiresAt);
  }
}
