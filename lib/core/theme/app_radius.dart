import 'package:flutter/painting.dart';

/// Design-system border-radius tokens.
///
/// Raw values (double) are exposed as `PiRadius.xs` etc.
/// Pre-built [BorderRadius] instances are exposed as `PiRadius.brXS` etc.
abstract class PiRadius {
  PiRadius._();

  // ── Raw values ──────────────────────────────────────────────────────────────
  static const double xs   = 4;   // chips, badges
  static const double sm   = 8;   // inputs, context menus
  static const double md   = 12;  // cards, contact blocks
  static const double lg   = 16;  // bottom sheets top, dialogs
  static const double xl   = 20;  // message bubbles
  static const double full = 999; // avatars, pills, FAB

  // ── BorderRadius shortcuts ───────────────────────────────────────────────
  static const BorderRadius brXS   = BorderRadius.all(Radius.circular(xs));
  static const BorderRadius brSM   = BorderRadius.all(Radius.circular(sm));
  static const BorderRadius brMD   = BorderRadius.all(Radius.circular(md));
  static const BorderRadius brLG   = BorderRadius.all(Radius.circular(lg));
  static const BorderRadius brXL   = BorderRadius.all(Radius.circular(xl));
  static const BorderRadius brFull = BorderRadius.all(Radius.circular(full));
}
