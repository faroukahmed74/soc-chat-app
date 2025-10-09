import 'package:flutter/material.dart';
import '../services/local_auth_service.dart';
import '../config/database_config.dart';

class DebugAuthScreen extends StatefulWidget {
  const DebugAuthScreen({super.key});

  @override
  State<DebugAuthScreen> createState() => _DebugAuthScreenState();
}

class _DebugAuthScreenState extends State<DebugAuthScreen> {
  String _debugInfo = 'Loading...';
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _checkAuthStatus();
  }

  Future<void> _checkAuthStatus() async {
    setState(() {
      _debugInfo = 'Checking authentication status...';
    });

    try {
      // Check if logged in
      final isLoggedIn = await LocalAuthService.isLoggedIn();
      _debugInfo += '\nIs logged in: $isLoggedIn';

      // Get token
      final token = await DatabaseConfig.getStoredAuthToken();
      _debugInfo += '\nToken length: ${token.length}';
      _debugInfo += '\nToken preview: ${token.length > 20 ? token.substring(0, 20) + "..." : token}';

      // Verify token
      if (token.isNotEmpty) {
        final isValid = await LocalAuthService.verifyToken();
        _debugInfo += '\nToken valid: $isValid';
      }

      // Get current user
      final user = await LocalAuthService.getCurrentUser();
      _debugInfo += '\nCurrent user: $user';

      setState(() {});
    } catch (e) {
      setState(() {
        _debugInfo += '\nError: $e';
      });
    }
  }

  Future<void> _testLogin() async {
    setState(() {
      _isLoading = true;
      _debugInfo = 'Testing login...';
    });

    try {
      final result = await LocalAuthService.login(
        email: 'admin@soc.com',
        password: '111111',
      );

      _debugInfo += '\nLogin result: $result';

      if (result['success']) {
        _debugInfo += '\nLogin successful!';
        // Check status again
        await _checkAuthStatus();
      } else {
        _debugInfo += '\nLogin failed: ${result['error']}';
      }
    } catch (e) {
      _debugInfo += '\nLogin error: $e';
    }

    setState(() {
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Debug Authentication'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: SingleChildScrollView(
                child: Text(
                  _debugInfo,
                  style: const TextStyle(fontFamily: 'monospace'),
                ),
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _isLoading ? null : _testLogin,
              child: _isLoading 
                ? const CircularProgressIndicator()
                : const Text('Test Login'),
            ),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: _checkAuthStatus,
              child: const Text('Refresh Status'),
            ),
          ],
        ),
      ),
    );
  }
}
