import 'package:flutter/material.dart';
import '../tokens.dart';

/// The five chip contexts the spec calls out. Each has a sensible default
/// color; pass [color] to override for a specific value (e.g. a particular
/// sport or blood group).
enum DSChipKind { status, sport, bloodGroup, category, role }

const Map<DSChipKind, Color> _chipDefaults = {
  DSChipKind.status: DSColors.info,
  DSChipKind.sport: DSColors.amber600,
  DSChipKind.bloodGroup: DSColors.danger,
  DSChipKind.category: DSColors.navy600,
  DSChipKind.role: DSColors.mint700,
};

/// Known status → color mapping, used by [DSChip.status] convenience
/// constructor so every "LIVE" chip in the app looks identical.
const Map<String, Color> _statusColors = {
  'LIVE': DSColors.danger,
  'ONGOING': DSColors.info,
  'UPCOMING': DSColors.amber600,
  'SCHEDULED': DSColors.amber600,
  'COMPLETED': DSColors.success,
  'CLOSED': Color(0xFF6B7280),
  'CANCELLED': Color(0xFF6B7280),
  'REGISTRATION_OPEN': DSColors.success,
  'REGISTRATION_CLOSED': DSColors.warning,
};

class DSChip extends StatelessWidget {
  final String label;
  final DSChipKind kind;
  final Color? color;
  final IconData? icon;
  final bool selected;
  final VoidCallback? onTap;

  const DSChip({
    super.key,
    required this.label,
    this.kind = DSChipKind.category,
    this.color,
    this.icon,
    this.selected = false,
    this.onTap,
  });

  /// Convenience constructor that colors itself from [_statusColors] by the
  /// raw backend status string (case-insensitive), falling back to the
  /// generic status default.
  factory DSChip.status(String status, {VoidCallback? onTap}) {
    final key = status.toUpperCase();
    return DSChip(
      label: status,
      kind: DSChipKind.status,
      color: _statusColors[key] ?? _chipDefaults[DSChipKind.status],
      onTap: onTap,
    );
  }

  @override
  Widget build(BuildContext context) {
    final base = color ?? _chipDefaults[kind]!;
    final bg = selected ? base : base.withOpacity(0.12);
    final fg = selected ? Colors.white : base;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(DSRadius.chip),
        child: AnimatedContainer(
          duration: DSMotion.standard,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(DSRadius.chip)),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 14, color: fg),
                const SizedBox(width: 5),
              ],
              Text(
                label,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(color: fg),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
