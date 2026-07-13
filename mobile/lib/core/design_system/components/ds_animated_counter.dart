import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

/// A number that counts up to [value] when it first appears (and re-animates
/// from the current value whenever [value] changes). Used for the Home impact
/// counters. Honours reduce-motion — jumps straight to the final value.
class DSAnimatedCounter extends StatelessWidget {
  final int value;

  /// Appended after the number, e.g. "+" for "5000+".
  final String suffix;

  final Duration duration;
  final TextStyle? style;

  const DSAnimatedCounter({
    super.key,
    required this.value,
    this.suffix = '',
    this.duration = const Duration(milliseconds: 900),
    this.style,
  });

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    final effective = style ??
        TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: context.cText);
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: value.toDouble()),
      duration: reduceMotion ? Duration.zero : duration,
      curve: Curves.easeOutCubic,
      builder: (context, v, _) => Text(
        '${v.round()}$suffix',
        style: effective,
      ),
    );
  }
}
