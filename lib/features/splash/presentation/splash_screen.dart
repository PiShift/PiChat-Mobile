// lib/features/splash/presentation/splash_screen.dart
import 'dart:async';

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
  ///
  /// Every provider this needs is read up front, before the first await.
  /// `ref` is tied to this widget's BuildContext, and the moment
  /// `setOrganization` flips the auth state GoRouter redirects away from the
  /// splash and deactivates us — so a `ref.read` after that await throws
  /// "Using ref when a widget is about to or has been unmounted", killing the
  /// rest of boot. That is what stopped calling presence from registering on
  /// a warm start.
  Future<void> _boot() async {
    final authToken = ref.read(authTokenProvider.notifier);
    final userIdState = ref.read(userIdProvider.notifier);
    final user = ref.read(userProvider.notifier);
    final organization = ref.read(organizationProvider.notifier);
    final auth = ref.read(authProvider.notifier);
    final reverb = ref.read(reverbServiceProvider);
    final db = ref.read(appDatabaseProvider);
    final dio = ref.read(dioProvider);

    // Storage first: the widget tree starts issuing authenticated requests
    // (e.g. /user/settings) as soon as it builds, and those 401 unless the
    // stored token is already in the provider. Restoring it before the
    // slower notification setup closes most of that window.
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
      authToken.state = token;
    }

    await NotificationService().initialize().catchError((_) => null);

    // Clear stale CallKit entries left behind by a crash — but ONLY when
    // nothing is currently ringing. A PushKit VoIP push launches the app, so
    // on iOS this code can run while the call that woke us is still ringing;
    // an unconditional endAllCalls() would hang up on the very call we were
    // started to answer.
    await _clearZombieCalls();

    if (userId != null && userId.isNotEmpty) {
      userIdState.state = int.parse(userId);
      user.loadUser(int.parse(userId));

      if (orgId != null && orgId.isNotEmpty) {
        reverb.startFor(
          orgId: orgId,
          database: db,
          userId: int.parse(userId),
        );

        final org = await db.getOrganizationById(int.parse(orgId));
        if (org != null) {
          organization.setOrganization(org, int.parse(userId));
          await auth.setOrganization(org.id);
        }

        // Register the FCM token first, then push it into calling presence.
        // Reading `fcmToken` immediately after firing registration used to
        // return null on a cold boot (iOS especially, where the APNs token
        // lands late), so the agent was stored with no device token and the
        // backend had nothing to wake for an incoming call.
        // NotificationService re-runs this from `onTokenRefresh` too.
        unawaited(
          NotificationService()
              .registerTokenWithBackend(dio)
              .then((_) => NotificationService().registerCallingDevice())
              .catchError((Object e) {
            debugPrint('calling presence registration failed at boot: $e');
          }),
        );
      }
    }

    if (mounted) setState(() => _isBooting = false);
  }

  /// Ends CallKit entries only if none of them is live. `activeCalls()`
  /// returns whatever the native side is currently showing, so a non-empty
  /// list means a real call is in progress or ringing and must be left alone.
  Future<void> _clearZombieCalls() async {
    try {
      final active = await FlutterCallkitIncoming.activeCalls();

      if (active is List && active.isNotEmpty) {
        // ignore: avoid_print
        print('[Calling] boot: ${active.length} live CallKit entry(ies); '
            'leaving them alone');
        return;
      }

      await FlutterCallkitIncoming.endAllCalls();
    } catch (e) {
      // ignore: avoid_print
      print('[Calling] boot: could not inspect CallKit entries: $e');
    }
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
