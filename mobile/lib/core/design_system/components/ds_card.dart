import 'package:flutter/material.dart';
import '../tokens.dart';

/// The seven card contexts the spec calls out, each with its own accent
/// color + default icon so a screen never has to hand-pick colors per card.
enum DSCardKind { community, sports, event, issue, blood, achievement, volunteer, neutral }

class _CardStyle {
  final Color color;
  final IconData icon;
  const _CardStyle(this.color, this.icon);
}

const Map<DSCardKind, _CardStyle> _cardStyles = {
  DSCardKind.community: _CardStyle(DSColors.navy600, Icons.groups_rounded),
  DSCardKind.sports: _CardStyle(DSColors.amber600, Icons.sports_cricket_rounded),
  DSCardKind.event: _CardStyle(DSColors.mint600, Icons.event_rounded),
  DSCardKind.issue: _CardStyle(DSColors.warning, Icons.report_problem_rounded),
  DSCardKind.blood: _CardStyle(DSColors.danger, Icons.bloodtype_rounded),
  DSCardKind.achievement: _CardStyle(DSColors.amber600, Icons.emoji_events_rounded),
  DSCardKind.volunteer: _CardStyle(DSColors.success, Icons.volunteer_activism_rounded),
  DSCardKind.neutral: _CardStyle(DSColors.navy700, Icons.article_rounded),
};

/// A single card shell used everywhere: same radius (24), same three
/// elevation levels, same border treatment — only the accent color/icon
/// changes per [kind]. Screens build content with [child]; the card supplies
/// chrome (surface, border, radius, elevation, tap ripple).
class DSCard extends StatelessWidget {
  final DSCardKind kind;
  final Widget child;
  final VoidCallback? onTap;
  final double elevation;
  final EdgeInsetsGeometry padding;
  final bool showAccentBar;

  const DSCard({
    super.key,
    this.kind = DSCardKind.neutral,
    required this.child,
    this.onTap,
    this.elevation = DSElevation.card,
    this.padding = const EdgeInsets.all(DSSpacing.sm),
    this.showAccentBar = false,
  });

  IconData get icon => _cardStyles[kind]!.icon;
  Color get accentColor => _cardStyles[kind]!.color;

  @override
  Widget build(BuildContext context) {
    final shadows = DSElevation.shadowFor(elevation, dark: context.dsIsDark);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(DSRadius.card),
        child: AnimatedContainer(
          duration: DSMotion.standard,
          curve: DSMotion.curve,
          decoration: BoxDecoration(
            color: context.dsSurface,
            borderRadius: BorderRadius.circular(DSRadius.card),
            border: Border.all(color: context.dsBorder),
            boxShadow: shadows,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (showAccentBar)
                Container(
                  width: 4,
                  decoration: BoxDecoration(
                    color: accentColor,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(DSRadius.card),
                      bottomLeft: Radius.circular(DSRadius.card),
                    ),
                  ),
                ),
              Expanded(child: Padding(padding: padding, child: child)),
            ],
          ),
        ),
      ),
    );
  }
}

/// Small round icon badge matching a card's [DSCardKind] accent — the
/// leading visual most card layouts use (e.g. a blood-drop circle on a
/// blood-request card).
class DSCardIcon extends StatelessWidget {
  final DSCardKind kind;
  final double size;
  const DSCardIcon({super.key, required this.kind, this.size = 40});

  @override
  Widget build(BuildContext context) {
    final style = _cardStyles[kind]!;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: style.color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(size * 0.3),
      ),
      child: Icon(style.icon, color: style.color, size: size * 0.5),
    );
  }
}
