// lib/features/auth/data/auth_repository.dart
import 'package:dio/dio.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pichat/core/network/dio_provider.dart';
import 'package:pichat/core/state/auth_state.dart';
import 'package:pichat/data/models/organization_model.dart';
import 'package:pichat/data/models/user_model.dart';

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
  }

  Future<void> logout() async {
    final response = await _dio.post('/auth/logout');
    // Clear all auth-related state
    await _ref.read(authProvider.notifier).logout();
    _ref.read(authTokenProvider.notifier).state = null;
    _ref.read(userIdProvider.notifier).state = null;
    _ref.read(authProvider.notifier).clear();
  }

  Future<void> selectOrganization(Organization orgModel) async {
    // final orgModel = Organization.fromJson(organization);
    await _ref.read(authProvider.notifier).setOrganization(orgModel.id);
    final userId = _ref.read(userIdProvider);
    _ref.read(organizationProvider.notifier).setOrganization(orgModel, userId!);
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
    } catch (e, st) {
      // debugPrint('REPO.verifyTfa() caught error: $e');
      // debugPrint('REPO.verifyTfa() tfaProvider currently=${_ref.read(tfaTokenProvider)}');
      rethrow;
    }
  }

}
