import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Animated glowing-particle background for chess game screens.
/// Renders a dark vignette with soft green "firefly" particles drifting
/// upward — matches the premium arena look in the reference design.
class ChessArenaBackground extends StatefulWidget {
  final Widget child;
  const ChessArenaBackground({super.key, required this.child});

  @override
  State<ChessArenaBackground> createState() => _ChessArenaBackgroundState();
}

class _ChessArenaBackgroundState extends State<ChessArenaBackground>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final List<_Particle> _particles;

  @override
  void initState() {
    super.initState();
    final rnd = math.Random(42);
    _particles = List.generate(26, (_) => _Particle.random(rnd));
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 12),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Base gradient
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: const Alignment(0, -0.3),
                radius: 1.2,
                colors: [
                  const Color(0xFF14301F), // green-tinted center glow
                  const Color(0xFF0E1A12),
                  const Color(0xFF080C09), // near-black edges
                ],
                stops: const [0.0, 0.55, 1.0],
              ),
            ),
          ),
        ),
        // Drifting particles
        Positioned.fill(
          child: AnimatedBuilder(
            animation: _ctrl,
            builder: (_, __) => CustomPaint(
              painter: _ParticlePainter(_particles, _ctrl.value),
            ),
          ),
        ),
        widget.child,
      ],
    );
  }
}

class _Particle {
  final double x;        // 0..1 horizontal
  final double baseY;    // 0..1 vertical start
  final double size;     // px
  final double speed;    // cycles per full animation
  final double phase;    // 0..1 offset
  final double opacity;

  _Particle(this.x, this.baseY, this.size, this.speed, this.phase, this.opacity);

  factory _Particle.random(math.Random r) => _Particle(
        r.nextDouble(),
        r.nextDouble(),
        1.5 + r.nextDouble() * 3.5,
        0.4 + r.nextDouble() * 0.9,
        r.nextDouble(),
        0.10 + r.nextDouble() * 0.45,
      );
}

class _ParticlePainter extends CustomPainter {
  final List<_Particle> particles;
  final double t;

  _ParticlePainter(this.particles, this.t);

  @override
  void paint(Canvas canvas, Size size) {
    final glow = Paint()..color = const Color(0xFF34D17A);
    for (final p in particles) {
      // Drift upward, wrap around
      final prog = ((t * p.speed) + p.phase) % 1.0;
      final y = (p.baseY - prog) % 1.0;
      final dx = p.x * size.width +
          math.sin((prog + p.phase) * math.pi * 2) * 14;
      final dy = y * size.height;

      // Twinkle
      final twinkle =
          0.5 + 0.5 * math.sin((t + p.phase) * math.pi * 4);
      final op = (p.opacity * twinkle).clamp(0.0, 1.0);

      glow.color = const Color(0xFF34D17A).withOpacity(op);
      glow.maskFilter = MaskFilter.blur(BlurStyle.normal, p.size * 1.2);
      canvas.drawCircle(Offset(dx, dy), p.size, glow);

      // Bright core
      glow.maskFilter = null;
      glow.color = const Color(0xFF8CF0B8).withOpacity(op * 0.8);
      canvas.drawCircle(Offset(dx, dy), p.size * 0.5, glow);
    }
  }

  @override
  bool shouldRepaint(_ParticlePainter old) => old.t != t;
}
