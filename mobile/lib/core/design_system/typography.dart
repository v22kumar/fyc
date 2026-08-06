import 'package:flutter/material.dart';

/// Design-system typography: Plus Jakarta Sans (Latin) + the matching Noto
/// Sans family per script for Tamil/Hindi/Malayalam. Fixed hierarchy, nothing
/// below 14sp anywhere.
///
/// **The faces are bundled, not fetched.** This used to go through
/// `GoogleFonts.getFont`, which downloads from `fonts.gstatic.com` on first use
/// and caches the result. The failure mode is unusually bad: on a network that
/// filters gstatic — school Wi-Fi, some ISPs, a captive portal — the download
/// never lands and the app renders **with no text at all**. Not an error, not
/// a fallback to a system face. Blank, with one console line nobody will read.
/// It was caught by loading the web build in a browser with gstatic blocked,
/// which is a state a member in Nagercoil can genuinely be in.
///
/// A club's own words should not be a request that might go unanswered. The
/// four weights the scale uses ship in `assets/fonts/` (~1.8 MB for all four
/// scripts), declared in `pubspec.yaml`. On the web Flutter fetches a face only
/// when something renders in it, so a Tamil reader never pays for Devanagari.
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
    return TextStyle(
      fontFamily: familyFor(languageCode),
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
