import 'dart:math' as math;

import 'package:flutter/material.dart';

/// The bar chart behind a voice note, with a playhead.
///
/// The bars are derived from the message's own id rather than decoded from the
/// audio. Reading real amplitudes means decoding every opus file on the device,
/// which is slow and would have to happen before the bubble could be drawn; a
/// seeded shape is stable for a given message, looks like speech, and costs
/// nothing. Swap [_amplitudesFor] for decoded samples if true accuracy is ever
/// worth the cost.
class VoiceWaveform extends StatelessWidget {
  const VoiceWaveform({
    required this.seed,
    required this.progress,
    required this.playedColor,
    required this.remainingColor,
    this.height = 28,
    this.onSeek,
    super.key,
  });

  /// Stable per message, so the same note always draws the same shape.
  final int seed;

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
                amplitudes: _amplitudesFor(seed, barCount),
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
