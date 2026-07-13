import 'package:flutter/services.dart';

/// Centralized haptic feedback so call sites read as intent, not platform
/// primitives — and so it can be globally muted later if a user setting calls
/// for it. Thin wrapper over [HapticFeedback].
class Haptics {
  const Haptics._();

  /// A tap on a control (tab switch, chip select, toggle).
  static void selection() => HapticFeedback.selectionClick();

  /// A light confirmation (button press, card tap).
  static void light() => HapticFeedback.lightImpact();

  /// A successful action landed (submitted, saved, registered).
  static void success() => HapticFeedback.mediumImpact();

  /// A strong alert (SOS, error, destructive confirm).
  static void heavy() => HapticFeedback.heavyImpact();
}
