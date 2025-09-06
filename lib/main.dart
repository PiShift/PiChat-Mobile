import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage_x/flutter_secure_storage_x.dart';

import 'core/router/app_router.dart';
import 'core/state/auth_state.dart';
import 'core/theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await EasyLocalization.ensureInitialized();

  final container = ProviderContainer();
  final storage = const FlutterSecureStorage();

  // load persisted values BEFORE app starts
  final token = await storage.read(key: 'token');
  final org = await storage.read(key: 'organization_id');

  if (token != null && token.isNotEmpty) {
    container.read(authTokenProvider.notifier).state = token;
  }
  if (org != null && org.isNotEmpty) {
    container.read(organizationProvider.notifier).state = int.tryParse(org);
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

class PiChatApp extends ConsumerWidget {
  const PiChatApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp.router(
      debugShowCheckedModeBanner: false,
      title: 'PiChat',
      theme: ref.watch(appThemeProvider),
      routerConfig: ref.watch(appRouterProvider),
      locale: context.locale,
      supportedLocales: context.supportedLocales,
      localizationsDelegates: context.localizationDelegates,
    );
  }
}
