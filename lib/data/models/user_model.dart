import 'package:drift/drift.dart';
import 'package:pichat/data/db/app_database.dart';

class User {
  final int id;
  final String firstName;
  final String lastName;
  final String email;
  final String? phone;
  final String? avatar;
  final String role;
  final int status;
  final DateTime createdAt;

  User({
    required this.id,
    required this.firstName,
    required this.lastName,
    required this.email,
    this.phone,
    this.avatar,
    this.role = 'user',
    this.status = 0,
    required this.createdAt,
  });

  /// From API JSON
  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'] as int,
      firstName: json['first_name'] as String,
      lastName: json['last_name'] as String,
      email: json['email'] as String,
      phone: json['phone'] as String?,
      avatar: json['avatar'] as String?,
      role: json['role'] ?? 'user',
      status: json['status'] ?? 0,
      createdAt: DateTime.parse(json['created_at']),
    );
  }

  /// To API JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'first_name': firstName,
      'last_name': lastName,
      'email': email,
      'phone': phone,
      'avatar': avatar,
      'role': role,
      'status': status,
      'created_at': createdAt.toIso8601String(),
    };
  }

  /// From Drift database row
  factory User.fromDb(UserData row) {
    return User(
      id: row.id,
      firstName: row.firstName,
      lastName: row.lastName,
      email: row.email,
      phone: row.phone,
      avatar: row.avatar,
      role: row.role,
      status: row.status,
      createdAt: row.createdAt,
    );
  }

  /// To Drift insertable
  UsersCompanion toCompanion() {
    return UsersCompanion.insert(
      id: Value(id),
      firstName: firstName,
      lastName: lastName,
      email: email,
      phone: Value(phone),
      avatar: Value(avatar),
      role: Value(role),
      status: Value(status),
      createdAt: Value(createdAt),
    );
  }
}
