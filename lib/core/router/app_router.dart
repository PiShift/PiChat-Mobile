// lib/core/router/app_router.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pichat/core/router/stream_listenable.dart';
import 'package:pichat/data/models/contact_model.dart';
import 'package:pichat/features/auth/presentation/login_screen.dart';
import 'package:pichat/features/auth/presentation/tfa_screen.dart';
import 'package:pichat/features/campaigns/presentation/campaigns_screen.dart';
import 'package:pichat/features/calls/presentation/call_history_screen.dart';
import 'package:pichat/features/groups/presentation/group_detail_screen.dart';
import 'package:pichat/features/groups/presentation/groups_screen.dart';
import 'package:pichat/data/models/group_model.dart';
import 'package:pichat/features/calls/presentation/in_call_screen.dart';
import 'package:pichat/features/calls/presentation/outbound_call_screen.dart';
import 'package:pichat/features/chat/presentation/chat_screen.dart';
import 'package:pichat/features/chat/presentation/chat_threads.dart';
import 'package:pichat/features/chat/presentation/new_chat_screen.dart';
import 'package:pichat/features/home/presentation/home_screen.dart';
import 'package:pichat/features/select_organization/presentation/select_org_screen.dart';
import 'package:pichat/features/settings/presentation/settings_screen.dart';
import 'package:pichat/features/splash/presentation/splash_screen.dart';
import 'package:pichat/features/templates/presentation/templates_management_screen.dart';
import '../state/auth_state.dart';


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
            path: '/home/templates',
            builder: (context, state) => const TemplatesManagementScreen(),
          ),
          GoRoute(
            path: '/home/campaigns',
            builder: (context, state) => const CampaignsManagementScreen(),
          ),
          GoRoute(
            path: '/home/settings',
            builder: (context, state) => const SettingsScreen(),
          ),
          GoRoute(
            path: '/home/chats/new',
            builder: (context, state) => const NewChatScreen(),
          ),
          GoRoute(
            path: '/home/chats/detail',
            builder: (context, state) {
              final contact = state.extra as Contact;
              return ChatThread(contact: contact);
            },
          ),
          GoRoute(
            path: '/home/calls',
            builder: (context, state) => const CallHistoryScreen(),
          ),
          GoRoute(
            path: '/home/groups',
            builder: (context, state) => const GroupsScreen(),
          ),
          GoRoute(
            path: '/home/groups/detail',
            builder: (context, state) {
              final group = state.extra as WhatsappGroup;
              return GroupDetailScreen(group: group);
            },
          ),
        ],
      ),
      GoRoute(
        path: '/call',
        builder: (context, state) => const InCallScreen(),
      ),
      GoRoute(
        path: '/call/outbound',
        builder: (context, state) {
          final extra = state.extra as Map<String, dynamic>;
          return OutboundCallScreen(
            contactUuid: extra['uuid'] as String,
            contactName: extra['name'] as String? ?? '',
            contactPhone: extra['phone'] as String? ?? '',
          );
        },
      ),
    ],
  );
});
