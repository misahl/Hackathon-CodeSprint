// ─────────────────────────────────────────────────────────────
//  App Theme — Material 3 colour scheme & typography
// ─────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  AppTheme._();

  // ── Brand colours ────────────────────────────────────────────
  static const Color primary    = Color(0xFF1565C0); // Deep Blue
  static const Color secondary  = Color(0xFF0288D1); // Sky Blue
  static const Color accent     = Color(0xFF00BCD4); // Cyan
  static const Color surface    = Color(0xFFF8FAFF);
  static const Color background = Color(0xFFEFF3FB);
  static const Color onPrimary  = Color(0xFFFFFFFF);
  static const Color textPrimary   = Color(0xFF0D1B2A);
  static const Color textSecondary = Color(0xFF5A6B7D);
  static const Color cardSurface   = Color(0xFFFFFFFF);
  static const Color divider       = Color(0xFFDDE3EE);

  // Category colours
  static const Color labColor      = Color(0xFF1565C0);
  static const Color officeColor   = Color(0xFF388E3C);
  static const Color facilityColor = Color(0xFF7B1FA2);
  static const Color hallColor     = Color(0xFFE64A19);

  // ── Light theme ───────────────────────────────────────────────
  static ThemeData get light {
    final base = ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primary,
        brightness: Brightness.light,
      ),
    );

    return base.copyWith(
      scaffoldBackgroundColor: background,
      appBarTheme: AppBarTheme(
        backgroundColor: cardSurface,
        foregroundColor: textPrimary,
        elevation: 0,
        scrolledUnderElevation: 1,
        centerTitle: false,
        titleTextStyle: GoogleFonts.inter(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: textPrimary,
        ),
      ),
      textTheme: GoogleFonts.interTextTheme(base.textTheme).copyWith(
        displayLarge: GoogleFonts.inter(
          fontSize: 32,
          fontWeight: FontWeight.w800,
          color: textPrimary,
        ),
        displayMedium: GoogleFonts.inter(
          fontSize: 26,
          fontWeight: FontWeight.w700,
          color: textPrimary,
        ),
        headlineMedium: GoogleFonts.inter(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: textPrimary,
        ),
        titleLarge: GoogleFonts.inter(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: textPrimary,
        ),
        titleMedium: GoogleFonts.inter(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: textPrimary,
        ),
        bodyLarge: GoogleFonts.inter(
          fontSize: 15,
          fontWeight: FontWeight.w400,
          color: textPrimary,
        ),
        bodyMedium: GoogleFonts.inter(
          fontSize: 13,
          fontWeight: FontWeight.w400,
          color: textSecondary,
        ),
        labelLarge: GoogleFonts.inter(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: onPrimary,
          letterSpacing: 0.3,
        ),
      ),
      cardTheme: CardThemeData(
        color: cardSurface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: divider, width: 1),
        ),
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: onPrimary,
          minimumSize: const Size.fromHeight(52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          elevation: 0,
          textStyle: GoogleFonts.inter(
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primary,
          minimumSize: const Size.fromHeight(52),
          side: const BorderSide(color: primary, width: 1.5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: GoogleFonts.inter(
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: cardSurface,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: divider),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: divider),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: primary, width: 2),
        ),
        hintStyle: GoogleFonts.inter(
          color: textSecondary,
          fontSize: 14,
        ),
        prefixIconColor: textSecondary,
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: cardSurface,
        selectedItemColor: primary,
        unselectedItemColor: textSecondary,
        elevation: 8,
        type: BottomNavigationBarType.fixed,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: background,
        labelStyle: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w500),
        side: const BorderSide(color: divider),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      ),
    );
  }

  /// Returns the colour associated with a room category string.
  static Color categoryColor(String category) {
    switch (category) {
      case 'lab':
        return labColor;
      case 'office':
        return officeColor;
      case 'facility':
        return facilityColor;
      case 'hall':
        return hallColor;
      case 'staircase':
        return const Color(0xFF8B5CF6);
      case 'entrance':
        return const Color(0xFF10B981);
      default:
        return textSecondary;
    }
  }

  static IconData categoryIcon(String category) {
    switch (category) {
      case 'lab':
        return Icons.computer_rounded;
      case 'office':
        return Icons.business_center_rounded;
      case 'facility':
        return Icons.place_rounded;
      case 'hall':
        return Icons.meeting_room_rounded;
      case 'classroom':
        return Icons.school_rounded;
      case 'staircase':
        return Icons.stairs_rounded;
      case 'entrance':
        return Icons.door_front_door_rounded;
      default:
        return Icons.room_rounded;
    }
  }
}
