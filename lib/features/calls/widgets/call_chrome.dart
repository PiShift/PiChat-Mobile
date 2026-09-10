import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pichat/features/calls/application/call_controller.dart';
import 'package:pichat/features/calls/widgets/active_call_banner.dart';
import 'package:pichat/features/calls/widgets/incoming_call_queue.dart';

/// The call strip pinned above every route: the call in progress, then
/// anything still ringing beneath it.
///
/// Mounted from `MaterialApp.builder` rather than inside HomeScreen, so a
/// pushed chat thread or media viewer cannot cover it — a call banner that
/// disappears when you open a conversation is useless exactly when it matters.
///
/// It owns the single [SafeArea] for the whole strip. Each piece applying its
/// own would inset the status bar twice when both are visible, leaving the
/// queue floating below a gap.
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
