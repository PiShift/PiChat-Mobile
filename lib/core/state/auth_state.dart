// lib/core/state/auth_state.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage_x/flutter_secure_storage_x.dart';

final authTokenProvider = StateProvider<String?>((ref) => null);
final userProvider = StateProvider<Map<String, dynamic>?>((ref) => null);
final organizationProvider = StateProvider<int?>((ref) => null);

final secureStorage = FlutterSecureStorage();

// Full auth state (user, status, etc.)
class AuthState {
  final bool isAuthenticated;
  final String? token;
  final int? organizationId;
  final Map<String, dynamic>? user;

  const AuthState({this.isAuthenticated = false, this.token, this.organizationId, this.user});

  AuthState copyWith({bool? isAuthenticated, String? token, int? organizationId, Map<String, dynamic>? user}) {
    return AuthState(
      isAuthenticated: isAuthenticated ?? this.isAuthenticated,
      token: token ?? this.token,
      organizationId: organizationId ?? this.organizationId,
      user: user ?? this.user,
    );
  }
}

class AuthStateNotifier extends StateNotifier<AuthState> {
  AuthStateNotifier() : super(const AuthState());

  Future<void> setToken(String token) async {
    await secureStorage.write(key: 'token', value: token);
    state = state.copyWith(token: token);
  }

  Future<void> setOrganization(int orgId) async {
    await secureStorage.write(key: 'organization_id', value: orgId.toString());
    state = state.copyWith(organizationId: orgId);
  }

  Future<void> loadFromStorage() async {
    final token = await secureStorage.read(key: 'token');
    final org = await secureStorage.read(key: 'organization_id');
    state = state.copyWith(
      token: token,
      organizationId: org != null ? int.parse(org) : null,
    );
  }

  Future<void> clear() async {
    await secureStorage.deleteAll();
    state = const AuthState();
  }

  Future<void> login(String token, Map<String, dynamic> user) async {
    state = state.copyWith(token: token, user: user);
    await secureStorage.write(key: 'token', value: token);
  }

  Future<void> logout() async {
    state = const AuthState();
    await secureStorage.deleteAll();
  }
}

final authProvider = StateNotifierProvider<AuthStateNotifier, AuthState>((ref) {
  return AuthStateNotifier();
});
