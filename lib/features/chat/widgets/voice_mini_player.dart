import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:pichat/core/theme/app_colors.dart';
import 'package:pichat/core/state/auth_state.dart';
import 'package:pichat/features/chat/application/voice_player.dart';

/// The strip that keeps a playing voice note reachable after you leave its
/// conversation.
///
/// Playback outlives the thread it started in, which is what you want when a
/// long note is running and you need to check something else. Without a handle
/// on it, though, audio carries on from a screen with nothing to stop it — so
/// this appears exactly when the bubble is no longer on screen, and disappears
/// again when you return to that conversation.
class VoiceMiniPlayer extends ConsumerWidget {
  const VoiceMiniPlayer({super.key});

  /// Whether the banner belongs on screen right now.
  static bool shouldShow(WidgetRef ref) {
    // Selected, not watched whole. This is read from above the Navigator, so
    // watching the entire playback object rebuilt the whole app several times
    // a second while a note played.
    final loaded =
        ref.watch(voicePlayerProvider.select((v) => v.mediaId != null));

    if (!loaded) return false;

    final owner = ref.watch(voicePlayerProvider.select((v) => v.contactId));

    // Inside its own thread the bubble already shows all of this.
    return ref.watch(activeContactIdProvider) != owner;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!shouldShow(ref)) return const SizedBox.shrink();

    final voice = ref.watch(voicePlayerProvider);
    final player = ref.read(voicePlayerProvider.notifier);

    return VoiceMiniPlayerBar(
      title: voice.contactName ?? 'Voice message',
      position: voice.position,
      total: voice.duration,
      playing: voice.playing,
      onToggle: voice.playing ? player.pause : player.resume,
      onClose: player.stop,
    );
  }
}

/// The bar itself, with no providers involved.
///
/// Split out so it can be rendered in a test under exactly the conditions it
/// runs in: mounted above the Navigator, where there is no [Overlay]. An
/// IconButton's tooltip asserts on one, and the resulting ErrorWidget was what
/// reported itself as a 199618-pixel overflow.
class VoiceMiniPlayerBar extends StatelessWidget {
  const VoiceMiniPlayerBar({
    required this.title,
    required this.position,
    required this.total,
    required this.playing,
    required this.onToggle,
    required this.onClose,
    super.key,
  });

  final String title;
  final Duration position;
  final Duration? total;
  final bool playing;
  final VoidCallback onToggle;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final colors = PiColors.of(context);

    final span = total;
    final progress = (span != null && span.inMilliseconds > 0)
        ? (position.inMilliseconds / span.inMilliseconds).clamp(0.0, 1.0)
        : 0.0;

    return Material(
      color: colors.surfaceRaised,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 8, 6, 8),
            child: Row(
              children: [
                Icon(LucideIcons.mic, size: 16, color: PiPalette.primary500),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: colors.textPrimary,
                        ),
                      ),
                      Text(
                        _elapsed(position, total),
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 11,
                          color: colors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                // Plain tap targets rather than IconButton: no Overlay here.
                _BannerButton(
                  onTap: onToggle,
                  icon: playing ? LucideIcons.pause : LucideIcons.play,
                  color: PiPalette.primary500,
                  semanticLabel: playing ? 'Pause' : 'Play',
                ),
                _BannerButton(
                  onTap: onClose,
                  icon: LucideIcons.x,
                  color: colors.textSecondary,
                  semanticLabel: 'Close player',
                ),
              ],
            ),
          ),
          LinearProgressIndicator(
            value: progress,
            minHeight: 2,
            color: PiPalette.primary500,
            backgroundColor: colors.divider,
          ),
        ],
      ),
    );
  }

  static String _elapsed(Duration position, Duration? total) {
    String fmt(Duration d) {
      final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
      final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');

      return '$m:$s';
    }

    return total == null ? fmt(position) : '${fmt(position)} / ${fmt(total)}';
  }
}

class _BannerButton extends StatelessWidget {
  const _BannerButton({
    required this.onTap,
    required this.icon,
    required this.color,
    required this.semanticLabel,
  });

  final VoidCallback onTap;
  final IconData icon;
  final Color color;
  final String semanticLabel;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: semanticLabel,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: SizedBox(
          width: 42,
          height: 38,
          child: Center(child: Icon(icon, size: 19, color: color)),
        ),
      ),
    );
  }
}
