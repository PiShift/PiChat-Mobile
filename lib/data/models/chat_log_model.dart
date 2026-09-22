import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:pichat/data/db/app_database.dart';

/// One event on a message: either a Meta delivery receipt, or an agent on this
/// organization opening it.
///
/// [userId] tells the two apart, matching `chat_status_logs` on the server.
class ChatLog {
  final int id;
  final int chatId;
  final Map<String, dynamic>? metadata;

  /// The agent who opened the message; null on delivery receipts.
  final int? userId;
  final String? userName;

  final DateTime? createdAt;

  ChatLog({
    required this.id,
    required this.chatId,
    this.metadata,
    this.userId,
    this.userName,
    this.createdAt,
  });

  /// True when this row is an agent opening the message rather than a
  /// delivery receipt from WhatsApp.
  bool get isAgentRead => userId != null;

  /// The delivery stage this row reports: 'sent', 'delivered', 'read', …
  String? get deliveryStatus => metadata?['status'] as String?;

  // ✅ From API JSON
  factory ChatLog.fromJson(Map<String, dynamic> json) => ChatLog(
    id: json['id'],
    chatId: json['chat_id'],
    // The server sends metadata as a JSON *string*, but a row we wrote
    // ourselves may already be decoded.
    metadata: _decodeMetadata(json['metadata']),
    userId: json['user_id'] as int?,
    userName: _readerName(json),
    createdAt: json['created_at'] != null
        ? DateTime.parse(json['created_at'])
        : null,
  );

  /// The reader's display name, from the nested user relation.
  static String? _readerName(Map<String, dynamic> json) {
    final user = json['user'];
    if (user is! Map) return null;

    final full = user['full_name'] as String?;
    if (full != null && full.trim().isNotEmpty) return full.trim();

    final parts = [user['first_name'], user['last_name']]
        .whereType<String>()
        .where((p) => p.trim().isNotEmpty);

    return parts.isEmpty ? null : parts.join(' ');
  }

  /// Tolerates a malformed payload: a bad row should cost one log line, not
  /// the whole conversation.
  static Map<String, dynamic>? _decodeMetadata(dynamic raw) {
    if (raw == null) return null;
    if (raw is Map) return Map<String, dynamic>.from(raw);

    if (raw is String) {
      try {
        final decoded = jsonDecode(raw);
        return decoded is Map ? Map<String, dynamic>.from(decoded) : null;
      } catch (_) {
        return null;
      }
    }

    return null;
  }

  // ✅ To API JSON
  Map<String, dynamic> toJson() => {
    'id': id,
    'chat_id': chatId,
    'metadata': metadata,
    'user_id': userId,
    'created_at': createdAt?.toIso8601String(),
  };

  // ✅ From DB row (Drift-generated data class)
  factory ChatLog.fromDb(ChatLogsData row) {
    return ChatLog(
      id: row.id,
      chatId: row.chatId,
      metadata: _decodeMetadata(row.metadata),
      userId: row.userId,
      userName: row.userName,
      createdAt: row.createdAt,
    );
  }

  // ✅ To DB insert/update
  ChatLogsCompanion toCompanion() => ChatLogsCompanion.insert(
    id: Value(id),
    chatId: chatId,
    // jsonEncode, not toString: `toString` on a Map produces Dart's own
    // notation, which does not read back as JSON.
    metadata: metadata != null ? Value(jsonEncode(metadata)) : const Value.absent(),
    userId: Value(userId),
    userName: Value(userName),
    createdAt: Value(createdAt),
  );
}
