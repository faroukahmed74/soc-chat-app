import 'package:flutter/material.dart';
import '../services/call_history_service.dart';
import '../services/logger_service.dart';
import '../utils/responsive_utils.dart';
import 'call_screen.dart';
import 'call_types.dart';

/// Call History Screen
/// Displays call history with filters and search
class CallHistoryScreen extends StatefulWidget {
  final String? chatId; // Optional: filter by chat
  final String? initialFilter; // Optional: initial status filter

  const CallHistoryScreen({
    Key? key,
    this.chatId,
    this.initialFilter,
  }) : super(key: key);

  @override
  State<CallHistoryScreen> createState() => _CallHistoryScreenState();
}

class _CallHistoryScreenState extends State<CallHistoryScreen> {
  final _callHistoryService = CallHistoryService();
  List<CallHistoryItem> _calls = [];
  bool _isLoading = true;
  bool _hasMore = true;
  int _currentPage = 1;
  final int _pageSize = 20;
  String? _selectedFilter; // 'all', 'missed', 'completed', 'rejected'
  String? _selectedCallType; // 'all', 'voice', 'video'

  @override
  void initState() {
    super.initState();
    _selectedFilter = widget.initialFilter ?? 'all';
    _selectedCallType = 'all';
    _loadCallHistory();
  }

  Future<void> _loadCallHistory({bool refresh = false}) async {
    if (refresh) {
      _currentPage = 1;
      _calls.clear();
      _hasMore = true;
    }

    if (!_hasMore && !refresh) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final result = await _callHistoryService.getCallHistory(
        page: _currentPage,
        limit: _pageSize,
        chatId: widget.chatId,
        status: _selectedFilter != 'all' ? _selectedFilter : null,
        callType: _selectedCallType != 'all' ? _selectedCallType : null,
      );

      if (result != null && result['calls'] != null) {
        final newCalls = (result['calls'] as List)
            .map((call) => CallHistoryItem.fromJson(call))
            .toList();

        setState(() {
          if (refresh) {
            _calls = newCalls;
          } else {
            _calls.addAll(newCalls);
          }
          _hasMore = newCalls.length == _pageSize;
          _currentPage++;
          _isLoading = false;
        });
      } else {
        setState(() {
          _hasMore = false;
          _isLoading = false;
        });
      }
    } catch (e) {
      Log.e('Error loading call history', 'CALL_HISTORY_SCREEN', e);
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading call history: $e')),
        );
      }
    }
  }

  void _onFilterChanged(String? filter) {
    setState(() {
      _selectedFilter = filter;
    });
    _loadCallHistory(refresh: true);
  }

  void _onCallTypeChanged(String? callType) {
    setState(() {
      _selectedCallType = callType;
    });
    _loadCallHistory(refresh: true);
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = ResponsiveUtils.isMobile(context);
    final isTablet = ResponsiveUtils.isTablet(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Call History'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => _loadCallHistory(refresh: true),
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: Column(
        children: [
          // Filters
          _buildFilters(isMobile),
          // Call list
          Expanded(
            child: _isLoading && _calls.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : _calls.isEmpty
                    ? _buildEmptyState()
                    : _buildCallList(isMobile, isTablet),
          ),
        ],
      ),
    );
  }

  Widget _buildFilters(bool isMobile) {
    return Container(
      padding: EdgeInsets.all(isMobile ? 8 : 12),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // Status filter
          Row(
            children: [
              Text(
                'Status:',
                style: TextStyle(
                  fontSize: isMobile ? 14 : 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(value: 'all', label: Text('All')),
                    ButtonSegment(value: 'completed', label: Text('Completed')),
                    ButtonSegment(value: 'missed', label: Text('Missed')),
                    ButtonSegment(value: 'rejected', label: Text('Rejected')),
                  ],
                  selected: {_selectedFilter ?? 'all'},
                  onSelectionChanged: (Set<String> selected) {
                    _onFilterChanged(selected.first);
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Call type filter
          Row(
            children: [
              Text(
                'Type:',
                style: TextStyle(
                  fontSize: isMobile ? 14 : 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(value: 'all', label: Text('All')),
                    ButtonSegment(value: 'voice', label: Text('Voice')),
                    ButtonSegment(value: 'video', label: Text('Video')),
                  ],
                  selected: {_selectedCallType ?? 'all'},
                  onSelectionChanged: (Set<String> selected) {
                    _onCallTypeChanged(selected.first);
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.call_end,
            size: 64,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            'No call history',
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Your call history will appear here',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[500],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCallList(bool isMobile, bool isTablet) {
    return RefreshIndicator(
      onRefresh: () => _loadCallHistory(refresh: true),
      child: ListView.builder(
        itemCount: _calls.length + (_hasMore ? 1 : 0),
        itemBuilder: (context, index) {
          if (index == _calls.length) {
            // Load more indicator
            if (_hasMore) {
              _loadCallHistory();
              return const Center(
                child: Padding(
                  padding: EdgeInsets.all(16.0),
                  child: CircularProgressIndicator(),
                ),
              );
            }
            return const SizedBox.shrink();
          }

          final call = _calls[index];
          return _buildCallItem(call, isMobile, isTablet);
        },
      ),
    );
  }

  Widget _buildCallItem(CallHistoryItem call, bool isMobile, bool isTablet) {
    final isVideo = call.callType == 'video';
    final isMissed = call.status == 'missed';
    final isRejected = call.status == 'rejected';
    final isIncoming = call.direction == 'incoming';

    return ListTile(
      leading: CircleAvatar(
        backgroundColor: isVideo ? Colors.blue : Colors.green,
        child: Icon(
          isVideo ? Icons.videocam : Icons.phone,
          color: Colors.white,
        ),
      ),
      title: Row(
        children: [
          Expanded(
            child: Text(
              call.chatName,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: isMissed || isRejected ? Colors.red : null,
              ),
            ),
          ),
          if (isIncoming)
            Icon(
              Icons.call_received,
              size: 16,
              color: Colors.grey[600],
            )
          else
            Icon(
              Icons.call_made,
              size: 16,
              color: Colors.grey[600],
            ),
        ],
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 4),
          Row(
            children: [
              Text(
                _formatDate(call.startedAt),
                style: TextStyle(
                  fontSize: isMobile ? 12 : 14,
                  color: Colors.grey[600],
                ),
              ),
              const SizedBox(width: 8),
              if (call.duration > 0)
                Text(
                  '• ${call.formattedDuration}',
                  style: TextStyle(
                    fontSize: isMobile ? 12 : 14,
                    color: Colors.grey[600],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            call.statusDisplay,
            style: TextStyle(
              fontSize: isMobile ? 11 : 12,
              color: isMissed || isRejected ? Colors.red : Colors.green,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
      trailing: IconButton(
        icon: Icon(
          isVideo ? Icons.videocam : Icons.phone,
          color: Theme.of(context).primaryColor,
        ),
        onPressed: () {
          // Navigate to call screen to redial
          // Note: This would require participant IDs which we'd need to fetch
          // For now, just show a message
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Redial functionality coming soon'),
              duration: const Duration(seconds: 2),
            ),
          );
        },
        tooltip: 'Redial',
      ),
      onTap: () {
        // Show call details
        _showCallDetails(call);
      },
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0) {
      // Today
      return 'Today ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    } else if (difference.inDays == 1) {
      // Yesterday
      return 'Yesterday ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    } else if (difference.inDays < 7) {
      // This week
      final weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
      return '${weekdays[date.weekday - 1]} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    } else {
      // Older
      return '${date.day}/${date.month}/${date.year} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    }
  }

  void _showCallDetails(CallHistoryItem call) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(call.chatName),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildDetailRow('Type', call.callType == 'video' ? 'Video Call' : 'Voice Call'),
            _buildDetailRow('Direction', call.direction == 'incoming' ? 'Incoming' : 'Outgoing'),
            _buildDetailRow('Status', call.statusDisplay),
            _buildDetailRow('Started', _formatDate(call.startedAt)),
            if (call.answeredAt != null)
              _buildDetailRow('Answered', _formatDate(call.answeredAt!)),
            if (call.endedAt != null)
              _buildDetailRow('Ended', _formatDate(call.endedAt!)),
            if (call.duration > 0)
              _buildDetailRow('Duration', call.formattedDuration),
            if (call.isGroupChat)
              _buildDetailRow('Participants', '${call.participantIds.length + 1}'),
            if (call.qualityMetrics != null && call.qualityMetrics!.isNotEmpty) ...[
              const Divider(),
              const Text('Quality Metrics:', style: TextStyle(fontWeight: FontWeight.bold)),
              if (call.qualityMetrics!['networkQuality'] != null)
                _buildDetailRow('Network', call.qualityMetrics!['networkQuality'].toString().toUpperCase()),
              if (call.qualityMetrics!['connectionScore'] != null)
                _buildDetailRow('Score', '${call.qualityMetrics!['connectionScore']}%'),
            ],
          ],
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

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
          Expanded(
            child: Text(value),
          ),
        ],
      ),
    );
  }
}

