import 'package:drift/drift.dart';

@DataClassName('ContactData')
class Contacts extends Table {
  IntColumn get id => integer().unique()();
  TextColumn get uuid => text().unique()();
  IntColumn get orgId => integer()();
  TextColumn get firstName => text().nullable()();
  TextColumn get lastName => text().nullable()();
  TextColumn get fullName => text().nullable()();
  TextColumn get phone => text()();
  TextColumn get formattedPhone => text()();
  DateTimeColumn get latestChatCreatedAt => dateTime().nullable()();
  TextColumn get avatar => text().nullable()();
  IntColumn get unreadCount => integer().withDefault(const Constant(0))();
  IntColumn get unreadMessages => integer().withDefault(const Constant(0))();
  IntColumn get lastChatId => integer().nullable()();
  /// Current ticket ownership, denormalised from the server so the chat list
  /// can label a row and the thread header can show who holds it without a
  /// per-row lookup.
  TextColumn get assignedAgentName => text().nullable()();
  IntColumn get assignedAgentId => integer().nullable()();
  TextColumn get ticketStatus => text().nullable()();
  DateTimeColumn get createdAt => dateTime().clientDefault(() => DateTime.now())();
  DateTimeColumn get updatedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

