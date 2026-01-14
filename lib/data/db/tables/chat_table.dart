import 'package:drift/drift.dart';

@DataClassName('ChatData')
class Chats extends Table {
  IntColumn get id => integer().unique()();
  TextColumn get uuid => text().unique()();
  IntColumn get orgId => integer()();
  TextColumn get wamId => text().nullable()(); // WhatsApp specific ID
  IntColumn get contactId => integer()();
  IntColumn get userId => integer().nullable()();
  TextColumn get type => text()(); // e.g., 'inbound', 'outbound'
  TextColumn get metadata => text().nullable()();
  IntColumn get mediaId => integer().nullable()();
  TextColumn get status => text().withDefault(const Constant('pending'))(); // e.g., 'pending', 'sent', 'delivered', 'read'
  BoolColumn get isRead => boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt => dateTime().clientDefault(() => DateTime.now())();
  DateTimeColumn get updatedAt => dateTime().nullable()();
  DateTimeColumn get deletedAt => dateTime().nullable()();
  IntColumn get deletedBy => integer().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('MediaData')
class Medias extends Table {
  IntColumn get id => integer().unique()();
  IntColumn get mediaId => integer().nullable()();
  TextColumn get name => text().nullable()();
  TextColumn get path => text().nullable()();
  TextColumn get metaUrl => text().nullable()();
  TextColumn get location => text().nullable()();
  TextColumn get type => text().nullable()();
  TextColumn get size => text().nullable()();
  DateTimeColumn get createdAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('ChatLogsData')
class ChatLogs extends Table {
  IntColumn get id => integer().unique()();
  IntColumn get chatId => integer()();
  TextColumn get metadata => text().nullable()();
  DateTimeColumn get createdAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}