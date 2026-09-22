import 'package:just_audio/just_audio.dart';

/// The short tone that marks the boundary between two voice notes.
///
/// Its whole job is to tell an agent that one note ended and another began —
/// with two notes from the same person, back to back, there is otherwise no
/// way to tell where the join was.
///
/// It is a plain asset so it can be swapped without touching this file: drop
/// any short clip at [assetPath] and it will be used instead. The one shipped
/// is a bell rather than a flat sine, because a steady tone with no decay
/// sounds like a test signal.
class VoiceChime {
  VoiceChime._();

  static final VoiceChime instance = VoiceChime._();

  /// Replace the file at this path to change the sound.
  static const assetPath = 'assets/sounds/voice_chime.wav';

  final AudioPlayer _player = AudioPlayer();

  bool _loaded = false;
  Future<void>? _inFlight;

  /// Serialised: two overlapping calls made the second interrupt the first
  /// mid-load, so neither was ever heard.
  Future<void> play() {
    return _inFlight = (_inFlight ?? Future.value()).then((_) => _play());
  }

  Future<void> _play() async {
    try {
      if (!_loaded) {
        await _player.setAsset(assetPath);
        _loaded = true;
      }

      // Rewind rather than reload: reloading each time delayed the start
      // enough to clip the front of a tone this short.
      await _player.seek(Duration.zero);
      await _player.play();
    } catch (e) {
      // A missing cue must not break the chain — the next note still plays.
      // Logged rather than swallowed: a cue that silently does nothing is
      // indistinguishable from one too quiet to hear.
      print('[VoiceChime] could not play cue: $e');
    }
  }

  Future<void> dispose() => _player.dispose();
}
