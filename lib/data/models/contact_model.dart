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
    );
  }

}
