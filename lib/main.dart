import 'package:easy_localization/easy_localization.dart';
import 'package:go_router/go_router.dart';
import 'package:pichat/features/share/share_intent_service.dart';
import 'package:pichat/services/outbox_service.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:pichat/features/chat/application/local_media_manager.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pichat/core/network/provider_logger.dart';
import 'package:pichat/core/services/notification_service.dart';
import 'package:pichat/features/calls/widgets/call_chrome.dart';
import 'package:pichat/firebase_options.dart';

import 'core/router/app_router.dart';
import 'core/theme/theme_provider.dart';
import 'data/repositories/settings_repository.dart';
import 'features/calls/application/call_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await EasyLocalization.ensureInitialized();

  // Firebase must be initialized before runApp — it's fast and required by
  // FCM and other providers that may be read synchronously on first build.
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Background message handler must be registered before any messaging usage.
  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

  final container = ProviderContainer(observers: [ProviderLogger()]);

  // Bind the container to the notification service so FCM foreground messages
  // can drive the CallController. Does not block the UI.
  NotificationService().bindContainer(container);

  // Everything else (SecureStorage reads, DB queries, Reverb setup, FCM token
  // registration) is deferred to SplashScreen so runApp() fires immediately.
  // Cache the documents directory so stored media paths can be resolved
  // synchronously while widgets build.
  await LocalMediaManager.init();

  runApp(
    EasyLocalization(
      supportedLocales: const [Locale('en'), Locale('ar'), Locale('fr')],
      path: 'assets/lang',
      fallbackLocale: const Locale('en'),
      child: UncontrolledProviderScope(
        container: container,
        child: PiChatApp()
      ),
    ),
  );
}

class PiChatApp extends ConsumerStatefulWidget {
  const PiChatApp({super.key});

  @override
  ConsumerState<PiChatApp> createState() => _PiChatAppState();
}

class _PiChatAppState extends ConsumerState<PiChatApp>
    with WidgetsBindingObserver {
  bool _localeSynced = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Shares from other apps: the one that launched us and any later ones.
    ref.read(shareIntentServiceProvider).start();

    // Pick up sends a previous run left unfinished, once the session is back.
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) ref.read(outboxServiceProvider).sweep();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _watchedRouter?.routerDelegate.removeListener(_openPendingShare);
    super.dispose();
  }

  GoRouter? _watchedRouter;

  /// Follow the current router — it is rebuilt when the session changes —
  /// so a share can be opened as soon as the agent reaches the app proper.
  void _watchRouter(GoRouter router) {
    if (identical(router, _watchedRouter)) return;
    _watchedRouter?.routerDelegate.removeListener(_openPendingShare);
    _watchedRouter = router;
    router.routerDelegate.addListener(_openPendingShare);
  }

  /// Open "Send to…" for a waiting share, but only once signed in and past
  /// the splash, login and organisation screens; until then it waits.
  void _openPendingShare() {
    if (ref.read(pendingShareProvider) == null) return;

    final router = _watchedRouter;
    if (router == null) return;

    final path = router.routerDelegate.currentConfiguration.uri.path;
    if (!path.startsWith('/home')) return;

    router.push('/share');
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) return;

    // Re-assert calling presence whenever the app comes back to the front.
    //
    // Two reasons. iOS registers the PushKit token asynchronously, so on a
    // cold start it can still be missing when presence is first sent — and
    // without it the phone cannot be rung at all while the app is closed.
    // Second, `last_seen_at` is the only signal the backend has that this
    // device is still real; a stale row means calls get dispatched to a
    // device that will never ring.
    NotificationService().registerCallingDevice();

    // Finish sends that were cut off while the app was in the background.
    ref.read(outboxServiceProvider).sweep();
  }

  @override
  Widget build(BuildContext context) {
    // On first load, sync the EasyLocalization locale with whatever the backend has stored.
    // This fixes the case where the cached locale (SharedPreferences) differs from the
    // backend setting (e.g. app was previously set to Arabic but backend shows English).
    if (!_localeSynced) {
      ref.listen<AsyncValue<AppSettings>>(appSettingsProvider, (_, next) {
        if (!_localeSynced) {
          next.whenData((settings) {
            _localeSynced = true;
            final target = Locale(settings.language);
            if (context.locale != target) {
              context.setLocale(target);
            }
          });
        }
      });
    }

    final router = ref.watch(appRouterProvider);
    _watchRouter(router);
    ref.listen<SharedPayload?>(pendingShareProvider, (_, next) {
      if (next != null) _openPendingShare();
    });

    return MaterialApp.router(
      debugShowCheckedModeBanner: false,
      title: 'PiChat',
      theme: ref.watch(lightThemeProvider),
      darkTheme: ref.watch(darkThemeProvider),
      themeMode: ref.watch(resolvedThemeModeProvider),
      routerConfig: router,
      locale: context.locale,
      supportedLocales: context.supportedLocales,
      localizationsDelegates: context.localizationDelegates,
      builder: (context, child) {
        // Stash the navigator-aware context so the CallController can push
        // the in-call screen when the agent accepts from the lock screen.
        WidgetsBinding.instance.addPostFrameCallback((_) {
          ref.read(callRouterContextProvider.notifier).state = context;
        });
        // Call chrome lives here rather than inside HomeScreen so it survives
        // pushed routes — a chat thread or the media viewer would otherwise
        // cover it, and a call banner that disappears when you open a
        // conversation is useless precisely when it is needed.
        //
        // Laid out above the app, not stacked over it: an overlay covered the
        // header of whatever screen was open underneath.
        return CallChromeScaffold(
          child: child ?? const SizedBox.shrink(),
        );
      },
    );
  }
}
