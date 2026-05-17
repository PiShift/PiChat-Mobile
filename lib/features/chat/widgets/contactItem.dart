import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:pichat/core/constants/app_constants.dart';
import 'package:pichat/core/theme/app_colors.dart';
import 'package:pichat/core/theme/app_sizing.dart';
import 'package:pichat/core/theme/app_spacing.dart';
import 'package:pichat/data/models/chat_model.dart';
import 'package:pichat/data/models/contact_model.dart';
import 'package:pichat/shared/widgets/pi_badge.dart';

class ContactItem extends StatelessWidget {
  final Contact contact;

  const ContactItem({super.key, required this.contact});

  @override
  Widget build(BuildContext context) {
    final lastChat = contact.lastChat;
    final name = contact.fullName ?? contact.phone;
    final hasUnread = contact.unreadCount > 0;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: Sz.h(context, 72),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: PiSpacing.space16),
            child: Row(
              children: [
                // ── Avatar ──────────────────────────────────────────────────
                _ContactAvatar(contact: contact, lastChat: lastChat),
                const SizedBox(width: PiSpacing.space12),

                // ── Name + preview ───────────────────────────────────────────
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: Sz.sp(context, 15),
                          fontWeight: hasUnread ? FontWeight.w700 : FontWeight.w600,
                          color: PiColors.of(context).textPrimary,
                          height: 20 / 15,
                        ),
                      ),
                      if (lastChat != null && lastChat.deletedAt == null) ...[
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            if (lastChat.type == 'outbound')
                              Padding(
                                padding: const EdgeInsets.only(right: PiSpacing.space4),
                                child: _StatusTick(status: lastChat.status),
                              ),
                            Expanded(
                              child: _LastMessagePreview(
                                lastChat: lastChat,
                                unread: hasUnread,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),

                const SizedBox(width: PiSpacing.space8),

                // ── Timestamp + badge ────────────────────────────────────────
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    if (lastChat != null)
                      Text(
                        _formatTime(contact.latestChatCreatedAt ?? lastChat.createdAt),
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: Sz.sp(context, 12),
                          fontWeight: hasUnread ? FontWeight.w600 : FontWeight.w400,
                          color: hasUnread ? PiPalette.primary500 : PiPalette.ink400,
                          height: 17 / 12,
                        ),
                      ),
                    if (hasUnread) ...[
                      const SizedBox(height: PiSpacing.space4),
                      PiCountBadge(count: contact.unreadCount),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ),

        // ── Divider (starts at avatar right edge: 16 + 44 + 12 = 72) ────────
        Divider(
          height: 1,
          thickness: 1,
          indent: PiSpacing.space16 + 44 + PiSpacing.space12,
          color: PiColors.of(context).divider,
        ),
      ],
    );
  }

  static String _formatTime(DateTime? time) {
    if (time == null) {
      return '';
    }
    final now = DateTime.now();
    final diff = now.difference(time);

    if (diff.inDays == 0) {
      return DateFormat.Hm('en').format(time);
    } else if (diff.inDays == 1) {
      return 'Yesterday';
    } else if (diff.inDays < 7) {
      return DateFormat.E('en').format(time);
    } else {
      return DateFormat('dd/MM', 'en').format(time);
    }
  }
}

// ─── Avatar subwidget ─────────────────────────────────────────────────────────

class _ContactAvatar extends StatelessWidget {
  final Contact contact;
  final Chat? lastChat;

  const _ContactAvatar({required this.contact, required this.lastChat});

  @override
  Widget build(BuildContext context) {
    final avatarUrl = contact.avatar != null
        ? '${AppConstants.baseUrl}${contact.avatar!}'
        : null;

    final statusColor = _resolveStatusColor(lastChat?.status);
    final showDot = lastChat?.status != null && statusColor != Colors.transparent;

    return SizedBox(
      width: 44,
      height: 44,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Base circle with person icon fallback
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: PiColors.of(context).surface,
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: const Icon(LucideIcons.user, size: 22, color: PiPalette.ink400),
          ),

          // Network image overlay
          if (avatarUrl != null)
            ClipOval(
              child: CachedNetworkImage(
                imageUrl: avatarUrl,
                width: 44,
                height: 44,
                fit: BoxFit.cover,
                placeholder: (_, __) => const SizedBox.shrink(),
                errorWidget: (_, __, ___) => const SizedBox.shrink(),
              ),
            ),

          // Status dot
          if (showDot)
            Positioned(
              bottom: 0,
              right: 0,
              child: Container(
                width: 11,
                height: 11,
                decoration: BoxDecoration(
                  color: statusColor,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: PiColors.of(context).background,
                    width: 1.5,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Color _resolveStatusColor(String? status) {
    return switch (status) {
      'open' => PiPalette.success500,
      'pending' => PiPalette.warning500,
      'closed' => PiPalette.ink400,
      _ => Colors.transparent,
    };
  }
}

// ─── Last message preview ─────────────────────────────────────────────────────

class _LastMessagePreview extends StatelessWidget {
  final Chat lastChat;
  final bool unread;

  const _LastMessagePreview({required this.lastChat, required this.unread});

  @override
  Widget build(BuildContext context) {
    final color = unread ? PiColors.of(context).textPrimary : PiPalette.ink500;
    final weight = unread ? FontWeight.w500 : FontWeight.w400;
    final fontSize = Sz.sp(context, 13);

    try {
      final meta = lastChat.metadata;
      final type = meta?['type'];

      if (type == 'text') {
        final body = meta?['text']?['body'] ?? '';

        return Text(
          body,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: GoogleFonts.plusJakartaSans(
            fontSize: fontSize,
            fontWeight: weight,
            color: color,
            height: 18 / 13,
          ),
        );
      }

      final (icon, label) = _iconAndLabel(type);

      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: fontSize, color: PiPalette.ink500),
          const SizedBox(width: PiSpacing.space4),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.plusJakartaSans(
                fontSize: fontSize,
                fontWeight: weight,
                color: color,
              ),
            ),
          ),
        ],
      );
    } catch (_) {
      return const SizedBox.shrink();
    }
  }

  (IconData, String) _iconAndLabel(String? type) {
    return switch (type) {
      'audio' => (LucideIcons.mic, 'Voice message'),
      'image' => (LucideIcons.image, 'Photo'),
      'document' => (LucideIcons.fileText, 'Document'),
      'video' => (LucideIcons.video, 'Video'),
      'sticker' => (LucideIcons.smile, 'Sticker'),
      _ => (LucideIcons.paperclip, 'Attachment'),
    };
  }
}

// ─── Delivery / read status tick ──────────────────────────────────────────────

class _StatusTick extends StatelessWidget {
  final String? status;

  const _StatusTick({required this.status});

  @override
  Widget build(BuildContext context) {
    return switch (status) {
      'pending' => const Icon(LucideIcons.clock, size: 13, color: PiPalette.ink400),
      'failed' => const Icon(LucideIcons.circleAlert, size: 13, color: PiPalette.error500),
      'read' => const Icon(LucideIcons.checkCheck, size: 13, color: PiPalette.info500),
      'delivered' => const Icon(LucideIcons.checkCheck, size: 13, color: PiPalette.ink400),
      _ => const Icon(LucideIcons.check, size: 13, color: PiPalette.ink400),
    };
  }
}
