import 'package:flutter/material.dart';
import '../utils/responsive_utils.dart';

/// Dialog for transferring a call to another user
class CallTransferDialog extends StatefulWidget {
  final List<Map<String, dynamic>> availableUsers;
  final Function(String userId, String transferType) onTransfer;

  const CallTransferDialog({
    Key? key,
    required this.availableUsers,
    required this.onTransfer,
  }) : super(key: key);

  @override
  State<CallTransferDialog> createState() => _CallTransferDialogState();
}

class _CallTransferDialogState extends State<CallTransferDialog> {
  String? _selectedUserId;
  String _transferType = 'blind'; // 'blind' or 'attended'

  @override
  Widget build(BuildContext context) {
    final isMobile = ResponsiveUtils.isMobile(context);
    final isTablet = ResponsiveUtils.isTablet(context);

    return AlertDialog(
      title: Text(
        'Transfer Call',
        style: TextStyle(fontSize: isMobile ? 20 : 24),
      ),
      content: SizedBox(
        width: isMobile ? double.maxFinite : (isTablet ? 400 : 500),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Transfer type selection
            Text(
              'Transfer Type:',
              style: TextStyle(
                fontSize: isMobile ? 14 : 16,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            RadioListTile<String>(
              title: const Text('Blind Transfer'),
              subtitle: const Text('Transfer immediately without confirmation'),
              value: 'blind',
              groupValue: _transferType,
              onChanged: (value) {
                setState(() {
                  _transferType = value!;
                });
              },
            ),
            RadioListTile<String>(
              title: const Text('Attended Transfer'),
              subtitle: const Text('Wait for recipient to answer before transferring'),
              value: 'attended',
              groupValue: _transferType,
              onChanged: (value) {
                setState(() {
                  _transferType = value!;
                });
              },
            ),
            const Divider(),
            const SizedBox(height: 8),
            // User selection
            Text(
              'Transfer To:',
              style: TextStyle(
                fontSize: isMobile ? 14 : 16,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            if (widget.availableUsers.isEmpty)
              const Text('No users available to transfer to')
            else
              SizedBox(
                height: 200,
                child: ListView.builder(
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
          ],
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
                  widget.onTransfer(_selectedUserId!, _transferType);
                  Navigator.of(context).pop();
                }
              : null,
          child: const Text('Transfer'),
        ),
      ],
    );
  }
}

