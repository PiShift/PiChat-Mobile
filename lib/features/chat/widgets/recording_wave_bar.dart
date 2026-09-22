import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' show FontFeature;

import 'package:flutter/material.dart';
import 'package:record/record.dart';

/// The live bar shown while a voice note is being recorded: elapsed time and a
/// waveform that scrolls as you speak.
///
/// This owns its own timer and amplitude subscription on purpose. The elapsed
/// counter used to live in the thread's own state, so every tick rebuilt the
/// whole conversation four times a second — every audio bubble re-ran its file
/// checks and its duration label flickered while you recorded. Keeping the
/// ticking state down here means nothing above this widget rebuilds at all.
///
/// Levels come from `record`, the same recorder that is writing the file. A
/// second recorder just to draw bars would fight it for the microphone and for
/// the audio session that CallKit and WebRTC also negotiate.
class RecordingWaveBar extends StatefulWidget {
  const RecordingWaveBar({
    required this.recorder,
    required this.startedAt,
    required this.barColor,
    required this.textColor,
    super.key,
  });

  final AudioRecorder recorder;
  final DateTime startedAt;
  final Color barColor;
  final Color textColor;

  @override
  State<RecordingWaveBar> createState() => _RecordingWaveBarState();
}

class _RecordingWaveBarState extends State<RecordingWaveBar> {
  static const _sampleInterval = Duration(milliseconds: 60);

  /// How many bars fit before the oldest scrolls off the left.
  static const _windowSize = 56;

  final List<double> _levels = [];

  Timer? _ticker;
  StreamSubscription<Amplitude>? _amplitudes;
  Duration _elapsed = Duration.zero;

  @override
  void initState() {
    super.initState();

    _ticker = Timer.periodic(const Duration(milliseconds: 200), (_) {
      if (!mounted) return;

      setState(() => _elapsed = DateTime.now().difference(widget.startedAt));
    });

    _amplitudes =
        widget.recorder.onAmplitudeChanged(_sampleInterval).listen((amplitude) {
      if (!mounted) return;

      setState(() {
        _levels.add(_normalise(amplitude.current));

        if (_levels.length > _windowSize) _levels.removeAt(0);
      });
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _amplitudes?.cancel();
    super.dispose();
  }

  /// Map dBFS onto 0..1.
  ///
  /// `current` is decibels relative to full scale, so it is negative and
  /// reaches 0 only when clipping. Quiet-room noise sits around -45 dB, which
  /// is treated as the floor; below that the bar stays at its minimum instead
  /// of disappearing, so the line never breaks while someone pauses for breath.
  static double _normalise(double decibels) {
    const floor = -45.0;

    if (!decibels.isFinite) return 0.06;

    return ((decibels - floor) / -floor).clamp(0.06, 1.0);
  }

  @override
  Widget build(BuildContext context) {
    final minutes = _elapsed.inMinutes.toString().padLeft(2, '0');
    final seconds = (_elapsed.inSeconds % 60).toString().padLeft(2, '0');

    return Row(
      children: [
        Text(
          '$minutes:$seconds',
          style: TextStyle(
            fontSize: 14,
            fontFeatures: const [FontFeature.tabularFigures()],
            color: widget.textColor,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: SizedBox(
            height: 24,
            child: CustomPaint(
              painter: _LiveWavePainter(
                // A copy, not `_levels` itself. Passing the live list meant
                // the painter compared the same object against itself in
                // shouldRepaint, which was always false — the bars only
                // redrew when something else forced a repaint, so the wave
                // lurched instead of moving with the voice.
                levels: List<double>.of(_levels),
                windowSize: _windowSize,
                color: widget.barColor,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _LiveWavePainter extends CustomPainter {
  _LiveWavePainter({
    required this.levels,
    required this.windowSize,
    required this.color,
  });

  final List<double> levels;
  final int windowSize;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || levels.isEmpty) return;

    // Bars keep a fixed slot width so the waveform grows from the left and
    // scrolls, rather than stretching wider as more samples arrive.
    final slot = size.width / windowSize;
    final barWidth = math.max(1.5, slot * 0.55);
    final centre = size.height / 2;

    final paint = Paint()
      ..color = color
      ..strokeCap = StrokeCap.round
      ..strokeWidth = barWidth;

    for (var i = 0; i < levels.length; i++) {
      final x = slot * i + slot / 2;

      if (x > size.width) break;

      final half = math.max(1.0, levels[i] * centre);

      canvas.drawLine(Offset(x, centre - half), Offset(x, centre + half), paint);
    }
  }

  @override
  bool shouldRepaint(_LiveWavePainter old) {
    if (old.color != color || old.levels.length != levels.length) return true;

    // Once the window is full every sample shifts left, so the length stops
    // changing and only the values differ.
    for (var i = 0; i < levels.length; i++) {
      if (old.levels[i] != levels[i]) return true;
    }

    return false;
  }
}
