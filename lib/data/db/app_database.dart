import 'dart:convert';
import 'dart:io';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:pichat/data/models/chat_log_model.dart';
import 'package:pichat/data/models/chat_media_model.dart';
import 'package:pichat/data/models/chat_model.dart';
import 'package:pichat/data/models/contact_model.dart';
import 'package:pichat/data/models/timeline_event_model.dart';
import 'package:pichat/data/repositories/label_repository.dart';
import 'package:pichat/data/models/organization_model.dart';
import 'package:pichat/data/models/user_model.dart';

// Import tables
import 'tables/timeline_event_table.dart';
import 'tables/user_table.dart';
import 'tables/organization_table.dart';
import 'tables/chat_table.dart';
import 'tables/contact_table.dart';

part 'app_database.g.dart';

@DriftDatabase(
  tables: [Users, Organizations, UserOrganizations, Chats, Contacts, Medias, ChatLogs, TimelineEvents],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  /// Opens the schema against a caller-supplied executor, so tests can run
  /// against an in-memory database instead of the on-device file.
  AppDatabase.forTesting(super.executor) : super();

  @override
  int get schemaVersion => 5;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) async => await m.createAll(),
    onUpgrade: (m, from, to) async {
      if (from < 2) {
        await m.addColumn(medias, medias.metaId);
      }
      if (from < 3) {
        // Calls, ticket changes and notes now render in the thread alongside
        // messages, and a message needs to say whether the AI assistant sent it.
        await m.createTable(timelineEvents);
        await m.addColumn(chats, chats.isPibot);
        await m.addColumn(contacts, contacts.assignedAgentName);
        await m.addColumn(contacts, contacts.assignedAgentId);
        await m.addColumn(contacts, contacts.ticketStatus);
      }
      if (from < 4) {
        // A missed call is conversation activity: the row moves up the list
        // and previews the call, the same way a message would.
        await m.addColumn(contacts, contacts.lastCallAt);
        await m.addColumn(contacts, contacts.lastCallDirection);
        await m.addColumn(contacts, contacts.lastCallStatus);
      }
      if (from < 5) {
        await m.addColumn(contacts, contacts.labels);
      }
    },
  );

  /// -----------------------
  /// USERS
  /// -----------------------
  Future<int> insertUser(User user) {
    return into(users).insert(
      UsersCompanion.insert(
        id: Value(user.id),
        firstName: user.firstName,
        lastName: user.lastName,
        email: user.email,
        phone: Value(user.phone),
        avatar: Value(user.avatar),
        role: Value(user.role),
        status: Value(user.status),
        createdAt: Value(user.createdAt),
      ),
      mode: InsertMode.insertOrReplace,
    );
  }

  Future<User?> getUserById(int id) async {
    final row = await (select(users)..where((u) => u.id.equals(id)))
        .getSingleOrNull();
    if (row == null) return null;

    return User.fromDb(row);
  }

  /// -----------------------
  /// ORGANIZATIONS
  /// -----------------------
  Future<int> insertOrganization(Organization org) {
    return into(organizations).insert(
      OrganizationsCompanion.insert(
        id: Value(org.id),
        identifier: org.identifier,
        name: org.name,
        metadata: Value(jsonEncode(org.metadata ?? {})),
        createdAt: Value(org.createdAt),
      ),
      mode: InsertMode.insertOrReplace,
    );
  }

  Future<Organization?> getOrganizationById(int id) async {
    final row = await (select(organizations)..where((o) => o.id.equals(id)))
        .getSingleOrNull();
    if (row == null) return null;

    return Organization.fromDb(row);
  }

  /// -----------------------
  /// CHATS
  /// -----------------------
  Future<int> insertChat(Chat chat) {
    return into(chats).insert(
      ChatsCompanion.insert(
        id: Value(chat.id),
        orgId: chat.orgId,
        uuid: chat.uuid,
        wamId: Value(chat.wamId),
        contactId: chat.contactId,
        userId: Value(chat.userId),
        type: chat.type,
        metadata: Value(jsonEncode(chat.metadata ?? {})),
        mediaId: Value(chat.mediaId),
        status: Value(chat.status),
        isRead: Value(chat.isRead),
        createdAt: Value(chat.createdAt),
        updatedAt: Value(chat.updatedAt),
      ),
      mode: InsertMode.insertOrReplace,
    );
  }

  Future<List<Chat>> getChatsForOrg(int orgId) async {
    final rows = await (select(chats)..where((c) => c.orgId.equals(orgId))).get();
    return rows.map((row) {
      return Chat.fromDb(row);
    }).toList();
  }

  Stream<List<Chat>> watchChatsForOrg(int orgId) {
    return (select(chats)..where((c) => c.orgId.equals(orgId)))
        .watch()
        .map((rows) => rows.map((row) {
      return Chat.fromDb(row);
    }).toList());
  }

  Future<List<Organization>> getUserOrganizations(int userId) async {
    // Join UserOrganizations and Organizations
    final query = select(organizations).join([
      innerJoin(
        userOrganizations,
        userOrganizations.orgId.equalsExp(organizations.id),
      ),
    ])
      ..where(userOrganizations.userId.equals(userId));

    final rows = await query.get();
    return rows.map((row) {
      final org = row.readTable(organizations);
      return Organization(
        id: org.id,
        userId: userId,
        identifier: org.identifier,
        name: org.name,
        metadata: org.metadata != null && org.metadata!.isNotEmpty
            ? Map<String, dynamic>.from(jsonDecode(org.metadata!))
            : {},
        createdAt: org.createdAt,
      );
    }).toList();
  }

  Future<int> insertUserOrganization({required int userId, required int orgId}) {
    return into(userOrganizations).insert(
      UserOrganizationsCompanion.insert(userId: userId, orgId: orgId),
      mode: InsertMode.insertOrReplace, // avoid duplicates
    );
  }

  /// -----------------------
  /// CONTACTS
  /// -----------------------
  Future<int> insertContact(Contact contact) {
    return into(contacts).insert(
      contact.toCompanion(),
      mode: InsertMode.insertOrReplace,
    );
  }

  Future<Contact?> getContactWithLastChat(int id) async {
    final row = await (select(contacts)..where((c) => c.id.equals(id)))
        .getSingleOrNull();
    if (row == null) return null;

    final contact = Contact.fromDb(row);

    if (contact.lastChatId != null) {
      final chatRow = await (select(chats)..where((c) => c.id.equals(contact.lastChatId!)))
          .getSingleOrNull();
      if (chatRow != null) {
        final chat = await getChatWithRelations(chatRow.id);
        return contact.copyWith(lastChat: chat);
      }
    }
    return contact;
  }

  /// -----------------------
  /// CHATS
  /// -----------------------
  Future<Chat?> getChatWithRelations(int chatId) async {
    final chatRow = await (select(chats)..where((c) => c.id.equals(chatId)))
        .getSingleOrNull();
    if (chatRow == null) return null;

    final chat = Chat.fromDb(chatRow);

    // Media relation
    ChatMedia? media;
    print("====== Chat mediaId: ${chat.mediaId}");
    if (chat.mediaId != null) {
      final mediaRow = await (select(medias)..where((m) => m.id.equals(chat.mediaId!)))
          .getSingleOrNull();
      if (mediaRow != null) {
        media = ChatMedia.fromDb(mediaRow);
      }
    }

    // Logs relation
    final logsRows = await (select(chatLogs)..where((l) => l.chatId.equals(chatId))).get();
    final logs = logsRows.map((row) => ChatLog.fromDb(row)).toList();

    return chat.copyWith(media: media, logs: logs);
  }

}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    final file = File(p.join(dbFolder.path, 'pichat.db'));
    return NativeDatabase(file);
  });
}

extension MediasUpdate on AppDatabase {
  Future<int> updateMediaPath(String mediaId, String localPath) async {
    return (update(medias)..where((m) => m.id.equals(int.parse(mediaId)))).write(
      MediasCompanion(
        path: Value(localPath),
        location: const Value('local'),
      ),
    );
  }

  /// Upsert chats from the server without dropping `_localFilePath`.
  ///
  /// That key is ours, not the server's — it points at the copy of the file
  /// already on this device, and it is the only reason an outbound voice note
  /// can play straight after sending instead of offering a download. A plain
  /// upsert of the server payload silently removed it every time the thread
  /// was refreshed or paged, so the bubble reverted to a download button.
  Future<void> upsertChatsPreservingLocalPaths(
    List<ChatsCompanion> rows,
  ) async {
    final ids = [
      for (final row in rows)
        if (row.id.present) row.id.value,
    ];

    if (ids.isEmpty) return;

    final existing = await (select(chats)..where((c) => c.id.isIn(ids))).get();

    final localPaths = <int, String>{};

    for (final row in existing) {
      final raw = row.metadata;

      if (raw == null) continue;

      try {
        final path = (jsonDecode(raw) as Map<String, dynamic>)['_localFilePath'];

        if (path is String && path.isNotEmpty) localPaths[row.id] = path;
      } catch (_) {
        // Unreadable metadata is the server's problem, not a reason to abort
        // the whole batch.
      }
    }

    final merged = <ChatsCompanion>[];

    for (final row in rows) {
      final path = row.id.present ? localPaths[row.id.value] : null;

      if (path == null) {
        merged.add(row);
        continue;
      }

      Map<String, dynamic> meta;

      try {
        meta = row.metadata.present && row.metadata.value != null
            ? Map<String, dynamic>.from(
                jsonDecode(row.metadata.value!) as Map)
            : <String, dynamic>{};
      } catch (_) {
        meta = <String, dynamic>{};
      }

      meta['_localFilePath'] = path;
      merged.add(row.copyWith(metadata: Value(jsonEncode(meta))));
    }

    await batch((b) => b.insertAllOnConflictUpdate(chats, merged));
  }

  /// Inserts or updates a media row from server data, but never overwrites a
  /// locally-downloaded file (location == 'local'). This preserves the local
  /// path and location after the user downloads an inbound image/document.
  Future<void> upsertMediaPreservingLocal(MediasCompanion companion) async {
    final id = companion.id.value;
    final existing = await (select(medias)..where((m) => m.id.equals(id))).getSingleOrNull();

    if (existing != null && existing.location == 'local') {
      // Already downloaded — update everything except path and location.
      await (update(medias)..where((m) => m.id.equals(id))).write(
        MediasCompanion(
          mediaId: companion.mediaId,
          metaId: companion.metaId,
          name: companion.name,
          metaUrl: companion.metaUrl,
          type: companion.type,
          size: companion.size,
          createdAt: companion.createdAt,
          // path and location intentionally omitted — keeps local values
        ),
      );
    } else {
      await into(medias).insertOnConflictUpdate(companion);
    }
  }
}

extension ChatsUpdate on AppDatabase {
  /// Update only the status column of a chat row (used for optimistic UI).
  Future<int> updateChatStatus(int chatId, String status) {
    return (update(chats)..where((c) => c.id.equals(chatId))).write(
      ChatsCompanion(status: Value(status)),
    );
  }

  /// Delete a chat row by id (used to remove failed optimistic messages on retry).
  /// Records who a conversation is assigned to.
  ///
  /// Written straight after the API accepts an assignment so the thread header
  /// and the chat list reflect it at once; the authoritative value still
  /// arrives with the next contacts fetch.
  Future<int> setContactAssignment({
    required int contactId,
    required int? agentId,
    required String? agentName,
  }) {
    return (update(contacts)..where((t) => t.id.equals(contactId))).write(
      ContactsCompanion(
        assignedAgentId: Value(agentId),
        assignedAgentName: Value(agentName),
      ),
    );
  }

  /// Stores the labels on a conversation after the agent changes them.
  ///
  /// Targeted write so it cannot disturb any other column, and immediate so the
  /// chat list repaints without waiting for the next contacts fetch.
  Future<int> setContactLabels({
    required int contactId,
    required List<Label> labels,
  }) {
    return (update(contacts)..where((t) => t.id.equals(contactId))).write(
      ContactsCompanion(
        labels: Value(jsonEncode(labels.map((l) => l.toJson()).toList())),
      ),
    );
  }

  /// Records the conversation's most recent call.
  ///
  /// Targeted write rather than an upsert of the whole contact, so it cannot
  /// disturb any other column.
  Future<int> setContactCallActivity({
    required int contactId,
    required DateTime at,
    required String direction,
    required String status,
  }) {
    return (update(contacts)..where((t) => t.id.equals(contactId))).write(
      ContactsCompanion(
        lastCallAt: Value(at),
        lastCallDirection: Value(direction),
        lastCallStatus: Value(status),
        latestChatCreatedAt: Value(at),
      ),
    );
  }

  /// -----------------------
  /// TIMELINE EVENTS (calls, ticket changes, notes)
  /// -----------------------

  /// Upserts a page of events. `insertAllOnConflictUpdate` keyed on the log id
  /// makes re-fetching a page idempotent.
  Future<void> upsertTimelineEvents(List<TimelineEvent> events) async {
    if (events.isEmpty) return;

    await batch((b) {
      b.insertAllOnConflictUpdate(
        timelineEvents,
        events.map((e) => e.toCompanion()).toList(),
      );
    });
  }

  Future<List<TimelineEvent>> getTimelineEventsForContact(int contactId) async {
    final rows = await (select(timelineEvents)
          ..where((t) => t.contactId.equals(contactId))
          ..orderBy([(t) => OrderingTerm.asc(t.createdAt)]))
        .get();

    return rows.map(TimelineEvent.fromDb).toList();
  }

  Stream<List<TimelineEvent>> watchTimelineEventsForContact(int contactId) {
    return (select(timelineEvents)
          ..where((t) => t.contactId.equals(contactId))
          ..orderBy([(t) => OrderingTerm.asc(t.createdAt)]))
        .watch()
        .map((rows) => rows.map(TimelineEvent.fromDb).toList());
  }

  Future<int> clearTimelineEventsForContact(int contactId) {
    return (delete(timelineEvents)..where((t) => t.contactId.equals(contactId)))
        .go();
  }

  Future<int> deleteChat(int chatId) {
    return (delete(chats)..where((c) => c.id.equals(chatId))).go();
  }
}