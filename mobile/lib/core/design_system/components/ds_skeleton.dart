import 'package:flutter/material.dart';
import '../tokens.dart';
import 'package:fyc_connect/core/theme/app_theme.dart';

/// A single shimmering block. Compose these into skeleton layouts that match
/// the real content's shape — never a full-screen spinner (spec §20).
class DSSkeletonBlock extends StatefulWidget {
  final double width;
  final double height;
  final double radius;

  const DSSkeletonBlock({super.key, required this.width, required this.height, this.radius = 8});

  @override
  State<DSSkeletonBlock> createState() => _DSSkeletonBlockState();
}

class _DSSkeletonBlockState extends State<DSSkeletonBlock> with SingleTickerProviderStateMixin {
  late final AnimationController _controller =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 1400))..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final base = context.dsIsDark ? DSColors.borderDark : DSColors.borderLight;
    final highlight = context.dsIsDark ? DSColors.surfaceDarkSolid : AppColors.background;
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final t = _controller.value;
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(widget.radius),
            gradient: LinearGradient(
              colors: [base, highlight, base],
              stops: const [0.0, 0.5, 1.0],
              begin: Alignment(t * 2 - 1 - 1.0, -0.3),
              end: Alignment(t * 2 - 1 + 1.0, 0.3),
            ),
          ),
        );
      },
    );
  }
}

/// A ready-made skeleton for a list of DSCard-shaped items — the common
/// "list is loading" state across Feed/Play/Serve.
class DSSkeletonList extends StatelessWidget {
  final int itemCount;
  const DSSkeletonList({super.key, this.itemCount = 4});

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: EdgeInsets.all(DSSpacing.sm),
      itemCount: itemCount,
      itemBuilder: (context, index) => Padding(
        padding: EdgeInsets.only(bottom: DSSpacing.xs),
        child: Container(
          padding: EdgeInsets.all(DSSpacing.sm),
          decoration: BoxDecoration(
            color: context.dsSurface,
            borderRadius: BorderRadius.circular(DSRadius.card),
            border: Border.all(color: context.dsBorder),
          ),
          child: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  DSSkeletonBlock(width: 40, height: 40, radius: 20),
                  SizedBox(width: 12),
                  Expanded(child: DSSkeletonBlock(width: double.infinity, height: 14)),
                ],
              ),
              SizedBox(height: 14),
              DSSkeletonBlock(width: double.infinity, height: 14),
              SizedBox(height: 8),
              DSSkeletonBlock(width: 160, height: 14),
            ],
          ),
        ),
      ),
    );
  }
}
