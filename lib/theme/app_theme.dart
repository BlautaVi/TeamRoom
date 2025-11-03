import 'package:flutter/material.dart';

class AppColors {
  static const Color primary = Color(0xFF62567E);
  static const Color secondary = Color(0xFFB6A5DE);
  static const Color tertiary = Color(0xFF7C6BA3);
  static const Color surface = Colors.white;
  static const Color background = Colors.white;
  static const Color onPrimary = Colors.white;
  static const Color onSurface = Color(0xFF7C6BA3); // unified purple tone for text
  static const Color outline = Color(0xFFD2CDE4);
}

class AppTheme {
  static ThemeData get lightTheme {
    final ColorScheme scheme = ColorScheme(
      brightness: Brightness.light,
      primary: AppColors.primary,
      onPrimary: AppColors.onPrimary,
      secondary: AppColors.secondary,
      onSecondary: AppColors.onPrimary,
      tertiary: AppColors.tertiary,
      onTertiary: AppColors.onPrimary,
      error: const Color(0xFFB00020),
      onError: Colors.white,
      surface: AppColors.surface,
      onSurface: AppColors.onSurface,
      surfaceContainerHighest: const Color(0xFFF6F4FA),
      // Fallbacks for non-M3 fields
      surfaceVariant: const Color(0xFFF2EFF7),
      outline: AppColors.outline,
      outlineVariant: AppColors.outline,
      scrim: Colors.black54,
      shadow: Colors.black12,
      inverseSurface: const Color(0xFF2B2740),
      onInverseSurface: Colors.white,
      inversePrimary: AppColors.secondary,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: AppColors.background,
      fontFamily: 'InstrumentSans',
      textTheme: const TextTheme().apply(
        bodyColor: AppColors.onSurface,
        displayColor: AppColors.onSurface,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.secondary,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primary,
          side: const BorderSide(color: AppColors.outline),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.6),
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: FadeUpwardsPageTransitionsBuilder(),
          TargetPlatform.iOS: FadeUpwardsPageTransitionsBuilder(),
          TargetPlatform.windows: FadeUpwardsPageTransitionsBuilder(),
          TargetPlatform.linux: FadeUpwardsPageTransitionsBuilder(),
          TargetPlatform.macOS: FadeUpwardsPageTransitionsBuilder(),
        },
      ),
      splashFactory: InkSparkle.splashFactory,
      visualDensity: VisualDensity.standard,
    );
  }
}


