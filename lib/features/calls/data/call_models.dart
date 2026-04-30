// lib/features/calls/data/call_models.dart
//
// Domain models for the WhatsApp Calling feature.
// Mirror the backend `CallResource` and `CallPermissionResource` shapes.

class CallModel {
  final int id;
  final String uuid;
  final String? waCallId;
  final String direction; // inbound | outbound
  final String status;
  final String? fromPhone;
  final String? toPhone;
  final int? assignedAgentId;
  final int? contactId;
  final String? contactUuid;
  final String? contactName;
  final int? durationSeconds;
  final String? endReason;
  final DateTime? createdAt;
  final DateTime? acceptedAt;
  final DateTime? endedAt;
  final Map<String, dynamic>? metadata;

  CallModel({
    required this.id,
    required this.uuid,
    required this.direction,
    required this.status,
    this.waCallId,
    this.fromPhone,
    this.toPhone,
    this.assignedAgentId,
    this.contactId,
    this.contactUuid,
    this.contactName,
    this.durationSeconds,
    this.endReason,
    this.createdAt,
    this.acceptedAt,
    this.endedAt,
    this.metadata,
  });

  factory CallModel.fromJson(Map<String, dynamic> json) {
    final contact = json['contact'] is Map ? json['contact'] as Map : null;
    return CallModel(
      // Backend's CallResource doesn't expose the integer id (only uuid),
      // so fall back to 0 — Flutter only ever needs the uuid.
      id: (json['id'] as num?)?.toInt() ?? 0,
      uuid: json['uuid'] as String,
      waCallId: json['wa_call_id'] as String?,
      direction: json['direction'] as String? ?? 'inbound',
      status: json['status'] as String? ?? 'queued',
      fromPhone: json['from_phone'] as String?,
      toPhone: json['to_phone'] as String?,
      assignedAgentId: (json['assigned_user_id'] as num?)?.toInt()
          ?? (json['assigned_agent_id'] as num?)?.toInt(),
      contactId: (json['contact_id'] as num?)?.toInt(),
      contactUuid: contact?['uuid'] as String?,
      contactName: contact == null
          ? null
          : ('${contact['first_name'] ?? ''} ${contact['last_name'] ?? ''}').trim(),
      durationSeconds: (json['duration_seconds'] as num?)?.toInt(),
      endReason: json['end_reason'] as String?,
      createdAt: _parseDate(json['created_at']),
      acceptedAt: _parseDate(json['accepted_at']),
      endedAt: _parseDate(json['ended_at']),
      metadata: json['metadata'] is Map ? Map<String, dynamic>.from(json['metadata'] as Map) : null,
    );
  }

  CallModel copyWith({
    String? status,
    int? assignedAgentId,
    int? durationSeconds,
    String? endReason,
    DateTime? acceptedAt,
    DateTime? endedAt,
    Map<String, dynamic>? metadata,
  }) =>
      CallModel(
        id: id,
        uuid: uuid,
        waCallId: waCallId,
        direction: direction,
        status: status ?? this.status,
        fromPhone: fromPhone,
        toPhone: toPhone,
        assignedAgentId: assignedAgentId ?? this.assignedAgentId,
        contactId: contactId,
        contactUuid: contactUuid,
        contactName: contactName,
        durationSeconds: durationSeconds ?? this.durationSeconds,
        endReason: endReason ?? this.endReason,
        createdAt: createdAt,
        acceptedAt: acceptedAt ?? this.acceptedAt,
        endedAt: endedAt ?? this.endedAt,
        metadata: metadata ?? this.metadata,
      );
}

class CallPermissionModel {
  final int id;
  final int contactId;
  final String? contactUuid;
  final String status; // pending | approved | denied | revoked | expired
  final DateTime? grantedAt;
  final DateTime? expiresAt;

  CallPermissionModel({
    required this.id,
    required this.contactId,
    required this.status,
    this.contactUuid,
    this.grantedAt,
    this.expiresAt,
  });

  factory CallPermissionModel.fromJson(Map<String, dynamic> json) {
    final contact = json['contact'] is Map ? json['contact'] as Map : null;
    return CallPermissionModel(
      // Backend resource exposes uuid only, no integer id.
      id: (json['id'] as num?)?.toInt() ?? 0,
      contactId: (json['contact_id'] as num?)?.toInt() ?? 0,
      contactUuid: contact?['uuid'] as String?,
      status: json['status'] as String? ?? 'pending',
      grantedAt: _parseDate(json['granted_at']),
      expiresAt: _parseDate(json['expires_at']),
    );
  }

  bool get isApproved => status == 'approved';
}

DateTime? _parseDate(dynamic value) {
  if (value == null) return null;
  try {
    return DateTime.parse(value.toString()).toLocal();
  } catch (_) {
    return null;
  }
}
