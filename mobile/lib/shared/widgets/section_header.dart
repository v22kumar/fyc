import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';

/// Bold, uppercase-style label used above list sections, with an optional
/// trailing action (e.g. "See all").
///
/// Replaces the identical private `_SectionHeader` widgets duplicated in
/// events, sports, directory, and green fyc screens.
class SectionHeader extends StatelessWidget {
  final String label;
  final Widget? trailing;
  final EdgeInsetsGeometry padding;

  const SectionHeader({
    super.key,
    required this.label,
    this.trailing,
    this.padding = const EdgeInsets.only(bottom: 10, top: 4),
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: AppColors.textSecondary,
              letterSpacing: 0.5,
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}
