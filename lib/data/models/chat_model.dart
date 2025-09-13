import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:pichat/data/db/app_database.dart';
import 'package:pichat/data/models/chat_log_model.dart';
import 'package:pichat/data/models/chat_media_model.dart';

class Chat {
  final int id;
  final int orgId;
  final String uuid;
  final String? wamId;
  final int contactId;
  final int? userId;
  final String type;
  final Map<String, dynamic>? metadata;
  final int? mediaId;
  final String status;
  final bool isRead;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final DateTime? deletedAt;
  final int? deletedBy;
  final ChatMedia? media;
  final List<ChatLog> logs;

  Chat({
    required this.id,
    required this.orgId,
    required this.uuid,
    this.wamId,
    required this.contactId,
    this.userId,
    required this.type,
    required this.metadata,
    this.mediaId,
    required this.status,
    required this.isRead,
    required this.createdAt,
    this.updatedAt,
    this.deletedAt,
    this.deletedBy,
    this.media,
    this.logs = const [],
  });

  // ✅ From API JSON
  factory Chat.fromJson(Map<String, dynamic> json) => Chat(
    id: json['id'],
    orgId: json['organization_id'],
    uuid: json['uuid'],
    wamId: json['wam_id'],
    contactId: json['contact_id'],
    userId: json['user_id'],
    type: json['type'],
    metadata: json['metadata'] != null ? Map<String, dynamic>.from(jsonDecode(json['metadata'])) : null,
    mediaId: json['media_id'],
    status: json['status'] ?? 'pending',
    isRead: json['is_read'] == 1 ? true : false,
    createdAt: DateTime.parse(json['created_at']),
    updatedAt: json['updated_at'] != null ? DateTime.parse(json['updated_at']) : null,
    deletedAt: json['deleted_at'] != null ? DateTime.parse(json['deleted_at']) : null,
    deletedBy: json['deleted_by']
  );

  // ✅ To API JSON
  Map<String, dynamic> toJson() => {
    'id': id,
    'organization_id': orgId,
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
    'deleted_at': deletedAt?.toIso8601String(),
    'deleted_by': deletedBy
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
      deletedAt: row.deletedAt,
      deletedBy: row.deletedBy
    );
  }

  // ✅ To DB insert/update
  ChatsCompanion toCompanion() => ChatsCompanion.insert(
    id: Value(id),
    orgId: orgId,
    uuid: uuid,
    wamId: Value(wamId),
    contactId: contactId,
    userId: Value(userId),
    type: type,
    metadata: Value(jsonEncode(metadata)),
    mediaId: Value(mediaId),
    status: Value(status),
    isRead: Value(isRead),
    createdAt: Value(createdAt),
    updatedAt: Value(updatedAt),
    deletedAt: Value(deletedAt),
    deletedBy: Value(deletedBy)
  );

  Chat copyWith({
    int? id,
    String? uuid,
    int? orgId,
    String? wamId,
    int? contactId,
    int? userId,
    String? type,
    Map<String, dynamic>? metadata,
    int? mediaId,
    String? status,
    bool? isRead,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? deletedAt,
    int? deletedBy,
    ChatMedia? media,
    List<ChatLog>? logs,
  }) {
    return Chat(
      id: id ?? this.id,
      uuid: uuid ?? this.uuid,
      orgId: orgId ?? this.orgId,
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
      deletedAt: deletedAt ?? this.deletedAt,
      deletedBy: deletedBy ?? this.deletedBy,
      media: media ?? this.media,
      logs: logs ?? this.logs,
    );
  }

}
