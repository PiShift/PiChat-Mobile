import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:pichat/core/theme/app_colors.dart';
import 'package:pichat/data/models/chat_log_model.dart';
import 'package:pichat/data/models/chat_model.dart';

/// Who opened a message, and when.
///
/// The business question this answers is accountability: `is_read` is a single
/// org-wide flag, so before this there was no way to tell which agent picked a
/// customer's message up, or how long it sat there. Times are shown to the
/// second because that is the granularity the question is asked at.
///
/// Reached by swiping a bubble sideways, the way WhatsApp's own message info
/// is.
class MessageInfoSheet extends StatelessWidget {
  const MessageInfoSheet({required this.message, super.key});

  final Chat message;

  static Future<void> show(BuildContext context, Chat message) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => MessageInfoSheet(message: message),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = PiColors.of(context);

    final readers = message.logs.where((l) => l.isAgentRead).toList()
      ..sort(_byNewestFirst);

    // Delivery is only meaningful on our own messages: nobody on the team
    // "opens" a message they sent, and for an inbound one the customer's
    // receipts are not ours to show.
    final isOutbound = message.type == 'outbound';
    final delivery = isOutbound
        ? (message.logs.where((l) => !l.isAgentRead).toList()..sort(_byNewestFirst))
        : const <ChatLog>[];

    return DraggableScrollableSheet(
      initialChildSize: 0.45,
      minChildSize: 0.25,
      maxChildSize: 0.85,
      expand: false,
      // Material, not a decorated Container: the rows below are ListTiles,
      // which paint onto the nearest Material ancestor — a coloured box in
      // between would swallow their ink.
      builder: (context, scrollController) => Material(
        color: colors.surfaceRaised,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                margin: const EdgeInsets.symmetric(vertical: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: colors.divider,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Icon(LucideIcons.info, size: 18, color: colors.textSecondary),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'message_info.title'.tr(),
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Flexible(
              child: ListView(
                controller: scrollController,
                padding: const EdgeInsets.only(bottom: 24),
                children: [
                  _Section(label: 'message_info.opened_by'.tr()),
                  if (readers.isEmpty)
                    _Empty(text: 'message_info.nobody_opened'.tr())
                  else
                    ...readers.map((r) => _ReaderRow(log: r)),
                  if (isOutbound) ...[
                    _Section(label: 'message_info.delivery'.tr()),
                    if (delivery.isEmpty)
                      _Empty(text: 'message_info.no_delivery'.tr())
                    else
                      ...delivery.map((d) => _DeliveryRow(log: d)),
                  ],
                  _Section(label: 'message_info.sent'.tr()),
                  _PlainRow(
                    icon: LucideIcons.clock,
                    label: formatStamp(message.createdAt),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Newest first: the most recent open is what an agent is usually checking.
  static int _byNewestFirst(ChatLog a, ChatLog b) {
    final at = a.createdAt;
    final bt = b.createdAt;

    if (at == null && bt == null) return 0;
    if (at == null) return 1;
    if (bt == null) return -1;

    return bt.compareTo(at);
  }
}

/// Second precision is the point of this screen, so it is never trimmed.
String formatStamp(DateTime? at) {
  if (at == null) return '—';

  return DateFormat('d MMM · HH:mm:ss').format(at);
}

class _Section extends StatelessWidget {
  const _Section({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Text(
        label.toUpperCase(),
        style: GoogleFonts.plusJakartaSans(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.6,
          color: PiColors.of(context).textSecondary,
        ),
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
      child: Text(
        text,
        style: GoogleFonts.plusJakartaSans(
          fontSize: 13,
          color: PiColors.of(context).textSecondary,
        ),
      ),
    );
  }
}

class _ReaderRow extends StatelessWidget {
  const _ReaderRow({required this.log});

  final ChatLog log;

  @override
  Widget build(BuildContext context) {
    final colors = PiColors.of(context);
    final name = log.userName ?? 'message_info.unknown_agent'.tr();

    return ListTile(
      dense: true,
      leading: CircleAvatar(
        radius: 16,
        backgroundColor: colors.surface,
        child: Text(
          _initials(name),
          style: GoogleFonts.plusJakartaSans(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: colors.textSecondary,
          ),
        ),
      ),
      title: Text(
        name,
        style: GoogleFonts.plusJakartaSans(
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
      ),
      trailing: Text(
        formatStamp(log.createdAt),
        style: GoogleFonts.plusJakartaSans(
          fontSize: 12,
          color: colors.textSecondary,
        ),
      ),
    );
  }

  static String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty);
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first[0].toUpperCase();

    return '${parts.first[0]}${parts.elementAt(1)[0]}'.toUpperCase();
  }
}

class _DeliveryRow extends StatelessWidget {
  const _DeliveryRow({required this.log});

  final ChatLog log;

  @override
  Widget build(BuildContext context) {
    final status = log.deliveryStatus ?? 'unknown';

    return _PlainRow(
      icon: switch (status) {
        'read' => LucideIcons.checkCheck,
        'delivered' => LucideIcons.checkCheck,
        'sent' => LucideIcons.check,
        'failed' => LucideIcons.circleAlert,
        _ => LucideIcons.circleDashed,
      },
      label: 'message_info.status.$status'.tr(),
      trailing: formatStamp(log.createdAt),
      accent: status == 'read'
          ? PiPalette.info500
          : status == 'failed'
              ? PiPalette.error500
              : null,
    );
  }
}

class _PlainRow extends StatelessWidget {
  const _PlainRow({
    required this.icon,
    required this.label,
    this.trailing,
    this.accent,
  });

  final IconData icon;
  final String label;
  final String? trailing;
  final Color? accent;

  @override
  Widget build(BuildContext context) {
    final colors = PiColors.of(context);
    final color = accent ?? colors.textSecondary;

    return ListTile(
      dense: true,
      leading: Icon(icon, size: 18, color: color),
      title: Text(
        label,
        style: GoogleFonts.plusJakartaSans(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: accent,
        ),
      ),
      trailing: trailing == null
          ? null
          : Text(
              trailing!,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 12,
                color: colors.textSecondary,
              ),
            ),
    );
  }
}
