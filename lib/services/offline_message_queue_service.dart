import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'package:dio/dio.dart';
import '../config/database_config.dart';
import 'connectivity_service.dart';
import 'local_message_storage.dart';
import 'logger_service.dart';
import 'mongodb_chat_service.dart';

/// Status of a queued offline message.
enum OfflineMessageStatus { pending, sending, failed }

/// A message waiting to be sent when connectivity returns.
class QueuedMessage {
  final String localId;
  final String chatId;
  final String content;
  final String messageType;
  final String? mediaUrl;
  final String? localMediaPath;
  final String? mimeType;
  final String? fileName;
  final String? replyToMessageId;
  final String? senderId;
  final String? senderName;
  final DateTime createdAt;
  OfflineMessageStatus status;
  int retryCount;

  QueuedMessage({
    required this.localId,
    required this.chatId,
    required this.content,
    this.messageType = 'text',
    this.mediaUrl,
    this.localMediaPath,
    this.mimeType,
    this.fileName,
    this.replyToMessageId,
    this.senderId,
    this.senderName,
    required this.createdAt,
    this.status = OfflineMessageStatus.pending,
    this.retryCount = 0,
  });

  Map<String, dynamic> toJson() => {
        'localId': localId,
        'chatId': chatId,
        'content': content,
        'messageType': messageType,
        'mediaUrl': mediaUrl,
        'localMediaPath': localMediaPath,
        'mimeType': mimeType,
        'fileName': fileName,
        'replyToMessageId': replyToMessageId,
        'senderId': senderId,
        'senderName': senderName,
        'createdAt': createdAt.toIso8601String(),
        'status': status.name,
        'retryCount': retryCount,
      };

  factory QueuedMessage.fromJson(Map<String, dynamic> json) {
    return QueuedMessage(
      localId: json['localId']?.toString() ?? '',
      chatId: json['chatId']?.toString() ?? '',
      content: json['content']?.toString() ?? '',
      messageType: json['messageType']?.toString() ?? 'text',
      mediaUrl: json['mediaUrl']?.toString(),
      localMediaPath: json['localMediaPath']?.toString(),
      mimeType: json['mimeType']?.toString(),
      fileName: json['fileName']?.toString(),
      replyToMessageId: json['replyToMessageId']?.toString(),
      senderId: json['senderId']?.toString(),
      senderName: json['senderName']?.toString(),
      createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? '') ??
          DateTime.now(),
      status: OfflineMessageStatus.values.firstWhere(
        (s) => s.name == json['status'],
        orElse: () => OfflineMessageStatus.pending,
      ),
      retryCount: json['retryCount'] is int ? json['retryCount'] as int : 0,
    );
  }

  /// Convert to an optimistic in-chat message map for UI display.
  Map<String, dynamic> toDisplayMessage() => {
        'id': localId,
        '_id': localId,
        'localId': localId,
        'chatId': chatId,
        'senderId': senderId,
        'senderName': senderName,
        'content': content,
        'messageType': messageType,
        'type': messageType,
        'mediaUrl': mediaUrl ?? localMediaPath,
        'createdAt': createdAt.toIso8601String(),
        'timestamp': createdAt.toIso8601String(),
        'status': status == OfflineMessageStatus.failed ? 'failed' : 'pending',
        'isOfflinePending': true,
        'readBy': <String>[],
        if (replyToMessageId != null) 'replyTo': replyToMessageId,
      };
}

/// Queues outbound messages while offline and sends them when back online.
class OfflineMessageQueueService {
  OfflineMessageQueueService._();
  static final OfflineMessageQueueService instance =
      OfflineMessageQueueService._();

  static const String _queueKey = 'offline_message_queue_v1';
  static const String _queueMediaDir = 'offline_queue_media';
  static const int _maxRetries = 5;

  final MongoDBChatService _chatService = MongoDBChatService();
  final _uuid = const Uuid();
  final _changeController = StreamController<void>.broadcast();

  List<QueuedMessage> _queue = [];
  bool _initialized = false;
  bool _syncing = false;

  Stream<void> get onQueueChanged => _changeController.stream;
  int get pendingCount =>
      _queue.where((m) => m.status != OfflineMessageStatus.failed).length;
  bool get isSyncing => _syncing;

  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;
    await _loadQueue();

    ConnectivityService.instance.addListener(_onConnectivityChanged);
    Log.i('OfflineMessageQueueService initialized (${_queue.length} queued)',
        'OFFLINE_QUEUE');
  }

  void _onConnectivityChanged(bool isOnline) {
    if (isOnline) {
      unawaited(syncAll());
    }
  }

  void _notifyChanged() {
    if (!_changeController.isClosed) {
      _changeController.add(null);
    }
  }

  Future<void> _loadQueue() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_queueKey);
      if (raw == null || raw.isEmpty) {
        _queue = [];
        return;
      }
      final list = json.decode(raw) as List;
      _queue = list
          .map((e) => QueuedMessage.fromJson(Map<String, dynamic>.from(e as Map)))
          .where((m) => m.localId.isNotEmpty && m.chatId.isNotEmpty)
          .toList();
    } catch (e) {
      Log.e('Failed to load offline queue', 'OFFLINE_QUEUE', e);
      _queue = [];
    }
  }

  Future<void> _saveQueue() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _queueKey,
        json.encode(_queue.map((m) => m.toJson()).toList()),
      );
    } catch (e) {
      Log.e('Failed to save offline queue', 'OFFLINE_QUEUE', e);
    }
  }

  List<QueuedMessage> getQueueForChat(String chatId) =>
      _queue.where((m) => m.chatId == chatId).toList();

  List<Map<String, dynamic>> getDisplayMessagesForChat(String chatId) =>
      getQueueForChat(chatId).map((m) => m.toDisplayMessage()).toList();

  /// Queue a text message (or reply).
  Future<QueuedMessage> enqueueText({
    required String chatId,
    required String content,
    String? replyToMessageId,
    String? senderId,
    String? senderName,
  }) async {
    final item = QueuedMessage(
      localId: 'offline_${_uuid.v4()}',
      chatId: chatId,
      content: content,
      messageType: 'text',
      replyToMessageId: replyToMessageId,
      senderId: senderId,
      senderName: senderName,
      createdAt: DateTime.now(),
    );
    _queue.add(item);
    await _saveQueue();
    await _cacheOptimisticMessage(item);
    _notifyChanged();
    Log.i('Queued text message ${item.localId} for chat $chatId', 'OFFLINE_QUEUE');
    return item;
  }

  /// Queue a media message. Saves bytes to local storage when provided.
  Future<QueuedMessage> enqueueMedia({
    required String chatId,
    required String messageType,
    String content = '',
    String? mediaUrl,
    Uint8List? mediaBytes,
    String? mimeType,
    String? fileName,
    String? senderId,
    String? senderName,
  }) async {
    String? localPath;
    if (mediaBytes != null && mediaBytes.isNotEmpty) {
      localPath = await _saveMediaBytes(mediaBytes, fileName ?? 'media.bin');
    }

    final item = QueuedMessage(
      localId: 'offline_${_uuid.v4()}',
      chatId: chatId,
      content: content.isNotEmpty ? content : 'Media message',
      messageType: messageType,
      mediaUrl: mediaUrl,
      localMediaPath: localPath,
      mimeType: mimeType,
      fileName: fileName,
      senderId: senderId,
      senderName: senderName,
      createdAt: DateTime.now(),
    );
    _queue.add(item);
    await _saveQueue();
    await _cacheOptimisticMessage(item);
    _notifyChanged();
    Log.i('Queued media message ${item.localId} ($messageType)', 'OFFLINE_QUEUE');
    return item;
  }

  Future<String?> _saveMediaBytes(Uint8List bytes, String fileName) async {
    try {
      if (kIsWeb) {
        // Web: store as base64 in a sidecar prefs key (path = key reference)
        final key = 'offline_media_${DateTime.now().millisecondsSinceEpoch}_$fileName';
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(key, base64Encode(bytes));
        return 'prefs:$key';
      }
      final dir = await _mediaDirectory();
      final file = File('${dir.path}/$fileName');
      await file.writeAsBytes(bytes, flush: true);
      return file.path;
    } catch (e) {
      Log.e('Failed to save offline media bytes', 'OFFLINE_QUEUE', e);
      return null;
    }
  }

  Future<Directory> _mediaDirectory() async {
    final base = await getApplicationDocumentsDirectory();
    final dir = Directory('${base.path}/$_queueMediaDir');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  Future<Uint8List?> _readMediaBytes(String? path) async {
    if (path == null || path.isEmpty) return null;
    try {
      if (path.startsWith('prefs:')) {
        final key = path.substring(6);
        final prefs = await SharedPreferences.getInstance();
        final b64 = prefs.getString(key);
        if (b64 == null) return null;
        return base64Decode(b64);
      }
      if (kIsWeb) return null;
      final file = File(path);
      if (!await file.exists()) return null;
      return await file.readAsBytes();
    } catch (e) {
      Log.e('Failed to read offline media at $path', 'OFFLINE_QUEUE', e);
      return null;
    }
  }

  Future<void> _cacheOptimisticMessage(QueuedMessage item) async {
    await LocalMessageStorage.upsertChatMessage(
      item.chatId,
      item.toDisplayMessage(),
    );
  }

  Future<void> removeFromQueue(String localId) async {
    final item = _queue.where((m) => m.localId == localId).toList();
    _queue.removeWhere((m) => m.localId == localId);
    await _saveQueue();
    for (final m in item) {
      await _deleteLocalMedia(m.localMediaPath);
    }
    _notifyChanged();
  }

  Future<void> _deleteLocalMedia(String? path) async {
    if (path == null || path.isEmpty) return;
    try {
      if (path.startsWith('prefs:')) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove(path.substring(6));
        return;
      }
      if (!kIsWeb) {
        final file = File(path);
        if (await file.exists()) await file.delete();
      }
    } catch (_) {}
  }

  /// Retry a failed queued message.
  Future<void> retry(String localId) async {
    final item = _queue.firstWhere(
      (m) => m.localId == localId,
      orElse: () => throw StateError('Not found'),
    );
    item.status = OfflineMessageStatus.pending;
    item.retryCount = 0;
    await _saveQueue();
    _notifyChanged();
    await syncAll();
  }

  /// Process all pending messages (newest chats first, FIFO per chat).
  Future<void> syncAll() async {
    if (_syncing) return;
    if (!ConnectivityService.instance.isOnline) return;
    if (_queue.isEmpty) return;

    _syncing = true;
    _notifyChanged();

    try {
      final pending = _queue
          .where((m) =>
              m.status == OfflineMessageStatus.pending ||
              m.status == OfflineMessageStatus.failed)
          .toList()
        ..sort((a, b) => a.createdAt.compareTo(b.createdAt));

      for (final item in pending) {
        if (!ConnectivityService.instance.isOnline) break;
        await _sendQueuedItem(item);
      }
    } finally {
      _syncing = false;
      _notifyChanged();
    }
  }

  Future<void> _sendQueuedItem(QueuedMessage item) async {
    item.status = OfflineMessageStatus.sending;
    await _saveQueue();
    _notifyChanged();

    try {
      Map<String, dynamic>? result;

      if (item.messageType == 'text') {
        if (item.replyToMessageId != null &&
            item.replyToMessageId!.isNotEmpty) {
          result = await _chatService.replyToMessage(
            item.replyToMessageId!,
            item.content,
          );
        } else {
          result = await _chatService.sendTextMessage(item.chatId, item.content);
        }
      } else {
        var mediaUrl = item.mediaUrl;
        if ((mediaUrl == null || mediaUrl.isEmpty) &&
            item.localMediaPath != null) {
          mediaUrl = await _uploadLocalMedia(item);
        }
        if (mediaUrl == null || mediaUrl.isEmpty) {
          throw Exception('Media upload failed for queued message');
        }
        result = await _chatService.sendMediaMessage(
          item.chatId,
          mediaUrl,
          item.messageType,
          content: item.content,
        );
      }

      if (result != null) {
        await removeFromQueue(item.localId);
        Log.i('Sent queued message ${item.localId}', 'OFFLINE_QUEUE');
      } else {
        throw Exception('Server returned null');
      }
    } catch (e) {
      item.retryCount += 1;
      item.status = item.retryCount >= _maxRetries
          ? OfflineMessageStatus.failed
          : OfflineMessageStatus.pending;
      await _saveQueue();
      _notifyChanged();
      Log.e('Failed to send queued message ${item.localId}', 'OFFLINE_QUEUE', e);
    }
  }

  Future<String?> _uploadLocalMedia(QueuedMessage item) async {
    final bytes = await _readMediaBytes(item.localMediaPath);
    if (bytes == null || bytes.isEmpty) return null;

    final token = await DatabaseConfig.getStoredAuthToken();
    if (token.isEmpty) return null;

    final baseUrl = DatabaseConfig.physicalServerUrl;
    final fileName = item.fileName ??
        'offline_${DateTime.now().millisecondsSinceEpoch}.${item.messageType}';

    try {
      final dio = Dio(BaseOptions(
        baseUrl: baseUrl,
        headers: {
          'Authorization': 'Bearer $token',
          'ngrok-skip-browser-warning': 'true',
        },
        connectTimeout: const Duration(seconds: 30),
        receiveTimeout: const Duration(seconds: 120),
        sendTimeout: const Duration(seconds: 120),
      ));

      final formData = FormData.fromMap({
        'chatId': item.chatId,
        'type': item.messageType,
        'file': MultipartFile.fromBytes(bytes, filename: fileName),
        if (item.content.isNotEmpty) 'caption': item.content,
      });

      final response = await dio.post('/api/media/upload', data: formData);
      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = response.data;
        if (data is Map) {
          return data['mediaUrl']?.toString() ?? data['url']?.toString();
        }
      }
    } catch (e) {
      Log.e('Queued media upload failed', 'OFFLINE_QUEUE', e);
    }

    // Fallback: multipart via http package
    try {
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('$baseUrl/api/media/upload'),
      );
      request.headers.addAll({
        'Authorization': 'Bearer $token',
        'ngrok-skip-browser-warning': 'true',
      });
      request.fields['chatId'] = item.chatId;
      request.fields['type'] = item.messageType;
      if (item.content.isNotEmpty) request.fields['caption'] = item.content;
      request.files.add(http.MultipartFile.fromBytes('file', bytes, filename: fileName));

      final streamed = await request.send().timeout(const Duration(seconds: 120));
      if (streamed.statusCode == 200 || streamed.statusCode == 201) {
        final body = await streamed.stream.bytesToString();
        final data = json.decode(body);
        if (data is Map) {
          return data['mediaUrl']?.toString() ?? data['url']?.toString();
        }
      }
    } catch (e) {
      Log.e('Queued media upload fallback failed', 'OFFLINE_QUEUE', e);
    }

    return null;
  }

  Map<String, dynamic> getStats() => {
        'isSyncing': _syncing,
        'syncQueue': pendingCount,
        'messages': _queue.length,
        'failed': _queue.where((m) => m.status == OfflineMessageStatus.failed).length,
      };

  void dispose() {
    _changeController.close();
  }
}

void unawaited(Future<void> future) {
  future.catchError((Object e, StackTrace st) {
    Log.e('Unhandled async error in connectivity callback', 'OFFLINE_QUEUE', e, st);
  });
}