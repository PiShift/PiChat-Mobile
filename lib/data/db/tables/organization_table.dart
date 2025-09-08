import 'package:drift/drift.dart';

@DataClassName('OrganizationData')
class Organizations extends Table {
  IntColumn get id => integer()();
  TextColumn get identifier => text().unique()();
  TextColumn get name => text()();
  TextColumn get metadata => text().nullable()();
  DateTimeColumn get createdAt => dateTime().clientDefault(() => DateTime.now())();

  @override
  Set<Column> get primaryKey => {id};
}

class UserOrganizations extends Table {
  IntColumn get userId => integer()();
  IntColumn get orgId => integer()();

  @override
  Set<Column> get primaryKey => {userId, orgId};
}
