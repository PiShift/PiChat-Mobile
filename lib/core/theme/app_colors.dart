import 'package:flutter/material.dart';

/// Design token colors — single source of truth.
/// Never use raw hex values anywhere else in the codebase.
/// Reference these tokens or [PiColors] (the context-aware accessor) instead.
abstract class PiPalette {
  // ── Primary / Orange ───────────────────────────────────────────────────────
  static const primary50  = Color(0xFFFFF4E6);
  static const primary100 = Color(0xFFFFE4BE);
  static const primary200 = Color(0xFFFFD193);
  static const primary300 = Color(0xFFFFBE68);
  static const primary400 = Color(0xFFFFAE46);
  static const primary500 = Color(0xFFFF7300); // brand primary
  static const primary600 = Color(0xFFE86600);
  static const primary700 = Color(0xFFCC5A00);
  static const primary800 = Color(0xFFA34800);
  static const primary900 = Color(0xFF7A3600);

  // ── Ink / Dark ─────────────────────────────────────────────────────────────
  static const ink900 = Color(0xFF231F20);
  static const ink800 = Color(0xFF3D3839);
  static const ink700 = Color(0xFF575354);
  static const ink600 = Color(0xFF706C6D);
  static const ink500 = Color(0xFF8A8687);
  static const ink400 = Color(0xFFA3A0A1);
  static const ink300 = Color(0xFFC4C2C2);
  static const ink200 = Color(0xFFE0DFDF);
  static const ink100 = Color(0xFFF0EFEF);
  static const ink50  = Color(0xFFF8F7F7);

  // ── Semantic ───────────────────────────────────────────────────────────────
  static const success500 = Color(0xFF22C55E);
  static const success100 = Color(0xFFDCFCE7);
  static const warning500 = Color(0xFFF59E0B);
  static const warning100 = Color(0xFFFEF3C7);
  static const error500   = Color(0xFFEF4444);
  static const error100   = Color(0xFFFEE2E2);
  static const info500    = Color(0xFF3B82F6);
  static const info100    = Color(0xFFDBEAFE);

  // ── Neutral ────────────────────────────────────────────────────────────────
  static const white = Color(0xFFFFFFFF);
  static const black = Color(0xFF000000);
}

/// Light-mode resolved tokens.
abstract class PiLight {
  static const background    = PiPalette.ink50;         // #F8F7F7
  static const surface       = PiPalette.ink100;        // #F0EFEF
  static const surfaceRaised = PiPalette.white;
  static const textPrimary   = PiPalette.ink900;
  static const textSecondary = PiPalette.ink500;
  static const divider       = PiPalette.ink200;
  static const online        = PiPalette.success500;
  static const bubbleSent    = PiPalette.primary50;     // #FFF4E6
  static const bubbleSentBorder    = PiPalette.primary100;
  static const bubbleReceived      = PiPalette.white;
  static const bubbleReceivedBorder = PiPalette.ink200;
  static const overlay       = Color(0x80231F20);
}

/// Dark-mode resolved tokens (warm near-blacks — never pure #000000).
abstract class PiDark {
  static const background    = Color(0xFF0F0E0D);
  static const surface       = Color(0xFF1A1917);
  static const surfaceRaised = Color(0xFF252321);
  static const textPrimary   = Color(0xFFFAF8F5);
  static const textSecondary = Color(0xFF9A9896);
  static const divider       = Color(0xFF2C2A28);
  static const online        = Color(0xFF30D158);
  static const bubbleSent    = Color(0xFF3D2A00);
  static const bubbleSentBorder    = Color(0xFF5A3D00);
  static const bubbleReceived      = Color(0xFF1C1917);
  static const bubbleReceivedBorder = Color(0xFF2C2A28);
  static const overlay       = Color(0x80000000);
  static const error          = Color(0xFFFF453A);
}

/// Context-aware token accessor. Use this everywhere in widgets.
///
/// ```dart
/// color: PiColors.of(context).textPrimary
/// ```
class PiColors {
  const PiColors._({
    required this.background,
    required this.surface,
    required this.surfaceRaised,
    required this.textPrimary,
    required this.textSecondary,
    required this.divider,
    required this.online,
    required this.bubbleSent,
    required this.bubbleSentBorder,
    required this.bubbleReceived,
    required this.bubbleReceivedBorder,
    required this.overlay,
    required this.error,
  });

  final Color background;
  final Color surface;
  final Color surfaceRaised;
  final Color textPrimary;
  final Color textSecondary;
  final Color divider;
  final Color online;
  final Color bubbleSent;
  final Color bubbleSentBorder;
  final Color bubbleReceived;
  final Color bubbleReceivedBorder;
  final Color overlay;
  final Color error;

  // Always-fixed tokens (same in light + dark):
  Color get primary500   => PiPalette.primary500;
  Color get primary600   => PiPalette.primary600;
  Color get primary50    => PiPalette.primary50;
  Color get primary100   => PiPalette.primary100;
  Color get primary200   => PiPalette.primary200;
  Color get success500   => PiPalette.success500;
  Color get success100   => PiPalette.success100;
  Color get warning500   => PiPalette.warning500;
  Color get warning100   => PiPalette.warning100;
  Color get info500      => PiPalette.info500;
  Color get info100      => PiPalette.info100;
  Color get white        => PiPalette.white;
  Color get ink900       => PiPalette.ink900;
  Color get ink600       => PiPalette.ink600;
  Color get ink500       => PiPalette.ink500;
  Color get ink400       => PiPalette.ink400;
  Color get ink300       => PiPalette.ink300;
  Color get ink200       => PiPalette.ink200;
  Color get ink100       => PiPalette.ink100;

  static const PiColors _light = PiColors._(
    background:           PiLight.background,
    surface:              PiLight.surface,
    surfaceRaised:        PiLight.surfaceRaised,
    textPrimary:          PiLight.textPrimary,
    textSecondary:        PiLight.textSecondary,
    divider:              PiLight.divider,
    online:               PiLight.online,
    bubbleSent:           PiLight.bubbleSent,
    bubbleSentBorder:     PiLight.bubbleSentBorder,
    bubbleReceived:       PiLight.bubbleReceived,
    bubbleReceivedBorder: PiLight.bubbleReceivedBorder,
    overlay:              PiLight.overlay,
    error:                PiPalette.error500,
  );

  static const PiColors _dark = PiColors._(
    background:           PiDark.background,
    surface:              PiDark.surface,
    surfaceRaised:        PiDark.surfaceRaised,
    textPrimary:          PiDark.textPrimary,
    textSecondary:        PiDark.textSecondary,
    divider:              PiDark.divider,
    online:               PiDark.online,
    bubbleSent:           PiDark.bubbleSent,
    bubbleSentBorder:     PiDark.bubbleSentBorder,
    bubbleReceived:       PiDark.bubbleReceived,
    bubbleReceivedBorder: PiDark.bubbleReceivedBorder,
    overlay:              PiDark.overlay,
    error:                PiDark.error,
  );

  /// Returns the correct token set for the current [BuildContext] brightness.
  static PiColors of(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark ? _dark : _light;
  }
}
