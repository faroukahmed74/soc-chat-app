// =============================================================================
// OFFLINE STATUS WIDGET
// =============================================================================
// This widget displays the current offline status and provides controls
// for managing offline functionality.
//
// KEY FEATURES:
// - Real-time online/offline status display
// - Sync progress indicator
// - Offline data statistics
// - Manual sync trigger
// - Offline mode controls
//
// USAGE:
// - Add to app bar or main screen
// - Provides visual feedback for connectivity status
// - Allows users to manage offline functionality

import 'package:flutter/material.dart';
import 'dart:async';
import '../services/offline_service.dart';

class OfflineStatusWidget extends StatefulWidget {
  final bool showDetails;
  final VoidCallback? onSyncPressed;
  final VoidCallback? onOfflineModeToggle;

  const OfflineStatusWidget({
    Key? key,
    this.showDetails = false,
    this.onSyncPressed,
    this.onOfflineModeToggle,
  }) : super(key: key);

  @override
  State<OfflineStatusWidget> createState() => _OfflineStatusWidgetState();
}

class _OfflineStatusWidgetState extends State<OfflineStatusWidget> {
  final OfflineService _offlineService = OfflineService();
  bool _isOnline = true;
  bool _isSyncing = false;
  Map<String, dynamic> _offlineStats = {};
  Timer? _updateTimer;

  @override
  void initState() {
    super.initState();
    _initializeOfflineService();
    _startPeriodicUpdates();
  }

  @override
  void dispose() {
    _updateTimer?.cancel();
    _offlineService.removeConnectivityListener(_onConnectivityChanged);
    super.dispose();
  }

  /// Initialize the offline service
  Future<void> _initializeOfflineService() async {
    await _offlineService.initialize();
    _offlineService.addConnectivityListener(_onConnectivityChanged);
    _updateOfflineStats();
  }

  /// Start periodic updates
  void _startPeriodicUpdates() {
    _updateTimer = Timer.periodic(const Duration(seconds: 2), (timer) {
      if (mounted) {
        _updateOfflineStats();
      }
    });
  }

  /// Handle connectivity changes
  void _onConnectivityChanged(bool isOnline) {
    if (mounted) {
      setState(() {
        _isOnline = isOnline;
      });
    }
  }

  /// Update offline statistics
  void _updateOfflineStats() {
    if (_offlineService.isInitialized) {
      setState(() {
        _isOnline = _offlineService.isOnline;
        _offlineStats = _offlineService.getOfflineStats();
        _isSyncing = _offlineStats['isSyncing'] ?? false;
      });
    }
  }

  /// Handle manual sync
  void _handleManualSync() {
    if (widget.onSyncPressed != null) {
      widget.onSyncPressed!();
    } else {
      // Default sync behavior
      _showSyncDialog();
    }
  }

  /// Show sync dialog
  void _showSyncDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Manual Sync'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('This will manually trigger synchronization of offline data.'),
            const SizedBox(height: 16),
            Text('Pending items: ${_offlineStats['syncQueue'] ?? 0}'),
            Text('Offline messages: ${_offlineStats['messages'] ?? 0}'),
            Text('Cached users: ${_offlineStats['users'] ?? 0}'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              // Trigger sync (this would be implemented in the service)
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Manual sync triggered')),
              );
            },
            child: const Text('Sync Now'),
          ),
        ],
      ),
    );
  }

  /// Handle offline mode toggle
  void _handleOfflineModeToggle() {
    if (widget.onOfflineModeToggle != null) {
      widget.onOfflineModeToggle!();
    } else {
      // Default offline mode toggle behavior
      _showOfflineModeDialog();
    }
  }

  /// Show offline mode dialog
  void _showOfflineModeDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Offline Mode'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Offline mode allows you to continue using the app without internet connection.'),
            const SizedBox(height: 16),
            const Text('Features available offline:'),
            const SizedBox(height: 8),
            const Text('• Read cached messages'),
            const Text('• Compose new messages'),
            const Text('• Browse cached users'),
            const Text('• Access offline media'),
            const Text('• Use app settings'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: _isOnline ? Colors.green.shade50 : Colors.orange.shade50,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: _isOnline ? Colors.green.shade200 : Colors.orange.shade200,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Status indicator
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: _isOnline ? Colors.green : Colors.orange,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          
          // Status text
          Text(
            _isOnline ? 'Online' : 'Offline',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: _isOnline ? Colors.green.shade700 : Colors.orange.shade700,
            ),
          ),
          
          // Sync indicator
          if (_isSyncing) ...[
            const SizedBox(width: 8),
            SizedBox(
              width: 12,
              height: 12,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(
                  _isOnline ? Colors.green.shade700 : Colors.orange.shade700,
                ),
              ),
            ),
          ],
          
          // Action buttons
          if (widget.showDetails) ...[
            const SizedBox(width: 8),
            IconButton(
              onPressed: _handleManualSync,
              icon: Icon(
                Icons.sync,
                size: 16,
                color: _isOnline ? Colors.green.shade700 : Colors.orange.shade700,
              ),
              tooltip: 'Manual Sync',
            ),
            IconButton(
              onPressed: _handleOfflineModeToggle,
              icon: Icon(
                Icons.offline_bolt,
                size: 16,
                color: _isOnline ? Colors.green.shade700 : Colors.orange.shade700,
              ),
              tooltip: 'Offline Mode Info',
            ),
          ],
        ],
      ),
    );
  }
}

/// Compact offline status indicator for app bars
class CompactOfflineIndicator extends StatelessWidget {
  final bool isOnline;
  final bool isSyncing;
  final VoidCallback? onTap;

  const CompactOfflineIndicator({
    Key? key,
    required this.isOnline,
    this.isSyncing = false,
    this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 12,
        height: 12,
        decoration: BoxDecoration(
          color: isOnline ? Colors.green : Colors.orange,
          shape: BoxShape.circle,
        ),
        child: isSyncing
            ? const SizedBox(
                width: 8,
                height: 8,
                child: CircularProgressIndicator(
                  strokeWidth: 1,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            : null,
      ),
    );
  }
}

/// Offline statistics card
class OfflineStatsCard extends StatelessWidget {
  final Map<String, dynamic> stats;
  final VoidCallback? onClearData;

  const OfflineStatsCard({
    Key? key,
    required this.stats,
    this.onClearData,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Offline Storage',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (onClearData != null)
                  TextButton(
                    onPressed: onClearData,
                    child: const Text('Clear All'),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            _buildStatRow('Messages', stats['messages'] ?? 0, Icons.message),
            _buildStatRow('Users', stats['users'] ?? 0, Icons.people),
            _buildStatRow('Chats', stats['chats'] ?? 0, Icons.chat),
            _buildStatRow('Media Files', stats['media'] ?? 0, Icons.photo),
            _buildStatRow('Pending Sync', stats['syncQueue'] ?? 0, Icons.sync),
            const SizedBox(height: 16),
            Row(
              children: [
                Icon(
                  stats['isOnline'] ?? false ? Icons.wifi : Icons.wifi_off,
                  color: stats['isOnline'] ?? false ? Colors.green : Colors.orange,
                ),
                const SizedBox(width: 8),
                Text(
                  stats['isOnline'] ?? false ? 'Online' : 'Offline',
                  style: TextStyle(
                    color: stats['isOnline'] ?? false ? Colors.green : Colors.orange,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (stats['isSyncing'] ?? false) ...[
                  const SizedBox(width: 16),
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  const SizedBox(width: 8),
                  const Text('Syncing...'),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatRow(String label, int count, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Colors.grey.shade600),
          const SizedBox(width: 12),
          Text(label),
          const Spacer(),
          Text(
            count.toString(),
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }
}
