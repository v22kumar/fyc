import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';
import '../tokens.dart';

/// Tabs that start at the left edge and stay legible in every language.
///
/// A scrollable [TabBar] centres its tabs by default. With short English labels
/// that looks tidy; with Tamil labels, which are longer, the row overflows in
/// both directions — so the screen opens already scrolled, the first tabs are
/// off the left edge, and the selected-tab indicator sits under nothing. That
/// is exactly what Events did.
///
/// Starting at the left is not just the fix, it is the better default: the
/// first tab is the one people read first, and the row scrolls the way every
/// other horizontal list in the app scrolls.
class DSTabBar extends StatelessWidget implements PreferredSizeWidget {
  const DSTabBar({
    super.key,
    required this.tabs,
    this.controller,
    this.onBrand = true,
  });

  final List<String> tabs;
  final TabController? controller;

  /// True when the tabs sit on the brand-coloured header; false on a page body.
  final bool onBrand;

  @override
  Size get preferredSize => const Size.fromHeight(48);

  @override
  Widget build(BuildContext context) {
    final selected = onBrand ? Colors.white : AppColors.primary;
    final unselected =
        onBrand ? Colors.white.withOpacity(0.68) : AppColors.textSecondary;

    return SizedBox(
      height: 48,
      child: TabBar(
        controller: controller,
        isScrollable: true,
        // The whole point: begin at the left edge.
        tabAlignment: TabAlignment.start,
        labelColor: selected,
        unselectedLabelColor: unselected,
        indicatorColor: selected,
        indicatorSize: TabBarIndicatorSize.label,
        indicatorWeight: 3,
        dividerColor: Colors.transparent,
        labelStyle: Theme.of(context).textTheme.titleSmall,
        unselectedLabelStyle: Theme.of(context).textTheme.titleSmall,
        labelPadding: EdgeInsets.symmetric(horizontal: DSSpacing.md),
        splashBorderRadius: BorderRadius.circular(DSRadius.button),
        tabs: [for (final t in tabs) Tab(text: t)],
      ),
    );
  }
}

/// A row of filter chips that cannot silently lose its last option.
///
/// Every chip row in the app ran off the right edge with no sign that anything
/// was there. This keeps them scrollable but adds the two things that were
/// missing: padding so the last chip clears the edge, and a fade at the edge so
/// it is visible that the row continues.
class DSFilterRow extends StatelessWidget {
  const DSFilterRow({super.key, required this.children, this.padding});

  final List<Widget> children;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    final bg = Theme.of(context).scaffoldBackgroundColor;
    return ShaderMask(
      shaderCallback: (rect) => LinearGradient(
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
        stops: const [0, 0.92, 1],
        colors: [bg, bg, bg.withOpacity(0)],
      ).createShader(rect),
      blendMode: BlendMode.dstIn,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: padding ??
            EdgeInsets.symmetric(horizontal: DSSpacing.md, vertical: DSSpacing.xs),
        child: Row(
          children: [
            for (var i = 0; i < children.length; i++) ...[
              if (i > 0) SizedBox(width: DSSpacing.xs),
              children[i],
            ],
            // Breathing room so the final chip is never flush to the edge.
            SizedBox(width: DSSpacing.md),
          ],
        ),
      ),
    );
  }
}
