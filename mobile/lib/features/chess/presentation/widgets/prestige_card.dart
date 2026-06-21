import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
import '../../data/models/chess_game_model.dart';

class PrestigeCard extends StatelessWidget {
  final ChessStatsModel stats;
  const PrestigeCard({super.key, required this.stats});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.darkSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.gold.withOpacity(0.35)),
        boxShadow: [
          BoxShadow(
            color: AppColors.gold.withOpacity(0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          // Prestige badge
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: AppColors.gold.withOpacity(0.12),
              shape: BoxShape.circle,
              border: Border.all(
                  color: AppColors.gold.withOpacity(0.4), width: 1.5),
            ),
            child: Center(
              child: Text(stats.titleEmoji, style: const TextStyle(fontSize: 26)),
            ),
          ),
          const SizedBox(width: 14),

          // Title + rating info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  stats.title,
                  style: const TextStyle(
                    color: AppColors.gold,
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                    letterSpacing: 0.3,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Rating ${stats.ratingDisplay} · RD ±${stats.glickoRd.round()}',
                  style: const TextStyle(
                    color: Colors.white54,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),

          // Streak badge
          if (stats.currentStreak != 0)
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: stats.currentStreak > 0
                    ? AppColors.primaryLight.withOpacity(0.15)
                    : AppColors.warning.withOpacity(0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '${stats.currentStreak > 0 ? '+' : ''}${stats.currentStreak}',
                style: TextStyle(
                  color: stats.currentStreak > 0
                      ? AppColors.primaryLight
                      : AppColors.warning,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
