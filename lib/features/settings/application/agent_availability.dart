import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pichat/core/services/notification_service.dart';
import 'package:pichat/features/calls/data/call_api.dart';

/// Whether this agent is on duty.
///
/// Replaces the old "push notifications" switch, which only ever meant
/// something to notifications and nothing to call routing — an agent could turn
/// notifications off and still have calls rung at them. One switch now governs
/// both, because from the agent's point of view they are the same decision:
/// am I working right now.
///
/// The state lives on the server (`agent_call_status.status`), so it survives a
/// reinstall and is visible to the router. Read back from the presence endpoint
/// rather than cached locally, which would drift after the one-device eviction
/// signs this handset out.
final agentAvailabilityProvider =
    AsyncNotifierProvider<AgentAvailability, bool>(AgentAvailability.new);

class AgentAvailability extends AsyncNotifier<bool> {
  @override
  Future<bool> build() async {
    try {
      final status = await ref.read(callApiProvider).fetchAgentStatus();

      return status == 'available';
    } catch (_) {
      // Assume on duty rather than silently going dark: a failed read must not
      // look like "you have no calls today".
      return true;
    }
  }

  Future<void> set(bool available) async {
    state = AsyncData(available);

    try {
      // Going off duty deliberately keeps the push tokens: the agent is
      // pausing, not signing out, and clearing them would force a full
      // re-registration on their next shift.
      await NotificationService().registerCallingDevice(
        status: available ? 'available' : 'offline',
      );
    } catch (e) {
      state = AsyncData(!available);
      rethrow;
    }
  }
}
