import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';

/// Reusable "nothing here" placeholder for list/grid screens.
///
/// Replaces the ad-hoc `Center(child: Column(...))` blocks duplicated across
/// feature screens (events, gallery, blood donation, green fyc, etc).
class EmptyState extends StatelessWidget {
  /// Emoji shown above the title, e.g. '🎗️'. Ignored if [icon] is set.
  final String? emoji;

  /// Material icon shown above the title. Takes precedence over [emoji].
  final IconData? icon;

  final String title;
  final String? subtitle;

  const EmptyState({
    super.key,
    this.emoji,
    this.icon,
    required this.title,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null)
              Icon(icon, size: 56, color: AppColors.textSecondary)
            else if (emoji != null)
              Text(emoji!, style: const TextStyle(fontSize: 64)),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 6),
              Text(
                subtitle!,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
