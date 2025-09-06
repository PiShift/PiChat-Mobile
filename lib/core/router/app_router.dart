// lib/core/router/app_router.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pichat/features/auth/presentation/login_screen.dart';
import 'package:pichat/features/chat/presentation/chat_screen.dart';
import 'package:pichat/features/home/presentation/home_screen.dart';
import 'package:pichat/features/settings/presentation/settings_screen.dart';
import 'package:pichat/features/splash/presentation/splash_screen.dart';
import '../state/auth_state.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authProvider);
  final token = ref.watch(authTokenProvider);
  final orgId = ref.watch(organizationProvider);

  return GoRouter(
    initialLocation: '/splash',
    redirect: (context, state) {
      final isAuth = token != null && token.isNotEmpty;
      final hasOrg = orgId != null;

      final loggingIn = state.matchedLocation == '/login';
      final onSplash = state.matchedLocation == '/splash';
      final onSelectOrg = state.matchedLocation == '/select_org';

      // not authenticated -> go to login (unless already logging in or on splash)
      if (!isAuth && !loggingIn && !onSplash) return '/login';

      // authenticated but no org -> force select_org
      if (isAuth && !hasOrg && !onSelectOrg) return '/select_org';

      // authenticated + org -> go to home (avoid staying on login/splash/select_org)
      if (isAuth && hasOrg && (loggingIn || onSplash || onSelectOrg)) return '/home/chats';

      return null;
    },
    routes: [
      GoRoute(path: '/splash', builder: (context, state) => const SplashScreen()),
      GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
      ShellRoute(
        builder: (context, state, child) => HomeScreen(child: child),
        routes: [
          GoRoute(
            path: '/home/chats',
            builder: (context, state) => const ChatListScreen(),
          ),
          GoRoute(
            path: '/home/settings',
            builder: (context, state) => const SettingsScreen(),
          ),
        ],
      ),
    ],
  );
});
