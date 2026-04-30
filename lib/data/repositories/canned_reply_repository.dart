import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pichat/core/network/dio_provider.dart';

final cannedReplyRepositoryProvider = Provider<CannedReplyRepository>((ref) {
  final dio = ref.watch(dioProvider);
  return CannedReplyRepository(dio);
});

/// Model for Canned Reply data
class CannedReply {
  final String uuid;
  final String shortcut;
  final String type; // text, image, audio, document
  final String content;

  CannedReply({
    required this.uuid,
    required this.shortcut,
    required this.type,
    required this.content,
  });

  factory CannedReply.fromJson(Map<String, dynamic> json) {
    return CannedReply(
      uuid: json['uuid'] as String? ?? '',
      shortcut: json['shortcut'] as String? ?? '',
      type: json['type'] as String? ?? 'text',
      content: json['content'] as String? ?? '',
    );
  }

  /// Check if this reply matches a / shortcut input
  bool matchesInput(String input) {
    if (input.isEmpty) return true;
    if (input.startsWith('/')) {
      return shortcut.toLowerCase().startsWith(input.toLowerCase());
    }
    return shortcut.toLowerCase().contains(input.toLowerCase()) ||
        content.toLowerCase().contains(input.toLowerCase());
  }
}

class CannedReplyRepository {
  final Dio _dio;

  CannedReplyRepository(this._dio);

  /// Get all canned replies for the organization
  Future<List<CannedReply>> getCannedReplies({String? search}) async {
    try {
      final queryParams = <String, dynamic>{
        'per_page': 100, // Get all for quick access
      };
      
      if (search != null && search.isNotEmpty) {
        queryParams['search'] = search;
      }
      
      final response = await _dio.get(
        '/canned-replies',
        queryParameters: queryParams,
      );
      
      if (response.statusCode == 200 && response.data['success'] == true) {
        final List<dynamic> repliesList = response.data['canned_replies'] ?? [];
        return repliesList.map((json) => CannedReply.fromJson(json)).toList();
      }
      
      throw Exception('Failed to load canned replies');
    } on DioException catch (e) {
      throw Exception(e.response?.data?['message'] ?? 'Failed to load canned replies');
    }
  }

  /// Find matching canned replies for the given input
  Future<List<CannedReply>> findMatches(String input) async {
    final allReplies = await getCannedReplies();
    
    if (input.isEmpty) return allReplies;
    
    // If starts with "/", match shortcuts
    if (input.startsWith('/')) {
      return allReplies.where((reply) {
        return reply.shortcut.toLowerCase().startsWith(input.toLowerCase());
      }).toList();
    }
    
    // Otherwise search by shortcut or content
    final lowerInput = input.toLowerCase();
    return allReplies.where((reply) {
      return reply.shortcut.toLowerCase().contains(lowerInput) ||
             reply.content.toLowerCase().contains(lowerInput);
    }).toList();
  }
}

/// Provider for all canned replies
final cannedRepliesProvider = FutureProvider<List<CannedReply>>((ref) async {
  final repo = ref.watch(cannedReplyRepositoryProvider);
  return repo.getCannedReplies();
});

/// Provider for filtered canned replies (used for search)
final filteredCannedRepliesProvider = FutureProvider.family<List<CannedReply>, String>((ref, search) async {
  final repo = ref.watch(cannedReplyRepositoryProvider);
  return repo.findMatches(search);
});
