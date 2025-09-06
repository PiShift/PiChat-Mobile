// lib/core/router/app_router.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pichat/features/auth/presentation/login_screen.dart';
import 'package:pichat/features/chat/presentation/chat_screen.dart';
import '../state/auth_state.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authStateProvider);

  return GoRouter(
    initialLocation: '/login',
    redirect: (context, state) {
      final isAuth = authState.isAuthenticated;
      final loggingIn = state.matchedLocation == '/login';

      if (!isAuth && !loggingIn) return '/login';
      if (isAuth && loggingIn) return '/chats';
      return null;
    },
    routes: [
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/chats',
        builder: (context, state) => const ChatListScreen(),
      ),
    ],
  );
});
