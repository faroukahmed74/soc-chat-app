import 'package:flutter/material.dart';
import '../services/call_scheduling_service.dart';
import '../services/logger_service.dart';
import '../utils/responsive_utils.dart';
import 'call_types.dart';

/// Call Scheduling Screen
/// Allows users to schedule calls for future dates
class CallSchedulingScreen extends StatefulWidget {
  final String? chatId;
  final String? chatName;
  final List<String>? participantIds;
  final CallType? defaultCallType;

  const CallSchedulingScreen({
    Key? key,
    this.chatId,
    this.chatName,
    this.participantIds,
    this.defaultCallType,
  }) : super(key: key);

  @override
  State<CallSchedulingScreen> createState() => _CallSchedulingScreenState();
}

class _CallSchedulingScreenState extends State<CallSchedulingScreen> {
  final _schedulingService = CallSchedulingService();
  final _formKey = GlobalKey<FormState>();
  
  DateTime _selectedDate = DateTime.now().add(const Duration(days: 1));
  TimeOfDay _selectedTime = TimeOfDay.now();
  CallType _callType = CallType.video;
  int _reminderMinutes = 15;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    if (widget.defaultCallType != null) {
      _callType = widget.defaultCallType!;
    }
  }

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  Future<void> _selectTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime,
    );
    if (picked != null) {
      setState(() {
        _selectedTime = picked;
      });
    }
  }

  Future<void> _scheduleCall() async {
    if (!_formKey.currentState!.validate()) return;
    if (widget.chatId == null || widget.participantIds == null || widget.participantIds!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Missing chat or participant information')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final scheduledDateTime = DateTime(
        _selectedDate.year,
        _selectedDate.month,
        _selectedDate.day,
        _selectedTime.hour,
        _selectedTime.minute,
      );

      if (scheduledDateTime.isBefore(DateTime.now())) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Scheduled time must be in the future')),
        );
        setState(() {
          _isLoading = false;
        });
        return;
      }

      final result = await _schedulingService.scheduleCall(
        chatId: widget.chatId!,
        chatName: widget.chatName ?? 'Scheduled Call',
        participantIds: widget.participantIds!,
        callType: _callType == CallType.video ? 'video' : 'voice',
        scheduledAt: scheduledDateTime,
        reminderMinutes: _reminderMinutes,
      );

      if (result != null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Call scheduled successfully')),
        );
        Navigator.of(context).pop(true);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to schedule call')),
          );
        }
      }
    } catch (e) {
      Log.e('Error scheduling call', 'CALL_SCHEDULING_SCREEN', e);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString()}')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = ResponsiveUtils.isMobile(context);
    final isTablet = ResponsiveUtils.isTablet(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Schedule Call'),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(isMobile ? 16 : 24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Chat info
              if (widget.chatName != null)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Chat:',
                          style: TextStyle(
                            fontSize: isMobile ? 12 : 14,
                            color: Colors.grey[600],
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          widget.chatName!,
                          style: TextStyle(
                            fontSize: isMobile ? 16 : 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (widget.participantIds != null)
                          Text(
                            '${widget.participantIds!.length} participants',
                            style: TextStyle(
                              fontSize: isMobile ? 12 : 14,
                              color: Colors.grey[600],
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              const SizedBox(height: 24),

              // Call type selection
              Text(
                'Call Type:',
                style: TextStyle(
                  fontSize: isMobile ? 14 : 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 8),
              SegmentedButton<CallType>(
                segments: const [
                  ButtonSegment(value: CallType.voice, label: Text('Voice')),
                  ButtonSegment(value: CallType.video, label: Text('Video')),
                ],
                selected: {_callType},
                onSelectionChanged: (Set<CallType> selected) {
                  setState(() {
                    _callType = selected.first;
                  });
                },
              ),
              const SizedBox(height: 24),

              // Date selection
              Text(
                'Date:',
                style: TextStyle(
                  fontSize: isMobile ? 14 : 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 8),
              InkWell(
                onTap: _selectDate,
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '${_selectedDate.day}/${_selectedDate.month}/${_selectedDate.year}',
                        style: const TextStyle(fontSize: 16),
                      ),
                      const Icon(Icons.calendar_today),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Time selection
              Text(
                'Time:',
                style: TextStyle(
                  fontSize: isMobile ? 14 : 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 8),
              InkWell(
                onTap: _selectTime,
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _selectedTime.format(context),
                        style: const TextStyle(fontSize: 16),
                      ),
                      const Icon(Icons.access_time),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Reminder selection
              Text(
                'Reminder (minutes before):',
                style: TextStyle(
                  fontSize: isMobile ? 14 : 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<int>(
                value: _reminderMinutes,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
                items: [5, 10, 15, 30, 60].map((minutes) {
                  return DropdownMenuItem(
                    value: minutes,
                    child: Text('$minutes minutes'),
                  );
                }).toList(),
                onChanged: (value) {
                  if (value != null) {
                    setState(() {
                      _reminderMinutes = value;
                    });
                  }
                },
              ),
              const SizedBox(height: 32),

              // Schedule button
              ElevatedButton(
                onPressed: _isLoading ? null : _scheduleCall,
                style: ElevatedButton.styleFrom(
                  padding: EdgeInsets.symmetric(
                    vertical: isMobile ? 16 : 20,
                  ),
                ),
                child: _isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(
                        'Schedule Call',
                        style: TextStyle(fontSize: isMobile ? 16 : 18),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

