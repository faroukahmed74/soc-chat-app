// =============================================================================
// CHAT MODERATION SCREEN
// =============================================================================
// Comprehensive chat moderation tools with message viewing, moderation actions,
// and group management features
// Features: View messages, delete messages, mute/archive chats, transfer ownership, manage moderators

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/mongodb_admin_service.dart';
import '../services/theme_service.dart';
import '../utils/responsive_utils.dart';
import '../services/logger_service.dart';
import 'user_detail_profile_screen.dart';

class ChatModerationScreen extends StatefulWidget {
  final String chatId;

  const ChatModerationScreen({Key? key, required this.chatId}) : super(key: key);

  @override
  State<ChatModerationScreen> createState() => _ChatModerationScreenState();
}

class _ChatModerationScreenState extends State<ChatModerationScreen> with SingleTickerProviderStateMixin {
  final MongoDBAdminService _adminService = MongoDBAdminService();
  late TabController _tabController;
  late ThemeService _themeService;

  Map<String, dynamic>? _chatDetails;
  List<Map<String, dynamic>> _messages = [];
  Map<String, dynamic>? _statistics;
  bool _isLoading = false;
  bool _isLoadingMessages = false;
  bool _isLoadingStats = false;
  int _currentPage = 1;
  int _totalPages = 1;

  // Moderation actions
  final TextEditingController _muteDurationController = TextEditingController();
  final TextEditingController _muteReasonController = TextEditingController();
  final TextEditingController _newOwnerIdController = TextEditingController();
  Set<String> _selectedModerators = {};

  @override
  void initState() {
    super.initState();
    _themeService = ThemeService.instance;
    _themeService.addListener(() {
      if (mounted) setState(() {});
    });
    
    _tabController = TabController(length: 4, vsync: this);
    _loadChatDetails();
    _loadMessages();
    _loadStatistics();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _muteDurationController.dispose();
    _muteReasonController.dispose();
    _newOwnerIdController.dispose();
    super.dispose();
  }

  Future<void> _loadChatDetails() async {
    setState(() => _isLoading = true);
    try {
      final data = await _adminService.getChatDetails(widget.chatId, includeMessages: false);
      setState(() {
        _chatDetails = data['chat'];
        _isLoading = false;
      });
    } catch (e) {
      Log.e('Error loading chat details', 'CHAT_MODERATION', e);
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load chat details: $e')),
        );
      }
    }
  }

  Future<void> _loadMessages() async {
    setState(() => _isLoadingMessages = true);
    try {
      final data = await _adminService.getChatMessages(widget.chatId, page: _currentPage);
      setState(() {
        _messages = List<Map<String, dynamic>>.from(data['messages'] ?? []);
        _totalPages = data['pagination']?['pages'] ?? 1;
        _isLoadingMessages = false;
      });
    } catch (e) {
      Log.e('Error loading messages', 'CHAT_MODERATION', e);
      setState(() => _isLoadingMessages = false);
    }
  }

  Future<void> _loadStatistics() async {
    setState(() => _isLoadingStats = true);
    try {
      // Statistics endpoint already exists, but we'll use chat details for now
      setState(() => _isLoadingStats = false);
    } catch (e) {
      Log.e('Error loading statistics', 'CHAT_MODERATION', e);
      setState(() => _isLoadingStats = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = ResponsiveUtils.isMobile(context);
    final isTablet = ResponsiveUtils.isTablet(context);
    final padding = ResponsiveUtils.getResponsivePadding(context);
    final fontSize = ResponsiveUtils.getResponsiveFontSize(context, baseSize: 16.0);

    return Scaffold(
      appBar: AppBar(
        title: Text(_chatDetails?['name'] ?? 'Chat Moderation'),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: !isTablet && !isMobile,
          tabs: const [
            Tab(icon: Icon(Icons.info), text: 'Details'),
            Tab(icon: Icon(Icons.message), text: 'Messages'),
            Tab(icon: Icon(Icons.people), text: 'Members'),
            Tab(icon: Icon(Icons.settings), text: 'Settings'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _chatDetails == null
              ? Center(
                  child: Text('Failed to load chat details', style: TextStyle(fontSize: fontSize)),
                )
              : TabBarView(
                  controller: _tabController,
                  children: [
                    _buildDetailsTab(context, isMobile, isTablet, padding, fontSize),
                    _buildMessagesTab(context, isMobile, isTablet, padding, fontSize),
                    _buildMembersTab(context, isMobile, isTablet, padding, fontSize),
                    _buildSettingsTab(context, isMobile, isTablet, padding, fontSize),
                  ],
                ),
    );
  }

  Widget _buildDetailsTab(BuildContext context, bool isMobile, bool isTablet, EdgeInsets padding, double fontSize) {
    final chat = _chatDetails!;
    final members = List<Map<String, dynamic>>.from(chat['members'] ?? []);
    
    return SingleChildScrollView(
      padding: padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Chat Info Card
          Card(
            child: Padding(
              padding: padding,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('Chat Information', style: TextStyle(fontSize: fontSize * 1.2, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  _buildInfoRow('Name', chat['name'] ?? 'Unnamed'),
                  _buildInfoRow('Type', chat['type'] ?? 'group'),
                  _buildInfoRow('Members', '${members.length}'),
                  if (chat['owner'] != null)
                    _buildInfoRow('Owner', chat['owner']?['name'] ?? 'Unknown'),
                  _buildInfoRow('Created', DateFormat('yyyy-MM-dd HH:mm').format(DateTime.parse(chat['createdAt'] ?? DateTime.now().toIso8601String()))),
                  _buildInfoRow('Last Updated', DateFormat('yyyy-MM-dd HH:mm').format(DateTime.parse(chat['updatedAt'] ?? DateTime.now().toIso8601String()))),
                  if (chat['muted'] == true)
                    Chip(
                      label: const Text('MUTED'),
                      backgroundColor: Colors.orange,
                    ),
                  if (chat['archived'] == true)
                    Chip(
                      label: const Text('ARCHIVED'),
                      backgroundColor: Colors.grey,
                    ),
                ],
              ),
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Quick Actions
          Card(
            child: Padding(
              padding: padding,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('Quick Actions', style: TextStyle(fontSize: fontSize * 1.2, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      ElevatedButton.icon(
                        icon: Icon(chat['muted'] == true ? Icons.volume_up : Icons.volume_off),
                        label: Text(chat['muted'] == true ? 'Unmute' : 'Mute'),
                        onPressed: () {
                          if (chat['muted'] == true) {
                            _unmuteChat();
                          } else {
                            _showMuteDialog();
                          }
                        },
                      ),
                      ElevatedButton.icon(
                        icon: Icon(chat['archived'] == true ? Icons.unarchive : Icons.archive),
                        label: Text(chat['archived'] == true ? 'Unarchive' : 'Archive'),
                        onPressed: () {
                          if (chat['archived'] == true) {
                            _unarchiveChat();
                          } else {
                            _archiveChat();
                          }
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text('$label:', style: const TextStyle(fontWeight: FontWeight.bold)),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  Widget _buildMessagesTab(BuildContext context, bool isMobile, bool isTablet, EdgeInsets padding, double fontSize) {
    return Column(
      children: [
        // Pagination controls
        Padding(
          padding: padding,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left),
                onPressed: _currentPage > 1
                    ? () {
                        setState(() => _currentPage--);
                        _loadMessages();
                      }
                    : null,
              ),
              Text('Page $_currentPage of $_totalPages'),
              IconButton(
                icon: const Icon(Icons.chevron_right),
                onPressed: _currentPage < _totalPages
                    ? () {
                        setState(() => _currentPage++);
                        _loadMessages();
                      }
                    : null,
              ),
            ],
          ),
        ),
        
        // Messages List
        Expanded(
          child: _isLoadingMessages
              ? const Center(child: CircularProgressIndicator())
              : _messages.isEmpty
                  ? Center(
                      child: Text('No messages', style: TextStyle(fontSize: fontSize, color: Colors.grey)),
                    )
                  : ListView.builder(
                      padding: padding,
                      itemCount: _messages.length,
                      itemBuilder: (context, index) {
                        final message = _messages[index];
                        return Card(
                          child: ListTile(
                            leading: CircleAvatar(
                              child: Text(message['senderName']?[0]?.toUpperCase() ?? '?'),
                            ),
                            title: Text(message['senderName'] ?? 'Unknown'),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(message['content'] ?? '[Media]'),
                                Text(DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.parse(message['createdAt'] ?? DateTime.now().toIso8601String()))),
                              ],
                            ),
                            trailing: PopupMenuButton(
                              itemBuilder: (context) => [
                                PopupMenuItem(
                                  child: const Row(
                                    children: [
                                      Icon(Icons.delete, color: Colors.red),
                                      SizedBox(width: 8),
                                      Text('Delete Message'),
                                    ],
                                  ),
                                  onTap: () {
                                    Future.delayed(const Duration(milliseconds: 100), () {
                                      _deleteMessage(message['id']);
                                    });
                                  },
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
        ),
      ],
    );
  }

  Widget _buildMembersTab(BuildContext context, bool isMobile, bool isTablet, EdgeInsets padding, double fontSize) {
    final chat = _chatDetails!;
    final members = List<Map<String, dynamic>>.from(chat['members'] ?? []);
    final moderators = List<Map<String, dynamic>>.from(chat['moderators'] ?? []);
    final moderatorIds = moderators.map((m) => m['id']).toSet();
    final owner = chat['owner'];
    
    return SingleChildScrollView(
      padding: padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Owner
          if (owner != null) ...[
            Card(
              child: ListTile(
                leading: const Icon(Icons.person, color: Colors.amber),
                title: Text(owner['name'] ?? 'Unknown'),
                subtitle: const Text('Owner'),
                trailing: IconButton(
                  icon: const Icon(Icons.arrow_forward),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => UserDetailProfileScreen(userId: owner['id']),
                      ),
                    );
                  },
                ),
              ),
            ),
            const SizedBox(height: 8),
          ],
          
          // Moderators
          if (moderators.isNotEmpty) ...[
            Text('Moderators', style: TextStyle(fontSize: fontSize * 1.1, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            ...moderators.map((mod) => Card(
                  child: ListTile(
                    leading: const Icon(Icons.shield, color: Colors.blue),
                    title: Text(mod['name'] ?? 'Unknown'),
                    subtitle: Text(mod['email'] ?? ''),
                    trailing: IconButton(
                      icon: const Icon(Icons.remove_circle),
                      onPressed: () {
                        _removeModerator(mod['id']);
                      },
                      tooltip: 'Remove Moderator',
                    ),
                  ),
                )),
            const SizedBox(height: 16),
          ],
          
          // All Members
          Text('All Members (${members.length})', style: TextStyle(fontSize: fontSize * 1.1, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          ...members.map((member) {
            final isModerator = moderatorIds.contains(member['id']);
            final isOwner = owner?['id'] == member['id'];
            
            return Card(
              child: ListTile(
                leading: CircleAvatar(
                  backgroundImage: member['profilePicture'] != null
                      ? NetworkImage(member['profilePicture'])
                      : null,
                  child: member['profilePicture'] == null
                      ? Text(member['name']?[0]?.toUpperCase() ?? '?')
                      : null,
                ),
                title: Text(member['name'] ?? 'Unknown'),
                subtitle: Text(member['email'] ?? ''),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (isOwner)
                      const Chip(label: Text('Owner'), backgroundColor: Colors.amber)
                    else if (isModerator)
                      const Chip(label: Text('Mod'), backgroundColor: Colors.blue)
                    else if (chat['type'] == 'group')
                      IconButton(
                        icon: const Icon(Icons.add_circle),
                        onPressed: () {
                          _addModerator(member['id']);
                        },
                        tooltip: 'Add as Moderator',
                      ),
                    IconButton(
                      icon: const Icon(Icons.arrow_forward),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => UserDetailProfileScreen(userId: member['id']),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildSettingsTab(BuildContext context, bool isMobile, bool isTablet, EdgeInsets padding, double fontSize) {
    final chat = _chatDetails!;
    final permissions = chat['permissions'] ?? {};
    final isGroup = chat['type'] == 'group';
    
    return SingleChildScrollView(
      padding: padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (isGroup) ...[
            // Transfer Ownership
            Card(
              child: Padding(
                padding: padding,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text('Transfer Ownership', style: TextStyle(fontSize: fontSize * 1.2, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _newOwnerIdController,
                      decoration: const InputDecoration(
                        labelText: 'New Owner User ID',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 8),
                    ElevatedButton(
                      onPressed: () {
                        if (_newOwnerIdController.text.isEmpty) return;
                        _transferOwnership();
                      },
                      child: const Text('Transfer Ownership'),
                    ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Permissions
            Card(
              child: Padding(
                padding: padding,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text('Group Permissions', style: TextStyle(fontSize: fontSize * 1.2, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 16),
                    CheckboxListTile(
                      title: const Text('Can Send Messages'),
                      value: permissions['canSendMessages'] ?? true,
                      onChanged: (value) {
                        _updatePermission('canSendMessages', value ?? true);
                      },
                    ),
                    CheckboxListTile(
                      title: const Text('Can Add Members'),
                      value: permissions['canAddMembers'] ?? true,
                      onChanged: (value) {
                        _updatePermission('canAddMembers', value ?? true);
                      },
                    ),
                    CheckboxListTile(
                      title: const Text('Can Remove Members'),
                      value: permissions['canRemoveMembers'] ?? false,
                      onChanged: (value) {
                        _updatePermission('canRemoveMembers', value ?? false);
                      },
                    ),
                    CheckboxListTile(
                      title: const Text('Can Change Settings'),
                      value: permissions['canChangeSettings'] ?? false,
                      onChanged: (value) {
                        _updatePermission('canChangeSettings', value ?? false);
                      },
                    ),
                  ],
                ),
              ),
            ),
          ] else
            Card(
              child: Padding(
                padding: padding,
                child: Text('Settings are only available for group chats', style: TextStyle(fontSize: fontSize)),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _deleteMessage(String messageId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Message'),
        content: const Text('Are you sure you want to delete this message?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    
    if (confirmed == true) {
      try {
        await _adminService.deleteChatMessage(widget.chatId, messageId);
        _loadMessages();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Message deleted')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e')),
          );
        }
      }
    }
  }

  void _showMuteDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Mute Chat'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _muteDurationController,
              decoration: const InputDecoration(
                labelText: 'Duration (hours, leave empty for permanent)',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _muteReasonController,
              decoration: const InputDecoration(
                labelText: 'Reason (optional)',
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _muteChat();
            },
            child: const Text('Mute'),
          ),
        ],
      ),
    );
  }

  Future<void> _muteChat() async {
    try {
      await _adminService.muteChat(
        widget.chatId,
        durationHours: _muteDurationController.text.isEmpty
            ? null
            : int.tryParse(_muteDurationController.text),
        reason: _muteReasonController.text.isEmpty ? null : _muteReasonController.text,
      );
      _muteDurationController.clear();
      _muteReasonController.clear();
      _loadChatDetails();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Chat muted')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  Future<void> _unmuteChat() async {
    try {
      await _adminService.unmuteChat(widget.chatId);
      _loadChatDetails();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Chat unmuted')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  Future<void> _archiveChat() async {
    try {
      await _adminService.archiveChat(widget.chatId);
      _loadChatDetails();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Chat archived')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  Future<void> _unarchiveChat() async {
    try {
      await _adminService.unarchiveChat(widget.chatId);
      _loadChatDetails();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Chat unarchived')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  Future<void> _transferOwnership() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Transfer Ownership'),
        content: const Text('Are you sure you want to transfer ownership? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Transfer'),
          ),
        ],
      ),
    );
    
    if (confirmed == true) {
      try {
        await _adminService.transferGroupOwnership(widget.chatId, _newOwnerIdController.text);
        _newOwnerIdController.clear();
        _loadChatDetails();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Ownership transferred')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e')),
          );
        }
      }
    }
  }

  Future<void> _addModerator(String userId) async {
    try {
      await _adminService.manageGroupModerators(widget.chatId, [userId], action: 'add');
      _loadChatDetails();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Moderator added')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  Future<void> _removeModerator(String userId) async {
    try {
      await _adminService.manageGroupModerators(widget.chatId, [userId], action: 'remove');
      _loadChatDetails();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Moderator removed')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  Future<void> _updatePermission(String permission, bool value) async {
    try {
      final chat = _chatDetails!;
      final currentPermissions = Map<String, bool>.from(chat['permissions'] ?? {});
      currentPermissions[permission] = value;
      
      await _adminService.updateGroupPermissions(widget.chatId, currentPermissions);
      _loadChatDetails();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Permission updated')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }
}

