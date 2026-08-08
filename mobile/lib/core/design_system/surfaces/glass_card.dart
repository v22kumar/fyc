import 'dart:ui';

import 'package:flutter/material.dart';

import '../tokens.dart';

/// A tinted, translucent surface that lets the mesh show through.
///
/// The launcher tiles get shorter and much stronger in colour. Eight saturated
/// glass tiles in one screen reads as considered; seven tall pale boxes across
/// three screens reads as unfinished — and the second is what Home had.
///
/// Blur is expensive, so it is applied once per card and the card is wrapped in
/// a RepaintBoundary: without that, scrolling a grid of these repaints every
/// blur on every frame on exactly the cheap phones this app is for.
class GlassCard extends StatelessWidget {
  const GlassCard({
    super.key,
    required this.child,
    required this.tint,
    this.onTap,
    this.height,
    this.blur = 18,
    this.padding,
  });

  final Widget child;

  /// The card's own colour, laid over the mesh at low alpha. Saturated is the
  /// point — a glass tile in grey is just a grey tile.
  final Color tint;

  final VoidCallback? onTap;
  final double? height;
  final double blur;
  final EdgeInsets? padding;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(DSRadius.card);

    return RepaintBoundary(
      child: DecoratedBox(
        // The tile throws its own colour onto the ground beneath it. This is
        // what separates a card sitting on a background from a card that
        // belongs to it.
        decoration: BoxDecoration(
          borderRadius: radius,
          boxShadow: [
            BoxShadow(
              color: tint.withValues(alpha: 0.45),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: ClipRRect(
        borderRadius: radius,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onTap,
              borderRadius: radius,
              child: Container(
                height: height,
                padding: padding ?? EdgeInsets.all(DSSpacing.sm),
                decoration: BoxDecoration(
                  borderRadius: radius,
                  // Two stops rather than one, so the surface has a direction
                  // and catches light at the top like a real pane would.
                  // Strong enough that the colour survives the ground.
                  //
                  // At a third alpha the mesh showed through and desaturated
                  // everything — crimson became maroon, gold became brown. A
                  // glass tile has to read as its own colour first and as
                  // translucent second, or it is just a grey tile with extra
                  // cost.
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      tint.withValues(alpha: 0.92),
                      tint.withValues(alpha: 0.62),
                    ],
                  ),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.22),
                    width: 1.2,
                  ),
                ),
                child: child,
              ),
            ),
          ),
        ),
        ),
      ),
    );
  }
}

/// The graphic behind a hero when there is no photograph.
///
/// Deliberately abstract: arcs and a bloom read as designed at any size, where
/// a stock image reads as filler and a missing one reads as broken.
class _HeroGraphic extends CustomPainter {
  _HeroGraphic({required this.tint});

  final Color tint;

  @override
  void paint(Canvas canvas, Size size) {
    final bloom = Offset(size.width * 0.86, size.height * 0.18);
    canvas.drawCircle(
      bloom,
      size.width * 0.42,
      Paint()
        ..shader = RadialGradient(colors: [
          Colors.white.withValues(alpha: 0.30),
          Colors.white.withValues(alpha: 0),
        ]).createShader(
            Rect.fromCircle(center: bloom, radius: size.width * 0.42)),
    );

    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4
      ..color = Colors.white.withValues(alpha: 0.16);
    final centre = Offset(size.width * 0.82, size.height * 0.22);
    for (var r = 26.0; r < size.width * 0.7; r += 26) {
      canvas.drawCircle(centre, r, stroke);
    }
  }

  @override
  bool shouldRepaint(_HeroGraphic old) => old.tint != tint;
}

/// Full-bleed imagery with a scrim, for the few cards that carry weight.
///
/// Image, then a gradient scrim, then the words — the pattern every premium app
/// uses, and the single biggest change in perceived quality available here. The
/// scrim is not decoration: it is what keeps a headline legible over a
/// photograph nobody chose for its brightness.
class ScrimHero extends StatelessWidget {
  const ScrimHero({
    super.key,
    required this.child,
    required this.tint,
    this.image,
    this.height = 190,
    this.onTap,
  });

  final Widget child;

  /// Used behind the image, and instead of it when there is none — so a card
  /// with a missing photograph still looks intentional rather than broken.
  final Color tint;

  final ImageProvider? image;
  final double height;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(DSRadius.card);

    return RepaintBoundary(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          height: height,
          decoration: BoxDecoration(
            borderRadius: radius,
            boxShadow: [
              BoxShadow(
                color: tint.withValues(alpha: 0.34),
                blurRadius: 24,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: radius,
            child: Stack(
              fit: StackFit.expand,
              children: [
                DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        tint,
                        Color.lerp(tint, Colors.black, 0.45)!,
                      ],
                    ),
                  ),
                ),
                // Something in the upper two thirds.
                //
                // With text bottom-anchored and no photograph, the top of this
                // card was flat colour — which is what made the first pass
                // read as unfinished rather than rich. Concentric arcs and a
                // corner bloom give it a subject without needing an image
                // nobody has taken yet.
                Positioned.fill(
                  child: CustomPaint(painter: _HeroGraphic(tint: tint)),
                ),
                if (image != null)
                  Image(image: image!, fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const SizedBox.shrink()),
                // Bottom-weighted, because that is where the words are.
                DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withValues(alpha: 0.05),
                        Colors.black.withValues(alpha: 0.30),
                        Colors.black.withValues(alpha: 0.72),
                      ],
                      stops: const [0, 0.45, 1],
                    ),
                  ),
                ),
                Padding(padding: EdgeInsets.all(DSSpacing.md), child: child),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
