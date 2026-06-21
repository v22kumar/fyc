import 'dart:ui';
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
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: isActive
            ? const Color(0xFF1E2D1F)
            : const Color(0xFF1A1D1E),
        border: Border(
          top: BorderSide(
            color: isActive
                ? const Color(0xFF4A7C59).withOpacity(0.60)
                : Colors.white.withOpacity(0.05),
          ),
          bottom: BorderSide(
            color: isActive
                ? const Color(0xFF4A7C59).withOpacity(0.60)
                : Colors.white.withOpacity(0.05),
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
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    if (rating != null)
                      Text(
                        'Rating $rating',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.40),
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    if (captured.isNotEmpty) ...[
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          captured.join(''),
                          style: TextStyle(
                            fontSize: 10,
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

          // Active badge or just space
          if (isActive)
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
        ],
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
