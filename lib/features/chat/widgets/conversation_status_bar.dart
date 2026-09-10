import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:pichat/core/theme/app_colors.dart';
import 'package:pichat/data/models/contact_model.dart';
import 'package:pichat/features/chat/application/message_provider.dart';
import 'package:pichat/features/chat/data/pibot_api.dart';

/// Thin strip under the thread header showing who owns the conversation and
/// whether the AI assistant is answering it.
///
/// Both facts were previously invisible in the app: an agent could not tell
/// that a colleague had taken a conversation, nor that the replies going out
/// were being written by the bot. They live here rather than in the header
/// itself because the header is already two lines of contact identity, and
/// because the AI state needs a control next to it.
class ConversationStatusBar extends ConsumerWidget {
  const ConversationStatusBar({required this.contact, super.key});

  final Contact contact;

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

    return Container(
      color: colors.surfaceRaised,
      padding: const EdgeInsets.fromLTRB(12, 0, 8, 6),
      child: Row(
        children: [
          if (assignedTo != null) ...[
            Icon(LucideIcons.userCheck, size: 12, color: colors.textSecondary),
            const SizedBox(width: 5),
            Flexible(
              child: Text(
                assignedTo,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  color: colors.textSecondary,
                ),
              ),
            ),
          ] else
            Text(
              'Unassigned',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 11.5,
                color: colors.textSecondary,
              ),
            ),
          const Spacer(),
          if (showAi) _AiControl(contact: contact, state: pibot),
        ],
      ),
    );
  }
}

class _AiControl extends ConsumerStatefulWidget {
  const _AiControl({required this.contact, required this.state});

  final Contact contact;
  final PibotState state;

  @override
  ConsumerState<_AiControl> createState() => _AiControlState();
}

class _AiControlState extends ConsumerState<_AiControl> {
  bool _busy = false;

  Future<void> _toggle() async {
    if (_busy) return;

    setState(() => _busy = true);

    final api = ref.read(pibotApiProvider);
    final uuid = widget.contact.uuid;

    try {
      // Resume only makes sense when the pause was an explicit handoff. If the
      // bot is quiet because the ticket is assigned, resuming the session alone
      // would not bring it back — PibotService still sees a human on the
      // ticket — so say that instead of silently doing nothing.
      if (widget.state.active) {
        await api.pause(uuid);
      } else if (widget.state.reason == PibotInactiveReason.takenByAgent) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Close or unassign this conversation to let the AI reply again.',
              ),
            ),
          );
        }

        return;
      } else {
        await api.resume(uuid);
      }

      ref.invalidate(pibotStateProvider(uuid));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not change AI state: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = PiColors.of(context);
    final active = widget.state.active;

    final accent = active ? PiPalette.primary500 : colors.textSecondary;

    return InkWell(
      onTap: _toggle,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_busy)
              SizedBox(
                width: 12,
                height: 12,
                child: CircularProgressIndicator(strokeWidth: 1.6, color: accent),
              )
            else
              Icon(
                active ? LucideIcons.sparkles : LucideIcons.pause,
                size: 12,
                color: accent,
              ),
            const SizedBox(width: 5),
            Text(
              widget.state.label,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                color: accent,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
