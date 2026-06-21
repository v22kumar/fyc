import 'package:flutter/material.dart';

/// Lichess-style horizontal move bar.
/// Shows move pairs, auto-scrolls to the latest move, and displays a
/// thinking indicator when the engine is computing.
class ChessMoveBar extends StatefulWidget {
  final List<String> moveSans;
  final bool isThinking;
  final String thinkingLabel;

  const ChessMoveBar({
    super.key,
    required this.moveSans,
    this.isThinking = false,
    this.thinkingLabel = 'Thinking…',
  });

  @override
  State<ChessMoveBar> createState() => _ChessMoveBarState();
}

class _ChessMoveBarState extends State<ChessMoveBar> {
  final _scrollController = ScrollController();

  @override
  void didUpdateWidget(ChessMoveBar old) {
    super.didUpdateWidget(old);
    if (widget.moveSans.length != old.moveSans.length ||
        widget.isThinking != old.isThinking) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
          );
        }
      });
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pairs = <(String, String?)>[];
    for (var i = 0; i < widget.moveSans.length; i += 2) {
      pairs.add((
        widget.moveSans[i],
        i + 1 < widget.moveSans.length ? widget.moveSans[i + 1] : null,
      ));
    }

    final lastIdx = widget.moveSans.length - 1;

    return Container(
      height: 40,
      color: const Color(0xFF1E1B18),
      child: Row(
        children: [
          Expanded(
            child: pairs.isEmpty && !widget.isThinking
                ? const Center(
                    child: Text(
                      'Game start',
                      style: TextStyle(
                        color: Color(0xFF8B8682),
                        fontSize: 12,
                      ),
                    ),
                  )
                : ListView.separated(
                    controller: _scrollController,
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    itemCount: pairs.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 4),
                    itemBuilder: (context, i) {
                      final (white, black) = pairs[i];
                      final moveNum = i + 1;
                      final isLastPair = i == pairs.length - 1;
                      final whiteIdx = i * 2;
                      final blackIdx = i * 2 + 1;
                      return Row(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Text(
                            '$moveNum.',
                            style: const TextStyle(
                              color: Color(0xFF6B6762),
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(width: 3),
                          _MoveToken(
                            san: white,
                            isLatest: whiteIdx == lastIdx,
                          ),
                          if (black != null) ...[
                            const SizedBox(width: 3),
                            _MoveToken(
                              san: black,
                              isLatest: blackIdx == lastIdx,
                            ),
                          ],
                          // Thinking indicator after last partial move
                          if (widget.isThinking && isLastPair && black == null) ...[
                            const SizedBox(width: 6),
                            const _ThinkingIndicator(),
                          ],
                        ],
                      );
                    },
                  ),
          ),

          // If thinking and no moves yet, show indicator at right
          if (widget.isThinking && widget.moveSans.isEmpty)
            const Padding(
              padding: EdgeInsets.only(right: 10),
              child: _ThinkingIndicator(),
            ),
        ],
      ),
    );
  }
}

class _MoveToken extends StatelessWidget {
  final String san;
  final bool isLatest;

  const _MoveToken({required this.san, required this.isLatest});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 5),
      decoration: isLatest
          ? BoxDecoration(
              color: const Color(0xFF4A7C59),
              borderRadius: BorderRadius.circular(4),
            )
          : null,
      child: Text(
        san,
        style: TextStyle(
          color: isLatest ? Colors.white : const Color(0xFFD0CEC9),
          fontSize: 12,
          fontWeight: isLatest ? FontWeight.w700 : FontWeight.w500,
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
      ),
    );
  }
}

class _ThinkingIndicator extends StatefulWidget {
  const _ThinkingIndicator();

  @override
  State<_ThinkingIndicator> createState() => _ThinkingIndicatorState();
}

class _ThinkingIndicatorState extends State<_ThinkingIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    )..repeat(reverse: true);
    _anim = Tween(begin: 0.3, end: 1.0).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        FadeTransition(
          opacity: _anim,
          child: const Icon(
            Icons.circle,
            size: 6,
            color: Color(0xFF4A7C59),
          ),
        ),
        const SizedBox(width: 5),
        const Text(
          'thinking…',
          style: TextStyle(
            color: Color(0xFF8B8682),
            fontSize: 11,
            fontStyle: FontStyle.italic,
          ),
        ),
      ],
    );
  }
}
