import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pichat/data/db/app_database.dart';

/// A server payload for one outbound voice note. It never carries
/// `_localFilePath` — that key is ours.
ChatsCompanion serverRow(int id) => ChatsCompanion(
      id: Value(id),
      orgId: const Value(1),
      uuid: Value('wamid_$id'),
      contactId: const Value(7),
      type: const Value('outbound'),
      metadata: Value(jsonEncode({
        'type': 'audio',
        'audio': {'voice': true},
      })),
      status: const Value('sent'),
      isRead: const Value(true),
      createdAt: Value(DateTime.now()),
    );

void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() => db.close());

  Future<Map<String, dynamic>> metaOf(int id) async {
    final row = await (db.select(db.chats)..where((c) => c.id.equals(id)))
        .getSingle();

    return jsonDecode(row.metadata!) as Map<String, dynamic>;
  }

  test('a refresh keeps the local file path the server does not know about',
      () async {
    await db.into(db.chats).insertOnConflictUpdate(
          serverRow(101).copyWith(
            metadata: Value(jsonEncode({
              'type': 'audio',
              'audio': {'voice': true},
              '_localFilePath': 'chat_media/7/audio/voice_1.ogg',
            })),
          ),
        );

    // The same message comes back from the API, without our key.
    await db.upsertChatsPreservingLocalPaths([serverRow(101)]);

    final meta = await metaOf(101);

    expect(meta['_localFilePath'], 'chat_media/7/audio/voice_1.ogg');
    // Server fields still win.
    expect((meta['audio'] as Map)['voice'], true);
  });

  test('a message with no local copy is written through untouched', () async {
    await db.upsertChatsPreservingLocalPaths([serverRow(102)]);

    expect((await metaOf(102)).containsKey('_localFilePath'), isFalse);
  });

  test('one row having a local copy does not leak it onto another', () async {
    await db.into(db.chats).insertOnConflictUpdate(
          serverRow(103).copyWith(
            metadata: Value(jsonEncode({
              'type': 'audio',
              '_localFilePath': 'chat_media/7/audio/voice_3.ogg',
            })),
          ),
        );

    await db.upsertChatsPreservingLocalPaths([serverRow(103), serverRow(104)]);

    expect((await metaOf(103))['_localFilePath'],
        'chat_media/7/audio/voice_3.ogg');
    expect((await metaOf(104)).containsKey('_localFilePath'), isFalse);
  });
}
