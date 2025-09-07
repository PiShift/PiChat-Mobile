// lib/features/settings/presentation/settings_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pichat/core/router/app_router.dart';
import 'package:pichat/features/auth/application/auth_controller.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.read(appRouterProvider);
    return Center(
      child: ElevatedButton(
        onPressed: () async {
          await ref.read(authControllerProvider.notifier).logout();

          // after logout, force navigation to login
          router.go('/login');
        },
        child: const Text("Logout"),
      ),
    );
  }
}

