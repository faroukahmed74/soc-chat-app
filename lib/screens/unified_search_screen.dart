// =============================================================================
// UNIFIED SEARCH SCREEN
// =============================================================================
// Advanced search and filtering interface for users, chats, and messages
// Features: Multi-field search, advanced filters, saved queries, search history

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/mongodb_admin_service.dart';
import '../services/theme_service.dart';
import '../utils/responsive_utils.dart';
import '../services/logger_service.dart';
import 'user_detail_profile_screen.dart';

class UnifiedSearchScreen extends StatefulWidget {
  const UnifiedSearchScreen({Key? key}) : super(key: key);

  @override
  State<UnifiedSearchScreen> createState() => _UnifiedSearchScreenState();
}

class _UnifiedSearchScreenState extends State<UnifiedSearchScreen> with SingleTickerProviderStateMixin {
  final MongoDBAdminService _adminService = MongoDBAdminService();
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _savedSearchNameController = TextEditingController();
  
  late TabController _tabController;
  late ThemeService _themeService;

  // Search state
  String _currentQuery = '';
  List<String> _selectedTypes = ['users', 'chats', 'messages'];
  Map<String, dynamic> _filters = {};
  Map<String, dynamic> _searchResults = {};
  bool _isSearching = false;
  bool _showFilters = false;
  int _currentPage = 1;
  int _totalPages = 1;

  // Saved searches and history
  List<Map<String, dynamic>> _savedSearches = [];
  List<Map<String, dynamic>> _searchHistory = [];
  bool _isLoadingSaved = false;
  bool _isLoadingHistory = false;

  // Filter controllers
  final TextEditingController _roleFilterController = TextEditingController();
  final TextEditingController _statusFilterController = TextEditingController();
  final TextEditingController _memberCountMinController = TextEditingController();
  final TextEditingController _memberCountMaxController = TextEditingController();
  DateTime? _registrationDateFrom;
  DateTime? _registrationDateTo;
  DateTime? _lastActivityFrom;
  DateTime? _lastActivityTo;
  DateTime? _messageDateFrom;
  DateTime? _messageDateTo;

  @override
  void initState() {
    super.initState();
    _themeService = ThemeService.instance;
    _themeService.addListener(() {
      if (mounted) setState(() {});
    });
    
    _tabController = TabController(length: 3, vsync: this);
    _loadSavedSearches();
    _loadSearchHistory();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    _savedSearchNameController.dispose();
    _roleFilterController.dispose();
    _statusFilterController.dispose();
    _memberCountMinController.dispose();
    _memberCountMaxController.dispose();
    super.dispose();
  }

  Future<void> _loadSavedSearches() async {
    setState(() => _isLoadingSaved = true);
    try {
      final searches = await _adminService.getSavedSearches();
      setState(() {
        _savedSearches = searches;
        _isLoadingSaved = false;
      });
    } catch (e) {
      Log.e('Error loading saved searches', 'UNIFIED_SEARCH', e);
      setState(() => _isLoadingSaved = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load saved searches: $e')),
        );
      }
    }
  }

  Future<void> _loadSearchHistory() async {
    setState(() => _isLoadingHistory = true);
    try {
      final history = await _adminService.getSearchHistory();
      setState(() {
        _searchHistory = List<Map<String, dynamic>>.from(history['history'] ?? []);
        _isLoadingHistory = false;
      });
    } catch (e) {
      Log.e('Error loading search history', 'UNIFIED_SEARCH', e);
      setState(() => _isLoadingHistory = false);
    }
  }

  Future<void> _performSearch({bool loadMore = false}) async {
    if (_currentQuery.isEmpty && _filters.isEmpty) {
      setState(() => _searchResults = {});
      return;
    }

    setState(() {
      _isSearching = true;
      if (!loadMore) {
        _currentPage = 1;
        _searchResults = {};
      }
    });

    try {
      // Build filters
      final filters = Map<String, dynamic>.from(_filters);
      
      if (_roleFilterController.text.isNotEmpty) {
        filters['role'] = _roleFilterController.text;
      }
      if (_statusFilterController.text.isNotEmpty) {
        filters['status'] = _statusFilterController.text;
      }
      if (_memberCountMinController.text.isNotEmpty) {
        filters['memberCountMin'] = _memberCountMinController.text;
      }
      if (_memberCountMaxController.text.isNotEmpty) {
        filters['memberCountMax'] = _memberCountMaxController.text;
      }
      if (_registrationDateFrom != null) {
        filters['registrationDateFrom'] = _registrationDateFrom!.toIso8601String();
      }
      if (_registrationDateTo != null) {
        filters['registrationDateTo'] = _registrationDateTo!.toIso8601String();
      }
      if (_lastActivityFrom != null) {
        filters['lastActivityFrom'] = _lastActivityFrom!.toIso8601String();
      }
      if (_lastActivityTo != null) {
        filters['lastActivityTo'] = _lastActivityTo!.toIso8601String();
      }
      if (_messageDateFrom != null) {
        filters['messageDateFrom'] = _messageDateFrom!.toIso8601String();
      }
      if (_messageDateTo != null) {
        filters['messageDateTo'] = _messageDateTo!.toIso8601String();
      }

      final results = await _adminService.unifiedSearch(
        query: _currentQuery,
        types: _selectedTypes,
        filters: filters,
        page: _currentPage,
        limit: 20,
      );

      setState(() {
        if (loadMore) {
          // Append results
          final existingUsers = List<Map<String, dynamic>>.from(_searchResults['users'] ?? []);
          final existingChats = List<Map<String, dynamic>>.from(_searchResults['chats'] ?? []);
          final existingMessages = List<Map<String, dynamic>>.from(_searchResults['messages'] ?? []);
          
          _searchResults = {
            'users': [...existingUsers, ...List<Map<String, dynamic>>.from(results['users'] ?? [])],
            'chats': [...existingChats, ...List<Map<String, dynamic>>.from(results['chats'] ?? [])],
            'messages': [...existingMessages, ...List<Map<String, dynamic>>.from(results['messages'] ?? [])],
            'total': results['total'] ?? 0,
            'pagination': results['pagination'] ?? {},
          };
        } else {
          _searchResults = results;
        }
        _totalPages = results['pagination']?['pages'] ?? 1;
        _isSearching = false;
      });

      // Reload history
      _loadSearchHistory();
    } catch (e) {
      Log.e('Error performing search', 'UNIFIED_SEARCH', e);
      setState(() => _isSearching = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Search failed: $e')),
        );
      }
    }
  }

  Future<void> _saveSearch() async {
    if (_currentQuery.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a search query')),
      );
      return;
    }

    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Save Search'),
        content: TextField(
          controller: _savedSearchNameController,
          decoration: const InputDecoration(
            labelText: 'Search Name',
            hintText: 'Enter a name for this search',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, _savedSearchNameController.text),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (name != null && name.isNotEmpty) {
      try {
        await _adminService.saveSearchQuery(
          name: name,
          query: _currentQuery,
          filters: _filters,
          types: _selectedTypes,
        );
        _savedSearchNameController.clear();
        _loadSavedSearches();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Search saved successfully')),
          );
        }
      } catch (e) {
        Log.e('Error saving search', 'UNIFIED_SEARCH', e);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to save search: $e')),
          );
        }
      }
    }
  }

  Future<void> _loadSavedSearch(Map<String, dynamic> savedSearch) async {
    setState(() {
      _currentQuery = savedSearch['query'] ?? '';
      _searchController.text = _currentQuery;
      _filters = Map<String, dynamic>.from(savedSearch['filters'] ?? {});
      _selectedTypes = List<String>.from(savedSearch['types'] ?? ['users', 'chats', 'messages']);
    });
    await _performSearch();
  }

  void _clearFilters() {
    setState(() {
      _filters = {};
      _roleFilterController.clear();
      _statusFilterController.clear();
      _memberCountMinController.clear();
      _memberCountMaxController.clear();
      _registrationDateFrom = null;
      _registrationDateTo = null;
      _lastActivityFrom = null;
      _lastActivityTo = null;
      _messageDateFrom = null;
      _messageDateTo = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = ResponsiveUtils.isMobile(context);
    final isTablet = ResponsiveUtils.isTablet(context);
    final padding = ResponsiveUtils.getResponsivePadding(context);
    final fontSize = ResponsiveUtils.getResponsiveFontSize(context, baseSize: 16.0);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Advanced Search'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.search), text: 'Search'),
            Tab(icon: Icon(Icons.bookmark), text: 'Saved'),
            Tab(icon: Icon(Icons.history), text: 'History'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildSearchTab(context, isMobile, isTablet, padding, fontSize),
          _buildSavedSearchesTab(context, isMobile, isTablet, padding, fontSize),
          _buildHistoryTab(context, isMobile, isTablet, padding, fontSize),
        ],
      ),
    );
  }

  Widget _buildSearchTab(BuildContext context, bool isMobile, bool isTablet, EdgeInsets padding, double fontSize) {
    return SingleChildScrollView(
      padding: padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Search bar
          Card(
            child: Padding(
              padding: padding,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      labelText: 'Search Query',
                      hintText: 'Search users, chats, messages...',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: () {
                                _searchController.clear();
                                setState(() => _currentQuery = '');
                              },
                            )
                          : null,
                      border: const OutlineInputBorder(),
                    ),
                    onChanged: (value) {
                      setState(() => _currentQuery = value);
                    },
                    onSubmitted: (_) => _performSearch(),
                  ),
                  const SizedBox(height: 16),
                  
                  // Type selection
                  Wrap(
                    spacing: 8,
                    children: ['users', 'chats', 'messages'].map((type) {
                      final isSelected = _selectedTypes.contains(type);
                      return FilterChip(
                        label: Text(type.toUpperCase()),
                        selected: isSelected,
                        onSelected: (selected) {
                          setState(() {
                            if (selected) {
                              _selectedTypes.add(type);
                            } else {
                              _selectedTypes.remove(type);
                            }
                          });
                        },
                      );
                    }).toList(),
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Action buttons
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _isSearching ? null : () => _performSearch(),
                          icon: _isSearching
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Icon(Icons.search),
                          label: const Text('Search'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        icon: Icon(_showFilters ? Icons.filter_list : Icons.filter_list_off),
                        onPressed: () {
                          setState(() => _showFilters = !_showFilters);
                        },
                        tooltip: 'Toggle Filters',
                      ),
                      IconButton(
                        icon: const Icon(Icons.save),
                        onPressed: _saveSearch,
                        tooltip: 'Save Search',
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          
          // Filters panel
          if (_showFilters) ...[
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: padding,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Advanced Filters', style: TextStyle(fontSize: fontSize * 1.2, fontWeight: FontWeight.bold)),
                        TextButton(
                          onPressed: _clearFilters,
                          child: const Text('Clear All'),
                        ),
                      ],
                    ),
                    const Divider(),
                    
                    // User filters
                    if (_selectedTypes.contains('users')) ...[
                      Text('User Filters', style: TextStyle(fontSize: fontSize * 1.1, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _roleFilterController,
                        decoration: const InputDecoration(
                          labelText: 'Role',
                          hintText: 'e.g., user, admin',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _statusFilterController,
                        decoration: const InputDecoration(
                          labelText: 'Status',
                          hintText: 'e.g., active, inactive',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: ListTile(
                              title: Text(_registrationDateFrom == null
                                  ? 'Registration From'
                                  : DateFormat('yyyy-MM-dd').format(_registrationDateFrom!)),
                              trailing: const Icon(Icons.calendar_today),
                              onTap: () async {
                                final date = await showDatePicker(
                                  context: context,
                                  initialDate: _registrationDateFrom ?? DateTime.now(),
                                  firstDate: DateTime(2020),
                                  lastDate: DateTime.now(),
                                );
                                if (date != null) {
                                  setState(() => _registrationDateFrom = date);
                                }
                              },
                            ),
                          ),
                          Expanded(
                            child: ListTile(
                              title: Text(_registrationDateTo == null
                                  ? 'Registration To'
                                  : DateFormat('yyyy-MM-dd').format(_registrationDateTo!)),
                              trailing: const Icon(Icons.calendar_today),
                              onTap: () async {
                                final date = await showDatePicker(
                                  context: context,
                                  initialDate: _registrationDateTo ?? DateTime.now(),
                                  firstDate: DateTime(2020),
                                  lastDate: DateTime.now(),
                                );
                                if (date != null) {
                                  setState(() => _registrationDateTo = date);
                                }
                              },
                            ),
                          ),
                        ],
                      ),
                    ],
                    
                    // Chat filters
                    if (_selectedTypes.contains('chats')) ...[
                      const SizedBox(height: 16),
                      Text('Chat Filters', style: TextStyle(fontSize: fontSize * 1.1, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _memberCountMinController,
                              decoration: const InputDecoration(
                                labelText: 'Min Members',
                                border: OutlineInputBorder(),
                              ),
                              keyboardType: TextInputType.number,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextField(
                              controller: _memberCountMaxController,
                              decoration: const InputDecoration(
                                labelText: 'Max Members',
                                border: OutlineInputBorder(),
                              ),
                              keyboardType: TextInputType.number,
                            ),
                          ),
                        ],
                      ),
                    ],
                    
                    // Message filters
                    if (_selectedTypes.contains('messages')) ...[
                      const SizedBox(height: 16),
                      Text('Message Filters', style: TextStyle(fontSize: fontSize * 1.1, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: ListTile(
                              title: Text(_messageDateFrom == null
                                  ? 'Date From'
                                  : DateFormat('yyyy-MM-dd').format(_messageDateFrom!)),
                              trailing: const Icon(Icons.calendar_today),
                              onTap: () async {
                                final date = await showDatePicker(
                                  context: context,
                                  initialDate: _messageDateFrom ?? DateTime.now(),
                                  firstDate: DateTime(2020),
                                  lastDate: DateTime.now(),
                                );
                                if (date != null) {
                                  setState(() => _messageDateFrom = date);
                                }
                              },
                            ),
                          ),
                          Expanded(
                            child: ListTile(
                              title: Text(_messageDateTo == null
                                  ? 'Date To'
                                  : DateFormat('yyyy-MM-dd').format(_messageDateTo!)),
                              trailing: const Icon(Icons.calendar_today),
                              onTap: () async {
                                final date = await showDatePicker(
                                  context: context,
                                  initialDate: _messageDateTo ?? DateTime.now(),
                                  firstDate: DateTime(2020),
                                  lastDate: DateTime.now(),
                                );
                                if (date != null) {
                                  setState(() => _messageDateTo = date);
                                }
                              },
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
          
          // Results
          if (_searchResults.isNotEmpty) ...[
            const SizedBox(height: 16),
            _buildResultsSection(context, isMobile, isTablet, padding, fontSize),
          ],
        ],
      ),
    );
  }

  Widget _buildResultsSection(BuildContext context, bool isMobile, bool isTablet, EdgeInsets padding, double fontSize) {
    final users = List<Map<String, dynamic>>.from(_searchResults['users'] ?? []);
    final chats = List<Map<String, dynamic>>.from(_searchResults['chats'] ?? []);
    final messages = List<Map<String, dynamic>>.from(_searchResults['messages'] ?? []);
    final total = _searchResults['total'] ?? 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Card(
          child: Padding(
            padding: padding,
            child: Text(
              'Search Results (${total} total)',
              style: TextStyle(fontSize: fontSize * 1.2, fontWeight: FontWeight.bold),
            ),
          ),
        ),
        
        if (users.isNotEmpty) ...[
          const SizedBox(height: 8),
          _buildUserResults(users, context, isMobile, isTablet, padding, fontSize),
        ],
        
        if (chats.isNotEmpty) ...[
          const SizedBox(height: 8),
          _buildChatResults(chats, context, isMobile, isTablet, padding, fontSize),
        ],
        
        if (messages.isNotEmpty) ...[
          const SizedBox(height: 8),
          _buildMessageResults(messages, context, isMobile, isTablet, padding, fontSize),
        ],
        
        // Pagination
        if (_totalPages > 1) ...[
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left),
                onPressed: _currentPage > 1
                    ? () {
                        setState(() => _currentPage--);
                        _performSearch(loadMore: true);
                      }
                    : null,
              ),
              Text('Page $_currentPage of $_totalPages'),
              IconButton(
                icon: const Icon(Icons.chevron_right),
                onPressed: _currentPage < _totalPages
                    ? () {
                        setState(() => _currentPage++);
                        _performSearch(loadMore: true);
                      }
                    : null,
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildUserResults(List<Map<String, dynamic>> users, BuildContext context, bool isMobile, bool isTablet, EdgeInsets padding, double fontSize) {
    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: padding,
            child: Text(
              'Users (${users.length})',
              style: TextStyle(fontSize: fontSize * 1.1, fontWeight: FontWeight.bold),
            ),
          ),
          const Divider(),
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: users.length,
            itemBuilder: (context, index) {
              final user = users[index];
              return ListTile(
                leading: CircleAvatar(
                  backgroundImage: user['profilePicture'] != null
                      ? NetworkImage(user['profilePicture'])
                      : null,
                  child: user['profilePicture'] == null
                      ? Text(user['displayName']?[0]?.toUpperCase() ?? 'U')
                      : null,
                ),
                title: Text(user['displayName'] ?? 'Unknown'),
                subtitle: Text(user['email'] ?? ''),
                trailing: IconButton(
                  icon: const Icon(Icons.arrow_forward),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => UserDetailProfileScreen(userId: user['id']),
                      ),
                    );
                  },
                ),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => UserDetailProfileScreen(userId: user['id']),
                    ),
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildChatResults(List<Map<String, dynamic>> chats, BuildContext context, bool isMobile, bool isTablet, EdgeInsets padding, double fontSize) {
    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: padding,
            child: Text(
              'Chats (${chats.length})',
              style: TextStyle(fontSize: fontSize * 1.1, fontWeight: FontWeight.bold),
            ),
          ),
          const Divider(),
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: chats.length,
            itemBuilder: (context, index) {
              final chat = chats[index];
              return ListTile(
                leading: const Icon(Icons.chat),
                title: Text(chat['name'] ?? 'Unnamed Chat'),
                subtitle: Text('${chat['memberCount'] ?? 0} members • ${chat['chatType'] ?? 'group'}'),
                trailing: Text(DateFormat('MMM d, y').format(DateTime.parse(chat['updatedAt'] ?? chat['createdAt'] ?? DateTime.now().toIso8601String()))),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildMessageResults(List<Map<String, dynamic>> messages, BuildContext context, bool isMobile, bool isTablet, EdgeInsets padding, double fontSize) {
    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: padding,
            child: Text(
              'Messages (${messages.length})',
              style: TextStyle(fontSize: fontSize * 1.1, fontWeight: FontWeight.bold),
            ),
          ),
          const Divider(),
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: messages.length,
            itemBuilder: (context, index) {
              final message = messages[index];
              return ListTile(
                leading: const Icon(Icons.message),
                title: Text(message['senderName'] ?? 'Unknown'),
                subtitle: Text(message['content'] ?? '[Media]'),
                trailing: Text(DateFormat('MMM d, y').format(DateTime.parse(message['createdAt'] ?? DateTime.now().toIso8601String()))),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSavedSearchesTab(BuildContext context, bool isMobile, bool isTablet, EdgeInsets padding, double fontSize) {
    if (_isLoadingSaved) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_savedSearches.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.bookmark_border, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            Text('No saved searches', style: TextStyle(fontSize: fontSize, color: Colors.grey)),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: padding,
      itemCount: _savedSearches.length,
      itemBuilder: (context, index) {
        final search = _savedSearches[index];
        return Card(
          child: ListTile(
            leading: const Icon(Icons.bookmark),
            title: Text(search['name'] ?? 'Unnamed Search'),
            subtitle: Text(search['query'] ?? ''),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.search),
                  onPressed: () => _loadSavedSearch(search),
                  tooltip: 'Load Search',
                ),
                IconButton(
                  icon: const Icon(Icons.delete),
                  onPressed: () async {
                    final confirmed = await showDialog<bool>(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text('Delete Saved Search'),
                        content: Text('Are you sure you want to delete "${search['name']}"?'),
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
                        await _adminService.deleteSavedSearch(search['id']);
                        _loadSavedSearches();
                      } catch (e) {
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Failed to delete: $e')),
                          );
                        }
                      }
                    }
                  },
                  tooltip: 'Delete',
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildHistoryTab(BuildContext context, bool isMobile, bool isTablet, EdgeInsets padding, double fontSize) {
    if (_isLoadingHistory) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_searchHistory.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.history, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            Text('No search history', style: TextStyle(fontSize: fontSize, color: Colors.grey)),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: padding,
      itemCount: _searchHistory.length,
      itemBuilder: (context, index) {
        final history = _searchHistory[index];
        return Card(
          child: ListTile(
            leading: const Icon(Icons.history),
            title: Text(history['query'] ?? ''),
            subtitle: Text('${history['resultCount'] ?? 0} results • ${DateFormat('MMM d, y HH:mm').format(DateTime.parse(history['createdAt'] ?? DateTime.now().toIso8601String()))}'),
            trailing: IconButton(
              icon: const Icon(Icons.search),
              onPressed: () {
                setState(() {
                  _currentQuery = history['query'] ?? '';
                  _searchController.text = _currentQuery;
                  _filters = Map<String, dynamic>.from(history['filters'] ?? {});
                  _selectedTypes = List<String>.from(history['types'] ?? ['users', 'chats', 'messages']);
                });
                _tabController.animateTo(0);
                _performSearch();
              },
              tooltip: 'Repeat Search',
            ),
          ),
        );
      },
    );
  }
}

