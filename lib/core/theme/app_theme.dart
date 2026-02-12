import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';

class AppTheme {
  AppTheme._();

  // ══════════════════════════════════════════════════════════
  //  DARK THEME — 赛博朋克 / Cyberpunk
  // ══════════════════════════════════════════════════════════
  static ThemeData get darkTheme {
    return ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: AppColors.darkBg,
      canvasColor: AppColors.darkBg,
      colorScheme: const ColorScheme.dark(
        primary: AppColors.neonCyan,
        secondary: AppColors.neonMagenta,
        tertiary: AppColors.neonGreen,
        surface: AppColors.darkSurface,
        onPrimary: AppColors.darkBg,
        onSecondary: AppColors.darkBg,
        onSurface: AppColors.darkText,
      ),
      textTheme: _buildTextTheme(isDark: true),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(
          fontFamily: 'Orbitron',
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: AppColors.neonCyan,
          letterSpacing: 2.0,
        ),
      ),
      cardTheme: CardThemeData(
        color: AppColors.darkCard,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppColors.darkCardBorder, width: 1),
        ),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: AppColors.darkSurface,
        selectedItemColor: AppColors.neonCyan,
        unselectedItemColor: AppColors.darkTextMuted,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.neonCyan,
          foregroundColor: AppColors.darkBg,
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: const TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 14,
            letterSpacing: 1.5,
          ),
        ),
      ),
      iconTheme: const IconThemeData(color: AppColors.neonCyan),
      dividerColor: AppColors.darkCardBorder,
    );
  }

  // ══════════════════════════════════════════════════════════
  //  LIGHT THEME — 企业级 / Enterprise
  // ══════════════════════════════════════════════════════════
  static ThemeData get lightTheme {
    return ThemeData(
      brightness: Brightness.light,
      scaffoldBackgroundColor: AppColors.lightBg,
      canvasColor: AppColors.lightBg,
      colorScheme: const ColorScheme.light(
        primary: AppColors.brandBlue,
        secondary: AppColors.brandIndigo,
        tertiary: AppColors.brandTeal,
        surface: AppColors.lightSurface,
        onPrimary: Colors.white,
        onSecondary: Colors.white,
        onSurface: AppColors.lightText,
      ),
      textTheme: _buildTextTheme(isDark: false),
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.lightSurface,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: GoogleFonts.inter(
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: AppColors.lightText,
          letterSpacing: 0.5,
        ),
        iconTheme: const IconThemeData(color: AppColors.lightText),
        surfaceTintColor: Colors.transparent,
      ),
      cardTheme: CardThemeData(
        color: AppColors.lightCard,
        elevation: 2,
        shadowColor: Colors.black.withValues(alpha: 0.06),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppColors.lightCardBorder, width: 1),
        ),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: AppColors.lightSurface,
        selectedItemColor: AppColors.brandBlue,
        unselectedItemColor: AppColors.lightTextMuted,
        type: BottomNavigationBarType.fixed,
        elevation: 8,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.brandBlue,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: GoogleFonts.inter(
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
          elevation: 2,
        ),
      ),
      iconTheme: const IconThemeData(color: AppColors.brandBlue),
      dividerColor: AppColors.lightCardBorder,
    );
  }

  // ──────────────────────────────────────────────────────────
  //  Text theme builder
  // ──────────────────────────────────────────────────────────
  static TextTheme _buildTextTheme({required bool isDark}) {
    final Color primary = isDark ? AppColors.darkText : AppColors.lightText;
    final Color secondary = isDark
        ? AppColors.darkTextSecondary
        : AppColors.lightTextSecondary;

    if (isDark) {
      // Cyberpunk font stack
      return TextTheme(
        displayLarge: GoogleFonts.orbitron(
          fontSize: 32,
          fontWeight: FontWeight.w900,
          color: AppColors.neonCyan,
          letterSpacing: 3,
        ),
        headlineLarge: GoogleFonts.orbitron(
          fontSize: 24,
          fontWeight: FontWeight.w700,
          color: primary,
          letterSpacing: 2,
        ),
        headlineMedium: GoogleFonts.orbitron(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: primary,
          letterSpacing: 1.5,
        ),
        titleLarge: GoogleFonts.rajdhani(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: primary,
          letterSpacing: 1,
        ),
        titleMedium: GoogleFonts.rajdhani(
          fontSize: 16,
          fontWeight: FontWeight.w500,
          color: primary,
        ),
        bodyLarge: GoogleFonts.jetBrainsMono(
          fontSize: 15,
          fontWeight: FontWeight.w400,
          color: primary,
        ),
        bodyMedium: GoogleFonts.jetBrainsMono(
          fontSize: 13,
          fontWeight: FontWeight.w400,
          color: secondary,
        ),
        labelLarge: GoogleFonts.orbitron(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.5,
        ),
      );
    } else {
      // Enterprise font stack
      return TextTheme(
        displayLarge: GoogleFonts.inter(
          fontSize: 32,
          fontWeight: FontWeight.w800,
          color: primary,
        ),
        headlineLarge: GoogleFonts.inter(
          fontSize: 24,
          fontWeight: FontWeight.w700,
          color: primary,
        ),
        headlineMedium: GoogleFonts.inter(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: primary,
        ),
        titleLarge: GoogleFonts.inter(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: primary,
        ),
        titleMedium: GoogleFonts.inter(
          fontSize: 16,
          fontWeight: FontWeight.w500,
          color: primary,
        ),
        bodyLarge: GoogleFonts.inter(
          fontSize: 15,
          fontWeight: FontWeight.w400,
          color: primary,
        ),
        bodyMedium: GoogleFonts.inter(
          fontSize: 13,
          fontWeight: FontWeight.w400,
          color: secondary,
        ),
        labelLarge: GoogleFonts.inter(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.5,
        ),
      );
    }
  }
}
