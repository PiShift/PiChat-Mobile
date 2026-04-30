// lib/features/settings/presentation/settings_screen.dart
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pichat/core/router/app_router.dart';
import 'package:pichat/core/theme/app_theme.dart';
import 'package:pichat/data/repositories/settings_repository.dart';
import 'package:pichat/features/auth/application/auth_controller.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  bool _isLoggingOut = false;

  @override
  Widget build(BuildContext context) {
    final router = ref.read(appRouterProvider);
    final profileAsync = ref.watch(userProfileProvider);
    final settingsAsync = ref.watch(appSettingsProvider);
    final size = MediaQuery.sizeOf(context);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        title: Text('settings.title'.tr(), style: TextStyle(fontSize: size.width * 0.045, fontWeight: FontWeight.bold, color: AppColors.textDark)),
      ),
      body: ListView(
        children: [
          // Profile section
          profileAsync.when(
            loading: () => _buildProfileSkeleton(),
            error: (_, __) => _buildProfileError(),
            data: (profile) => _buildProfileSection(profile),
          ),

          Divider(height: 1, color: Colors.grey[200]),

          // Settings sections
          settingsAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (_, __) => const SizedBox.shrink(),
            data: (settings) => Column(
              children: [
                // Notifications
                _buildSection(
                  title: 'settings.section.notifications'.tr(),
                  icon: Icons.notifications_outlined,
                  children: [
                    _buildSwitchTile(
                      title: 'settings.notifications.push_title'.tr(),
                      subtitle: 'settings.notifications.push_subtitle'.tr(),
                      value: settings.notificationsEnabled,
                      onChanged: (v) => _updateSetting('notifications_enabled', v),
                    ),
                    _buildSwitchTile(
                      title: 'settings.notifications.sound_title'.tr(),
                      subtitle: 'settings.notifications.sound_subtitle'.tr(),
                      value: settings.soundEnabled,
                      onChanged: (v) => _updateSetting('notification_sound', v),
                    ),
                  ],
                ),

                Divider(height: 1, color: Colors.grey[200]),

                // Chat settings
                _buildSection(
                  title: 'settings.section.chat'.tr(),
                  icon: Icons.chat_outlined,
                  children: [
                    _buildSwitchTile(
                      title: 'settings.chat.enter_to_send_title'.tr(),
                      subtitle: 'settings.chat.enter_to_send_subtitle'.tr(),
                      value: settings.enterToSend,
                      onChanged: (v) => _updateSetting('enter_to_send', v),
                    ),
                  ],
                ),

                Divider(height: 1, color: Colors.grey[200]),

                // Appearance
                _buildSection(
                  title: 'settings.section.appearance'.tr(),
                  icon: Icons.palette_outlined,
                  children: [
                    _buildOptionTile(
                      title: 'settings.appearance.theme'.tr(),
                      subtitle: settings.theme.capitalize(),
                      onTap: () => _showThemeOptions(settings.theme),
                    ),
                    _buildOptionTile(
                      title: 'settings.appearance.language'.tr(),
                      subtitle: _getLanguageLabel(settings.language),
                      onTap: () => _showLanguageOptions(settings.language),
                    ),
                  ],
                ),

                Divider(height: 1, color: Colors.grey[200]),

                // Account
                _buildSection(
                  title: 'settings.section.account'.tr(),
                  icon: Icons.person_outline,
                  children: [
                    _buildOptionTile(
                      title: 'settings.account.change_password'.tr(),
                      onTap: () => _showChangePasswordDialog(),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Logout button
          Padding(
            padding: EdgeInsets.symmetric(horizontal: size.width * 0.04, vertical: size.height * 0.01),
            child: SizedBox(
              width: double.infinity,
              child: TextButton(
                style: TextButton.styleFrom(
                  foregroundColor: Colors.red[400],
                  padding: EdgeInsets.symmetric(vertical: size.height * 0.014),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  backgroundColor: Colors.red.shade50,
                ),
                onPressed: _isLoggingOut ? null : () => _logout(router),
                child: _isLoggingOut
                    ? SizedBox(width: size.width * 0.04, height: size.width * 0.04, child: const CircularProgressIndicator(strokeWidth: 2))
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.logout_outlined, size: size.width * 0.04),
                          SizedBox(width: size.width * 0.02),
                          Text('settings.logout_button'.tr(), style: TextStyle(fontSize: size.width * 0.034, fontWeight: FontWeight.w500)),
                        ],
                      ),
              ),
            ),
          ),

          // App version
          Padding(
            padding: EdgeInsets.only(bottom: size.height * 0.04),
            child: Center(
              child: Text('settings.version'.tr(namedArgs: {'version': '1.0.0'}), style: TextStyle(color: Colors.grey[400], fontSize: size.width * 0.028)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileSection(UserProfile profile) {
    final size = MediaQuery.sizeOf(context);
    final avatarRadius = size.width * 0.1;
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: size.width * 0.04, vertical: size.height * 0.016),
      child: Row(
        children: [
          CircleAvatar(
            radius: avatarRadius,
            backgroundColor: Colors.grey[100],
            backgroundImage: profile.avatar != null ? NetworkImage(profile.avatar!) : null,
            child: profile.avatar == null
                ? Text(
                    _getInitials(profile.fullName),
                    style: TextStyle(fontSize: avatarRadius * 0.7, fontWeight: FontWeight.w600, color: AppColors.primary),
                  )
                : null,
          ),
          SizedBox(width: size.width * 0.04),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(profile.fullName, style: TextStyle(fontSize: size.width * 0.038, fontWeight: FontWeight.w600, color: AppColors.textDark)),
                SizedBox(height: size.height * 0.003),
                Text(profile.email, style: TextStyle(fontSize: size.width * 0.031, color: Colors.grey[500])),
                SizedBox(height: size.height * 0.004),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: size.width * 0.018, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    profile.role.toUpperCase(),
                    style: TextStyle(fontSize: size.width * 0.024, color: Colors.grey[600], fontWeight: FontWeight.w600, letterSpacing: 0.5),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileSkeleton() {
    final size = MediaQuery.sizeOf(context);
    final avatarSize = size.width * 0.2;
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: size.width * 0.04, vertical: size.height * 0.016),
      child: Row(
        children: [
          Container(width: avatarSize, height: avatarSize, decoration: BoxDecoration(color: Colors.grey[200], shape: BoxShape.circle)),
          SizedBox(width: size.width * 0.04),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(width: size.width * 0.3, height: size.width * 0.034, color: Colors.grey[200]),
                SizedBox(height: size.height * 0.006),
                Container(width: size.width * 0.45, height: size.width * 0.028, color: Colors.grey[200]),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileError() {
    final size = MediaQuery.sizeOf(context);
    final avatarSize = size.width * 0.2;
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: size.width * 0.04, vertical: size.height * 0.016),
      child: Row(
        children: [
          Container(
            width: avatarSize, height: avatarSize,
            decoration: BoxDecoration(color: Colors.grey[100], shape: BoxShape.circle),
            child: Icon(Icons.error_outline, color: Colors.grey[400], size: size.width * 0.06),
          ),
          SizedBox(width: size.width * 0.04),
          Text('settings.error.load_profile'.tr(), style: TextStyle(fontSize: size.width * 0.032, color: Colors.grey[500])),
        ],
      ),
    );
  }

  Widget _buildSection({required String title, required IconData icon, required List<Widget> children}) {
    final size = MediaQuery.sizeOf(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(size.width * 0.04, size.height * 0.014, size.width * 0.04, size.height * 0.004),
          child: Row(
            children: [
              Icon(icon, size: size.width * 0.038, color: Colors.grey[500]),
              SizedBox(width: size.width * 0.02),
              Text(title, style: TextStyle(fontSize: size.width * 0.03, fontWeight: FontWeight.w600, color: Colors.grey[500], letterSpacing: 0.3)),
            ],
          ),
        ),
        ...children,
      ],
    );
  }

  Widget _buildSwitchTile({required String title, String? subtitle, required bool value, required ValueChanged<bool> onChanged}) {
    final size = MediaQuery.sizeOf(context);
    return SwitchListTile(
      title: Text(title, style: TextStyle(fontSize: size.width * 0.034, color: AppColors.textDark)),
      subtitle: subtitle != null ? Text(subtitle, style: TextStyle(color: Colors.grey[500], fontSize: size.width * 0.028)) : null,
      value: value,
      onChanged: onChanged,
      activeThumbColor: AppColors.primary,
      dense: true,
      contentPadding: EdgeInsets.symmetric(horizontal: size.width * 0.04),
    );
  }

  Widget _buildOptionTile({required String title, String? subtitle, required VoidCallback onTap}) {
    final size = MediaQuery.sizeOf(context);
    return ListTile(
      title: Text(title, style: TextStyle(fontSize: size.width * 0.034, color: AppColors.textDark)),
      subtitle: subtitle != null ? Text(subtitle, style: TextStyle(color: Colors.grey[500], fontSize: size.width * 0.028)) : null,
      trailing: Icon(Icons.chevron_right, size: size.width * 0.045, color: Colors.grey[400]),
      dense: true,
      contentPadding: EdgeInsets.symmetric(horizontal: size.width * 0.04),
      onTap: onTap,
    );
  }

  String _getInitials(String name) {
    if (name.isEmpty) return '?';
    final parts = name.trim().split(' ');
    if (parts.length >= 2) return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    return name[0].toUpperCase();
  }

  String _getLanguageLabel(String code) {
    switch (code) {
      case 'en': return 'English';
      case 'fr': return 'Français';
      case 'ar': return 'العربية';
      default: return code;
    }
  }

  Future<void> _updateSetting(String key, dynamic value) async {
    try {
      final repo = ref.read(settingsRepositoryProvider);
      await repo.updateSettings({key: value});
      ref.invalidate(appSettingsProvider);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('settings.snackbar.failed_to_update'.tr(namedArgs: {'error': e.toString()})), backgroundColor: Colors.red));
      }
    }
  }

  void _showThemeOptions(String current) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final theme in ['light', 'dark', 'system'])
              ListTile(
                title: Text(theme.capitalize()),
                trailing: current == theme ? const Icon(Icons.check, color: AppColors.primary) : null,
                onTap: () {
                  Navigator.pop(ctx);
                  _updateSetting('theme', theme);
                },
              ),
          ],
        ),
      ),
    );
  }

  void _showLanguageOptions(String current) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final lang in [('en', 'English'), ('fr', 'Français'), ('ar', 'العربية')])
              ListTile(
                title: Text(lang.$2),
                trailing: current == lang.$1 ? const Icon(Icons.check, color: AppColors.primary) : null,
                onTap: () async {
                  Navigator.pop(ctx);
                  await _updateSetting('language', lang.$1);
                  // Apply the locale change immediately
                  if (mounted) {
                    // ignore: use_build_context_synchronously
                    await context.setLocale(Locale(lang.$1));
                  }
                },
              ),
          ],
        ),
      ),
    );
  }

  void _showChangePasswordDialog() {
    final currentController = TextEditingController();
    final newController = TextEditingController();
    final confirmController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('settings.account.change_password'.tr()),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: currentController, obscureText: true, decoration: InputDecoration(labelText: 'settings.password.current_label'.tr())),
            const SizedBox(height: 12),
            TextField(controller: newController, obscureText: true, decoration: InputDecoration(labelText: 'settings.password.new_label'.tr())),
            const SizedBox(height: 12),
            TextField(controller: confirmController, obscureText: true, decoration: InputDecoration(labelText: 'settings.password.confirm_label'.tr())),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text('common.cancel'.tr())),
          ElevatedButton(
            onPressed: () async {
              try {
                final repo = ref.read(settingsRepositoryProvider);
                await repo.changePassword(
                  currentPassword: currentController.text,
                  newPassword: newController.text,
                  confirmPassword: confirmController.text,
                );
                if (mounted) {
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('settings.snackbar.password_changed'.tr()), backgroundColor: Colors.green));
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('settings.snackbar.failed_to_update'.tr(namedArgs: {'error': e.toString()})), backgroundColor: Colors.red));
                }
              }
            },
            child: Text('settings.password.change_button'.tr()),
          ),
        ],
      ),
    );
  }

  Future<void> _logout(dynamic router) async {
    setState(() => _isLoggingOut = true);
    try {
      await ref.read(authControllerProvider.notifier).logout();
      router.go('/login');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('settings.snackbar.logout_failed'.tr(namedArgs: {'error': e.toString()})), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _isLoggingOut = false);
    }
  }
}

extension StringCapExtension on String {
  String capitalize() {
    if (isEmpty) return this;
    return '${this[0].toUpperCase()}${substring(1)}';
  }
}

