import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class BlockedUsersScreen extends StatelessWidget {
  const BlockedUsersScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      return const Scaffold(body: Center(child: Text('Not logged in.')));
    }
    return Scaffold(
      appBar: AppBar(title: const Text('Blocked Users')),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(currentUser.uid)
            .collection('blocked')
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text('No blocked users.'));
          }
          return ListView(
            children: snapshot.data!.docs.map((doc) {
              final data = doc.data() as Map<String, dynamic>;
              final blockedUid = doc.id;
              return ListTile(
                leading: const Icon(Icons.person_off),
                title: Text(data['username'] ?? blockedUid),
                subtitle: Text(data['email'] ?? ''),
                trailing: IconButton(
                  icon: const Icon(Icons.lock_open),
                  tooltip: 'Unblock',
                  onPressed: () async {
                    final scaffoldMessenger = ScaffoldMessenger.of(context);
                    await FirebaseFirestore.instance
                        .collection('users')
                        .doc(currentUser.uid)
                        .collection('blocked')
                        .doc(blockedUid)
                        .delete();
                    scaffoldMessenger.showSnackBar(
                      const SnackBar(content: Text('User unblocked.')),
                    );
                  },
                ),
              );
            }).toList(),
          );
        },
      ),
    );
  }
} 