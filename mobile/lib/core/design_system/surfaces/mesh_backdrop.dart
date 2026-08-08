import 'dart:math' as math;

import 'package:flutter/material.dart';

/// A mesh-gradient ground for a whole page.
///
/// Several soft radial gradients blended behind everything, drifting slowly
/// with scroll. It reads as depth rather than as a background colour — and it
/// costs a member nothing to look at, because there is nothing in it to decide
/// about. Richness in the ground is free; richness in the number of choices is
/// not.
///
/// Painted once, as a single custom paint, so this is one layer rather than a
/// stack of decorated boxes.
class MeshBackdrop extends StatelessWidget {
  const MeshBackdrop({
    super.key,
    required this.child,
    required this.colors,
    this.scroll = 0,
    this.intensity = 1,
  });

  final Widget child;

  /// Three or four hues. They bleed into each other, so they want to be
  /// related — a mesh of unrelated colours reads as a fault, not a gradient.
  final List<Color> colors;

  /// Current scroll offset. The blobs drift at different rates, which is what
  /// separates this from a static image.
  final double scroll;

  /// 0 flattens it away entirely, for anybody who finds it busy.
  final double intensity;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(
          child: RepaintBoundary(
            child: CustomPaint(
              painter: _MeshPainter(
                colors: colors,
                scroll: scroll,
                intensity: intensity.clamp(0, 1),
                base: Theme.of(context).scaffoldBackgroundColor,
              ),
            ),
          ),
        ),
        child,
      ],
    );
  }
}

class _MeshPainter extends CustomPainter {
  _MeshPainter({
    required this.colors,
    required this.scroll,
    required this.intensity,
    required this.base,
  });

  final List<Color> colors;
  final double scroll;
  final double intensity;
  final Color base;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = base);
    if (intensity == 0 || colors.isEmpty) return;

    // Each blob has its own drift rate and phase, so they never move as a
    // block — which is what would make it look like a scrolling image.
    for (var i = 0; i < colors.length; i++) {
      final phase = i * 1.7;
      final drift = scroll * (0.06 + i * 0.035);

      final cx = size.width *
          (0.2 + 0.6 * (0.5 + 0.5 * math.sin(phase + drift / 240)));
      final cy = size.height *
              (0.12 + 0.22 * i) -
          drift * 0.35;

      final radius = size.width * (0.55 + 0.12 * math.sin(phase));

      canvas.drawCircle(
        Offset(cx, cy),
        radius,
        Paint()
          ..shader = RadialGradient(
            colors: [
              colors[i].withValues(alpha: 0.42 * intensity),
              colors[i].withValues(alpha: 0),
            ],
          ).createShader(
              Rect.fromCircle(center: Offset(cx, cy), radius: radius))
          // Plus, so overlapping blobs brighten rather than muddy. Over-drawing
          // translucent circles with the default blend is what makes a mesh
          // look like spilled ink.
          ..blendMode = BlendMode.plus,
      );
    }
  }

  @override
  bool shouldRepaint(_MeshPainter old) =>
      old.scroll != scroll ||
      old.intensity != intensity ||
      old.base != base ||
      !listEquals(old.colors, colors);
}

bool listEquals(List<Color> a, List<Color> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}
