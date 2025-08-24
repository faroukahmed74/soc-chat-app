import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import '../services/version_check_service.dart';

class VersionDisplayWidget extends StatefulWidget {
  final bool showUpdateButton;
  final VoidCallback? onUpdateCheck;

  const VersionDisplayWidget({
    super.key,
    this.showUpdateButton = true,
    this.onUpdateCheck,
  });

  @override
  State<VersionDisplayWidget> createState() => _VersionDisplayWidgetState();
}

class _VersionDisplayWidgetState extends State<VersionDisplayWidget> {
  String _currentVersion = '';
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadVersionInfo();
  }

  Future<void> _loadVersionInfo() async {
    try {
      final version = await VersionCheckService.getCurrentVersion();
      final appName = await VersionCheckService.getAppName();
      setState(() {
        _currentVersion = '$appName v$version';
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _currentVersion = 'SOC Chat App v1.0.0';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Only show on Android
    if (!kIsWeb && defaultTargetPlatform != TargetPlatform.android) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          if (_isLoading)
            const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          else
            Text(
              _currentVersion,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w500,
              ),
            ),
          if (widget.showUpdateButton)
            TextButton.icon(
              onPressed: widget.onUpdateCheck,
              icon: const Icon(Icons.system_update, size: 16),
              label: const Text('Check Update'),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
        ],
      ),
    );
  }
}
