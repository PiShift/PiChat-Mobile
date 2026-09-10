import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pichat/core/network/dio_provider.dart';
import 'package:pichat/core/state/auth_state.dart';

/// Why the AI assistant is not answering a conversation.
///
/// These mirror the checks `PibotService::handle()` runs, in the order it runs
/// them, so the app can tell an agent the actual reason rather than just
/// showing the bot as off.
enum PibotInactiveReason {
  /// The organization has no assistant configured, or it is switched off.
  notConfigured,

  /// Someone explicitly handed this conversation to a human — either the bot
  /// itself via its handoff tool, or an agent from this screen.
  handedOff,

  /// The ticket is open and assigned to an agent. Taking a conversation is
  /// itself how the bot is silenced.
  takenByAgent,

  /// Not inactive.
  none,
}

class PibotState {
  const PibotState({
    required this.orgEnabled,
    required this.active,
    required this.reason,
    this.botName,
    this.sessionStatus,
    this.autoPauseOnHumanReply = false,
  });

  /// The organization has the assistant configured and switched on.
  final bool orgEnabled;

  /// The assistant will answer this conversation as things stand.
  final bool active;

  final PibotInactiveReason reason;
  final String? botName;
  final String? sessionStatus;

  /// When set, a human reply newer than the customer's last message pauses the
  /// bot until the customer writes again — so [active] can be true while the
  /// bot still stays quiet for a while.
  final bool autoPauseOnHumanReply;

  static const unavailable = PibotState(
    orgEnabled: false,
    active: false,
    reason: PibotInactiveReason.notConfigured,
  );

  factory PibotState.fromJson(Map<String, dynamic> json) => PibotState(
        orgEnabled: json['org_enabled'] == true,
        active: json['active'] == true,
        reason: switch (json['reason']) {
          'not_configured' => PibotInactiveReason.notConfigured,
          'handed_off' => PibotInactiveReason.handedOff,
          'taken_by_agent' => PibotInactiveReason.takenByAgent,
          _ => PibotInactiveReason.none,
        },
        botName: json['bot_name'] as String?,
        sessionStatus: json['session_status'] as String?,
        autoPauseOnHumanReply: json['auto_pause_on_human_reply'] == true,
      );

  /// Short label for the status strip.
  String get label {
    if (!orgEnabled) return 'AI off';
    if (active) return '${botName ?? 'AI'} replying';

    return switch (reason) {
      PibotInactiveReason.handedOff => 'AI paused',
      PibotInactiveReason.takenByAgent => 'AI paused · you have this',
      _ => 'AI paused',
    };
  }
}

class PibotApi {
  PibotApi(this._dio, this._orgId);

  final Dio _dio;
  final int? _orgId;

  int get _org {
    final id = _orgId;
    if (id == null) {
      throw StateError('No organization selected — cannot read AI state.');
    }

    return id;
  }

  Future<PibotState> fetch(String contactUuid) async {
    final res = await _dio.get(
      '/contacts/$contactUuid/ai',
      queryParameters: {'organization_id': _org},
    );

    return PibotState.fromJson(
      Map<String, dynamic>.from(res.data['data'] as Map),
    );
  }

  Future<PibotState> pause(String contactUuid) => _setState(contactUuid, 'pause');

  Future<PibotState> resume(String contactUuid) =>
      _setState(contactUuid, 'resume');

  Future<PibotState> _setState(String contactUuid, String action) async {
    final res = await _dio.post(
      '/contacts/$contactUuid/ai/$action',
      data: {'organization_id': _org},
    );

    return PibotState.fromJson(
      Map<String, dynamic>.from(res.data['data'] as Map),
    );
  }
}

final pibotApiProvider = Provider<PibotApi>((ref) {
  final dio = ref.watch(dioProvider);
  final orgId = ref.watch(authProvider).organizationId;

  return PibotApi(dio, orgId);
});

/// AI state for one conversation.
///
/// Returns [PibotState.unavailable] rather than throwing when the request
/// fails: an org without the assistant enabled is the common case, and the
/// status strip should simply stay quiet instead of surfacing an error.
final pibotStateProvider =
    FutureProvider.family<PibotState, String>((ref, contactUuid) async {
  try {
    return await ref.watch(pibotApiProvider).fetch(contactUuid);
  } catch (_) {
    return PibotState.unavailable;
  }
});
