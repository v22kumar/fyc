import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppColors {
  AppColors._();

  // FYC Brand — Deep Navy + Live Mint (unified design system v2).
  // These are aliases of the DSColors token scale (core/design_system/tokens.dart)
  // so the whole shipping app renders in one palette instead of the old
  // forest-green theme. Change these five and every legacy screen re-skins.
  static const Color primary = Color(0xFF16255A);       // Deep Navy (navy700)
  static const Color primaryLight = Color(0xFF14B891);  // Live Mint (mint600) — action accent
  static const Color primarySurface = Color(0xFFF0FDF9); // Mint 50 tint

  static const Color accent = Color(0xFFF43F5E);        // Rose 500 - Blood Donation / danger
  static const Color accentLight = Color(0xFFFFF1F2);   // Rose 50
  static const Color accentSurface = Color(0xFFFFE4E6); // Rose 100

  // Gold accent (championships, logos)
  static const Color gold = Color(0xFFD4AF37);
  static const Color goldLight = Color(0xFFFBF3C7);

  // Aurora dark surfaces (now navy, feeding gradientAurora)
  static const Color darkBg = Color(0xFF0A1128);        // navy900 — aurora base
  static const Color darkSurface = Color(0xFF16255A);   // navy700 — aurora mid

  static const Color background = Color(0xFFF7F8FC);    // cool navy-tinted paper
  static const Color surface = Color(0xFFFFFFFF);

  static const Color textPrimary = Color(0xFF0A1128);    // navy900 ink
  static const Color textSecondary = Color(0xFF5B6478);  // slate
  static const Color border = Color(0xFFE3E7F0);         // navy-tinted line

  static const Color success = Color(0xFF16A34A);
  static const Color warning = Color(0xFFF59E0B);       // Amber 500

  // ── Dark theme palette (navy-black, matches DSColors dark) ──────────────────
  static const Color darkBackground = Color(0xFF080B14); // navy-black
  static const Color darkCard = Color(0xFF141A2B);       // elevated surface
  static const Color darkBorder = Color(0xFF242B3D);     // subtle divider
  static const Color darkText = Color(0xFFF1F3FA);        // off-white
  static const Color darkTextSecondary = Color(0xFF9AA3B8); // slate
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

  static const double radiusCard = 20.0;
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

  /// The app-wide type scale, shared by light and dark (only `primary`/
  /// `secondary` text color differs between them — previously they didn't
  /// share a scale at all: light hand-overrode 7 of 12 TextTheme slots while
  /// dark fell through to Material's stock sizes, so the two themes actually
  /// rendered text at different sizes). Mirrors DSTypography's hierarchy
  /// (core/design_system/typography.dart) — nothing below 14sp — while
  /// keeping the Outfit font already in use everywhere; adopting DSTypography's
  /// own per-language font families (Plus Jakarta Sans / Noto Sans Tamil etc.)
  /// is a separate follow-up, since the theme doesn't currently rebuild on
  /// language change.
  static TextTheme _textTheme({required Color primary, required Color secondary}) {
    TextStyle s(double size, FontWeight w, {double? ls, double? h, Color? c}) =>
        GoogleFonts.outfit(fontSize: size, fontWeight: w, letterSpacing: ls, height: h, color: c ?? primary);

    return TextTheme(
      displayLarge: s(34, FontWeight.w800, ls: -0.6, h: 1.15),
      displayMedium: s(28, FontWeight.w800, ls: -0.4, h: 1.2),
      headlineLarge: s(24, FontWeight.w700, ls: -0.3, h: 1.25),
      headlineMedium: s(24, FontWeight.w700, ls: -0.4),
      titleLarge: s(18, FontWeight.w700, h: 1.3),
      titleMedium: s(16, FontWeight.w600, h: 1.35),
      titleSmall: s(14, FontWeight.w600, h: 1.35),
      bodyLarge: s(16, FontWeight.w400, h: 1.5),
      bodyMedium: s(15, FontWeight.w400, h: 1.5, c: secondary),
      bodySmall: s(14, FontWeight.w400, h: 1.45, c: secondary),
      labelLarge: s(15, FontWeight.w700, ls: 0.2),
      labelMedium: s(14, FontWeight.w700, ls: 0.2),
      labelSmall: s(14, FontWeight.w600, ls: 0.2, c: secondary),
    );
  }

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
        textTheme: _textTheme(primary: AppColors.textPrimary, secondary: AppColors.textSecondary),
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
          fillColor: const Color(0xFFF1F5F9),
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
          labelStyle: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.bold),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(50),
          ),
        ),
      );

  static ThemeData get dark => ThemeData(
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
        textTheme: _textTheme(primary: AppColors.darkText, secondary: AppColors.darkTextSecondary),
        appBarTheme: AppBarTheme(
          backgroundColor: AppColors.darkBackground,
          foregroundColor: AppColors.darkText,
          elevation: 0,
          centerTitle: false,
          titleTextStyle: GoogleFonts.outfit(
            color: AppColors.darkText,
            fontSize: 20,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.5,
          ),
          iconTheme: const IconThemeData(color: AppColors.darkText),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primaryLight,
            foregroundColor: Colors.white,
            minimumSize: const Size(double.infinity, 54),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radiusBtn)),
            textStyle: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 0.5),
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
          hintStyle: GoogleFonts.outfit(color: AppColors.darkTextSecondary, fontSize: 14),
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
