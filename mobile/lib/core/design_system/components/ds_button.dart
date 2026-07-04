import 'package:flutter/material.dart';
import '../tokens.dart';

enum DSButtonVariant { filled, outlined, tonal, text, danger }

/// The one button component every design-system screen uses. Five variants
/// per the spec: filled (primary action), outlined, tonal, text, danger.
class DSButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final DSButtonVariant variant;
  final IconData? icon;
  final bool loading;
  final bool fullWidth;

  const DSButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.variant = DSButtonVariant.filled,
    this.icon,
    this.loading = false,
    this.fullWidth = true,
  });

  const DSButton.filled({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.loading = false,
    this.fullWidth = true,
  }) : variant = DSButtonVariant.filled;

  const DSButton.outlined({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.loading = false,
    this.fullWidth = true,
  }) : variant = DSButtonVariant.outlined;

  const DSButton.tonal({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.loading = false,
    this.fullWidth = true,
  }) : variant = DSButtonVariant.tonal;

  const DSButton.text({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.loading = false,
    this.fullWidth = true,
  }) : variant = DSButtonVariant.text;

  const DSButton.danger({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.loading = false,
    this.fullWidth = true,
  }) : variant = DSButtonVariant.danger;

  bool get _disabled => onPressed == null || loading;

  @override
  Widget build(BuildContext context) {
    final child = loading
        ? SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(
              strokeWidth: 2.2,
              valueColor: AlwaysStoppedAnimation<Color>(_foreground(context)),
            ),
          )
        : Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 18),
                const SizedBox(width: 8),
              ],
              Text(label),
            ],
          );

    final button = switch (variant) {
      DSButtonVariant.filled => FilledButton(
          onPressed: _disabled ? null : onPressed,
          style: FilledButton.styleFrom(
            backgroundColor: context.dsAccent,
            foregroundColor: Colors.white,
            disabledBackgroundColor: context.dsAccent.withOpacity(0.4),
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: DSSpacing.md),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(DSRadius.button)),
          ),
          child: child,
        ),
      DSButtonVariant.outlined => OutlinedButton(
          onPressed: _disabled ? null : onPressed,
          style: OutlinedButton.styleFrom(
            foregroundColor: context.dsPrimary,
            side: BorderSide(color: context.dsPrimary.withOpacity(_disabled ? 0.3 : 0.6), width: 1.5),
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: DSSpacing.md),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(DSRadius.button)),
          ),
          child: child,
        ),
      DSButtonVariant.tonal => FilledButton.tonal(
          onPressed: _disabled ? null : onPressed,
          style: FilledButton.styleFrom(
            backgroundColor: context.dsAccent.withOpacity(0.12),
            foregroundColor: context.dsAccent,
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: DSSpacing.md),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(DSRadius.button)),
          ),
          child: child,
        ),
      DSButtonVariant.text => TextButton(
          onPressed: _disabled ? null : onPressed,
          style: TextButton.styleFrom(
            foregroundColor: context.dsPrimary,
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: DSSpacing.sm),
          ),
          child: child,
        ),
      DSButtonVariant.danger => FilledButton(
          onPressed: _disabled ? null : onPressed,
          style: FilledButton.styleFrom(
            backgroundColor: DSColors.danger,
            foregroundColor: Colors.white,
            disabledBackgroundColor: DSColors.danger.withOpacity(0.4),
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: DSSpacing.md),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(DSRadius.button)),
          ),
          child: child,
        ),
    };

    if (!fullWidth) return button;
    return SizedBox(width: double.infinity, child: button);
  }

  Color _foreground(BuildContext context) {
    switch (variant) {
      case DSButtonVariant.filled:
      case DSButtonVariant.danger:
        return Colors.white;
      case DSButtonVariant.outlined:
      case DSButtonVariant.text:
        return context.dsPrimary;
      case DSButtonVariant.tonal:
        return context.dsAccent;
    }
  }
}
