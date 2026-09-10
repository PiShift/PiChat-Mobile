import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:pichat/core/router/app_router.dart';
import 'package:pichat/core/theme/app_colors.dart';
import 'package:pichat/features/calls/application/call_controller.dart';

/// Slim bar shown while a call is running and its screen is minimised.
///
/// Minimising is what makes a call usable for an agent: they can read the
/// customer's history, check an order, or take a note without hanging up. The
/// bar keeps the call one tap away and, unlike the iOS system pill, names who
/// is on the line.
///
/// It floats over the top of whatever screen is showing rather than being
/// inserted into it — the chat thread's scroll positioning is sensitive, and
/// reflowing it mid-call would jump the reader's place.
class ActiveCallBanner extends ConsumerStatefulWidget {
  const ActiveCallBanner({super.key});

  /// Whether the banner has anything to show. Read by [CallChrome] so the
  /// whole strip — and its SafeArea — can be left out when idle.
  static bool shouldShow(WidgetRef ref) {
    final state = ref.watch(callControllerProvider);

    return ref.watch(callMinimisedProvider) &&
        const {
          CallPhase.connecting,
          CallPhase.inProgress,
          CallPhase.dialing,
        }.contains(state.phase);
  }

  @override
  ConsumerState<ActiveCallBanner> createState() => _ActiveCallBannerState();
}

class _ActiveCallBannerState extends ConsumerState<ActiveCallBanner> {
  Timer? _ticker;
  Duration _elapsed = Duration.zero;

  @override
  void initState() {
    super.initState();

    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      final acceptedAt = ref.read(callControllerProvider).acceptedAt;

      if (acceptedAt == null || !mounted) return;

      setState(() => _elapsed = DateTime.now().difference(acceptedAt));
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  String _clock(Duration d) {
    final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');

    return d.inHours > 0 ? '${d.inHours}:$minutes:$seconds' : '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    if (!ActiveCallBanner.shouldShow(ref)) return const SizedBox.shrink();

    final state = ref.watch(callControllerProvider);

    final call = state.call;
    final name = call?.contactName?.isNotEmpty == true
        ? call!.contactName!
        : (call?.fromPhone ?? call?.toPhone ?? 'Unknown');

    final label = state.phase == CallPhase.inProgress
        ? _clock(_elapsed)
        : (state.phase == CallPhase.dialing ? 'Calling…' : 'Connecting…');

    return Material(
      color: PiPalette.success500,
      child: InkWell(
        onTap: () {
          ref.read(callMinimisedProvider.notifier).state = false;
          ref.read(appRouterProvider).push('/call');
        },
        // SafeArea belongs to CallChrome, which owns the whole strip.
        child: SizedBox(
            height: 34,
            child: Row(
              children: [
                const SizedBox(width: 12),
                const Icon(LucideIcons.phone, size: 13, color: Colors.white),
                const SizedBox(width: 7),
                Expanded(
                  child: Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
                Text(
                  label,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  'Tap to return',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 11,
                    color: Colors.white.withValues(alpha: 0.85),
                  ),
                ),
                const SizedBox(width: 12),
              ],
            ),
          ),
      ),
    );
  }
}
