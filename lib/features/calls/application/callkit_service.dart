// lib/features/calls/application/callkit_service.dart
//
// Thin wrapper around `flutter_callkit_incoming` so the rest of the app can
// show / dismiss the native incoming-call UI (CallKit on iOS,
// ConnectionService on Android) without touching plugin specifics.

import 'dart:async';

import 'package:flutter_callkit_incoming/entities/entities.dart';
import 'package:flutter_callkit_incoming/flutter_callkit_incoming.dart';

class CallkitService {
  CallkitService._();
  static final instance = CallkitService._();

  /// Stream the user's accept/decline/end actions on the system call UI.
  Stream<CallEvent> get events =>
      FlutterCallkitIncoming.onEvent.where((e) => e != null).cast<CallEvent>();

  /// Returns true if CallKit already has an active/incoming entry for [callUuid].
  /// Used to dedupe duplicate webhook broadcasts (same call arrives on the
  /// org channel and the agent channel, possibly across multiple isolates).
  Future<bool> hasActiveCall(String callUuid) async {
    try {
      final raw = await FlutterCallkitIncoming.activeCalls();
      if (raw is! List) return false;
      for (final entry in raw) {
        if (entry is Map && entry['id']?.toString() == callUuid) return true;
      }
    } catch (_) {}
    return false;
  }

  /// Show the incoming-call overlay. [extra] is round-tripped to all events
  /// so we can correlate to our backend `Call` UUID.
  Future<void> showIncoming({
    required String callUuid,
    required String callerName,
    required String callerPhone,
    Map<String, dynamic> extra = const {},
  }) async {
    final params = CallKitParams(
      id: callUuid,
      nameCaller: callerName,
      handle: callerPhone,
      type: 0, // 0 = audio
      duration: 30000,
      textAccept: 'Accept',
      textDecline: 'Decline',
      missedCallNotification: NotificationParams(
        showNotification: true,
        isShowCallback: false,
        subtitle: 'Missed WhatsApp call',
      ),
      extra: extra,
      android: const AndroidParams(
        isCustomNotification: true,
        isShowLogo: false,
        ringtonePath: 'system_ringtone_default',
        backgroundColor: '#0955fa',
        actionColor: '#4CAF50',
        incomingCallNotificationChannelName: 'PiChat WhatsApp Calls',
        missedCallNotificationChannelName: 'PiChat Missed Calls',
      ),
      ios: const IOSParams(
        iconName: 'CallKitLogo',
        handleType: 'generic',
        supportsVideo: false,
        maximumCallGroups: 2,
        maximumCallsPerCallGroup: 1,
        audioSessionMode: 'default',
        audioSessionActive: true,
        audioSessionPreferredSampleRate: 44100.0,
        audioSessionPreferredIOBufferDuration: 0.005,
        supportsDTMF: true,
        supportsHolding: true,
        supportsGrouping: false,
        supportsUngrouping: false,
        ringtonePath: 'system_ringtone_default',
      ),
    );
    await FlutterCallkitIncoming.showCallkitIncoming(params);
  }

  Future<void> startOutgoing({
    required String callUuid,
    required String calleeName,
    required String calleePhone,
  }) async {
    final params = CallKitParams(
      id: callUuid,
      nameCaller: calleeName,
      handle: calleePhone,
      type: 0,
      extra: const {'direction': 'outbound'},
      ios: const IOSParams(handleType: 'generic'),
    );
    await FlutterCallkitIncoming.startCall(params);
  }

  /// Strip surrounding double-quotes that occasionally wrap the uuid when it
  /// round-trips through CallKit `extras` / FCM JSON encoding.
  String _normalizeUuid(String uuid) {
    var s = uuid.trim();
    if (s.length >= 2 && s.startsWith('"') && s.endsWith('"')) {
      s = s.substring(1, s.length - 1);
    }
    return s;
  }

  Future<void> endCall(String callUuid) async {
    final id = _normalizeUuid(callUuid);
    try {
      await FlutterCallkitIncoming.endCall(id);
    } catch (_) {}
    // Belt-and-suspenders: if the entry was registered with a quoted id
    // (legacy FCM / CallKit extras serialization) the call above misses it.
    // Walk the active list and end every entry whose normalized id matches.
    try {
      final raw = await FlutterCallkitIncoming.activeCalls();
      if (raw is List) {
        for (final entry in raw) {
          if (entry is Map) {
            final entryId = entry['id']?.toString() ?? '';
            if (_normalizeUuid(entryId) == id && entryId != id) {
              await FlutterCallkitIncoming.endCall(entryId);
            }
          }
        }
      }
    } catch (_) {}
  }

  Future<void> endAll() async {
    await FlutterCallkitIncoming.endAllCalls();
  }
}
