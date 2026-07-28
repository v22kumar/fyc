import 'package:flutter/material.dart';

/// A gently twinkling sparkle that signals AI-generated content. Shared by the
/// AI cards so the "intelligence" cue reads the same everywhere.
class AiSparkle extends StatefulWidget {
  final double size;
  final Color color;
  AiSparkle({super.key, this.size = 18, this.color = AppColors.background});

  @override
  State<AiSparkle> createState() => _AiSparkleState();
}

class _AiSparkleState extends State<AiSparkle>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1700),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) {
        final t = _c.value;
        return Transform.scale(
          scale: 0.82 + 0.28 * t,
          child: Transform.rotate(
            angle: 0.10 * t,
            child: Opacity(
              opacity: 0.55 + 0.45 * t,
              child: Icon(Icons.auto_awesome, size: widget.size, color: widget.color),
            ),
          ),
        );
      },
    );
  }
}

/// A soft pulsing placeholder bar for AI "thinking" skeletons.
class AiSkeletonBar extends StatelessWidget {
  final double widthFactor;
  final Color color;
  AiSkeletonBar({super.key, this.widthFactor = 1, this.color = AppColors.background});

  @override
  Widget build(BuildContext context) {
    return FractionallySizedBox(
      alignment: Alignment.centerLeft,
      widthFactor: widthFactor,
      child: Container(
        height: 11,
        decoration: BoxDecoration(
          color: color.withOpacity(0.22),
          borderRadius: BorderRadius.circular(6),
        ),
      ),
    );
  }
}
