import 'package:drift/drift.dart';

/// Non-message entries in a conversation: ticket changes, notes and calls.
///
/// The server builds a thread from `chat_logs`, where every entry is a
/// (entity_type, entity_id) pair — messages are just one type among several.
/// The app used to keep only the messages and drop the rest, so a conversation
/// showed no record of a call, of who it was assigned to, or of when it was
/// closed.
///
/// `payload` holds the server's `value` object verbatim rather than being
/// spread across typed columns. The shape differs per kind and will keep
/// growing, and this table exists to render entries, not to query their
/// internals — so storing the JSON avoids a schema migration every time the
/// backend adds a field.
/// Named explicitly so the generated row class does not collide with the
/// `TimelineEvent` domain model that wraps it.
@DataClassName('TimelineEventRow')
class TimelineEvents extends Table {
  /// `chat_logs.id` — unique across every entity type, unlike `entity_id`.
  IntColumn get id => integer().unique()();

  IntColumn get contactId => integer()();

  /// `ticket`, `notes` or `call`.
  TextColumn get kind => text()();

  /// The server's `value` object, as JSON.
  TextColumn get payload => text()();

  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}
