import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';

class MoveHistoryPanel extends StatefulWidget {
  final List<String> moveSans;

  const MoveHistoryPanel({super.key, required this.moveSans});

  @override
  State<MoveHistoryPanel> createState() => _MoveHistoryPanelState();
}

class _MoveHistoryPanelState extends State<MoveHistoryPanel> {
  final _scrollController = ScrollController();

  @override
  void didUpdateWidget(MoveHistoryPanel old) {
    super.didUpdateWidget(old);
    if (widget.moveSans.length != old.moveSans.length) {
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
    // Group into move pairs: [ (white, black?), ... ]
    final pairs = <(String, String?)>[];
    for (var i = 0; i < widget.moveSans.length; i += 2) {
      final white = widget.moveSans[i];
      final black = i + 1 < widget.moveSans.length ? widget.moveSans[i + 1] : null;
      pairs.add((white, black));
    }

    if (pairs.isEmpty) {
      return Container(
        height: 44,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.border),
        ),
        child: const Text(
          'No moves yet',
          style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
        ),
      );
    }

    return Container(
      height: 44,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: ListView.separated(
        controller: _scrollController,
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        itemCount: pairs.length,
        separatorBuilder: (_, __) => const SizedBox(width: 2),
        itemBuilder: (context, i) {
          final (white, black) = pairs[i];
          final moveNum = i + 1;
          final isLast = i == pairs.length - 1;
          return Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Center(
                child: Text(
                  '$moveNum.',
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              const SizedBox(width: 2),
              _MoveChip(san: white, isLatest: isLast && widget.moveSans.length.isOdd),
              if (black != null) ...[
                const SizedBox(width: 2),
                _MoveChip(san: black, isLatest: isLast),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _MoveChip extends StatelessWidget {
  final String san;
  final bool isLatest;

  const _MoveChip({required this.san, required this.isLatest});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: isLatest
          ? BoxDecoration(
              color: AppColors.primaryLight,
              borderRadius: BorderRadius.circular(6),
            )
          : null,
      child: Text(
        san,
        style: TextStyle(
          color: isLatest ? Colors.white : AppColors.textPrimary,
          fontSize: 12,
          fontWeight: isLatest ? FontWeight.w700 : FontWeight.w500,
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
      ),
    );
  }
}
