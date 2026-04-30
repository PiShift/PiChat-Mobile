// lib/features/main/presentation/main_screen.dart
import 'dart:io';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../../core/theme/app_theme.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key, required this.child});
  final Widget child;

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  int _currentIndex = 0;

  @override
  void initState() {
    requestPermissions();
    super.initState();
  }

  void _onTabSelected(int index) {
    setState(() => _currentIndex = index);
    switch (index) {
      case 0:
        context.go('/home/chats');
        break;
      case 1:
        context.go('/home/calls');
        break;
      case 2:
        context.go('/home/templates');
        break;
      case 3:
        context.go('/home/campaigns');
        break;
      case 4:
        context.go('/home/settings');
        break;
    }
  }

  Future<bool> requestPermissions() async {
    if (Platform.isAndroid) {
      if (await Permission.storage.request().isGranted) {
        return true;
      }
      final photos = await Permission.photos.request();
      final audio = await Permission.audio.request();
      return photos.isGranted && audio.isGranted;
    } else {
      final photos = await Permission.photos.request();
      final audio = await Permission.audio.request();
      return photos.isGranted && audio.isGranted;
    }
  }

  // Determine if the current route is a detail screen (no bottom nav).
  // Inside a ShellRoute, `GoRouterState.of(context).matchedLocation` returns
  // the SHELL's matched location, not the active child's, so we read the
  // current URI from the router itself.
  bool get _hideBottomNav {
    final location = GoRouter.of(context).routeInformationProvider.value.uri.toString();
    return location.contains('/detail') || location.contains('/new');
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final hide = _hideBottomNav;

    return Scaffold(
      body: widget.child,
      bottomNavigationBar: hide
          ? null
          : BottomNavigationBar(
              currentIndex: _currentIndex,
              selectedItemColor: AppColors.primary,
              unselectedItemColor: Colors.grey[500],
              backgroundColor: Colors.white,
              type: BottomNavigationBarType.fixed,
              selectedLabelStyle: TextStyle(fontSize: size.width * 0.028, fontWeight: FontWeight.w600),
              unselectedLabelStyle: TextStyle(fontSize: size.width * 0.027),
              iconSize: size.width * 0.058,
              elevation: 8,
              onTap: _onTabSelected,
              items: [
                BottomNavigationBarItem(
                  icon: const Icon(Icons.chat_bubble_outline),
                  activeIcon: const Icon(Icons.chat_bubble),
                  label: 'home.nav.chats'.tr(),
                ),
                BottomNavigationBarItem(
                  icon: const Icon(Icons.call_outlined),
                  activeIcon: const Icon(Icons.call),
                  label: 'Calls',
                ),
                BottomNavigationBarItem(
                  icon: const Icon(Icons.description_outlined),
                  activeIcon: const Icon(Icons.description),
                  label: 'Templates',
                ),
                BottomNavigationBarItem(
                  icon: const Icon(Icons.campaign_outlined),
                  activeIcon: const Icon(Icons.campaign),
                  label: 'Campaigns',
                ),
                BottomNavigationBarItem(
                  icon: const Icon(Icons.settings_outlined),
                  activeIcon: const Icon(Icons.settings),
                  label: 'home.nav.settings'.tr(),
                ),
              ],
            ),
    );
  }
}
