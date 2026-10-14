import 'package:flutter/material.dart';

abstract final class AppColors {
  static const background = Color(0xFF04050D);
  static const accent = Color(0xFF5CE1FF);
  static const gold = Color(0xFFFFD166);
  static const danger = Color(0xFFFF4D6D);
  static const textDim = Color(0xFF8A93B8);
  static const panel = Color(0xE6101428);
}

extension ColorFade on Color {
  /// Version-safe opacity helper (avoids withOpacity/withValues API churn).
  Color fade(double opacity) => withAlpha((opacity.clamp(0.0, 1.0) * 255).round());
}

abstract final class AppTheme {
  static ThemeData get dark => ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: AppColors.background,
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.accent,
          brightness: Brightness.dark,
        ),
      );
}
