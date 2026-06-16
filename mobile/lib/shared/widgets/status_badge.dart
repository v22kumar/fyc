import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';

/// Colored pill used to show a short status/category label.
///
/// Replaces the duplicated `Container(decoration: BoxDecoration(...))`
/// status chips found in events, sports fixtures, and announcements screens.
class StatusBadge extends StatelessWidget {
  final String label;
  final Color color;

  /// When true, [color] is used at low opacity as the background and at
  /// full opacity as the text color (the "soft" announcement-category
  /// style). When false, [color] fills the background and the text is
  /// white (the "solid" live/status style).
  final bool soft;

  const StatusBadge({
    super.key,
    required this.label,
    required this.color,
    this.soft = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: soft ? color.withOpacity(0.12) : color,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: soft ? color : Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.3,
        ),
      ),
    );
  }

  factory StatusBadge.success(String label) =>
      StatusBadge(label: label, color: AppColors.success);

  factory StatusBadge.warning(String label) =>
      StatusBadge(label: label, color: AppColors.warning);

  factory StatusBadge.neutral(String label) =>
      StatusBadge(label: label, color: AppColors.textSecondary);
}
