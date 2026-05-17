import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pichat/core/state/auth_state.dart';
import 'package:pichat/core/theme/app_colors.dart';
import 'package:pichat/core/theme/app_theme.dart';
import 'package:pichat/data/db/database_provider.dart';
import 'package:pichat/data/models/contact_model.dart';

/// Displays a WhatsApp-style in-app notification banner at the top of the screen
/// when a message arrives from a contact whose thread is NOT currently open.
///
/// Place this widget inside a [Stack] that covers the whole screen, typically
/// in [HomeScreen]'s build method. It listens to [inAppNotificationProvider]
/// and auto-dismisses after 4 seconds.
class InAppNotificationBanner extends ConsumerStatefulWidget {
  const InAppNotificationBanner({super.key});

  @override
  ConsumerState<InAppNotificationBanner> createState() => _InAppNotificationBannerState();
}

class _InAppNotificationBannerState extends ConsumerState<InAppNotificationBanner>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animController;
  late final Animation<Offset> _slideAnim;
  Timer? _dismissTimer;
  InAppNotification? _current;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, -1),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _animController, curve: Curves.easeOut));
  }

  @override
  void dispose() {
    _dismissTimer?.cancel();
    _animController.dispose();
    super.dispose();
  }

  void _show(InAppNotification notification) {
    _dismissTimer?.cancel();
    setState(() => _current = notification);
    _animController.forward(from: 0);
    _dismissTimer = Timer(const Duration(seconds: 4), _dismiss);
  }

  void _dismiss() {
    _animController.reverse().then((_) {
      if (mounted) {
        setState(() => _current = null);
        // Clear the provider so a re-trigger is possible.
        ref.read(inAppNotificationProvider.notifier).state = null;
      }
    });
  }

  Future<Contact?> _loadContact(int contactId) async {
    final db = ref.read(appDatabaseProvider);
    final row = await (db.select(db.contacts)..where((t) => t.id.equals(contactId)))
        .getSingleOrNull();
    return row != null ? Contact.fromDb(row) : null;
  }

  @override
  Widget build(BuildContext context) {
    // Listen for new notifications.
    ref.listen<InAppNotification?>(inAppNotificationProvider, (prev, next) {
      if (next != null) _show(next);
    });

    if (_current == null) return const SizedBox.shrink();

    final notification = _current!;

    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: SlideTransition(
        position: _slideAnim,
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Material(
              elevation: 6,
              borderRadius: BorderRadius.circular(14),
              color: PiColors.of(context).surfaceRaised,
              child: InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: () async {
                  _dismiss();
                  final contact = await _loadContact(notification.contactId);
                  if (contact != null && context.mounted) {
                    // Use go() instead of push() so the back button returns to
                    // the contacts list rather than the previously open chat.
                    context.go('/home/chats/detail', extra: contact);
                  }
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 22,
                        backgroundColor: AppColors.primary.withOpacity(0.15),
                        child: Text(
                          (notification.contactName.isNotEmpty
                              ? notification.contactName[0]
                              : '?'),
                          style: TextStyle(
                            color: AppColors.primary,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              notification.contactName,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 14,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              notification.body,
                              style: TextStyle(
                                color: PiColors.of(context).textSecondary,
                                fontSize: 13,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: Icon(Icons.close, size: 18, color: PiColors.of(context).textSecondary),
                        onPressed: _dismiss,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
