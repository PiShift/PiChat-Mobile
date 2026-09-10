import 'dart:convert';

import 'package:drift/drift.dart' show Value;
import 'package:pichat/data/db/app_database.dart';

/// A non-message entry in a conversation.
///
/// The server's thread is assembled from `chat_logs`, where each row is an
/// (entity_type, entity_id) pair. Messages are one type; tickets, notes and
/// calls are the others, and the app previously discarded them — so a
/// conversation carried no record of a call, of who it was assigned to, or of
/// when it was closed.
///
/// The raw `value` object is kept as JSON and read through the accessors below
/// rather than being flattened into fields. The three kinds share almost
/// nothing, and the shapes still change on the server side.
enum TimelineEventKind { ticket, note, call, unknown }

class TimelineEvent {
  const TimelineEvent({
    required this.id,
    required this.contactId,
    required this.kind,
    required this.payload,
    required this.createdAt,
  });

  /// `chat_logs.id`. Unique across every entity type, unlike `entity_id`.
  final int id;
  final int contactId;
  final TimelineEventKind kind;
  final Map<String, dynamic> payload;
  final DateTime createdAt;

  static TimelineEventKind kindFrom(String? raw) => switch (raw) {
        'ticket' => TimelineEventKind.ticket,
        'notes' => TimelineEventKind.note,
        'call' => TimelineEventKind.call,
        _ => TimelineEventKind.unknown,
      };

  static String kindToString(TimelineEventKind kind) => switch (kind) {
        TimelineEventKind.ticket => 'ticket',
        TimelineEventKind.note => 'notes',
        TimelineEventKind.call => 'call',
        TimelineEventKind.unknown => 'unknown',
      };

  /// Builds an event from one `{type, log_id, logged_at, value}` entry.
  ///
  /// Returns null for anything unusable so an unrecognised entry is skipped
  /// rather than rendered as an empty row.
  static TimelineEvent? fromApi(Map<String, dynamic> entry, int contactId) {
    final kind = kindFrom(entry['type'] as String?);
    if (kind == TimelineEventKind.unknown) return null;

    final value = entry['value'];
    if (value is! Map) return null;

    final payload = Map<String, dynamic>.from(value);

    final logId = entry['log_id'];
    // Older servers do not send log_id; fall back to the entity's own id, which
    // is at least stable within a kind.
    final id = logId is int ? logId : (payload['id'] as int?);
    if (id == null) return null;

    return TimelineEvent(
      id: id,
      contactId: contactId,
      kind: kind,
      payload: payload,
      createdAt: _parseDate(entry['logged_at']) ??
          _parseDate(payload['created_at']) ??
          DateTime.now(),
    );
  }

  factory TimelineEvent.fromDb(TimelineEventRow row) => TimelineEvent(
        id: row.id,
        contactId: row.contactId,
        kind: kindFrom(row.kind),
        payload: _decode(row.payload),
        createdAt: row.createdAt,
      );

  TimelineEventsCompanion toCompanion() => TimelineEventsCompanion(
        id: Value(id),
        contactId: Value(contactId),
        kind: Value(kindToString(kind)),
        payload: Value(jsonEncode(payload)),
        createdAt: Value(createdAt),
      );

  // ---------------------------------------------------------------------------
  // Ticket / note
  // ---------------------------------------------------------------------------

  /// Prose written by the server, e.g. "Conversation was assigned to Bechir".
  String? get description => payload['description'] as String?;

  String? get noteContent => payload['content'] as String?;

  // ---------------------------------------------------------------------------
  // Call
  // ---------------------------------------------------------------------------

  bool get isInbound => payload['direction'] == 'inbound';

  String? get callStatus => payload['status'] as String?;

  /// True when nobody answered — the distinction an agent scanning the thread
  /// cares about most.
  bool get callMissed =>
      const {'missed', 'rejected', 'failed', 'expired'}.contains(callStatus);

  int? get durationSeconds {
    final raw = payload['duration_seconds'];

    if (raw is int) return raw;
    if (raw is num) return raw.toInt();
    if (raw is String) return int.tryParse(raw);

    return null;
  }

  String? get endReason => payload['end_reason'] as String?;

  /// The agent who took the call, when the server eager-loaded them.
  String? get agentName {
    final agent = payload['assigned_agent'];
    if (agent is! Map) return null;

    final name =
        '${agent['first_name'] ?? ''} ${agent['last_name'] ?? ''}'.trim();

    return name.isEmpty ? null : name;
  }

  /// `3:07`, or `0:45`. Null when the call never connected.
  String? get formattedDuration {
    final seconds = durationSeconds;
    if (seconds == null || seconds <= 0) return null;

    final minutes = seconds ~/ 60;
    final remainder = (seconds % 60).toString().padLeft(2, '0');

    if (minutes >= 60) {
      final hours = minutes ~/ 60;
      final mins = (minutes % 60).toString().padLeft(2, '0');

      return '$hours:$mins:$remainder';
    }

    return '$minutes:$remainder';
  }

  static Map<String, dynamic> _decode(String raw) {
    try {
      final decoded = jsonDecode(raw);

      return decoded is Map ? Map<String, dynamic>.from(decoded) : {};
    } catch (_) {
      return {};
    }
  }

  static DateTime? _parseDate(dynamic raw) {
    if (raw is! String || raw.isEmpty) return null;

    return DateTime.tryParse(raw)?.toLocal();
  }
}
