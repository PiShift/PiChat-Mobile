import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:pichat/data/db/app_database.dart';

class Organization {
  final int id;
  final int? userId;
  final String identifier;
  final String name;
  final Map<String, dynamic>? metadata;
  final DateTime createdAt;

  Organization({
    required this.id,
    this.userId,
    required this.identifier,
    required this.name,
    this.metadata,
    required this.createdAt,
  });

  /// From API JSON
  factory Organization.fromJson(Map<String, dynamic> json) {
    return Organization(
      id: json['id'] as int,
      userId: json['user_id'] as int?,
      identifier: json['identifier'] as String,
      name: json['name'] as String,
      metadata: json['metadata'] != null ? Map<String, dynamic>.from(jsonDecode(json['metadata'])) : null,
      createdAt: DateTime.parse(json['created_at']),
    );
  }

  /// To API JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'identifier': identifier,
      'name': name,
      'metadata': metadata,
      'created_at': createdAt.toIso8601String(),
    };
  }

  /// From Drift database row
  factory Organization.fromDb(OrganizationData row) {
    return Organization(
      id: row.id,
      userId: null, // userId is not stored in Organizations table
      identifier: row.identifier,
      name: row.name,
      metadata: row.metadata != null ? Map<String, dynamic>.from(jsonDecode(row.metadata as String)) : null,
      createdAt: row.createdAt,
    );
  }

  /// To Drift insertable
  OrganizationsCompanion toCompanion() {
    return OrganizationsCompanion.insert(
      id: Value(id),
      identifier: identifier,
      name: name,
      metadata: metadata != null ? Value(metadata.toString()) : const Value.absent(),
      createdAt: Value(createdAt),
    );
  }
}
