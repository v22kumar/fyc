import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Kolam-inspired background texture — a *pulli* (dot) grid with
/// quarter-circle loops around alternating dots, the simplest classical
/// South Indian kolam motif. Drawn at very low opacity so it reads as
/// texture, not decoration (see docs/design/md3-elite-redesign.md §3.4).
///
/// Zero asset cost: pure canvas, no shaders. Wrap the paint in a
/// [RepaintBoundary] (KolamBackground does) so it rasters once.
class KolamPattern extends CustomPainter {
  final Color color;
  final double spacing;

  const KolamPattern({required this.color, this.spacing = 28});

  @override
  void paint(Canvas canvas, Size size) {
    final dot = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    final loop = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    final cols = (size.width / spacing).ceil() + 1;
    final rows = (size.height / spacing).ceil() + 1;
    for (var r = 0; r < rows; r++) {
      for (var c = 0; c < cols; c++) {
        final center = Offset(c * spacing, r * spacing);
        canvas.drawCircle(center, 1.2, dot);
        if ((r + c).isEven) {
          final rect = Rect.fromCircle(center: center, radius: spacing / 2.6);
          canvas.drawArc(rect, 0, math.pi / 2, false, loop);
          canvas.drawArc(rect, math.pi, math.pi / 2, false, loop);
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant KolamPattern oldDelegate) =>
      oldDelegate.color != color || oldDelegate.spacing != spacing;
}

/// Layers the kolam texture between the scaffold color and [child].
///
/// Defaults are theme-aware: 3% navy ink in light, 4% white in dark. Pass
/// [color]/[opacity] to place it inside branded areas (e.g. 6% white inside
/// a gradient hero header). Never place behind dense body text at higher
/// opacities — cards and sheets stay clean paper.
class KolamBackground extends StatelessWidget {
  final Widget child;
  final Color? color;
  final double? opacity;

  const KolamBackground({super.key, required this.child, this.color, this.opacity});

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final ink = color ?? (dark ? Colors.white : const Color(0xFF0A1128));
    final op = opacity ?? (dark ? 0.04 : 0.03);
    return Stack(
      children: [
        Positioned.fill(
          child: RepaintBoundary(
            child: CustomPaint(
              painter: KolamPattern(color: ink.withOpacity(op)),
            ),
          ),
        ),
        child,
      ],
    );
  }
}
