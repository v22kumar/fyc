import 'package:flutter/material.dart';

/// Lichess-style player card — shown above and below the board.
/// Displays avatar, name, rating, active indicator, thinking spinner, clock.
class ChessPlayerCard extends StatelessWidget {
  final String name;
  final int? rating;
  final bool isActive;
  final bool isThinking;

  /// A pre-built avatar widget. If null, falls back to [avatarLetter] initial.
  final Widget? avatarWidget;

  /// Single letter shown in the avatar circle when [avatarWidget] is null.
  final String? avatarLetter;

  /// Background color of the avatar circle.
  final Color avatarColor;

  /// Captured piece strings (unicode symbols)
  final List<String> captured;

  /// Optional clock label (e.g. "14:55"). When set, shown on the right.
  final String? clock;

  /// Whether the clock is low on time (turns red).
  final bool clockLow;

  /// Label shown next to the name while [isThinking] (e.g. "thinking").
  final String thinkingText;

  const ChessPlayerCard({
    super.key,
    required this.name,
    this.rating,
    this.isActive = false,
    this.isThinking = false,
    this.avatarWidget,
    this.avatarLetter,
    this.avatarColor = const Color(0xFF4A7C59),
    this.captured = const [],
    this.clock,
    this.clockLow = false,
    this.thinkingText = 'thinking',
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: isActive
            ? const Color(0xFF1E2D1F).withOpacity(0.85)
            : const Color(0xFF14181A).withOpacity(0.70),
        border: Border(
          top: BorderSide(
            color: isActive
                ? const Color(0xFF4A7C59).withOpacity(0.60)
                : Colors.white.withOpacity(0.04),
          ),
          bottom: BorderSide(
            color: isActive
                ? const Color(0xFF4A7C59).withOpacity(0.60)
                : Colors.white.withOpacity(0.04),
          ),
        ),
      ),
      child: Row(
        children: [
          // Avatar
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: avatarColor.withOpacity(isActive ? 1.0 : 0.55),
              boxShadow: isActive
                  ? [BoxShadow(color: avatarColor.withOpacity(0.40), blurRadius: 8)]
                  : null,
            ),
            child: Center(
              child: avatarWidget ??
                  Text(
                    avatarLetter ?? (name.isNotEmpty ? name[0].toUpperCase() : '?'),
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 16),
                  ),
            ),
          ),
          const SizedBox(width: 12),

          // Name + rating + captured
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        name,
                        style: TextStyle(
                          color: isActive ? Colors.white : Colors.white60,
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (isThinking) ...[
                      const SizedBox(width: 8),
                      const _ThinkingDots(),
                      const SizedBox(width: 6),
                      Text(
                        '$thinkingText…',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.45),
                          fontSize: 11,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    if (rating != null)
                      Row(
                        children: [
                          const Icon(Icons.shield_outlined,
                              size: 11, color: Color(0xFF7C8A80)),
                          const SizedBox(width: 3),
                          Text(
                            'Rating $rating',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.42),
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    if (captured.isNotEmpty) ...[
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          captured.join(''),
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.white.withOpacity(0.50),
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),

          // "Your turn" badge (only when active and no clock present)
          if (isActive && clock == null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFF4A7C59),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Text(
                'Your turn',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.2,
                ),
              ),
            ),

          // Clock
          if (clock != null) ...[
            if (isActive)
              Container(
                margin: const EdgeInsets.only(right: 8),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFF4A7C59),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text(
                  'Your turn',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            _ClockChip(label: clock!, isActive: isActive, isLow: clockLow),
          ],
        ],
      ),
    );
  }
}

class _ClockChip extends StatelessWidget {
  final String label;
  final bool isActive;
  final bool isLow;

  const _ClockChip({
    required this.label,
    required this.isActive,
    required this.isLow,
  });

  @override
  Widget build(BuildContext context) {
    final bg = isActive
        ? (isLow ? const Color(0xFF8E1B1B) : const Color(0xFF2A3A2C))
        : const Color(0xFF1A1D1E);
    final fg = isActive
        ? (isLow ? Colors.red.shade200 : Colors.white)
        : const Color(0xFF7C8A80);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
        border: isActive
            ? Border.all(
                color: isLow
                    ? Colors.red.shade400
                    : const Color(0xFF4A7C59).withOpacity(0.7),
                width: 1)
            : null,
      ),
      child: Text(
        label,
        style: TextStyle(
          color: fg,
          fontWeight: FontWeight.w800,
          fontSize: 18,
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
      ),
    );
  }
}

class _ThinkingDots extends StatefulWidget {
  const _ThinkingDots();

  @override
  State<_ThinkingDots> createState() => _ThinkingDotsState();
}

class _ThinkingDotsState extends State<_ThinkingDots>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 900))
      ..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (i) {
            final offset = (i / 3);
            final val = ((_ctrl.value + offset) % 1.0);
            final opacity = val < 0.5 ? val * 2 : 2 - val * 2;
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 1),
              child: Container(
                width: 4,
                height: 4,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFF4A7C59)
                      .withOpacity(0.4 + opacity * 0.6),
                ),
              ),
            );
          }),
        );
      },
    );
  }
}
