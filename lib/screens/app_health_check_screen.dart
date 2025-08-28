// =============================================================================
// APP HEALTH CHECK SCREEN
// =============================================================================
// This screen provides a comprehensive view of the app's health status.
// It displays test results, allows running health checks, and shows
// detailed information about all services and functions.
//
// KEY FEATURES:
// - Run comprehensive health checks
// - View detailed test results
// - Monitor service status
// - Performance metrics
// - Error reporting and debugging
//
// ARCHITECTURE:
// - Uses AppHealthCheckService for testing
// - Real-time status updates
// - Responsive design for all screen sizes
// - Detailed result visualization
//
// PLATFORM SUPPORT:
// - Web: Full functionality with responsive design
// - Mobile: Touch-optimized interface
// - Cross-platform: Unified health check experience

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import '../services/app_health_check_service.dart';
import '../services/logger_service.dart';

class AppHealthCheckScreen extends StatefulWidget {
  const AppHealthCheckScreen({Key? key}) : super(key: key);

  @override
  State<AppHealthCheckScreen> createState() => _AppHealthCheckScreenState();
}

class _AppHealthCheckScreenState extends State<AppHealthCheckScreen> {
  final AppHealthCheckService _healthService = AppHealthCheckService();
  
  Map<String, dynamic> _healthResults = {};
  bool _isRunning = false;
  String _status = 'idle';
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadLastResults();
  }

  Future<void> _loadLastResults() async {
    final lastResults = _healthService.getLastResults();
    if (lastResults['results'].isNotEmpty) {
      setState(() {
        _healthResults = lastResults['results'];
        _status = 'completed';
      });
    }
  }

  Future<void> _runHealthCheck() async {
    setState(() {
      _isRunning = true;
      _status = 'running';
      _error = null;
    });

    try {
      final results = await _healthService.runFullHealthCheck();
      
      if (results['error'] != null) {
        setState(() {
          _error = results['error'];
          _status = 'error';
        });
      } else {
        setState(() {
          _healthResults = results['categories'] ?? {};
          _status = 'completed';
        });
      }
    } catch (e) {
      Log.e('Error running health check', 'HEALTH_CHECK_SCREEN', e);
      setState(() {
        _error = 'Failed to run health check: $e';
        _status = 'error';
      });
    } finally {
      setState(() {
        _isRunning = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 600;
    final isMediumScreen = screenWidth >= 600 && screenWidth < 1200;
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('App Health Check'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        elevation: 2,
        actions: [
          IconButton(
            onPressed: _isRunning ? null : _runHealthCheck,
            icon: _isRunning 
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.refresh),
            tooltip: 'Run Health Check',
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(isSmallScreen ? 16.0 : 24.0),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: isMediumScreen ? 800 : 1200,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Status Header
              _buildStatusHeader(),
              const SizedBox(height: 24),
              
              // Control Panel
              _buildControlPanel(),
              const SizedBox(height: 24),
              
              // Health Results
              if (_healthResults.isNotEmpty) ...[
                _buildHealthResults(),
                const SizedBox(height: 24),
              ],
              
              // Error Display
              if (_error != null) _buildErrorDisplay(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusHeader() {
    Color statusColor;
    IconData statusIcon;
    String statusText;
    
    switch (_status) {
      case 'running':
        statusColor = Colors.blue;
        statusIcon = Icons.sync;
        statusText = 'Health Check Running...';
        break;
      case 'completed':
        statusColor = Colors.green;
        statusIcon = Icons.check_circle;
        statusText = 'Health Check Completed';
        break;
      case 'error':
        statusColor = Colors.red;
        statusIcon = Icons.error;
        statusText = 'Health Check Failed';
        break;
      default:
        statusColor = Colors.grey;
        statusIcon = Icons.info;
        statusText = 'Ready to Run Health Check';
    }

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            Icon(statusIcon, size: 32, color: statusColor),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    statusText,
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: statusColor,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Comprehensive testing of all app services and functions',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildControlPanel() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.control_camera, color: Colors.blue),
                const SizedBox(width: 12),
                const Text(
                  'Control Panel',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isRunning ? null : _runHealthCheck,
                    icon: _isRunning 
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.play_arrow),
                    label: Text(_isRunning ? 'Running...' : 'Run Full Health Check'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _healthResults.isEmpty ? null : _loadLastResults,
                    icon: const Icon(Icons.history),
                    label: const Text('Load Last Results'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Text(
              'This will test all app services including Firebase, permissions, storage, notifications, and more.',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHealthResults() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.analytics, color: Colors.purple),
                const SizedBox(width: 12),
                const Text(
                  'Health Check Results',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ..._healthResults.entries.map((entry) => _buildCategoryCard(entry.key, entry.value)),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryCard(String category, Map<String, dynamic> tests) {
    final categoryName = category.replaceAll('_', ' ').split(' ').map((word) => 
      word[0].toUpperCase() + word.substring(1)
    ).join(' ');
    
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ExpansionTile(
        title: Row(
          children: [
            Icon(_getCategoryIcon(category), color: _getCategoryColor(category)),
            const SizedBox(width: 12),
            Text(
              categoryName,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const Spacer(),
            _buildCategoryStatusBadge(tests),
          ],
        ),
        children: tests.entries.map((test) => _buildTestResult(test.key, test.value)).toList(),
      ),
    );
  }

  IconData _getCategoryIcon(String category) {
    switch (category) {
      case 'firebase_services':
        return Icons.cloud;
      case 'authentication':
        return Icons.security;
      case 'permissions':
        return Icons.verified_user;
      case 'storage':
        return Icons.storage;
      case 'notifications':
        return Icons.notifications;
      case 'database':
        return Icons.storage;
      case 'app_services':
        return Icons.build;
      case 'platform_features':
        return Icons.devices;
      default:
        return Icons.info;
    }
  }

  Color _getCategoryColor(String category) {
    switch (category) {
      case 'firebase_services':
        return Colors.blue;
      case 'authentication':
        return Colors.green;
      case 'permissions':
        return Colors.orange;
      case 'storage':
        return Colors.purple;
      case 'notifications':
        return Colors.red;
      case 'database':
        return Colors.teal;
      case 'app_services':
        return Colors.indigo;
      case 'platform_features':
        return Colors.brown;
      default:
        return Colors.grey;
    }
  }

  Widget _buildCategoryStatusBadge(Map<String, dynamic> tests) {
    int totalTests = tests.length;
    int passedTests = 0;
    int failedTests = 0;
    
    tests.values.forEach((test) {
      if (test['status'] == 'success') {
        passedTests++;
      } else if (test['status'] == 'error') {
        failedTests++;
      }
    });
    
    Color badgeColor;
    String badgeText;
    
    if (failedTests > 0) {
      badgeColor = Colors.red;
      badgeText = '$failedTests failed';
    } else if (passedTests == totalTests) {
      badgeColor = Colors.green;
      badgeText = 'All passed';
    } else {
      badgeColor = Colors.orange;
      badgeText = '$passedTests/$totalTests passed';
    }
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: badgeColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        badgeText,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildTestResult(String testName, Map<String, dynamic> test) {
    final testDisplayName = testName.replaceAll('_', ' ').split(' ').map((word) => 
      word[0].toUpperCase() + word.substring(1)
    ).join(' ');
    
    Color statusColor;
    IconData statusIcon;
    
    switch (test['status']) {
      case 'success':
        statusColor = Colors.green;
        statusIcon = Icons.check_circle;
        break;
      case 'error':
        statusColor = Colors.red;
        statusIcon = Icons.error;
        break;
      case 'warning':
        statusColor = Colors.orange;
        statusIcon = Icons.warning;
        break;
      default:
        statusColor = Colors.grey;
        statusIcon = Icons.info;
    }
    
    return ListTile(
      leading: Icon(statusIcon, color: statusColor, size: 20),
      title: Text(
        testDisplayName,
        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            test['details'] ?? 'No details available',
            style: const TextStyle(fontSize: 12),
          ),
          if (test['error'] != null) ...[
            const SizedBox(height: 4),
            Text(
              'Error: ${test['error']}',
              style: const TextStyle(
                fontSize: 11,
                color: Colors.red,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
          if (test['responseTime'] != null) ...[
            const SizedBox(height: 4),
            Text(
              'Response: ${test['responseTime']}',
              style: const TextStyle(
                fontSize: 11,
                color: Colors.blue,
              ),
            ),
          ],
        ],
      ),
      dense: true,
    );
  }

  Widget _buildErrorDisplay() {
    return Card(
      elevation: 2,
      color: Colors.red[50],
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.error, color: Colors.red),
                const SizedBox(width: 12),
                const Text(
                  'Error Details',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.red,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              _error!,
              style: TextStyle(color: Colors.red[800]),
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: _runHealthCheck,
              icon: const Icon(Icons.refresh),
              label: const Text('Try Again'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
