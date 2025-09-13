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
  DateTimeColumn get createdAt => dateTime().clientDefault(() => DateTime.now())();
  DateTimeColumn get updatedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

