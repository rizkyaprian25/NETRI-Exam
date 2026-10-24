// Tema Desain Terpadu NETRI Exam (Apple HIG & UI/UX Pro Max)
// Menggunakan token desain dari tokens.g.dart sebagai sumber kebenaran tunggal (SSOT).

import 'package:flutter/material.dart';
import 'tokens.g.dart';

class NetriTheme {
  // Mencegah instansiasi class utilitas tema
  NetriTheme._();

  /// Tema Terang (Light Mode)
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: NetriColors.bgLight,
      colorScheme: const ColorScheme(
        brightness: Brightness.light,
        primary: NetriColors.brandLight,
        onPrimary: Colors.white,
        secondary: NetriColors.brandSurfaceLight,
        onSecondary: NetriColors.brandLight,
        surface: NetriColors.surfaceLight,
        onSurface: NetriColors.textPrimaryLight,
        error: NetriColors.stateDangerLight,
        onError: Colors.white,
      ),
      textTheme: _buildTextTheme(
        primaryColor: NetriColors.textPrimaryLight,
        secondaryColor: NetriColors.textSecondaryLight,
      ),
      cardTheme: CardThemeData(
        color: NetriColors.surfaceLight,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(NetriRadius.md),
          side: const BorderSide(color: NetriColors.borderLight, width: 1),
        ),
        margin: const EdgeInsets.symmetric(
          horizontal: NetriSpacing.space4,
          vertical: NetriSpacing.space2,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          elevation: 0,
          backgroundColor: NetriColors.brandLight,
          foregroundColor: Colors.white,
          minimumSize: const Size(NetriExamMetrics.minTouchTarget, 48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(NetriRadius.md),
          ),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: NetriColors.textPrimaryLight,
          minimumSize: const Size(NetriExamMetrics.minTouchTarget, 48),
          side: const BorderSide(color: NetriColors.borderLight),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(NetriRadius.md),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: NetriColors.surfaceLight,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: NetriSpacing.space4,
          vertical: NetriSpacing.space3,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(NetriRadius.sm),
          borderSide: const BorderSide(color: NetriColors.borderLight),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(NetriRadius.sm),
          borderSide: const BorderSide(color: NetriColors.borderLight),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(NetriRadius.sm),
          borderSide: const BorderSide(color: NetriColors.brandLight, width: 2),
        ),
      ),
    );
  }

  /// Tema Gelap (Dark Mode / OLED Friendly)
  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: NetriColors.bgDark,
      colorScheme: const ColorScheme(
        brightness: Brightness.dark,
        primary: NetriColors.brandDark,
        onPrimary: NetriColors.bgDark,
        secondary: NetriColors.brandSurfaceDark,
        onSecondary: NetriColors.brandDark,
        surface: NetriColors.surfaceDark,
        onSurface: NetriColors.textPrimaryDark,
        error: NetriColors.stateDangerDark,
        onError: Colors.black,
      ),
      textTheme: _buildTextTheme(
        primaryColor: NetriColors.textPrimaryDark,
        secondaryColor: NetriColors.textSecondaryDark,
      ),
      cardTheme: CardThemeData(
        color: NetriColors.surfaceDark,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(NetriRadius.md),
          side: const BorderSide(color: NetriColors.borderDark, width: 1),
        ),
        margin: const EdgeInsets.symmetric(
          horizontal: NetriSpacing.space4,
          vertical: NetriSpacing.space2,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          elevation: 0,
          backgroundColor: NetriColors.brandDark,
          foregroundColor: NetriColors.bgDark,
          minimumSize: const Size(NetriExamMetrics.minTouchTarget, 48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(NetriRadius.md),
          ),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: NetriColors.textPrimaryDark,
          minimumSize: const Size(NetriExamMetrics.minTouchTarget, 48),
          side: const BorderSide(color: NetriColors.borderDark),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(NetriRadius.md),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: NetriColors.surfaceDark,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: NetriSpacing.space4,
          vertical: NetriSpacing.space3,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(NetriRadius.sm),
          borderSide: const BorderSide(color: NetriColors.borderDark),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(NetriRadius.sm),
          borderSide: const BorderSide(color: NetriColors.borderDark),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(NetriRadius.sm),
          borderSide: const BorderSide(color: NetriColors.brandDark, width: 2),
        ),
      ),
    );
  }

  /// Membangun hirarki tipografi dengan Tabular Figures untuk stabilitas visual
  static TextTheme _buildTextTheme({
    required Color primaryColor,
    required Color secondaryColor,
  }) {
    // Font feature tabular figures memastikan angka memiliki lebar yang sama,
    // mencegah layout shift (CLS < 0.1) saat countdown timer berdetak tiap detik.
    const fontFeatures = [FontFeature.tabularFigures()];

    return TextTheme(
      displayLarge: TextStyle(
        fontSize: 32,
        fontWeight: FontWeight.w700,
        color: primaryColor,
        fontFeatures: fontFeatures,
        letterSpacing: -0.5,
      ),
      titleLarge: TextStyle(
        fontSize: 22,
        fontWeight: FontWeight.w600,
        color: primaryColor,
        letterSpacing: -0.2,
      ),
      titleMedium: TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: primaryColor,
      ),
      bodyLarge: TextStyle(
        fontSize: 17,
        fontWeight: FontWeight.w400,
        color: primaryColor,
        height: 1.4,
      ),
      bodyMedium: TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w400,
        color: secondaryColor,
        height: 1.4,
      ),
      labelLarge: const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w600,
      ),
      labelSmall: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w500,
        color: secondaryColor,
        fontFeatures: fontFeatures,
      ),
    );
  }
}
