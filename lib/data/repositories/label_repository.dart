import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pichat/core/network/dio_provider.dart';
import 'package:pichat/core/state/auth_state.dart';
import 'package:pichat/core/theme/app_colors.dart';

/// A label, as the whole organization sees it.
///
/// Labels are PiChat's own idea — the WhatsApp Cloud API has no equivalent — so
/// they live in our database and are shared by every agent. Renaming one on a
/// phone renames it for the team, which is the point: a label is only useful if
/// everyone means the same thing by it.
class Label {
  const Label({
    required this.uuid,
    required this.name,
    this.color,
    this.isExpirable = false,
    this.contactsCount = 0,
  });

  final String uuid;
  final String name;

  /// Hex string as stored by the web (`#FF9800`), or null for older labels
  /// created before colours existed.
  final String? color;

  final bool isExpirable;
  final int contactsCount;

  factory Label.fromJson(Map<String, dynamic> json) => Label(
        uuid: json['uuid'] as String,
        name: json['name'] as String? ?? '',
        color: json['color'] as String?,
        isExpirable: json['is_expirable'] == true || json['is_expirable'] == 1,
        contactsCount: (json['contacts_count'] as num?)?.toInt() ?? 0,
      );

  Map<String, dynamic> toJson() => {
        'uuid': uuid,
        'name': name,
        'color': color,
        'is_expirable': isExpirable,
      };

  /// The colour to paint this label.
  ///
  /// Falls back to a hue derived from the name rather than a single grey, so a
  /// set of unstyled labels is still visually separable — and the same label
  /// keeps the same colour everywhere it appears.
  Color get displayColor {
    final raw = color?.trim();

    if (raw != null && raw.isNotEmpty) {
      final parsed = _parseHex(raw);

      if (parsed != null) return parsed;
    }

    return _fallbackPalette[name.hashCode.abs() % _fallbackPalette.length];
  }

  static Color? _parseHex(String value) {
    var hex = value.replaceAll('#', '').trim();

    if (hex.length == 6) hex = 'FF$hex';
    if (hex.length != 8) return null;

    final parsed = int.tryParse(hex, radix: 16);

    return parsed == null ? null : Color(parsed);
  }

  static const _fallbackPalette = <Color>[
    PiPalette.primary500,
    PiPalette.info500,
    PiPalette.success500,
    PiPalette.warning500,
    Color(0xFF8E5AF7),
    Color(0xFF00A3A3),
  ];
}

class LabelRepository {
  LabelRepository(this._dio, this._orgId);

  final Dio _dio;
  final int? _orgId;

  int get _org {
    final id = _orgId;
    if (id == null) {
      throw StateError('No organization selected — cannot manage labels.');
    }

    return id;
  }

  Future<List<Label>> list() async {
    final res = await _dio.get('/labels', queryParameters: {
      'organization_id': _org,
    });

    return (res.data['data'] as List)
        .map((e) => Label.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<Label> create({
    required String name,
    String? color,
    bool isExpirable = false,
  }) async {
    final res = await _dio.post('/labels', data: {
      'organization_id': _org,
      'name': name,
      if (color != null) 'color': color,
      'is_expirable': isExpirable,
    });

    return Label.fromJson(Map<String, dynamic>.from(res.data['data'] as Map));
  }

  Future<Label> update(
    String uuid, {
    String? name,
    String? color,
    bool? isExpirable,
  }) async {
    final res = await _dio.put('/labels/$uuid', data: {
      'organization_id': _org,
      if (name != null) 'name': name,
      if (color != null) 'color': color,
      if (isExpirable != null) 'is_expirable': isExpirable,
    });

    return Label.fromJson(Map<String, dynamic>.from(res.data['data'] as Map));
  }

  Future<void> delete(String uuid) async {
    await _dio.delete('/labels/$uuid', data: {'organization_id': _org});
  }

  /// Replaces the labels on a conversation with exactly [labelUuids].
  ///
  /// A full replace rather than add/remove calls, so a retry on a flaky
  /// connection cannot leave the conversation half-labelled.
  Future<List<Label>> syncForContact(
    String contactUuid,
    List<String> labelUuids,
  ) async {
    final res = await _dio.post('/contacts/$contactUuid/labels', data: {
      'organization_id': _org,
      'label_uuids': labelUuids,
    });

    return (res.data['data'] as List)
        .map((e) => Label.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }
}

final labelRepositoryProvider = Provider<LabelRepository>((ref) {
  final dio = ref.watch(dioProvider);
  final orgId = ref.watch(authProvider).organizationId;

  return LabelRepository(dio, orgId);
});

/// Every label in the organization. Invalidated after any change so all
/// surfaces — the manager, the picker, the chat list — agree at once.
final labelsProvider = FutureProvider<List<Label>>((ref) async {
  return ref.watch(labelRepositoryProvider).list();
});
