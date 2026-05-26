// lib/features/splash/presentation/splash_screen.dart
import 'package:flutter/foundation.dart' show defaultTargetPlatform, TargetPlatform;
import 'package:flutter/material.dart';
import 'package:flutter_callkit_incoming/flutter_callkit_incoming.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage_x/flutter_secure_storage_x.dart';
import 'package:go_router/go_router.dart';
import 'package:pichat/core/network/dio_provider.dart';
import 'package:pichat/core/services/notification_service.dart';
import 'package:pichat/core/state/auth_state.dart';
import 'package:pichat/core/theme/app_colors.dart';
import 'package:pichat/core/theme/app_theme.dart';
import 'package:pichat/data/db/database_provider.dart';
import 'package:pichat/features/calls/data/call_api.dart';
import 'package:pichat/services/reverb_singleton.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeIn;
  bool _isBooting = true;

  @override
  void initState() {
    super.initState();

    _controller =
        AnimationController(vsync: this, duration: const Duration(seconds: 2));
    _fadeIn = CurvedAnimation(parent: _controller, curve: Curves.easeInOut);

    _controller.forward();
    _boot();
  }

  /// Loads persisted auth state, sets up Reverb, registers FCM token —
  /// everything that was previously blocking runApp() in main.dart.
  Future<void> _boot() async {
    // Initialize notifications and clear zombie CallKit calls in parallel.
    await Future.wait([
      NotificationService().initialize().catchError((_) => null),
      FlutterCallkitIncoming.endAllCalls().catchError((_) => null),
    ]);

    const storage = FlutterSecureStorage();
    final results = await Future.wait([
      storage.read(key: 'token'),
      storage.read(key: 'organization_id'),
      storage.read(key: 'user_id'),
    ]);
    final token = results[0];
    final orgId = results[1];
    final userId = results[2];

    if (token != null && token.isNotEmpty) {
      ref.read(authTokenProvider.notifier).state = token;
    }

    if (userId != null && userId.isNotEmpty) {
      final db = ref.read(appDatabaseProvider);
      ref.read(userIdProvider.notifier).state = int.parse(userId);
      ref.read(userProvider.notifier).loadUser(int.parse(userId));

      if (orgId != null && orgId.isNotEmpty) {
        final reverbService = ref.read(reverbServiceProvider);
        reverbService.init(
          orgId: orgId,
          database: db,
          userId: int.parse(userId),
        );
        reverbService.connect();

        final org = await db.getOrganizationById(int.parse(orgId));
        if (org != null) {
          ref.read(organizationProvider.notifier).setOrganization(org, int.parse(userId));
          await ref.read(authProvider.notifier).setOrganization(org.id);
        }

        // FCM token registration and agent status — fire-and-forget.
        final dio = ref.read(dioProvider);
        NotificationService().registerTokenWithBackend(dio).catchError((_) {});

        final fcmToken = NotificationService().fcmToken;
        ref.read(callApiProvider).updateAgentStatus(
          status: 'available',
          deviceToken: fcmToken,
          devicePlatform: defaultTargetPlatform == TargetPlatform.iOS ? 'ios' : 'android',
        ).catchError((e) {
          debugPrint('updateAgentStatus failed at boot: $e');
        });
      }
    }

    if (mounted) setState(() => _isBooting = false);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);

    if (!_isBooting) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        if (authState.isAuthenticated) {
          if (authState.organizationId != null) {
            context.go('/home/chats');
          } else {
            context.go('/select_org');
          }
        } else {
          context.go('/login');
        }
      });
    }
    return Scaffold(
      backgroundColor: PiColors.of(context).background,
      body: Center(
        child: FadeTransition(
          opacity: _fadeIn,
          child: Image.asset(
            'assets/images/ic_launcher.png',
            width: 120,
          ),
        ),
      ),
    );
  }
}
