// lib/features/calls/application/call_controller.dart
//
// Riverpod orchestrator that ties together:
//   - the WebRTC signaling layer (CallSignalingService)
//   - the native call UI (CallkitService)
//   - HTTP calls to our backend (CallApi)
//   - Reverb broadcasts (call.{uuid} + calls.agent.{me})
//   - FCM data pushes (handled by CallFcmHandler -> .startIncoming)
//
// One controller serves the whole app — at most one active call at a time
// (matches the locked policy of "1 call/agent").

import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:dio/dio.dart';
import 'package:flutter_callkit_incoming/entities/entities.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../../../core/router/app_router.dart';
import '../../../core/state/auth_state.dart';
import '../../chat/application/main_controller.dart';
import '../../chat/application/voice_player.dart';
import '../data/call_api.dart';
import '../data/call_models.dart';
import 'call_signaling_service.dart';
import 'callkit_service.dart';

/// High-level lifecycle phases shown to the UI.
enum CallPhase {
  idle,
  requestingPermission,   // outbound: waiting for customer to accept WA call permission
  dialing,                // outbound: SDP offer sent, ringing customer
  ringing,                // inbound: callkit shown, waiting for agent action
  connecting,             // SDP exchange in progress
  inProgress,             // bidirectional audio
  ending,
  ended,
}

class CallState {
  final CallPhase phase;
  final CallModel? call;
  final String? error;
  final DateTime? acceptedAt;

  const CallState({
    this.phase = CallPhase.idle,
    this.call,
    this.error,
    this.acceptedAt,
  });

  CallState copyWith({
    CallPhase? phase,
    CallModel? call,
    String? error,
    DateTime? acceptedAt,
    bool clearError = false,
  }) =>
      CallState(
        phase: phase ?? this.phase,
        call: call ?? this.call,
        error: clearError ? null : (error ?? this.error),
        acceptedAt: acceptedAt ?? this.acceptedAt,
      );
}

class CallController extends StateNotifier<CallState> {
  CallController(this._ref) : super(const CallState()) {
    _bindCallkit();
    addListener(_pauseVoiceNotes, fireImmediately: false);
  }

  /// A call takes the audio over: a voice note left playing under it talked
  /// over the customer.
  void _pauseVoiceNotes(CallState s) {
    switch (s.phase) {
      case CallPhase.dialing:
      case CallPhase.ringing:
      case CallPhase.connecting:
      case CallPhase.inProgress:
        _ref.read(voicePlayerProvider.notifier).pause();
      default:
        break;
    }
  }

  final Ref _ref;
  final CallSignalingService _signaling = CallSignalingService();
  StreamSubscription<CallEvent>? _callkitSub;

  /// Last call uuid we already showed/handled an `IncomingCall` for.
  /// Backend broadcasts the same event on both `calls.org.{orgId}` and
  /// `calls.agent.{userId}` channels — without dedupe we'd ring twice.
  String? _lastIncomingUuid;

  /// Process-wide guards. We sometimes end up with two CallController
  /// instances (e.g. main() runs twice when EasyLocalization rebuilds the
  /// root, or when an FCM background isolate rebinds providers). Static
  /// sets ensure the very first instance to act on a given uuid wins.
  static final Set<String> _globalIncomingShown = <String>{};
  static final Set<String> _globalAccepting = <String>{};

  /// Pending outbound dial that is waiting for the customer to accept the
  /// WhatsApp call permission. Re-played when [handleRemoteCallEvent]
  /// receives a `CallPermissionUpdated` event with status=approved.
  ({String contactUuid, String contactName, String contactPhone})? _pendingOutbound;

  CallSignalingService get signaling => _signaling;

  // ---------------------------------------------------------------------------
  // Outbound
  // ---------------------------------------------------------------------------

  /// Agent tapped "Call" on a contact. Order of operations:
  ///   1) Build local SDP offer (microphone capture).
  ///   2) POST /calls/outbound  with {contact_uuid, sdp_offer}.
  ///   3) If 409 permission_required → stay in `requestingPermission` and
  ///      remember the dial; we replay it once the customer accepts.
  ///   4) Otherwise show the native call UI and wait for `CallAccepted`.
  Future<void> startOutbound({
    required String contactUuid,
    required String contactName,
    required String contactPhone,
  }) async {
    state = state.copyWith(phase: CallPhase.dialing, clearError: true);
    final api = _ref.read(callApiProvider);

    try {
      // 1) Local mic + SDP offer first — Meta needs it in the same Graph call.
      final sdpOffer = await _signaling.createOffer();

      // 2) Backend forwards to Meta.
      final result = await api.initiateOutbound(
        contactUuid: contactUuid,
        sdpOffer: sdpOffer,
      );

      // 3) Permission missing — backend already requested it from the customer.
      if (result.permissionRequired) {
        _pendingOutbound = (
          contactUuid: contactUuid,
          contactName: contactName,
          contactPhone: contactPhone,
        );
        // Tear down the local mic for now; we'll rebuild it on retry.
        await _signaling.dispose();
        state = state.copyWith(
          phase: CallPhase.requestingPermission,
          clearError: true,
        );
        return;
      }

      // 4) Stay on our own OutboundCallScreen; the SDP answer arrives via
      // Reverb (CallAccepted).
      //
      // We deliberately do NOT register the outgoing leg with CallKit. The
      // system UI adds nothing here — the app is in the foreground and
      // OutboundCallScreen already renders the dialing state — while
      // CallKit's own `actionCallEnded` was tearing the call down a few
      // seconds into ringing, before the customer could answer.
      final call = result.call!;
      state = state.copyWith(call: call, phase: CallPhase.dialing);
      await WakelockPlus.enable();
    } catch (e) {
      state = state.copyWith(phase: CallPhase.ended, error: e.toString());
      await _signaling.dispose();
    }
  }

  // ---------------------------------------------------------------------------
  // Inbound
  // ---------------------------------------------------------------------------

  /// Called from the FCM handler / Reverb listener when an incoming call
  /// arrives for this agent. Shows the native call UI.
  Future<void> startIncoming({
    required String callUuid,
    required String fromPhone,
    required String contactName,
    String? sdpOffer,
    Map<String, dynamic>? metadata,
  }) async {
    // Same dedupe path as IncomingCall: an FCM foreground push arrives
    // for the same call that Reverb just delivered. First caller wins.
    if (_lastIncomingUuid == callUuid) return;
    if (_globalIncomingShown.contains(callUuid)) {
      _lastIncomingUuid = callUuid;
      return;
    }
    if (await CallkitService.instance.hasActiveCall(callUuid)) {
      _lastIncomingUuid = callUuid;
      _globalIncomingShown.add(callUuid);
      state = CallState(
        phase: CallPhase.ringing,
        call: CallModel(
          id: 0,
          uuid: callUuid,
          direction: 'inbound',
          status: 'ringing',
          fromPhone: fromPhone,
          contactName: contactName,
          metadata: {
            if (sdpOffer != null) 'sdp_offer': sdpOffer,
            ...?metadata,
          },
        ),
      );
      return;
    }
    _lastIncomingUuid = callUuid;
    _globalIncomingShown.add(callUuid);

    state = CallState(
      phase: CallPhase.ringing,
      call: CallModel(
        id: 0,
        uuid: callUuid,
        direction: 'inbound',
        status: 'ringing',
        fromPhone: fromPhone,
        contactName: contactName,
        metadata: {
          if (sdpOffer != null) 'sdp_offer': sdpOffer,
          ...?metadata,
        },
      ),
    );

    await CallkitService.instance.showIncoming(
      callUuid: callUuid,
      callerName: contactName.isEmpty ? fromPhone : contactName,
      callerPhone: fromPhone,
      extra: {
        if (sdpOffer != null) 'sdp_offer': sdpOffer,
      },
    );
  }

  /// True while this agent is engaged — ringing, negotiating or talking.
  bool get _isOnCall =>
      state.call != null &&
      const {
        CallPhase.ringing,
        CallPhase.connecting,
        CallPhase.inProgress,
        CallPhase.dialing,
      }.contains(state.phase);

  Future<void> _acceptCurrent({String? sdpOffer}) async {
    final call = state.call;
    if (call == null) return;
    // Process-wide guard: if any controller in this process is already
    // accepting (or has accepted) this uuid, don't fire a second SDP/POST.
    if (!_globalAccepting.add(call.uuid)) {
      print('[CallController] _acceptCurrent skipped: already accepting ${call.uuid}');
      return;
    }
    state = state.copyWith(phase: CallPhase.connecting);

    try {
      // A VoIP push launches the app, so an accept from the CallKit UI can
      // arrive before SplashScreen has finished restoring the token and
      // organization from secure storage. Without this wait, CallApi throws
      // "No organization selected" and the call the push woke us for fails.
      await _awaitAuthReady();

      // The SDP offer may be inline (FCM extra) or fetched separately later.
      final offer = sdpOffer ?? call.metadata?['sdp_offer'] as String?;
      if (offer == null) {
        throw StateError('No SDP offer available to accept call');
      }

      final answer = await _signaling.setRemoteOfferAndAnswer(offer);
      await _ref.read(callApiProvider).accept(
            callUuid: call.uuid,
            sdpAnswer: answer,
          );
      await WakelockPlus.enable();
      // Switch Android into MODE_IN_COMMUNICATION and route to earpiece by
      // default — speaker route loses HW echo cancellation and produces a
      // feedback hiss that gets louder when the user hits speakerphone.
      await _signaling.activateCallAudio(speaker: false);
      state = state.copyWith(
        phase: CallPhase.inProgress,
        acceptedAt: DateTime.now(),
        call: call.copyWith(status: 'in_progress', acceptedAt: DateTime.now()),
      );
    } catch (e) {
      // 409 with reason `taken_by_other_agent` and our own user_id as the
      // winner means another instance/container of THIS app already
      // accepted the call (e.g. duplicate ProviderContainer race). The
      // call is still active — just don't tear down our UI.
      if (e is DioException &&
          e.response?.statusCode == 409 &&
          e.response?.data is Map) {
        final body = e.response!.data as Map;
        final winner = body['winner_user_id'];
        final me = _ref.read(userIdProvider);
        if (body['reason'] == 'taken_by_other_agent' &&
            winner != null &&
            me != null &&
            winner.toString() == me.toString()) {
          print('[CallController] _acceptCurrent: 409 from sibling instance; treating as success');
          await WakelockPlus.enable();
          state = state.copyWith(
            phase: CallPhase.inProgress,
            acceptedAt: DateTime.now(),
            call: call.copyWith(status: 'in_progress', acceptedAt: DateTime.now()),
          );
          return;
        }
      }
      state = state.copyWith(phase: CallPhase.ended, error: e.toString());
      await CallkitService.instance.endCall(call.uuid);
    }
  }

  /// Waits, briefly, for auth state to be restored. Returns as soon as both
  /// the token and organization are present; gives up after [timeout] so a
  /// genuinely-logged-out app still fails fast rather than hanging the accept.
  Future<void> _awaitAuthReady({
    Duration timeout = const Duration(seconds: 8),
  }) async {
    final deadline = DateTime.now().add(timeout);

    while (DateTime.now().isBefore(deadline)) {
      final token = _ref.read(authTokenProvider);
      final orgId = _ref.read(authProvider).organizationId;

      if (token != null && token.isNotEmpty && orgId != null) return;

      await Future<void>.delayed(const Duration(milliseconds: 200));
    }

    // ignore: avoid_print
    print('[Calling] auth not ready after ${timeout.inSeconds}s; '
        'attempting accept anyway');
  }

  /// Take a call from the queue.
  ///
  /// Meta's calling API has no hold, and WhatsApp itself does not offer it, so
  /// answering a second call necessarily ends the first. The UI says "End &
  /// Accept" rather than plain "Accept" so that is a decision the agent makes
  /// knowingly instead of discovering afterwards.
  Future<void> acceptQueued(CallModel queued) async {
    _ref.read(callQueueProvider.notifier).remove(queued.uuid);

    if (_isOnCall) {
      await hangup();
    }

    // A fresh peer connection: the previous call's one has just been torn down
    // with it, and reusing it would negotiate against a closed transport.
    await _signaling.dispose();

    _lastIncomingUuid = queued.uuid;
    _globalIncomingShown.add(queued.uuid);

    state = CallState(phase: CallPhase.ringing, call: queued);

    _navigateToCallScreen();

    await _acceptCurrent(sdpOffer: queued.metadata?['sdp_offer'] as String?);
  }

  /// Decline a queued call for THIS agent only.
  ///
  /// The backend's reject is per-agent: colleagues keep ringing, and the call
  /// stays claimable by them. That is what makes this usable as a dismiss —
  /// an agent mid-conversation can clear it off their screen without hanging
  /// up on the customer.
  Future<void> declineQueued(CallModel queued) async {
    _ref.read(callQueueProvider.notifier).remove(queued.uuid);

    try {
      await _ref.read(callApiProvider).reject(queued.uuid);
    } catch (e) {
      // ignore: avoid_print
      print('[Calling] declining queued call failed: $e');
    }
  }

  Future<void> _rejectCurrent() async {
    final call = state.call;
    if (call == null) return;
    try {
      await _ref.read(callApiProvider).reject(call.uuid);
    } catch (_) {}
    await _teardown();
  }

  Future<void> hangup() async {
    final call = state.call;

    // Cancel a pending outbound that is still waiting for the customer
    // to grant WhatsApp call permission (no call row yet).
    if (call == null) {
      if (_pendingOutbound != null || state.phase == CallPhase.requestingPermission) {
        _pendingOutbound = null;
        await _teardown();
      }
      return;
    }

    state = state.copyWith(phase: CallPhase.ending);
    try {
      await _ref.read(callApiProvider).hangup(call.uuid);
    } catch (_) {}
    await CallkitService.instance.endCall(call.uuid);
    await _teardown();
  }

  // ---------------------------------------------------------------------------
  // Remote -> local: events from Reverb (`call.{uuid}` + `calls.agent.{me}`)
  // ---------------------------------------------------------------------------

  /// Apply a Reverb call event broadcast by the backend.
  Future<void> handleRemoteCallEvent(String event, Map<String, dynamic> payload) async {
    final remoteCall = payload['call'] is Map
        ? CallModel.fromJson(Map<String, dynamic>.from(payload['call'] as Map))
        : null;

    // Keep the chat list in step with the call as it happens, so a row reads
    // "Incoming call" while it rings and "Missed call" the moment nobody takes
    // it — rather than staying stale until the next refresh.
    if (remoteCall?.contactId != null) {
      unawaited(
        _ref.read(mainDataProvider.notifier).applyCallActivity(
              contactId: remoteCall!.contactId!,
              at: remoteCall.createdAt ?? DateTime.now(),
              direction: remoteCall.direction,
              status: remoteCall.status,
            ),
      );
    }

    switch (event) {
      case 'IncomingCall':
        if (remoteCall == null) return;

        // Already on a call? Queue it instead of ringing.
        //
        // The backend deliberately sends no push to a busy agent, because iOS
        // forces every PushKit push to become a CallKit ring — a queued call
        // would stack as a call-waiting prompt over the live one. So this
        // arrives over Reverb and belongs in the in-app queue, where it stays
        // claimable for the ~20-30s Meta keeps it ringing.
        if (_isOnCall && remoteCall.uuid != state.call?.uuid) {
          _ref.read(callQueueProvider.notifier).add(
                remoteCall.copyWith(
                  metadata: {
                    if (payload['sdp_offer'] != null)
                      'sdp_offer': payload['sdp_offer'],
                    ...?remoteCall.metadata,
                  },
                ),
              );

          return;
        }

        // Dedupe across channels (org + agent), across multiple controller
        // instances within the same process (static set), AND across isolates
        // (CallKit native check).
        if (_lastIncomingUuid == remoteCall.uuid) return;
        if (_globalIncomingShown.contains(remoteCall.uuid)) {
          _lastIncomingUuid = remoteCall.uuid;
          return;
        }
        if (await CallkitService.instance.hasActiveCall(remoteCall.uuid)) {
          _lastIncomingUuid = remoteCall.uuid;
          _globalIncomingShown.add(remoteCall.uuid);
          // Hydrate state so the controller can take over once the user accepts.
          state = CallState(
            phase: CallPhase.ringing,
            call: remoteCall.copyWith(
              metadata: {
                if (payload['sdp_offer'] != null) 'sdp_offer': payload['sdp_offer'],
                ...?remoteCall.metadata,
              },
            ),
          );
          return;
        }
        _lastIncomingUuid = remoteCall.uuid;
        _globalIncomingShown.add(remoteCall.uuid);
        await startIncoming(
          callUuid: remoteCall.uuid,
          fromPhone: remoteCall.fromPhone ?? '',
          contactName: remoteCall.contactName ?? '',
          sdpOffer: payload['sdp_offer'] as String?,
          metadata: remoteCall.metadata,
        );
        break;

      case 'CallAccepted':
        // Only relevant for OUTBOUND calls — the customer just answered
        // and Meta returned their SDP answer. For inbound calls we already
        // created our own answer locally during _acceptCurrent (state is
        // already 'stable'); applying this echoed answer would crash with
        // "Called in wrong state: stable".
        final isInbound = (remoteCall?.direction ?? state.call?.direction) == 'inbound';
        final sdpAnswer = payload['sdp_answer'] as String?;
        if (sdpAnswer != null && !isInbound) {
          await _signaling.setRemoteAnswer(sdpAnswer);
        }
        if (remoteCall != null) {
          state = state.copyWith(
            phase: CallPhase.inProgress,
            call: remoteCall,
            acceptedAt: DateTime.now(),
          );
        }
        break;

      case 'CallTakenByOtherAgent':
        // Another agent picked it up first — drop our ringer.
        if (remoteCall != null) {
          _ref.read(callQueueProvider.notifier).remove(remoteCall.uuid);
        }
        if (remoteCall != null) {
          await CallkitService.instance.endCall(remoteCall.uuid);
        }
        await _teardown();
        break;

      case 'CallStatus':
        if (remoteCall != null) {
          state = state.copyWith(call: remoteCall);
        }
        break;

      case 'CallEnded':
      case 'CallMissed':
        if (remoteCall != null) {
          _ref.read(callQueueProvider.notifier).remove(remoteCall.uuid);

          // A queued call ending is not this agent's call ending — tearing
          // down here would drop the conversation they are actually on.
          if (remoteCall.uuid != state.call?.uuid) return;
        }
        if (remoteCall != null) {
          await CallkitService.instance.endCall(remoteCall.uuid);
        }
        // If we were still in the ringing phase (caller cancelled before we
        // accepted) the targeted endCall above can miss the registered
        // CallKit entry due to id-quoting mismatch. Force-clear any
        // remaining incoming UI so the ringtone stops.
        if (state.phase == CallPhase.ringing || state.phase == CallPhase.idle) {
          await CallkitService.instance.endAll();
        }
        await _teardown();
        break;

      case 'CallPermissionUpdated':
        // Customer just acted on the permission request. If they approved
        // and we have a pending dial, retry it now.
        final status = payload['status'] as String? ??
            (payload['permission'] is Map ? (payload['permission']['status'] as String?) : null);
        final pending = _pendingOutbound;
        if (status == 'approved' && pending != null) {
          _pendingOutbound = null;
          await startOutbound(
            contactUuid: pending.contactUuid,
            contactName: pending.contactName,
            contactPhone: pending.contactPhone,
          );
        } else if (status == 'rejected' || status == 'denied' || status == 'expired' || status == 'failed') {
          _pendingOutbound = null;
          state = state.copyWith(
            phase: CallPhase.ended,
            error: switch (status) {
              'denied' || 'rejected' => 'Customer declined call permission',
              'expired' => 'Call permission request expired',
              'failed' => 'Could not deliver call permission request to WhatsApp',
              _ => 'Call permission unavailable',
            },
          );
          await _teardown();
        }
        break;
    }
  }

  // ---------------------------------------------------------------------------
  // Audio controls (mute / speaker)
  // ---------------------------------------------------------------------------

  Future<void> toggleMute() async {
    await _signaling.setMuted(!_signaling.isMuted);
    state = state.copyWith();
  }

  Future<void> toggleSpeaker() async {
    await _signaling.setSpeakerOn(!_signaling.isSpeakerOn);
    state = state.copyWith();
  }

  // ---------------------------------------------------------------------------
  // Internals
  // ---------------------------------------------------------------------------

  void _bindCallkit() {
    _callkitSub = CallkitService.instance.events.listen((event) async {
      // CallkitEvent body shape: { 'id': callUuid, ... }
      final body = (event.body is Map)
          ? Map<String, dynamic>.from(event.body as Map)
          : <String, dynamic>{};
      final extra = (body['extra'] is Map)
          ? Map<String, dynamic>.from(body['extra'] as Map)
          : <String, dynamic>{};
      final callUuid = body['id'] as String?;

      switch (event.event) {
        case Event.actionCallAccept:
          // Cold-start path: the CallKit UI was shown by the background
          // FCM handler in a separate isolate, so this controller has no
          // CallModel in state yet. Hydrate a minimal one from CallKit
          // body so _acceptCurrent has something to work with.
          if (state.call == null && callUuid != null) {
            state = CallState(
              phase: CallPhase.ringing,
              call: CallModel(
                id: 0,
                uuid: callUuid,
                direction: 'inbound',
                status: 'ringing',
                fromPhone: body['handle'] as String?,
                contactName: body['nameCaller'] as String?,
                metadata: extra,
              ),
            );
          }
          // Flip phase to connecting and push the in-call screen IMMEDIATELY
          // so the user doesn't see whatever screen was previously on top
          // (e.g. chat) for the 1-2s it takes _acceptCurrent to negotiate
          // SDP / hit the backend. The screen renders the "Connecting…"
          // state until inProgress is reached.
          state = state.copyWith(phase: CallPhase.connecting);
          _navigateToCallScreen();
          await _acceptCurrent(sdpOffer: extra['sdp_offer'] as String?);
          break;
        case Event.actionCallDecline:
          await _rejectCurrent();
          break;
        case Event.actionCallEnded:
          // User pressed the red hangup button on the system UI. We MUST
          // tell the backend so it can terminate the call on Meta's side,
          // otherwise the customer's WhatsApp keeps ringing/talking.
          //
          // Only inbound calls are registered with CallKit, so an event that
          // arrives while we are placing a call is the system tearing down a
          // leg it should not own — acting on it would hang up on ourselves.
          if (state.call?.direction == 'outbound') {
            // ignore: avoid_print
            print('[Calling] ignoring CallKit actionCallEnded for outbound call');
            break;
          }
          await hangup();
          break;
        case Event.actionCallTimeout:
          await _teardown();
          break;
        default:
          break;
      }
    });
  }

  void _navigateToCallScreen() {
    // Use the GoRouter instance directly — its rootNavigatorKey works even
    // when no widget context with GoRouter inherited above is available
    // (e.g. cold-start through CallKit lock-screen accept).
    try {
      final router = _ref.read(appRouterProvider);
      router.push('/call');
    } catch (e) {
      // ignore: avoid_print
      print('[Calling] navigate to /call failed: $e');
    }
  }

  Future<void> _teardown() async {
    // Reset the minimised flag, otherwise the next call inherits it and opens
    // as a banner instead of a screen.
    _ref.read(callMinimisedProvider.notifier).state = false;

    final endedUuid = state.call?.uuid;
    await _signaling.dispose();
    await WakelockPlus.disable();
    _lastIncomingUuid = null;
    if (endedUuid != null) {
      _globalIncomingShown.remove(endedUuid);
      _globalAccepting.remove(endedUuid);
    }
    state = state.copyWith(phase: CallPhase.ended);
    // Reset to idle after a short delay so the UI can show "Ended" briefly.
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) state = const CallState();
    });
  }

  @override
  void dispose() {
    _callkitSub?.cancel();
    _signaling.dispose();
    super.dispose();
  }
}

/// Calls ringing right now that this agent has not taken.
///
/// Only ever holds calls that arrived while the agent was already on one. A
/// free agent's first call is rung natively by CallKit, which is a better
/// surface than anything in-app; queueing it as well would show the same call
/// twice.
class CallQueue extends StateNotifier<List<CallModel>> {
  CallQueue() : super(const []);

  void add(CallModel call) {
    if (state.any((c) => c.uuid == call.uuid)) return;

    state = [...state, call];
  }

  void remove(String uuid) {
    if (!state.any((c) => c.uuid == uuid)) return;

    state = state.where((c) => c.uuid != uuid).toList();
  }

  void clear() => state = const [];
}

final callQueueProvider =
    StateNotifierProvider<CallQueue, List<CallModel>>((ref) => CallQueue());

/// True while a running call's screen has been put away.
///
/// Minimising is purely a presentation state — the call itself is untouched —
/// so it lives beside the controller rather than inside CallState, which
/// mirrors the backend's view of the call.
final callMinimisedProvider = StateProvider<bool>((ref) => false);

final callControllerProvider =
    StateNotifierProvider<CallController, CallState>((ref) {
  return CallController(ref);
});

/// Set from the root MaterialApp so the controller can navigate when the
/// agent accepts a call from the lock screen / native UI.
final callRouterContextProvider = StateProvider<BuildContext?>((_) => null);
