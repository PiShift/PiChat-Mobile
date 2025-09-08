import 'package:drift/drift.dart';

@DataClassName('ChatData')
class Chats extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get orgId => integer()();
  TextColumn get uuid => text().unique()();
  TextColumn get wamId => text().nullable()(); // WhatsApp specific ID
  IntColumn get contactId => integer()();
  IntColumn get userId => integer()();
  TextColumn get type => text()(); // e.g., 'inbound', 'outbound'
  TextColumn get metadata => text().nullable()();
  IntColumn get mediaId => integer().nullable()();
  TextColumn get status => text().withDefault(const Constant('pending'))(); // e.g., 'pending', 'sent', 'delivered', 'read'
  BoolColumn get isRead => boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt => dateTime().clientDefault(() => DateTime.now())();
  DateTimeColumn get updatedAt => dateTime().nullable()();
}

