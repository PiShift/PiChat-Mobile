import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pichat/data/db/app_database.dart';
import 'package:pichat/data/db/database_provider.dart';
import 'package:pichat/data/models/chat_model.dart';
import 'package:pichat/data/models/contact_model.dart';
import 'package:pichat/data/models/timeline_event_model.dart';
import 'package:pichat/data/repositories/chat_repository.dart';

/// Provider for messages of a specific contact (on-demand loading)
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

/// Non-message entries for a conversation — calls, ticket changes and notes —
/// ordered oldest first, matching the message stream.
///
/// Kept separate from [messagesProvider] rather than merged into one list: the
/// thread's scroll positioning is indexed on messages, so events are rendered
/// anchored to the message they follow instead of occupying list slots of their
/// own.
final timelineEventsProvider =
    StreamProvider.family<List<TimelineEvent>, int>((ref, int contactId) {
  final db = ref.watch(appDatabaseProvider);

  return db.watchTimelineEventsForContact(contactId);
});

/// Live view of one contact from the local database.
///
/// The thread is handed a Contact when it opens, but ticket ownership changes
/// while it is on screen — assigning the conversation to yourself should update
/// the header immediately rather than after the next list refresh.
final contactByIdProvider =
    StreamProvider.family<Contact?, int>((ref, int contactId) {
  final db = ref.watch(appDatabaseProvider);

  return (db.select(db.contacts)..where((t) => t.id.equals(contactId)))
      .watchSingleOrNull()
      .map((row) => row == null ? null : Contact.fromDb(row));
});

/// Provider for total unread count (for app badge)
final totalUnreadProvider = FutureProvider<int>((ref) async {
  final chatRepo = ref.watch(chatRepositoryProvider);
  try {
    final summary = await chatRepo.getUnreadSummary();
    return summary.totalUnread;
  } catch (e) {
    // Fall back to counting from local DB
    final db = ref.watch(appDatabaseProvider);
    final count = await (db.selectOnly(db.chats)
      ..addColumns([db.chats.id.count()])
      ..where(db.chats.type.equals('inbound') & db.chats.isRead.equals(false)))
        .map((row) => row.read(db.chats.id.count()))
        .getSingleOrNull();
    return count ?? 0;
  }
});


