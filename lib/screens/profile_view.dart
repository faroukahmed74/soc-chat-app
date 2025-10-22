import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/cupertino.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../utils/responsive_utils.dart';

class ProfileView extends StatelessWidget {
  final String userId;
  final bool isFriend;
  final bool canUnfriend;
  final bool canSendRequest;
  final VoidCallback? onUnfriend;
  final VoidCallback? onSendRequest;

  const ProfileView({
    Key? key,
    required this.userId,
    this.isFriend = false,
    this.canUnfriend = false,
    this.canSendRequest = false,
    this.onUnfriend,
    this.onSendRequest,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final isIOS = Theme.of(context).platform == TargetPlatform.iOS;
    
    // Responsive dimensions
    final avatarRadius = ResponsiveUtils.getResponsiveAvatarRadius(context);
    final titleFontSize = ResponsiveUtils.getResponsiveFontSize(context, baseSize: 22.0);
    final bodyFontSize = ResponsiveUtils.getResponsiveFontSize(context, baseSize: 16.0);
    final spacing = ResponsiveUtils.getResponsiveSpacing(context);
    
    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance.collection('users').doc(userId).get(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return isIOS
              ? const CupertinoActivityIndicator()
              : const Center(child: CircularProgressIndicator());
        }
        final data = snapshot.data!.data() as Map<String, dynamic>?;
        if (data == null) {
          return Center(
            child: isIOS
                ? Text('User not found.', style: TextStyle(fontSize: titleFontSize))
                : Text('User not found.', style: TextStyle(fontSize: titleFontSize)),
          );
        }
        final content = Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              radius: avatarRadius,
              backgroundImage: (data['photoUrl'] ?? '').isNotEmpty
                  ? NetworkImage(data['photoUrl'])
                  : null,
              child: (data['photoUrl'] ?? '').isEmpty
                  ? Icon(Icons.person, size: avatarRadius)
                  : null,
            ),
            SizedBox(height: spacing),
            Text(data['username'] ?? '', style: TextStyle(fontSize: titleFontSize, fontWeight: FontWeight.bold)),
            SizedBox(height: spacing / 2),
            Text(data['email'] ?? '', style: TextStyle(fontSize: bodyFontSize)),
            if ((data['phoneNumber'] ?? '').isNotEmpty)
              Padding(
                padding: EdgeInsets.only(top: spacing / 2),
                child: Text(data['phoneNumber'], style: TextStyle(fontSize: bodyFontSize)),
              ),
            SizedBox(height: spacing * 1.5),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton.icon(
                  icon: const Icon(Icons.block),
                  label: const Text('Block'),
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                  onPressed: () => _blockUser(context, userId, data),
                ),
                SizedBox(width: spacing / 2),
                ElevatedButton.icon(
                  icon: const Icon(Icons.report),
                  label: const Text('Report'),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
                  onPressed: () => _reportUser(context, userId, data),
                ),
              ],
                    ),
          ],
        );
        return isIOS
            ? CupertinoPageScaffold(child: SafeArea(child: content))
            : Padding(padding: ResponsiveUtils.getResponsivePadding(context), child: content);
      },
    );
  }

  void _blockUser(BuildContext context, String userId, Map<String, dynamic> userData) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;
    
    final navigator = Navigator.of(context);
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    String? reason;
    
    await showDialog(
      context: context,
      builder: (context) {
        final reasonController = TextEditingController();
        return AlertDialog(
          title: Text('Block ${userData['username'] ?? ''}?'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('You will not see messages or invites from this user.'),
              TextField(
                controller: reasonController,
                decoration: const InputDecoration(hintText: 'Reason (optional)'),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            TextButton(
              onPressed: () {
                reason = reasonController.text.trim();
                Navigator.pop(context);
              },
              child: const Text('Block'),
            ),
          ],
        );
      },
    );
    if (reason != null) {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.uid)
          .collection('blocked')
          .doc(userId)
          .set({
        'username': userData['username'],
        'email': userData['email'],
        'timestamp': FieldValue.serverTimestamp(),
        'reason': reason,
      });
      navigator.pop();
      scaffoldMessenger.showSnackBar(
        const SnackBar(content: Text('User blocked.')),
      );
    }
  }

  void _reportUser(BuildContext context, String userId, Map<String, dynamic> userData) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;
    
    final navigator = Navigator.of(context);
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    String? reason;
    String? details;
    
    await showDialog(
      context: context,
      builder: (context) {
        final reasonController = TextEditingController();
        final detailsController = TextEditingController();
        return AlertDialog(
          title: Text('Report ${userData['username'] ?? ''}?'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: reasonController,
                decoration: const InputDecoration(hintText: 'Reason (required)'),
              ),
              TextField(
                controller: detailsController,
                decoration: const InputDecoration(hintText: 'Details (optional)'),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            TextButton(
              onPressed: () {
                reason = reasonController.text.trim();
                details = detailsController.text.trim();
                Navigator.pop(context);
              },
              child: const Text('Report'),
            ),
          ],
        );
      },
    );
    if (reason != null && reason!.isNotEmpty) {
      await FirebaseFirestore.instance.collection('reports').add({
        'reporterId': currentUser.uid,
        'reportedUserId': userId,
        'reason': reason,
        'details': details,
        'timestamp': FieldValue.serverTimestamp(),
        'reportedUsername': userData['username'],
        'reportedEmail': userData['email'],
      });
      navigator.pop();
      scaffoldMessenger.showSnackBar(
        const SnackBar(content: Text('User reported.')),
      );
    }
  }
} 