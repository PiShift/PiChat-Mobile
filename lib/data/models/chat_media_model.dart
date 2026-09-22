import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:pichat/data/db/app_database.dart';

class ChatMedia {
  final int id;
  final int? mediaId;
  final String? metaId; // WhatsApp media ID
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
    this.metaId,
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
    metaId: json['meta_id']?.toString(),
    name: json['name'],
    path: json['path'],
    metaUrl: json['meta_url'],
    location: _deviceLocation(json['location'], json['path']),
    type: json['type'],
    size: json['size'],
    createdAt: DateTime.parse(json['created_at']),
  );

  /// Translate the server's `location` into what this app means by it.
  ///
  /// The word means two different things on the two sides. On the server it
  /// records where *it* put the file — 'local' for its own disk, 'amazon' for
  /// S3 — and every outbound upload is stamped 'local'. In this app it means
  /// the file is on *this phone*, which is what tells a bubble to play instead
  /// of offering a download.
  ///
  /// Taken literally, every message we sent arrived claiming to be already on
  /// the device, with an https URL as its "path". Bubbles then tried to open
  /// that URL as a file, found nothing, and offered a download that could not
  /// repair the row — so after a reinstall no outbound media would play. A
  /// path we could not have written ourselves is remote, whatever it is
  /// labelled.
  static String? _deviceLocation(dynamic location, dynamic path) {
    final url = path is String ? path : '';

    if (url.startsWith('http://') || url.startsWith('https://')) {
      return 'remote';
    }

    return location as String?;
  }

  // ✅ To API JSON
  Map<String, dynamic> toJson() => {
    'id': id,
    'media_id': mediaId,
    'meta_id': metaId,
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
      metaId: row.metaId,
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
    metaId: Value(metaId),
    name: Value(name),
    path: Value(path),
    metaUrl: Value(metaUrl),
    location: Value(location),
    type: Value(type),
    size: Value(size),
    createdAt: Value(createdAt),
  );
}
