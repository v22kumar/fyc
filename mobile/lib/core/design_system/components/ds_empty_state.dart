import 'package:flutter/material.dart';
import '../tokens.dart';
import 'ds_button.dart';

/// Never show a raw "No Data". Every empty list gets an illustration (icon
/// fallback when no asset is supplied), a helpful explanation, and a primary
/// action — with an optional secondary action (spec §19: Create / Explore /
/// Refresh / Invite / Learn More).
class DSEmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final String? imageAsset;
  final String primaryLabel;
  final VoidCallback onPrimary;
  final String? secondaryLabel;
  final VoidCallback? onSecondary;

  const DSEmptyState({
    super.key,
    this.icon = Icons.inbox_rounded,
    required this.title,
    required this.message,
    this.imageAsset,
    required this.primaryLabel,
    required this.onPrimary,
    this.secondaryLabel,
    this.onSecondary,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(DSSpacing.md),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (imageAsset != null)
              Image.asset(
                imageAsset!,
                width: 150,
                height: 150,
                errorBuilder: (_, __, ___) => _iconBubble(context),
              )
            else
              _iconBubble(context),
            const SizedBox(height: DSSpacing.sm),
            Text(title, style: Theme.of(context).textTheme.headlineMedium?.copyWith(color: context.dsText),
                textAlign: TextAlign.center),
            const SizedBox(height: 8),
            Text(message, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: context.dsTextSecondary),
                textAlign: TextAlign.center),
            const SizedBox(height: DSSpacing.md),
            SizedBox(
              width: 220,
              child: DSButton.filled(label: primaryLabel, onPressed: onPrimary, fullWidth: true),
            ),
            if (secondaryLabel != null && onSecondary != null) ...[
              const SizedBox(height: 8),
              DSButton.text(label: secondaryLabel!, onPressed: onSecondary, fullWidth: false),
            ],
          ],
        ),
      ),
    );
  }

  Widget _iconBubble(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(color: context.dsAccent.withOpacity(0.1), shape: BoxShape.circle),
      child: Icon(icon, size: 56, color: context.dsAccent),
    );
  }
}
