// =============================================================================
// BACKUP & RESTORE SCREEN
// =============================================================================
// Comprehensive backup management with scheduling and restoration
// Features: Backup creation, restoration, scheduling, backup history

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'dart:async';
import '../services/mongodb_admin_service.dart';
import '../services/theme_service.dart';
import '../utils/responsive_utils.dart';
import '../services/logger_service.dart';

class BackupRestoreScreen extends StatefulWidget {
  const BackupRestoreScreen({Key? key}) : super(key: key);

  @override
  State<BackupRestoreScreen> createState() => _BackupRestoreScreenState();
}

class _BackupRestoreScreenState extends State<BackupRestoreScreen> with SingleTickerProviderStateMixin {
  final MongoDBAdminService _adminService = MongoDBAdminService();
  late TabController _tabController;
  late ThemeService _themeService;

  // Backups
  List<Map<String, dynamic>> _backups = [];
  bool _isLoadingBackups = false;
  Timer? _backupRefreshTimer;
  bool _autoRefreshEnabled = true;

  // Schedules
  List<Map<String, dynamic>> _schedules = [];
  bool _isLoadingSchedules = false;

  // Create backup
  final TextEditingController _backupNameController = TextEditingController();
  String _backupType = 'full';

  // Create schedule
  final TextEditingController _scheduleNameController = TextEditingController();
  String _scheduleFrequency = 'daily';
  String _scheduleTime = '00:00';
  String _scheduleType = 'full';

  @override
  void initState() {
    super.initState();
    _themeService = ThemeService.instance;
    _themeService.addListener(() {
      if (mounted) setState(() {});
    });
    
    _tabController = TabController(length: 2, vsync: this);
    _loadBackups();
    _loadSchedules();
    _startAutoRefresh();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _backupNameController.dispose();
    _scheduleNameController.dispose();
    _backupRefreshTimer?.cancel();
    super.dispose();
  }

  void _startAutoRefresh() {
    _backupRefreshTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      if (_autoRefreshEnabled && mounted) {
        _loadBackups();
      }
    });
  }

  Future<void> _loadBackups() async {
    setState(() => _isLoadingBackups = true);
    try {
      final backups = await _adminService.getBackups();
      setState(() {
        _backups = backups;
        _isLoadingBackups = false;
      });
    } catch (e) {
      Log.e('Error loading backups', 'BACKUP_RESTORE', e);
      setState(() => _isLoadingBackups = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load backups: $e')),
        );
      }
    }
  }

  Future<void> _loadSchedules() async {
    setState(() => _isLoadingSchedules = true);
    try {
      final schedules = await _adminService.getBackupSchedules();
      setState(() {
        _schedules = schedules;
        _isLoadingSchedules = false;
      });
    } catch (e) {
      Log.e('Error loading schedules', 'BACKUP_RESTORE', e);
      setState(() => _isLoadingSchedules = false);
    }
  }

  Future<void> _createBackup() async {
    try {
      await _adminService.createBackup(
        name: _backupNameController.text.trim().isEmpty ? null : _backupNameController.text.trim(),
        type: _backupType,
      );
      _backupNameController.clear();
      _loadBackups();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Backup started')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to create backup: $e')),
        );
      }
    }
  }

  Future<void> _restoreBackup(String backupId, String backupName) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Restore Backup'),
        content: Text('Are you sure you want to restore "$backupName"? This will overwrite current data.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Restore', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _adminService.restoreBackup(backupId, confirm: true);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Backup restoration started')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to restore backup: $e')),
          );
        }
      }
    }
  }

  Future<void> _cancelBackup(String backupId, String backupName) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel Backup'),
        content: Text('Are you sure you want to cancel "$backupName"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('No'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Cancel Backup', style: TextStyle(color: Colors.orange)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _adminService.cancelBackup(backupId);
        _loadBackups();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Backup cancelled')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to cancel backup: $e')),
          );
        }
      }
    }
  }

  Future<void> _deleteBackup(String backupId, String backupName) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Backup'),
        content: Text('Are you sure you want to delete "$backupName"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _adminService.deleteBackup(backupId);
        _loadBackups();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Backup deleted')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to delete backup: $e')),
          );
        }
      }
    }
  }

  Future<void> _createSchedule() async {
    if (_scheduleNameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Schedule name is required')),
      );
      return;
    }

    try {
      await _adminService.createBackupSchedule(
        name: _scheduleNameController.text.trim(),
        frequency: _scheduleFrequency,
        time: _scheduleTime,
        type: _scheduleType,
      );
      _scheduleNameController.clear();
      _loadSchedules();
      Navigator.pop(context);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Schedule created')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to create schedule: $e')),
        );
      }
    }
  }

  void _showCreateBackupDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Create Backup'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _backupNameController,
              decoration: const InputDecoration(
                labelText: 'Backup Name (Optional)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: _backupType,
              decoration: const InputDecoration(
                labelText: 'Backup Type',
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(value: 'full', child: Text('Full Backup')),
                DropdownMenuItem(value: 'incremental', child: Text('Incremental Backup')),
              ],
              onChanged: (value) => setState(() => _backupType = value ?? 'full'),
            ),
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
              _createBackup();
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }

  void _showCreateScheduleDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Create Backup Schedule'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _scheduleNameController,
                decoration: const InputDecoration(
                  labelText: 'Schedule Name',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _scheduleFrequency,
                decoration: const InputDecoration(
                  labelText: 'Frequency',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(value: 'daily', child: Text('Daily')),
                  DropdownMenuItem(value: 'weekly', child: Text('Weekly')),
                  DropdownMenuItem(value: 'monthly', child: Text('Monthly')),
                ],
                onChanged: (value) => setState(() => _scheduleFrequency = value ?? 'daily'),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: TextEditingController(text: _scheduleTime),
                decoration: const InputDecoration(
                  labelText: 'Time (HH:MM)',
                  border: OutlineInputBorder(),
                ),
                onChanged: (value) => _scheduleTime = value,
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _scheduleType,
                decoration: const InputDecoration(
                  labelText: 'Backup Type',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(value: 'full', child: Text('Full Backup')),
                  DropdownMenuItem(value: 'incremental', child: Text('Incremental Backup')),
                ],
                onChanged: (value) => setState(() => _scheduleType = value ?? 'full'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: _createSchedule,
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = ResponsiveUtils.isMobile(context);
    final isTablet = ResponsiveUtils.isTablet(context);
    final padding = ResponsiveUtils.getResponsivePadding(context);
    final fontSize = ResponsiveUtils.getResponsiveFontSize(context, baseSize: 16.0);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Backup & Restore'),
        actions: [
          IconButton(
            icon: Icon(_autoRefreshEnabled ? Icons.refresh : Icons.refresh_outlined),
            onPressed: () {
              setState(() => _autoRefreshEnabled = !_autoRefreshEnabled);
              if (_autoRefreshEnabled) {
                _startAutoRefresh();
              } else {
                _backupRefreshTimer?.cancel();
              }
            },
            tooltip: _autoRefreshEnabled ? 'Auto-refresh enabled' : 'Auto-refresh disabled',
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadBackups,
            tooltip: 'Refresh backups',
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          isScrollable: !isTablet && !isMobile,
          tabs: const [
            Tab(icon: Icon(Icons.backup), text: 'Backups'),
            Tab(icon: Icon(Icons.schedule), text: 'Schedules'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildBackupsTab(context, isMobile, isTablet, padding, fontSize),
          _buildSchedulesTab(context, isMobile, isTablet, padding, fontSize),
        ],
      ),
      floatingActionButton: _tabController.index == 0
          ? FloatingActionButton(
              onPressed: _showCreateBackupDialog,
              child: const Icon(Icons.add),
              tooltip: 'Create Backup',
            )
          : FloatingActionButton(
              onPressed: _showCreateScheduleDialog,
              child: const Icon(Icons.add),
              tooltip: 'Create Schedule',
            ),
    );
  }

  Widget _buildBackupsTab(BuildContext context, bool isMobile, bool isTablet, EdgeInsets padding, double fontSize) {
    if (_isLoadingBackups) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_backups.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.backup_outlined, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            Text('No backups', style: TextStyle(fontSize: fontSize, color: Colors.grey)),
            const SizedBox(height: 8),
            Text('Tap + to create a new backup', style: TextStyle(fontSize: fontSize * 0.9, color: Colors.grey)),
          ],
        ),
      );
    }

    // Group backups by status
    final runningBackups = _backups.where((b) => b['status'] == 'in_progress' || b['restoreStatus'] == 'in_progress').toList();
    final completedBackups = _backups.where((b) => b['status'] == 'completed' && (b['restoreStatus'] == null || b['restoreStatus'] != 'in_progress')).toList();
    final failedBackups = _backups.where((b) => b['status'] == 'failed' || b['status'] == 'cancelled' || b['restoreStatus'] == 'failed').toList();

    return ListView(
      padding: padding,
      children: [
        if (runningBackups.isNotEmpty) ...[
          Padding(
            padding: EdgeInsets.only(bottom: padding.bottom / 2),
            child: Text(
              'Running Backups (${runningBackups.length})',
              style: TextStyle(fontSize: fontSize * 1.1, fontWeight: FontWeight.bold, color: Colors.blue),
            ),
          ),
          ...runningBackups.map((backup) => _buildBackupCard(context, backup, isMobile, isTablet, padding, fontSize)),
          const SizedBox(height: 16),
        ],
        if (completedBackups.isNotEmpty) ...[
          Padding(
            padding: EdgeInsets.only(bottom: padding.bottom / 2),
            child: Text(
              'Completed Backups (${completedBackups.length})',
              style: TextStyle(fontSize: fontSize * 1.1, fontWeight: FontWeight.bold, color: Colors.green),
            ),
          ),
          ...completedBackups.map((backup) => _buildBackupCard(context, backup, isMobile, isTablet, padding, fontSize)),
          const SizedBox(height: 16),
        ],
        if (failedBackups.isNotEmpty) ...[
          Padding(
            padding: EdgeInsets.only(bottom: padding.bottom / 2),
            child: Text(
              'Failed/Cancelled Backups (${failedBackups.length})',
              style: TextStyle(fontSize: fontSize * 1.1, fontWeight: FontWeight.bold, color: Colors.red),
            ),
          ),
          ...failedBackups.map((backup) => _buildBackupCard(context, backup, isMobile, isTablet, padding, fontSize)),
        ],
      ],
    );
  }

  Widget _buildBackupCard(BuildContext context, Map<String, dynamic> backup, bool isMobile, bool isTablet, EdgeInsets padding, double fontSize) {
    final status = backup['status'] ?? 'unknown';
    final restoreStatus = backup['restoreStatus'];
    final progress = backup['progress'] ?? 0;
    
    Color statusColor = Colors.grey;
    IconData statusIcon = Icons.help_outline;
    
    if (status == 'completed') {
      statusColor = Colors.green;
      statusIcon = Icons.check_circle;
    } else if (status == 'in_progress') {
      statusColor = Colors.blue;
      statusIcon = Icons.sync;
    } else if (status == 'failed') {
      statusColor = Colors.red;
      statusIcon = Icons.error;
    } else if (status == 'cancelled') {
      statusColor = Colors.orange;
      statusIcon = Icons.cancel;
    }

    final isRunning = status == 'in_progress' || restoreStatus == 'in_progress';
    final canRestore = status == 'completed' && (restoreStatus == null || restoreStatus != 'in_progress');
    final canCancel = status == 'in_progress';

    return Card(
      margin: EdgeInsets.only(bottom: padding.bottom),
      child: ExpansionTile(
        leading: isRunning
            ? SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(statusColor),
                ),
              )
            : Icon(statusIcon, color: statusColor),
        title: Text(backup['name'] ?? 'Unknown', style: TextStyle(fontSize: fontSize)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Chip(
                  label: Text(status.toUpperCase(), style: TextStyle(fontSize: fontSize * 0.75, fontWeight: FontWeight.bold)),
                  backgroundColor: statusColor.withOpacity(0.2),
                  labelPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
                ),
                if (restoreStatus != null) ...[
                  const SizedBox(width: 8),
                  Chip(
                    label: Text('RESTORE: ${restoreStatus.toUpperCase()}', style: TextStyle(fontSize: fontSize * 0.75, fontWeight: FontWeight.bold)),
                    backgroundColor: restoreStatus == 'in_progress' ? Colors.blue.withOpacity(0.2) : restoreStatus == 'completed' ? Colors.green.withOpacity(0.2) : Colors.red.withOpacity(0.2),
                    labelPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
                  ),
                ],
              ],
            ),
            if (isRunning && progress > 0) ...[
              const SizedBox(height: 8),
              LinearProgressIndicator(
                value: progress / 100,
                backgroundColor: Colors.grey.withOpacity(0.2),
                valueColor: AlwaysStoppedAnimation<Color>(statusColor),
              ),
              const SizedBox(height: 4),
              Text('${progress.toStringAsFixed(0)}%', style: TextStyle(fontSize: fontSize * 0.8, color: Colors.grey)),
            ],
            const SizedBox(height: 4),
            Text('Type: ${backup['type'] ?? 'unknown'}', style: TextStyle(fontSize: fontSize * 0.9)),
            if (backup['size'] != null && backup['size'] > 0)
              Text('Size: ${(backup['size'] / 1024 / 1024).toStringAsFixed(1)} MB', style: TextStyle(fontSize: fontSize * 0.9)),
            if (backup['collectionsBackedUp'] != null && (backup['collectionsBackedUp'] as List).isNotEmpty)
              Text('Collections: ${(backup['collectionsBackedUp'] as List).join(', ')}', style: TextStyle(fontSize: fontSize * 0.85, color: Colors.blue)),
            if (backup['documentCount'] != null && backup['documentCount'] > 0)
              Text('Documents: ${backup['documentCount']}', style: TextStyle(fontSize: fontSize * 0.85, color: Colors.grey)),
            if (backup['createdAt'] != null)
              Text(
                'Created: ${DateFormat('yyyy-MM-dd HH:mm').format(DateTime.parse(backup['createdAt']))}',
                style: TextStyle(fontSize: fontSize * 0.85, color: Colors.grey),
              ),
            if (backup['error'] != null)
              Text(
                'Error: ${backup['error']}',
                style: TextStyle(fontSize: fontSize * 0.85, color: Colors.red),
              ),
            if (backup['restoreError'] != null)
              Text(
                'Restore Error: ${backup['restoreError']}',
                style: TextStyle(fontSize: fontSize * 0.85, color: Colors.red),
              ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (canRestore)
              IconButton(
                icon: const Icon(Icons.restore, color: Colors.green),
                onPressed: () => _restoreBackup(backup['id'], backup['name'] ?? 'Unknown'),
                tooltip: 'Restore',
              ),
            if (canCancel)
              IconButton(
                icon: const Icon(Icons.cancel, color: Colors.orange),
                onPressed: () => _cancelBackup(backup['id'], backup['name'] ?? 'Unknown'),
                tooltip: 'Cancel',
              ),
            IconButton(
              icon: const Icon(Icons.delete, color: Colors.red),
              onPressed: () => _deleteBackup(backup['id'], backup['name'] ?? 'Unknown'),
              tooltip: 'Delete',
            ),
          ],
        ),
        children: [
          Padding(
            padding: padding,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (backup['completedAt'] != null)
                  Text('Completed: ${DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.parse(backup['completedAt']))}', style: TextStyle(fontSize: fontSize * 0.9)),
                if (backup['verified'] == true)
                  Row(
                    children: [
                      const Icon(Icons.verified, color: Colors.green, size: 16),
                      const SizedBox(width: 4),
                      Text('Verified', style: TextStyle(fontSize: fontSize * 0.9, color: Colors.green)),
                    ],
                  ),
                if (backup['restoreStartedAt'] != null)
                  Text('Restore Started: ${DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.parse(backup['restoreStartedAt']))}', style: TextStyle(fontSize: fontSize * 0.9)),
                if (backup['restoreCompletedAt'] != null)
                  Text('Restore Completed: ${DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.parse(backup['restoreCompletedAt']))}', style: TextStyle(fontSize: fontSize * 0.9)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSchedulesTab(BuildContext context, bool isMobile, bool isTablet, EdgeInsets padding, double fontSize) {
    if (_isLoadingSchedules) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_schedules.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.schedule_outlined, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            Text('No schedules', style: TextStyle(fontSize: fontSize, color: Colors.grey)),
            const SizedBox(height: 8),
            Text('Tap + to create a new schedule', style: TextStyle(fontSize: fontSize * 0.9, color: Colors.grey)),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: padding,
      itemCount: _schedules.length,
      itemBuilder: (context, index) {
        final schedule = _schedules[index];
        final isActive = schedule['isActive'] == true;

        return Card(
          margin: EdgeInsets.only(bottom: padding.bottom),
          child: ListTile(
            leading: Icon(
              isActive ? Icons.schedule : Icons.schedule_outlined,
              color: isActive ? Colors.green : Colors.grey,
            ),
            title: Text(schedule['name'] ?? 'Unknown', style: TextStyle(fontSize: fontSize)),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Frequency: ${schedule['frequency'] ?? 'unknown'}, Type: ${schedule['type'] ?? 'unknown'}', style: TextStyle(fontSize: fontSize * 0.9)),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Chip(
                      label: Text(isActive ? 'Active' : 'Inactive', style: TextStyle(fontSize: fontSize * 0.8)),
                      backgroundColor: isActive ? Colors.green.withOpacity(0.2) : Colors.grey.withOpacity(0.2),
                    ),
                    if (schedule['nextRun'] != null) ...[
                      const SizedBox(width: 8),
                      Chip(
                        label: Text('Next: ${DateFormat('MM-dd HH:mm').format(DateTime.parse(schedule['nextRun']))}', style: TextStyle(fontSize: fontSize * 0.8)),
                        backgroundColor: Colors.blue.withOpacity(0.2),
                      ),
                    ],
                  ],
                ),
              ],
            ),
            trailing: IconButton(
              icon: const Icon(Icons.delete, color: Colors.red),
              onPressed: () async {
                try {
                  await _adminService.deleteBackupSchedule(schedule['id']);
                  _loadSchedules();
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Failed to delete schedule: $e')),
                    );
                  }
                }
              },
            ),
          ),
        );
      },
    );
  }
}

