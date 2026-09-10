import 'dart:math' as math;

import 'package:flutter/material.dart';

/// The bar chart behind a voice note, with a playhead.
///
/// Draws real decoded amplitudes when [amplitudes] is supplied. Decoding reads
/// the whole clip, so it happens off the build path — until it lands, and on
/// any file the device cannot decode, the bars fall back to a shape seeded from
/// the message id. That fallback is stable per message, reads as speech, and
/// seeks correctly, so a bubble is never blank and never jumps around.
class VoiceWaveform extends StatelessWidget {
  const VoiceWaveform({
    required this.seed,
    required this.progress,
    this.amplitudes,
    required this.playedColor,
    required this.remainingColor,
    this.height = 28,
    this.onSeek,
    super.key,
  });

  /// Stable per message, so the same note always draws the same shape.
  final int seed;

  /// Decoded peaks in 0..1, or null while they are still being read.
  final List<double>? amplitudes;

  /// 0..1 playback position.
  final double progress;

  final Color playedColor;
  final Color remainingColor;
  final double height;

  /// Called with a 0..1 fraction when the listener taps or drags the bars.
  final ValueChanged<double>? onSeek;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth.isFinite ? constraints.maxWidth : 160.0;

        // ~3px bar + 2px gap. Clamped so very narrow bubbles stay legible.
        final barCount = (width / 5).floor().clamp(12, 64);

        void seekTo(Offset localPosition) {
          if (onSeek == null || width <= 0) return;

          onSeek!((localPosition.dx / width).clamp(0.0, 1.0));
        }

        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (d) => seekTo(d.localPosition),
          onHorizontalDragStart: (d) => seekTo(d.localPosition),
          onHorizontalDragUpdate: (d) => seekTo(d.localPosition),
          child: SizedBox(
            height: height,
            width: double.infinity,
            child: CustomPaint(
              painter: _WaveformPainter(
                amplitudes: _resample(amplitudes, barCount) ??
                    _amplitudesFor(seed, barCount),
                progress: progress.clamp(0.0, 1.0),
                playedColor: playedColor,
                remainingColor: remainingColor,
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Fit decoded peaks to the number of bars this bubble can show.
///
/// The decoder is asked for a fixed count, but bubble width varies with the
/// screen, so the samples are bucketed and each bucket keeps its loudest value.
/// Averaging instead would flatten the transients that make speech legible.
List<double>? _resample(List<double>? source, int count) {
  if (source == null || source.isEmpty || count <= 0) return null;

  if (source.length == count) return source;

  return List<double>.generate(count, (i) {
    final start = (i * source.length / count).floor();
    final end = math.max(start + 1, ((i + 1) * source.length / count).floor());

    var peak = 0.0;

    for (var j = start; j < end && j < source.length; j++) {
      if (source[j] > peak) peak = source[j];
    }

    return peak;
  });
}

/// A speech-like envelope: random peaks smoothed against their neighbours so the
/// result rises and falls instead of looking like noise.
List<double> _amplitudesFor(int seed, int count) {
  final random = math.Random(seed);
  final raw = List<double>.generate(count, (_) => random.nextDouble());
  final smoothed = <double>[];

  for (var i = 0; i < count; i++) {
    final prev = i > 0 ? raw[i - 1] : raw[i];
    final next = i < count - 1 ? raw[i + 1] : raw[i];
    final value = (prev + raw[i] * 2 + next) / 4;

    // Taper the very start and end so a note reads as fading in and out.
    final edge = math.min(i, count - 1 - i) / math.max(1, count * 0.12);
    final taper = edge.clamp(0.35, 1.0);

    smoothed.add((0.18 + value * 0.82) * taper);
  }

  return smoothed;
}

class _WaveformPainter extends CustomPainter {
  _WaveformPainter({
    required this.amplitudes,
    required this.progress,
    required this.playedColor,
    required this.remainingColor,
  });

  final List<double> amplitudes;
  final double progress;
  final Color playedColor;
  final Color remainingColor;

  @override
  void paint(Canvas canvas, Size size) {
    if (amplitudes.isEmpty || size.width <= 0) return;

    final slot = size.width / amplitudes.length;
    final barWidth = math.max(2.0, slot * 0.55);
    final centreY = size.height / 2;
    final playedUpTo = size.width * progress;

    final paint = Paint()..strokeCap = StrokeCap.round;

    for (var i = 0; i < amplitudes.length; i++) {
      final x = slot * i + slot / 2;
      final barHeight = math.max(3.0, amplitudes[i] * size.height);

      paint.color = x <= playedUpTo ? playedColor : remainingColor;

      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: Offset(x, centreY),
            width: barWidth,
            height: barHeight,
          ),
          Radius.circular(barWidth / 2),
        ),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_WaveformPainter old) {
    return old.progress != progress ||
        old.playedColor != playedColor ||
        old.remainingColor != remainingColor ||
        old.amplitudes.length != amplitudes.length;
  }
}
