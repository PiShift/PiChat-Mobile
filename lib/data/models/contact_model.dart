import 'package:pichat/data/repositories/label_repository.dart';
import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:pichat/data/db/app_database.dart';
import 'package:pichat/data/models/chat_model.dart';

class Contact {
  final int id;
  final String uuid;
  final int orgId;
  final String? firstName;
  final String? lastName;
  final String? fullName;
  final String phone;
  final String formattedPhone;
  late DateTime? latestChatCreatedAt;
  final DateTime? lastInboundChatAt;
  final String? avatar;
  final int unreadCount;
  final int unreadMessages;
  late int? lastChatId;

  /// Current ticket ownership, flattened from the server's `ticket` object so
  /// the chat list can label a row and the thread header can name the owner
  /// without a per-conversation lookup.
  final String? assignedAgentName;
  final int? assignedAgentId;
  final String? ticketStatus;

  /// Most recent call on this conversation. The chat list previews whichever
  /// of this and [lastChat] actually happened last.
  final DateTime? lastCallAt;
  final String? lastCallDirection;
  final String? lastCallStatus;

  /// Whether the payload this was built from actually carried ticket / call
  /// data.
  ///
  /// Only the contacts list eager-loads those relations; `contactById` and
  /// `newestChats` do not, and their payloads omit the keys entirely. Without
  /// this distinction the model cannot tell "no call" from "not asked about",
  /// and persisting the resulting null wiped the call preview off the chat list
  /// the moment a thread was opened.
  final bool hasTicketData;
  final bool hasCallData;
  final bool hasLabelData;

  /// Labels on this conversation, ready to paint.
  final List<Label> labels;
  final Chat? lastChat;
  final DateTime createdAt;
  final DateTime? updatedAt;

  Contact({
    required this.id,
    required this.uuid,
    required this.orgId,
    this.firstName,
    this.lastName,
    this.fullName,
    required this.phone,
    required this.formattedPhone,
    this.latestChatCreatedAt,
    this.lastInboundChatAt,
    this.avatar,
    required this.unreadCount,
    required this.unreadMessages,
    this.lastChatId,
    this.assignedAgentName,
    this.assignedAgentId,
    this.ticketStatus,
    this.lastCallAt,
    this.lastCallDirection,
    this.lastCallStatus,
    this.hasTicketData = false,
    this.hasCallData = false,
    this.hasLabelData = false,
    this.labels = const [],
    this.lastChat,
    required this.createdAt,
    this.updatedAt,
  });

  // ✅ From API JSON
  factory Contact.fromJson(Map<String, dynamic> json) {
    // Handle both old 'last_chat' and new 'last_message' formats
    Chat? lastChat;
    int? lastChatId;
    
    if (json['last_chat'] != null) {
      // Old format: full chat object
      lastChat = Chat.fromJson(json['last_chat']);
      lastChatId = json['last_chat']['id'];
    } else if (json['last_message'] != null) {
      // New format: simplified preview - create a minimal Chat object
      final lm = json['last_message'];
      lastChatId = lm['id'];
      lastChat = Chat.fromPreview(lm, json['id']);
    }
    
    // Parse last_message_at or latest_chat_created_at
    DateTime? latestChatCreatedAt;
    if (json['last_message_at'] != null) {
      latestChatCreatedAt = DateTime.parse(json['last_message_at']);
    } else if (json['latest_chat_created_at'] != null) {
      latestChatCreatedAt = DateTime.parse(json['latest_chat_created_at']);
    }
    
    DateTime? lastInboundChatAt;
    if (json['last_inbound_chat_at'] != null) {
      lastInboundChatAt = DateTime.parse(json['last_inbound_chat_at']);
    }

    // Only present when the server eager-loaded the relation; absent on
    // endpoints that do not need ticket state.
    final rawTicket = json['ticket'];
    final ticket = rawTicket is Map ? Map<String, dynamic>.from(rawTicket) : null;

    final rawCall = json['last_call'];
    final lastCall =
        rawCall is Map ? Map<String, dynamic>.from(rawCall) : null;

    return Contact(
      id: json['id'],
      uuid: json['uuid'],
      orgId: json['organization_id'] ?? 0,
      firstName: json['first_name'],
      lastName: json['last_name'],
      fullName: json['full_name'],
      phone: json['phone'] ?? '',
      formattedPhone: json['formatted_phone_number'] ?? json['phone'] ?? '',
      latestChatCreatedAt: latestChatCreatedAt,
      lastInboundChatAt: lastInboundChatAt,
      avatar: json['avatar'],
      unreadCount: json['unread_count'] ?? 0,
      unreadMessages: json['unread_messages'] ?? json['unread_count'] ?? 0,
      lastChatId: lastChatId,
      assignedAgentName: ticket?['agent_name'] as String?,
      assignedAgentId: ticket?['assigned_to'] as int?,
      ticketStatus: ticket?['status'] as String?,
      lastCallAt: lastCall?['created_at'] != null
          ? DateTime.tryParse(lastCall!['created_at'] as String)?.toLocal()
          : null,
      lastCallDirection: lastCall?['direction'] as String?,
      lastCallStatus: lastCall?['status'] as String?,
      hasTicketData: json.containsKey('ticket'),
      hasCallData: json.containsKey('last_call'),
      hasLabelData: json.containsKey('labels'),
      labels: (json['labels'] as List<dynamic>? ?? const [])
          .map((e) => Label.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList(),
      lastChat: lastChat,
      createdAt: json['created_at'] != null ? DateTime.parse(json['created_at']) : DateTime.now(),
      updatedAt: json['updated_at'] != null ? DateTime.parse(json['updated_at']) : null,
    );
  }

  // ✅ To API JSON
  Map<String, dynamic> toJson() => {
    'id': id,
    'uuid': uuid,
    'organization_id': orgId,
    'first_name': firstName,
    'last_name': lastChatId,
    'full_name': fullName,
    'phone': phone,
    'formatted_phone_number': formattedPhone,
    'latest_chat_created_at': latestChatCreatedAt,
    'avatar': avatar,
    'unread_count': unreadCount,
    'unread_messages': unreadMessages,
    'last_chat_id': lastChatId,
    'assigned_agent_name': assignedAgentName,
    'assigned_agent_id': assignedAgentId,
    'ticket_status': ticketStatus,
    'last_call_at': lastCallAt?.toIso8601String(),
    'last_chat': lastChat,
    'created_at': createdAt.toIso8601String(),
    'updated_at': updatedAt?.toIso8601String(),
  };

  // ✅ From DB row (Drift-generated data class)
  factory Contact.fromDb(ContactData row) {
    return Contact(
      id: row.id,
      uuid: row.uuid,
      orgId: row.orgId,
      firstName: row.firstName,
      lastName: row.lastName,
      fullName: row.fullName,
      phone: row.phone,
      formattedPhone: row.formattedPhone,
      latestChatCreatedAt: row.latestChatCreatedAt,
      lastInboundChatAt: null,
      avatar: row.avatar,
      unreadCount: row.unreadCount,
      unreadMessages: row.unreadMessages,
      lastChatId: row.lastChatId,
      assignedAgentName: row.assignedAgentName,
      assignedAgentId: row.assignedAgentId,
      ticketStatus: row.ticketStatus,
      lastCallAt: row.lastCallAt,
      lastCallDirection: row.lastCallDirection,
      lastCallStatus: row.lastCallStatus,
      hasTicketData: true,
      hasCallData: true,
      hasLabelData: true,
      labels: _decodeLabels(row.labels),
      createdAt: row.createdAt,
      updatedAt: row.updatedAt,
    );
  }

  // ✅ To DB insert/update
  ContactsCompanion toCompanion() => ContactsCompanion.insert(
    id: Value(id),
    orgId: orgId,
    uuid: uuid,
    firstName: Value(firstName),
    lastName: Value(lastName),
    fullName: Value(fullName),
    phone: phone,
    formattedPhone: formattedPhone,
    latestChatCreatedAt: Value(latestChatCreatedAt),
    // Absent, not null, when the payload did not carry the relation — an
    // omitted field must never overwrite a stored one.
    assignedAgentName:
        hasTicketData ? Value(assignedAgentName) : const Value.absent(),
    assignedAgentId:
        hasTicketData ? Value(assignedAgentId) : const Value.absent(),
    ticketStatus: hasTicketData ? Value(ticketStatus) : const Value.absent(),
    lastCallAt: hasCallData ? Value(lastCallAt) : const Value.absent(),
    lastCallDirection:
        hasCallData ? Value(lastCallDirection) : const Value.absent(),
    lastCallStatus:
        hasCallData ? Value(lastCallStatus) : const Value.absent(),
    labels: hasLabelData
        ? Value(jsonEncode(labels.map((l) => l.toJson()).toList()))
        : const Value.absent(),
    avatar: Value(avatar),
    unreadCount: Value(unreadCount),
    unreadMessages: Value(unreadMessages),
    lastChatId: Value(lastChatId),
    createdAt: Value(createdAt),
    updatedAt: Value(updatedAt),
  );

  Contact copyWith({
    int? id,
    String? uuid,
    int? orgId,
    String? firstName,
    String? lastName,
    String? fullName,
    String? phone,
    String? formattedPhone,
    DateTime? latestChatCreatedAt,
    DateTime? lastInboundChatAt,
    String? avatar,
    int? unreadCount,
    int? unreadMessages,
    int? lastChatId,
    DateTime? createdAt,
    DateTime? updatedAt,
    Chat? lastChat,
    String? assignedAgentName,
    int? assignedAgentId,
    String? ticketStatus,
    DateTime? lastCallAt,
    String? lastCallDirection,
    String? lastCallStatus,
    List<Label>? labels,
  }) {
    return Contact(
      id: id ?? this.id,
      uuid: uuid ?? this.uuid,
      orgId: orgId ?? this.orgId,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      fullName: fullName ?? this.fullName,
      phone: phone ?? this.phone,
      formattedPhone: formattedPhone ?? this.formattedPhone,
      latestChatCreatedAt: latestChatCreatedAt ?? this.latestChatCreatedAt,
      lastInboundChatAt: lastInboundChatAt ?? this.lastInboundChatAt,
      avatar: avatar ?? this.avatar,
      unreadCount: unreadCount ?? this.unreadCount,
      unreadMessages: unreadMessages ?? this.unreadMessages,
      lastChatId: lastChatId ?? this.lastChatId,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      lastChat: lastChat ?? this.lastChat,
      assignedAgentName: assignedAgentName ?? this.assignedAgentName,
      assignedAgentId: assignedAgentId ?? this.assignedAgentId,
      ticketStatus: ticketStatus ?? this.ticketStatus,
      lastCallAt: lastCallAt ?? this.lastCallAt,
      lastCallDirection: lastCallDirection ?? this.lastCallDirection,
      lastCallStatus: lastCallStatus ?? this.lastCallStatus,
      labels: labels ?? this.labels,
      // Carried through too: a copy must not look like a payload that never
      // mentioned tickets or calls, or persisting it would blank the columns.
      hasTicketData: hasTicketData,
      hasCallData: hasCallData,
      hasLabelData: hasLabelData,
    );
  }

}

/// Reads the labels column, tolerating anything unexpected — a malformed row
/// should cost the chips, not the whole conversation list.
List<Label> _decodeLabels(String? raw) {
  if (raw == null || raw.isEmpty) return const [];

  try {
    final decoded = jsonDecode(raw);

    if (decoded is! List) return const [];

    return decoded
        .whereType<Map>()
        .map((e) => Label.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  } catch (_) {
    return const [];
  }
}
