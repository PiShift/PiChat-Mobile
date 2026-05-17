class WhatsappGroupParticipant {
  final int id;
  final String waId;
  final String? name;
  final String status; // 'active', 'pending', 'removed'
  final DateTime? joinedAt;

  const WhatsappGroupParticipant({
    required this.id,
    required this.waId,
    this.name,
    required this.status,
    this.joinedAt,
  });

  factory WhatsappGroupParticipant.fromJson(Map<String, dynamic> json) {
    return WhatsappGroupParticipant(
      id: json['id'] as int,
      waId: json['wa_id'] as String,
      name: json['name'] as String?,
      status: json['status'] as String? ?? 'active',
      joinedAt: json['joined_at'] != null ? DateTime.tryParse(json['joined_at'] as String) : null,
    );
  }
}

class WhatsappGroup {
  final String uuid;
  final String groupId;
  final String subject;
  final String? description;
  final String? inviteLink;
  final String joinApprovalMode; // 'auto_approve' | 'approval_required'
  final String status; // 'active' | 'suspended' | 'deleted'
  final int participantCount;
  final List<WhatsappGroupParticipant> participants;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const WhatsappGroup({
    required this.uuid,
    required this.groupId,
    required this.subject,
    this.description,
    this.inviteLink,
    required this.joinApprovalMode,
    required this.status,
    required this.participantCount,
    required this.participants,
    this.createdAt,
    this.updatedAt,
  });

  factory WhatsappGroup.fromJson(Map<String, dynamic> json) {
    final rawParticipants = json['participants'] as List<dynamic>? ?? [];
    return WhatsappGroup(
      uuid: json['uuid'] as String,
      groupId: json['group_id'] as String,
      subject: json['subject'] as String,
      description: json['description'] as String?,
      inviteLink: json['invite_link'] as String?,
      joinApprovalMode: json['join_approval_mode'] as String? ?? 'auto_approve',
      status: json['status'] as String? ?? 'active',
      participantCount: json['participant_count'] as int? ?? 0,
      participants: rawParticipants
          .map((p) => WhatsappGroupParticipant.fromJson(p as Map<String, dynamic>))
          .toList(),
      createdAt: json['created_at'] != null ? DateTime.tryParse(json['created_at'] as String) : null,
      updatedAt: json['updated_at'] != null ? DateTime.tryParse(json['updated_at'] as String) : null,
    );
  }

  bool get isActive => status == 'active';
  bool get isSuspended => status == 'suspended';
  bool get needsApproval => joinApprovalMode == 'approval_required';

  WhatsappGroup copyWith({String? inviteLink, String? status, int? participantCount, List<WhatsappGroupParticipant>? participants}) {
    return WhatsappGroup(
      uuid: uuid,
      groupId: groupId,
      subject: subject,
      description: description,
      inviteLink: inviteLink ?? this.inviteLink,
      joinApprovalMode: joinApprovalMode,
      status: status ?? this.status,
      participantCount: participantCount ?? this.participantCount,
      participants: participants ?? this.participants,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }
}
