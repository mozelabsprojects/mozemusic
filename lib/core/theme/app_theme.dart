import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // Ultra Modern Deep Dark Theme Colors
  static const Color backgroundBlack = Color(0xFF000000);
  static const Color surfaceDark = Color(0xFF121212);
  static const Color surfaceMedium = Color(0xFF181818);
  static const Color surfaceLight = Color(0xFF282828);

  // Light Theme Colors
  static const Color backgroundWhite = Color(0xFFFFFFFF);
  static const Color surfaceLightMedium = Color(0xFFF0F0F0);
  static const Color surfaceLightDark = Color(0xFFE0E0E0);

  // Text Colors
  static const Color textPrimary = Color(0xFFFFFFFF);
  static const Color textSecondary = Color(0xFFB3B3B3);
  
  static const Color textPrimaryDark = Color(0xFFFFFFFF);
  static const Color textSecondaryDark = Color(0xFFB3B3B3);
  
  static const Color textPrimaryLight = Color(0xFF000000);
  static const Color textSecondaryLight = Color(0xFF555555);

  // Neon Accents
  static const Color neonGreen = Color(0xFF1DB954); // Spotify Green
  static const Color neonPurple = Color(0xFFB455FF); // Purple Accent
  static const Color redAccent = Color(0xFFFF3636);

  static ThemeData get darkTheme {
    final baseTextTheme = GoogleFonts.interTextTheme(ThemeData.dark().textTheme);

    return ThemeData(
      brightness: Brightness.dark,
      primaryColor: neonGreen,
      scaffoldBackgroundColor: backgroundBlack,
      cardColor: surfaceDark,
      dividerColor: surfaceLight,
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: textPrimaryDark),
        titleTextStyle: GoogleFonts.inter(
          color: textPrimaryDark,
          fontSize: 20,
          fontWeight: FontWeight.w700,
        ),
      ),
      textTheme: baseTextTheme.apply(
        bodyColor: textPrimaryDark,
        displayColor: textPrimaryDark,
      ).copyWith(
        bodyMedium: baseTextTheme.bodyMedium?.copyWith(color: textSecondaryDark),
        titleMedium: baseTextTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
      ),
      sliderTheme: SliderThemeData(
        activeTrackColor: textPrimaryDark,
        inactiveTrackColor: surfaceLight,
        thumbColor: textPrimaryDark,
        overlayColor: textPrimaryDark.withValues(alpha: 0.1),
        trackHeight: 4.0,
        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6.0),
        overlayShape: const RoundSliderOverlayShape(overlayRadius: 14.0),
      ),
      snackBarTheme: const SnackBarThemeData(
        backgroundColor: backgroundWhite,
        contentTextStyle: TextStyle(color: backgroundBlack, fontWeight: FontWeight.bold),
        actionTextColor: redAccent,
        behavior: SnackBarBehavior.floating,
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: backgroundBlack,
        selectedItemColor: textPrimaryDark,
        unselectedItemColor: textSecondaryDark,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
        selectedLabelStyle: TextStyle(fontWeight: FontWeight.w600, fontSize: 11),
        unselectedLabelStyle: TextStyle(fontWeight: FontWeight.w500, fontSize: 11),
      ),
      colorScheme: const ColorScheme.dark(
        primary: neonGreen,
        secondary: neonPurple,
        surface: surfaceDark,
        error: redAccent,
      ),
      useMaterial3: true,
    );
  }

  static ThemeData get lightTheme {
    final baseTextTheme = GoogleFonts.interTextTheme(ThemeData.light().textTheme);

    return ThemeData(
      brightness: Brightness.light,
      primaryColor: redAccent,
      scaffoldBackgroundColor: backgroundWhite,
      cardColor: surfaceLightMedium,
      dividerColor: surfaceLightDark,
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: textPrimaryLight),
        titleTextStyle: GoogleFonts.inter(
          color: textPrimaryLight,
          fontSize: 20,
          fontWeight: FontWeight.w700,
        ),
      ),
      textTheme: baseTextTheme.apply(
        bodyColor: textPrimaryLight,
        displayColor: textPrimaryLight,
      ).copyWith(
        bodyMedium: baseTextTheme.bodyMedium?.copyWith(color: textSecondaryLight),
        titleMedium: baseTextTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
      ),
      sliderTheme: SliderThemeData(
        activeTrackColor: textPrimaryLight,
        inactiveTrackColor: surfaceLightDark,
        thumbColor: textPrimaryLight,
        overlayColor: textPrimaryLight.withValues(alpha: 0.1),
        trackHeight: 4.0,
        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6.0),
        overlayShape: const RoundSliderOverlayShape(overlayRadius: 14.0),
      ),
      snackBarTheme: const SnackBarThemeData(
        backgroundColor: backgroundBlack,
        contentTextStyle: TextStyle(color: textPrimaryDark, fontWeight: FontWeight.bold),
        actionTextColor: redAccent,
        behavior: SnackBarBehavior.floating,
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: backgroundWhite,
        selectedItemColor: redAccent,
        unselectedItemColor: textSecondaryLight,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
        selectedLabelStyle: TextStyle(fontWeight: FontWeight.w600, fontSize: 11),
        unselectedLabelStyle: TextStyle(fontWeight: FontWeight.w500, fontSize: 11),
      ),
      colorScheme: const ColorScheme.light(
        primary: redAccent,
        secondary: neonPurple,
        surface: surfaceLightMedium,
        error: redAccent,
      ),
      useMaterial3: true,
    );
  }
}
