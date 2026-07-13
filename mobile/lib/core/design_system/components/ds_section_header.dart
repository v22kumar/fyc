import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

/// A standard section header: an optional leading icon, a title, and an optional
/// trailing action ("View all →"). The reusable version of the per-screen
/// section headers, so every list on Home reads the same.
class DSSectionHeader extends StatelessWidget {
  final String title;
  final IconData? icon;
  final String? actionLabel;
  final VoidCallback? onAction;

  const DSSectionHeader({
    super.key,
    required this.title,
    this.icon,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          if (icon != null) ...[
            Icon(icon, size: 18, color: AppColors.primary),
            const SizedBox(width: 8),
          ],
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                  fontSize: 16, fontWeight: FontWeight.w800, color: context.cText),
            ),
          ),
          if (actionLabel != null && onAction != null)
            GestureDetector(
              onTap: onAction,
              behavior: HitTestBehavior.opaque,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    actionLabel!,
                    style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primaryLight),
                  ),
                  const Icon(Icons.chevron_right_rounded,
                      size: 16, color: AppColors.primaryLight),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
