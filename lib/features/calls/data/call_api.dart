// lib/features/calls/data/call_api.dart
//
// Sanctum-authenticated HTTP client for the calling endpoints registered
// in routes/api.php (`/api/v1/calls/*` and `/api/v1/agents/me/status`).
//
// All endpoints require the current `organization_id` (per backend
// CallController contract). It is read once from authProvider and passed
// in every request body / query param.

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pichat/core/network/dio_provider.dart';
import 'package:pichat/core/state/auth_state.dart';

import 'call_models.dart';

/// Result of an outbound attempt. `permissionRequired` means the backend
/// has just queued a permission request to the customer over WhatsApp;
/// the caller must wait for the `CallPermissionUpdated` Reverb event,
/// then retry.
class OutboundResult {
  final CallModel? call;
  final CallPermissionModel? permission;
  final bool permissionRequired;

  const OutboundResult({this.call, this.permission, this.permissionRequired = false});
}

class CallApi {
  CallApi(this._dio, this._orgId);

  final Dio _dio;
  final int? _orgId;

  int get _org {
    final id = _orgId;
    if (id == null) {
      throw StateError('No organization selected — cannot make calling API requests.');
    }
    return id;
  }

  /// Initiate an outbound call. The SDP offer must be created locally
  /// (WebRTC) BEFORE calling this endpoint — backend forwards it to Meta
  /// in the same Graph API request.
  ///
  /// Returns [OutboundResult.permissionRequired] when the customer has
  /// not granted WhatsApp call permission yet (HTTP 409).
  Future<OutboundResult> initiateOutbound({
    required String contactUuid,
    required String sdpOffer,
  }) async {
    try {
      final res = await _dio.post('/calls/outbound', data: <String, dynamic>{
        'contact_uuid': contactUuid,
        'sdp_offer': sdpOffer,
        'organization_id': _org,
      });
      return OutboundResult(
        call: CallModel.fromJson(res.data['data'] as Map<String, dynamic>),
      );
    } on DioException catch (e) {
      // 409 = permission_required. Backend already queued a permission
      // request to the customer; we surface the permission row.
      if (e.response?.statusCode == 409 &&
          e.response?.data is Map &&
          (e.response?.data['reason'] == 'permission_required')) {
        final permJson = e.response?.data['permission'] as Map<String, dynamic>?;
        return OutboundResult(
          permission: permJson != null ? CallPermissionModel.fromJson(permJson) : null,
          permissionRequired: true,
        );
      }
      rethrow;
    }
  }

  /// Manually request WhatsApp call permission for a contact.
  Future<CallPermissionModel> requestPermission(String contactUuid) async {
    final res = await _dio.post('/calls/permissions/request', data: <String, dynamic>{
      'contact_uuid': contactUuid,
      'organization_id': _org,
    });
    return CallPermissionModel.fromJson(res.data['data'] as Map<String, dynamic>);
  }

  /// Accept an inbound call assigned to this agent. Backend forwards the
  /// SDP answer (and pre-accept) to Meta.
  Future<void> accept({
    required String callUuid,
    required String sdpAnswer,
  }) async {
    final uuid = _cleanUuid(callUuid);
    await _dio.post('/calls/$uuid/accept', data: <String, dynamic>{
      'sdp_answer': sdpAnswer,
      'organization_id': _org,
    });
  }

  /// Per-agent reject (other ringing agents keep ringing).
  Future<void> reject(String callUuid, {String? reason}) async {
    final uuid = _cleanUuid(callUuid);
    await _dio.post('/calls/$uuid/reject', data: <String, dynamic>{
      'organization_id': _org,
      if (reason != null) 'reason': reason,
    });
  }

  /// Hang up an active call (terminates on Meta side too).
  Future<void> hangup(String callUuid) async {
    final uuid = _cleanUuid(callUuid);
    await _dio.post('/calls/$uuid/terminate', data: <String, dynamic>{
      'organization_id': _org,
    });
  }

  /// Strip stray surrounding quotes / whitespace that occasionally leak in
  /// when a uuid has been routed through a JSON-encoded payload (e.g. some
  /// CallKit / FCM bridges).
  String _cleanUuid(String raw) {
    var u = raw.trim();
    if (u.length >= 2 && u.startsWith('"') && u.endsWith('"')) {
      u = u.substring(1, u.length - 1);
    }
    return u;
  }

  /// Update agent presence + register FCM device token so the backend
  /// can wake this device for incoming calls.
  Future<void> updateAgentStatus({
    required String status,
    String? deviceToken,
    String? devicePlatform,
  }) async {
    await _dio.patch('/agents/me/status', data: <String, dynamic>{
      'status': status,
      'organization_id': _org,
      if (deviceToken != null) 'device_token': deviceToken,
      if (devicePlatform != null) 'device_platform': devicePlatform,
    });
  }

  Future<CallModel> fetchCall(String uuid) async {
    final res = await _dio.get('/calls/$uuid', queryParameters: {
      'organization_id': _org,
    });
    return CallModel.fromJson(res.data['data'] as Map<String, dynamic>);
  }

  Future<List<CallModel>> fetchHistory({int page = 1, int perPage = 30}) async {
    final res = await _dio.get('/calls', queryParameters: {
      'page': page,
      'per_page': perPage,
      'organization_id': _org,
    });
    final list = (res.data['data'] as List).cast<Map<String, dynamic>>();
    return list.map(CallModel.fromJson).toList();
  }
}

final callApiProvider = Provider<CallApi>((ref) {
  final dio = ref.watch(dioProvider);
  final orgId = ref.watch(authProvider).organizationId;
  return CallApi(dio, orgId);
});
