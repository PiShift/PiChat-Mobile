// lib/features/calls/presentation/outbound_call_screen.dart
//
// Shown after the agent taps the call button on a contact. The screen
// observes the CallController; when the controller flips to `inProgress`
// the in-call UI takes over (push /call from the controller).
//
// This screen primarily covers the "requesting permission" + "dialing"
// states.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../application/call_controller.dart';

class OutboundCallScreen extends ConsumerStatefulWidget {
  const OutboundCallScreen({
    super.key,
    required this.contactUuid,
    required this.contactName,
    required this.contactPhone,
  });

  final String contactUuid;
  final String contactName;
  final String contactPhone;

  @override
  ConsumerState<OutboundCallScreen> createState() => _OutboundCallScreenState();
}

class _OutboundCallScreenState extends ConsumerState<OutboundCallScreen> {
  @override
  void initState() {
    super.initState();
    // Kick off the call once the screen is mounted.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(callControllerProvider.notifier).startOutbound(
            contactUuid: widget.contactUuid,
            contactName: widget.contactName,
            contactPhone: widget.contactPhone,
          );
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(callControllerProvider);

    // When call connects, jump to the in-call screen.
    ref.listen<CallState>(callControllerProvider, (_, next) {
      if (next.phase == CallPhase.inProgress) {
        if (mounted) context.pushReplacement('/call');
      } else if (next.phase == CallPhase.ended || next.phase == CallPhase.idle) {
        if (mounted && context.canPop()) context.pop();
      }
    });

    final phaseLabel = switch (state.phase) {
      CallPhase.requestingPermission =>
        'Requesting permission… The customer must accept the call request in WhatsApp first.',
      CallPhase.dialing => 'Calling ${widget.contactName}…',
      CallPhase.connecting => 'Connecting…',
      _ => 'Preparing call…',
    };

    return Scaffold(
      backgroundColor: const Color(0xFF101820),
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                Column(
                  children: [
                    CircleAvatar(
                      radius: 60,
                      backgroundColor: Colors.white.withOpacity(0.1),
                      child: const Icon(Icons.person, size: 60, color: Colors.white70),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      widget.contactName.isEmpty ? widget.contactPhone : widget.contactName,
                      style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 8),
                    Text(widget.contactPhone, style: const TextStyle(color: Colors.white54)),
                  ],
                ),
                Column(
                  children: [
                    const CircularProgressIndicator(color: Colors.white24),
                    const SizedBox(height: 16),
                    Text(
                      phaseLabel,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.white70),
                    ),
                    if (state.error != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        state.error!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.redAccent, fontSize: 12),
                      ),
                    ],
                  ],
                ),
                GestureDetector(
                  onTap: () => ref.read(callControllerProvider.notifier).hangup(),
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
        ),
      ),
    );
  }
}
