import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:pichat/core/theme/app_colors.dart';
import 'package:pichat/features/calls/application/call_controller.dart';
import 'package:pichat/features/calls/data/call_models.dart';

/// Calls ringing right now that this agent could still take.
///
/// This is a busy-agent surface. A free agent's first call is rung by CallKit,
/// full screen and unmissable, so anything shown in-app for that case would be
/// noise. What lands here are the calls that arrived while they were already
/// talking — the ones that used to be marked missed the moment they arrived.
///
/// Collapsed by default and never modal: the agent is mid-conversation, taps
/// must reach the screen underneath, and the strip has to be small enough to
/// live with for the twenty-odd seconds Meta keeps a call ringing. Declining is
/// the way out — it is per-agent, so it clears the row here while colleagues
/// keep ringing.
class IncomingCallQueue extends ConsumerStatefulWidget {
  const IncomingCallQueue({super.key});

  @override
  ConsumerState<IncomingCallQueue> createState() => _IncomingCallQueueState();
}

class _IncomingCallQueueState extends ConsumerState<IncomingCallQueue> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final queue = ref.watch(callQueueProvider);

    if (queue.isEmpty) return const SizedBox.shrink();

    // One call needs no list — show it as a single actionable row.
    final showList = _expanded || queue.length == 1;

    return Material(
      color: PiPalette.primary500,
      // SafeArea belongs to CallChrome, which owns the whole strip.
      child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!showList) _summary(queue.length),
            if (showList)
              ConstrainedBox(
                // Caps at roughly three rows; more than that scrolls rather
                // than swallowing the screen.
                constraints: const BoxConstraints(maxHeight: 186),
                child: ListView.builder(
                  shrinkWrap: true,
                  padding: EdgeInsets.zero,
                  itemCount: queue.length,
                  itemBuilder: (_, i) => _QueuedCallRow(call: queue[i]),
                ),
              ),
            if (showList && queue.length > 1)
              InkWell(
                onTap: () => setState(() => _expanded = false),
                child: SizedBox(
                  height: 22,
                  child: Center(
                    child: Icon(
                      LucideIcons.chevronUp,
                      size: 14,
                      color: Colors.white.withValues(alpha: 0.9),
                    ),
                  ),
                ),
              ),
          ],
      ),
    );
  }

  Widget _summary(int count) {
    return InkWell(
      onTap: () => setState(() => _expanded = true),
      child: SizedBox(
        height: 40,
        child: Row(
          children: [
            const SizedBox(width: 12),
            const Icon(LucideIcons.phoneIncoming, size: 14, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                '$count incoming calls',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ),
            Text(
              'Tap to view',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 11,
                color: Colors.white.withValues(alpha: 0.85),
              ),
            ),
            const SizedBox(width: 12),
          ],
        ),
      ),
    );
  }
}

class _QueuedCallRow extends ConsumerWidget {
  const _QueuedCallRow({required this.call});

  final CallModel call;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(callControllerProvider.notifier);

    // Accepting while already talking necessarily ends the current call —
    // Meta has no hold — so the button says so.
    final busy = ref.watch(callControllerProvider).call != null;

    final name = call.contactName?.isNotEmpty == true
        ? call.contactName!
        : (call.fromPhone ?? 'Unknown');

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 6, 8, 6),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                if (call.fromPhone != null && call.contactName?.isNotEmpty == true)
                  Text(
                    call.fromPhone!,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 11,
                      color: Colors.white.withValues(alpha: 0.85),
                    ),
                  ),
              ],
            ),
          ),
          _Action(
            label: 'Decline',
            background: Colors.white.withValues(alpha: 0.18),
            onTap: () => controller.declineQueued(call),
          ),
          const SizedBox(width: 6),
          _Action(
            label: busy ? 'End & Accept' : 'Accept',
            background: PiPalette.success500,
            onTap: () => controller.acceptQueued(call),
          ),
        ],
      ),
    );
  }
}

class _Action extends StatelessWidget {
  const _Action({
    required this.label,
    required this.background,
    required this.onTap,
  });

  final String label;
  final Color background;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: background,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          child: Text(
            label,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
        ),
      ),
    );
  }
}
