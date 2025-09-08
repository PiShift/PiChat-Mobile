import 'dart:convert';
import 'dart:io';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:pichat/data/models/chat_model.dart';
import 'package:pichat/data/models/organization_model.dart';
import 'package:pichat/data/models/user_model.dart';

// Import tables
import 'tables/user_table.dart';
import 'tables/organization_table.dart';
import 'tables/chat_table.dart';

part 'app_database.g.dart';

@DriftDatabase(
  tables: [Users, Organizations, UserOrganizations, Chats],
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
        id: Value(chat.id!),
        orgId: chat.orgId,
        uuid: chat.uuid,
        wamId: Value(chat.wamId),
        contactId: chat.contactId,
        userId: chat.userId,
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


}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    final file = File(p.join(dbFolder.path, 'pichat.db'));
    return NativeDatabase(file);
  });
}
