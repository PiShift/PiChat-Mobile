// lib/core/router/app_router.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pichat/core/router/stream_listenable.dart';
import 'package:pichat/features/auth/presentation/login_screen.dart';
import 'package:pichat/features/auth/presentation/tfa_screen.dart';
import 'package:pichat/features/chat/presentation/chat_screen.dart';
import 'package:pichat/features/home/presentation/home_screen.dart';
import 'package:pichat/features/select_organization/presentation/select_org_screen.dart';
import 'package:pichat/features/settings/presentation/settings_screen.dart';
import 'package:pichat/features/splash/presentation/splash_screen.dart';
import '../state/auth_state.dart';
import 'package:async/async.dart';


final appRouterProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authProvider);
  final token = ref.watch(authTokenProvider);
  final orgId = ref.watch(organizationProvider)?.id;
  final tfaToken = ref.watch(tfaTokenProvider);

  // create a StreamListenable that watches the providers' streams
  final refresh = StreamListenable([
    ref.watch(authTokenProvider.notifier).stream,
    ref.watch(organizationProvider.notifier).stream,
    ref.watch(tfaTokenProvider.notifier).stream,
    ref.watch(userProvider.notifier).stream,
  ]);

  // make sure it is disposed when provider is disposed
  ref.onDispose(() {
    refresh.dispose();
  });

  return GoRouter(
    initialLocation: '/splash',
    refreshListenable: refresh,
    redirect: (context, state) {
      final isAuth = token != null && token.isNotEmpty;
      final hasOrg = orgId != null;

      final loggingIn = state.matchedLocation == '/login';
      final onSplash = state.matchedLocation == '/splash';
      final onSelectOrg = state.matchedLocation == '/select_org';
      final onTfa = state.matchedLocation == '/tfa';

      print("GoRouter redirect: isAuth=$isAuth, hasOrg=$hasOrg, tfaToken=$tfaToken, loggingIn=$loggingIn, onSplash=$onSplash, onSelectOrg=$onSelectOrg, onTfa=$onTfa");
      // in TFA flow -> stay on TFA
      // if (!isAuth && tfaToken != null && !onTfa) return '/tfa';
      if (tfaToken != null) {
        return onTfa ? null : '/tfa';
      }

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
      GoRoute(path: '/tfa', builder: (context, state) => const TfaScreen()),
      GoRoute(path: '/select_org', builder: (context, state) => const SelectOrganizationScreen()),
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
