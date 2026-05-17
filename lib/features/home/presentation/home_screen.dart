// lib/features/main/presentation/main_screen.dart
import 'dart:io';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../../core/services/notification_service.dart';
import '../../../data/db/database_provider.dart';
import '../../../data/models/contact_model.dart';
import '../../chat/application/main_controller.dart';
import '../../chat/widgets/in_app_notification_banner.dart';
import '../../../shared/widgets/pi_bottom_nav.dart';

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
    super.initState();
    requestPermissions();
    // Consume any pending navigation stored by a background notification tap.
    // We defer until after the first frame so GoRouter is ready.
    WidgetsBinding.instance.addPostFrameCallback((_) => _handlePendingNotificationNav());
  }

  Future<void> _handlePendingNotificationNav() async {
    final contactUuid = NotificationService().consumePendingNavigation();
    if (contactUuid == null || !mounted) return;

    // Try the live in-memory list first (fast, no I/O).
    final contacts = ref.read(mainDataProvider);
    Contact? contact;
    try {
      contact = contacts.firstWhere((c) => c.uuid == contactUuid);
    } catch (_) {
      contact = null;
    }

    // Fallback: query the local DB if not in memory yet.
    if (contact == null) {
      final db = ref.read(appDatabaseProvider);
      final row = await (db.select(db.contacts)
            ..where((t) => t.uuid.equals(contactUuid)))
          .getSingleOrNull();
      if (row == null || !mounted) return;
      contact = Contact.fromDb(row);
    }

    if (!mounted) return;
    // Use go() so back always returns to the contacts list.
    context.go('/home/chats/detail', extra: contact);
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
        context.go('/home/groups');
        break;
      case 3:
        context.go('/home/templates');
        break;
      case 4:
        context.go('/home/campaigns');
        break;
      case 5:
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
    final hide = _hideBottomNav;

    return Scaffold(
      body: Stack(
        children: [
          widget.child,
          const InAppNotificationBanner(),
        ],
      ),
      bottomNavigationBar: hide
          ? null
          : PiBottomNavBar(
              currentIndex: _currentIndex,
              onTap: _onTabSelected,
              items: [
                PiNavItem(icon: LucideIcons.messageCircle, label: 'home.nav.chats'.tr()),
                PiNavItem(icon: LucideIcons.phone,          label: 'home.nav.calls'.tr()),
                PiNavItem(icon: LucideIcons.users,          label: 'home.nav.groups'.tr()),
                PiNavItem(icon: LucideIcons.fileText,       label: 'home.nav.templates'.tr()),
                PiNavItem(icon: LucideIcons.megaphone,      label: 'home.nav.campaigns'.tr()),
                PiNavItem(icon: LucideIcons.settings,       label: 'home.nav.settings'.tr()),
              ],
            ),
    );
  }
}
