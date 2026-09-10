import 'dart:io';

import 'package:audio_waveforms/audio_waveforms.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Real amplitudes for one voice note, decoded from the file on this device.
///
/// Only the decoder half of `audio_waveforms` is used here. Playback stays with
/// just_audio, which already owns seeking, speed and the position stream — a
/// second player on the same file would fight it for the audio session that
/// CallKit and WebRTC are also negotiating.
///
/// Decoding is per-file and cached for the session, because it reads the whole
/// clip: doing it again on every rebuild would make scrolling a long thread
/// stutter. A failure is cached as an empty list so a file that cannot be
/// decoded is not retried on every frame — the bubble simply keeps the seeded
/// shape, which is a fine waveform to look at and still seeks correctly.
final waveformProvider =
    FutureProvider.family<List<double>, String>((ref, path) async {
  if (path.isEmpty || !File(path).existsSync()) return const [];

  // Enough bars for the widest bubble; the painter samples down from these.
  const sampleCount = 64;

  final controller = PlayerController();

  try {
    final samples = await controller.waveformExtraction.extractWaveformData(
      path: path,
      noOfSamples: sampleCount,
    );

    return _normalise(samples);
  } catch (_) {
    // Ogg/Opus on iOS is the expected case here: AVFoundation will not decode
    // it, so extraction throws rather than returning silence.
    return const [];
  } finally {
    controller.dispose();
  }
});

/// Scale peaks into 0..1 against the loudest bar.
///
/// Raw extraction is relative to full scale, so a normally-spoken note comes
/// back as a row of stubs. Scaling to the note's own loudest moment is what
/// makes the shape read as speech, and it is what WhatsApp appears to do too.
List<double> _normalise(List<double> samples) {
  if (samples.isEmpty) return const [];

  var peak = 0.0;

  for (final sample in samples) {
    final magnitude = sample.abs();

    if (magnitude > peak) peak = magnitude;
  }

  // Digital silence: nothing to scale against, and dividing would give NaN.
  if (peak <= 0) return const [];

  return [
    for (final sample in samples) (sample.abs() / peak).clamp(0.06, 1.0),
  ];
}
