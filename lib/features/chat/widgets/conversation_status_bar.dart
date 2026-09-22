import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:pichat/core/theme/app_colors.dart';
import 'package:pichat/data/models/contact_model.dart';
import 'package:pichat/features/chat/application/message_provider.dart';
import 'package:pichat/features/chat/data/pibot_api.dart';

/// Thin strip under the thread header showing who owns the conversation.
///
/// Both facts were previously invisible in the app: an agent could not tell
/// that a colleague had taken a conversation, nor that the replies going out
/// were being written by the bot. They live here rather than in the header
/// itself because the header is already two lines of contact identity.
///
/// Ownership is one decision, so it is one control: tapping the chip opens the
/// combined assistant-and-agents sheet. It used to be split between a label
/// here, a separate AI pause button, and a buried "assign" menu item.
class ConversationStatusBar extends ConsumerWidget {
  const ConversationStatusBar({
    required this.contact,
    required this.onTap,
    super.key,
  });

  final Contact contact;

  /// Opens the owner picker. Owned by the thread, which already holds the
  /// ticket lookup and the assignment calls.
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = PiColors.of(context);
    final pibot = ref.watch(pibotStateProvider(contact.uuid)).maybeWhen(
      data: (value) => value,
      orElse: () => null,
    );

    // Prefer the database row: assigning the conversation from this screen
    // updates it, while the Contact passed in at open time does not change.
    final live = ref.watch(contactByIdProvider(contact.id)).maybeWhen(
          data: (value) => value,
          orElse: () => null,
        );

    final assignedTo = (live ?? contact).assignedAgentName;
    final showAi = pibot != null && pibot.orgEnabled;

    // Nothing to say: unassigned conversation in an org without the assistant.
    if (assignedTo == null && !showAi) return const SizedBox.shrink();

    // An assigned conversation is owned by that agent. Otherwise the assistant
    // has it, if the org runs one.
    final IconData icon;
    final String label;
    final Color accent;

    if (assignedTo != null) {
      icon = LucideIcons.userCheck;
      label = assignedTo;
      accent = colors.textSecondary;
    } else if (showAi && pibot.active) {
      icon = LucideIcons.sparkles;
      label = pibot.label;
      accent = PiPalette.primary500;
    } else {
      icon = LucideIcons.pause;
      label = pibot?.label ?? 'Unassigned';
      accent = colors.textSecondary;
    }

    return Container(
      color: colors.surfaceRaised,
      padding: const EdgeInsets.fromLTRB(8, 0, 8, 6),
      child: Row(
        children: [
          Flexible(
            child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(icon, size: 12, color: accent),
                    const SizedBox(width: 5),
                    Flexible(
                      child: Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          color: accent,
                        ),
                      ),
                    ),
                    const SizedBox(width: 2),
                    Icon(LucideIcons.chevronDown, size: 12, color: accent),
                  ],
                ),
              ),
            ),
          ),
          const Spacer(),
        ],
      ),
    );
  }
}
