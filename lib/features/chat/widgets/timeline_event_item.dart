import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:pichat/core/theme/app_colors.dart';
import 'package:pichat/data/models/timeline_event_model.dart';

/// Renders a non-message entry in the conversation: a call, a ticket change or
/// an internal note.
///
/// These sit centred between the message bubbles rather than on either side,
/// because none of them was "said" by the customer or the agent — they are
/// things that happened to the conversation. Calls get the most detail, since
/// answered-versus-missed and how long it ran are what an agent scanning back
/// through a thread actually wants.
class TimelineEventItem extends StatelessWidget {
  const TimelineEventItem({required this.event, super.key});

  final TimelineEvent event;

  @override
  Widget build(BuildContext context) {
    return switch (event.kind) {
      TimelineEventKind.call => _CallEntry(event: event),
      TimelineEventKind.note => _NoteEntry(event: event),
      TimelineEventKind.ticket => _SystemChip(
          icon: _ticketIcon(event.description),
          text: event.description ?? 'Conversation updated',
          time: event.createdAt,
        ),
      TimelineEventKind.unknown => const SizedBox.shrink(),
    };
  }

  /// The server writes these as prose ("Conversation was assigned to …"), so
  /// the icon is picked from the wording. Falls back to a neutral glyph, which
  /// is the right outcome for any phrasing added later.
  static IconData _ticketIcon(String? description) {
    final text = description?.toLowerCase() ?? '';

    if (text.contains('assigned')) return LucideIcons.userCheck;
    if (text.contains('closed')) return LucideIcons.circleCheck;
    if (text.contains('open')) return LucideIcons.circleDot;

    return LucideIcons.info;
  }
}

/// Shared centred pill used by ticket changes.
class _SystemChip extends StatelessWidget {
  const _SystemChip({
    required this.icon,
    required this.text,
    required this.time,
  });

  final IconData icon;
  final String text;
  final DateTime time;

  @override
  Widget build(BuildContext context) {
    final colors = PiColors.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 24),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: colors.surfaceRaised,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: colors.divider),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 13, color: colors.textSecondary),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  text,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 11.5,
                    height: 1.35,
                    color: colors.textSecondary,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Text(
                _clock(time),
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 10.5,
                  color: colors.textSecondary.withValues(alpha: 0.75),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A call, rendered as a card so duration and outcome are readable at a glance.
class _CallEntry extends StatelessWidget {
  const _CallEntry({required this.event});

  final TimelineEvent event;

  @override
  Widget build(BuildContext context) {
    final colors = PiColors.of(context);
    final missed = event.callMissed;
    final inbound = event.isInbound;

    // Missed calls are the ones worth spotting while scrolling, so they are the
    // only entry here that carries colour.
    final accent = missed ? PiPalette.error500 : colors.textSecondary;

    final icon = missed
        ? LucideIcons.phoneMissed
        : (inbound ? LucideIcons.phoneIncoming : LucideIcons.phoneOutgoing);

    final duration = event.formattedDuration;
    final agent = event.agentName;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 24),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          decoration: BoxDecoration(
            color: colors.surfaceRaised,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: missed
                  ? PiPalette.error500.withValues(alpha: 0.35)
                  : colors.divider,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Icon(icon, size: 15, color: accent),
              const SizedBox(width: 8),
              Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _headline(missed: missed, inbound: inbound),
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: missed ? accent : colors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    [
                      _clock(event.createdAt),
                      if (duration != null) duration,
                      if (agent != null) agent,
                    ].join('  ·  '),
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 10.5,
                      color: colors.textSecondary,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _headline({required bool missed, required bool inbound}) {
    if (missed) return inbound ? 'Missed call' : 'No answer';

    return inbound ? 'Incoming call' : 'Outgoing call';
  }
}

/// An internal note. Tinted and labelled so it is never mistaken for something
/// the customer can see.
class _NoteEntry extends StatelessWidget {
  const _NoteEntry({required this.event});

  final TimelineEvent event;

  @override
  Widget build(BuildContext context) {
    final colors = PiColors.of(context);
    final content = event.noteContent;

    if (content == null || content.trim().isEmpty) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 32),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: PiPalette.warning500.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: PiPalette.warning500.withValues(alpha: 0.30),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  LucideIcons.stickyNote,
                  size: 12,
                  color: PiPalette.warning500,
                ),
                const SizedBox(width: 5),
                Text(
                  'Internal note',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    color: PiPalette.warning500,
                  ),
                ),
                const Spacer(),
                Text(
                  _clock(event.createdAt),
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 10.5,
                    color: colors.textSecondary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 5),
            Text(
              content,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 12.5,
                height: 1.4,
                color: colors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String _clock(DateTime time) {
  final hour = time.hour.toString().padLeft(2, '0');
  final minute = time.minute.toString().padLeft(2, '0');

  return '$hour:$minute';
}
