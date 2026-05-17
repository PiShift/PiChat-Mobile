import 'package:flutter/material.dart';

/// Dynamic sizing helper — all font sizes and dimensions must use this class.
/// Never hardcode pixel values for sizes directly in widgets.
///
/// ```dart
/// fontSize: Sz.sp(context, 14)
/// width:    Sz.w(context, 44)
/// height:   Sz.h(context, 56)
/// ```
class Sz {
  Sz._();

  // Design reference width — all sizes are relative to this baseline.
  static const double _baseWidth = 390.0; // iPhone 14 Pro logical width

  static double _scale(BuildContext ctx) {
    final w = MediaQuery.sizeOf(ctx).width;
    // Clamp so tablets don't grow unbounded.
    return (w / _baseWidth).clamp(0.8, 1.3);
  }

  /// Scaled font / icon size.
  static double sp(BuildContext ctx, double v) => (v * _scale(ctx)).roundToDouble();

  /// Scaled width.
  static double w(BuildContext ctx, double v) => (v * _scale(ctx)).roundToDouble();

  /// Scaled height.
  static double h(BuildContext ctx, double v) => (v * _scale(ctx)).roundToDouble();
}
