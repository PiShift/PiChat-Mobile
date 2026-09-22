import 'package:flutter/material.dart';

import 'package:pichat/core/theme/app_colors.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pichat/features/calls/application/call_controller.dart';
import 'package:pichat/features/calls/widgets/active_call_banner.dart';
import 'package:pichat/features/calls/widgets/incoming_call_queue.dart';
import 'package:pichat/features/chat/widgets/voice_mini_player.dart';

/// Places the call strip above the app rather than on top of it.
///
/// Mounted from `MaterialApp.builder` rather than inside HomeScreen, so a
/// pushed chat thread or media viewer cannot cover it — a call banner that
/// disappears when you open a conversation is useless exactly when it matters.
///
/// The strip used to be stacked over the app, which meant it sat on top of
/// whatever was underneath: on the chat list it covered the "Chats" title and
/// its buttons. It now takes its own row and the app is laid out beneath it,
/// the way an ongoing-call bar behaves everywhere else.
///
/// It owns the single [SafeArea] for the whole strip. Each piece applying its
/// own would inset the status bar twice when both are visible, leaving the
/// queue floating below a gap.
class CallChromeScaffold extends ConsumerWidget {
  const CallChromeScaffold({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final showBanner = ActiveCallBanner.shouldShow(ref);
    final showQueue = ref.watch(callQueueProvider).isNotEmpty;
    final showVoice = VoiceMiniPlayer.shouldShow(ref);

    return CallChromeLayout(
      callStrip: (showBanner || showQueue) ? const CallChrome() : null,
      voiceStrip: showVoice
          // The Material sits outside the SafeArea so it paints behind the
          // status bar too; otherwise that inset showed as a black band.
          ? Material(
              color: PiColors.of(context).surfaceRaised,
              child: SafeArea(
                bottom: false,
                // The call strip above has already taken the status bar inset.
                top: !showBanner && !showQueue,
                child: const VoiceMiniPlayer(),
              ),
            )
          : null,
      child: child,
    );
  }
}

/// Lays the app out beneath the strip, without ever changing shape.
///
/// Both slots are always present, empty when there is nothing to show, and the
/// app sits at a fixed position below them. This matters more than it looks:
/// returning a bare child when idle and a wrapped one otherwise moved the
/// Navigator to a different place in the tree whenever a banner appeared or
/// went away. Flutter re-parented it by its GlobalKey and discarded the route
/// state — `state.extra` came back null and opening a conversation bounced
/// straight back to the chat list.
class CallChromeLayout extends StatelessWidget {
  const CallChromeLayout({
    required this.callStrip,
    required this.voiceStrip,
    required this.child,
    super.key,
  });

  /// Null when hidden; the slot stays either way.
  final Widget? callStrip;
  final Widget? voiceStrip;

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final anyStrip = callStrip != null || voiceStrip != null;

    return Column(
      children: [
        callStrip ?? const SizedBox.shrink(),
        voiceStrip ?? const SizedBox.shrink(),
        Expanded(
          key: const ValueKey('app-below-strip'),
          // Always applied so the widget is a fixed part of the tree; only the
          // flag changes. A visible strip has already consumed the status-bar
          // inset, and leaving it in would make the screen below add the same
          // gap a second time.
          child: MediaQuery.removePadding(
            context: context,
            removeTop: anyStrip,
            child: child,
          ),
        ),
      ],
    );
  }
}

/// The strip itself: the call in progress, then anything still ringing.
class CallChrome extends ConsumerWidget {
  const CallChrome({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final showBanner = ActiveCallBanner.shouldShow(ref);
    final showQueue = ref.watch(callQueueProvider).isNotEmpty;

    // Render nothing at all when idle, so no transparent inset sits over the
    // top of the app collecting stray taps.
    if (!showBanner && !showQueue) return const SizedBox.shrink();

    return SafeArea(
      bottom: false,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: const [
          ActiveCallBanner(),
          IncomingCallQueue(),
        ],
      ),
    );
  }
}
