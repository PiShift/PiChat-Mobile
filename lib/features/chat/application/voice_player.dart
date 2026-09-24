import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:just_audio/just_audio.dart';

import 'package:pichat/core/state/auth_state.dart';
import 'package:pichat/features/chat/application/voice_chain.dart';
import 'package:pichat/features/chat/application/voice_chime.dart';

/// What is playing right now, across the whole conversation.
class VoicePlayback {
  const VoicePlayback({
    this.mediaId,
    this.position = Duration.zero,
    this.duration,
    this.playing = false,
    this.speed = 1.0,
    this.contactId,
    this.contactName,
  });

  /// The note the shared player is loaded with, if any.
  final String? mediaId;

  final Duration position;
  final Duration? duration;
  final bool playing;
  final double speed;

  /// Who the note belongs to, captured when it starts, so the banner can name
  /// the conversation and know when it is being shown outside it.
  final int? contactId;
  final String? contactName;

  VoicePlayback copyWith({
    String? mediaId,
    Duration? position,
    Duration? duration,
    bool? playing,
    double? speed,
  }) {
    return VoicePlayback(
      mediaId: mediaId ?? this.mediaId,
      position: position ?? this.position,
      duration: duration ?? this.duration,
      playing: playing ?? this.playing,
      speed: speed ?? this.speed,
      contactId: contactId,
      contactName: contactName,
    );
  }
}

/// One player for every voice note in the thread.
///
/// Each bubble used to own an `AudioPlayer` and hold the position, duration and
/// playing flag in its own State. That made playback a property of a *widget*,
/// and widgets in a long list are disposed and rebuilt constantly — scrolling a
/// few pixels was enough to tear down the player mid-sentence and lose the
/// duration, which is what made every timestamp flicker at once.
///
/// Keeping it here means the audio outlives the bubble that started it. It also
/// matches the behaviour people expect: exactly one voice note plays at a time,
/// and starting another stops the first without either bubble having to know
/// about the other.
class VoicePlayerNotifier extends StateNotifier<VoicePlayback> {
  VoicePlayerNotifier(this._ref) : super(const VoicePlayback()) {
    // Throttled deliberately. The default positionStream emits as often as
    // every 16ms — sixty new states a second, each one waking every listener
    // and every observer. A progress bar does not need that, and it drowned
    // the logs while a note played.
    _position = _player
        .createPositionStream(
      steps: 200,
      minPeriod: const Duration(milliseconds: 200),
      maxPeriod: const Duration(milliseconds: 200),
    )
        .listen((p) {
      if (mounted) state = state.copyWith(position: p);
    });

    _duration = _player.durationStream.listen((d) {
      if (mounted && d != null) state = state.copyWith(duration: d);
    });

    _playerState = _player.playerStateStream.listen((s) {
      if (!mounted) return;

      state = state.copyWith(playing: s.playing);

      if (s.processingState == ProcessingState.completed) _onCompleted();

    });
  }

  final Ref _ref;
  final AudioPlayer _player = AudioPlayer();

  StreamSubscription<Duration>? _position;
  StreamSubscription<Duration?>? _duration;
  StreamSubscription<PlayerState>? _playerState;

  /// Which file each note is loaded from, so the chain can start the next one
  /// even when its bubble has been scrolled out of the list.
  final Map<String, String> _paths = {};

  static const _speeds = <double>[1.0, 1.5, 2.0];

  /// The run's links, kept from while the conversation was open.
  ///
  /// They are derived from the thread's messages, and that provider is
  /// disposed once nothing is watching it — so reading them fresh after the
  /// agent has navigated away returns an empty map and the run stops. Holding
  /// the last good copy is what lets a run keep going from the banner.
  Map<String, String> _links = const {};
  int? _linksOwner;

  /// Guards against re-entering the hand-over.
  ///
  /// `completed` is a state, not an event: it keeps being re-emitted, and the
  /// pause and seek below emit further states of their own. Without this the
  /// hand-over ran dozens of times, each restarting the cue before the last
  /// had loaded — which is exactly the "Loading interrupted" in the log, and
  /// why no cue was ever heard.
  bool _advancing = false;

  /// Remember where a note lives, so it can be played without its bubble.
  void register(String mediaId, String path) {
    _paths[mediaId] = path;
  }

  bool isActive(String mediaId) => state.mediaId == mediaId;

  Future<void> toggle(String mediaId, String path) async {
    if (isActive(mediaId)) {
      if (state.playing) {
        await _player.pause();
      } else {
        unawaited(_player.play());
      }

      return;
    }

    await play(mediaId, path);
  }

  Future<void> play(
    String mediaId,
    String path, {
    int? contactId,
    String? contactName,
  }) async {
    try {
      register(mediaId, path);

      // The owner is passed in when a run hands over, and otherwise taken from
      // whichever thread is open — a tap can only come from inside one.
      //
      // Re-reading the open thread on every note was wrong: once the agent had
      // navigated away, nothing was open, so the next note in the run had no
      // owner and the banner decided it was already in the right place and
      // vanished mid-run.
      final owner = contactId ?? _ref.read(activeContactIdProvider);
      final ownerName = contactId != null
          ? contactName
          : _ref.read(activeContactNameProvider);

      // Switching notes: clear the old duration so the new bubble does not
      // briefly show the previous note's length.
      state = VoicePlayback(
        mediaId: mediaId,
        speed: state.speed,
        contactId: owner,
        contactName: ownerName,
      );

      _rememberLinks(owner);

      await _player.setFilePath(path);
      await _player.setSpeed(state.speed);

      // Deliberately not awaited: just_audio's play() completes when playback
      // *finishes*, not when it starts. Awaiting it held the hand-over guard
      // for the whole of the next note, so that note's own completion was
      // swallowed and a run stopped after one step.
      unawaited(_player.play());
    } catch (e) {
      print('[VoicePlayer] could not play $mediaId: $e');

      state = const VoicePlayback();
    }
  }

  /// Keep the freshest non-empty set of links for [owner].
  void _rememberLinks(int? owner) {
    if (owner == null) return;

    final links = _ref.read(voiceLinksProvider(owner));

    // An empty read means the thread is closed, not that the run ended; the
    // copy we already hold is better than nothing.
    if (links.isEmpty && _linksOwner == owner) return;

    _links = links;
    _linksOwner = owner;
  }

  Future<void> pause() => _player.pause();

  Future<void> resume() async => unawaited(_player.play());

  /// Stop and let go of the note entirely — the banner's close button.
  Future<void> stop() async {
    await _player.stop();

    if (mounted) state = VoicePlayback(speed: state.speed);
  }

  Future<void> seekFraction(double fraction) async {
    final total = state.duration;

    if (total == null || total == Duration.zero) return;

    await _player.seek(
      Duration(milliseconds: (total.inMilliseconds * fraction).round()),
    );
  }

  Future<void> cycleSpeed() async {
    final next = _speeds[(_speeds.indexOf(state.speed) + 1) % _speeds.length];

    state = state.copyWith(speed: next);

    await _player.setSpeed(next);
  }

  /// Play the next note in the run, after the boundary cue.
  Future<void> _onCompleted() async {
    if (_advancing) return;

    _advancing = true;

    try {
      await _handOver();
    } finally {
      _advancing = false;
    }
  }

  Future<void> _handOver() async {
    final finished = state.mediaId;
    final owner = state.contactId;
    final ownerName = state.contactName;

    await _player.pause();
    await _player.seek(Duration.zero);

    if (finished == null || owner == null) {
      _release();
      return;
    }

    _rememberLinks(owner);

    final follower = _linksOwner == owner ? _links[finished] : null;

    // End of the run: let go of the note so the banner goes away. Leaving it
    // loaded kept the mini player up, paused at 0:00, after every note.
    if (follower == null) {
      _release();
      return;
    }

    final path = _paths[follower];

    await VoiceChime.instance.play();

    if (!mounted) return;

    // Known file: start it here, so a run keeps going even if the next bubble
    // is off-screen. Otherwise ask whichever bubble is mounted to start it.
    if (path != null) {
      await play(follower, path, contactId: owner, contactName: ownerName);
      // play() now returns once the note has *started*, so the guard is
      // released here rather than when the whole run ends.
    } else {
      // The next file isn't known here. A mounted bubble picks the request up
      // and play() loads it again; with none mounted (the agent is in another
      // chat) the run ends, and the banner must not hang on the finished note.
      _release();
      _ref.read(voiceChainProvider.notifier).requestAutoPlay(follower);
    }
  }

  /// Forget the loaded note without touching the player — it is already
  /// paused and rewound.
  void _release() {
    if (mounted) state = VoicePlayback(speed: state.speed);
  }

  @override
  void dispose() {
    _position?.cancel();
    _duration?.cancel();
    _playerState?.cancel();
    _player.dispose();
    super.dispose();
  }
}

final voicePlayerProvider =
    StateNotifierProvider<VoicePlayerNotifier, VoicePlayback>(
  VoicePlayerNotifier.new,
);

/// How long a voice note runs, read once per file and kept.
///
/// Cached outside the widget on purpose: the duration used to be discovered by
/// each bubble's own player, so it vanished every time the bubble was rebuilt
/// and the timestamp fell back to `--:--`.
final voiceDurationProvider =
    FutureProvider.family<Duration?, String>((ref, path) async {
  final player = AudioPlayer();

  try {
    return await player.setFilePath(path);
  } catch (_) {
    return null;
  } finally {
    await player.dispose();
  }
});
