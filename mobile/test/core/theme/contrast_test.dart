import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fyc_connect/core/design_system/tokens.dart';
import 'package:fyc_connect/core/theme/app_theme.dart';

/// Contrast, measured rather than eyeballed.
///
/// Every review so far has said the colours "look fine", which is not a claim
/// anybody can check and is worth little to a member reading a phone in
/// Nagercoil sunlight. WCAG 2.2 asks 4.5:1 for body text. That is arithmetic,
/// so it can simply be asserted.
double _channel(double v) {
  final c = v / 255.0;
  return c <= 0.03928
      ? c / 12.92
      : math.pow((c + 0.055) / 1.055, 2.4).toDouble();
}

double _luminance(Color c) =>
    0.2126 * _channel(c.r * 255) +
    0.7152 * _channel(c.g * 255) +
    0.0722 * _channel(c.b * 255);

double contrast(Color a, Color b) {
  final la = _luminance(a);
  final lb = _luminance(b);
  return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05);
}

void main() {
  group('light', () {
    test('body text on the page reaches AA', () {
      expect(contrast(DSColors.textPrimaryLight, DSColors.backgroundLight),
          greaterThanOrEqualTo(4.5));
    });

    test('body text on a card reaches AA', () {
      expect(contrast(DSColors.textPrimaryLight, DSColors.surfaceLight),
          greaterThanOrEqualTo(4.5));
    });

    test('secondary text reaches AA', () {
      // The area and description on a listing card. Muted is fine; unreadable
      // in sunlight is not.
      expect(contrast(DSColors.textSecondaryLight, DSColors.surfaceLight),
          greaterThanOrEqualTo(4.5));
    });
  });

  group('dark', () {
    test('body text on the page reaches AA', () {
      expect(contrast(DSColors.textPrimaryDark, DSColors.backgroundDark),
          greaterThanOrEqualTo(4.5));
    });

    test('body text on a card reaches AA', () {
      expect(contrast(DSColors.textPrimaryDark, DSColors.surfaceDarkSolid),
          greaterThanOrEqualTo(4.5));
    });

    test('secondary text reaches AA', () {
      expect(contrast(DSColors.textSecondaryDark, DSColors.surfaceDarkSolid),
          greaterThanOrEqualTo(4.5));
    });
  });

  test('white on the primary button reaches AA', () {
    // The Call button — the most consequential control in the work index, and
    // the one people tap in daylight.
    expect(contrast(Colors.white, AppColors.primary),
        greaterThanOrEqualTo(4.5));
  });
}
