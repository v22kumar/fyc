import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class EmptyState extends StatelessWidget {
  final String emoji;
  final String title;
  final String message;
  final String? buttonText;
  final VoidCallback? onAction;

  /// Optional Material Symbol shown in the bubble instead of the emoji — the
  /// preferred path (emoji render inconsistently across OEM font stacks).
  final IconData? icon;

  /// Optional illustration asset shown instead of the emoji/icon bubble.
  final String? imageAsset;

  const EmptyState({
    super.key,
    this.emoji = '',
    required this.title,
    required this.message,
    this.buttonText,
    this.onAction,
    this.icon,
    this.imageAsset,
  });

  Widget _glyph(BuildContext context) => icon != null
      ? Icon(icon, size: 56, color: AppColors.primary)
      : Text(emoji, style: const TextStyle(fontSize: 64));

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.paddingPage),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (imageAsset != null)
              Image.asset(
                imageAsset!,
                width: 170,
                height: 170,
                errorBuilder: (_, __, ___) => Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: context.cSurface,
                    shape: BoxShape.circle,
                    boxShadow: AppTheme.glowShadow,
                  ),
                  child: _glyph(context),
                ),
              )
            else
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: context.cSurface,
                  shape: BoxShape.circle,
                  boxShadow: AppTheme.glowShadow,
                ),
                child: _glyph(context),
              ),
            const SizedBox(height: 24),
            Text(
              title,
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                color: context.cText,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              message,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: context.cTextSecondary,
              ),
              textAlign: TextAlign.center,
            ),
            if (buttonText != null && onAction != null) ...[
              const SizedBox(height: 32),
              SizedBox(
                width: 200,
                child: ElevatedButton(
                  onPressed: onAction,
                  child: Text(buttonText!),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
