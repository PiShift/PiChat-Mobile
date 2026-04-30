import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pichat/core/network/dio_provider.dart';

final templateRepositoryProvider = Provider<TemplateRepository>((ref) {
  final dio = ref.watch(dioProvider);
  return TemplateRepository(dio);
});

/// Model for Template variable
class TemplateVariable {
  final String component;
  final int index;
  final String placeholder;

  TemplateVariable({
    required this.component,
    required this.index,
    required this.placeholder,
  });

  factory TemplateVariable.fromJson(Map<String, dynamic> json) {
    return TemplateVariable(
      component: json['component'] as String? ?? 'body',
      index: json['index'] as int? ?? 1,
      placeholder: json['placeholder'] as String? ?? '',
    );
  }
}

/// Model for Template data
class Template {
  final int id;
  final String uuid;
  final String metaId;
  final String name;
  final String category;
  final String language;
  final String status;
  final List<Map<String, dynamic>> components;
  final List<TemplateVariable> variables;
  final String preview;

  Template({
    required this.id,
    required this.uuid,
    required this.metaId,
    required this.name,
    required this.category,
    required this.language,
    required this.status,
    required this.components,
    required this.variables,
    required this.preview,
  });

  factory Template.fromJson(Map<String, dynamic> json) {
    final variablesList = (json['variables'] as List<dynamic>? ?? [])
        .map((v) => TemplateVariable.fromJson(v as Map<String, dynamic>))
        .toList();

    return Template(
      id: json['id'] as int,
      uuid: json['uuid'] as String? ?? '',
      metaId: json['meta_id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      category: json['category'] as String? ?? '',
      language: json['language'] as String? ?? 'en',
      status: json['status'] as String? ?? '',
      components: (json['components'] as List<dynamic>? ?? [])
          .map((c) => c as Map<String, dynamic>)
          .toList(),
      variables: variablesList,
      preview: json['preview'] as String? ?? '',
    );
  }

  bool get hasVariables => variables.isNotEmpty;

  /// Returns the HEADER component format (TEXT, IMAGE, DOCUMENT, VIDEO) or null
  String? get headerFormat {
    try {
      final header = components.firstWhere(
        (c) => (c['type'] as String?)?.toUpperCase() == 'HEADER',
        orElse: () => {},
      );
      return (header['format'] as String?)?.toUpperCase();
    } catch (_) {
      return null;
    }
  }

  List<TemplateVariable> get headerVariables =>
      variables.where((v) => v.component == 'header').toList();

  List<TemplateVariable> get bodyVariables =>
      variables.where((v) => v.component == 'body').toList();
}

class TemplateRepository {
  final Dio _dio;

  TemplateRepository(this._dio);

  /// Get all approved templates
  Future<List<Template>> getTemplates({String? category, String? search}) async {
    try {
      final queryParams = <String, dynamic>{
        'per_page': 100,
      };

      if (category != null && category.isNotEmpty) {
        queryParams['category'] = category;
      }
      if (search != null && search.isNotEmpty) {
        queryParams['search'] = search;
      }

      final response = await _dio.get(
        '/templates',
        queryParameters: queryParams,
      );

      if (response.statusCode == 200 && response.data['success'] == true) {
        final List<dynamic> templatesList = response.data['templates'] ?? [];
        return templatesList.map((json) => Template.fromJson(json)).toList();
      }

      throw Exception('Failed to load templates');
    } on DioException catch (e) {
      throw Exception(e.response?.data?['message'] ?? 'Failed to load templates');
    }
  }

  /// Send a template message to a contact.
  /// Pass [bodyValues] for body variables (ordered), [headerValues] for text header variables,
  /// and [mediaFile] for DOCUMENT/IMAGE/VIDEO header files (uploaded to Meta on the server side).
  Future<void> sendTemplate(
    String contactUuid,
    int templateId, {
    List<String>? bodyValues,
    List<String>? headerValues,
    PlatformFile? mediaFile,
  }) async {
    try {
      final data = FormData.fromMap({
        'template_id': templateId,
        if (bodyValues != null)
          for (var i = 0; i < bodyValues.length; i++) 'body_values[$i]': bodyValues[i],
        if (headerValues != null)
          for (var i = 0; i < headerValues.length; i++) 'header_values[$i]': headerValues[i],
        if (mediaFile != null && mediaFile.path != null)
          'header_media_file': await MultipartFile.fromFile(
            mediaFile.path!,
            filename: mediaFile.name,
          ),
      });

      final response = await _dio.post(
        '/contacts/$contactUuid/send-template',
        data: data,
        options: Options(contentType: 'multipart/form-data'),
      );

      if (response.statusCode != 200 || response.data['success'] != true) {
        throw Exception(response.data['message'] ?? 'Failed to send template');
      }
    } on DioException catch (e) {
      throw Exception(e.response?.data?['message'] ?? 'Failed to send template');
    }
  }

  /// Get canned replies for the current organization.
  Future<List<CannedReplyData>> getCannedReplies({String? search}) async {
    try {
      final response = await _dio.get(
        '/canned-replies',
        queryParameters: search != null && search.isNotEmpty ? {'search': search} : null,
      );
      if (response.statusCode == 200) {
        final List<dynamic> list = response.data['canned_replies'] ?? [];
        return list.map((json) => CannedReplyData.fromJson(json as Map<String, dynamic>)).toList();
      }
      throw Exception('Failed to load canned replies');
    } on DioException catch (e) {
      throw Exception(e.response?.data?['message'] ?? 'Failed to load canned replies');
    }
  }

  /// Create a new canned reply.
  Future<void> storeCannedReply({
    required String shortcut,
    required String content,
    String type = 'text',
  }) async {
    try {
      await _dio.post(
        '/canned-replies',
        data: {'shortcut': shortcut, 'type': type, 'content': content},
        options: Options(contentType: 'application/json'),
      );
    } on DioException catch (e) {
      throw Exception(e.response?.data?['message'] ?? 'Failed to create canned reply');
    }
  }

  /// Update an existing canned reply.
  Future<void> updateCannedReply({
    required String uuid,
    required String shortcut,
    required String content,
    String type = 'text',
  }) async {
    try {
      await _dio.put(
        '/canned-replies/$uuid',
        data: {'shortcut': shortcut, 'type': type, 'content': content},
        options: Options(contentType: 'application/json'),
      );
    } on DioException catch (e) {
      throw Exception(e.response?.data?['message'] ?? 'Failed to update canned reply');
    }
  }

  /// Delete a canned reply.
  Future<void> deleteCannedReply(String uuid) async {
    try {
      await _dio.delete('/canned-replies/$uuid');
    } on DioException catch (e) {
      throw Exception(e.response?.data?['message'] ?? 'Failed to delete canned reply');
    }
  }
}

class CannedReplyData {
  final String uuid;
  final String shortcut;
  final String type;
  final String content;

  const CannedReplyData({
    required this.uuid,
    required this.shortcut,
    required this.type,
    required this.content,
  });

  factory CannedReplyData.fromJson(Map<String, dynamic> json) {
    return CannedReplyData(
      uuid: json['uuid'] as String? ?? '',
      shortcut: json['shortcut'] as String? ?? '',
      type: json['type'] as String? ?? 'text',
      content: json['content'] as String? ?? '',
    );
  }
}

/// Provider for all templates
final templatesProvider = FutureProvider<List<Template>>((ref) async {
  final repo = ref.watch(templateRepositoryProvider);
  return repo.getTemplates();
});

/// Provider for templates by category
final templatesByCategoryProvider = FutureProvider.family<List<Template>, String?>((ref, category) async {
  final repo = ref.watch(templateRepositoryProvider);
  return repo.getTemplates(category: category);
});
