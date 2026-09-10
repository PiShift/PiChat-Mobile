import 'package:easy_localization/easy_localization.dart';
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
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
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

    return MaterialApp.router(
      debugShowCheckedModeBanner: false,
      title: 'PiChat',
      theme: ref.watch(lightThemeProvider),
      darkTheme: ref.watch(darkThemeProvider),
      themeMode: ref.watch(resolvedThemeModeProvider),
      routerConfig: ref.watch(appRouterProvider),
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
        // Stacked, not inserted into the layout: the chat thread's scroll
        // positioning is sensitive, and reflowing it mid-call would move the
        // reader's place.
        return Stack(
          children: [
            child ?? const SizedBox.shrink(),
            const Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: CallChrome(),
            ),
          ],
        );
      },
    );
  }
}
