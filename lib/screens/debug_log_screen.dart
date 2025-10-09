import 'package:flutter/material.dart';
import '../services/local_auth_service.dart';
import '../config/database_config.dart';

class DebugLogScreen extends StatefulWidget {
  const DebugLogScreen({super.key});

  @override
  State<DebugLogScreen> createState() => _DebugLogScreenState();
}

class _DebugLogScreenState extends State<DebugLogScreen> {
  List<String> _logs = [];
  bool _isLoading = false;

  void _addLog(String message) {
    setState(() {
      _logs.add('${DateTime.now().toString().substring(11, 19)}: $message');
    });
  }

  @override
  void initState() {
    super.initState();
    _addLog('Debug Log Screen initialized');
    _checkAuthStatus();
  }

  Future<void> _checkAuthStatus() async {
    _addLog('=== AUTHENTICATION STATUS CHECK ===');
    
    try {
      // Check if logged in
      _addLog('Checking if user is logged in...');
      final isLoggedIn = await LocalAuthService.isLoggedIn();
      _addLog('Is logged in: $isLoggedIn');

      // Get token
      _addLog('Getting stored token...');
      final token = await DatabaseConfig.getStoredAuthToken();
      _addLog('Token length: ${token.length}');
      _addLog('Token preview: ${token.length > 20 ? token.substring(0, 20) + "..." : token}');

      // Verify token
      if (token.isNotEmpty) {
        _addLog('Verifying token with server...');
        final isValid = await LocalAuthService.verifyToken();
        _addLog('Token valid: $isValid');
      }

      // Get current user
      _addLog('Getting current user data...');
      final user = await LocalAuthService.getCurrentUser();
      _addLog('Current user: $user');

      _addLog('=== AUTHENTICATION CHECK COMPLETE ===');
    } catch (e) {
      _addLog('Error during auth check: $e');
    }
  }

  Future<void> _testLogin() async {
    setState(() {
      _isLoading = true;
    });
    _addLog('=== TESTING LOGIN ===');

    try {
      _addLog('Attempting login with admin@soc.com...');
      final result = await LocalAuthService.login(
        email: 'admin@soc.com',
        password: '111111',
      );

      _addLog('Login result: ${result['success']}');
      if (result['success']) {
        _addLog('Login successful!');
        _addLog('User data: ${result['user']}');
        _addLog('Token received: ${result['token']?.substring(0, 20) ?? 'No token'}...');
        
        // Check status again
        _addLog('Re-checking authentication status...');
        await _checkAuthStatus();
      } else {
        _addLog('Login failed: ${result['error']}');
      }
    } catch (e) {
      _addLog('Login error: $e');
    }

    setState(() {
      _isLoading = false;
    });
  }

  Future<void> _clearLogs() async {
    setState(() {
      _logs.clear();
    });
    _addLog('Logs cleared');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Debug Logs - SM-T585'),
        backgroundColor: Colors.red,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          // Control buttons
          Container(
            padding: const EdgeInsets.all(8.0),
            color: Colors.grey[100],
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton(
                  onPressed: _isLoading ? null : _testLogin,
                  child: _isLoading 
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Test Login'),
                ),
                ElevatedButton(
                  onPressed: _checkAuthStatus,
                  child: const Text('Check Auth'),
                ),
                ElevatedButton(
                  onPressed: _clearLogs,
                  child: const Text('Clear Logs'),
                ),
              ],
            ),
          ),
          // Log display
          Expanded(
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(8.0),
              color: Colors.black,
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: _logs.map((log) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2.0),
                    child: Text(
                      log,
                      style: const TextStyle(
                        color: Colors.green,
                        fontFamily: 'monospace',
                        fontSize: 12,
                      ),
                    ),
                  )).toList(),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
