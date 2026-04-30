// lib/core/theme/app_theme.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

class AppColors {
  static const primary = Color(0xFFff7300);
  static const secondary = Color(0xFF000000);
  static const error = Color(0xFFD32F2F);
  static const background = Colors.white;
  static const greyBorder = Color(0xFFE0E0E0);
  static const textDark = Color(0xFF2E2E2E);
  static const surface = Color(0xFFF5F5F5);
}

final appThemeProvider = Provider<ThemeData>((ref) {
  final textTheme = GoogleFonts.tajawalTextTheme(
    const TextTheme(
      bodyMedium: TextStyle(fontSize: 14, color: Colors.black87),
      bodySmall: TextStyle(fontSize: 12, color: Colors.black54),
      titleLarge: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
      titleMedium: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
      labelSmall: TextStyle(fontSize: 11),
    ),
  );

  return ThemeData(
    useMaterial3: true,
    primaryColor: AppColors.primary,
    colorScheme: ColorScheme.fromSeed(
      seedColor: AppColors.primary,
      primary: AppColors.primary,
      secondary: AppColors.secondary,
      error: AppColors.error,
      surface: AppColors.surface,
    ),
    scaffoldBackgroundColor: AppColors.background,
    textTheme: textTheme,
    appBarTheme: AppBarTheme(
      backgroundColor: AppColors.background,
      foregroundColor: AppColors.textDark,
      elevation: 0,
      titleTextStyle: GoogleFonts.tajawal(
        fontSize: 18,
        fontWeight: FontWeight.bold,
        color: AppColors.textDark,
      ),
    ),
    inputDecorationTheme: const InputDecorationTheme(
      border: OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(8)),
      ),
    ),
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: Colors.white,
      elevation: 8,
    ),
  );
});