import 'package:flutter/animation.dart';

/// Design-system motion tokens — durations and easing curves.
abstract class PiMotion {
  PiMotion._();

  // ── Durations ────────────────────────────────────────────────────────────
  /// 150 ms — micro-interactions, state changes (hover/press).
  static const Duration fast     = Duration(milliseconds: 150);

  /// 250 ms — page transitions, sheet open/close.
  static const Duration normal   = Duration(milliseconds: 250);

  /// 350 ms — modal appear, large layout shifts.
  static const Duration slow     = Duration(milliseconds: 350);

  /// 500 ms — splash screen, onboarding sequences.
  static const Duration verySlow = Duration(milliseconds: 500);

  // ── Easing curves ────────────────────────────────────────────────────────
  /// Fast deceleration — elements entering screen.
  static const Curve easeOut   = Curves.easeOut;

  /// Symmetric acceleration/deceleration — general transitions.
  static const Curve easeInOut = Curves.easeInOut;
}
