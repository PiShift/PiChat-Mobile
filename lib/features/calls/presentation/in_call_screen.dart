// lib/features/calls/presentation/in_call_screen.dart
//
// Active-call UI. Used for both inbound (after accept) and outbound (after
// dialing connects). Shows the contact, an elapsed timer, mute / speaker
// toggles, and a hangup button. The native CallKit/ConnectionService UI
// remains responsible for showing the call on the lock screen.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../application/call_controller.dart';

class InCallScreen extends ConsumerStatefulWidget {
  const InCallScreen({super.key});

  @override
  ConsumerState<InCallScreen> createState() => _InCallScreenState();
}

class _InCallScreenState extends ConsumerState<InCallScreen> {
  Timer? _timer;
  Duration _elapsed = Duration.zero;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      final accepted = ref.read(callControllerProvider).acceptedAt;
      if (accepted != null) {
        setState(() => _elapsed = DateTime.now().difference(accepted));
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String _fmt(Duration d) {
    String two(int n) => n.toString().padLeft(2, '0');
    final m = two(d.inMinutes.remainder(60));
    final s = two(d.inSeconds.remainder(60));
    final h = d.inHours;
    return h > 0 ? '$h:$m:$s' : '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(callControllerProvider);
    final controller = ref.read(callControllerProvider.notifier);
    final call = state.call;

    // If call ended while screen is open, pop.
    ref.listen<CallState>(callControllerProvider, (_, next) {
      if (next.phase == CallPhase.ended || next.phase == CallPhase.idle) {
        if (mounted && context.canPop()) context.pop();
      }
    });

    final phaseLabel = switch (state.phase) {
      CallPhase.requestingPermission => 'Asking permission…',
      CallPhase.dialing => 'Calling…',
      CallPhase.ringing => 'Incoming call',
      CallPhase.connecting => 'Connecting…',
      CallPhase.inProgress => _fmt(_elapsed),
      CallPhase.ending => 'Ending…',
      CallPhase.ended => 'Call ended',
      _ => '',
    };

    return Scaffold(
      backgroundColor: const Color(0xFF101820),
      body: SafeArea(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const SizedBox(height: 40),
            Column(
              children: [
                CircleAvatar(
                  radius: 60,
                  backgroundColor: AppColors.primary.withOpacity(0.2),
                  child: const Icon(Icons.person, size: 60, color: Colors.white70),
                ),
                const SizedBox(height: 16),
                Text(
                  call?.contactName?.isNotEmpty == true
                      ? call!.contactName!
                      : (call?.fromPhone ?? call?.toPhone ?? 'Unknown'),
                  style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                Text(
                  phaseLabel,
                  style: const TextStyle(color: Colors.white60, fontSize: 14),
                ),
                if (state.error != null) ...[
                  const SizedBox(height: 12),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: Text(
                      state.error!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.redAccent, fontSize: 12),
                    ),
                  ),
                ],
              ],
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: 40),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _CircleAction(
                        icon: controller.signaling.isMuted ? Icons.mic_off : Icons.mic,
                        label: controller.signaling.isMuted ? 'Unmute' : 'Mute',
                        onPressed: () => controller.toggleMute(),
                      ),
                      _CircleAction(
                        icon: controller.signaling.isSpeakerOn ? Icons.volume_up : Icons.hearing,
                        label: 'Speaker',
                        onPressed: () => controller.toggleSpeaker(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),
                  GestureDetector(
                    onTap: () => controller.hangup(),
                    child: Container(
                      width: 70,
                      height: 70,
                      decoration: const BoxDecoration(
                        color: Colors.redAccent,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.call_end, color: Colors.white, size: 32),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CircleAction extends StatelessWidget {
  const _CircleAction({required this.icon, required this.label, required this.onPressed});

  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        InkResponse(
          onTap: onPressed,
          radius: 40,
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withOpacity(0.12),
            ),
            child: Icon(icon, color: Colors.white, size: 24),
          ),
        ),
        const SizedBox(height: 6),
        Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12)),
      ],
    );
  }
}
