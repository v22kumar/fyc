import 'package:flutter/material.dart';

import '../../../../core/design_system/tokens.dart';
import '../../../../core/theme/app_theme.dart';

/// The shape of the answer, while the answer is loading.
///
/// A spinner tells somebody to wait. A skeleton tells them what they are
/// waiting for, and on the connections these members actually have — a bar of
/// 3G in Vadasery — that difference is most of what "fast" means. The page
/// also does not jump when the real cards arrive, because the space was
/// already the right size.
class ListingSkeleton extends StatefulWidget {
  const ListingSkeleton({super.key, this.count = 4});

  final int count;

  @override
  State<ListingSkeleton> createState() => _ListingSkeletonState();
}

class _ListingSkeletonState extends State<ListingSkeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _shimmer = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _shimmer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var i = 0; i < widget.count; i++)
          AnimatedBuilder(
            animation: _shimmer,
            builder: (context, _) => Opacity(
              // Gentle. A skeleton that pulses hard reads as an error state,
              // and somebody on a slow connection is already anxious.
              opacity: 0.35 + (_shimmer.value * 0.25),
              child: _Card(),
            ),
          ),
      ],
    );
  }
}

class _Card extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    Widget bar(double widthFactor, double height) => FractionallySizedBox(
          alignment: Alignment.centerLeft,
          widthFactor: widthFactor,
          child: Container(
            height: height,
            decoration: BoxDecoration(
              color: context.cBorder,
              borderRadius: BorderRadius.circular(6),
            ),
          ),
        );

    return Container(
      margin: EdgeInsets.only(bottom: DSSpacing.sm),
      padding: EdgeInsets.all(DSSpacing.sm),
      decoration: BoxDecoration(
        color: context.cSurface,
        borderRadius: BorderRadius.circular(DSRadius.card),
        border: Border.all(color: context.cBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Same rhythm as a real card: name, place, trust, two buttons.
          bar(0.45, 16),
          const SizedBox(height: 8),
          bar(0.75, 12),
          const SizedBox(height: 8),
          bar(0.35, 12),
          SizedBox(height: DSSpacing.xs),
          Row(
            children: [
              Expanded(child: bar(1, 40)),
              SizedBox(width: DSSpacing.xs),
              Expanded(child: bar(1, 40)),
            ],
          ),
        ],
      ),
    );
  }
}
