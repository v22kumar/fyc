import 'package:flutter/material.dart';

/// FYC Connect Design System v2 — tokens.
///
/// This is the Sprint 1 foundation: a single, additive source of truth for
/// color, spacing, radius, elevation, and motion. It does NOT replace
/// `core/theme/app_theme.dart` (still used by every shipping screen) — that
/// migration happens screen-by-screen in later sprints (S2+) as each bucket
/// (Home/Play/Serve/Me) is rebuilt. Building both systems is deliberate:
/// changing the live palette today would reskin the entire shipping app in
/// one uncontrolled step instead of the planned, testable rollout.
class DSColors {
  DSColors._();

  // ── Primary: Deep Navy ────────────────────────────────────────────────
  static const Color navy900 = Color(0xFF0A1128);
  static const Color navy800 = Color(0xFF0F1B3C);
  static const Color navy700 = Color(0xFF16255A); // primary
  static const Color navy600 = Color(0xFF1E3378);
  static const Color navy500 = Color(0xFF2B4494);
  static const Color navy100 = Color(0xFFE4E8F5);
  static const Color navy50 = Color(0xFFF3F5FB);

  // ── Accent: Mint ──────────────────────────────────────────────────────
  static const Color mint700 = Color(0xFF0F9B7E);
  static const Color mint600 = Color(0xFF14B891); // accent / primary action
  static const Color mint500 = Color(0xFF2DD4A7);
  static const Color mint100 = Color(0xFFDCFBF2);
  static const Color mint50 = Color(0xFFF0FDF9);

  // ── Highlight: Amber (awards / sports / premium) ─────────────────────
  static const Color amber700 = Color(0xFFB45309);
  static const Color amber600 = Color(0xFFD97706);
  static const Color amber500 = Color(0xFFF59E0B); // highlight
  static const Color amber100 = Color(0xFFFEF3C7);
  static const Color amber50 = Color(0xFFFFFBEB);

  // ── Semantic (Material-accessible contrast pairs) ────────────────────
  static const Color success = Color(0xFF16A34A);
  static const Color successSurface = Color(0xFFF0FDF4);
  static const Color warning = Color(0xFFD97706);
  static const Color warningSurface = Color(0xFFFFFBEB);
  static const Color danger = Color(0xFFDC2626);
  static const Color dangerSurface = Color(0xFFFEF2F2);
  static const Color info = Color(0xFF2563EB);
  static const Color infoSurface = Color(0xFFEFF6FF);

  // ── Neutrals ──────────────────────────────────────────────────────────
  static const Color backgroundLight = Color(0xFFF7F8FC);
  static const Color surfaceLight = Color(0xFFFFFFFF);
  static const Color borderLight = Color(0xFFE3E7F0);
  static const Color textPrimaryLight = navy900;
  static const Color textSecondaryLight = Color(0xFF5B6478);

  static const Color backgroundDark = Color(0xFF080B14);
  static const Color surfaceDarkSolid = Color(0xFF141A2B);
  static const Color borderDark = Color(0xFF242B3D);
  static const Color textPrimaryDark = Color(0xFFF1F3FA);
  static const Color textSecondaryDark = Color(0xFF9AA3B8);
}

/// Theme-aware token getters — mirrors the pattern already used by
/// `AppColorsX` in app_theme.dart, so migrated screens read identically.
extension DSColorsX on BuildContext {
  bool get dsIsDark => Theme.of(this).brightness == Brightness.dark;
  Color get dsBackground => dsIsDark ? DSColors.backgroundDark : DSColors.backgroundLight;
  Color get dsSurface => dsIsDark ? DSColors.surfaceDarkSolid : DSColors.surfaceLight;
  Color get dsBorder => dsIsDark ? DSColors.borderDark : DSColors.borderLight;
  Color get dsText => dsIsDark ? DSColors.textPrimaryDark : DSColors.textPrimaryLight;
  Color get dsTextSecondary => dsIsDark ? DSColors.textSecondaryDark : DSColors.textSecondaryLight;
  Color get dsPrimary => dsIsDark ? DSColors.navy500 : DSColors.navy700;
  Color get dsAccent => DSColors.mint600;
  Color get dsHighlight => DSColors.amber500;
}

/// 8dp grid. No spacing value outside this scale is used in design-system
/// components.
class DSSpacing {
  DSSpacing._();
  static const double xs = 8;
  static const double sm = 16;
  static const double md = 24;
  static const double lg = 32;
  static const double xl = 48;
}

/// Fixed radius scale — matches the spec exactly (card 24 / button 20 /
/// dialog 28). Chip radius (pill) is derived, not a new scale value.
class DSRadius {
  DSRadius._();
  static const double card = 24;
  static const double button = 20;
  static const double dialog = 28;
  static const double chip = 999; // pill
  static const double input = 16;
}

/// Exactly three elevation levels — no ad-hoc shadow tuning per screen.
class DSElevation {
  DSElevation._();

  static const double surface = 0;
  static const double card = 2;
  static const double floating = 8;

  static List<BoxShadow> shadowFor(double level, {bool dark = false}) {
    if (level <= surface) return const [];
    final base = dark ? Colors.black : const Color(0xFF0A1128);
    if (level <= card) {
      return [
        BoxShadow(color: base.withOpacity(dark ? 0.35 : 0.06), blurRadius: 16, offset: const Offset(0, 4)),
      ];
    }
    return [
      BoxShadow(color: base.withOpacity(dark ? 0.45 : 0.14), blurRadius: 28, offset: const Offset(0, 10)),
    ];
  }
}

/// Standard motion duration (200ms) — the only duration used by design
/// system components (card lift, ripple, page fade, hero transition).
class DSMotion {
  DSMotion._();
  static const Duration standard = Duration(milliseconds: 200);
  static const Curve curve = Curves.easeOut;
}
