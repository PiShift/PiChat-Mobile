import 'package:easy_localization/easy_localization.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart' show defaultTargetPlatform, TargetPlatform;
import 'package:flutter/material.dart';
import 'package:flutter_callkit_incoming/flutter_callkit_incoming.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage_x/flutter_secure_storage_x.dart';
import 'package:pichat/core/network/dio_provider.dart';
import 'package:pichat/core/network/provider_logger.dart';
import 'package:pichat/core/services/notification_service.dart';
import 'package:pichat/firebase_options.dart';
import 'package:pichat/services/reverb_singleton.dart';

import 'core/router/app_router.dart';
import 'core/state/auth_state.dart';
import 'core/theme/app_theme.dart';
import 'data/db/database_provider.dart';
import 'data/repositories/settings_repository.dart';
import 'features/calls/application/call_controller.dart';
import 'features/calls/data/call_api.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await EasyLocalization.ensureInitialized();

  // Initialize Firebase
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Register background message handler - must be done before any Firebase Messaging usage
  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

  // Initialize notification service (requests permission + gets FCM token)
  await NotificationService().initialize();

  // Clear any zombie CallKit entries left over from a previous session.
  // (Old builds could leave malformed quoted-uuid entries that CallKit
  // would keep showing forever and that bring up phantom "second app"
  // tasks when the user taps them.)
  try {
    await FlutterCallkitIncoming.endAllCalls();
  } catch (_) {}

  final container = ProviderContainer(observers: [ProviderLogger()]);
  // final container = ProviderContainer();
  final storage = const FlutterSecureStorage();

  // Bind the container to the notification service so FCM messages received
  // in the foreground can drive the CallController.
  NotificationService().bindContainer(container);

  // load persisted values BEFORE app starts
  final token = await storage.read(key: 'token');
  final orgId = await storage.read(key: 'organization_id');
  final userId = await storage.read(key: 'user_id');

  if (token != null && token.isNotEmpty) {
    container.read(authTokenProvider.notifier).state = token;
  }
  if (userId != null && userId.isNotEmpty) {
    final db = container.read(appDatabaseProvider);
    container.read(userIdProvider.notifier).state = int.parse(userId);
    container.read(userProvider.notifier).loadUser(int.parse(userId));

    if (orgId != null && orgId.isNotEmpty) {
      // Start Reverb connection (subscribes to chats + calls channels).
      final reverbService = container.read(reverbServiceProvider);
      reverbService.init(
        orgId: orgId,
        database: db,
        userId: int.parse(userId),
      );
      reverbService.connect();
      final org = await db.getOrganizationById(int.parse(orgId));
      if(org != null) {
        container.read(organizationProvider.notifier).setOrganization(org, int.parse(userId));
        await container.read(authProvider.notifier).setOrganization(org.id);
      }

      // Register FCM token with backend (user is already logged in)
      final dio = container.read(dioProvider);
      await NotificationService().registerTokenWithBackend(dio);

      // Also register the device with the calling backend so FcmDispatcher
      // can wake this phone for incoming WhatsApp calls. We mark the agent
      // available immediately on app launch — they can flip to offline from
      // the in-app settings.
      final fcmToken = NotificationService().fcmToken;
      try {
        await container.read(callApiProvider).updateAgentStatus(
              status: 'available',
              deviceToken: fcmToken,
              devicePlatform: defaultTargetPlatform == TargetPlatform.iOS ? 'ios' : 'android',
            );
      } catch (e) {
        // Non-fatal: calling features may not be enabled for this org.
        debugPrint('updateAgentStatus failed at boot: $e');
      }
    }
  }

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

class _PiChatAppState extends ConsumerState<PiChatApp> {
  bool _localeSynced = false;

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
      theme: ref.watch(appThemeProvider),
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
        return child ?? const SizedBox.shrink();
      },
    );
  }
}
