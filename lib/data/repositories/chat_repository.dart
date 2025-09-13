import 'package:dio/dio.dart';
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

  ChatRepository(this._dio, this._db, this._ref);

  Future<List<Chat>> getMessages(
      int contactId, {
        int? afterId,
        int page = 1,
        int perPage = 20,
        bool forceRefresh = false,
      }) async {
    if (!forceRefresh && page == 1) {
      final cached = await (_db.select(_db.chats)..where((tbl) => tbl.contactId.equals(contactId))).get();
      if (cached.isNotEmpty) {
        return cached.map((row) => Chat.fromDb(row)).toList();
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
      await _db.batch((batch) {
        batch.insertAllOnConflictUpdate(
          _db.chats,
          messages.map((m) => m.toCompanion()).toList(),
        );
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
}
