import 'package:flutter/material.dart';
import '../tokens.dart';
import 'ds_button.dart';

/// Human-language error state (spec §21): never show "500 Error" — show what
/// happened and what to do about it, with a retry and an optional secondary
/// escape hatch (e.g. "Go Home").
class DSErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  final String? secondaryLabel;
  final VoidCallback? onSecondary;

  const DSErrorState({
    super.key,
    required this.message,
    required this.onRetry,
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
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(color: DSColors.dangerSurface, shape: BoxShape.circle),
              child: const Icon(Icons.cloud_off_rounded, size: 48, color: DSColors.danger),
            ),
            const SizedBox(height: DSSpacing.sm),
            Text(
              message,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(color: context.dsText),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: DSSpacing.md),
            SizedBox(width: 200, child: DSButton.filled(label: 'Retry', icon: Icons.refresh_rounded, onPressed: onRetry)),
            if (secondaryLabel != null && onSecondary != null) ...[
              const SizedBox(height: 8),
              DSButton.text(label: secondaryLabel!, onPressed: onSecondary, fullWidth: false),
            ],
          ],
        ),
      ),
    );
  }
}
