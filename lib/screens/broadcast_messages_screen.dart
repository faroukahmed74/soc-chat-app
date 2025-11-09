import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../config/database_config.dart';
import '../services/logger_service.dart';
import '../services/theme_service.dart';

class BroadcastMessagesScreen extends StatefulWidget {
  const BroadcastMessagesScreen({super.key});

  @override
  State<BroadcastMessagesScreen> createState() => _BroadcastMessagesScreenState();
}

class _BroadcastMessagesScreenState extends State<BroadcastMessagesScreen> {
  final ThemeService _themeService = ThemeService();
  List<Map<String, dynamic>> _broadcasts = [];
  bool _isLoading = true;
  bool _hasMore = true;
  int _currentPage = 1;
  final int _limit = 50;

  @override
  void initState() {
    super.initState();
    _loadBroadcasts();
  }

  Future<void> _loadBroadcasts({bool refresh = false}) async {
    if (refresh) {
      setState(() {
        _currentPage = 1;
        _broadcasts = [];
        _hasMore = true;
      });
    }

    if (!_hasMore && !refresh) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final token = await DatabaseConfig.getStoredAuthToken();
      if (token.isEmpty) {
        throw Exception('Not authenticated');
      }

      final baseUrl = DatabaseConfig.physicalServerUrl;
      final response = await http.get(
        Uri.parse('$baseUrl/api/broadcasts?page=$_currentPage&limit=$_limit'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
          'ngrok-skip-browser-warning': 'true',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List<dynamic> broadcasts = data['broadcasts'] ?? [];
        final pagination = data['pagination'] ?? {};

        setState(() {
          if (refresh) {
            _broadcasts = List<Map<String, dynamic>>.from(broadcasts);
          } else {
            _broadcasts.addAll(List<Map<String, dynamic>>.from(broadcasts));
          }
          _hasMore = pagination['page'] < pagination['pages'];
          _currentPage++;
          _isLoading = false;
        });
      } else {
        throw Exception('Failed to load broadcasts: ${response.statusCode}');
      }
    } catch (e) {
      Log.e('Error loading broadcasts', 'BROADCAST_SCREEN', e);
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading broadcasts: $e')),
        );
      }
    }
  }

  Future<void> _markAsRead(String broadcastId) async {
    try {
      final token = await DatabaseConfig.getStoredAuthToken();
      if (token.isEmpty) return;

      final baseUrl = DatabaseConfig.physicalServerUrl;
      await http.patch(
        Uri.parse('$baseUrl/api/broadcasts/$broadcastId/read'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
          'ngrok-skip-browser-warning': 'true',
        },
      );

      // Update local state
      setState(() {
        final index = _broadcasts.indexWhere((b) => b['id'] == broadcastId);
        if (index != -1) {
          _broadcasts[index]['read'] = true;
        }
      });
    } catch (e) {
      Log.e('Error marking broadcast as read', 'BROADCAST_SCREEN', e);
    }
  }

  String _formatDate(DateTime? date) {
    if (date == null) return '';
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0) {
      if (difference.inHours == 0) {
        if (difference.inMinutes == 0) {
          return 'Just now';
        }
        return '${difference.inMinutes}m ago';
      }
      return '${difference.inHours}h ago';
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = _themeService.isDarkMode;
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('📢 Broadcast Messages'),
        backgroundColor: isDark ? Colors.grey[900] : Colors.blue,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => _loadBroadcasts(refresh: true),
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _isLoading && _broadcasts.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : _broadcasts.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.campaign,
                        size: 64,
                        color: isDark ? Colors.white54 : Colors.black54,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No broadcast messages yet',
                        style: TextStyle(
                          fontSize: 18,
                          color: isDark ? Colors.white54 : Colors.black54,
                        ),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: () => _loadBroadcasts(refresh: true),
                  child: ListView.builder(
                    padding: const EdgeInsets.all(8),
                    itemCount: _broadcasts.length + (_hasMore ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (index == _broadcasts.length) {
                        return const Center(
                          child: Padding(
                            padding: EdgeInsets.all(16.0),
                            child: CircularProgressIndicator(),
                          ),
                        );
                      }

                      final broadcast = _broadcasts[index];
                      final isRead = broadcast['read'] == true;
                      final content = broadcast['content'] ?? '';
                      final senderName = broadcast['senderName'] ?? 'Admin';
                      final createdAt = broadcast['createdAt'] != null
                          ? DateTime.parse(broadcast['createdAt'])
                          : null;

                      // Mark as read when viewed
                      if (!isRead) {
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          _markAsRead(broadcast['id']);
                        });
                      }

                      return Card(
                        margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                        color: isRead
                            ? (isDark ? Colors.grey[800] : Colors.grey[100])
                            : (isDark ? Colors.blue[900] : Colors.blue[50]),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: isDark ? Colors.blue[700] : Colors.blue,
                            child: const Icon(Icons.campaign, color: Colors.white),
                          ),
                          title: Text(
                            senderName,
                            style: TextStyle(
                              fontWeight: isRead ? FontWeight.normal : FontWeight.bold,
                              color: isDark ? Colors.white : Colors.black87,
                            ),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 4),
                              Text(
                                content,
                                style: TextStyle(
                                  color: isDark ? Colors.white70 : Colors.black87,
                                ),
                                maxLines: 3,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _formatDate(createdAt),
                                style: TextStyle(
                                  fontSize: 12,
                                  color: isDark ? Colors.white54 : Colors.black54,
                                ),
                              ),
                            ],
                          ),
                          isThreeLine: true,
                          onTap: () {
                            // Show full message in dialog
                            showDialog(
                              context: context,
                              builder: (context) => AlertDialog(
                                title: Row(
                                  children: [
                                    const Icon(Icons.campaign, color: Colors.blue),
                                    const SizedBox(width: 8),
                                    Text(senderName),
                                  ],
                                ),
                                content: SingleChildScrollView(
                                  child: Text(content),
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(context),
                                    child: const Text('Close'),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}

