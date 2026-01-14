import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:pichat/data/db/app_database.dart';

class ChatMedia {
  final int id;
  final int? mediaId;
  final String? name;
  final String? path;
  final String? metaUrl;
  final String? location;
  final String? type;
  final String? size;
  final DateTime? createdAt;

  ChatMedia({
    required this.id,
    this.mediaId,
    this.name,
    this.path,
    this.metaUrl,
    this.location,
    this.type,
    this.size,
    this.createdAt,
  });

  // ✅ From API JSON
  factory ChatMedia.fromJson(Map<String, dynamic> json) => ChatMedia(
    id: json['id'],
    mediaId: json['media_id'],
    name: json['name'],
    path: json['path'],
    metaUrl: json['meta_url'],
    location: json['location'],
    type: json['type'],
    size: json['size'],
    createdAt: DateTime.parse(json['created_at']),
  );

  // ✅ To API JSON
  Map<String, dynamic> toJson() => {
    'id': id,
    'media_id': mediaId,
    'name': name,
    'path': path,
    'meta_url': metaUrl,
    'location': location,
    'type': type,
    'size': size,
    'created_at': createdAt?.toIso8601String(),
  };

  // ✅ From DB row (Drift-generated data class)
  factory ChatMedia.fromDb(MediaData row) {
    return ChatMedia(
      id: row.id,
      mediaId: row.mediaId,
      name: row.name,
      path: row.path,
      metaUrl: row.metaUrl,
      location: row.location,
      type: row.type,
      size: row.size,
      createdAt: row.createdAt,
    );
  }

  // ✅ To DB insert/update
  MediasCompanion toCompanion() => MediasCompanion.insert(
    id: Value(id),
    mediaId: Value(mediaId),
    name: Value(name),
    path: Value(path),
    metaUrl: Value(metaUrl),
    location: Value(location),
    type: Value(type),
    size: Value(size),
    createdAt: Value(createdAt),
  );
}
