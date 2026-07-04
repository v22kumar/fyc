import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Design-system typography: Plus Jakarta Sans (Latin) + the matching Noto
/// Sans family per script for Tamil/Hindi/Malayalam. Fixed hierarchy, nothing
/// below 14sp anywhere.
///
/// Built on `GoogleFonts.getFont(familyName)` (the package's stable dynamic
/// lookup) rather than the auto-generated per-font methods
/// (`GoogleFonts.plusJakartaSans()` etc.) — this environment has no way to
/// compile-check the generated method names against the installed package
/// version, and `getFont` with the official Google Fonts family-name string
/// is documented and version-stable.
///
/// NOTE (flagged for Sprint 3 — Offline & Performance Core): `google_fonts`
/// fetches font files over the network on first use and caches them. For an
/// app that must work on low/no connectivity, fonts should eventually ship as
/// bundled assets (`GoogleFonts.config.allowRuntimeFetching = false` +
/// pre-downloaded .ttf in `assets/fonts/`). Not changed here: the existing
/// theme (`app_theme.dart`) already uses `GoogleFonts.outfit()` the same way,
/// so this follows the codebase's current, established convention rather
/// than introducing a second font-loading strategy mid-sprint. Bundling is
/// tracked as an offline-hardening task, not a design-system concern.
class DSFonts {
  DSFonts._();

  static const String latin = 'Plus Jakarta Sans';
  static const String tamil = 'Noto Sans Tamil';
  static const String devanagari = 'Noto Sans Devanagari'; // Hindi
  static const String malayalam = 'Noto Sans Malayalam';

  static String familyFor(String languageCode) {
    switch (languageCode) {
      case 'ta':
        return tamil;
      case 'hi':
        return devanagari;
      case 'ml':
        return malayalam;
      default:
        return latin;
    }
  }

  static TextStyle style(
    String languageCode, {
    required double fontSize,
    required FontWeight fontWeight,
    double? letterSpacing,
    double? height,
    Color? color,
  }) {
    return GoogleFonts.getFont(
      familyFor(languageCode),
      fontSize: fontSize,
      fontWeight: fontWeight,
      letterSpacing: letterSpacing,
      height: height,
      color: color,
    );
  }
}

/// The fixed type hierarchy the spec calls for: Display / Heading / Title /
/// Body / Caption / Label. No size below 14sp exists in this scale.
class DSTypography {
  DSTypography._();

  static TextTheme textTheme(String languageCode, {required Color color, required Color secondaryColor}) {
    TextStyle s(double size, FontWeight w, {double? ls, double? h, Color? c}) =>
        DSFonts.style(languageCode, fontSize: size, fontWeight: w, letterSpacing: ls, height: h, color: c ?? color);

    return TextTheme(
      // Display — hero numbers, splash
      displayLarge: s(34, FontWeight.w800, ls: -0.6, h: 1.15),
      displayMedium: s(28, FontWeight.w800, ls: -0.4, h: 1.2),
      // Heading — screen titles
      headlineLarge: s(24, FontWeight.w700, ls: -0.3, h: 1.25),
      headlineMedium: s(20, FontWeight.w700, ls: -0.2, h: 1.3),
      // Title — section/card titles
      titleLarge: s(18, FontWeight.w700, h: 1.3),
      titleMedium: s(16, FontWeight.w600, h: 1.35),
      titleSmall: s(14, FontWeight.w600, h: 1.35),
      // Body
      bodyLarge: s(16, FontWeight.w400, h: 1.5),
      bodyMedium: s(15, FontWeight.w400, h: 1.5, c: secondaryColor),
      bodySmall: s(14, FontWeight.w400, h: 1.45, c: secondaryColor),
      // Label — buttons, chips, badges
      labelLarge: s(15, FontWeight.w700, ls: 0.2),
      labelMedium: s(14, FontWeight.w700, ls: 0.2),
      labelSmall: s(14, FontWeight.w600, ls: 0.2, c: secondaryColor),
    );
  }
}
