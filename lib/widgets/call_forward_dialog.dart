import 'package:flutter/material.dart';
import '../utils/responsive_utils.dart';

/// Dialog for forwarding a call to another user
class CallForwardDialog extends StatefulWidget {
  final List<Map<String, dynamic>> availableUsers;
  final Function(String userId) onForward;

  const CallForwardDialog({
    Key? key,
    required this.availableUsers,
    required this.onForward,
  }) : super(key: key);

  @override
  State<CallForwardDialog> createState() => _CallForwardDialogState();
}

class _CallForwardDialogState extends State<CallForwardDialog> {
  String? _selectedUserId;

  @override
  Widget build(BuildContext context) {
    final isMobile = ResponsiveUtils.isMobile(context);
    final isTablet = ResponsiveUtils.isTablet(context);

    return AlertDialog(
      title: Text(
        'Forward Call',
        style: TextStyle(fontSize: isMobile ? 20 : 24),
      ),
      content: SizedBox(
        width: isMobile ? double.maxFinite : (isTablet ? 400 : 500),
        child: widget.availableUsers.isEmpty
            ? const Text('No users available to forward to')
            : ListView.builder(
                shrinkWrap: true,
                itemCount: widget.availableUsers.length,
                itemBuilder: (context, index) {
                  final user = widget.availableUsers[index];
                  final userId = user['id']?.toString() ?? user['_id']?.toString() ?? '';
                  final userName = user['name']?.toString() ?? user['email']?.toString() ?? 'Unknown';
                  final isSelected = _selectedUserId == userId;

                  return RadioListTile<String>(
                    title: Text(userName),
                    subtitle: Text(user['email']?.toString() ?? ''),
                    value: userId,
                    groupValue: _selectedUserId,
                    onChanged: (value) {
                      setState(() {
                        _selectedUserId = value;
                      });
                    },
                    selected: isSelected,
                  );
                },
              ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _selectedUserId != null
              ? () {
                  widget.onForward(_selectedUserId!);
                  Navigator.of(context).pop();
                }
              : null,
          child: const Text('Forward'),
        ),
      ],
    );
  }
}

