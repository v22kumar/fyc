import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppColors {
  AppColors._();

  // Modern Premium Slate-Teal/Rose Palette
  static const Color primary = Color(0xFF0E7490);       // Cyan/Teal 700 - Vibrant Tech Teal
  static const Color primaryLight = Color(0xFF06B6D4);  // Cyan 500
  static const Color primarySurface = Color(0xFFECFEFF); // Cyan 50
  
  static const Color accent = Color(0xFFF43F5E);        // Rose 500 - Heart/Life Rose for Blood Donation
  static const Color accentLight = Color(0xFFFFF1F2);   // Rose 50
  static const Color accentSurface = Color(0xFFFFE4E6); // Rose 100

  static const Color background = Color(0xFFF8FAFC);    // Slate 50 - Very clean off-white
  static const Color surface = Color(0xFFFFFFFF);
  
  static const Color textPrimary = Color(0xFF0F172A);    // Slate 900 - Soft rich dark navy
  static const Color textSecondary = Color(0xFF64748B);  // Slate 500 - Soft slate grey
  static const Color border = Color(0xFFE2E8F0);         // Slate 200 - Very subtle divider
  
  static const Color success = Color(0xFF10B981);       // Emerald 500
  static const Color warning = Color(0xFFF59E0B);       // Amber 500
}

class AppTheme {
  AppTheme._();

  static const double radiusCard = 20.0;
  static const double radiusBtn = 16.0;
  static const double paddingPage = 20.0;

  static List<BoxShadow> get cardShadow => [
        BoxShadow(
          color: const Color(0xFF0F172A).withOpacity(0.035),
          blurRadius: 24,
          offset: const Offset(0, 8),
        ),
      ];

  static ThemeData get light => ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.primary,
          primary: AppColors.primary,
          secondary: AppColors.primaryLight,
          surface: AppColors.surface,
          background: AppColors.background,
          error: AppColors.accent,
        ),
        scaffoldBackgroundColor: AppColors.background,
        textTheme: GoogleFonts.outfitTextTheme(),
        appBarTheme: AppBarTheme(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          elevation: 0,
          centerTitle: false,
          titleTextStyle: GoogleFonts.outfit(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.5,
          ),
          iconTheme: const IconThemeData(color: Colors.white),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            minimumSize: const Size(double.infinity, 54),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(radiusBtn),
            ),
            textStyle: GoogleFonts.outfit(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
            ),
            elevation: 0,
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.primary,
            side: const BorderSide(color: AppColors.primary, width: 1.5),
            minimumSize: const Size(double.infinity, 54),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(radiusBtn),
            ),
            textStyle: GoogleFonts.outfit(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
            ),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color(0xFFF1F5F9), // Slate 100 background
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(radiusBtn),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(radiusBtn),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(radiusBtn),
            borderSide: const BorderSide(color: AppColors.primary, width: 2),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(radiusBtn),
            borderSide: const BorderSide(color: AppColors.accent, width: 1.5),
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          hintStyle: GoogleFonts.outfit(color: AppColors.textSecondary, fontSize: 14),
          labelStyle: GoogleFonts.outfit(color: AppColors.textSecondary, fontSize: 14),
        ),
        cardTheme: CardThemeData(
          color: AppColors.surface,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusCard),
            side: const BorderSide(color: AppColors.border, width: 1),
          ),
          margin: EdgeInsets.zero,
        ),
        bottomNavigationBarTheme: const BottomNavigationBarThemeData(
          backgroundColor: AppColors.surface,
          selectedItemColor: AppColors.primary,
          unselectedItemColor: AppColors.textSecondary,
          type: BottomNavigationBarType.fixed,
          elevation: 12,
        ),
        chipTheme: ChipThemeData(
          backgroundColor: AppColors.background,
          selectedColor: AppColors.primary,
          labelStyle: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.bold),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(50),
          ),
        ),
      );
}
