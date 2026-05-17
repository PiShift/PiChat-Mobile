import 'package:flutter/painting.dart';

/// Design-system shadow tokens.
///
/// Base colour: #231F20 (PiPalette.ink900).
/// Opacity steps: 8 % / 10 % / 12 % / 16 %.
abstract class PiShadow {
  PiShadow._();

  /// No shadow — flat surface.
  static const List<BoxShadow> shadow0 = [];

  /// Subtle depth — cards, list tiles.
  /// `0 1px 3px rgba(35,31,32, 0.08)`
  static const List<BoxShadow> shadow1 = [
    BoxShadow(
      color: Color(0x14231F20), // 0.08 × 255 ≈ 20 → 0x14
      offset: Offset(0, 1),
      blurRadius: 3,
    ),
  ];

  /// Medium depth — bottom nav, floating bar.
  /// `0 2px 8px rgba(35,31,32, 0.10)`
  static const List<BoxShadow> shadow2 = [
    BoxShadow(
      color: Color(0x1A231F20), // 0.10 × 255 ≈ 26 → 0x1A
      offset: Offset(0, 2),
      blurRadius: 8,
    ),
  ];

  /// Elevated depth — bottom sheets, FAB.
  /// `0 4px 16px rgba(35,31,32, 0.12)`
  static const List<BoxShadow> shadow3 = [
    BoxShadow(
      color: Color(0x1F231F20), // 0.12 × 255 ≈ 31 → 0x1F
      offset: Offset(0, 4),
      blurRadius: 16,
    ),
  ];

  /// Max depth — modals, dialogs.
  /// `0 8px 32px rgba(35,31,32, 0.16)`
  static const List<BoxShadow> shadow4 = [
    BoxShadow(
      color: Color(0x29231F20), // 0.16 × 255 ≈ 41 → 0x29
      offset: Offset(0, 8),
      blurRadius: 32,
    ),
  ];
}
