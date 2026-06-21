import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
import '../bloc/game_state.dart';
import '../../domain/entities/chess_game.dart';

class GameResultSheet extends StatelessWidget {
  final GameOver state;
  final VoidCallback onNewGame;
  final VoidCallback onClose;

  const GameResultSheet({
    super.key,
    required this.state,
    required this.onNewGame,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final isDraw = state.result == GameResult.draw;
    final emoji = switch (state.result) {
      GameResult.whiteWins => '♔',
      GameResult.blackWins => '♚',
      GameResult.draw => '🤝',
      GameResult.ongoing => '',
    };
    final color = isDraw ? AppColors.warning : AppColors.primary;

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 36),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.border,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 24),

          // Result emoji
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color.withOpacity(0.1),
            ),
            child: Center(
              child: Text(emoji, style: const TextStyle(fontSize: 36)),
            ),
          ),
          const SizedBox(height: 16),

          Text(
            state.resultLabel,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '${state.moveSans.length} moves played',
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 14,
            ),
          ),

          const SizedBox(height: 32),

          // New game button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: onNewGame,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppTheme.radiusBtn),
                ),
                elevation: 0,
              ),
              child: const Text(
                'New Game',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Review game button
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: onClose,
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primary,
                padding: const EdgeInsets.symmetric(vertical: 16),
                side: const BorderSide(color: AppColors.border),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppTheme.radiusBtn),
                ),
              ),
              child: const Text(
                'Review Position',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
