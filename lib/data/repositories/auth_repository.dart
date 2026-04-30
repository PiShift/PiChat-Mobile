// lib/features/auth/data/auth_repository.dart
import 'package:dio/dio.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart' show defaultTargetPlatform, TargetPlatform;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pichat/core/network/dio_provider.dart';
import 'package:pichat/core/services/notification_service.dart';
import 'package:pichat/core/state/auth_state.dart';
import 'package:pichat/data/models/organization_model.dart';
import 'package:pichat/data/models/user_model.dart';
import 'package:pichat/features/calls/data/call_api.dart';

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(ref.watch(dioProvider), ref);
});

class AuthRepository {
  final Dio _dio;
  final Ref _ref;

  AuthRepository(this._dio, this._ref);

  Future<void> login(String email, String password) async {
    final response = await _dio.post('/auth/login', data: {
      'email': email,
      'password': password,
    });

    if (response.data['status'] == 'tfa_required') {
      // store temporary TFA token
      _ref.read(tfaTokenProvider.notifier).setToken(response.data['tfa_token'] as String);
      // navigation to TFA screen should be handled in login controller/state listener
      return;
    }

    final token = response.data['token'] as String;
    final user = response.data['user'] as Map<String, dynamic>;
    final currentOrg = response.data['current_organization'] as Map<String, dynamic>?;

    // Save token and user globally
    _ref.read(authTokenProvider.notifier).state = token;
    _ref.read(userIdProvider.notifier).state = user['id'] as int;
    final userModel = User.fromJson(user);
    await _ref.read(authProvider.notifier).login(token, userModel);
    _ref.read(userProvider.notifier).setUser(userModel);

    // Save organization if only one exists
    if (currentOrg != null) {
      print('AuthRepository.login() - setting current organization: ${currentOrg['name']}');
      final orgModel = Organization.fromJson(currentOrg);
      print(orgModel.id);
      await _ref.read(authProvider.notifier).setOrganization(orgModel.id);
      await _ref.read(organizationProvider.notifier).setOrganization(orgModel, userModel.id);
    }

    // Register FCM token with backend for push notifications
    await NotificationService().registerTokenWithBackend(_dio);

    // Also register the device with the calling backend so FcmDispatcher
    // can wake this phone for incoming WhatsApp calls. Without this the
    // backend stores no/expired token and FCM responds 404 UNREGISTERED.
    if (currentOrg != null) {
      await _registerCallingDevice();
    }
  }

  Future<void> _registerCallingDevice() async {
    try {
      final fcmToken = NotificationService().fcmToken;
      await _ref.read(callApiProvider).updateAgentStatus(
            status: 'available',
            deviceToken: fcmToken,
            devicePlatform:
                defaultTargetPlatform == TargetPlatform.iOS ? 'ios' : 'android',
          );
    } catch (e) {
      // Non-fatal: calling features may not be enabled for this org.
      debugPrint('updateAgentStatus failed after auth: $e');
    }
  }

  Future<void> logout() async {
    // Unregister FCM token first (before clearing auth state)
    try {
      await NotificationService().unregisterToken(_dio);
    } catch (e) {
      debugPrint('Failed to unregister FCM token: $e');
    }

    // Clear all auth-related state FIRST (before API call)
    // This ensures logout works even if API fails (e.g., token already invalid)
    await _ref.read(authProvider.notifier).logout();
    _ref.read(authTokenProvider.notifier).state = null;
    _ref.read(userIdProvider.notifier).state = null;
    await _ref.read(organizationProvider.notifier).clear();
    await _ref.read(userProvider.notifier).clear();
    
    // Try to notify server (but don't fail if it errors)
    try {
      await _dio.post('/auth/logout');
    } catch (e) {
      // Ignore - we've already cleared local state
      debugPrint('Logout API call failed (ignored): $e');
    }
  }

  Future<void> selectOrganization(Organization orgModel) async {
    // final orgModel = Organization.fromJson(organization);
    await _ref.read(authProvider.notifier).setOrganization(orgModel.id);
    final userId = _ref.read(userIdProvider);
    _ref.read(organizationProvider.notifier).setOrganization(orgModel, userId!);
    // Register this device with the calling backend now that we have an org.
    await _registerCallingDevice();
  }

  Future<void> verifyTfa(String tfaToken, String code) async {
    try {
      // debugPrint('REPO.verifyTfa() calling API with tfaToken=$tfaToken');
      final response = await _dio.post('/auth/verify-2fa', data: {
        'tfa_token': tfaToken,
        'token': code, // code entered by the user
      });
      // debugPrint('REPO.verifyTfa() success: ${response.statusCode}');
      final data = response.data as Map<String, dynamic>;

      // Save token and user globally like normal login
      final token = data['token'] as String;
      final user = data['user'] as Map<String, dynamic>;
      final currentOrg = data['current_organization'] as Map<String, dynamic>?;

      // Clear temporary TFA token
      _ref.read(tfaTokenProvider.notifier).setToken(null);

      _ref.read(authTokenProvider.notifier).state = token;
      _ref.read(userIdProvider.notifier).state = user['id'] as int;
      final userModel = User.fromJson(user);
      await _ref.read(authProvider.notifier).login(token, userModel);
      _ref.read(userProvider.notifier).setUser(userModel);

      if (currentOrg != null) {
        final orgModel = Organization.fromJson(currentOrg);
        _ref.read(organizationProvider.notifier).setOrganization(orgModel, userModel.id);
        await _ref.read(authProvider.notifier).setOrganization(orgModel.id);
      }

      // Register FCM token with backend for push notifications
      await NotificationService().registerTokenWithBackend(_dio);
    } catch (e, st) {
      // debugPrint('REPO.verifyTfa() caught error: $e');
      // debugPrint('REPO.verifyTfa() tfaProvider currently=${_ref.read(tfaTokenProvider)}');
      rethrow;
    }
  }

}
