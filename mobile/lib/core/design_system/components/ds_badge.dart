import 'package:flutter/material.dart';
import '../tokens.dart';

/// The six badge kinds the spec calls out. Fixed color + icon per kind so a
/// "LIVE" badge is visually identical everywhere in the app.
enum DSBadgeKind { live, urgent, isNew, verified, closed, volunteer }

class _BadgeStyle {
  final Color color;
  final IconData? icon;
  final String label;
  final bool pulse;
  const _BadgeStyle(this.color, this.icon, this.label, {this.pulse = false});
}

const Map<DSBadgeKind, _BadgeStyle> _badgeStyles = {
  DSBadgeKind.live: _BadgeStyle(DSColors.danger, null, 'LIVE', pulse: true),
  DSBadgeKind.urgent: _BadgeStyle(DSColors.danger, Icons.priority_high_rounded, 'URGENT'),
  DSBadgeKind.isNew: _BadgeStyle(DSColors.mint600, Icons.auto_awesome_rounded, 'NEW'),
  DSBadgeKind.verified: _BadgeStyle(DSColors.info, Icons.verified_rounded, 'VERIFIED'),
  DSBadgeKind.closed: _BadgeStyle(Color(0xFF6B7280), Icons.lock_rounded, 'CLOSED'),
  DSBadgeKind.volunteer: _BadgeStyle(DSColors.success, Icons.volunteer_activism_rounded, 'VOLUNTEER'),
};

/// Small status pill. Use [kind] for the six standard badges, or pass a
/// [labelOverride] to reuse a kind's color scheme with custom text.
class DSBadge extends StatefulWidget {
  final DSBadgeKind kind;
  final String? labelOverride;

  const DSBadge({super.key, required this.kind, this.labelOverride});

  @override
  State<DSBadge> createState() => _DSBadgeState();
}

class _DSBadgeState extends State<DSBadge> with SingleTickerProviderStateMixin {
  AnimationController? _pulseController;

  @override
  void initState() {
    super.initState();
    if (_badgeStyles[widget.kind]!.pulse) {
      _pulseController = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))
        ..repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _pulseController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final style = _badgeStyles[widget.kind]!;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: style.color, borderRadius: BorderRadius.circular(DSRadius.chip)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_pulseController != null) ...[
            FadeTransition(
              opacity: _pulseController!,
              child: Container(
                width: 6,
                height: 6,
                decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
              ),
            ),
            const SizedBox(width: 6),
          ] else if (style.icon != null) ...[
            Icon(style.icon, size: 12, color: Colors.white),
            const SizedBox(width: 4),
          ],
          Text(
            widget.labelOverride ?? style.label,
            style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 0.3),
          ),
        ],
      ),
    );
  }
}
