import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../service_locator.dart';
import '../../data/datasources/chess_remote_datasource.dart';
import '../../data/models/chess_game_model.dart';

/// Maps a player's Glicko rating + game count to the matching prestige title emoji.
/// Thresholds mirror the backend's `title_emoji()` helper in glicko2.py.
String _titleEmoji(double rating, int games) {
  if (games < 5) return '🌱';
  if (rating < 1400) return '⭐';
  if (rating < 1550) return '♟️';
  if (rating < 1700) return '🎯';
  if (rating < 1850) return '🔥';
  if (rating < 2000) return '💎';
  if (rating < 2150) return '👑';
  return '🏆';
}

class LegacyPage extends StatefulWidget {
  const LegacyPage({super.key});

  @override
  State<LegacyPage> createState() => _LegacyPageState();
}

class _LegacyPageState extends State<LegacyPage> {
  late Future<WeeklyAwardsModel> _awardsFuture;
  late Future<List<ChessMemberModel>> _membersFuture;

  @override
  void initState() {
    super.initState();
    final ds = sl<ChessRemoteDataSource>();
    _awardsFuture = ds.weeklyAwards();
    _membersFuture = ds.members();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.darkBg,
        foregroundColor: Colors.white,
        title: const Text(
          'Hall of Fame & Awards',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
        ),
        centerTitle: false,
        elevation: 0,
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          final ds = sl<ChessRemoteDataSource>();
          setState(() {
            _awardsFuture = ds.weeklyAwards();
            _membersFuture = ds.members();
          });
        },
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
          children: [
            // ── Weekly Spotlight ────────────────────────────────────────────
            const Text(
              'Weekly Spotlight',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 12),
            FutureBuilder<WeeklyAwardsModel>(
              future: _awardsFuture,
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const _LoadingCard();
                }
                if (snap.hasError) {
                  return _ErrorCard(message: snap.error.toString());
                }
                final awards = snap.data!;
                return Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: _AwardCard(
                            emoji: '🏆',
                            label: 'Best Player',
                            winner: awards.topPlayer?.name,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _AwardCard(
                            emoji: '⚡',
                            label: 'Most Active',
                            winner: awards.mostActive?.name,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: _AwardCard(
                            emoji: '🌱',
                            label: 'Best Newcomer',
                            winner: awards.bestNewcomer?.name,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _AwardCard(
                            emoji: '🧠',
                            label: 'Sharpest Mind',
                            winner: awards.sharpestMind?.name,
                          ),
                        ),
                      ],
                    ),
                  ],
                );
              },
            ),

            const SizedBox(height: 28),

            // ── Leaderboard ─────────────────────────────────────────────────
            const Text(
              'Leaderboard',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 12),
            FutureBuilder<List<ChessMemberModel>>(
              future: _membersFuture,
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const _LoadingCard();
                }
                if (snap.hasError) {
                  return _ErrorCard(message: snap.error.toString());
                }
                final members = List<ChessMemberModel>.from(snap.data ?? [])
                  ..sort((a, b) => b.glickoRating.compareTo(a.glickoRating));

                if (members.isEmpty) {
                  return Container(
                    padding: const EdgeInsets.symmetric(vertical: 24),
                    alignment: Alignment.center,
                    child: const Text(
                      'No ranked players yet',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 14,
                      ),
                    ),
                  );
                }

                return Column(
                  children: List.generate(members.length, (i) {
                    final m = members[i];
                    return _LeaderboardTile(
                      rank: i + 1,
                      member: m,
                      emoji: _titleEmoji(m.glickoRating, m.gamesPlayed),
                    );
                  }),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

// ── Award Card ────────────────────────────────────────────────────────────────

class _AwardCard extends StatelessWidget {
  final String emoji;
  final String label;
  final String? winner;

  const _AwardCard({
    required this.emoji,
    required this.label,
    required this.winner,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(emoji, style: const TextStyle(fontSize: 28)),
          const SizedBox(height: 6),
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            winner ?? 'None yet',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: winner != null ? AppColors.textPrimary : AppColors.textSecondary,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

// ── Leaderboard Tile ──────────────────────────────────────────────────────────

class _LeaderboardTile extends StatelessWidget {
  final int rank;
  final ChessMemberModel member;
  final String emoji;

  const _LeaderboardTile({
    required this.rank,
    required this.member,
    required this.emoji,
  });

  @override
  Widget build(BuildContext context) {
    final isTop3 = rank <= 3;
    final rankColor = switch (rank) {
      1 => const Color(0xFFFFD700),  // gold
      2 => const Color(0xFFC0C0C0),  // silver
      3 => const Color(0xFFCD7F32),  // bronze
      _ => AppColors.textSecondary,
    };

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isTop3 ? rankColor.withOpacity(0.4) : AppColors.border,
        ),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Row(
        children: [
          SizedBox(
            width: 32,
            child: Text(
              '#$rank',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 14,
                color: rankColor,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  member.name,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    color: AppColors.textPrimary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (member.area != null)
                  Text(
                    member.area!,
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.textSecondary,
                    ),
                  ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '$emoji  ${member.ratingDisplay}',
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 15,
                  color: AppColors.textPrimary,
                ),
              ),
              Text(
                '${member.gamesPlayed} games',
                style: const TextStyle(
                  fontSize: 11,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Helpers ───────────────────────────────────────────────────────────────────

class _LoadingCard extends StatelessWidget {
  const _LoadingCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 32),
      alignment: Alignment.center,
      child: const CircularProgressIndicator(
        strokeWidth: 2,
        color: AppColors.primaryLight,
      ),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  final String message;
  const _ErrorCard({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Text(
        'Could not load data. Please try again.',
        style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
      ),
    );
  }
}
