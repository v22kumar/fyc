import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

/// A single self-explaining service tile — the core unit of the redesigned
/// Home (and, progressively, the rest of the app). It mirrors the clarity of
/// the web: a tinted icon square, a title, one line of description, an optional
/// status pill, and an "Open" affordance, all on the tonal Kolam surface.
///
/// Designed to sit in a 2-column grid; the description flexes so the "Open"
/// row always pins to the bottom and the cell never overflows.
class DSFeatureCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  /// The category accent — used for the icon tint and the "Open" affordance.
  final Color tint;

  /// Optional short status marker (e.g. "New", "Eco", "Jobs").
  final String? pillLabel;

  /// Pill colour; defaults to [tint] when a [pillLabel] is set.
  final Color? pillColor;

  /// The "Open" affordance label; pass a localized string.
  final String actionLabel;

  final VoidCallback onTap;

  const DSFeatureCard({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.tint,
    required this.onTap,
    this.pillLabel,
    this.pillColor,
    this.actionLabel = 'Open',
  });

  @override
  Widget build(BuildContext context) {
    final pill = pillColor ?? tint;
    return Material(
      color: context.cSurface,
      borderRadius: BorderRadius.circular(AppTheme.radiusCard),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppTheme.radiusCard),
        child: Ink(
          decoration: BoxDecoration(
            color: context.cSurface,
            borderRadius: BorderRadius.circular(AppTheme.radiusCard),
            border: Border.all(color: context.cBorder),
            boxShadow: context.isDark ? null : AppTheme.cardShadow,
          ),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Stack(
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: tint.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(13),
                      ),
                      child: Icon(icon, color: tint, size: 23),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: context.cText,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Expanded(
                      child: Text(
                        subtitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          height: 1.35,
                          color: context.cTextSecondary,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          actionLabel,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: tint,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Icon(Icons.arrow_forward_rounded, size: 13, color: tint),
                      ],
                    ),
                  ],
                ),
                if (pillLabel != null)
                  Positioned(
                    top: 0,
                    right: 0,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                      decoration: BoxDecoration(
                        color: pill.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(7),
                      ),
                      child: Text(
                        pillLabel!.toUpperCase(),
                        style: TextStyle(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.6,
                          color: pill,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
