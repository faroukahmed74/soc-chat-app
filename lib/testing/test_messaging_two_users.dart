import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config/database_config.dart';
import '../services/database_service.dart';
import '../services/physical_auth_service.dart';

void main() {
  runApp(const MaterialApp(home: DualUserMessagingHarness()));
}

class DualUserMessagingHarness extends StatefulWidget {
  const DualUserMessagingHarness({Key? key}) : super(key: key);

  @override
  State<DualUserMessagingHarness> createState() => _DualUserMessagingHarnessState();
}

class _DualUserMessagingHarnessState extends State<DualUserMessagingHarness> {
  String _status = 'Initializing...';
  final List<String> _logs = [];
  bool _running = false;

  @override
  void initState() {
    super.initState();
    _start();
  }

  Future<void> _start() async {
    if (_running) return;
    _running = true;
    setState(() { _status = 'Preparing environment...'; });
    try {
      await DatabaseConfig.initialize();
      await DatabaseConfig.setServerUrlOverride('http://localhost:3010');

      // Prepare two users
      final userAEmail = 'test.a@example.com';
      final userBEmail = 'test.b@example.com';
      const password = 'Test12345!';

      final auth = PhysicalAuthService();
      final a = await _ensureAccount(auth, userAEmail, password, name: 'Test A');
      final b = await _ensureAccount(auth, userBEmail, password, name: 'Test B');
      if (!a['success'] || !b['success']) {
        _log('Failed to prepare accounts: A=${a['success']} B=${b['success']}');
        setState(() { _status = 'Failed'; });
        return;
      }

      final tokenA = a['token'] as String;
      final tokenB = b['token'] as String;
      final userA = a['user'] as Map<String, dynamic>;
      final userB = b['user'] as Map<String, dynamic>;
      final userAId = (userA['id'] ?? userA['_id']).toString();
      final userBId = (userB['id'] ?? userB['_id']).toString();
      _log('Prepared users: A=$userAId, B=$userBId');

      // Create services bound to each user
      const baseUrl = 'http://localhost:3010';
      final dbA = MongoDBService(baseUrl: baseUrl, authToken: tokenA);
      final dbB = MongoDBService(baseUrl: baseUrl, authToken: tokenB);

      // Private chat
      setState(() { _status = 'Creating private chat...'; });
      final privateRef = await dbA.createChat('private', 'Dual Private Test', [userAId, userBId]);
      _log('Private chat created: ${privateRef.id}');
      await dbA.sendMessage(privateRef.id, 'Private text from A');
      _log('Private text (A) sent');
      await dbB.sendMessage(privateRef.id, 'Private text from B');
      _log('Private text (B) sent');
      await dbA.sendMessage(privateRef.id, '[image] Private media A', mediaUrl: 'https://picsum.photos/420', messageType: 'image');
      _log('Private media (A) sent');
      await dbB.sendMessage(privateRef.id, '[image] Private media B', mediaUrl: 'https://picsum.photos/440', messageType: 'image');
      _log('Private media (B) sent');

      // Group chat
      setState(() { _status = 'Creating group chat...'; });
      final groupRef = await dbA.createChat('group', 'Dual Group Test', [userAId, userBId]);
      _log('Group chat created: ${groupRef.id}');
      await dbA.sendMessage(groupRef.id, 'Group text from A');
      _log('Group text (A) sent');
      await dbB.sendMessage(groupRef.id, 'Group text from B');
      _log('Group text (B) sent');
      await dbA.sendMessage(groupRef.id, '[image] Group media A', mediaUrl: 'https://picsum.photos/460', messageType: 'image');
      _log('Group media (A) sent');
      await dbB.sendMessage(groupRef.id, '[image] Group media B', mediaUrl: 'https://picsum.photos/480', messageType: 'image');
      _log('Group media (B) sent');

      setState(() { _status = 'Done'; });
      _log('RESULT: SUCCESS');
    } catch (e, st) {
      _log('Error: $e');
      _log(st.toString());
      setState(() { _status = 'Failed'; });
      _log('RESULT: FAILED');
    }
  }

  Future<Map<String, dynamic>> _ensureAccount(PhysicalAuthService auth, String email, String password, {required String name}) async {
    // Try register, fallback to login
    final reg = await auth.register(email, password, name);
    if (reg['success'] == true) {
      print('EnsureAccount: Registered $email');
      return reg;
    }
    final login = await auth.login(email, password);
    print('EnsureAccount: Login for $email success=${login['success']}');
    return login;
  }

  void _log(String msg) {
    print(msg);
    setState(() { _logs.add(msg); });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Dual-User Messaging Harness')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Status: $_status'),
            const SizedBox(height: 12),
            const Text('Logs:'),
            const SizedBox(height: 8),
            Expanded(
              child: ListView.builder(
                itemCount: _logs.length,
                itemBuilder: (_, i) => Text('• ${_logs[i]}'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}