// =============================================================================
// MODERATION CENTER SCREEN
// =============================================================================
// This screen provides comprehensive content moderation tools including:
// - Moderation rules management
// - Keyword filtering
// - Moderation queue (flagged messages)
// - User violation history
// - Moderation actions (warn, mute, ban)

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/mongodb_admin_service.dart';
import '../services/theme_service.dart';
import '../services/logger_service.dart';

class ModerationCenterScreen extends StatefulWidget {
  const ModerationCenterScreen({Key? key}) : super(key: key);

  @override
  State<ModerationCenterScreen> createState() => _ModerationCenterScreenState();
}

class _ModerationCenterScreenState extends State<ModerationCenterScreen> with SingleTickerProviderStateMixin {
  final MongoDBAdminService _adminService = MongoDBAdminService();
  final ThemeService _themeService = ThemeService();
  late TabController _tabController;
  
  // Rules
  List<Map<String, dynamic>> _rules = [];
  bool _isLoadingRules = false;
  
  // Queue
  List<Map<String, dynamic>> _queue = [];
  bool _isLoadingQueue = false;
  String _queueStatus = 'pending';
  int _queueTotal = 0;
  int _queueSkip = 0;
  final int _queueLimit = 20;
  
  // Selected items for bulk actions
  Set<String> _selectedQueueItems = {};
  
  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadRules();
    _loadQueue();
  }
  
  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }
  
  Future<void> _loadRules() async {
    setState(() => _isLoadingRules = true);
    try {
      final rules = await _adminService.getModerationRules();
      setState(() {
        _rules = rules;
        _isLoadingRules = false;
      });
    } catch (e) {
      Log.e('Error loading moderation rules', 'MODERATION_CENTER', e);
      setState(() => _isLoadingRules = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load rules: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
  
  Future<void> _loadQueue() async {
    setState(() => _isLoadingQueue = true);
    try {
      final data = await _adminService.getModerationQueue(
        status: _queueStatus,
        limit: _queueLimit,
        skip: _queueSkip,
      );
      setState(() {
        _queue = List<Map<String, dynamic>>.from(data['queue'] ?? []);
        _queueTotal = data['total'] ?? 0;
        _isLoadingQueue = false;
      });
    } catch (e) {
      Log.e('Error loading moderation queue', 'MODERATION_CENTER', e);
      setState(() => _isLoadingQueue = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load queue: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
  
  @override
  Widget build(BuildContext context) {
    final isMobile = ResponsiveUtils.isMobile(context);
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Moderation Center'),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: isMobile,
          tabs: [
            if (isMobile)
              const Tab(icon: Icon(Icons.rule))
            else
              const Tab(icon: Icon(Icons.rule), text: 'Rules'),
            if (isMobile)
              const Tab(icon: Icon(Icons.queue))
            else
              const Tab(icon: Icon(Icons.queue), text: 'Queue'),
            if (isMobile)
              const Tab(icon: Icon(Icons.history))
            else
              const Tab(icon: Icon(Icons.history), text: 'History'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildRulesTab(),
          _buildQueueTab(),
          _buildHistoryTab(),
        ],
      ),
    );
  }
  
  // =============================================================================
  // RULES TAB
  // =============================================================================
  
  Widget _buildRulesTab() {
    final padding = ResponsiveUtils.getResponsivePadding(context);
    final isMobile = ResponsiveUtils.isMobile(context);
    
    return Column(
      children: [
        Padding(
          padding: padding,
          child: isMobile
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Moderation Rules',
                      style: ResponsiveUtils.getResponsiveHeadingStyle(
                        context,
                        color: _themeService.isDarkMode ? Colors.white : Colors.black87,
                      ),
                    ),
                    SizedBox(height: ResponsiveUtils.getResponsiveSpacing(context)),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _showCreateRuleDialog,
                        icon: const Icon(Icons.add),
                        label: const Text('Create Rule'),
                      ),
                    ),
                  ],
                )
              : Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Moderation Rules',
                        style: ResponsiveUtils.getResponsiveHeadingStyle(
                          context,
                          color: _themeService.isDarkMode ? Colors.white : Colors.black87,
                        ),
                      ),
                    ),
                    ElevatedButton.icon(
                      onPressed: _showCreateRuleDialog,
                      icon: const Icon(Icons.add),
                      label: const Text('Create Rule'),
                    ),
                  ],
                ),
        ),
        if (_isLoadingRules)
          const Expanded(child: Center(child: CircularProgressIndicator()))
        else if (_rules.isEmpty)
          Expanded(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.rule_outlined, size: 64, color: Colors.grey),
                  const SizedBox(height: 16),
                  const Text('No moderation rules configured'),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: _showCreateRuleDialog,
                    icon: const Icon(Icons.add),
                    label: const Text('Create First Rule'),
                  ),
                ],
              ),
            ),
          )
        else
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final maxWidth = ResponsiveUtils.getResponsiveValue(
                  context,
                  mobile: double.infinity,
                  tablet: 800.0,
                  desktop: 1000.0,
                );
                
                return Center(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: maxWidth),
                    child: ListView.builder(
                      padding: ResponsiveUtils.getResponsiveHorizontalPadding(context),
                      itemCount: _rules.length,
                      itemBuilder: (context, index) {
                        final rule = _rules[index];
                        return _buildRuleCard(rule);
                      },
                    ),
                  ),
                );
              },
            ),
          ),
      ],
    );
  }
  
  Widget _buildRuleCard(Map<String, dynamic> rule) {
    final ruleId = rule['_id']?.toString() ?? '';
    final name = rule['name'] ?? 'Unnamed Rule';
    final type = rule['type'] ?? 'keyword';
    final action = rule['action'] ?? 'flag';
    final enabled = rule['enabled'] ?? true;
    final severity = rule['severity'] ?? 'medium';
    final keywords = List<String>.from(rule['keywords'] ?? []);
    
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: Icon(
          enabled ? Icons.check_circle : Icons.cancel,
          color: enabled ? Colors.green : Colors.grey,
        ),
        title: Text(name),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Type: $type | Action: $action | Severity: $severity'),
            if (keywords.isNotEmpty)
              Text('Keywords: ${keywords.take(3).join(', ')}${keywords.length > 3 ? '...' : ''}'),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Switch(
              value: enabled,
              onChanged: (value) => _toggleRule(ruleId, value),
            ),
            PopupMenuButton<String>(
              onSelected: (value) {
                if (value == 'edit') {
                  _showEditRuleDialog(rule);
                } else if (value == 'delete') {
                  _deleteRule(ruleId);
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'edit',
                  child: Row(
                    children: [
                      Icon(Icons.edit, size: 20),
                      SizedBox(width: 8),
                      Text('Edit'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'delete',
                  child: Row(
                    children: [
                      Icon(Icons.delete, color: Colors.red, size: 20),
                      SizedBox(width: 8),
                      Text('Delete', style: TextStyle(color: Colors.red)),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
  
  void _showCreateRuleDialog() {
    _showRuleDialog();
  }
  
  void _showEditRuleDialog(Map<String, dynamic> rule) {
    _showRuleDialog(rule: rule);
  }
  
  void _showRuleDialog({Map<String, dynamic>? rule}) {
    final isEdit = rule != null;
    final nameController = TextEditingController(text: rule?['name'] ?? '');
    final keywordsController = TextEditingController(
      text: (rule?['keywords'] as List<dynamic>?)?.join(', ') ?? '',
    );
    String? selectedType = rule?['type'] ?? 'keyword';
    String? selectedAction = rule?['action'] ?? 'flag';
    String? selectedSeverity = rule?['severity'] ?? 'medium';
    bool enabled = rule?['enabled'] ?? true;
    
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(isEdit ? 'Edit Rule' : 'Create Rule'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'Rule Name',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: selectedType,
                  decoration: const InputDecoration(
                    labelText: 'Type',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'keyword', child: Text('Keyword')),
                    DropdownMenuItem(value: 'profanity', child: Text('Profanity')),
                    DropdownMenuItem(value: 'spam', child: Text('Spam')),
                  ],
                  onChanged: (value) => setDialogState(() => selectedType = value),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: keywordsController,
                  decoration: const InputDecoration(
                    labelText: 'Keywords (comma-separated)',
                    border: OutlineInputBorder(),
                    hintText: 'word1, word2, word3',
                  ),
                  maxLines: 3,
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: selectedAction,
                  decoration: const InputDecoration(
                    labelText: 'Action',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'flag', child: Text('Flag')),
                    DropdownMenuItem(value: 'warn', child: Text('Warn')),
                    DropdownMenuItem(value: 'mute', child: Text('Mute')),
                    DropdownMenuItem(value: 'ban', child: Text('Ban')),
                  ],
                  onChanged: (value) => setDialogState(() => selectedAction = value),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: selectedSeverity,
                  decoration: const InputDecoration(
                    labelText: 'Severity',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'low', child: Text('Low')),
                    DropdownMenuItem(value: 'medium', child: Text('Medium')),
                    DropdownMenuItem(value: 'high', child: Text('High')),
                    DropdownMenuItem(value: 'critical', child: Text('Critical')),
                  ],
                  onChanged: (value) => setDialogState(() => selectedSeverity = value),
                ),
                const SizedBox(height: 16),
                CheckboxListTile(
                  title: const Text('Enabled'),
                  value: enabled,
                  onChanged: (value) => setDialogState(() => enabled = value ?? true),
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
                final keywords = keywordsController.text
                    .split(',')
                    .map((e) => e.trim())
                    .where((e) => e.isNotEmpty)
                    .toList();
                
                try {
                  if (isEdit) {
                    await _adminService.updateModerationRule(
                      rule!['_id'].toString(),
                      {
                        'name': nameController.text,
                        'type': selectedType,
                        'keywords': keywords,
                        'action': selectedAction,
                        'severity': selectedSeverity,
                        'enabled': enabled,
                      },
                    );
                  } else {
                    await _adminService.createModerationRule(
                      name: nameController.text,
                      type: selectedType!,
                      action: selectedAction!,
                      keywords: keywords,
                      severity: selectedSeverity!,
                      enabled: enabled,
                    );
                  }
                  
                  if (mounted) {
                    Navigator.of(context).pop();
                    _loadRules();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(isEdit ? 'Rule updated' : 'Rule created'),
                        backgroundColor: Colors.green,
                      ),
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Error: ${e.toString()}'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                }
              },
              child: Text(isEdit ? 'Update' : 'Create'),
            ),
          ],
        ),
      ),
    );
  }
  
  Future<void> _toggleRule(String ruleId, bool enabled) async {
    try {
      await _adminService.updateModerationRule(ruleId, {'enabled': enabled});
      _loadRules();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to toggle rule: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
  
  Future<void> _deleteRule(String ruleId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Rule'),
        content: const Text('Are you sure you want to delete this rule?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    
    if (confirmed == true) {
      try {
        await _adminService.deleteModerationRule(ruleId);
        _loadRules();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Rule deleted'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to delete rule: ${e.toString()}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }
  
  // =============================================================================
  // QUEUE TAB
  // =============================================================================
  
  Widget _buildQueueTab() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'Moderation Queue',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: _themeService.isDarkMode ? Colors.white : Colors.black87,
                  ),
                ),
              ),
              Chip(
                label: Text('Total: $_queueTotal'),
                backgroundColor: Colors.blue.withOpacity(0.2),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Expanded(
                child: SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(value: 'pending', label: Text('Pending')),
                    ButtonSegment(value: 'processed', label: Text('Processed')),
                  ],
                  selected: {_queueStatus},
                  onSelectionChanged: (Set<String> selection) {
                    setState(() {
                      _queueStatus = selection.first;
                      _queueSkip = 0;
                      _selectedQueueItems.clear();
                    });
                    _loadQueue();
                  },
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: _loadQueue,
                tooltip: 'Refresh',
              ),
            ],
          ),
        ),
        if (_selectedQueueItems.isNotEmpty) _buildBulkActionBar(),
        if (_isLoadingQueue)
          const Expanded(child: Center(child: CircularProgressIndicator()))
        else if (_queue.isEmpty)
          Expanded(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.queue_outlined, size: 64, color: Colors.grey),
                  const SizedBox(height: 16),
                  Text('No ${_queueStatus} items in queue'),
                ],
              ),
            ),
          )
        else
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _queue.length,
              itemBuilder: (context, index) {
                final item = _queue[index];
                return _buildQueueItemCard(item);
              },
            ),
          ),
        if (_queueTotal > _queueLimit)
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (_queueSkip > 0)
                  TextButton(
                    onPressed: () {
                      setState(() => _queueSkip = (_queueSkip - _queueLimit).clamp(0, double.infinity).toInt());
                      _loadQueue();
                    },
                    child: const Text('Previous'),
                  ),
                const SizedBox(width: 16),
                Text('Page ${(_queueSkip / _queueLimit).floor() + 1} of ${(_queueTotal / _queueLimit).ceil()}'),
                const SizedBox(width: 16),
                if (_queueSkip + _queueLimit < _queueTotal)
                  TextButton(
                    onPressed: () {
                      setState(() => _queueSkip += _queueLimit);
                      _loadQueue();
                    },
                    child: const Text('Next'),
                  ),
              ],
            ),
          ),
      ],
    );
  }
  
  Widget _buildBulkActionBar() {
    return Container(
      padding: const EdgeInsets.all(12),
      color: Colors.blue.withOpacity(0.1),
      child: Row(
        children: [
          Text('${_selectedQueueItems.length} selected'),
          const Spacer(),
          TextButton.icon(
            onPressed: () => setState(() => _selectedQueueItems.clear()),
            icon: const Icon(Icons.clear),
            label: const Text('Clear'),
          ),
          const SizedBox(width: 8),
          ElevatedButton.icon(
            onPressed: () => _processBulkAction('approve'),
            icon: const Icon(Icons.check),
            label: const Text('Approve'),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
          ),
          const SizedBox(width: 8),
          ElevatedButton.icon(
            onPressed: () => _processBulkAction('delete'),
            icon: const Icon(Icons.delete),
            label: const Text('Delete'),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
          ),
        ],
      ),
    );
  }
  
  Widget _buildQueueItemCard(Map<String, dynamic> item) {
    final itemId = item['_id']?.toString() ?? '';
    final isSelected = _selectedQueueItems.contains(itemId);
    final messageContent = item['messageContent'] ?? 'No content';
    final userName = item['userName'] ?? 'Unknown User';
    final flaggedAt = item['flaggedAt'] != null
        ? DateTime.parse(item['flaggedAt'])
        : null;
    final reason = item['reason'] ?? 'No reason specified';
    
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: isSelected ? Colors.blue.withOpacity(0.1) : null,
      child: ListTile(
        leading: Checkbox(
          value: isSelected,
          onChanged: (value) {
            setState(() {
              if (value == true) {
                _selectedQueueItems.add(itemId);
              } else {
                _selectedQueueItems.remove(itemId);
              }
            });
          },
        ),
        title: Text(userName),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(messageContent, maxLines: 2, overflow: TextOverflow.ellipsis),
            if (flaggedAt != null)
              Text(
                'Flagged: ${DateFormat('MMM dd, yyyy HH:mm').format(flaggedAt)}',
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
            Text('Reason: $reason', style: TextStyle(fontSize: 12, color: Colors.orange[700])),
          ],
        ),
        trailing: _queueStatus == 'pending'
            ? PopupMenuButton<String>(
                onSelected: (value) => _processQueueItem(itemId, value),
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: 'approve',
                    child: Row(
                      children: [
                        Icon(Icons.check, color: Colors.green),
                        SizedBox(width: 8),
                        Text('Approve'),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'delete',
                    child: Row(
                      children: [
                        Icon(Icons.delete, color: Colors.red),
                        SizedBox(width: 8),
                        Text('Delete'),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'warn',
                    child: Row(
                      children: [
                        Icon(Icons.warning, color: Colors.orange),
                        SizedBox(width: 8),
                        Text('Warn User'),
                      ],
                    ),
                  ),
                ],
              )
            : null,
        onTap: () {
          if (_queueStatus == 'pending') {
            _showQueueItemDetails(item);
          }
        },
      ),
    );
  }
  
  void _showQueueItemDetails(Map<String, dynamic> item) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Message Details'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('User: ${item['userName'] ?? 'Unknown'}'),
              const SizedBox(height: 8),
              Text('Content: ${item['messageContent'] ?? 'No content'}'),
              const SizedBox(height: 8),
              if (item['reason'] != null)
                Text('Reason: ${item['reason']}'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
  
  Future<void> _processQueueItem(String itemId, String action) async {
    String? reason;
    if (action == 'warn' || action == 'delete') {
      final reasonController = TextEditingController();
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('${action.toUpperCase()} Message'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Please provide a reason:'),
              const SizedBox(height: 16),
              TextField(
                controller: reasonController,
                decoration: const InputDecoration(
                  hintText: 'Reason...',
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                reason = reasonController.text.trim();
                Navigator.of(context).pop(true);
              },
              child: const Text('Confirm'),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
    }
    
    try {
      await _adminService.processModerationQueueItem(itemId, action, reason: reason);
      if (mounted) {
        _loadQueue();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Message ${action}d successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to process: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
  
  Future<void> _processBulkAction(String action) async {
    if (_selectedQueueItems.isEmpty) return;
    
    String? reason;
    if (action == 'delete') {
      final reasonController = TextEditingController();
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('${action.toUpperCase()} ${_selectedQueueItems.length} Messages'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Please provide a reason:'),
              const SizedBox(height: 16),
              TextField(
                controller: reasonController,
                decoration: const InputDecoration(
                  hintText: 'Reason...',
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                reason = reasonController.text.trim();
                Navigator.of(context).pop(true);
              },
              child: const Text('Confirm'),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
    }
    
    try {
      final selectedCount = _selectedQueueItems.length;
      final itemsToProcess = List<String>.from(_selectedQueueItems);
      
      for (final itemId in itemsToProcess) {
        await _adminService.processModerationQueueItem(itemId, action, reason: reason);
      }
      
      setState(() => _selectedQueueItems.clear());
      if (mounted) {
        _loadQueue();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$selectedCount messages processed'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to process: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
  
  // =============================================================================
  // HISTORY TAB
  // =============================================================================
  
  Widget _buildHistoryTab() {
    return const Center(
      child: Text('Violation history will be shown here'),
    );
  }
}

