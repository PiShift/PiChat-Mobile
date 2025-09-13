import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:pichat/data/db/app_database.dart';

class ChatLog {
  final int id;
  final int chatId;
  final Map<String, dynamic>? metadata;
  final DateTime? createdAt;

  ChatLog({
    required this.id,
    required this.chatId,
    this.metadata,
    this.createdAt,
  });

  // ✅ From API JSON
  factory ChatLog.fromJson(Map<String, dynamic> json) => ChatLog(
    id: json['id'],
    chatId: json['chat_id'],
    metadata: json['metadata'] != null ? Map<String, dynamic>.from(jsonDecode(json['metadata'])) : null,
    createdAt: DateTime.parse(json['created_at']),
  );

  // ✅ To API JSON
  Map<String, dynamic> toJson() => {
    'id': id,
    'chat_id': chatId,
    'metadata': metadata,
    'created_at': createdAt?.toIso8601String(),
  };

  // ✅ From DB row (Drift-generated data class)
  factory ChatLog.fromDb(ChatLogsData row) {
    return ChatLog(
      id: row.id,
      chatId: row.chatId,
      metadata: row.metadata != null ? Map<String, dynamic>.from(jsonDecode(row.metadata as String)) : null,
      createdAt: row.createdAt,
    );
  }

  // ✅ To DB insert/update
  ChatLogsCompanion toCompanion() => ChatLogsCompanion.insert(
    id: Value(id),
    chatId: chatId,
    metadata: metadata != null ? Value(metadata.toString()) : const Value.absent(),
    createdAt: Value(createdAt),
  );
}
