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
import 'package:pichat/data/models/organization_model.dart';
import 'package:pichat/data/models/user_model.dart';

// Import tables
import 'tables/user_table.dart';
import 'tables/organization_table.dart';
import 'tables/chat_table.dart';
import 'tables/contact_table.dart';

part 'app_database.g.dart';

@DriftDatabase(
  tables: [Users, Organizations, UserOrganizations, Chats, Contacts, Medias, ChatLogs],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) async => await m.createAll(),
    onUpgrade: (m, from, to) async {
      // Add migration logic here if needed
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
        location: const Value('local'), // Update location to local
      ),
    );
  }
}