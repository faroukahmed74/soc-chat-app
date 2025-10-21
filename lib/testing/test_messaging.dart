import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config/database_config.dart';
import '../services/database_service.dart';
import '../services/logger_service.dart';

void main() {
  runApp(const MaterialApp(home: MessagingTestHarness()));
}

class MessagingTestHarness extends StatefulWidget {
  const MessagingTestHarness({Key? key}) : super(key: key);

  @override
  State<MessagingTestHarness> createState() => _MessagingTestHarnessState();
}

class _MessagingTestHarnessState extends State<MessagingTestHarness> {
  String _status = 'Initializing...';
  List<String> _logs = [];
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
      // Ensure we use local API server for web
      await DatabaseConfig.initialize();
      await DatabaseConfig.setServerUrlOverride('http://localhost:3010');

      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token') ?? '';
      if (token.isEmpty) {
        _log('No auth token found. Please log in first via /login.');
        setState(() { _status = 'Blocked: not logged in'; });
        return;
      }

      // Resolve current user
      String? currentUserId;
      final userJson = prefs.getString('user_data');
      if (userJson != null) {
        final obj = json.decode(userJson);
        currentUserId = (obj['id'] ?? obj['_id'])?.toString();
      }
      if (currentUserId == null || currentUserId.isEmpty) {
        _log('Current user id not found in SharedPreferences');
        setState(() { _status = 'Blocked: no user id'; });
        return;
      }

      setState(() { _status = 'Fetching users...'; });
      final db = await DatabaseConfig.getDatabaseService();
      final users = await db.getAllUsers();
      final others = users.where((u) => u.id != currentUserId).toList();
      if (others.isEmpty) {
        _log('No other users available to test with');
        setState(() { _status = 'Blocked: no other users'; });
        return;
      }

      // Pick partner for private chat and group members
      final partner = others.first;
      final groupMembers = <String>{currentUserId!, partner.id};
      for (final u in others.skip(1)) {
        groupMembers.add(u.id);
        if (groupMembers.length >= 3) break;
      }

      // Private chat
      setState(() { _status = 'Creating private chat...'; });
      final privateChatRef = await db.createChat('private', 'E2E Private Test', [currentUserId!, partner.id]);
      _log('Private chat created: ${privateChatRef.id}');
      await db.sendMessage(privateChatRef.id, 'E2E text (private)');
      _log('Private text sent');
      await db.sendMessage(
        privateChatRef.id,
        '[image] E2E media (private)',
        mediaUrl: 'https://picsum.photos/400',
        messageType: 'image',
      );
      _log('Private media sent');

      // Group chat
      setState(() { _status = 'Creating group chat...'; });
      final groupChatRef = await db.createChat('group', 'E2E Group Test', groupMembers.toList());
      _log('Group chat created: ${groupChatRef.id}');
      await db.sendMessage(groupChatRef.id, 'E2E text (group)');
      _log('Group text sent');
      await db.sendMessage(
        groupChatRef.id,
        '[image] E2E media (group)',
        mediaUrl: 'https://picsum.photos/500',
        messageType: 'image',
      );
      _log('Group media sent');

      setState(() { _status = 'Done'; });
    } catch (e, st) {
      Log.e('Messaging test error', 'E2E', e);
      _log('Error: $e');
      _log(st.toString());
      setState(() { _status = 'Failed'; });
    }
  }

  void _log(String msg) {
    setState(() { _logs.add(msg); });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Messaging Test Harness')),
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
            Row(
              children: [
                ElevatedButton(
                  onPressed: _running ? null : _start,
                  child: const Text('Run Again'),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: () async {
                    final prefs = await SharedPreferences.getInstance();
                    await prefs.remove('auth_token');
                    await prefs.remove('user_data');
                    setState(() { _logs.add('Cleared auth token and user data'); });
                  },
                  child: const Text('Clear Auth'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}