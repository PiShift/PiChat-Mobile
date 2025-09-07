// lib/features/auth/application/auth_controller.dart
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pichat/core/network/error_handler.dart';
import 'package:pichat/data/repositories/auth_repository.dart';

class AuthController extends StateNotifier<AsyncValue<void>> {
  final AuthRepository _repository;
  AuthController(this._repository) : super(const AsyncData(null));


  Future<void> login(String email, String password) async {
    state = const AsyncLoading();
    try {
      await _repository.login(email, password);
      state = const AsyncData(null);
    } catch (e, st) {
      final message = ErrorHandler.getErrorMessage(e);
      state = AsyncError(message, st);
    }
  }

  // Logout user
  Future<void> logout() async {
    state = const AsyncLoading();
    try {
      await _repository.logout();
      state = const AsyncData(null);
    } catch (e, st) {
      final message = ErrorHandler.getErrorMessage(e);
      state = AsyncError(message, st);
    }
  }

  // Verify TFA code
  Future<void> verifyTfa(String tfaToken, String code) async {
    state = const AsyncLoading();
    try {
      await _repository.verifyTfa(tfaToken, code);
      state = const AsyncData(null);
    } catch (e, st) {
      final message = ErrorHandler.getErrorMessage(e);
      state = AsyncError(message, st);
      rethrow;
    }
  }
}

final authControllerProvider =
StateNotifierProvider<AuthController, AsyncValue<void>>((ref) {
  return AuthController(ref.watch(authRepositoryProvider));
});
