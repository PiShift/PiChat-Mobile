// lib/features/calls/application/call_signaling_service.dart
//
// Wraps `flutter_webrtc` to manage a single audio peer-connection per call.
// Generates SDP offer / processes SDP answer (and vice-versa for inbound).
// Captures the local mic, plays the remote audio stream automatically.

import 'dart:async';

import 'package:flutter_webrtc/flutter_webrtc.dart';

class CallSignalingService {
  RTCPeerConnection? _pc;
  MediaStream? _localStream;
  MediaStream? _remoteStream;
  final _remoteStreamController = StreamController<MediaStream>.broadcast();
  bool _muted = false;
  bool _speaker = false;

  Stream<MediaStream> get remoteStream$ => _remoteStreamController.stream;
  MediaStream? get localStream => _localStream;
  bool get isMuted => _muted;
  bool get isSpeakerOn => _speaker;

  /// Create the peer connection and acquire mic. Returns an SDP offer for
  /// outbound calls; for inbound calls call [setRemoteOffer] first.
  Future<String> createOffer() async {
    await _ensurePeerConnection();
    final offer = await _pc!.createOffer({
      'mandatory': {
        'OfferToReceiveAudio': true,
        'OfferToReceiveVideo': false,
      },
    });
    await _pc!.setLocalDescription(offer);
    return offer.sdp ?? '';
  }

  /// Inbound flow: accept remote offer, then build an SDP answer to send back.
  Future<String> setRemoteOfferAndAnswer(String sdpOffer) async {
    await _ensurePeerConnection();
    final normalized = _normalizeSdp(sdpOffer);
    // ignore: avoid_print
    print('[Calling] setRemoteOffer SDP (${normalized.length} chars):\n$normalized');
    try {
      await _pc!.setRemoteDescription(RTCSessionDescription(normalized, 'offer'));
    } catch (e) {
      // ignore: avoid_print
      print('[Calling] setRemoteOffer FAILED: $e');
      rethrow;
    }
    final answer = await _pc!.createAnswer({
      'mandatory': {
        'OfferToReceiveAudio': true,
        'OfferToReceiveVideo': false,
      },
    });
    final tunedSdp = _tuneOpus(answer.sdp ?? '');
    await _pc!.setLocalDescription(
      RTCSessionDescription(tunedSdp, answer.type),
    );
    return tunedSdp;
  }

  /// Outbound flow: process the remote SDP answer once received via webhook.
  Future<void> setRemoteAnswer(String sdpAnswer) async {
    if (_pc == null) return;
    final normalized = _normalizeSdp(sdpAnswer);
    // ignore: avoid_print
    print('[Calling] setRemoteAnswer SDP (${normalized.length} chars):\n$normalized');
    try {
      await _pc!.setRemoteDescription(RTCSessionDescription(normalized, 'answer'));
    } catch (e) {
      // ignore: avoid_print
      print('[Calling] setRemoteAnswer FAILED: $e');
      rethrow;
    }
  }

  /// Rewrites the OPUS `a=fmtp` line to ask for a higher bitrate, full
  /// playback rate and inband forward error correction. Meta's offer caps us
  /// at ~20 kbps mono / 16 kHz, which produces audible warble; bumping the
  /// answer side encourages the codec to allocate more bits in the egress
  /// direction (the only direction we control) and turns on FEC so packet
  /// loss doesn't pop.
  String _tuneOpus(String sdp) {
    final lines = sdp.split('\r\n');
    int? opusPt;
    final rtpRe = RegExp(r'^a=rtpmap:(\d+) opus/');
    for (final l in lines) {
      final m = rtpRe.firstMatch(l);
      if (m != null) {
        opusPt = int.parse(m.group(1)!);
        break;
      }
    }
    if (opusPt == null) return sdp;
    final fmtpPrefix = 'a=fmtp:$opusPt ';
    final tunedFmtp =
        '${fmtpPrefix}minptime=10;useinbandfec=1;usedtx=0;stereo=0;cbr=0;'
        'maxaveragebitrate=40000;maxplaybackrate=48000;'
        'sprop-maxcapturerate=48000';
    var found = false;
    for (var i = 0; i < lines.length; i++) {
      if (lines[i].startsWith(fmtpPrefix)) {
        lines[i] = tunedFmtp;
        found = true;
        break;
      }
    }
    if (!found) {
      // Insert right after the rtpmap line.
      for (var i = 0; i < lines.length; i++) {
        if (lines[i].startsWith('a=rtpmap:$opusPt opus/')) {
          lines.insert(i + 1, tunedFmtp);
          break;
        }
      }
    }
    return lines.join('\r\n');
  }

  /// libwebrtc's SDP parser is strict: every line must end with `\r\n` and the
  /// document itself must end with `\r\n`. It also chokes on stray double
  /// escapes that survive a JSON round-trip in some plugins (e.g. when
  /// flutter_callkit_incoming serializes extras).
  String _normalizeSdp(String raw) {
    var s = raw;
    // Some webhook payloads land with literal backslash-escaped sequences
    // (e.g. when re-serialized through CallKit extras).
    if (s.contains(r'\r\n') && !s.contains('\r\n')) {
      s = s.replaceAll(r'\r\n', '\r\n').replaceAll(r'\n', '\n');
    }
    // Normalize lone LFs to CRLF.
    s = s.replaceAll('\r\n', '\n').replaceAll('\n', '\r\n');
    if (!s.endsWith('\r\n')) {
      s += '\r\n';
    }
    return s;
  }

  Future<void> _ensurePeerConnection() async {
    if (_pc != null) return;

    _pc = await createPeerConnection({
      'iceServers': [
        {'urls': 'stun:stun.l.google.com:19302'},
      ],
      'sdpSemantics': 'unified-plan',
      // Larger jitter buffer reduces audio dropouts / underruns on lossy
      // mobile networks at the cost of a small latency increase.
      'audioJitterBufferMaxPackets': 200,
      'audioJitterBufferFastAccelerate': true,
    });

    _pc!.onTrack = (RTCTrackEvent event) {
      if (event.streams.isNotEmpty) {
        _remoteStream = event.streams.first;
        _remoteStreamController.add(_remoteStream!);
      }
    };

    _pc!.onConnectionState = (state) {
      // Could surface this to controller for UI badges.
    };

    _localStream = await navigator.mediaDevices.getUserMedia({
      'audio': {
        'mandatory': {
          'googEchoCancellation': true,
          'googEchoCancellation2': true,
          'googNoiseSuppression': true,
          'googNoiseSuppression2': true,
          'googAutoGainControl': true,
          'googHighpassFilter': true,
          'googTypingNoiseDetection': true,
        },
        'optional': [],
        'echoCancellation': true,
        'noiseSuppression': true,
        'autoGainControl': true,
      },
      'video': false,
    });

    for (final track in _localStream!.getAudioTracks()) {
      await _pc!.addTrack(track, _localStream!);
    }
  }

  Future<void> setMuted(bool muted) async {
    _muted = muted;
    if (_localStream == null) return;
    for (final track in _localStream!.getAudioTracks()) {
      track.enabled = !muted;
    }
  }

  Future<void> setSpeakerOn(bool on) async {
    _speaker = on;
    if (_localStream == null) return;
    // ignore: deprecated_member_use
    await Helper.setSpeakerphoneOn(on);
  }

  /// Apply the platform audio routing policy expected during a voice call.
  /// MUST be called once a call is active so Android switches to
  /// MODE_IN_COMMUNICATION (engages HW AEC + AGC + NS and routes through the
  /// telephony pipeline). Without this the speaker can produce a feedback
  /// loop because the mic picks the speaker output back up.
  Future<void> activateCallAudio({bool speaker = false}) async {
    try {
      // ignore: deprecated_member_use
      await Helper.setSpeakerphoneOn(speaker);
    } catch (_) {}
    _speaker = speaker;
  }

  Future<void> dispose() async {
    try {
      for (final track in _localStream?.getTracks() ?? []) {
        await track.stop();
      }
      await _localStream?.dispose();
    } catch (_) {}
    try {
      await _pc?.close();
    } catch (_) {}
    _pc = null;
    _localStream = null;
    _remoteStream = null;
  }
}
