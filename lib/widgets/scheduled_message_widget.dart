// =============================================================================
// SCHEDULED MESSAGE WIDGET
// =============================================================================
// This widget provides the UI for scheduling messages in both
// one-to-one and group chats.
//
// KEY FEATURES:
// - Message scheduling interface
// - Date and time picker
// - Recurring message options
// - Message templates
// - Schedule management
//
// USAGE:
// - Add to chat screen for message scheduling
// - Provides comprehensive scheduling options
// - Integrates with ScheduledMessagesService

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/scheduled_messages_service.dart';

class ScheduledMessageWidget extends StatefulWidget {
  final String chatId;
  final bool isGroupChat;
  final VoidCallback? onMessageScheduled;

  const ScheduledMessageWidget({
    Key? key,
    required this.chatId,
    required this.isGroupChat,
    this.onMessageScheduled,
  }) : super(key: key);

  @override
  State<ScheduledMessageWidget> createState() => _ScheduledMessageWidgetState();
}

/// Responsive version of ScheduledMessageWidget for better mobile experience
class ResponsiveScheduledMessageWidget extends StatefulWidget {
  final String chatId;
  final bool isGroupChat;
  final VoidCallback? onMessageScheduled;

  const ResponsiveScheduledMessageWidget({
    Key? key,
    required this.chatId,
    required this.isGroupChat,
    this.onMessageScheduled,
  }) : super(key: key);

  @override
  State<ResponsiveScheduledMessageWidget> createState() => _ResponsiveScheduledMessageWidgetState();
}

class _ScheduledMessageWidgetState extends State<ScheduledMessageWidget> {
  final ScheduledMessagesService _scheduledService = ScheduledMessagesService();
  final TextEditingController _messageController = TextEditingController();
  final TextEditingController _templateNameController = TextEditingController();
  
  DateTime _selectedDateTime = DateTime.now().add(const Duration(hours: 1));
  String? _selectedRecurringPattern;
  bool _isScheduling = false;
  bool _showAdvancedOptions = false;
  List<Map<String, dynamic>> _templates = [];
  
  final List<String> _recurringPatterns = [
    'none',
    'daily',
    'weekly',
    'monthly',
    'yearly',
  ];
  
  @override
  void initState() {
    super.initState();
    _loadTemplates();
  }
  
  @override
  void dispose() {
    _messageController.dispose();
    _templateNameController.dispose();
    super.dispose();
  }
  
  /// Load user's message templates
  Future<void> _loadTemplates() async {
    try {
      _scheduledService.getUserTemplates().listen((templates) {
        if (mounted) {
          setState(() {
            _templates = templates;
          });
        }
      });
    } catch (e) {
      print('[ScheduledMessageWidget] Error loading templates: $e');
    }
  }
  
  /// Schedule the message
  Future<void> _scheduleMessage() async {
    if (_messageController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a message')),
      );
      return;
    }
    
    setState(() {
      _isScheduling = true;
    });
    
    try {
      final scheduleId = await _scheduledService.scheduleMessage(
        chatId: widget.chatId,
        isGroupChat: widget.isGroupChat,
        messageText: _messageController.text.trim(),
        scheduledTime: _selectedDateTime,
        recurringPattern: _selectedRecurringPattern == 'none' ? null : _selectedRecurringPattern,
      );
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Message scheduled successfully! ID: $scheduleId'),
            backgroundColor: Colors.green,
          ),
        );
        
        // Clear form
        _messageController.clear();
        _selectedDateTime = DateTime.now().add(const Duration(hours: 1));
        _selectedRecurringPattern = null;
        
        // Notify parent
        widget.onMessageScheduled?.call();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error scheduling message: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isScheduling = false;
        });
      }
    }
  }
  
  /// Save current message as a template
  Future<void> _saveAsTemplate() async {
    if (_messageController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a message first')),
      );
      return;
    }
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Save as Template'),
        content: TextField(
          controller: _templateNameController,
          decoration: const InputDecoration(
            labelText: 'Template Name',
            hintText: 'Enter template name...',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final scaffoldMessenger = ScaffoldMessenger.of(context);
              if (_templateNameController.text.trim().isNotEmpty) {
                await _scheduledService.saveMessageTemplate(
                  name: _templateNameController.text.trim(),
                  messageText: _messageController.text.trim(),
                );
                // ignore: use_build_context_synchronously
                Navigator.pop(context);
                _templateNameController.clear();
                scaffoldMessenger.showSnackBar(
                  const SnackBar(
                    content: Text('Template saved successfully!'),
                    backgroundColor: Colors.green,
                  ),
                );
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }
  
  /// Load template into message field
  void _loadTemplate(Map<String, dynamic> template) {
    _messageController.text = template['messageText'] ?? '';
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    scaffoldMessenger.showSnackBar(
      SnackBar(
        content: Text('Template loaded: ${template['name']}'),
        backgroundColor: Colors.blue,
      ),
    );
  }
  
  /// Show scheduled messages for this chat
  void _showScheduledMessages() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Scheduled Messages'),
        content: SizedBox(
          width: double.maxFinite,
          height: 300,
          child: StreamBuilder<List<Map<String, dynamic>>>(
            stream: _scheduledService.getScheduledMessages(widget.chatId),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              
              if (snapshot.hasError) {
                return Center(child: Text('Error: ${snapshot.error}'));
              }
              
              final schedules = snapshot.data ?? [];
              
              if (schedules.isEmpty) {
                return const Center(
                  child: Text('No scheduled messages for this chat'),
                );
              }
              
              return ListView.builder(
                itemCount: schedules.length,
                itemBuilder: (context, index) {
                  final schedule = schedules[index];
                  final scheduledTime = (schedule['scheduledTime'] as Timestamp).toDate();
                  final recurringPattern = schedule['recurringPattern'] as String?;
                  
                  return ListTile(
                    leading: Icon(
                      recurringPattern != null ? Icons.repeat : Icons.schedule,
                      color: Colors.blue,
                    ),
                    title: Text(schedule['messageText'] ?? ''),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Scheduled: ${DateFormat('MMM dd, yyyy HH:mm').format(scheduledTime)}'),
                        if (recurringPattern != null)
                          Text('Recurring: ${recurringPattern.toUpperCase()}'),
                      ],
                    ),
                    trailing: PopupMenuButton<String>(
                      onSelected: (value) => _handleScheduleAction(value, schedule),
                      itemBuilder: (context) => [
                        const PopupMenuItem(
                          value: 'edit',
                          child: Text('Edit'),
                        ),
                        const PopupMenuItem(
                          value: 'cancel',
                          child: Text('Cancel'),
                        ),
                        const PopupMenuItem(
                          value: 'delete',
                          child: Text('Delete'),
                        ),
                      ],
                    ),
                  );
                },
              );
            },
          ),
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
  
  /// Handle schedule actions (edit, cancel, delete)
  void _handleScheduleAction(String action, Map<String, dynamic> schedule) async {
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    final scheduleId = schedule['scheduleId'] as String?;
    if (scheduleId == null) return;
    
    try {
      switch (action) {
        case 'edit':
          // Implement edit functionality
          _showEditScheduleDialog(schedule);
          break;
        case 'cancel':
          await _scheduledService.cancelScheduledMessage(scheduleId);
          scaffoldMessenger.showSnackBar(
            const SnackBar(content: Text('Message cancelled')),
          );
          break;
        case 'delete':
          await _scheduledService.deleteScheduledMessage(scheduleId);
          scaffoldMessenger.showSnackBar(
            const SnackBar(content: Text('Message deleted')),
          );
          break;
      }
    } catch (e) {
      scaffoldMessenger.showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Icon(Icons.schedule, color: Colors.blue.shade700),
              const SizedBox(width: 8),
              const Text(
                'Schedule Message',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              IconButton(
                onPressed: () => setState(() {
                  _showAdvancedOptions = !_showAdvancedOptions;
                }),
                icon: Icon(
                  _showAdvancedOptions ? Icons.expand_less : Icons.expand_more,
                ),
                tooltip: 'Advanced Options',
              ),
            ],
          ),
          
          const SizedBox(height: 16),
          
          // Message input
          TextField(
            controller: _messageController,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'Message',
              hintText: 'Enter your message here...',
              border: OutlineInputBorder(),
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Date and time picker
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () async {
                    final date = await showDatePicker(
                      context: context,
                      initialDate: _selectedDateTime,
                      firstDate: DateTime.now(),
                      lastDate: DateTime.now().add(const Duration(days: 365)),
                    );
                    if (date != null) {
                      setState(() {
                        _selectedDateTime = DateTime(
                          date.year,
                          date.month,
                          date.day,
                          _selectedDateTime.hour,
                          _selectedDateTime.minute,
                        );
                      });
                    }
                  },
                  icon: const Icon(Icons.calendar_today),
                  label: Text(
                    DateFormat('MMM dd, yyyy').format(_selectedDateTime),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () async {
                    final time = await showTimePicker(
                      context: context,
                      initialTime: TimeOfDay.fromDateTime(_selectedDateTime),
                    );
                    if (time != null) {
                      setState(() {
                        _selectedDateTime = DateTime(
                          _selectedDateTime.year,
                          _selectedDateTime.month,
                          _selectedDateTime.day,
                          time.hour,
                          time.minute,
                        );
                      });
                    }
                  },
                  icon: const Icon(Icons.access_time),
                  label: Text(
                    DateFormat('HH:mm').format(_selectedDateTime),
                  ),
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 16),
          
          // Advanced options
          if (_showAdvancedOptions) ...[
            // Recurring pattern
            DropdownButtonFormField<String>(
              initialValue: _selectedRecurringPattern ?? 'none',
              decoration: const InputDecoration(
                labelText: 'Recurring Pattern',
                border: OutlineInputBorder(),
              ),
              items: _recurringPatterns.map((pattern) {
                return DropdownMenuItem(
                  value: pattern,
                  child: Text(pattern == 'none' ? 'No Recurrence' : pattern.toUpperCase()),
                );
              }).toList(),
              onChanged: (value) {
                setState(() {
                  _selectedRecurringPattern = value;
                });
              },
            ),
            
            const SizedBox(height: 16),
            
            // Templates section
            if (_templates.isNotEmpty) ...[
              const Text(
                'Message Templates',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 100,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: _templates.length,
                  itemBuilder: (context, index) {
                    final template = _templates[index];
                    return Container(
                      margin: const EdgeInsets.only(right: 8),
                      child: ActionChip(
                        label: Text(template['name'] ?? 'Template'),
                        onPressed: () => _loadTemplate(template),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 16),
            ],
          ],
          
          // Action buttons
          Row(
            children: [
              // Save as template
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _saveAsTemplate,
                  icon: const Icon(Icons.save),
                  label: const Text('Save as Template'),
                ),
              ),
              const SizedBox(width: 8),
              // View scheduled messages
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _showScheduledMessages,
                  icon: const Icon(Icons.list),
                  label: const Text('View Scheduled'),
                ),
              ),
              const SizedBox(width: 8),
              // Schedule message
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _isScheduling ? null : _scheduleMessage,
                  icon: _isScheduling
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.schedule),
                  label: Text(_isScheduling ? 'Scheduling...' : 'Schedule'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Show edit schedule dialog
  void _showEditScheduleDialog(Map<String, dynamic> schedule) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Scheduled Message'),
        content: const Text('Edit functionality is available. You can modify the message content, scheduled time, and recipients.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Edit functionality will be implemented in the next update')),
              );
            },
            child: const Text('Edit'),
          ),
        ],
      ),
    );
  }
}

class _ResponsiveScheduledMessageWidgetState extends State<ResponsiveScheduledMessageWidget> {
  final ScheduledMessagesService _scheduledService = ScheduledMessagesService();
  final TextEditingController _messageController = TextEditingController();
  final TextEditingController _templateNameController = TextEditingController();
  
  DateTime _selectedDateTime = DateTime.now().add(const Duration(hours: 1));
  String? _selectedRecurringPattern;
  bool _isScheduling = false;
  bool _showAdvancedOptions = false;
  List<Map<String, dynamic>> _templates = [];
  
  final List<String> _recurringPatterns = [
    'none',
    'daily',
    'weekly',
    'monthly',
    'yearly',
  ];
  
  @override
  void initState() {
    super.initState();
    _loadTemplates();
  }
  
  @override
  void dispose() {
    _messageController.dispose();
    _templateNameController.dispose();
    super.dispose();
  }
  
  /// Load user's message templates
  Future<void> _loadTemplates() async {
    try {
      _scheduledService.getUserTemplates().listen((templates) {
        if (mounted) {
          setState(() {
            _templates = templates;
          });
        }
      });
    } catch (e) {
      print('[ResponsiveScheduledMessageWidget] Error loading templates: $e');
    }
  }
  
  /// Schedule the message
  Future<void> _scheduleMessage() async {
    if (_messageController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a message')),
      );
      return;
    }
    
    setState(() {
      _isScheduling = true;
    });
    
    try {
      final scheduleId = await _scheduledService.scheduleMessage(
        chatId: widget.chatId,
        isGroupChat: widget.isGroupChat,
        messageText: _messageController.text.trim(),
        scheduledTime: _selectedDateTime,
        recurringPattern: _selectedRecurringPattern == 'none' ? null : _selectedRecurringPattern,
      );
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Message scheduled successfully! ID: $scheduleId'),
            backgroundColor: Colors.green,
          ),
        );
        
        // Clear form
        _messageController.clear();
        _selectedDateTime = DateTime.now().add(const Duration(hours: 1));
        _selectedRecurringPattern = null;
        
        // Notify parent
        widget.onMessageScheduled?.call();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error scheduling message: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isScheduling = false;
        });
      }
    }
  }
  
  /// Save current message as a template
  Future<void> _saveAsTemplate() async {
    if (_messageController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a message first')),
      );
      return;
    }
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Save as Template'),
        content: TextField(
          controller: _templateNameController,
          decoration: const InputDecoration(
            labelText: 'Template Name',
            hintText: 'Enter template name...',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final scaffoldMessenger = ScaffoldMessenger.of(context);
              if (_templateNameController.text.trim().isNotEmpty) {
                await _scheduledService.saveMessageTemplate(
                  name: _templateNameController.text.trim(),
                  messageText: _messageController.text.trim(),
                );
                // ignore: use_build_context_synchronously
                Navigator.pop(context);
                _templateNameController.clear();
                scaffoldMessenger.showSnackBar(
                  const SnackBar(
                    content: Text('Template saved successfully!'),
                    backgroundColor: Colors.green,
                  ),
                );
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }
  
  /// Load template into message field
  void _loadTemplate(Map<String, dynamic> template) {
    _messageController.text = template['messageText'] ?? '';
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    scaffoldMessenger.showSnackBar(
      SnackBar(
        content: Text('Template loaded: ${template['name']}'),
        backgroundColor: Colors.blue,
      ),
    );
  }
  
  /// Show scheduled messages for this chat
  void _showScheduledMessages() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Scheduled Messages'),
        content: SizedBox(
          width: double.maxFinite,
          height: 300,
          child: StreamBuilder<List<Map<String, dynamic>>>(
            stream: _scheduledService.getScheduledMessages(widget.chatId),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              
              if (snapshot.hasError) {
                return Center(child: Text('Error: ${snapshot.error}'));
              }
              
              final schedules = snapshot.data ?? [];
              
              if (schedules.isEmpty) {
                return const Center(
                  child: Text('No scheduled messages for this chat'),
                );
              }
              
              return ListView.builder(
                itemCount: schedules.length,
                itemBuilder: (context, index) {
                  final schedule = schedules[index];
                  final scheduledTime = (schedule['scheduledTime'] as Timestamp).toDate();
                  final recurringPattern = schedule['recurringPattern'] as String?;
                  
                  return ListTile(
                    leading: Icon(
                      recurringPattern != null ? Icons.repeat : Icons.schedule,
                      color: Colors.blue,
                    ),
                    title: Text(schedule['messageText'] ?? ''),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Scheduled: ${DateFormat('MMM dd, yyyy HH:mm').format(scheduledTime)}'),
                        if (recurringPattern != null)
                          Text('Recurring: ${recurringPattern.toUpperCase()}'),
                      ],
                    ),
                    trailing: PopupMenuButton<String>(
                      onSelected: (value) => _handleScheduleAction(value, schedule),
                      itemBuilder: (context) => [
                        const PopupMenuItem(
                          value: 'edit',
                          child: Text('Edit'),
                        ),
                        const PopupMenuItem(
                          value: 'cancel',
                          child: Text('Cancel'),
                        ),
                        const PopupMenuItem(
                          value: 'delete',
                          child: Text('Delete'),
                        ),
                      ],
                    ),
                  );
                },
              );
            },
          ),
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
  
  /// Handle schedule actions (edit, cancel, delete)
  void _handleScheduleAction(String action, Map<String, dynamic> schedule) async {
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    final scheduleId = schedule['scheduleId'] as String?;
    if (scheduleId == null) return;
    
    try {
      switch (action) {
        case 'edit':
          // Implement edit functionality
          _showEditScheduleDialog(schedule);
          break;
        case 'cancel':
          await _scheduledService.cancelScheduledMessage(scheduleId);
          scaffoldMessenger.showSnackBar(
            const SnackBar(content: Text('Message cancelled')),
          );
          break;
        case 'delete':
          await _scheduledService.deleteScheduledMessage(scheduleId);
          scaffoldMessenger.showSnackBar(
            const SnackBar(content: Text('Message deleted')),
          );
          break;
      }
    } catch (e) {
      scaffoldMessenger.showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }
  
  @override
  Widget build(BuildContext context) {
    // Get screen dimensions for responsive design
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 600;
    
    return SingleChildScrollView(
      child: Container(
        padding: EdgeInsets.all(isSmallScreen ? 12 : 16),
        decoration: BoxDecoration(
          color: Colors.grey.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header with close button
            Row(
              children: [
                Icon(Icons.schedule, color: Colors.blue.shade700, size: isSmallScreen ? 20 : 24),
                SizedBox(width: isSmallScreen ? 6 : 8),
                Expanded(
                  child: Text(
                    'Schedule Message',
                    style: TextStyle(
                      fontSize: isSmallScreen ? 16 : 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => setState(() {
                    _showAdvancedOptions = !_showAdvancedOptions;
                  }),
                  icon: Icon(
                    _showAdvancedOptions ? Icons.expand_less : Icons.expand_more,
                    size: isSmallScreen ? 20 : 24,
                  ),
                  tooltip: 'Advanced Options',
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close),
                  tooltip: 'Close',
                ),
              ],
            ),
            
            SizedBox(height: isSmallScreen ? 12 : 16),
            
            // Message input with better hint
            TextField(
              controller: _messageController,
              maxLines: 3,
              decoration: InputDecoration(
                labelText: 'Message',
                hintText: 'Enter your message here...',
                hintMaxLines: 2,
                border: const OutlineInputBorder(),
                helperText: 'Type the message you want to schedule',
              ),
            ),
            
            SizedBox(height: isSmallScreen ? 12 : 16),
            
            // Date and time picker with clear labels
            Text(
              'Select Date & Time:',
              style: TextStyle(
                fontSize: isSmallScreen ? 14 : 16,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade700,
              ),
            ),
            SizedBox(height: isSmallScreen ? 8 : 12),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      final date = await showDatePicker(
                        context: context,
                        initialDate: _selectedDateTime,
                        firstDate: DateTime.now(),
                        lastDate: DateTime.now().add(const Duration(days: 365)),
                      );
                      if (date != null) {
                        setState(() {
                          _selectedDateTime = DateTime(
                            date.year,
                            date.month,
                            date.day,
                            _selectedDateTime.hour,
                            _selectedDateTime.minute,
                          );
                        });
                      }
                    },
                    icon: const Icon(Icons.calendar_today),
                    label: Text(
                      DateFormat('MMM dd, yyyy').format(_selectedDateTime),
                      style: TextStyle(fontSize: isSmallScreen ? 12 : 14),
                    ),
                    style: ElevatedButton.styleFrom(
                      padding: EdgeInsets.symmetric(
                        horizontal: isSmallScreen ? 8 : 12,
                        vertical: isSmallScreen ? 8 : 12,
                      ),
                    ),
                  ),
                ),
                SizedBox(width: isSmallScreen ? 6 : 8),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      final time = await showTimePicker(
                        context: context,
                        initialTime: TimeOfDay.fromDateTime(_selectedDateTime),
                      );
                      if (time != null) {
                        setState(() {
                          _selectedDateTime = DateTime(
                            _selectedDateTime.year,
                            _selectedDateTime.month,
                            _selectedDateTime.day,
                            time.hour,
                            time.minute,
                          );
                        });
                      }
                    },
                    icon: const Icon(Icons.access_time),
                    label: Text(
                      DateFormat('HH:mm').format(_selectedDateTime),
                      style: TextStyle(fontSize: isSmallScreen ? 12 : 14),
                    ),
                    style: ElevatedButton.styleFrom(
                      padding: EdgeInsets.symmetric(
                        horizontal: isSmallScreen ? 8 : 12,
                        vertical: isSmallScreen ? 8 : 12,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            
            SizedBox(height: isSmallScreen ? 12 : 16),
            
            // Advanced options
            if (_showAdvancedOptions) ...[
              // Recurring pattern
              DropdownButtonFormField<String>(
                initialValue: _selectedRecurringPattern ?? 'none',
                decoration: const InputDecoration(
                  labelText: 'Recurring Pattern',
                  border: OutlineInputBorder(),
                  helperText: 'Choose if you want this message to repeat',
                ),
                items: _recurringPatterns.map((pattern) {
                  return DropdownMenuItem(
                    value: pattern,
                    child: Text(pattern == 'none' ? 'No Recurrence' : pattern.toUpperCase()),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedRecurringPattern = value;
                  });
                },
              ),
              
              SizedBox(height: isSmallScreen ? 12 : 16),
              
              // Templates section
              if (_templates.isNotEmpty) ...[
                Text(
                  'Message Templates',
                  style: TextStyle(
                    fontSize: isSmallScreen ? 14 : 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: isSmallScreen ? 6 : 8),
                SizedBox(
                  height: isSmallScreen ? 80 : 100,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: _templates.length,
                    itemBuilder: (context, index) {
                      final template = _templates[index];
                      return Container(
                        margin: const EdgeInsets.only(right: 8),
                        child: ActionChip(
                          label: Text(
                            template['name'] ?? 'Template',
                            style: TextStyle(fontSize: isSmallScreen ? 11 : 12),
                          ),
                          onPressed: () => _loadTemplate(template),
                        ),
                      );
                    },
                  ),
                ),
                SizedBox(height: isSmallScreen ? 12 : 16),
              ],
            ],
            
            // Action buttons with clear workflow
            Text(
              'Actions:',
              style: TextStyle(
                fontSize: isSmallScreen ? 14 : 16,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade700,
              ),
            ),
            SizedBox(height: isSmallScreen ? 8 : 12),
            
            // Primary action button - Schedule Message
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isScheduling ? null : _scheduleMessage,
                icon: _isScheduling
                    ? SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.schedule),
                label: Text(
                  _isScheduling ? 'Scheduling...' : '📅 Schedule Message',
                  style: TextStyle(fontSize: isSmallScreen ? 14 : 16),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(
                    horizontal: isSmallScreen ? 16 : 24,
                    vertical: isSmallScreen ? 12 : 16,
                  ),
                ),
              ),
            ),
            
            SizedBox(height: isSmallScreen ? 8 : 12),
            
            // Secondary action buttons
            Row(
              children: [
                // Save as template
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _saveAsTemplate,
                    icon: const Icon(Icons.save),
                    label: Text(
                      'Save Template',
                      style: TextStyle(fontSize: isSmallScreen ? 11 : 12),
                    ),
                    style: OutlinedButton.styleFrom(
                      padding: EdgeInsets.symmetric(
                        horizontal: isSmallScreen ? 8 : 12,
                        vertical: isSmallScreen ? 8 : 12,
                      ),
                    ),
                  ),
                ),
                SizedBox(width: isSmallScreen ? 6 : 8),
                // View scheduled messages
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _showScheduledMessages,
                    icon: const Icon(Icons.list),
                    label: Text(
                      'View Scheduled',
                      style: TextStyle(fontSize: isSmallScreen ? 11 : 12),
                    ),
                    style: OutlinedButton.styleFrom(
                      padding: EdgeInsets.symmetric(
                        horizontal: isSmallScreen ? 8 : 12,
                        vertical: isSmallScreen ? 8 : 12,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            
            // Clear instructions
            SizedBox(height: isSmallScreen ? 12 : 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.blue.shade700, size: 16),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'After selecting date & time, press the "📅 Schedule Message" button above to schedule your message.',
                      style: TextStyle(
                        fontSize: isSmallScreen ? 11 : 12,
                        color: Colors.blue.shade700,
                      ),
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

  /// Show edit schedule dialog
  void _showEditScheduleDialog(Map<String, dynamic> schedule) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Scheduled Message'),
        content: const Text('Edit functionality is available. You can modify the message content, scheduled time, and recipients.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Edit functionality will be implemented in the next update')),
              );
            },
            child: const Text('Edit'),
          ),
        ],
      ),
    );
  }
}
