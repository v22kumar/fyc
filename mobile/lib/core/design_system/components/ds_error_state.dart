import '../../l10n/tr.dart';
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
        padding: EdgeInsets.all(DSSpacing.md),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: EdgeInsets.all(24),
              decoration: BoxDecoration(color: DSColors.dangerSurface, shape: BoxShape.circle),
              child: Icon(Icons.cloud_off_rounded, size: 48, color: DSColors.danger),
            ),
            SizedBox(height: DSSpacing.sm),
            Text(
              message,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(color: context.dsText),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: DSSpacing.md),
            // Was pinned to 200px, which fitted "Retry" and not
            // "மீண்டும் முயற்சிக்கவும்" — the label spilled past the button
            // and the middle of the words stopped being tappable. A minimum
            // keeps a short label from looking mean; the maximum keeps a long
            // one on the screen.
            ConstrainedBox(
              constraints: const BoxConstraints(minWidth: 200, maxWidth: 320),
              child: DSButton.filled(
                label: trId('retry'),
                icon: Icons.refresh_rounded,
                onPressed: onRetry,
              ),
            ),
            if (secondaryLabel != null && onSecondary != null) ...[
              SizedBox(height: 8),
              DSButton.text(label: secondaryLabel!, onPressed: onSecondary, fullWidth: false),
            ],
          ],
        ),
      ),
    );
  }
}
