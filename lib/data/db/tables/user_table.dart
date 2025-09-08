import 'package:drift/drift.dart';

@DataClassName('UserData')
class Users extends Table {
  IntColumn get id => integer()();
  TextColumn get firstName => text()();
  TextColumn get lastName => text()();
  TextColumn get email => text()();
  TextColumn get phone => text().nullable()();
  TextColumn get avatar => text().nullable()();
  TextColumn get role => text().withDefault(const Constant('user'))();
  IntColumn get status => integer().withDefault(const Constant(0))();
  DateTimeColumn get createdAt => dateTime().clientDefault(() => DateTime.now())();

  @override
  Set<Column> get primaryKey => {id};
}
