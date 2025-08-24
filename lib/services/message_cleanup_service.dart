import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:async';
import 'dart:io';
import 'package:path_provider/path_provider.dart';


/// Service for automatically cleaning up messages and implementing local-only storage
/// Handles all message types: text, image, document, voice
class MessageCleanupService {
  static final MessageCleanupService _instance = MessageCleanupService._internal();
  factory MessageCleanupService() => _instance;
  MessageCleanupService._internal();

  Timer? _cleanupTimer;
  static const Duration _cleanupInterval = Duration(hours: 6); // Run every 6 hours
  static const Duration _readMessageExpiry = Duration(days: 3); // Remove read messages after 3 days
  static const Duration _unreadMessageExpiry = Duration(days: 7); // Remove unread messages after 7 days
  static const Duration _mediaFileExpiry = Duration(days: 14); // Remove media files after 14 days

  /// Starts the automatic message cleanup service
  void start() {
    _cleanupTimer?.cancel();
    _cleanupTimer = Timer.periodic(_cleanupInterval, (_) => _performCleanup());
    
    // Perform initial cleanup
    _performCleanup();
  }

  /// Stops the automatic message cleanup service
  void stop() {
    _cleanupTimer?.cancel();
  }

  /// Performs the actual cleanup of expired messages and media files with retry mechanism
  Future<void> _performCleanup() async {
    int retryCount = 0;
    const maxRetries = 3;
    
    while (retryCount < maxRetries) {
      try {
        final currentUser = FirebaseAuth.instance.currentUser;
        if (currentUser == null) return;

        print('[MessageCleanup] Starting automatic cleanup... (attempt ${retryCount + 1})');
        
        // Clean up Firestore messages (keep only recent ones)
        final firestoreMessagesRemoved = await _cleanupFirestoreMessages(currentUser.uid);
        
        // Clean up local storage
        final localFilesRemoved = await _cleanupLocalStorage();
        
        // Clean up Firebase Storage media files
        final storageFilesRemoved = await _cleanupFirebaseStorage();
        
        print('[MessageCleanup] Cleanup completed. Firestore: $firestoreMessagesRemoved, Local: $localFilesRemoved, Storage: $storageFilesRemoved');
        
        // Update cleanup statistics
        await _updateCleanupStatistics(
          firestoreMessagesRemoved, 
          localFilesRemoved, 
          storageFilesRemoved
        );
        
        // Success - break out of retry loop
        break;
        
      } catch (e) {
        retryCount++;
        print('[MessageCleanup] Error during cleanup (attempt $retryCount): $e');
        
        if (retryCount >= maxRetries) {
          print('[MessageCleanup] Max retries reached. Cleanup failed.');
          // Log the final failure
          await _logCleanupFailure(e.toString());
        } else {
          // Wait before retrying (exponential backoff)
          final delay = Duration(seconds: retryCount * 2);
          print('[MessageCleanup] Retrying in ${delay.inSeconds} seconds...');
          await Future.delayed(delay);
        }
      }
    }
  }
  
  /// Logs cleanup failures for monitoring
  Future<void> _logCleanupFailure(String error) async {
    try {
      await FirebaseFirestore.instance
          .collection('cleanup_logs')
          .add({
        'timestamp': FieldValue.serverTimestamp(),
        'error': error,
        'type': 'automatic_cleanup_failure',
        'userId': FirebaseAuth.instance.currentUser?.uid,
      });
    } catch (e) {
      print('[MessageCleanup] Failed to log cleanup failure: $e');
    }
  }

  /// Cleans up old messages from Firestore (keep only recent ones for sync)
  Future<int> _cleanupFirestoreMessages(String userId) async {
    try {
      final now = DateTime.now();
      final readExpiryTime = now.subtract(_readMessageExpiry);
      final unreadExpiryTime = now.subtract(_unreadMessageExpiry);

      // Get all chats for the current user
      final chatsSnapshot = await FirebaseFirestore.instance
          .collection('chats')
          .where('members', arrayContains: userId)
          .get();

      int totalMessagesRemoved = 0;
      
      for (final chatDoc in chatsSnapshot.docs) {
        final chatId = chatDoc.id;
        final messagesRemoved = await _cleanupChatMessages(chatId, userId, readExpiryTime, unreadExpiryTime);
        totalMessagesRemoved += messagesRemoved;
      }

      return totalMessagesRemoved;
    } catch (e) {
      print('[MessageCleanup] Error cleaning up Firestore messages: $e');
      return 0;
    }
  }

  /// Cleans up messages for a specific chat
  Future<int> _cleanupChatMessages(String chatId, String userId, DateTime readExpiryTime, DateTime unreadExpiryTime) async {
    try {
      // Get messages that need cleanup
      final messagesQuery = FirebaseFirestore.instance
          .collection('chats')
          .doc(chatId)
          .collection('messages')
          .where('timestamp', isLessThan: Timestamp.fromDate(unreadExpiryTime));

      final messagesSnapshot = await messagesQuery.get();
      
      int removedCount = 0;
      final batch = FirebaseFirestore.instance.batch();

      for (final messageDoc in messagesSnapshot.docs) {
        final messageData = messageDoc.data();
        final timestamp = messageData['timestamp'] as Timestamp?;
        final readBy = messageData['readBy'] as Map<String, dynamic>?;
        final isReadByUser = readBy?[userId] == true;
        final messageType = messageData['type'] ?? 'text';

        if (timestamp != null) {
          final messageTime = timestamp.toDate();
          
          // Remove if message is old enough
          if (messageTime.isBefore(unreadExpiryTime)) {
            // Message is older than unread expiry, remove regardless of read status
            batch.delete(messageDoc.reference);
            removedCount++;
            
            // Also remove associated media files from Firebase Storage
            if (messageType != 'text') {
              await _removeMediaFromStorage(messageData);
            }
          } else if (isReadByUser && messageTime.isBefore(readExpiryTime)) {
            // Message was read by user and is older than read expiry, remove it
            batch.delete(messageDoc.reference);
            removedCount++;
            
            // Remove associated media files
            if (messageType != 'text') {
              await _removeMediaFromStorage(messageData);
            }
          }
        }
      }

      // Commit the batch deletion
      if (removedCount > 0) {
        await batch.commit();
        print('[MessageCleanup] Removed $removedCount messages from chat $chatId');
      }

      return removedCount;
    } catch (e) {
      print('[MessageCleanup] Error cleaning up chat $chatId: $e');
      return 0;
    }
  }

  /// Removes media files from Firebase Storage
  Future<void> _removeMediaFromStorage(Map<String, dynamic> messageData) async {
    try {
      final messageType = messageData['type'] ?? 'text';
      
      switch (messageType) {
        case 'image':
          final imageUrl = messageData['imageUrl'];
          if (imageUrl != null) {
            await _deleteStorageFile(imageUrl);
          }
          break;
        case 'document':
          final documentUrl = messageData['documentUrl'];
          if (documentUrl != null) {
            await _deleteStorageFile(documentUrl);
          }
          break;
        case 'voice':
          final voiceUrl = messageData['voiceUrl'];
          if (voiceUrl != null) {
            await _deleteStorageFile(voiceUrl);
          }
          break;
      }
    } catch (e) {
      print('[MessageCleanup] Error removing media from storage: $e');
    }
  }

  /// Deletes a file from Firebase Storage
  Future<void> _deleteStorageFile(String url) async {
    try {
      final ref = FirebaseStorage.instance.refFromURL(url);
      await ref.delete();
      print('[MessageCleanup] Deleted storage file: $url');
    } catch (e) {
      print('[MessageCleanup] Error deleting storage file $url: $e');
    }
  }

  /// Cleans up local storage files
  Future<int> _cleanupLocalStorage() async {
    try {
      int removedCount = 0;
      
      // Clean up app documents directory
      final appDir = await getApplicationDocumentsDirectory();
      final chatDir = Directory('${appDir.path}/chat_files');
      
      if (await chatDir.exists()) {
        removedCount += await _cleanupDirectory(chatDir, _mediaFileExpiry);
      }
      
      // Clean up temporary directory
      final tempDir = await getTemporaryDirectory();
      final chatTempDir = Directory('${tempDir.path}/chat_temp');
      
      if (await chatTempDir.exists()) {
        removedCount += await _cleanupDirectory(chatTempDir, Duration(hours: 24)); // Temp files expire in 24 hours
      }
      
      return removedCount;
    } catch (e) {
      print('[MessageCleanup] Error cleaning up local storage: $e');
      return 0;
    }
  }

  /// Cleans up a specific directory
  Future<int> _cleanupDirectory(Directory dir, Duration expiry) async {
    try {
      int removedCount = 0;
      final now = DateTime.now();
      final expiryTime = now.subtract(expiry);
      
      await for (final entity in dir.list(recursive: true)) {
        if (entity is File) {
          final stat = await entity.stat();
          if (stat.modified.isBefore(expiryTime)) {
            await entity.delete();
            removedCount++;
          }
        }
      }
      
      return removedCount;
    } catch (e) {
      print('[MessageCleanup] Error cleaning up directory ${dir.path}: $e');
      return 0;
    }
  }

  /// Cleans up Firebase Storage files
  Future<int> _cleanupFirebaseStorage() async {
    try {
      int removedCount = 0;
      
      // Clean up chat images
      removedCount += await _cleanupStorageFolder('chat_images', _mediaFileExpiry);
      
      // Clean up chat documents
      removedCount += await _cleanupStorageFolder('chat_documents', _mediaFileExpiry);
      
      // Clean up voice messages
      removedCount += await _cleanupStorageFolder('voice_messages', _mediaFileExpiry);
      
      return removedCount;
    } catch (e) {
      print('[MessageCleanup] Error cleaning up Firebase Storage: $e');
      return 0;
    }
  }

  /// Cleans up a specific storage folder
  Future<int> _cleanupStorageFolder(String folderName, Duration expiry) async {
    try {
      int removedCount = 0;
      final now = DateTime.now();
      final expiryTime = now.subtract(expiry);
      
      final folderRef = FirebaseStorage.instance.ref().child(folderName);
      final result = await folderRef.listAll();
      
      for (final item in result.items) {
        try {
          final metadata = await item.getMetadata();
          final creationTime = metadata.timeCreated;
          
          if (creationTime != null && creationTime.isBefore(expiryTime)) {
            await item.delete();
            removedCount++;
          }
        } catch (e) {
          // Skip items that can't be processed
          continue;
        }
      }
      
      return removedCount;
    } catch (e) {
      print('[MessageCleanup] Error cleaning up storage folder $folderName: $e');
      return 0;
    }
  }

  /// Updates cleanup statistics in Firestore
  Future<void> _updateCleanupStatistics(int firestoreRemoved, int localRemoved, int storageRemoved) async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) return;

      await FirebaseFirestore.instance
          .collection('system_stats')
          .doc('message_cleanup')
          .set({
        'lastCleanup': FieldValue.serverTimestamp(),
        'firestoreMessagesRemoved': firestoreRemoved,
        'localFilesRemoved': localRemoved,
        'storageFilesRemoved': storageRemoved,
        'totalRemoved': firestoreRemoved + localRemoved + storageRemoved,
        'cleanupInterval': _cleanupInterval.inHours,
        'readMessageExpiry': _readMessageExpiry.inDays,
        'unreadMessageExpiry': _unreadMessageExpiry.inDays,
        'mediaFileExpiry': _mediaFileExpiry.inDays,
        'performedBy': currentUser.uid,
      }, SetOptions(merge: true));
    } catch (e) {
      print('[MessageCleanup] Error updating statistics: $e');
    }
  }

  /// Manually triggers cleanup for a specific chat
  Future<int> manualCleanup(String chatId) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return 0;
    
    final now = DateTime.now();
    final readExpiryTime = now.subtract(_readMessageExpiry);
    final unreadExpiryTime = now.subtract(_unreadMessageExpiry);
    
    return await _cleanupChatMessages(chatId, currentUser.uid, readExpiryTime, unreadExpiryTime);
  }

  /// Gets cleanup statistics
  Future<Map<String, dynamic>?> getCleanupStats() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('system_stats')
          .doc('message_cleanup')
          .get();
      
      return doc.data();
    } catch (e) {
      print('[MessageCleanup] Error getting cleanup stats: $e');
      return null;
    }
  }

  /// Updates cleanup settings
  Future<void> updateCleanupSettings({
    Duration? readMessageExpiry,
    Duration? unreadMessageExpiry,
    Duration? mediaFileExpiry,
    Duration? cleanupInterval,
  }) async {
    try {
      if (readMessageExpiry != null) {
        print('[MessageCleanup] Read message expiry updated to ${readMessageExpiry.inDays} days');
      }
      
      if (unreadMessageExpiry != null) {
        print('[MessageCleanup] Unread message expiry updated to ${unreadMessageExpiry.inDays} days');
      }
      
      if (mediaFileExpiry != null) {
        print('[MessageCleanup] Media file expiry updated to ${mediaFileExpiry.inDays} days');
      }
      
      if (cleanupInterval != null) {
        print('[MessageCleanup] Cleanup interval updated to ${cleanupInterval.inHours} hours');
        // Restart timer with new interval
        start();
      }
    } catch (e) {
      print('[MessageCleanup] Error updating cleanup settings: $e');
    }
  }

  /// Downloads and stores message locally (for offline access)
  Future<String?> downloadMessageLocally(Map<String, dynamic> messageData) async {
    try {
      final messageType = messageData['type'] ?? 'text';
      
      if (messageType == 'text') {
        // Text messages are stored directly in local storage
        return await _storeTextMessageLocally(messageData);
      } else {
        // Media messages are downloaded and stored locally
        return await _downloadMediaMessageLocally(messageData);
      }
    } catch (e) {
      print('[MessageCleanup] Error downloading message locally: $e');
      return null;
    }
  }

  /// Stores text message locally
  Future<String?> _storeTextMessageLocally(Map<String, dynamic> messageData) async {
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final chatDir = Directory('${appDir.path}/chat_messages');
      await chatDir.create(recursive: true);
      
      final messageId = messageData['id'] ?? DateTime.now().millisecondsSinceEpoch.toString();
      final file = File('${chatDir.path}/$messageId.json');
      
      // Store message data locally
      await file.writeAsString(messageData.toString());
      
      return file.path;
    } catch (e) {
      print('[MessageCleanup] Error storing text message locally: $e');
      return null;
    }
  }

  /// Downloads and stores media message locally
  Future<String?> _downloadMediaMessageLocally(Map<String, dynamic> messageData) async {
    try {
      final messageType = messageData['type'] ?? 'text';
      String? downloadUrl;
      
      switch (messageType) {
        case 'image':
          downloadUrl = messageData['imageUrl'];
          break;
        case 'document':
          downloadUrl = messageData['documentUrl'];
          break;
        case 'voice':
          downloadUrl = messageData['voiceUrl'];
          break;
        default:
          return null;
      }
      
      if (downloadUrl == null) return null;
      
      // Download file from Firebase Storage
      final ref = FirebaseStorage.instance.refFromURL(downloadUrl);
      final bytes = await ref.getData();
      
      if (bytes == null) return null;
      
      // Store locally
      final appDir = await getApplicationDocumentsDirectory();
      final chatDir = Directory('${appDir.path}/chat_files/$messageType');
      await chatDir.create(recursive: true);
      
      final fileName = '${messageData['id'] ?? DateTime.now().millisecondsSinceEpoch}.${_getFileExtension(messageType)}';
      final file = File('${chatDir.path}/$fileName');
      
      await file.writeAsBytes(bytes);
      
      // Update message data with local path
      messageData['localPath'] = file.path;
      await _storeTextMessageLocally(messageData);
      
      return file.path;
    } catch (e) {
      print('[MessageCleanup] Error downloading media message locally: $e');
      return null;
    }
  }

  /// Gets file extension based on message type
  String _getFileExtension(String messageType) {
    switch (messageType) {
      case 'image':
        return 'jpg';
      case 'document':
        return 'pdf';
      case 'voice':
        return 'wav';
      default:
        return 'txt';
    }
  }
}
