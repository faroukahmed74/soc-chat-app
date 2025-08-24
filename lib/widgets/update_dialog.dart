import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import '../services/version_check_service.dart';

class UpdateDialog extends StatelessWidget {
  final Map<String, dynamic> updateInfo;
  final VoidCallback? onDismiss;

  const UpdateDialog({
    super.key,
    required this.updateInfo,
    this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    // Only show on Android
    if (!kIsWeb && defaultTargetPlatform != TargetPlatform.android) {
      return const SizedBox.shrink();
    }

    return AlertDialog(
      title: Row(
        children: [
          Icon(
            Icons.system_update,
            color: Theme.of(context).primaryColor,
            size: 28,
          ),
          const SizedBox(width: 12),
          const Text('Update Available'),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'A new version of ${updateInfo['appName'] ?? 'SOC Chat App'} is available!',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 16),
          _buildVersionInfo(updateInfo),
          const SizedBox(height: 16),
          if (updateInfo['releaseNotes'] != null) ...[
            const Text(
              'What\'s New:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              updateInfo['releaseNotes'],
              style: const TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 16),
          ],
          if (updateInfo['forceUpdate'] == true)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.shade100,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange.shade300),
              ),
              child: Row(
                children: [
                  Icon(Icons.warning, color: Colors.orange.shade700),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'This update is required to continue using the app.',
                      style: TextStyle(
                        color: Colors.orange.shade700,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
      actions: [
        if (updateInfo['forceUpdate'] != true)
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              onDismiss?.call();
            },
            child: const Text('Later'),
          ),
        ElevatedButton.icon(
          onPressed: () => _downloadUpdate(context),
          icon: const Icon(Icons.download),
          label: const Text('Download Update'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Theme.of(context).primaryColor,
            foregroundColor: Colors.white,
          ),
        ),
      ],
    );
  }

  Widget _buildVersionInfo(Map<String, dynamic> updateInfo) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Current Version:'),
              Text(
                '${updateInfo['currentVersion']} (${updateInfo['currentBuildNumber']})',
                style: const TextStyle(fontWeight: FontWeight.w500),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Latest Version:'),
              Text(
                '${updateInfo['latestVersion']} (${updateInfo['latestBuildNumber']})',
                style: const TextStyle(
                  fontWeight: FontWeight.w500,
                  color: Colors.green,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _downloadUpdate(BuildContext context) async {
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    Navigator.of(context).pop();
    
    final bool success = await VersionCheckService.downloadAndInstallUpdate(
      updateInfo['downloadUrl'],
      context,
    );
    
    if (success) {
      scaffoldMessenger.showSnackBar(
        const SnackBar(
          content: Text('Update downloaded successfully!'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }
}
