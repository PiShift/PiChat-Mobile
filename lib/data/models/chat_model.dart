import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:pichat/data/db/app_database.dart';

class Chat {
  final int? id;
  final int orgId;
  final String uuid;
  final String? wamId;
  final int contactId;
  final int userId;
  final String type;
  final Map<String, dynamic> metadata;
  final int? mediaId;
  final String status;
  final bool isRead;
  final DateTime createdAt;
  final DateTime? updatedAt;

  Chat({
    this.id,
    required this.orgId,
    required this.uuid,
    this.wamId,
    required this.contactId,
    required this.userId,
    required this.type,
    required this.metadata,
    this.mediaId,
    required this.status,
    required this.isRead,
    required this.createdAt,
    this.updatedAt,
  });

  // ✅ From API JSON
  factory Chat.fromJson(Map<String, dynamic> json) => Chat(
    id: json['id'],
    orgId: json['org_id'],
    uuid: json['uuid'],
    wamId: json['wam_id'],
    contactId: json['contact_id'],
    userId: json['user_id'],
    type: json['type'],
    metadata: json['metadata'] ?? '{}',
    mediaId: json['media_id'],
    status: json['status'] ?? 'pending',
    isRead: json['is_read'] ?? false,
    createdAt: DateTime.parse(json['created_at']),
    updatedAt:
    json['updated_at'] != null ? DateTime.parse(json['updated_at']) : null,
  );

  // ✅ To API JSON
  Map<String, dynamic> toJson() => {
    'id': id,
    'org_id': orgId,
    'uuid': uuid,
    'wam_id': wamId,
    'contact_id': contactId,
    'user_id': userId,
    'type': type,
    'metadata': metadata,
    'media_id': mediaId,
    'status': status,
    'is_read': isRead,
    'created_at': createdAt.toIso8601String(),
    'updated_at': updatedAt?.toIso8601String(),
  };

  // ✅ From DB row (Drift-generated data class)
  factory Chat.fromDb(ChatData row) {
    return Chat(
      id: row.id,
      orgId: row.orgId,
      uuid: row.uuid,
      wamId: row.wamId,
      contactId: row.contactId,
      userId: row.userId,
      type: row.type,
      metadata: row.metadata != null ? jsonDecode(row.metadata!) : {},
      mediaId: row.mediaId,
      status: row.status,
      isRead: row.isRead,
      createdAt: row.createdAt,
      updatedAt: row.updatedAt,
    );
  }

  // ✅ To DB insert/update
  ChatsCompanion toCompanion() => ChatsCompanion.insert(
    orgId: orgId,
    uuid: uuid,
    wamId: Value(wamId),
    contactId: contactId,
    userId: userId,
    type: type,
    metadata: Value(jsonEncode(metadata)),
    mediaId: Value(mediaId),
    status: Value(status),
    isRead: Value(isRead),
    createdAt: Value(createdAt),
    updatedAt: Value(updatedAt),
  );
}
