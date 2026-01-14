// lib/features/main/presentation/main_screen.dart
import 'dart:io';

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
        context.go('/home/settings');
        break;
    }
  }

  Future<bool> requestPermissions() async {
    if (Platform.isAndroid) {
      if (await Permission.storage.request().isGranted) {
        return true;
      }
      // For Android 13+
      final photos = await Permission.photos.request();
      final audio = await Permission.audio.request();
      return photos.isGranted && audio.isGranted;
    } else {
      final photos = await Permission.photos.request();
      final audio = await Permission.audio.request();
      return photos.isGranted && audio.isGranted;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: widget.child,
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        selectedItemColor: AppColors.primary,
        unselectedItemColor: Colors.grey,
        onTap: _onTabSelected,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.chat_bubble_outline),
            label: 'Chats',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings_outlined),
            label: 'Settings',
          ),
        ],
      ),
    );
  }
}
