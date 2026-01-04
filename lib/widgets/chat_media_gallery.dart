import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/mongodb_chat_service.dart';
import '../services/logger_service.dart';
import '../services/media_download_service.dart';
import '../services/media_download_manager.dart';
import '../utils/responsive_utils.dart';
import 'full_screen_media_preview.dart';
import 'media_download_progress_indicator.dart';
import 'whatsapp_download_indicator.dart';
import 'dart:async';

class ChatMediaGallery extends StatefulWidget {
  final String chatId;
  final String chatName;

  const ChatMediaGallery({
    super.key,
    required this.chatId,
    required this.chatName,
  });

  @override
  State<ChatMediaGallery> createState() => _ChatMediaGalleryState();
}

class _ChatMediaGalleryState extends State<ChatMediaGallery>
    with SingleTickerProviderStateMixin {
  final MongoDBChatService _chatService = MongoDBChatService();

  bool _isLoading = true;
  String? _error;
  List<MediaCategorySummary> _categories = [];

  TabController? _tabController;
  final Map<String, MediaTabState> _tabStates = {};

  @override
  void initState() {
    super.initState();
    _loadMediaSummary();
  }

  Future<void> _loadMediaSummary() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final summary = await _chatService.fetchMediaSummary(widget.chatId);
      if (!mounted) return;

      // Filter out text messages - only show media types
      final mediaOnlyCategories = summary.where((category) {
        final type = category.type.toLowerCase();
        return type != 'text' && 
               type != 'message' && 
               (type == 'image' || type == 'video' || type == 'document' || type == 'audio');
      }).toList();

      setState(() {
        _categories = mediaOnlyCategories;
        _isLoading = false;
      });

      if (_categories.isNotEmpty) {
        _tabController = TabController(
          length: _categories.length,
          vsync: this,
        );
        _tabController!.addListener(() {
          final type = _categories[_tabController!.index].type;
          _ensureTabLoaded(type);
        });
        _ensureTabLoaded(_categories.first.type);
      }
    } catch (e, stack) {
      Log.e('Media summary load error', 'CHAT_MEDIA_GALLERY', e, stack);
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _error = 'Failed to load media summary: $e';
      });
    }
  }

  void _ensureTabLoaded(String type) {
    final state = _tabStates[type];
    if (state == null || (!state.isLoading && state.items.isEmpty && !state.hasReachedEnd)) {
      _loadTabPage(type);
    }
  }

  Future<void> _loadTabPage(String type, {bool refresh = false}) async {
    final existing = _tabStates[type] ??
        MediaTabState(
          type: type,
          page: 1,
          hasReachedEnd: false,
          isLoading: false,
          items: [],
        );
    if (existing.isLoading || (existing.hasReachedEnd && !refresh)) return;

    setState(() {
      _tabStates[type] = existing.copyWith(isLoading: true, error: null);
    });

    try {
      final page = refresh ? 1 : existing.page;
      final result = await _chatService.fetchMediaByType(
        widget.chatId,
        type: type,
        page: page,
      );

      if (!mounted) return;

      // Filter out text messages - only keep media items
      final mediaItems = result.messages.where((item) {
        final messageType = (item['messageType'] ?? item['type'] ?? '').toString().toLowerCase();
        final hasMediaUrl = (item['mediaUrl'] ?? item['media_url'] ?? '').toString().isNotEmpty;
        return messageType != 'text' && 
               messageType != 'message' && 
               hasMediaUrl &&
               (messageType == 'image' || 
                messageType == 'video' || 
                messageType == 'document' || 
                messageType == 'audio');
      }).toList();

      final newItems = refresh ? mediaItems : [...existing.items, ...mediaItems];
      final hasMore = result.hasMore;

      setState(() {
        _tabStates[type] = existing.copyWith(
          isLoading: false,
          page: hasMore ? page + 1 : page,
          hasReachedEnd: !hasMore,
          items: newItems,
          error: null,
        );
      });
    } catch (e, stack) {
      Log.e('Media tab load error ($type)', 'CHAT_MEDIA_GALLERY', e, stack);
      if (!mounted) return;
      setState(() {
        _tabStates[type] = existing.copyWith(
          isLoading: false,
          error: e.toString(),
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.chatName),
            Text(
              'Media',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onPrimary.withOpacity(0.8),
              ),
            )
          ],
        ),
        bottom: _categories.isNotEmpty && _tabController != null
            ? TabBar(
                controller: _tabController,
                isScrollable: true,
                tabs: _categories
                    .map(
                      (category) => Tab(
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              _iconForType(category.type),
                              size: 18,
                            ),
                            const SizedBox(width: 6),
                            Text('${category.label} (${category.count})'),
                          ],
                        ),
                      ),
                    )
                    .toList(),
              )
            : null,
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return _buildErrorState(_error!, onRetry: _loadMediaSummary);
    }
    if (_categories.isEmpty) {
      return _buildEmptyState(
        title: 'No media yet',
        description: 'Images, videos, and documents shared in this chat will appear here.',
      );
    }

    return TabBarView(
      controller: _tabController,
      children: _categories.map((category) {
        final tabState = _tabStates[category.type] ??
            MediaTabState(
              type: category.type,
              page: 1,
              hasReachedEnd: false,
              isLoading: false,
              items: [],
            );
        return _MediaTabView(
          tabState: tabState,
          onLoadMore: () => _loadTabPage(category.type),
          onRefresh: () => _loadTabPage(category.type, refresh: true),
        );
      }).toList(),
    );
  }

  IconData _iconForType(String type) {
    switch (type) {
      case 'image':
        return Icons.photo;
      case 'video':
        return Icons.videocam;
      case 'document':
        return Icons.description;
      case 'audio':
        return Icons.audiotrack;
      default:
        return Icons.insert_drive_file;
    }
  }

  Widget _buildErrorState(String message, {VoidCallback? onRetry}) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.redAccent),
            const SizedBox(height: 16),
            Text(
              'Failed to load media',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState({
    required String title,
    required String description,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.photo_library_outlined, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            Text(
              title,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              description,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
}

class MediaTabState {
  final String type;
  final int page;
  final bool hasReachedEnd;
  final bool isLoading;
  final List<Map<String, dynamic>> items;
  final String? error;

  MediaTabState({
    required this.type,
    required this.page,
    required this.hasReachedEnd,
    required this.isLoading,
    required this.items,
    this.error,
  });

  MediaTabState copyWith({
    int? page,
    bool? hasReachedEnd,
    bool? isLoading,
    List<Map<String, dynamic>>? items,
    String? error,
  }) {
    return MediaTabState(
      type: type,
      page: page ?? this.page,
      hasReachedEnd: hasReachedEnd ?? this.hasReachedEnd,
      isLoading: isLoading ?? this.isLoading,
      items: items ?? this.items,
      error: error,
    );
  }
}

class _MediaTabView extends StatefulWidget {
  final MediaTabState tabState;
  final Future<void> Function() onLoadMore;
  final Future<void> Function() onRefresh;

  const _MediaTabView({
    required this.tabState,
    required this.onLoadMore,
    required this.onRefresh,
  });

  @override
  State<_MediaTabView> createState() => _MediaTabViewState();
}

class _MediaTabViewState extends State<_MediaTabView> {
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >
            _scrollController.position.maxScrollExtent - 200 &&
        !widget.tabState.isLoading &&
        !widget.tabState.hasReachedEnd) {
      widget.onLoadMore();
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.tabState;

    if (state.error != null && state.items.isEmpty) {
      return _buildErrorState(state.error!);
    }

    if (state.items.isEmpty && state.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (state.items.isEmpty) {
      return _buildEmptyState();
    }

    if (state.type == 'image' || state.type == 'video') {
      return _buildMediaGrid();
    }

    return _buildDocumentList();
  }

  Widget _buildMediaGrid() {
    final state = widget.tabState;
    final isVideo = state.type == 'video';

    return RefreshIndicator(
      onRefresh: widget.onRefresh,
      child: GridView.builder(
        controller: _scrollController,
        padding: const EdgeInsets.all(12),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          crossAxisSpacing: 8,
          mainAxisSpacing: 8,
          childAspectRatio: 1,
        ),
        itemCount: state.items.length + (state.isLoading && !state.hasReachedEnd ? 1 : 0),
        itemBuilder: (context, index) {
          if (index >= state.items.length) {
            return const Center(child: CircularProgressIndicator(strokeWidth: 2));
          }
          final item = state.items[index];
          return _MediaThumbnailCard(
            item: item,
            isVideo: isVideo,
          );
        },
      ),
    );
  }

  Widget _buildDocumentList() {
    final state = widget.tabState;

    return RefreshIndicator(
      onRefresh: widget.onRefresh,
      child: ListView.builder(
        controller: _scrollController,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        itemCount: state.items.length + (state.isLoading && !state.hasReachedEnd ? 1 : 0),
        itemBuilder: (context, index) {
          if (index >= state.items.length) {
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
            );
          }
          final item = state.items[index];
          return _DocumentTile(item: item);
        },
      ),
    );
  }

  Widget _buildErrorState(String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 42, color: Colors.redAccent),
            const SizedBox(height: 12),
            Text(
              'Failed to load',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: widget.onRefresh,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.inbox_outlined, size: 48, color: Colors.grey),
            const SizedBox(height: 12),
            Text(
              'No ${widget.tabState.type}s yet',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 6),
            const Text(
              'Media shared in this category will appear here.',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _MediaThumbnailCard extends StatelessWidget {
  final Map<String, dynamic> item;
  final bool isVideo;

  const _MediaThumbnailCard({
    required this.item,
    required this.isVideo,
  });

  @override
  Widget build(BuildContext context) {
    final mediaUrl = item['mediaUrl'] ?? item['media_url'] ?? '';
    final createdAt = item['createdAt'];
    final timestamp = createdAt != null
        ? DateTime.tryParse(createdAt.toString())
        : null;
    final caption = item['content']?.toString() ?? '';

    return InkWell(
      onTap: () => _openFullScreen(context, item),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (mediaUrl.isNotEmpty)
              Image.network(
                mediaUrl,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  color: Colors.grey.shade300,
                  child: const Icon(Icons.broken_image),
                ),
              )
            else
              Container(
                alignment: Alignment.center,
                color: Colors.grey.shade200,
                child: Icon(
                  isVideo ? Icons.videocam : Icons.photo,
                  color: Colors.grey,
                  size: 36,
                ),
              ),
            if (isVideo)
              const Align(
                alignment: Alignment.center,
                child: Icon(
                  Icons.play_circle_outline,
                  size: 42,
                  color: Colors.white70,
                ),
              ),
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.black.withOpacity(0.7),
                      Colors.transparent,
                    ],
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (timestamp != null)
                      Text(
                        _formatTimestamp(timestamp),
                        style: const TextStyle(color: Colors.white, fontSize: 10),
                      ),
                    if (caption.isNotEmpty)
                      Text(
                        caption,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                  ],
                ),
              ),
            ),
            Positioned(
              top: 4,
              right: 4,
              child: _MediaContextMenu(item: item),
            ),
          ],
        ),
      ),
    );
  }

  String _formatTimestamp(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);
    if (difference.inDays == 0) {
      return '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else if (difference.inDays < 7) {
      return ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'][dateTime.weekday - 1];
    } else {
      return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
    }
  }

  void _openFullScreen(BuildContext context, Map<String, dynamic> item) {
    // Reuse existing full-screen preview widget
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => FullScreenMediaPreview(
          mediaUrl: item['mediaUrl'] ?? item['media_url'] ?? '',
          mediaType: item['messageType'] ?? item['type'] ?? 'image',
          fileName: item['fileName'] ?? item['id']?.toString(),
        ),
      ),
    );
  }
}

class _MediaContextMenu extends StatelessWidget {
  final Map<String, dynamic> item;

  const _MediaContextMenu({required this.item});

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      icon: Container(
        decoration: BoxDecoration(
          color: Colors.black45,
          borderRadius: BorderRadius.circular(20),
        ),
        padding: const EdgeInsets.all(6),
        child: const Icon(Icons.more_vert, color: Colors.white, size: 18),
      ),
      onSelected: (value) {
        switch (value) {
          case 'download':
            _downloadMedia(context);
            break;
          case 'share':
            _shareMedia(context);
            break;
        }
      },
      itemBuilder: (_) => [
        const PopupMenuItem(
          value: 'download',
          child: ListTile(
            leading: Icon(Icons.download),
            title: Text('Download'),
          ),
        ),
        const PopupMenuItem(
          value: 'share',
          child: ListTile(
            leading: Icon(Icons.share),
            title: Text('Share'),
          ),
        ),
      ],
    );
  }

  void _downloadMedia(BuildContext context) {
    final mediaUrl = item['mediaUrl'] ?? item['media_url'] ?? '';
    if (mediaUrl.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Media not available')),
      );
      return;
    }

    _showDownloadProgress(context, mediaUrl);
  }

  void _showDownloadProgress(BuildContext context, String url) {
    final mediaType = item['messageType'] ?? item['type'] ?? 'image';
    final fileName = item['fileName']?.toString();
    
    // Use MediaDownloadManager for proper progress tracking
    MediaDownloadManager().download(
      url: url,
      mediaType: mediaType,
      fileName: fileName,
      onProgress: (info) {
        // Progress updates are handled by the manager
      },
    ).then((successMessage) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(successMessage),
            backgroundColor: Colors.green,
          ),
        );
      }
    }).catchError((e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Download failed: $e')),
        );
      }
    });
  }

  void _shareMedia(BuildContext context) {
    // TODO: integrate share functionality (Share plugin)
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Share coming soon')),
    );
  }
}

class _DocumentTile extends StatelessWidget {
  final Map<String, dynamic> item;

  const _DocumentTile({required this.item});

  @override
  Widget build(BuildContext context) {
    final mediaUrl = item['mediaUrl'] ?? item['media_url'] ?? '';
    final fileName = item['fileName']?.toString() ??
        _fallbackFileName(item['id']?.toString(), item['messageType']);
    final size = item['fileSize']?.toString() ?? '';
    final timestamp = item['createdAt'] != null
        ? DateTime.tryParse(item['createdAt'].toString())
        : null;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Theme.of(context).colorScheme.primary.withOpacity(0.15),
          child: Icon(
            Icons.description,
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
        title: Text(
          fileName,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (size.isNotEmpty) Text(_formatFileSizeString(size)),
            if (timestamp != null) Text(_formatTimestamp(timestamp)),
          ],
        ),
        trailing: IconButton(
          icon: const Icon(Icons.download),
          onPressed: () => _downloadDocument(context, mediaUrl),
        ),
        onTap: () => _openDocument(context, mediaUrl),
      ),
    );
  }

  String _fallbackFileName(String? id, String? type) {
    if (id == null) return 'document';
    final extension = type?.contains('pdf') == true ? '.pdf' : '.bin';
    return 'document_$id$extension';
  }

  String _formatFileSizeString(String size) {
    try {
      final bytes = double.parse(size);
      if (bytes < 1024) return '${bytes.toStringAsFixed(0)} B';
      if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
      if (bytes < 1024 * 1024 * 1024) {
        return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
      }
      return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
    } catch (_) {
      return size;
    }
  }

  String _formatTimestamp(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);
    if (difference.inDays == 0) {
      return '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else if (difference.inDays < 7) {
      return ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'][dateTime.weekday - 1];
    } else {
      return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
    }
  }

  void _downloadDocument(BuildContext context, String url) {
    if (url.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Document not available')),
      );
      return;
    }

    MediaDownloadService.saveToDevice(
      url: url,
      mediaType: 'document',
      fileName: item['fileName']?.toString(),
    ).then((successMessage) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(successMessage)),
      );
    }).catchError((e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Download failed: $e')),
      );
    });
  }

  void _openDocument(BuildContext context, String url) async {
    if (url.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Document not available')),
      );
      return;
    }

    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cannot open document')),
      );
    }
  }
}

