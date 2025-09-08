// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_database.dart';

// ignore_for_file: type=lint
class $UsersTable extends Users with TableInfo<$UsersTable, UserData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $UsersTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
      'id', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: false);
  static const VerificationMeta _firstNameMeta =
      const VerificationMeta('firstName');
  @override
  late final GeneratedColumn<String> firstName = GeneratedColumn<String>(
      'first_name', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _lastNameMeta =
      const VerificationMeta('lastName');
  @override
  late final GeneratedColumn<String> lastName = GeneratedColumn<String>(
      'last_name', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _emailMeta = const VerificationMeta('email');
  @override
  late final GeneratedColumn<String> email = GeneratedColumn<String>(
      'email', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _phoneMeta = const VerificationMeta('phone');
  @override
  late final GeneratedColumn<String> phone = GeneratedColumn<String>(
      'phone', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _avatarMeta = const VerificationMeta('avatar');
  @override
  late final GeneratedColumn<String> avatar = GeneratedColumn<String>(
      'avatar', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _roleMeta = const VerificationMeta('role');
  @override
  late final GeneratedColumn<String> role = GeneratedColumn<String>(
      'role', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant('user'));
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<int> status = GeneratedColumn<int>(
      'status', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(0));
  static const VerificationMeta _createdAtMeta =
      const VerificationMeta('createdAt');
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
      'created_at', aliasedName, false,
      type: DriftSqlType.dateTime,
      requiredDuringInsert: false,
      clientDefault: () => DateTime.now());
  @override
  List<GeneratedColumn> get $columns =>
      [id, firstName, lastName, email, phone, avatar, role, status, createdAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'users';
  @override
  VerificationContext validateIntegrity(Insertable<UserData> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('first_name')) {
      context.handle(_firstNameMeta,
          firstName.isAcceptableOrUnknown(data['first_name']!, _firstNameMeta));
    } else if (isInserting) {
      context.missing(_firstNameMeta);
    }
    if (data.containsKey('last_name')) {
      context.handle(_lastNameMeta,
          lastName.isAcceptableOrUnknown(data['last_name']!, _lastNameMeta));
    } else if (isInserting) {
      context.missing(_lastNameMeta);
    }
    if (data.containsKey('email')) {
      context.handle(
          _emailMeta, email.isAcceptableOrUnknown(data['email']!, _emailMeta));
    } else if (isInserting) {
      context.missing(_emailMeta);
    }
    if (data.containsKey('phone')) {
      context.handle(
          _phoneMeta, phone.isAcceptableOrUnknown(data['phone']!, _phoneMeta));
    }
    if (data.containsKey('avatar')) {
      context.handle(_avatarMeta,
          avatar.isAcceptableOrUnknown(data['avatar']!, _avatarMeta));
    }
    if (data.containsKey('role')) {
      context.handle(
          _roleMeta, role.isAcceptableOrUnknown(data['role']!, _roleMeta));
    }
    if (data.containsKey('status')) {
      context.handle(_statusMeta,
          status.isAcceptableOrUnknown(data['status']!, _statusMeta));
    }
    if (data.containsKey('created_at')) {
      context.handle(_createdAtMeta,
          createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  UserData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return UserData(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      firstName: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}first_name'])!,
      lastName: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}last_name'])!,
      email: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}email'])!,
      phone: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}phone']),
      avatar: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}avatar']),
      role: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}role'])!,
      status: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}status'])!,
      createdAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}created_at'])!,
    );
  }

  @override
  $UsersTable createAlias(String alias) {
    return $UsersTable(attachedDatabase, alias);
  }
}

class UserData extends DataClass implements Insertable<UserData> {
  final int id;
  final String firstName;
  final String lastName;
  final String email;
  final String? phone;
  final String? avatar;
  final String role;
  final int status;
  final DateTime createdAt;
  const UserData(
      {required this.id,
      required this.firstName,
      required this.lastName,
      required this.email,
      this.phone,
      this.avatar,
      required this.role,
      required this.status,
      required this.createdAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['first_name'] = Variable<String>(firstName);
    map['last_name'] = Variable<String>(lastName);
    map['email'] = Variable<String>(email);
    if (!nullToAbsent || phone != null) {
      map['phone'] = Variable<String>(phone);
    }
    if (!nullToAbsent || avatar != null) {
      map['avatar'] = Variable<String>(avatar);
    }
    map['role'] = Variable<String>(role);
    map['status'] = Variable<int>(status);
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  UsersCompanion toCompanion(bool nullToAbsent) {
    return UsersCompanion(
      id: Value(id),
      firstName: Value(firstName),
      lastName: Value(lastName),
      email: Value(email),
      phone:
          phone == null && nullToAbsent ? const Value.absent() : Value(phone),
      avatar:
          avatar == null && nullToAbsent ? const Value.absent() : Value(avatar),
      role: Value(role),
      status: Value(status),
      createdAt: Value(createdAt),
    );
  }

  factory UserData.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return UserData(
      id: serializer.fromJson<int>(json['id']),
      firstName: serializer.fromJson<String>(json['firstName']),
      lastName: serializer.fromJson<String>(json['lastName']),
      email: serializer.fromJson<String>(json['email']),
      phone: serializer.fromJson<String?>(json['phone']),
      avatar: serializer.fromJson<String?>(json['avatar']),
      role: serializer.fromJson<String>(json['role']),
      status: serializer.fromJson<int>(json['status']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'firstName': serializer.toJson<String>(firstName),
      'lastName': serializer.toJson<String>(lastName),
      'email': serializer.toJson<String>(email),
      'phone': serializer.toJson<String?>(phone),
      'avatar': serializer.toJson<String?>(avatar),
      'role': serializer.toJson<String>(role),
      'status': serializer.toJson<int>(status),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  UserData copyWith(
          {int? id,
          String? firstName,
          String? lastName,
          String? email,
          Value<String?> phone = const Value.absent(),
          Value<String?> avatar = const Value.absent(),
          String? role,
          int? status,
          DateTime? createdAt}) =>
      UserData(
        id: id ?? this.id,
        firstName: firstName ?? this.firstName,
        lastName: lastName ?? this.lastName,
        email: email ?? this.email,
        phone: phone.present ? phone.value : this.phone,
        avatar: avatar.present ? avatar.value : this.avatar,
        role: role ?? this.role,
        status: status ?? this.status,
        createdAt: createdAt ?? this.createdAt,
      );
  UserData copyWithCompanion(UsersCompanion data) {
    return UserData(
      id: data.id.present ? data.id.value : this.id,
      firstName: data.firstName.present ? data.firstName.value : this.firstName,
      lastName: data.lastName.present ? data.lastName.value : this.lastName,
      email: data.email.present ? data.email.value : this.email,
      phone: data.phone.present ? data.phone.value : this.phone,
      avatar: data.avatar.present ? data.avatar.value : this.avatar,
      role: data.role.present ? data.role.value : this.role,
      status: data.status.present ? data.status.value : this.status,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('UserData(')
          ..write('id: $id, ')
          ..write('firstName: $firstName, ')
          ..write('lastName: $lastName, ')
          ..write('email: $email, ')
          ..write('phone: $phone, ')
          ..write('avatar: $avatar, ')
          ..write('role: $role, ')
          ..write('status: $status, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
      id, firstName, lastName, email, phone, avatar, role, status, createdAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is UserData &&
          other.id == this.id &&
          other.firstName == this.firstName &&
          other.lastName == this.lastName &&
          other.email == this.email &&
          other.phone == this.phone &&
          other.avatar == this.avatar &&
          other.role == this.role &&
          other.status == this.status &&
          other.createdAt == this.createdAt);
}

class UsersCompanion extends UpdateCompanion<UserData> {
  final Value<int> id;
  final Value<String> firstName;
  final Value<String> lastName;
  final Value<String> email;
  final Value<String?> phone;
  final Value<String?> avatar;
  final Value<String> role;
  final Value<int> status;
  final Value<DateTime> createdAt;
  const UsersCompanion({
    this.id = const Value.absent(),
    this.firstName = const Value.absent(),
    this.lastName = const Value.absent(),
    this.email = const Value.absent(),
    this.phone = const Value.absent(),
    this.avatar = const Value.absent(),
    this.role = const Value.absent(),
    this.status = const Value.absent(),
    this.createdAt = const Value.absent(),
  });
  UsersCompanion.insert({
    this.id = const Value.absent(),
    required String firstName,
    required String lastName,
    required String email,
    this.phone = const Value.absent(),
    this.avatar = const Value.absent(),
    this.role = const Value.absent(),
    this.status = const Value.absent(),
    this.createdAt = const Value.absent(),
  })  : firstName = Value(firstName),
        lastName = Value(lastName),
        email = Value(email);
  static Insertable<UserData> custom({
    Expression<int>? id,
    Expression<String>? firstName,
    Expression<String>? lastName,
    Expression<String>? email,
    Expression<String>? phone,
    Expression<String>? avatar,
    Expression<String>? role,
    Expression<int>? status,
    Expression<DateTime>? createdAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (firstName != null) 'first_name': firstName,
      if (lastName != null) 'last_name': lastName,
      if (email != null) 'email': email,
      if (phone != null) 'phone': phone,
      if (avatar != null) 'avatar': avatar,
      if (role != null) 'role': role,
      if (status != null) 'status': status,
      if (createdAt != null) 'created_at': createdAt,
    });
  }

  UsersCompanion copyWith(
      {Value<int>? id,
      Value<String>? firstName,
      Value<String>? lastName,
      Value<String>? email,
      Value<String?>? phone,
      Value<String?>? avatar,
      Value<String>? role,
      Value<int>? status,
      Value<DateTime>? createdAt}) {
    return UsersCompanion(
      id: id ?? this.id,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      avatar: avatar ?? this.avatar,
      role: role ?? this.role,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (firstName.present) {
      map['first_name'] = Variable<String>(firstName.value);
    }
    if (lastName.present) {
      map['last_name'] = Variable<String>(lastName.value);
    }
    if (email.present) {
      map['email'] = Variable<String>(email.value);
    }
    if (phone.present) {
      map['phone'] = Variable<String>(phone.value);
    }
    if (avatar.present) {
      map['avatar'] = Variable<String>(avatar.value);
    }
    if (role.present) {
      map['role'] = Variable<String>(role.value);
    }
    if (status.present) {
      map['status'] = Variable<int>(status.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('UsersCompanion(')
          ..write('id: $id, ')
          ..write('firstName: $firstName, ')
          ..write('lastName: $lastName, ')
          ..write('email: $email, ')
          ..write('phone: $phone, ')
          ..write('avatar: $avatar, ')
          ..write('role: $role, ')
          ..write('status: $status, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }
}

class $OrganizationsTable extends Organizations
    with TableInfo<$OrganizationsTable, OrganizationData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $OrganizationsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
      'id', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: false);
  static const VerificationMeta _identifierMeta =
      const VerificationMeta('identifier');
  @override
  late final GeneratedColumn<String> identifier = GeneratedColumn<String>(
      'identifier', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: true,
      defaultConstraints: GeneratedColumn.constraintIsAlways('UNIQUE'));
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
      'name', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _metadataMeta =
      const VerificationMeta('metadata');
  @override
  late final GeneratedColumn<String> metadata = GeneratedColumn<String>(
      'metadata', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _createdAtMeta =
      const VerificationMeta('createdAt');
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
      'created_at', aliasedName, false,
      type: DriftSqlType.dateTime,
      requiredDuringInsert: false,
      clientDefault: () => DateTime.now());
  @override
  List<GeneratedColumn> get $columns =>
      [id, identifier, name, metadata, createdAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'organizations';
  @override
  VerificationContext validateIntegrity(Insertable<OrganizationData> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('identifier')) {
      context.handle(
          _identifierMeta,
          identifier.isAcceptableOrUnknown(
              data['identifier']!, _identifierMeta));
    } else if (isInserting) {
      context.missing(_identifierMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
          _nameMeta, name.isAcceptableOrUnknown(data['name']!, _nameMeta));
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('metadata')) {
      context.handle(_metadataMeta,
          metadata.isAcceptableOrUnknown(data['metadata']!, _metadataMeta));
    }
    if (data.containsKey('created_at')) {
      context.handle(_createdAtMeta,
          createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  OrganizationData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return OrganizationData(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      identifier: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}identifier'])!,
      name: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}name'])!,
      metadata: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}metadata']),
      createdAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}created_at'])!,
    );
  }

  @override
  $OrganizationsTable createAlias(String alias) {
    return $OrganizationsTable(attachedDatabase, alias);
  }
}

class OrganizationData extends DataClass
    implements Insertable<OrganizationData> {
  final int id;
  final String identifier;
  final String name;
  final String? metadata;
  final DateTime createdAt;
  const OrganizationData(
      {required this.id,
      required this.identifier,
      required this.name,
      this.metadata,
      required this.createdAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['identifier'] = Variable<String>(identifier);
    map['name'] = Variable<String>(name);
    if (!nullToAbsent || metadata != null) {
      map['metadata'] = Variable<String>(metadata);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  OrganizationsCompanion toCompanion(bool nullToAbsent) {
    return OrganizationsCompanion(
      id: Value(id),
      identifier: Value(identifier),
      name: Value(name),
      metadata: metadata == null && nullToAbsent
          ? const Value.absent()
          : Value(metadata),
      createdAt: Value(createdAt),
    );
  }

  factory OrganizationData.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return OrganizationData(
      id: serializer.fromJson<int>(json['id']),
      identifier: serializer.fromJson<String>(json['identifier']),
      name: serializer.fromJson<String>(json['name']),
      metadata: serializer.fromJson<String?>(json['metadata']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'identifier': serializer.toJson<String>(identifier),
      'name': serializer.toJson<String>(name),
      'metadata': serializer.toJson<String?>(metadata),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  OrganizationData copyWith(
          {int? id,
          String? identifier,
          String? name,
          Value<String?> metadata = const Value.absent(),
          DateTime? createdAt}) =>
      OrganizationData(
        id: id ?? this.id,
        identifier: identifier ?? this.identifier,
        name: name ?? this.name,
        metadata: metadata.present ? metadata.value : this.metadata,
        createdAt: createdAt ?? this.createdAt,
      );
  OrganizationData copyWithCompanion(OrganizationsCompanion data) {
    return OrganizationData(
      id: data.id.present ? data.id.value : this.id,
      identifier:
          data.identifier.present ? data.identifier.value : this.identifier,
      name: data.name.present ? data.name.value : this.name,
      metadata: data.metadata.present ? data.metadata.value : this.metadata,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('OrganizationData(')
          ..write('id: $id, ')
          ..write('identifier: $identifier, ')
          ..write('name: $name, ')
          ..write('metadata: $metadata, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, identifier, name, metadata, createdAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is OrganizationData &&
          other.id == this.id &&
          other.identifier == this.identifier &&
          other.name == this.name &&
          other.metadata == this.metadata &&
          other.createdAt == this.createdAt);
}

class OrganizationsCompanion extends UpdateCompanion<OrganizationData> {
  final Value<int> id;
  final Value<String> identifier;
  final Value<String> name;
  final Value<String?> metadata;
  final Value<DateTime> createdAt;
  const OrganizationsCompanion({
    this.id = const Value.absent(),
    this.identifier = const Value.absent(),
    this.name = const Value.absent(),
    this.metadata = const Value.absent(),
    this.createdAt = const Value.absent(),
  });
  OrganizationsCompanion.insert({
    this.id = const Value.absent(),
    required String identifier,
    required String name,
    this.metadata = const Value.absent(),
    this.createdAt = const Value.absent(),
  })  : identifier = Value(identifier),
        name = Value(name);
  static Insertable<OrganizationData> custom({
    Expression<int>? id,
    Expression<String>? identifier,
    Expression<String>? name,
    Expression<String>? metadata,
    Expression<DateTime>? createdAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (identifier != null) 'identifier': identifier,
      if (name != null) 'name': name,
      if (metadata != null) 'metadata': metadata,
      if (createdAt != null) 'created_at': createdAt,
    });
  }

  OrganizationsCompanion copyWith(
      {Value<int>? id,
      Value<String>? identifier,
      Value<String>? name,
      Value<String?>? metadata,
      Value<DateTime>? createdAt}) {
    return OrganizationsCompanion(
      id: id ?? this.id,
      identifier: identifier ?? this.identifier,
      name: name ?? this.name,
      metadata: metadata ?? this.metadata,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (identifier.present) {
      map['identifier'] = Variable<String>(identifier.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (metadata.present) {
      map['metadata'] = Variable<String>(metadata.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('OrganizationsCompanion(')
          ..write('id: $id, ')
          ..write('identifier: $identifier, ')
          ..write('name: $name, ')
          ..write('metadata: $metadata, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }
}

class $UserOrganizationsTable extends UserOrganizations
    with TableInfo<$UserOrganizationsTable, UserOrganization> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $UserOrganizationsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _userIdMeta = const VerificationMeta('userId');
  @override
  late final GeneratedColumn<int> userId = GeneratedColumn<int>(
      'user_id', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _orgIdMeta = const VerificationMeta('orgId');
  @override
  late final GeneratedColumn<int> orgId = GeneratedColumn<int>(
      'org_id', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns => [userId, orgId];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'user_organizations';
  @override
  VerificationContext validateIntegrity(Insertable<UserOrganization> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('user_id')) {
      context.handle(_userIdMeta,
          userId.isAcceptableOrUnknown(data['user_id']!, _userIdMeta));
    } else if (isInserting) {
      context.missing(_userIdMeta);
    }
    if (data.containsKey('org_id')) {
      context.handle(
          _orgIdMeta, orgId.isAcceptableOrUnknown(data['org_id']!, _orgIdMeta));
    } else if (isInserting) {
      context.missing(_orgIdMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {userId, orgId};
  @override
  UserOrganization map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return UserOrganization(
      userId: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}user_id'])!,
      orgId: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}org_id'])!,
    );
  }

  @override
  $UserOrganizationsTable createAlias(String alias) {
    return $UserOrganizationsTable(attachedDatabase, alias);
  }
}

class UserOrganization extends DataClass
    implements Insertable<UserOrganization> {
  final int userId;
  final int orgId;
  const UserOrganization({required this.userId, required this.orgId});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['user_id'] = Variable<int>(userId);
    map['org_id'] = Variable<int>(orgId);
    return map;
  }

  UserOrganizationsCompanion toCompanion(bool nullToAbsent) {
    return UserOrganizationsCompanion(
      userId: Value(userId),
      orgId: Value(orgId),
    );
  }

  factory UserOrganization.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return UserOrganization(
      userId: serializer.fromJson<int>(json['userId']),
      orgId: serializer.fromJson<int>(json['orgId']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'userId': serializer.toJson<int>(userId),
      'orgId': serializer.toJson<int>(orgId),
    };
  }

  UserOrganization copyWith({int? userId, int? orgId}) => UserOrganization(
        userId: userId ?? this.userId,
        orgId: orgId ?? this.orgId,
      );
  UserOrganization copyWithCompanion(UserOrganizationsCompanion data) {
    return UserOrganization(
      userId: data.userId.present ? data.userId.value : this.userId,
      orgId: data.orgId.present ? data.orgId.value : this.orgId,
    );
  }

  @override
  String toString() {
    return (StringBuffer('UserOrganization(')
          ..write('userId: $userId, ')
          ..write('orgId: $orgId')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(userId, orgId);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is UserOrganization &&
          other.userId == this.userId &&
          other.orgId == this.orgId);
}

class UserOrganizationsCompanion extends UpdateCompanion<UserOrganization> {
  final Value<int> userId;
  final Value<int> orgId;
  final Value<int> rowid;
  const UserOrganizationsCompanion({
    this.userId = const Value.absent(),
    this.orgId = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  UserOrganizationsCompanion.insert({
    required int userId,
    required int orgId,
    this.rowid = const Value.absent(),
  })  : userId = Value(userId),
        orgId = Value(orgId);
  static Insertable<UserOrganization> custom({
    Expression<int>? userId,
    Expression<int>? orgId,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (userId != null) 'user_id': userId,
      if (orgId != null) 'org_id': orgId,
      if (rowid != null) 'rowid': rowid,
    });
  }

  UserOrganizationsCompanion copyWith(
      {Value<int>? userId, Value<int>? orgId, Value<int>? rowid}) {
    return UserOrganizationsCompanion(
      userId: userId ?? this.userId,
      orgId: orgId ?? this.orgId,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (userId.present) {
      map['user_id'] = Variable<int>(userId.value);
    }
    if (orgId.present) {
      map['org_id'] = Variable<int>(orgId.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('UserOrganizationsCompanion(')
          ..write('userId: $userId, ')
          ..write('orgId: $orgId, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ChatsTable extends Chats with TableInfo<$ChatsTable, ChatData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ChatsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
      'id', aliasedName, false,
      hasAutoIncrement: true,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('PRIMARY KEY AUTOINCREMENT'));
  static const VerificationMeta _orgIdMeta = const VerificationMeta('orgId');
  @override
  late final GeneratedColumn<int> orgId = GeneratedColumn<int>(
      'org_id', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _uuidMeta = const VerificationMeta('uuid');
  @override
  late final GeneratedColumn<String> uuid = GeneratedColumn<String>(
      'uuid', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: true,
      defaultConstraints: GeneratedColumn.constraintIsAlways('UNIQUE'));
  static const VerificationMeta _wamIdMeta = const VerificationMeta('wamId');
  @override
  late final GeneratedColumn<String> wamId = GeneratedColumn<String>(
      'wam_id', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _contactIdMeta =
      const VerificationMeta('contactId');
  @override
  late final GeneratedColumn<int> contactId = GeneratedColumn<int>(
      'contact_id', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _userIdMeta = const VerificationMeta('userId');
  @override
  late final GeneratedColumn<int> userId = GeneratedColumn<int>(
      'user_id', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _typeMeta = const VerificationMeta('type');
  @override
  late final GeneratedColumn<String> type = GeneratedColumn<String>(
      'type', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _metadataMeta =
      const VerificationMeta('metadata');
  @override
  late final GeneratedColumn<String> metadata = GeneratedColumn<String>(
      'metadata', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _mediaIdMeta =
      const VerificationMeta('mediaId');
  @override
  late final GeneratedColumn<int> mediaId = GeneratedColumn<int>(
      'media_id', aliasedName, true,
      type: DriftSqlType.int, requiredDuringInsert: false);
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
      'status', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant('pending'));
  static const VerificationMeta _isReadMeta = const VerificationMeta('isRead');
  @override
  late final GeneratedColumn<bool> isRead = GeneratedColumn<bool>(
      'is_read', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('CHECK ("is_read" IN (0, 1))'),
      defaultValue: const Constant(false));
  static const VerificationMeta _createdAtMeta =
      const VerificationMeta('createdAt');
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
      'created_at', aliasedName, false,
      type: DriftSqlType.dateTime,
      requiredDuringInsert: false,
      clientDefault: () => DateTime.now());
  static const VerificationMeta _updatedAtMeta =
      const VerificationMeta('updatedAt');
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
      'updated_at', aliasedName, true,
      type: DriftSqlType.dateTime, requiredDuringInsert: false);
  @override
  List<GeneratedColumn> get $columns => [
        id,
        orgId,
        uuid,
        wamId,
        contactId,
        userId,
        type,
        metadata,
        mediaId,
        status,
        isRead,
        createdAt,
        updatedAt
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'chats';
  @override
  VerificationContext validateIntegrity(Insertable<ChatData> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('org_id')) {
      context.handle(
          _orgIdMeta, orgId.isAcceptableOrUnknown(data['org_id']!, _orgIdMeta));
    } else if (isInserting) {
      context.missing(_orgIdMeta);
    }
    if (data.containsKey('uuid')) {
      context.handle(
          _uuidMeta, uuid.isAcceptableOrUnknown(data['uuid']!, _uuidMeta));
    } else if (isInserting) {
      context.missing(_uuidMeta);
    }
    if (data.containsKey('wam_id')) {
      context.handle(
          _wamIdMeta, wamId.isAcceptableOrUnknown(data['wam_id']!, _wamIdMeta));
    }
    if (data.containsKey('contact_id')) {
      context.handle(_contactIdMeta,
          contactId.isAcceptableOrUnknown(data['contact_id']!, _contactIdMeta));
    } else if (isInserting) {
      context.missing(_contactIdMeta);
    }
    if (data.containsKey('user_id')) {
      context.handle(_userIdMeta,
          userId.isAcceptableOrUnknown(data['user_id']!, _userIdMeta));
    } else if (isInserting) {
      context.missing(_userIdMeta);
    }
    if (data.containsKey('type')) {
      context.handle(
          _typeMeta, type.isAcceptableOrUnknown(data['type']!, _typeMeta));
    } else if (isInserting) {
      context.missing(_typeMeta);
    }
    if (data.containsKey('metadata')) {
      context.handle(_metadataMeta,
          metadata.isAcceptableOrUnknown(data['metadata']!, _metadataMeta));
    }
    if (data.containsKey('media_id')) {
      context.handle(_mediaIdMeta,
          mediaId.isAcceptableOrUnknown(data['media_id']!, _mediaIdMeta));
    }
    if (data.containsKey('status')) {
      context.handle(_statusMeta,
          status.isAcceptableOrUnknown(data['status']!, _statusMeta));
    }
    if (data.containsKey('is_read')) {
      context.handle(_isReadMeta,
          isRead.isAcceptableOrUnknown(data['is_read']!, _isReadMeta));
    }
    if (data.containsKey('created_at')) {
      context.handle(_createdAtMeta,
          createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta));
    }
    if (data.containsKey('updated_at')) {
      context.handle(_updatedAtMeta,
          updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  ChatData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ChatData(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      orgId: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}org_id'])!,
      uuid: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}uuid'])!,
      wamId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}wam_id']),
      contactId: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}contact_id'])!,
      userId: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}user_id'])!,
      type: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}type'])!,
      metadata: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}metadata']),
      mediaId: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}media_id']),
      status: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}status'])!,
      isRead: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}is_read'])!,
      createdAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}created_at'])!,
      updatedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}updated_at']),
    );
  }

  @override
  $ChatsTable createAlias(String alias) {
    return $ChatsTable(attachedDatabase, alias);
  }
}

class ChatData extends DataClass implements Insertable<ChatData> {
  final int id;
  final int orgId;
  final String uuid;
  final String? wamId;
  final int contactId;
  final int userId;
  final String type;
  final String? metadata;
  final int? mediaId;
  final String status;
  final bool isRead;
  final DateTime createdAt;
  final DateTime? updatedAt;
  const ChatData(
      {required this.id,
      required this.orgId,
      required this.uuid,
      this.wamId,
      required this.contactId,
      required this.userId,
      required this.type,
      this.metadata,
      this.mediaId,
      required this.status,
      required this.isRead,
      required this.createdAt,
      this.updatedAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['org_id'] = Variable<int>(orgId);
    map['uuid'] = Variable<String>(uuid);
    if (!nullToAbsent || wamId != null) {
      map['wam_id'] = Variable<String>(wamId);
    }
    map['contact_id'] = Variable<int>(contactId);
    map['user_id'] = Variable<int>(userId);
    map['type'] = Variable<String>(type);
    if (!nullToAbsent || metadata != null) {
      map['metadata'] = Variable<String>(metadata);
    }
    if (!nullToAbsent || mediaId != null) {
      map['media_id'] = Variable<int>(mediaId);
    }
    map['status'] = Variable<String>(status);
    map['is_read'] = Variable<bool>(isRead);
    map['created_at'] = Variable<DateTime>(createdAt);
    if (!nullToAbsent || updatedAt != null) {
      map['updated_at'] = Variable<DateTime>(updatedAt);
    }
    return map;
  }

  ChatsCompanion toCompanion(bool nullToAbsent) {
    return ChatsCompanion(
      id: Value(id),
      orgId: Value(orgId),
      uuid: Value(uuid),
      wamId:
          wamId == null && nullToAbsent ? const Value.absent() : Value(wamId),
      contactId: Value(contactId),
      userId: Value(userId),
      type: Value(type),
      metadata: metadata == null && nullToAbsent
          ? const Value.absent()
          : Value(metadata),
      mediaId: mediaId == null && nullToAbsent
          ? const Value.absent()
          : Value(mediaId),
      status: Value(status),
      isRead: Value(isRead),
      createdAt: Value(createdAt),
      updatedAt: updatedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(updatedAt),
    );
  }

  factory ChatData.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ChatData(
      id: serializer.fromJson<int>(json['id']),
      orgId: serializer.fromJson<int>(json['orgId']),
      uuid: serializer.fromJson<String>(json['uuid']),
      wamId: serializer.fromJson<String?>(json['wamId']),
      contactId: serializer.fromJson<int>(json['contactId']),
      userId: serializer.fromJson<int>(json['userId']),
      type: serializer.fromJson<String>(json['type']),
      metadata: serializer.fromJson<String?>(json['metadata']),
      mediaId: serializer.fromJson<int?>(json['mediaId']),
      status: serializer.fromJson<String>(json['status']),
      isRead: serializer.fromJson<bool>(json['isRead']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime?>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'orgId': serializer.toJson<int>(orgId),
      'uuid': serializer.toJson<String>(uuid),
      'wamId': serializer.toJson<String?>(wamId),
      'contactId': serializer.toJson<int>(contactId),
      'userId': serializer.toJson<int>(userId),
      'type': serializer.toJson<String>(type),
      'metadata': serializer.toJson<String?>(metadata),
      'mediaId': serializer.toJson<int?>(mediaId),
      'status': serializer.toJson<String>(status),
      'isRead': serializer.toJson<bool>(isRead),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime?>(updatedAt),
    };
  }

  ChatData copyWith(
          {int? id,
          int? orgId,
          String? uuid,
          Value<String?> wamId = const Value.absent(),
          int? contactId,
          int? userId,
          String? type,
          Value<String?> metadata = const Value.absent(),
          Value<int?> mediaId = const Value.absent(),
          String? status,
          bool? isRead,
          DateTime? createdAt,
          Value<DateTime?> updatedAt = const Value.absent()}) =>
      ChatData(
        id: id ?? this.id,
        orgId: orgId ?? this.orgId,
        uuid: uuid ?? this.uuid,
        wamId: wamId.present ? wamId.value : this.wamId,
        contactId: contactId ?? this.contactId,
        userId: userId ?? this.userId,
        type: type ?? this.type,
        metadata: metadata.present ? metadata.value : this.metadata,
        mediaId: mediaId.present ? mediaId.value : this.mediaId,
        status: status ?? this.status,
        isRead: isRead ?? this.isRead,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt.present ? updatedAt.value : this.updatedAt,
      );
  ChatData copyWithCompanion(ChatsCompanion data) {
    return ChatData(
      id: data.id.present ? data.id.value : this.id,
      orgId: data.orgId.present ? data.orgId.value : this.orgId,
      uuid: data.uuid.present ? data.uuid.value : this.uuid,
      wamId: data.wamId.present ? data.wamId.value : this.wamId,
      contactId: data.contactId.present ? data.contactId.value : this.contactId,
      userId: data.userId.present ? data.userId.value : this.userId,
      type: data.type.present ? data.type.value : this.type,
      metadata: data.metadata.present ? data.metadata.value : this.metadata,
      mediaId: data.mediaId.present ? data.mediaId.value : this.mediaId,
      status: data.status.present ? data.status.value : this.status,
      isRead: data.isRead.present ? data.isRead.value : this.isRead,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ChatData(')
          ..write('id: $id, ')
          ..write('orgId: $orgId, ')
          ..write('uuid: $uuid, ')
          ..write('wamId: $wamId, ')
          ..write('contactId: $contactId, ')
          ..write('userId: $userId, ')
          ..write('type: $type, ')
          ..write('metadata: $metadata, ')
          ..write('mediaId: $mediaId, ')
          ..write('status: $status, ')
          ..write('isRead: $isRead, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, orgId, uuid, wamId, contactId, userId,
      type, metadata, mediaId, status, isRead, createdAt, updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ChatData &&
          other.id == this.id &&
          other.orgId == this.orgId &&
          other.uuid == this.uuid &&
          other.wamId == this.wamId &&
          other.contactId == this.contactId &&
          other.userId == this.userId &&
          other.type == this.type &&
          other.metadata == this.metadata &&
          other.mediaId == this.mediaId &&
          other.status == this.status &&
          other.isRead == this.isRead &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class ChatsCompanion extends UpdateCompanion<ChatData> {
  final Value<int> id;
  final Value<int> orgId;
  final Value<String> uuid;
  final Value<String?> wamId;
  final Value<int> contactId;
  final Value<int> userId;
  final Value<String> type;
  final Value<String?> metadata;
  final Value<int?> mediaId;
  final Value<String> status;
  final Value<bool> isRead;
  final Value<DateTime> createdAt;
  final Value<DateTime?> updatedAt;
  const ChatsCompanion({
    this.id = const Value.absent(),
    this.orgId = const Value.absent(),
    this.uuid = const Value.absent(),
    this.wamId = const Value.absent(),
    this.contactId = const Value.absent(),
    this.userId = const Value.absent(),
    this.type = const Value.absent(),
    this.metadata = const Value.absent(),
    this.mediaId = const Value.absent(),
    this.status = const Value.absent(),
    this.isRead = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
  });
  ChatsCompanion.insert({
    this.id = const Value.absent(),
    required int orgId,
    required String uuid,
    this.wamId = const Value.absent(),
    required int contactId,
    required int userId,
    required String type,
    this.metadata = const Value.absent(),
    this.mediaId = const Value.absent(),
    this.status = const Value.absent(),
    this.isRead = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
  })  : orgId = Value(orgId),
        uuid = Value(uuid),
        contactId = Value(contactId),
        userId = Value(userId),
        type = Value(type);
  static Insertable<ChatData> custom({
    Expression<int>? id,
    Expression<int>? orgId,
    Expression<String>? uuid,
    Expression<String>? wamId,
    Expression<int>? contactId,
    Expression<int>? userId,
    Expression<String>? type,
    Expression<String>? metadata,
    Expression<int>? mediaId,
    Expression<String>? status,
    Expression<bool>? isRead,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (orgId != null) 'org_id': orgId,
      if (uuid != null) 'uuid': uuid,
      if (wamId != null) 'wam_id': wamId,
      if (contactId != null) 'contact_id': contactId,
      if (userId != null) 'user_id': userId,
      if (type != null) 'type': type,
      if (metadata != null) 'metadata': metadata,
      if (mediaId != null) 'media_id': mediaId,
      if (status != null) 'status': status,
      if (isRead != null) 'is_read': isRead,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
    });
  }

  ChatsCompanion copyWith(
      {Value<int>? id,
      Value<int>? orgId,
      Value<String>? uuid,
      Value<String?>? wamId,
      Value<int>? contactId,
      Value<int>? userId,
      Value<String>? type,
      Value<String?>? metadata,
      Value<int?>? mediaId,
      Value<String>? status,
      Value<bool>? isRead,
      Value<DateTime>? createdAt,
      Value<DateTime?>? updatedAt}) {
    return ChatsCompanion(
      id: id ?? this.id,
      orgId: orgId ?? this.orgId,
      uuid: uuid ?? this.uuid,
      wamId: wamId ?? this.wamId,
      contactId: contactId ?? this.contactId,
      userId: userId ?? this.userId,
      type: type ?? this.type,
      metadata: metadata ?? this.metadata,
      mediaId: mediaId ?? this.mediaId,
      status: status ?? this.status,
      isRead: isRead ?? this.isRead,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (orgId.present) {
      map['org_id'] = Variable<int>(orgId.value);
    }
    if (uuid.present) {
      map['uuid'] = Variable<String>(uuid.value);
    }
    if (wamId.present) {
      map['wam_id'] = Variable<String>(wamId.value);
    }
    if (contactId.present) {
      map['contact_id'] = Variable<int>(contactId.value);
    }
    if (userId.present) {
      map['user_id'] = Variable<int>(userId.value);
    }
    if (type.present) {
      map['type'] = Variable<String>(type.value);
    }
    if (metadata.present) {
      map['metadata'] = Variable<String>(metadata.value);
    }
    if (mediaId.present) {
      map['media_id'] = Variable<int>(mediaId.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (isRead.present) {
      map['is_read'] = Variable<bool>(isRead.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ChatsCompanion(')
          ..write('id: $id, ')
          ..write('orgId: $orgId, ')
          ..write('uuid: $uuid, ')
          ..write('wamId: $wamId, ')
          ..write('contactId: $contactId, ')
          ..write('userId: $userId, ')
          ..write('type: $type, ')
          ..write('metadata: $metadata, ')
          ..write('mediaId: $mediaId, ')
          ..write('status: $status, ')
          ..write('isRead: $isRead, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $UsersTable users = $UsersTable(this);
  late final $OrganizationsTable organizations = $OrganizationsTable(this);
  late final $UserOrganizationsTable userOrganizations =
      $UserOrganizationsTable(this);
  late final $ChatsTable chats = $ChatsTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities =>
      [users, organizations, userOrganizations, chats];
}

typedef $$UsersTableCreateCompanionBuilder = UsersCompanion Function({
  Value<int> id,
  required String firstName,
  required String lastName,
  required String email,
  Value<String?> phone,
  Value<String?> avatar,
  Value<String> role,
  Value<int> status,
  Value<DateTime> createdAt,
});
typedef $$UsersTableUpdateCompanionBuilder = UsersCompanion Function({
  Value<int> id,
  Value<String> firstName,
  Value<String> lastName,
  Value<String> email,
  Value<String?> phone,
  Value<String?> avatar,
  Value<String> role,
  Value<int> status,
  Value<DateTime> createdAt,
});

class $$UsersTableFilterComposer extends Composer<_$AppDatabase, $UsersTable> {
  $$UsersTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get firstName => $composableBuilder(
      column: $table.firstName, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get lastName => $composableBuilder(
      column: $table.lastName, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get email => $composableBuilder(
      column: $table.email, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get phone => $composableBuilder(
      column: $table.phone, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get avatar => $composableBuilder(
      column: $table.avatar, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get role => $composableBuilder(
      column: $table.role, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get status => $composableBuilder(
      column: $table.status, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnFilters(column));
}

class $$UsersTableOrderingComposer
    extends Composer<_$AppDatabase, $UsersTable> {
  $$UsersTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get firstName => $composableBuilder(
      column: $table.firstName, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get lastName => $composableBuilder(
      column: $table.lastName, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get email => $composableBuilder(
      column: $table.email, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get phone => $composableBuilder(
      column: $table.phone, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get avatar => $composableBuilder(
      column: $table.avatar, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get role => $composableBuilder(
      column: $table.role, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get status => $composableBuilder(
      column: $table.status, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnOrderings(column));
}

class $$UsersTableAnnotationComposer
    extends Composer<_$AppDatabase, $UsersTable> {
  $$UsersTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get firstName =>
      $composableBuilder(column: $table.firstName, builder: (column) => column);

  GeneratedColumn<String> get lastName =>
      $composableBuilder(column: $table.lastName, builder: (column) => column);

  GeneratedColumn<String> get email =>
      $composableBuilder(column: $table.email, builder: (column) => column);

  GeneratedColumn<String> get phone =>
      $composableBuilder(column: $table.phone, builder: (column) => column);

  GeneratedColumn<String> get avatar =>
      $composableBuilder(column: $table.avatar, builder: (column) => column);

  GeneratedColumn<String> get role =>
      $composableBuilder(column: $table.role, builder: (column) => column);

  GeneratedColumn<int> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);
}

class $$UsersTableTableManager extends RootTableManager<
    _$AppDatabase,
    $UsersTable,
    UserData,
    $$UsersTableFilterComposer,
    $$UsersTableOrderingComposer,
    $$UsersTableAnnotationComposer,
    $$UsersTableCreateCompanionBuilder,
    $$UsersTableUpdateCompanionBuilder,
    (UserData, BaseReferences<_$AppDatabase, $UsersTable, UserData>),
    UserData,
    PrefetchHooks Function()> {
  $$UsersTableTableManager(_$AppDatabase db, $UsersTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$UsersTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$UsersTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$UsersTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<String> firstName = const Value.absent(),
            Value<String> lastName = const Value.absent(),
            Value<String> email = const Value.absent(),
            Value<String?> phone = const Value.absent(),
            Value<String?> avatar = const Value.absent(),
            Value<String> role = const Value.absent(),
            Value<int> status = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
          }) =>
              UsersCompanion(
            id: id,
            firstName: firstName,
            lastName: lastName,
            email: email,
            phone: phone,
            avatar: avatar,
            role: role,
            status: status,
            createdAt: createdAt,
          ),
          createCompanionCallback: ({
            Value<int> id = const Value.absent(),
            required String firstName,
            required String lastName,
            required String email,
            Value<String?> phone = const Value.absent(),
            Value<String?> avatar = const Value.absent(),
            Value<String> role = const Value.absent(),
            Value<int> status = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
          }) =>
              UsersCompanion.insert(
            id: id,
            firstName: firstName,
            lastName: lastName,
            email: email,
            phone: phone,
            avatar: avatar,
            role: role,
            status: status,
            createdAt: createdAt,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$UsersTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $UsersTable,
    UserData,
    $$UsersTableFilterComposer,
    $$UsersTableOrderingComposer,
    $$UsersTableAnnotationComposer,
    $$UsersTableCreateCompanionBuilder,
    $$UsersTableUpdateCompanionBuilder,
    (UserData, BaseReferences<_$AppDatabase, $UsersTable, UserData>),
    UserData,
    PrefetchHooks Function()>;
typedef $$OrganizationsTableCreateCompanionBuilder = OrganizationsCompanion
    Function({
  Value<int> id,
  required String identifier,
  required String name,
  Value<String?> metadata,
  Value<DateTime> createdAt,
});
typedef $$OrganizationsTableUpdateCompanionBuilder = OrganizationsCompanion
    Function({
  Value<int> id,
  Value<String> identifier,
  Value<String> name,
  Value<String?> metadata,
  Value<DateTime> createdAt,
});

class $$OrganizationsTableFilterComposer
    extends Composer<_$AppDatabase, $OrganizationsTable> {
  $$OrganizationsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get identifier => $composableBuilder(
      column: $table.identifier, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get name => $composableBuilder(
      column: $table.name, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get metadata => $composableBuilder(
      column: $table.metadata, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnFilters(column));
}

class $$OrganizationsTableOrderingComposer
    extends Composer<_$AppDatabase, $OrganizationsTable> {
  $$OrganizationsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get identifier => $composableBuilder(
      column: $table.identifier, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get name => $composableBuilder(
      column: $table.name, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get metadata => $composableBuilder(
      column: $table.metadata, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnOrderings(column));
}

class $$OrganizationsTableAnnotationComposer
    extends Composer<_$AppDatabase, $OrganizationsTable> {
  $$OrganizationsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get identifier => $composableBuilder(
      column: $table.identifier, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get metadata =>
      $composableBuilder(column: $table.metadata, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);
}

class $$OrganizationsTableTableManager extends RootTableManager<
    _$AppDatabase,
    $OrganizationsTable,
    OrganizationData,
    $$OrganizationsTableFilterComposer,
    $$OrganizationsTableOrderingComposer,
    $$OrganizationsTableAnnotationComposer,
    $$OrganizationsTableCreateCompanionBuilder,
    $$OrganizationsTableUpdateCompanionBuilder,
    (
      OrganizationData,
      BaseReferences<_$AppDatabase, $OrganizationsTable, OrganizationData>
    ),
    OrganizationData,
    PrefetchHooks Function()> {
  $$OrganizationsTableTableManager(_$AppDatabase db, $OrganizationsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$OrganizationsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$OrganizationsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$OrganizationsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<String> identifier = const Value.absent(),
            Value<String> name = const Value.absent(),
            Value<String?> metadata = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
          }) =>
              OrganizationsCompanion(
            id: id,
            identifier: identifier,
            name: name,
            metadata: metadata,
            createdAt: createdAt,
          ),
          createCompanionCallback: ({
            Value<int> id = const Value.absent(),
            required String identifier,
            required String name,
            Value<String?> metadata = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
          }) =>
              OrganizationsCompanion.insert(
            id: id,
            identifier: identifier,
            name: name,
            metadata: metadata,
            createdAt: createdAt,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$OrganizationsTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $OrganizationsTable,
    OrganizationData,
    $$OrganizationsTableFilterComposer,
    $$OrganizationsTableOrderingComposer,
    $$OrganizationsTableAnnotationComposer,
    $$OrganizationsTableCreateCompanionBuilder,
    $$OrganizationsTableUpdateCompanionBuilder,
    (
      OrganizationData,
      BaseReferences<_$AppDatabase, $OrganizationsTable, OrganizationData>
    ),
    OrganizationData,
    PrefetchHooks Function()>;
typedef $$UserOrganizationsTableCreateCompanionBuilder
    = UserOrganizationsCompanion Function({
  required int userId,
  required int orgId,
  Value<int> rowid,
});
typedef $$UserOrganizationsTableUpdateCompanionBuilder
    = UserOrganizationsCompanion Function({
  Value<int> userId,
  Value<int> orgId,
  Value<int> rowid,
});

class $$UserOrganizationsTableFilterComposer
    extends Composer<_$AppDatabase, $UserOrganizationsTable> {
  $$UserOrganizationsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get userId => $composableBuilder(
      column: $table.userId, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get orgId => $composableBuilder(
      column: $table.orgId, builder: (column) => ColumnFilters(column));
}

class $$UserOrganizationsTableOrderingComposer
    extends Composer<_$AppDatabase, $UserOrganizationsTable> {
  $$UserOrganizationsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get userId => $composableBuilder(
      column: $table.userId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get orgId => $composableBuilder(
      column: $table.orgId, builder: (column) => ColumnOrderings(column));
}

class $$UserOrganizationsTableAnnotationComposer
    extends Composer<_$AppDatabase, $UserOrganizationsTable> {
  $$UserOrganizationsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get userId =>
      $composableBuilder(column: $table.userId, builder: (column) => column);

  GeneratedColumn<int> get orgId =>
      $composableBuilder(column: $table.orgId, builder: (column) => column);
}

class $$UserOrganizationsTableTableManager extends RootTableManager<
    _$AppDatabase,
    $UserOrganizationsTable,
    UserOrganization,
    $$UserOrganizationsTableFilterComposer,
    $$UserOrganizationsTableOrderingComposer,
    $$UserOrganizationsTableAnnotationComposer,
    $$UserOrganizationsTableCreateCompanionBuilder,
    $$UserOrganizationsTableUpdateCompanionBuilder,
    (
      UserOrganization,
      BaseReferences<_$AppDatabase, $UserOrganizationsTable, UserOrganization>
    ),
    UserOrganization,
    PrefetchHooks Function()> {
  $$UserOrganizationsTableTableManager(
      _$AppDatabase db, $UserOrganizationsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$UserOrganizationsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$UserOrganizationsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$UserOrganizationsTableAnnotationComposer(
                  $db: db, $table: table),
          updateCompanionCallback: ({
            Value<int> userId = const Value.absent(),
            Value<int> orgId = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              UserOrganizationsCompanion(
            userId: userId,
            orgId: orgId,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required int userId,
            required int orgId,
            Value<int> rowid = const Value.absent(),
          }) =>
              UserOrganizationsCompanion.insert(
            userId: userId,
            orgId: orgId,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$UserOrganizationsTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $UserOrganizationsTable,
    UserOrganization,
    $$UserOrganizationsTableFilterComposer,
    $$UserOrganizationsTableOrderingComposer,
    $$UserOrganizationsTableAnnotationComposer,
    $$UserOrganizationsTableCreateCompanionBuilder,
    $$UserOrganizationsTableUpdateCompanionBuilder,
    (
      UserOrganization,
      BaseReferences<_$AppDatabase, $UserOrganizationsTable, UserOrganization>
    ),
    UserOrganization,
    PrefetchHooks Function()>;
typedef $$ChatsTableCreateCompanionBuilder = ChatsCompanion Function({
  Value<int> id,
  required int orgId,
  required String uuid,
  Value<String?> wamId,
  required int contactId,
  required int userId,
  required String type,
  Value<String?> metadata,
  Value<int?> mediaId,
  Value<String> status,
  Value<bool> isRead,
  Value<DateTime> createdAt,
  Value<DateTime?> updatedAt,
});
typedef $$ChatsTableUpdateCompanionBuilder = ChatsCompanion Function({
  Value<int> id,
  Value<int> orgId,
  Value<String> uuid,
  Value<String?> wamId,
  Value<int> contactId,
  Value<int> userId,
  Value<String> type,
  Value<String?> metadata,
  Value<int?> mediaId,
  Value<String> status,
  Value<bool> isRead,
  Value<DateTime> createdAt,
  Value<DateTime?> updatedAt,
});

class $$ChatsTableFilterComposer extends Composer<_$AppDatabase, $ChatsTable> {
  $$ChatsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get orgId => $composableBuilder(
      column: $table.orgId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get uuid => $composableBuilder(
      column: $table.uuid, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get wamId => $composableBuilder(
      column: $table.wamId, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get contactId => $composableBuilder(
      column: $table.contactId, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get userId => $composableBuilder(
      column: $table.userId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get type => $composableBuilder(
      column: $table.type, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get metadata => $composableBuilder(
      column: $table.metadata, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get mediaId => $composableBuilder(
      column: $table.mediaId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get status => $composableBuilder(
      column: $table.status, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get isRead => $composableBuilder(
      column: $table.isRead, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnFilters(column));
}

class $$ChatsTableOrderingComposer
    extends Composer<_$AppDatabase, $ChatsTable> {
  $$ChatsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get orgId => $composableBuilder(
      column: $table.orgId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get uuid => $composableBuilder(
      column: $table.uuid, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get wamId => $composableBuilder(
      column: $table.wamId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get contactId => $composableBuilder(
      column: $table.contactId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get userId => $composableBuilder(
      column: $table.userId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get type => $composableBuilder(
      column: $table.type, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get metadata => $composableBuilder(
      column: $table.metadata, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get mediaId => $composableBuilder(
      column: $table.mediaId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get status => $composableBuilder(
      column: $table.status, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get isRead => $composableBuilder(
      column: $table.isRead, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnOrderings(column));
}

class $$ChatsTableAnnotationComposer
    extends Composer<_$AppDatabase, $ChatsTable> {
  $$ChatsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get orgId =>
      $composableBuilder(column: $table.orgId, builder: (column) => column);

  GeneratedColumn<String> get uuid =>
      $composableBuilder(column: $table.uuid, builder: (column) => column);

  GeneratedColumn<String> get wamId =>
      $composableBuilder(column: $table.wamId, builder: (column) => column);

  GeneratedColumn<int> get contactId =>
      $composableBuilder(column: $table.contactId, builder: (column) => column);

  GeneratedColumn<int> get userId =>
      $composableBuilder(column: $table.userId, builder: (column) => column);

  GeneratedColumn<String> get type =>
      $composableBuilder(column: $table.type, builder: (column) => column);

  GeneratedColumn<String> get metadata =>
      $composableBuilder(column: $table.metadata, builder: (column) => column);

  GeneratedColumn<int> get mediaId =>
      $composableBuilder(column: $table.mediaId, builder: (column) => column);

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<bool> get isRead =>
      $composableBuilder(column: $table.isRead, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$ChatsTableTableManager extends RootTableManager<
    _$AppDatabase,
    $ChatsTable,
    ChatData,
    $$ChatsTableFilterComposer,
    $$ChatsTableOrderingComposer,
    $$ChatsTableAnnotationComposer,
    $$ChatsTableCreateCompanionBuilder,
    $$ChatsTableUpdateCompanionBuilder,
    (ChatData, BaseReferences<_$AppDatabase, $ChatsTable, ChatData>),
    ChatData,
    PrefetchHooks Function()> {
  $$ChatsTableTableManager(_$AppDatabase db, $ChatsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ChatsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ChatsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ChatsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<int> orgId = const Value.absent(),
            Value<String> uuid = const Value.absent(),
            Value<String?> wamId = const Value.absent(),
            Value<int> contactId = const Value.absent(),
            Value<int> userId = const Value.absent(),
            Value<String> type = const Value.absent(),
            Value<String?> metadata = const Value.absent(),
            Value<int?> mediaId = const Value.absent(),
            Value<String> status = const Value.absent(),
            Value<bool> isRead = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
            Value<DateTime?> updatedAt = const Value.absent(),
          }) =>
              ChatsCompanion(
            id: id,
            orgId: orgId,
            uuid: uuid,
            wamId: wamId,
            contactId: contactId,
            userId: userId,
            type: type,
            metadata: metadata,
            mediaId: mediaId,
            status: status,
            isRead: isRead,
            createdAt: createdAt,
            updatedAt: updatedAt,
          ),
          createCompanionCallback: ({
            Value<int> id = const Value.absent(),
            required int orgId,
            required String uuid,
            Value<String?> wamId = const Value.absent(),
            required int contactId,
            required int userId,
            required String type,
            Value<String?> metadata = const Value.absent(),
            Value<int?> mediaId = const Value.absent(),
            Value<String> status = const Value.absent(),
            Value<bool> isRead = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
            Value<DateTime?> updatedAt = const Value.absent(),
          }) =>
              ChatsCompanion.insert(
            id: id,
            orgId: orgId,
            uuid: uuid,
            wamId: wamId,
            contactId: contactId,
            userId: userId,
            type: type,
            metadata: metadata,
            mediaId: mediaId,
            status: status,
            isRead: isRead,
            createdAt: createdAt,
            updatedAt: updatedAt,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$ChatsTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $ChatsTable,
    ChatData,
    $$ChatsTableFilterComposer,
    $$ChatsTableOrderingComposer,
    $$ChatsTableAnnotationComposer,
    $$ChatsTableCreateCompanionBuilder,
    $$ChatsTableUpdateCompanionBuilder,
    (ChatData, BaseReferences<_$AppDatabase, $ChatsTable, ChatData>),
    ChatData,
    PrefetchHooks Function()>;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$UsersTableTableManager get users =>
      $$UsersTableTableManager(_db, _db.users);
  $$OrganizationsTableTableManager get organizations =>
      $$OrganizationsTableTableManager(_db, _db.organizations);
  $$UserOrganizationsTableTableManager get userOrganizations =>
      $$UserOrganizationsTableTableManager(_db, _db.userOrganizations);
  $$ChatsTableTableManager get chats =>
      $$ChatsTableTableManager(_db, _db.chats);
}
