import 'package:flutter/material.dart';
import '../design_system/typography.dart';
import '../design_system/tokens.dart';
import 'theme_manager.dart';
import 'package:fyc_connect/core/theme/app_theme.dart';

/// Semantic aliases over the dynamic [ThemeManager] color scale.
/// Instead of hardcoded constants, this reads from the live backend-driven theme.
class AppColors {
  AppColors._();

  static Color get primary => ThemeManager.instance.colors.primary;
  static Color get primaryLight => ThemeManager.instance.colors.primary.withOpacity(0.8);
  static Color get primarySurface => ThemeManager.instance.colors.primary.withOpacity(0.1);

  static Color get accent => ThemeManager.instance.colors.danger;          // Rose — Blood Donation / danger
  static Color get accentLight => ThemeManager.instance.colors.danger.withOpacity(0.8);
  static Color get accentSurface => ThemeManager.instance.colors.danger.withOpacity(0.1);

  // Gold accent (championships, logos)
  static const Color gold = Color(0xFFD4AF37);
  static const Color goldLight = Color(0xFFFBF3C7);

  // Aurora dark surfaces (navy, feeding gradientAurora)
  static Color get darkBg => DSColors.navy900;
  static Color get darkSurface => DSColors.navy700;

  static Color get background => ThemeManager.instance.colors.background; // scaffold
  static Color get surface => ThemeManager.instance.colors.surface;       // cards/sheets
  static Color get surfaceContainerLow => ThemeManager.instance.colors.surface.withOpacity(0.9);
  static Color get surfaceContainer => ThemeManager.instance.colors.surface.withOpacity(0.95);
  static Color get surfaceContainerHigh => ThemeManager.instance.colors.surface.withOpacity(0.98);

  static Color get textPrimary => ThemeManager.instance.colors.textPrimary;
  static Color get textSecondary => ThemeManager.instance.colors.textSecondary;
  static Color get border => ThemeManager.instance.colors.border;

  static Color get success => ThemeManager.instance.colors.success;
  static Color get warning => ThemeManager.instance.colors.warning;
  static Color get danger => ThemeManager.instance.colors.danger;
  static Color get info => ThemeManager.instance.colors.info;

  // ── Dark theme palette ──────────────────────────────
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

  static double get radiusCard => DSRadius.card; // single-sourced (v2 0.3)
  static const double radiusBtn = 16.0;
  static const double paddingPage = 20.0;

  // Brand Gradients
  static LinearGradient get gradientPrimary => LinearGradient(
    colors: [AppColors.primary, AppColors.primaryLight],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  static LinearGradient get primaryGradient => gradientPrimary;

  static LinearGradient get gradientAccent => LinearGradient(
    colors: [AppColors.accent, Color(0xFFFB7185)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  static LinearGradient get accentGradient => gradientAccent;

  static LinearGradient get gradientSuccess => LinearGradient(
    colors: [AppColors.success, Color(0xFF34D399)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  static LinearGradient get successGradient => gradientSuccess;

  static LinearGradient get gradientAurora => LinearGradient(
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
          foregroundColor: AppColors.background,
          elevation: 0,
          centerTitle: false,
          titleTextStyle: _font(lang, color: AppColors.background, fontSize: 20, fontWeight: FontWeight.bold, letterSpacing: 0.5),
          iconTheme: IconThemeData(color: AppColors.background),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: AppColors.background,
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
            side: BorderSide(color: AppColors.primary, width: 1.5),
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
            borderSide: BorderSide(color: AppColors.primary, width: 2),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(radiusBtn),
            borderSide: BorderSide(color: AppColors.accent, width: 1.5),
          ),
          contentPadding: EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          hintStyle: _font(lang, color: AppColors.textSecondary, fontSize: 14, fontWeight: FontWeight.w400),
          labelStyle: _font(lang, color: AppColors.textSecondary, fontSize: 14, fontWeight: FontWeight.w400),
        ),
        cardTheme: CardThemeData(
          color: AppColors.surface,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusCard),
            side: BorderSide(color: AppColors.border, width: 1),
          ),
          margin: EdgeInsets.zero,
        ),
        bottomNavigationBarTheme: BottomNavigationBarThemeData(
          backgroundColor: AppColors.surface,
          selectedItemColor: AppColors.primary,
          unselectedItemColor: AppColors.textSecondary,
          type: BottomNavigationBarType.fixed,
          elevation: 12,
        ),
        chipTheme: ChipThemeData(
          backgroundColor: AppColors.background,
          selectedColor: AppColors.primary,
          // The colour is not optional.
          //
          // This labelStyle carried a family and a weight and no colour, and a
          // Material 3 Chip given a labelStyle uses it as-is rather than
          // filling the gap from the text theme — so every chip label in the
          // app laid out at the right width and painted nothing. A plain
          // `Chip` with no code of ours does it too, which is how it was
          // found: bold text renders perfectly well two lines above an empty
          // chip.
          labelStyle: _font(lang, fontSize: 14, fontWeight: FontWeight.bold,
              color: DSColors.textPrimaryLight),
          secondaryLabelStyle: _font(lang, fontSize: 14,
              fontWeight: FontWeight.bold, color: Colors.white),
          padding: EdgeInsets.symmetric(horizontal: 14, vertical: 8),
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
          iconTheme: IconThemeData(color: AppColors.darkText),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primaryLight,
            foregroundColor: AppColors.background,
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
            borderSide: BorderSide(color: AppColors.darkBorder),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(radiusBtn),
            borderSide: BorderSide(color: AppColors.primaryLight, width: 2),
          ),
          contentPadding: EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          hintStyle: _font(lang, color: AppColors.darkTextSecondary, fontSize: 14, fontWeight: FontWeight.w400),
        ),
        cardTheme: CardThemeData(
          color: AppColors.darkCard,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusCard),
            side: BorderSide(color: AppColors.darkBorder, width: 1),
          ),
          margin: EdgeInsets.zero,
        ),
        bottomNavigationBarTheme: BottomNavigationBarThemeData(
          backgroundColor: AppColors.darkCard,
          selectedItemColor: AppColors.primaryLight,
          unselectedItemColor: AppColors.darkTextSecondary,
          type: BottomNavigationBarType.fixed,
          elevation: 12,
        ),
      );
}
