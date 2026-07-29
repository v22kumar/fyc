import 'package:flutter/material.dart';
import '../../../../core/l10n/tr.dart';
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
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.fromLTRB(24, 12, 24, 36),
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
          SizedBox(height: 24),

          // Result emoji
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color.withOpacity(0.1),
            ),
            child: Center(
              child: Text(emoji, style: TextStyle(fontSize: 36)),
            ),
          ),
          SizedBox(height: 16),

          Text(
            state.resultLabel,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
          SizedBox(height: 6),
          Text(
            '${state.moveSans.length} moves played',
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 14,
            ),
          ),

          SizedBox(height: 32),

          // New game button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: onNewGame,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: AppColors.background,
                padding: EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppTheme.radiusBtn),
                ),
                elevation: 0,
              ),
              child: Text(
                trId('new_game'),
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
              ),
            ),
          ),
          SizedBox(height: 12),

          // Review game button
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: onClose,
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primary,
                padding: EdgeInsets.symmetric(vertical: 16),
                side: BorderSide(color: AppColors.border),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppTheme.radiusBtn),
                ),
              ),
              child: Text(
                trId('review_position'),
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
