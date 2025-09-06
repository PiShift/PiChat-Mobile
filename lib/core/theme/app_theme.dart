// lib/core/theme/app_theme.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class AppColors {
  static const primary = Color(0xFFff7300);
  static const secondary = Color(0xFF000000);
  static const error = Color(0xFFD32F2F);
  static const background = Colors.white;
}

final appThemeProvider = Provider<ThemeData>((ref) {
  return ThemeData(
    useMaterial3: true,
    primaryColor: AppColors.primary,
    colorScheme: ColorScheme.fromSeed(
      seedColor: AppColors.primary,
      primary: AppColors.primary,
      secondary: AppColors.secondary,
      error: AppColors.error,
    ),
    scaffoldBackgroundColor: AppColors.background,
    inputDecorationTheme: const InputDecorationTheme(
      border: OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(8)),
      ),
    ),
    textTheme: const TextTheme(
      bodyMedium: TextStyle(fontSize: 14, color: Colors.black87),
      titleLarge: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
    ),
  );
});