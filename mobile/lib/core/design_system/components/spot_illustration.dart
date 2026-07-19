import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:lottie/lottie.dart';

/// A brand spot illustration from `assets/illustrations/svg/<name>.svg`.
///
/// Duotone vector art (a soft category disc + a bold emblem), used as the hero
/// art on Home feature/hero tiles. If the asset can't be parsed it renders an
/// empty box of the same size, so a malformed illustration never breaks a tile.
class SpotIllustration extends StatelessWidget {
  final String name;
  final double size;

  const SpotIllustration(this.name, {super.key, this.size = 72});

  @override
  Widget build(BuildContext context) {
    return SvgPicture.asset(
      'assets/illustrations/svg/$name.svg',
      width: size,
      height: size,
      fit: BoxFit.contain,
      placeholderBuilder: (_) => SizedBox(width: size, height: size),
    );
  }
}

/// A looping "live" pulse rendered from a Lottie animation. Falls back to a
/// simple static dot if the animation asset fails to load, so the live badge is
/// always present even if the JSON can't be parsed.
class LivePulse extends StatelessWidget {
  final double size;
  final Color fallbackColor;

  const LivePulse({super.key, this.size = 26, this.fallbackColor = const Color(0xFF21C55E)});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Lottie.asset(
        'assets/lottie/live_pulse.json',
        width: size,
        height: size,
        fit: BoxFit.contain,
        errorBuilder: (context, error, stack) => Center(
          child: Container(
            width: size * 0.36,
            height: size * 0.36,
            decoration: BoxDecoration(color: fallbackColor, shape: BoxShape.circle),
          ),
        ),
      ),
    );
  }
}
