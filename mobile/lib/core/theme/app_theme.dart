import 'package:flutter/material.dart';
import '../design_system/typography.dart';
import '../design_system/tokens.dart';

/// Semantic aliases over the raw [DSColors] token scale — the **single source
/// of truth** for the palette. AppColors names the roles the shipping app uses;
/// the values live in `tokens.dart` and are referenced here, so the two can
/// never drift (v2 0.3 unification). Rose-tints and gold have no raw-scale
/// equivalent yet and stay as literals.
class AppColors {
  AppColors._();

  static const Color primary = DSColors.navy700;        // Deep Navy
  static const Color primaryLight = DSColors.mint600;   // Live Mint — action accent
  static const Color primarySurface = DSColors.mint50;  // Mint 50 tint

  static const Color accent = DSColors.danger;          // Rose — Blood Donation / danger
  static const Color accentLight = DSColors.dangerSurface; // Rose 50
  static const Color accentSurface = Color(0xFFFFE4E6); // Rose 100

  // Gold accent (championships, logos)
  static const Color gold = Color(0xFFD4AF37);
  static const Color goldLight = Color(0xFFFBF3C7);

  // Aurora dark surfaces (navy, feeding gradientAurora)
  static const Color darkBg = DSColors.navy900;         // aurora base
  static const Color darkSurface = DSColors.navy700;    // aurora mid

  // MD3 tonal ladder (docs/design/md3-elite-redesign.md §3.1) — no pure
  // white anywhere: cards are tinted "paper", the scaffold sits one tone
  // deeper, and hierarchy reads through tone instead of borders/shadows.
  static const Color background = DSColors.backgroundLight; // scaffold
  static const Color surface = DSColors.surfaceLight;       // cards/sheets
  static const Color surfaceContainerLow = Color(0xFFECEFF7);
  static const Color surfaceContainer = Color(0xFFE6EAF4);
  static const Color surfaceContainerHigh = Color(0xFFE0E5F1);

  static const Color textPrimary = DSColors.textPrimaryLight;   // navy900 ink
  static const Color textSecondary = DSColors.textSecondaryLight; // slate
  static const Color border = DSColors.borderLight;              // navy-tinted line

  static const Color success = DSColors.success;
  static const Color warning = DSColors.amber500;

  // ── Dark theme palette (mirrors DSColors dark) ──────────────────────────────
  static const Color darkBackground = DSColors.backgroundDark;
  static const Color darkCard = DSColors.surfaceDarkSolid;
  static const Color darkBorder = DSColors.borderDark;
  static const Color darkText = DSColors.textPrimaryDark;
  static const Color darkTextSecondary = DSColors.textSecondaryDark;
}

/// Theme-aware colour getters — use `context.cSurface` etc. so a widget renders
/// correctly in both light and dark mode without touching every call site.
extension AppColorsX on BuildContext {
  bool get isDark => Theme.of(this).brightness == Brightness.dark;
  Color get cBackground => isDark ? AppColors.darkBackground : AppColors.background;
  Color get cSurface => isDark ? AppColors.darkCard : AppColors.surface;
  Color get cText => isDark ? AppColors.darkText : AppColors.textPrimary;
  Color get cTextSecondary => isDark ? AppColors.darkTextSecondary : AppColors.textSecondary;
  Color get cBorder => isDark ? AppColors.darkBorder : AppColors.border;
}

class AppTheme {
  AppTheme._();

  static const double radiusCard = DSRadius.card; // single-sourced (v2 0.3)
  static const double radiusBtn = 16.0;
  static const double paddingPage = 20.0;

  // Brand Gradients
  static const LinearGradient gradientPrimary = LinearGradient(
    colors: [AppColors.primary, AppColors.primaryLight],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  static const LinearGradient primaryGradient = gradientPrimary;

  static const LinearGradient gradientAccent = LinearGradient(
    colors: [AppColors.accent, Color(0xFFFB7185)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  static const LinearGradient accentGradient = gradientAccent;

  static const LinearGradient gradientSuccess = LinearGradient(
    colors: [AppColors.success, Color(0xFF34D399)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  static const LinearGradient successGradient = gradientSuccess;

  static const LinearGradient gradientAurora = LinearGradient(
    colors: [AppColors.darkBg, AppColors.darkSurface, AppColors.primary],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static List<BoxShadow> get cardShadow => [
        BoxShadow(
          color: const Color(0xFF0F172A).withOpacity(0.09),
          blurRadius: 24,
          offset: const Offset(0, 10),
        ),
        BoxShadow(
          color: const Color(0xFF0F172A).withOpacity(0.04),
          blurRadius: 4,
          offset: const Offset(0, 1),
        ),
      ];

  static List<BoxShadow> get glowShadow => [
        BoxShadow(
          color: AppColors.primary.withOpacity(0.35),
          blurRadius: 20,
          offset: const Offset(0, 6),
        ),
      ];

  /// The app-wide type scale is now the design system's own DSTypography
  /// (core/design_system/typography.dart): Plus Jakarta Sans for Latin, the
  /// matching Noto Sans family per script (Tamil/Hindi/Malayalam), nothing
  /// below 14sp. This is the audit's Critical fix — Outfit ships no Tamil/
  /// Devanagari/Malayalam glyphs, so the primary language silently fell back
  /// to a system font. The theme is now built per-language and rebuilt on
  /// language change (see AppTheme.lightFor / main.dart), so the correct
  /// script font is always active.
  static TextTheme _textTheme(String lang, {required Color primary, required Color secondary}) =>
      DSTypography.textTheme(lang, color: primary, secondaryColor: secondary);

  /// The design-system font for a given language — used for the handful of
  /// component text styles (app-bar title, buttons, inputs, chips) that sit
  /// outside the TextTheme.
  static TextStyle _font(String lang,
          {required double fontSize, required FontWeight fontWeight, double? letterSpacing, Color? color}) =>
      DSFonts.style(lang, fontSize: fontSize, fontWeight: fontWeight, letterSpacing: letterSpacing, color: color);

  /// Backward-compatible getters — the app is Tamil-first, so a caller that
  /// doesn't specify a language gets the Tamil-capable theme. The live app
  /// passes the real language via [lightFor]/[darkFor] and rebuilds on change.
  static ThemeData get light => lightFor('ta');
  static ThemeData get dark => darkFor('ta');

  static ThemeData lightFor(String lang) => ThemeData(
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
        textTheme: _textTheme(lang, primary: AppColors.textPrimary, secondary: AppColors.textSecondary),
        appBarTheme: AppBarTheme(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          elevation: 0,
          centerTitle: false,
          titleTextStyle: _font(lang, color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold, letterSpacing: 0.5),
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
            textStyle: _font(lang, fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 0.5),
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
            textStyle: _font(lang, fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 0.5),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: AppColors.surfaceContainer,
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
          hintStyle: _font(lang, color: AppColors.textSecondary, fontSize: 14, fontWeight: FontWeight.w400),
          labelStyle: _font(lang, color: AppColors.textSecondary, fontSize: 14, fontWeight: FontWeight.w400),
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
          labelStyle: _font(lang, fontSize: 14, fontWeight: FontWeight.bold),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(50),
          ),
        ),
      );

  static ThemeData darkFor(String lang) => ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.primary,
          brightness: Brightness.dark,
          primary: AppColors.primaryLight,
          secondary: AppColors.primary,
          surface: AppColors.darkCard,
          background: AppColors.darkBackground,
          error: AppColors.accent,
        ),
        scaffoldBackgroundColor: AppColors.darkBackground,
        textTheme: _textTheme(lang, primary: AppColors.darkText, secondary: AppColors.darkTextSecondary),
        appBarTheme: AppBarTheme(
          backgroundColor: AppColors.darkBackground,
          foregroundColor: AppColors.darkText,
          elevation: 0,
          centerTitle: false,
          titleTextStyle: _font(lang, color: AppColors.darkText, fontSize: 20, fontWeight: FontWeight.bold, letterSpacing: 0.5),
          iconTheme: const IconThemeData(color: AppColors.darkText),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primaryLight,
            foregroundColor: Colors.white,
            minimumSize: const Size(double.infinity, 54),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radiusBtn)),
            textStyle: _font(lang, fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 0.5),
            elevation: 0,
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: AppColors.darkCard,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(radiusBtn),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(radiusBtn),
            borderSide: const BorderSide(color: AppColors.darkBorder),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(radiusBtn),
            borderSide: const BorderSide(color: AppColors.primaryLight, width: 2),
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          hintStyle: _font(lang, color: AppColors.darkTextSecondary, fontSize: 14, fontWeight: FontWeight.w400),
        ),
        cardTheme: CardThemeData(
          color: AppColors.darkCard,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusCard),
            side: const BorderSide(color: AppColors.darkBorder, width: 1),
          ),
          margin: EdgeInsets.zero,
        ),
        bottomNavigationBarTheme: const BottomNavigationBarThemeData(
          backgroundColor: AppColors.darkCard,
          selectedItemColor: AppColors.primaryLight,
          unselectedItemColor: AppColors.darkTextSecondary,
          type: BottomNavigationBarType.fixed,
          elevation: 12,
        ),
      );
}
