import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pichat/core/network/dio_provider.dart';
import 'package:pichat/data/models/group_model.dart';

final groupRepositoryProvider = Provider<GroupRepository>((ref) {
  final dio = ref.watch(dioProvider);
  return GroupRepository(dio);
});

class GroupRepository {
  final Dio _dio;

  GroupRepository(this._dio);

  // -------------------------------------------------------------------------
  // Groups CRUD
  // -------------------------------------------------------------------------

  Future<List<WhatsappGroup>> getGroups({int page = 1}) async {
    final response = await _dio.get('/groups', queryParameters: {'page': page});
    final data = response.data['data'] as List<dynamic>? ?? [];
    return data.map((g) => WhatsappGroup.fromJson(g as Map<String, dynamic>)).toList();
  }

  Future<WhatsappGroup> getGroup(String uuid) async {
    final response = await _dio.get('/groups/$uuid');
    return WhatsappGroup.fromJson(response.data['data'] as Map<String, dynamic>);
  }

  Future<WhatsappGroup> createGroup({
    required String subject,
    String? description,
    String joinApprovalMode = 'auto_approve',
  }) async {
    final response = await _dio.post('/groups', data: {
      'subject': subject,
      'join_approval_mode': joinApprovalMode,
      if (description != null) 'description': description,
    });
    return WhatsappGroup.fromJson(response.data['data'] as Map<String, dynamic>);
  }

  Future<void> deleteGroup(String uuid) async {
    await _dio.delete('/groups/$uuid');
  }

  // -------------------------------------------------------------------------
  // Invite Link
  // -------------------------------------------------------------------------

  Future<String?> getInviteLink(String uuid) async {
    final response = await _dio.get('/groups/$uuid/invite-link');
    return response.data['invite_link'] as String?;
  }

  Future<String?> resetInviteLink(String uuid) async {
    final response = await _dio.post('/groups/$uuid/invite-link/reset');
    return response.data['invite_link'] as String?;
  }

  // -------------------------------------------------------------------------
  // Participants
  // -------------------------------------------------------------------------

  Future<void> removeParticipant(String uuid, String waId) async {
    await _dio.delete('/groups/$uuid/participants/$waId');
  }

  // -------------------------------------------------------------------------
  // Join Requests
  // -------------------------------------------------------------------------

  Future<List<Map<String, dynamic>>> getJoinRequests(String uuid) async {
    final response = await _dio.get('/groups/$uuid/join-requests');
    final data = response.data['data'] as List<dynamic>? ?? [];
    return data.cast<Map<String, dynamic>>();
  }

  Future<void> approveJoinRequest(String uuid, String requestId) async {
    await _dio.post('/groups/$uuid/join-requests/$requestId/approve');
  }

  Future<void> rejectJoinRequest(String uuid, String requestId) async {
    await _dio.post('/groups/$uuid/join-requests/$requestId/reject');
  }
}
