import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ReportsReviewScreen extends StatelessWidget {
  const ReportsReviewScreen({Key? key}) : super(key: key);

  Future<void> _blockUser(BuildContext context, String userId, String username, String email) async {
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    final admin = FirebaseAuth.instance.currentUser;
    if (admin == null) return;
    await FirebaseFirestore.instance
        .collection('users')
        .doc(admin.uid)
        .collection('blocked')
        .doc(userId)
        .set({
      'username': username,
      'email': email,
      'timestamp': FieldValue.serverTimestamp(),
      'reason': 'Blocked by admin from report review',
    });
    scaffoldMessenger.showSnackBar(
      SnackBar(content: Text('User $username blocked.')),
    );
  }

  Future<void> _deleteUser(BuildContext context, String userId) async {
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    await FirebaseFirestore.instance.collection('users').doc(userId).delete();
    scaffoldMessenger.showSnackBar(
      const SnackBar(content: Text('User deleted from Firestore.')),
    );
  }

  Future<void> _disableUser(BuildContext context, String userId) async {
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    await FirebaseFirestore.instance.collection('users').doc(userId).update({'disabled': true});
    scaffoldMessenger.showSnackBar(
      const SnackBar(content: Text('User account disabled in Firestore.')),);
  }

  Future<void> _setReportStatus(BuildContext context, String reportId, String status) async {
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    await FirebaseFirestore.instance.collection('reports').doc(reportId).update({'status': status});
    scaffoldMessenger.showSnackBar(
      SnackBar(content: Text('Report marked as $status.')),);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('User Reports Review')),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('reports').orderBy('timestamp', descending: true).snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text('No reports found.'));
          }
          return ListView(
            children: snapshot.data!.docs.map((doc) {
              final data = doc.data() as Map<String, dynamic>;
              final reportedUserId = data['reportedUserId'] ?? '';
              final reportedUsername = data['reportedUsername'] ?? '';
              final reportedEmail = data['reportedEmail'] ?? '';
              final reporterId = data['reporterId'] ?? '';
              final reason = data['reason'] ?? '';
              final details = data['details'] ?? '';
              final timestamp = (data['timestamp'] as Timestamp?)?.toDate();
              final status = data['status'] ?? 'open';
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: ListTile(
                  title: Text('Reported: $reportedUsername ($reportedEmail)'),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('User ID: $reportedUserId'),
                      Text('Reporter ID: $reporterId'),
                      Text('Reason: $reason'),
                      if (details.isNotEmpty) Text('Details: $details'),
                      if (timestamp != null) Text('Time: $timestamp'),
                      Text('Status: $status', style: TextStyle(fontWeight: FontWeight.bold, color: status == 'open' ? Colors.red : Colors.green)),
                    ],
                  ),
                  trailing: PopupMenuButton<String>(
                    onSelected: (value) async {
                      if (value == 'block') {
                        await _blockUser(context, reportedUserId, reportedUsername, reportedEmail);
                      } else if (value == 'delete') {
                        await _deleteUser(context, reportedUserId);
                      } else if (value == 'disable') {
                        await _disableUser(context, reportedUserId);
                      } else if (value == 'resolved') {
                        await _setReportStatus(context, doc.id, 'resolved');
                      } else if (value == 'ignored') {
                        await _setReportStatus(context, doc.id, 'ignored');
                      }
                    },
                    itemBuilder: (context) => [
                      const PopupMenuItem(value: 'block', child: Text('Block User')),
                      const PopupMenuItem(value: 'disable', child: Text('Disable User (Firestore)')),
                      const PopupMenuItem(value: 'delete', child: Text('Delete User (Firestore only)')),
                      const PopupMenuItem(value: 'resolved', child: Text('Mark as Resolved')),
                      const PopupMenuItem(value: 'ignored', child: Text('Ignore Report')),
                    ],
                  ),
                ),
              );
            }).toList(),
          );
        },
      ),
    );
  }
} 