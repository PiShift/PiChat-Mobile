import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:dio/dio.dart';
import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pichat/core/network/dio_provider.dart';
import 'package:pichat/data/db/app_database.dart';
import 'package:pichat/data/db/database_provider.dart';
import 'package:pichat/data/models/chat_model.dart';

/// Thrown when the server rejects a plain text message because the
/// 24-hour WhatsApp messaging window has expired.
class MessageWindowExpiredException implements Exception {
  const MessageWindowExpiredException();
  @override
  String toString() => 'MessageWindowExpiredException';
}


final chatRepositoryProvider = Provider<ChatRepository>((ref) {
  final dio = ref.watch(dioProvider);
  final db = ref.watch(appDatabaseProvider);
  return ChatRepository(dio, db, ref);
});

class ChatRepository {
  final Dio _dio;
  final AppDatabase _db;
  final Ref _ref;

  // pending IDs to sync (in-memory set)
  final Set<int> _pendingReadIds = {};
  Timer? _debounceTimer;
  DateTime? _firstPendingAt;
  bool _isSyncing = false;
  int _retryCount = 0;

  // configuration knobs
  final Duration _debounceDuration = const Duration(seconds: 10);
  final Duration _maxDelay = const Duration(seconds: 30);
  final int _batchSize = 200; // flush when this many pending
  final int _maxRetries = 5;

  ChatRepository(this._dio, this._db, this._ref);

  Future<List<Chat>> getMessages(
      int contactId, {
        int? afterId,
        int page = 1,
        int perPage = 20,
        bool forceRefresh = false,
      }) async {

    if (!forceRefresh && page == 1) {
      // First get chat rows
      final cached = await (_db.select(_db.chats)..where((tbl) => tbl.contactId.equals(contactId))).get();
      if (cached.isNotEmpty) {
        // Load each chat with its relations
        final messages = await Future.wait(
            cached.map((row) => _db.getChatWithRelations(row.id)).toList()
        );
        // Filter out null values and return
        return messages.whereType<Chat>().toList();
      }
    }

    final query = {
      'page': page,
      'per_page': perPage,
      if (afterId != null) 'after_id': afterId,
    };

    final response = await _dio.get('/contacts/$contactId/messages', queryParameters: query);

    final data = response.data['messages'] as List;
    final messages = <Chat>[];

    for (var page in data) {
      for (var item in page) {
        if (item['type'] == 'chat') {
          messages.add(Chat.fromJson(item['value']));
        }
        // handle tickets or notes here if needed
      }
    }

    if (messages.isNotEmpty) {
      await _db.transaction(() async {
        // Insert all chats
        await _db.batch((batch) {
          batch.insertAllOnConflictUpdate(
            _db.chats,
            messages.map((m) => m.toCompanion()).toList(),
          );
        });

        // Insert all media — preserving locally-downloaded paths
        final mediaList = messages.where((m) => m.media != null).toList();
        for (final m in mediaList) {
          await _db.upsertMediaPreservingLocal(m.media!.toCompanion());
        }

        // Insert logs - handle as separate entries per chat
        final logsToInsert = <ChatLogsCompanion>[];
        for (final chat in messages) {
          if (chat.logs.isNotEmpty) {
            logsToInsert.addAll(
                chat.logs.map((log) => log.toCompanion()).toList()
            );
          }
        }

        if (logsToInsert.isNotEmpty) {
          await _db.batch((batch) {
            batch.insertAllOnConflictUpdate(_db.chatLogs, logsToInsert);
          });
        }
      });
    }

    return messages;
  }

  Future<Chat> sendMessage(int contactId, Chat message) async {
    final response = await _dio.post('/contacts/$contactId/messages', data: message.toJson());
    final sent = Chat.fromJson(response.data['data']);

    await _db.into(_db.chats).insertOnConflictUpdate(sent.toCompanion());
    return sent;
  }

  /// Send a text message to a contact by UUID
  /// Returns the sent Chat object on success, or throws on failure.
  /// Optimistically inserts the message with status='pending' first,
  /// then updates to 'sent' or 'failed' after the API call.
  Future<Chat> sendTextMessage(
    String contactUuid,
    String message, {
    required int contactId,
    required int orgId,
    int? tempId,
  }) async {
    // Generate a stable negative temp ID so the caller can retry with the same row
    final localId = tempId ?? -(DateTime.now().millisecondsSinceEpoch);

    final optimistic = Chat(
      id: localId,
      orgId: orgId,
      uuid: 'pending_$localId',
      contactId: contactId,
      type: 'outbound',
      metadata: {'type': 'text', 'text': {'body': message}},
      status: 'pending',
      isRead: true,
      createdAt: DateTime.now(),
    );

    await _db.into(_db.chats).insertOnConflictUpdate(optimistic.toCompanion());

    try {
      final response = await _dio.post(
        '/contacts/$contactUuid/messages',
        data: <String, dynamic>{'message': message, 'type': 'text'},
      );

      if (response.data['success'] == true) {
        if (response.data['message'] != null) {
          final sent = Chat.fromJson(response.data['message']);
          // Atomically swap temp row → real row so the stream fires only once
          await _db.transaction(() async {
            await _db.deleteChat(localId);
            await _db.into(_db.chats).insertOnConflictUpdate(sent.toCompanion());
          });
          return sent;
        }
        // API confirmed success but did not return the full message.
        // Keep the temp row visible with 'sent' status — Reverb will replace it
        // atomically later via _handleIncomingChat (FIFO matching).
        await _db.updateChatStatus(localId, 'sent');
        return optimistic.copyWith(status: 'sent');
      }

      await _db.updateChatStatus(localId, 'failed');
      throw Exception(response.data['message'] ?? 'Failed to send message');
    } on DioException catch (e) {
      // 422 message_window_expired: remove the optimistic row — no retry makes sense.
      // The caller should show the 24h-expired banner instead.
      final errorCode = e.response?.data?['error'] as String?;
      if (e.response?.statusCode == 422 && errorCode == 'message_window_expired') {
        await _db.deleteChat(localId);
        throw const MessageWindowExpiredException();
      }
      await _db.updateChatStatus(localId, 'failed');
      rethrow;
    } catch (e) {
      await _db.updateChatStatus(localId, 'failed');
      rethrow;
    }
  }

  /// Send a media file with optimistic UI.
  /// Immediately inserts a pending message, updates to sent/failed after upload.
  /// Set [isVoice] when the file is an OPUS-encoded `.ogg` voice memo so the
  /// backend forwards `voice: true` to Meta and WhatsApp renders it as a
  /// voice note (mic icon, transcription) instead of a basic audio file.
  Future<Chat> sendMediaMessage(
    String contactUuid,
    File file, {
    String? caption,
    required int contactId,
    required int orgId,
    int? tempId,
    bool isVoice = false,
  }) async {
    final localId = tempId ?? -(DateTime.now().millisecondsSinceEpoch);
    final fileName = file.path.split('/').last;
    final isImage = _isImageFile(fileName);

    // Build metadata like a real chat so ChatMessageItem can render it
    final Map<String, dynamic> mediaType = isImage
        ? {'caption': caption ?? ''}
        : (isVoice
            ? {'filename': fileName, 'caption': caption ?? '', 'voice': true}
            : {'filename': fileName, 'caption': caption ?? ''});
    final String type = isImage ? 'image' : _guessMediaType(fileName);

    final optimistic = Chat(
      id: localId,
      orgId: orgId,
      uuid: 'pending_$localId',
      contactId: contactId,
      type: 'outbound',
      metadata: {
        'type': type,
        type: mediaType,
        '_localFilePath': file.path, // used by ChatMessageItem to render local preview
      },
      status: 'pending',
      isRead: true,
      createdAt: DateTime.now(),
    );

    await _db.into(_db.chats).insertOnConflictUpdate(optimistic.toCompanion());

    try {
      final formData = FormData.fromMap({
        'file': await MultipartFile.fromFile(file.path, filename: fileName),
        if (caption != null) 'caption': caption,
        if (isVoice) 'voice': '1',
      });

      final response = await _dio.post(
        '/contacts/$contactUuid/media',
        data: formData,
      );

      if (response.data['success'] == true) {
        if (response.data['message'] != null) {
          // Server returned the full chat — atomically swap temp → real (no flicker)
          final sent = Chat.fromJson(response.data['message']);
          // Always build an updated metadata map
          final meta = Map<String, dynamic>.from(sent.metadata ?? {});
          // 1) Keep image accessible from local file — no network download needed
          meta['_localFilePath'] = file.path;
          // 2) If server didn't store caption, restore it from what we sent
          if (caption != null && caption.isNotEmpty) {
            final serverType = meta['type'] as String? ?? type;
            final block = Map<String, dynamic>.from((meta[serverType] as Map?) ?? {});
            block['caption'] ??= caption;
            meta[serverType] = block;
          }
          final finalSent = sent.copyWith(metadata: meta);
          await _db.transaction(() async {
            await _db.deleteChat(localId);
            await _db.into(_db.chats).insertOnConflictUpdate(finalSent.toCompanion());
            if (sent.media != null) {
              await _db.upsertMediaPreservingLocal(sent.media!.toCompanion());
            }
          });
          return finalSent;
        }
        // API confirmed but did not return the full message — keep temp visible.
        // Reverb will atomically replace it (FIFO) when it arrives.
        await _db.updateChatStatus(localId, 'sent');
        return optimistic.copyWith(status: 'sent');
      }

      await _db.updateChatStatus(localId, 'failed');
      throw Exception(response.data['message'] ?? 'Failed to send media');
    } catch (e) {
      await _db.updateChatStatus(localId, 'failed');
      rethrow;
    }
  }

  /// Send a location pin to a contact.
  /// Optimistically inserts a `location` chat row, then swaps it with the
  /// authoritative server response (or marks it failed).
  Future<Chat> sendLocation(
    String contactUuid, {
    required double latitude,
    required double longitude,
    String? name,
    String? address,
    required int contactId,
    required int orgId,
    int? tempId,
  }) async {
    final localId = tempId ?? -(DateTime.now().millisecondsSinceEpoch);

    final locationPayload = <String, dynamic>{
      'latitude': latitude,
      'longitude': longitude,
      if (name != null && name.isNotEmpty) 'name': name,
      if (address != null && address.isNotEmpty) 'address': address,
    };

    final optimistic = Chat(
      id: localId,
      orgId: orgId,
      uuid: 'pending_$localId',
      contactId: contactId,
      type: 'outbound',
      metadata: {'type': 'location', 'location': locationPayload},
      status: 'pending',
      isRead: true,
      createdAt: DateTime.now(),
    );

    await _db.into(_db.chats).insertOnConflictUpdate(optimistic.toCompanion());

    try {
      final response = await _dio.post(
        '/contacts/$contactUuid/location',
        data: <String, dynamic>{
          'latitude': latitude,
          'longitude': longitude,
          if (name != null && name.isNotEmpty) 'name': name,
          if (address != null && address.isNotEmpty) 'address': address,
        },
      );

      if (response.data['success'] == true) {
        if (response.data['message'] != null) {
          final sent = Chat.fromJson(response.data['message']);
          await _db.transaction(() async {
            await _db.deleteChat(localId);
            await _db.into(_db.chats).insertOnConflictUpdate(sent.toCompanion());
          });
          return sent;
        }
        await _db.updateChatStatus(localId, 'sent');
        return optimistic.copyWith(status: 'sent');
      }

      await _db.updateChatStatus(localId, 'failed');
      throw Exception(response.data['message'] ?? 'Failed to send location');
    } on DioException catch (e) {
      final errorCode = e.response?.data?['error'] as String?;
      if (e.response?.statusCode == 422 && errorCode == 'message_window_expired') {
        await _db.deleteChat(localId);
        throw const MessageWindowExpiredException();
      }
      await _db.updateChatStatus(localId, 'failed');
      rethrow;
    } catch (e) {
      await _db.updateChatStatus(localId, 'failed');
      rethrow;
    }
  }

  /// Share one or more contact cards. The [contacts] list must already be
  /// shaped per Meta's Cloud API spec (each item has `name.formatted_name`
  /// plus optional phones / emails / addresses / urls / org / birthday).
  Future<Chat> sendContactCards(
    String contactUuid,
    List<Map<String, dynamic>> contacts, {
    required int contactId,
    required int orgId,
    int? tempId,
  }) async {
    final localId = tempId ?? -(DateTime.now().millisecondsSinceEpoch);

    final optimistic = Chat(
      id: localId,
      orgId: orgId,
      uuid: 'pending_$localId',
      contactId: contactId,
      type: 'outbound',
      metadata: {'type': 'contacts', 'contacts': contacts},
      status: 'pending',
      isRead: true,
      createdAt: DateTime.now(),
    );

    await _db.into(_db.chats).insertOnConflictUpdate(optimistic.toCompanion());

    try {
      final response = await _dio.post(
        '/contacts/$contactUuid/contact-cards',
        data: <String, dynamic>{'contacts': contacts},
      );

      if (response.data['success'] == true) {
        if (response.data['message'] != null) {
          final sent = Chat.fromJson(response.data['message']);
          await _db.transaction(() async {
            await _db.deleteChat(localId);
            await _db.into(_db.chats).insertOnConflictUpdate(sent.toCompanion());
          });
          return sent;
        }
        await _db.updateChatStatus(localId, 'sent');
        return optimistic.copyWith(status: 'sent');
      }

      await _db.updateChatStatus(localId, 'failed');
      throw Exception(response.data['message'] ?? 'Failed to send contact');
    } on DioException catch (e) {
      final errorCode = e.response?.data?['error'] as String?;
      if (e.response?.statusCode == 422 && errorCode == 'message_window_expired') {
        await _db.deleteChat(localId);
        throw const MessageWindowExpiredException();
      }
      await _db.updateChatStatus(localId, 'failed');
      rethrow;
    } catch (e) {
      await _db.updateChatStatus(localId, 'failed');
      rethrow;
    }
  }

  /// React to a previously received WhatsApp message with a single emoji.
  /// Pass an empty string for [emoji] to clear the reaction. The reaction
  /// itself is stored as a small outbound chat row for history; UIs are
  /// expected to render it as an overlay on the bubble identified by
  /// [wamId] rather than as a standalone bubble.
  Future<Chat> sendReaction(
    String contactUuid, {
    required String wamId,
    required String emoji,
    required int contactId,
    required int orgId,
  }) async {
    final localId = -(DateTime.now().millisecondsSinceEpoch);

    final optimistic = Chat(
      id: localId,
      orgId: orgId,
      uuid: 'pending_$localId',
      contactId: contactId,
      type: 'outbound',
      metadata: {
        'type': 'reaction',
        'reaction': {'message_id': wamId, 'emoji': emoji},
      },
      status: 'pending',
      isRead: true,
      createdAt: DateTime.now(),
    );

    await _db.into(_db.chats).insertOnConflictUpdate(optimistic.toCompanion());

    try {
      final response = await _dio.post(
        '/contacts/$contactUuid/reaction',
        data: <String, dynamic>{'wam_id': wamId, 'emoji': emoji},
      );

      if (response.data['success'] == true) {
        if (response.data['message'] != null) {
          final sent = Chat.fromJson(response.data['message']);
          await _db.transaction(() async {
            await _db.deleteChat(localId);
            await _db.into(_db.chats).insertOnConflictUpdate(sent.toCompanion());
          });
          return sent;
        }
        await _db.updateChatStatus(localId, 'sent');
        return optimistic.copyWith(status: 'sent');
      }

      await _db.updateChatStatus(localId, 'failed');
      throw Exception(response.data['message'] ?? 'Failed to send reaction');
    } catch (e) {
      await _db.updateChatStatus(localId, 'failed');
      rethrow;
    }
  }

  static bool _isImageFile(String name) {
    final ext = name.split('.').last.toLowerCase();
    return ['jpg', 'jpeg', 'png', 'gif', 'webp', 'heic'].contains(ext);
  }

  static String _guessMediaType(String name) {
    final ext = name.split('.').last.toLowerCase();
    if (['mp4', 'mov', 'avi', 'mkv'].contains(ext)) return 'video';
    if (['mp3', 'ogg', 'opus', 'm4a', 'aac'].contains(ext)) return 'audio';
    return 'document';
  }

  Future<Map<String, dynamic>> checkMessageWindow(String contactUuid) async {
    final response = await _dio.get('/contacts/$contactUuid/message-window');
    return response.data as Map<String, dynamic>;
  }

  /// Get media files for a contact, grouped by type (images, videos, documents, audio)
  Future<Map<String, dynamic>> getContactMedia(String contactUuid, {String? type, int page = 1}) async {
    final params = <String, dynamic>{
      'page': page,
      'per_page': 20,
    };
    if (type != null) {
      params['type'] = type;
    }
    
    final response = await _dio.get(
      '/contacts/$contactUuid/media',
      queryParameters: params,
    );
    return response.data as Map<String, dynamic>;
  }

  /// Send a media file (image, video, document, audio) to a contact
  Future<List<ChatData>> getMessagesForContact(int contactId) {
    return (_db.select(_db.chats)
      ..where((tbl) => tbl.contactId.equals(contactId)))
        .get();
  }

  /// Called by UI logic to mark messages as read locally and queue them for sync.
  Future<void> markMessagesAsRead(List<Chat> messages) async {
    if (messages.isEmpty) return;

    // 1) Update local DB immediately (partial update)
    for (final msg in messages) {
      await (_db.update(_db.chats)..where((t) => t.id.equals(msg.id))).write(
        ChatsCompanion(isRead: Value(true)),
      );

      _pendingReadIds.add(msg.id);
    }

    // 2) Schedule a sync (debounced with maxDelay)
    _scheduleSync();
  }

  void _scheduleSync() {
    // record when first pending was added
    _firstPendingAt ??= DateTime.now();

    // if too many pending, flush immediately (batch-size)
    if (_pendingReadIds.length >= _batchSize) {
      _debounceTimer?.cancel();
      _syncReadMessages();
      return;
    }

    // if we've already waited longer than maxDelay, sync now
    final elapsed = DateTime.now().difference(_firstPendingAt!);
    if (elapsed >= _maxDelay) {
      _debounceTimer?.cancel();
      _syncReadMessages();
      return;
    }

    // debounce: cancel previous timer and start a new one
    _debounceTimer?.cancel();
    _debounceTimer = Timer(_debounceDuration, () {
      _syncReadMessages();
    });
  }

  Future<void> _syncReadMessages() async {
    if (_isSyncing) return;
    if (_pendingReadIds.isEmpty) {
      _firstPendingAt = null;
      return;
    }

    _isSyncing = true;

    final idsToSync = _pendingReadIds.take(_batchSize).toList();

    try {
      // Explicitly type as Map<String, dynamic> to allow Dio interceptor to add organization_id
      final Map<String, dynamic> payload = {
        "ids": idsToSync,
      };

      print("==============");
      print("Sending payload: ${jsonEncode(payload)}");

      final response = await _dio.post(
        '/contacts/messages/mark_as_read',
        data: payload,
        options: Options(
          contentType: Headers.jsonContentType, // <-- force JSON encoding
        ),
      );

      print("MarkAsRead: ${json.encode(response.data)}");

      // remove synced ids
      idsToSync.forEach(_pendingReadIds.remove);

      _retryCount = 0;

      // schedule next batch if still pending
      if (_pendingReadIds.isNotEmpty) {
        _scheduleSync();
      } else {
        _firstPendingAt = null;
        _debounceTimer?.cancel();
      }
    } catch (e) {
      print("MarkAsRead Failed: $e");

      _retryCount++;
      final backoffSeconds = math.min(60, 5 * _retryCount);

      _debounceTimer?.cancel();
      _debounceTimer = Timer(Duration(seconds: backoffSeconds), _syncReadMessages);
    } finally {
      _isSyncing = false;
    }
  }


  /// Force flush pending reads immediately (call when app goes background or chat closed)
  Future<void> flushPendingReads() async {
    _debounceTimer?.cancel();
    await _syncReadMessages();
  }

  /// Get lightweight unread summary for all contacts
  /// Returns total unread count and per-contact breakdown
  Future<UnreadSummary> getUnreadSummary() async {
    final response = await _dio.get('/chats/unread-summary');
    final data = response.data;
    
    final byContact = <int, int>{};
    if (data['by_contact'] != null) {
      (data['by_contact'] as Map<String, dynamic>).forEach((key, value) {
        byContact[int.parse(key)] = value['unread_count'] as int;
      });
    }
    
    return UnreadSummary(
      totalUnread: data['total_unread'] ?? 0,
      byContact: byContact,
    );
  }

  void dispose() {
    _debounceTimer?.cancel();
  }

}

/// Lightweight model for unread message summary
class UnreadSummary {
  final int totalUnread;
  final Map<int, int> byContact; // contactId -> unread count
  
  UnreadSummary({required this.totalUnread, required this.byContact});
}
