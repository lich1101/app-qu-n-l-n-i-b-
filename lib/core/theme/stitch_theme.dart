import 'package:flutter/material.dart';

class StitchTheme {
  static Color primaryStrong = const Color(0xFF0F4C81);
  static Color primary = primaryStrong;
  static Color primarySoft = primaryStrong.withValues(alpha: 0.12);
  static const Color bg = Color(0xFFF4F7FB);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceAlt = Color(0xFFEAF1F8);
  static const Color border = Color(0xFFD7E2EE);
  static const Color textMain = Color(0xFF0F172A);
  static const Color textMuted = Color(0xFF516173);
  static const Color textSubtle = Color(0xFF8A98A8);
  static Color successStrong = const Color(0xFF15803D);
  static Color warningStrong = const Color(0xFFC97A10);
  static Color dangerStrong = const Color(0xFFDC2626);
  static Color success = successStrong;
  static Color warning = warningStrong;
  static Color danger = dangerStrong;
  static Color successSoft = successStrong.withValues(alpha: 0.12);
  static Color warningSoft = warningStrong.withValues(alpha: 0.12);
  static Color dangerSoft = dangerStrong.withValues(alpha: 0.12);
  static const Color shadow = Color(0x120F172A);

  static void applyPrimary(Color color) {
    primaryStrong = color;
    primary = color;
    primarySoft = color.withValues(alpha: 0.12);
  }

  static ThemeData light() {
    final ColorScheme scheme = ColorScheme.fromSeed(
      seedColor: primary,
      brightness: Brightness.light,
    ).copyWith(
      primary: primary,
      onPrimary: Colors.white,
      secondary: const Color(0xFF6B7280),
      onSecondary: Colors.white,
      surface: surface,
      onSurface: textMain,
      error: danger,
      onError: Colors.white,
    );

    final ThemeData base = ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: bg,
      fontFamily: 'Inter',
      visualDensity: VisualDensity.standard,
    );

    return base.copyWith(
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        foregroundColor: textMain,
        iconTheme: IconThemeData(color: textMain),
        titleTextStyle: TextStyle(
          color: textMain,
          fontSize: 18,
          fontWeight: FontWeight.w700,
        ),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: surface,
        selectedItemColor: primary,
        unselectedItemColor: textSubtle,
        selectedLabelStyle: TextStyle(fontWeight: FontWeight.w600, fontSize: 11),
        unselectedLabelStyle: TextStyle(fontWeight: FontWeight.w500, fontSize: 11),
        type: BottomNavigationBarType.fixed,
        showSelectedLabels: true,
        showUnselectedLabels: true,
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: border),
        ),
      ),
      dividerTheme: const DividerThemeData(color: border, thickness: 1),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFFF9FBFD),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        hintStyle: const TextStyle(color: textSubtle),
        labelStyle: const TextStyle(color: textMuted, fontWeight: FontWeight.w600),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: primary, width: 1.4),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: danger),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: danger, width: 1.4),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: surfaceAlt,
        selectedColor: primarySoft,
        side: const BorderSide(color: border),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(999),
        ),
        labelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 15),
          elevation: 0,
          backgroundColor: primary,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          textStyle: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 15),
          foregroundColor: textMain,
          side: const BorderSide(color: border),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          textStyle: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          textStyle: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      textTheme: base.textTheme.copyWith(
        titleLarge: const TextStyle(
          fontWeight: FontWeight.w700,
          fontSize: 24,
          color: textMain,
        ),
        titleMedium: const TextStyle(
          fontWeight: FontWeight.w700,
          fontSize: 19,
          color: textMain,
        ),
        titleSmall: const TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: 14,
          color: textMain,
        ),
        bodyLarge: const TextStyle(fontSize: 16, color: textMain, height: 1.45),
        bodyMedium: const TextStyle(fontSize: 14, color: textMain, height: 1.45),
        bodySmall: const TextStyle(fontSize: 12, color: textMuted, height: 1.35),
      ),
    );
  }
}
