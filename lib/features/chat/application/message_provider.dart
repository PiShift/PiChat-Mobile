import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pichat/data/db/app_database.dart';
import 'package:pichat/data/db/database_provider.dart';
import 'package:pichat/data/models/chat_model.dart';

final messagesProvider =
StreamProvider.family<List<Chat>, int>((ref, int contactId) {
  final db = ref.watch(appDatabaseProvider);

  return (db.select(db.chats)
    ..where((tbl) => tbl.contactId.equals(contactId))
    ..orderBy([(t) => OrderingTerm(expression: t.createdAt)]))
      .watch()
      .asyncMap((rows) async {
    // Load each chat with its relations (media and logs)
    final chatsWithRelations = await Future.wait(
        rows.map((row) => db.getChatWithRelations(row.id))
    );
    // Filter out null values and return
    return chatsWithRelations.whereType<Chat>().toList();
  });
});



