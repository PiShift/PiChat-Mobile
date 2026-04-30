// lib/features/calls/application/call_fcm_handler.dart
//
// Routes FCM data-only push messages with `type: incoming_call` into the
// CallController. Works in foreground via the existing `FirebaseMessaging.onMessage`
// listener AND in the background-handler entry point in main.dart.

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_callkit_incoming/flutter_callkit_incoming.dart';
import 'package:flutter_callkit_incoming/entities/entities.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'call_controller.dart';

/// Foreground handler invoked from main.dart's `FirebaseMessaging.onMessage`
/// callback for messages whose data has `type=incoming_call`.
Future<void> handleIncomingCallFcm(
  ProviderContainer container,
  RemoteMessage message,
) async {
  final data = message.data;
  if (data['type'] != 'incoming_call') return;

  final callUuid = data['call_uuid'] as String?;
  if (callUuid == null) return;

  final controller = container.read(callControllerProvider.notifier);
  await controller.startIncoming(
    callUuid: callUuid,
    fromPhone: data['from_phone'] as String? ?? '',
    contactName: data['contact_name'] as String? ?? '',
    sdpOffer: data['sdp_offer'] as String?,
    metadata: {
      if (data['wa_call_id'] != null) 'wa_call_id': data['wa_call_id'],
    },
  );
}

/// Static background handler — runs in an isolated Dart isolate, so it can
/// only show the native call UI; the actual SDP exchange happens later from
/// the main isolate after the user taps Accept and the app is brought up.
Future<void> backgroundShowCallkitFromFcm(RemoteMessage message) async {
  final data = message.data;
  if (data['type'] != 'incoming_call') return;
  final callUuid = data['call_uuid'] as String?;
  if (callUuid == null) return;

  final fromPhone = data['from_phone'] as String? ?? '';
  final contactName = data['contact_name'] as String? ?? fromPhone;

  await FlutterCallkitIncoming.showCallkitIncoming(CallKitParams(
    id: callUuid,
    nameCaller: contactName,
    handle: fromPhone,
    type: 0,
    duration: 30000,
    textAccept: 'Accept',
    textDecline: 'Decline',
    extra: {
      if (data['sdp_offer'] != null) 'sdp_offer': data['sdp_offer'],
      if (data['wa_call_id'] != null) 'wa_call_id': data['wa_call_id'],
    },
    android: const AndroidParams(
      isCustomNotification: true,
      ringtonePath: 'system_ringtone_default',
      backgroundColor: '#0955fa',
      actionColor: '#4CAF50',
    ),
    ios: const IOSParams(
      handleType: 'generic',
      supportsVideo: false,
    ),
  ));
}
