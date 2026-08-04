import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';

/// Thin wrapper around the app's standard card styling
/// (`AppTheme.radiusCard`, subtle border, optional tap handler).
///
/// Replaces one-off `Card`/`Container` blocks repeated across feature
/// screens (event, donor, contact, fixture cards, etc) that all reproduce
/// the same padding/margin/border values by hand.
class AppCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry margin;
  // Nullable so they can default to the (runtime, non-const) theme colours,
  // resolved in build() — a theme getter can't be a const default value.
  final Color? backgroundColor;
  final Color? borderColor;
  final VoidCallback? onTap;

  const AppCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.margin = const EdgeInsets.only(bottom: 12),
    this.backgroundColor,
    this.borderColor,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final card = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: backgroundColor ?? AppColors.surface,
        borderRadius: BorderRadius.circular(AppTheme.radiusCard),
        border: Border.all(color: borderColor ?? AppColors.border),
      ),
      child: child,
    );

    return Padding(
      padding: margin,
      child: onTap == null
          ? card
          : Material(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(AppTheme.radiusCard),
              child: InkWell(
                onTap: onTap,
                borderRadius: BorderRadius.circular(AppTheme.radiusCard),
                child: card,
              ),
            ),
    );
  }
}
