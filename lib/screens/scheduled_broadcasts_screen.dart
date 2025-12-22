// =============================================================================
// SCHEDULED BROADCASTS SCREEN
// =============================================================================
// This screen allows admins to schedule broadcasts with recurrence options
// and view/manage all scheduled broadcasts

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/mongodb_admin_service.dart';
import '../services/theme_service.dart';
import '../services/logger_service.dart';
import '../utils/responsive_utils.dart';

class ScheduledBroadcastsScreen extends StatefulWidget {
  const ScheduledBroadcastsScreen({Key? key}) : super(key: key);

  @override
  State<ScheduledBroadcastsScreen> createState() => _ScheduledBroadcastsScreenState();
}

class _ScheduledBroadcastsScreenState extends State<ScheduledBroadcastsScreen> {
  final MongoDBAdminService _adminService = MongoDBAdminService();
  final ThemeService _themeService = ThemeService();
  
  List<Map<String, dynamic>> _scheduledBroadcasts = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadScheduledBroadcasts();
  }

  Future<void> _loadScheduledBroadcasts() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final broadcasts = await _adminService.getScheduledBroadcasts();
      setState(() {
        _scheduledBroadcasts = broadcasts;
        _isLoading = false;
      });
    } catch (e) {
      Log.e('Error loading scheduled broadcasts', 'SCHEDULED_BROADCASTS', e);
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _cancelBroadcast(String broadcastId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel Broadcast'),
        content: const Text('Are you sure you want to cancel this scheduled broadcast?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('No'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Yes', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await _adminService.cancelScheduledBroadcast(broadcastId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Broadcast cancelled successfully')),
        );
      }
      _loadScheduledBroadcasts();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error cancelling broadcast: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = ResponsiveUtils.isMobile(context);
    final padding = ResponsiveUtils.getResponsivePadding(context);
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Scheduled Broadcasts'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _showScheduleDialog(),
            tooltip: 'Schedule Broadcast',
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadScheduledBroadcasts,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.error_outline,
                        size: ResponsiveUtils.getResponsiveValue(
                          context,
                          mobile: 48.0,
                          tablet: 56.0,
                          desktop: 64.0,
                        ),
                        color: Colors.red,
                      ),
                      SizedBox(height: ResponsiveUtils.getResponsiveSpacing(context)),
                      Text(
                        'Error loading scheduled broadcasts',
                        style: ResponsiveUtils.getResponsiveBodyStyle(context),
                      ),
                      SizedBox(height: ResponsiveUtils.getResponsiveSpacing(context) * 0.5),
                      Text(
                        _error!,
                        style: ResponsiveUtils.getResponsiveCaptionStyle(context),
                        textAlign: TextAlign.center,
                      ),
                      SizedBox(height: ResponsiveUtils.getResponsiveSpacing(context)),
                      ElevatedButton(
                        onPressed: _loadScheduledBroadcasts,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : _scheduledBroadcasts.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.schedule,
                            size: ResponsiveUtils.getResponsiveValue(
                              context,
                              mobile: 48.0,
                              tablet: 56.0,
                              desktop: 64.0,
                            ),
                            color: Colors.grey,
                          ),
                          SizedBox(height: ResponsiveUtils.getResponsiveSpacing(context)),
                          Text(
                            'No scheduled broadcasts',
                            style: ResponsiveUtils.getResponsiveBodyStyle(context),
                          ),
                          SizedBox(height: ResponsiveUtils.getResponsiveSpacing(context)),
                          ElevatedButton.icon(
                            onPressed: () => _showScheduleDialog(),
                            icon: const Icon(Icons.add),
                            label: const Text('Schedule Broadcast'),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: padding,
                      itemCount: _scheduledBroadcasts.length,
                      itemBuilder: (context, index) {
                        final broadcast = _scheduledBroadcasts[index];
                        return _buildBroadcastCard(broadcast, isMobile);
                      },
                    ),
    );
  }

  Widget _buildBroadcastCard(Map<String, dynamic> broadcast, bool isMobile) {
    final status = broadcast['status'] ?? 'scheduled';
    final scheduledAt = broadcast['scheduledAt'];
    final recurrence = broadcast['recurrence'] ?? 'none';
    
    Color statusColor;
    IconData statusIcon;
    switch (status) {
      case 'scheduled':
        statusColor = Colors.blue;
        statusIcon = Icons.schedule;
        break;
      case 'sent':
        statusColor = Colors.green;
        statusIcon = Icons.check_circle;
        break;
      case 'cancelled':
        statusColor = Colors.grey;
        statusIcon = Icons.cancel;
        break;
      case 'error':
        statusColor = Colors.red;
        statusIcon = Icons.error;
        break;
      default:
        statusColor = Colors.grey;
        statusIcon = Icons.help;
    }

    return Card(
      margin: EdgeInsets.only(
        bottom: ResponsiveUtils.getResponsiveSpacing(context) * 0.5,
      ),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: statusColor.withOpacity(0.1),
          child: Icon(statusIcon, color: statusColor, size: ResponsiveUtils.getResponsiveIconSize(context)),
        ),
        title: Text(
          broadcast['message'] ?? 'No message',
          style: ResponsiveUtils.getResponsiveBodyStyle(context),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(height: ResponsiveUtils.getResponsiveSpacing(context) * 0.25),
            Text(
              'Scheduled: ${_formatDate(scheduledAt)}',
              style: ResponsiveUtils.getResponsiveCaptionStyle(context),
            ),
            if (recurrence != 'none')
              Text(
                'Recurrence: ${recurrence.toUpperCase()}',
                style: ResponsiveUtils.getResponsiveCaptionStyle(context),
              ),
            if (broadcast['sentAt'] != null)
              Text(
                'Sent: ${_formatDate(broadcast['sentAt'])}',
                style: ResponsiveUtils.getResponsiveCaptionStyle(context),
              ),
          ],
        ),
        trailing: status == 'scheduled'
            ? IconButton(
                icon: const Icon(Icons.cancel, color: Colors.red),
                onPressed: () => _cancelBroadcast(broadcast['id']),
                tooltip: 'Cancel',
              )
            : null,
        isThreeLine: true,
        dense: isMobile,
      ),
    );
  }

  String _formatDate(dynamic date) {
    if (date == null) return 'Unknown';
    try {
      final dateTime = date is String ? DateTime.parse(date) : date as DateTime;
      return DateFormat('MMM d, yyyy HH:mm').format(dateTime);
    } catch (e) {
      return date.toString();
    }
  }

  void _showScheduleDialog() {
    final messageController = TextEditingController();
    DateTime? selectedDate;
    TimeOfDay? selectedTime;
    String selectedRecurrence = 'none';

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Schedule Broadcast'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: messageController,
                  decoration: const InputDecoration(
                    labelText: 'Message',
                    border: OutlineInputBorder(),
                    hintText: 'Enter broadcast message...',
                  ),
                  maxLines: 4,
                ),
                SizedBox(height: ResponsiveUtils.getResponsiveSpacing(context)),
                Row(
                  children: [
                    Expanded(
                      child: TextButton.icon(
                        onPressed: () async {
                          final date = await showDatePicker(
                            context: context,
                            initialDate: DateTime.now().add(const Duration(days: 1)),
                            firstDate: DateTime.now(),
                            lastDate: DateTime.now().add(const Duration(days: 365)),
                          );
                          if (date != null) {
                            setDialogState(() => selectedDate = date);
                          }
                        },
                        icon: const Icon(Icons.calendar_today),
                        label: Text(selectedDate != null
                            ? DateFormat('MMM d, yyyy').format(selectedDate!)
                            : 'Select Date'),
                      ),
                    ),
                    SizedBox(width: ResponsiveUtils.getResponsiveSpacing(context) * 0.5),
                    Expanded(
                      child: TextButton.icon(
                        onPressed: () async {
                          final time = await showTimePicker(
                            context: context,
                            initialTime: TimeOfDay.now(),
                          );
                          if (time != null) {
                            setDialogState(() => selectedTime = time);
                          }
                        },
                        icon: const Icon(Icons.access_time),
                        label: Text(selectedTime != null
                            ? selectedTime!.format(context)
                            : 'Select Time'),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: ResponsiveUtils.getResponsiveSpacing(context)),
                DropdownButtonFormField<String>(
                  value: selectedRecurrence,
                  decoration: const InputDecoration(
                    labelText: 'Recurrence',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'none', child: Text('One-time')),
                    DropdownMenuItem(value: 'daily', child: Text('Daily')),
                    DropdownMenuItem(value: 'weekly', child: Text('Weekly')),
                    DropdownMenuItem(value: 'monthly', child: Text('Monthly')),
                  ],
                  onChanged: (value) {
                    setDialogState(() => selectedRecurrence = value ?? 'none');
                  },
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
              onPressed: () async {
                if (messageController.text.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Please enter a message')),
                  );
                  return;
                }
                if (selectedDate == null || selectedTime == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Please select date and time')),
                  );
                  return;
                }

                final scheduledDateTime = DateTime(
                  selectedDate!.year,
                  selectedDate!.month,
                  selectedDate!.day,
                  selectedTime!.hour,
                  selectedTime!.minute,
                );

                try {
                  await _adminService.scheduleBroadcast(
                    message: messageController.text,
                    scheduledAt: scheduledDateTime,
                    recurrence: selectedRecurrence,
                  );
                  if (mounted) {
                    Navigator.of(context).pop();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Broadcast scheduled successfully')),
                    );
                    _loadScheduledBroadcasts();
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Error scheduling broadcast: ${e.toString()}'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                }
              },
              child: const Text('Schedule'),
            ),
          ],
        ),
      ),
    );
  }
}

