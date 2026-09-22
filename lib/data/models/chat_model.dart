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
  /// True when the AI assistant sent this rather than an agent.
  final bool isPibot;
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
    this.isPibot = false,
    required this.createdAt,
    this.updatedAt,
    this.deletedAt,
    this.deletedBy,
    this.media,
    this.logs = const [],
  });

  // ✅ From API JSON (full chat object)
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
    media: json['media'] != null ? ChatMedia.fromJson(json['media']) : null,
    status: json['status'] ?? 'pending',
    isRead: json['is_read'] == 1 ? true : false,
    isPibot: json['is_pibot'] == true || json['is_pibot'] == 1,
    createdAt: DateTime.parse(json['created_at']),
    updatedAt: json['updated_at'] != null ? DateTime.parse(json['updated_at']) : null,
    deletedAt: json['deleted_at'] != null ? DateTime.parse(json['deleted_at']) : null,
    deletedBy: json['deleted_by'],
    // Both server relations land in one list, told apart by ChatLog.isAgentRead:
    // `logs` are WhatsApp delivery receipts, `readers` are agents on this
    // organization who opened the message. This was never parsed before, which
    // is why the ChatLogs table and its insert path sat unused.
    logs: [
      ..._parseLogs(json['logs']),
      ..._parseLogs(json['readers']),
    ],
  );

  /// Tolerates a missing or malformed relation — a bad log should cost the
  /// message info sheet, not the message.
  static List<ChatLog> _parseLogs(dynamic raw) {
    if (raw is! List) return const [];

    return raw
        .whereType<Map>()
        .map((e) {
          try {
            return ChatLog.fromJson(Map<String, dynamic>.from(e));
          } catch (_) {
            return null;
          }
        })
        .whereType<ChatLog>()
        .toList();
  }

  // ✅ From simplified preview (used in contact list last_message)
  factory Chat.fromPreview(Map<String, dynamic> json, int contactId) {
    // Build metadata based on content_type
    final contentType = json['content_type'] ?? 'text';
    final messageText = json['message'];
    
    Map<String, dynamic>? metadata;
    if (messageText != null || contentType != null) {
      metadata = {'type': contentType};
      
      switch (contentType) {
        case 'text':
          metadata['text'] = {'body': messageText ?? ''};
          break;
        case 'image':
          metadata['image'] = messageText != null ? {'caption': messageText} : {};
          break;
        case 'video':
          metadata['video'] = messageText != null ? {'caption': messageText} : {};
          break;
        case 'audio':
          metadata['audio'] = {};
          break;
        case 'document':
          metadata['document'] = messageText != null ? {'caption': messageText} : {};
          break;
        default:
          metadata['text'] = {'body': messageText ?? ''};
      }
    }
    
    return Chat(
      id: json['id'],
      orgId: 0, // Not provided in preview
      uuid: '', // Not provided in preview
      contactId: contactId,
      type: json['direction'] ?? json['type'] ?? 'inbound', // direction = inbound/outbound
      metadata: metadata,
      status: 'delivered',
      isRead: json['is_read'] == true || json['is_read'] == 1,
      isPibot: json['is_pibot'] == true || json['is_pibot'] == 1,
      createdAt: json['sent_at'] != null 
          ? DateTime.parse(json['sent_at']) 
          : (json['created_at'] != null ? DateTime.parse(json['created_at']) : DateTime.now()),
    );
  }

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
    'is_pibot': isPibot,
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
      isPibot: row.isPibot,
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
    isPibot: Value(isPibot),
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
    bool? isPibot,
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
      isPibot: isPibot ?? this.isPibot,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt ?? this.deletedAt,
      deletedBy: deletedBy ?? this.deletedBy,
      media: media ?? this.media,
      logs: logs ?? this.logs,
    );
  }

}
