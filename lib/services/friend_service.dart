import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class FriendService {
  static final _firestore = FirebaseFirestore.instance;
  static final _auth = FirebaseAuth.instance;

  /// Send a friend request from current user to [toUid]
  static Future<void> sendFriendRequest(String toUid) async {
    final fromUid = _auth.currentUser?.uid;
    if (fromUid == null || fromUid == toUid) return;
    final receiverRequestRef = _firestore.collection('users').doc(toUid).collection('friend_requests').doc(fromUid);
    final senderOutgoingRef = _firestore.collection('users').doc(fromUid).collection('outgoing_requests').doc(toUid);
    final data = {
      'from': fromUid,
      'to': toUid,
      'status': 'pending',
      'timestamp': FieldValue.serverTimestamp(),
    };
    await receiverRequestRef.set(data);
    await senderOutgoingRef.set(data);
  }

  /// Accept a friend request from [fromUid] to current user
  static Future<void> acceptFriendRequest(String fromUid) async {
    final toUid = _auth.currentUser?.uid;
    if (toUid == null) return;
    final receiverRequestRef = _firestore.collection('users').doc(toUid).collection('friend_requests').doc(fromUid);
    final senderOutgoingRef = _firestore.collection('users').doc(fromUid).collection('outgoing_requests').doc(toUid);
    await receiverRequestRef.update({'status': 'accepted'});
    await senderOutgoingRef.update({'status': 'accepted'});
    // Add each other as friends
    await _firestore.collection('users').doc(toUid).collection('friends').doc(fromUid).set({'since': FieldValue.serverTimestamp()});
    await _firestore.collection('users').doc(fromUid).collection('friends').doc(toUid).set({'since': FieldValue.serverTimestamp()});
  }

  /// Reject a friend request from [fromUid] to current user
  static Future<void> rejectFriendRequest(String fromUid) async {
    final toUid = _auth.currentUser?.uid;
    if (toUid == null) return;
    final receiverRequestRef = _firestore.collection('users').doc(toUid).collection('friend_requests').doc(fromUid);
    final senderOutgoingRef = _firestore.collection('users').doc(fromUid).collection('outgoing_requests').doc(toUid);
    await receiverRequestRef.update({'status': 'rejected'});
    await senderOutgoingRef.update({'status': 'rejected'});
  }

  /// Remove a friend (unfriend)
  static Future<void> removeFriend(String friendUid) async {
    final currentUid = _auth.currentUser?.uid;
    if (currentUid == null) return;
    await _firestore.collection('users').doc(currentUid).collection('friends').doc(friendUid).delete();
    await _firestore.collection('users').doc(friendUid).collection('friends').doc(currentUid).delete();
  }

  /// Check if [otherUid] is a friend of the current user
  static Future<bool> isFriend(String otherUid) async {
    final currentUid = _auth.currentUser?.uid;
    if (currentUid == null) return false;
    final doc = await _firestore.collection('users').doc(currentUid).collection('friends').doc(otherUid).get();
    return doc.exists;
  }

  /// Get all friends of the current user
  static Stream<List<String>> friendsStream() {
    final currentUid = _auth.currentUser?.uid;
    if (currentUid == null) return const Stream.empty();
    return _firestore.collection('users').doc(currentUid).collection('friends').snapshots().map(
      (snap) => snap.docs.map((doc) => doc.id).toList(),
    );
  }

  /// Get all incoming friend requests for the current user
  static Stream<List<Map<String, dynamic>>> incomingRequestsStream() {
    final currentUid = _auth.currentUser?.uid;
    if (currentUid == null) return const Stream.empty();
    return _firestore.collection('users').doc(currentUid).collection('friend_requests').where('status', isEqualTo: 'pending').snapshots().map(
      (snap) => snap.docs.map((doc) => doc.data()).toList(),
    );
  }

  /// Get all outgoing friend requests sent by the current user
  static Stream<List<Map<String, dynamic>>> outgoingRequestsStream() {
    final currentUid = _auth.currentUser?.uid;
    if (currentUid == null) return const Stream.empty();
    return _firestore.collection('users').doc(currentUid).collection('outgoing_requests').where('status', isEqualTo: 'pending').snapshots().map(
      (snap) => snap.docs.map((doc) => doc.data()).toList(),
    );
  }
} 