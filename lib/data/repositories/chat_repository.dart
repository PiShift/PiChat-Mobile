import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:dio/dio.dart';
import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pichat/core/network/dio_provider.dart';
import 'package:pichat/data/db/app_database.dart';
import 'package:pichat/data/db/database_provider.dart';
import 'package:pichat/data/models/chat_model.dart';


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

        // Insert all media
        final mediaEntries = messages
            .where((m) => m.media != null)
            .map((m) => m.media!.toCompanion())
            .toList();
        if (mediaEntries.isNotEmpty) {
          await _db.batch((batch) {
            batch.insertAllOnConflictUpdate(_db.medias, mediaEntries);
          });
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

      final payload = {
        "ids": idsToSync.map((e) => e).toList(), // <-- ensures pure List<int>
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

  void dispose() {
    _debounceTimer?.cancel();
  }

}
