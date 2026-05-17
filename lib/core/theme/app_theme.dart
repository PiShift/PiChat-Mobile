import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_colors.dart';

// Keep a minimal AppColors stub so existing references compile during migration.
@Deprecated('Use PiColors.of(context) or PiPalette constants instead.')
class AppColors {
  static const primary    = PiPalette.primary500;
  static const secondary  = PiPalette.ink900;
  static const error      = PiPalette.error500;
  static const background = PiLight.background;
  static const greyBorder = PiPalette.ink200;
  static const textDark   = PiLight.textPrimary;
  static const surface    = PiLight.surface;
}

// ─── Text theme ──────────────────────────────────────────────────────────────

TextTheme _buildTextTheme({required Brightness brightness}) {
  final base      = brightness == Brightness.dark ? PiDark.textPrimary : PiLight.textPrimary;
  final secondary = brightness == Brightness.dark ? PiDark.textSecondary : PiLight.textSecondary;

  TextStyle s(double size, FontWeight weight, Color color, double lineH) =>
      GoogleFonts.plusJakartaSans(
        fontSize: size,
        fontWeight: weight,
        color: color,
        height: lineH / size,
      );

  return TextTheme(
    displayLarge:   s(28, FontWeight.w800, base,      34),
    displayMedium:  s(24, FontWeight.w700, base,      30),
    headlineLarge:  s(20, FontWeight.w700, base,      26),
    headlineMedium: s(18, FontWeight.w700, base,      24),
    headlineSmall:  s(16, FontWeight.w600, base,      22),
    titleLarge:     s(15, FontWeight.w600, base,      20),
    titleMedium:    s(14, FontWeight.w600, base,      19),
    bodyLarge:      s(14, FontWeight.w400, base,      20),
    bodyMedium:     s(13, FontWeight.w400, secondary, 18),
    bodySmall:      s(12, FontWeight.w400, secondary, 17),
    labelLarge:     s(12, FontWeight.w600, base,      16),
    labelSmall:     s(10, FontWeight.w500, secondary, 14),
  );
}

/// Returns a Tajawal [TextStyle] for Arabic / RTL content.
/// Line height is automatically increased (+30%) per design spec.
TextStyle arabicTextStyle({
  double fontSize = 14,
  FontWeight fontWeight = FontWeight.w400,
  Color? color,
  double? lineHeight,
}) {
  final h = lineHeight ?? fontSize * 1.5;
  return GoogleFonts.tajawal(
    fontSize: fontSize,
    fontWeight: fontWeight,
    color: color,
    height: (h * 1.3) / fontSize,
  );
}

// ─── Light theme ─────────────────────────────────────────────────────────────

ThemeData buildLightTheme() {
  const brightness = Brightness.light;
  final textTheme = _buildTextTheme(brightness: brightness);

  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    primaryColor: PiPalette.primary500,
    colorScheme: const ColorScheme(
      brightness: brightness,
      primary:             PiPalette.primary500,
      onPrimary:           PiPalette.white,
      primaryContainer:    PiPalette.primary100,
      onPrimaryContainer:  PiPalette.primary900,
      secondary:           PiPalette.ink700,
      onSecondary:         PiPalette.white,
      secondaryContainer:  PiPalette.ink100,
      onSecondaryContainer: PiPalette.ink900,
      error:               PiPalette.error500,
      onError:             PiPalette.white,
      errorContainer:      PiPalette.error100,
      onErrorContainer:    PiPalette.error500,
      surface:             PiLight.surfaceRaised,
      onSurface:           PiLight.textPrimary,
      onSurfaceVariant:    PiLight.textSecondary,
      outline:             PiPalette.ink200,
      outlineVariant:      PiPalette.ink100,
      scrim:               PiLight.overlay,
    ),
    scaffoldBackgroundColor: PiLight.background,
    textTheme: textTheme,
    appBarTheme: AppBarTheme(
      backgroundColor: PiLight.surfaceRaised,
      foregroundColor: PiLight.textPrimary,
      elevation: 0,
      scrolledUnderElevation: 0,
      systemOverlayStyle: SystemUiOverlayStyle.dark,
      titleTextStyle: textTheme.headlineLarge,
    ),
    dividerColor: PiLight.divider,
    dividerTheme: const DividerThemeData(
      color: PiLight.divider,
      thickness: 1,
      space: 0,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: PiLight.surfaceRaised,
      hintStyle: GoogleFonts.plusJakartaSans(color: PiPalette.ink400, fontSize: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: PiPalette.ink200),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: PiPalette.ink200),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: PiPalette.primary500, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: PiPalette.error500, width: 2),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    ),
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: PiLight.surfaceRaised,
      selectedItemColor: PiPalette.primary500,
      unselectedItemColor: PiPalette.ink400,
      elevation: 0,
    ),
    cardTheme: CardThemeData(
      color: PiLight.surfaceRaised,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: PiPalette.ink200),
      ),
    ),
  );
}

// ─── Dark theme ──────────────────────────────────────────────────────────────

ThemeData buildDarkTheme() {
  const brightness = Brightness.dark;
  final textTheme = _buildTextTheme(brightness: brightness);

  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    primaryColor: PiPalette.primary500,
    colorScheme: const ColorScheme(
      brightness: brightness,
      primary:             PiPalette.primary500,
      onPrimary:           PiPalette.white,
      primaryContainer:    PiPalette.primary800,
      onPrimaryContainer:  PiPalette.primary100,
      secondary:           PiPalette.ink300,
      onSecondary:         PiDark.surface,
      secondaryContainer:  PiDark.surfaceRaised,
      onSecondaryContainer: PiDark.textPrimary,
      error:               PiDark.error,
      onError:             PiPalette.white,
      errorContainer:      Color(0xFF3B0D0D),
      onErrorContainer:    PiDark.error,
      surface:             PiDark.surfaceRaised,
      onSurface:           PiDark.textPrimary,
      onSurfaceVariant:    PiDark.textSecondary,
      outline:             PiDark.divider,
      outlineVariant:      PiDark.surface,
      scrim:               PiDark.overlay,
    ),
    scaffoldBackgroundColor: PiDark.background,
    textTheme: textTheme,
    appBarTheme: AppBarTheme(
      backgroundColor: PiDark.surface,
      foregroundColor: PiDark.textPrimary,
      elevation: 0,
      scrolledUnderElevation: 0,
      systemOverlayStyle: SystemUiOverlayStyle.light,
      titleTextStyle: textTheme.headlineLarge,
    ),
    dividerColor: PiDark.divider,
    dividerTheme: const DividerThemeData(
      color: PiDark.divider,
      thickness: 1,
      space: 0,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: PiDark.surfaceRaised,
      hintStyle: GoogleFonts.plusJakartaSans(color: PiDark.textSecondary, fontSize: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: PiDark.divider),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: PiDark.divider),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: PiPalette.primary500, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: PiDark.error, width: 2),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    ),
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: PiDark.surface,
      selectedItemColor: PiPalette.primary500,
      unselectedItemColor: PiDark.textSecondary,
      elevation: 0,
    ),
    cardTheme: CardThemeData(
      color: PiDark.surfaceRaised,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: PiDark.divider),
      ),
    ),
  );
}

// ─── Providers ───────────────────────────────────────────────────────────────

// Keep old provider name so existing code using appThemeProvider compiles
// without changes during the migration to the new system.
@Deprecated('Use lightThemeProvider / darkThemeProvider and themeModeProvider.')
final appThemeProvider = Provider<ThemeData>((ref) => buildLightTheme());