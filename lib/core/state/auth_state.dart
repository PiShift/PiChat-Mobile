// lib/core/state/auth_state.dart
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage_x/flutter_secure_storage_x.dart';
import 'package:pichat/core/constants/app_constants.dart';
import 'package:pichat/data/db/app_database.dart';
import 'package:pichat/data/db/database_provider.dart';
import 'package:pichat/data/models/chat_model.dart';
import 'package:pichat/data/models/organization_model.dart';
import 'package:pichat/data/models/user_model.dart';
import 'package:pichat/data/services/organization_%20notifier.dart';
import 'package:pichat/data/services/tfa_notifier.dart';
import 'package:pichat/data/services/user_notifier.dart';

final authTokenProvider = StateProvider<String?>((ref) => null);
final userIdProvider = StateProvider<int?>((ref) => null);
final tfaTokenProvider = StateNotifierProvider<TfaNotifier, String?>((ref) => TfaNotifier());
// final databaseProvider = Provider<AppDatabase>((ref) => AppDatabase());

final chatStreamProvider = StreamProvider.family<List<Chat>, int>((ref, orgId) {
  final db = ref.watch(appDatabaseProvider);
  return db.watchChatsForOrg(orgId);
});

final userProvider = StateNotifierProvider<UserNotifier, User?>(
      (ref) => UserNotifier(ref.read(appDatabaseProvider)),
);

final organizationProvider = StateNotifierProvider<OrganizationNotifier, Organization?>(
      (ref) => OrganizationNotifier(ref.read(appDatabaseProvider)),
);

final userOrgsProvider = FutureProvider<List<Organization>>((ref) async {
  final db = ref.watch(appDatabaseProvider);
  final userId = ref.watch(userIdProvider);
  print("Fetching organizations for userId: $userId");
  if (userId == null) return [];

  // join table UserOrganizations to get user's orgs
  final userOrgs = await db.getUserOrganizations(userId);
  return userOrgs;
});


final secureStorage = FlutterSecureStorage();

// Full auth state (user, status, etc.)
class AuthState {
  final bool isAuthenticated;
  final String? token;
  final int? organizationId;
  final User? user;
  final int? userId;

  const AuthState({this.isAuthenticated = false, this.token, this.organizationId, this.user, this.userId});

  AuthState copyWith({bool? isAuthenticated, String? token, int? organizationId, User? user, int? userId}) {
    return AuthState(
      isAuthenticated: isAuthenticated ?? this.isAuthenticated,
      token: token ?? this.token,
      organizationId: organizationId ?? this.organizationId,
      user: user ?? this.user,
      userId: userId ?? this.userId,
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

  Future<void> setUserId(int userId) async {
    await secureStorage.write(key: 'user_id', value: userId.toString());
    state = state.copyWith(userId: userId);
  }

  Future<void> setUser(User user) async {
    state = state.copyWith(user: user, userId: user.id);
    await secureStorage.write(key: 'user_id', value: user.id.toString());
  }

  Future<void> loadFromStorage() async {
    final token = await secureStorage.read(key: 'token');
    final org = await secureStorage.read(key: 'organization_id');
    final userIdStr = await secureStorage.read(key: 'user_id');
    state = state.copyWith(
      token: token,
      organizationId: org != null ? int.parse(org) : null,
      userId: userIdStr != null ? int.parse(userIdStr) : null,
    );
  }

  Future<void> clear() async {
    await secureStorage.deleteAll();
    state = const AuthState();
  }

  Future<void> login(String token, User user) async {
    state = state.copyWith(token: token, user: user, userId: user.id);
    await secureStorage.write(key: 'token', value: token);
    await secureStorage.write(key: AppConstants.kLastEmailKey, value: user.email);
    await secureStorage.write(key: 'user_id', value: user.id.toString());
  }

  Future<void> logout() async {
    state = const AuthState();
    await secureStorage.delete(key: 'token');
    await secureStorage.delete(key: 'organization_id');
    await secureStorage.delete(key: 'user_id');
  }
}

final authProvider = StateNotifierProvider<AuthStateNotifier, AuthState>((ref) {
  return AuthStateNotifier();
});