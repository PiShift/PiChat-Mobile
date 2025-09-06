// lib/core/state/auth_state.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

// Just the token
final authTokenProvider = StateProvider<String?>((ref) => null);

// Full auth state (user, status, etc.)
class AuthState {
  final bool isAuthenticated;
  final String? token;
  final Map<String, dynamic>? user;

  const AuthState({this.isAuthenticated = false, this.token, this.user});

  AuthState copyWith({bool? isAuthenticated, String? token, Map<String, dynamic>? user}) {
    return AuthState(
      isAuthenticated: isAuthenticated ?? this.isAuthenticated,
      token: token ?? this.token,
      user: user ?? this.user,
    );
  }
}

class AuthStateNotifier extends StateNotifier<AuthState> {
  AuthStateNotifier() : super(const AuthState());

  void login(String token, Map<String, dynamic> user) {
    state = AuthState(isAuthenticated: true, token: token, user: user);
  }

  void logout() {
    state = const AuthState(isAuthenticated: false);
  }
}

final authStateProvider = StateNotifierProvider<AuthStateNotifier, AuthState>((ref) {
  return AuthStateNotifier();
});
