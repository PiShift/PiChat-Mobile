// lib/features/auth/data/auth_repository.dart
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pichat/core/network/dio_provider.dart';
import 'package:pichat/core/state/auth_state.dart';

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

    final token = response.data['token'] as String;
    final user = response.data['user'] as Map<String, dynamic>;
    final currentOrg = response.data['current_organization'] as int?;

    // Save token and user globally
    _ref.read(authTokenProvider.notifier).state = token;
    await _ref.read(authProvider.notifier).login(token, user);
    _ref.read(userProvider.notifier).state = user;

    // Save organization if only one exists
    if (currentOrg != null) {
      _ref.read(organizationProvider.notifier).state = currentOrg;
      await _ref.read(authProvider.notifier).setOrganization(currentOrg);
    }
  }

  Future<void> logout() async {
    // Clear all auth-related state
    await _ref.read(authProvider.notifier).logout();
    _ref.read(authTokenProvider.notifier).state = null;
    _ref.read(userProvider.notifier).state = null;
    _ref.read(organizationProvider.notifier).state = null;
  }

  Future<void> selectOrganization(int orgId) async {
    await _ref.read(authProvider.notifier).setOrganization(orgId);
    _ref.read(organizationProvider.notifier).state = orgId;
  }
}
