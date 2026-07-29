import 'package:flutter/material.dart';
import '../../../../core/l10n/tr.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/storage/local_storage.dart';
import '../../../../service_locator.dart';
import '../../data/datasources/chess_remote_datasource.dart';
import '../../data/models/chess_game_model.dart';
import '../widgets/prestige_card.dart';

class GameHistoryPage extends StatefulWidget {
  const GameHistoryPage({super.key});

  @override
  State<GameHistoryPage> createState() => _GameHistoryPageState();
}

class _GameHistoryPageState extends State<GameHistoryPage> {
  late final Future<List<ChessGameModel>> _future;
  late final Future<ChessStatsModel> _statsFuture;

  @override
  void initState() {
    super.initState();
    final ds = sl<ChessRemoteDataSource>();
    _future = ds.myGames();
    _statsFuture = ds.myStats();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.darkBg,
        foregroundColor: AppColors.background,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        title: Text(
          trId('game_history'),
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
        ),
      ),
      body: Column(
        children: [
          // Stats banner
          FutureBuilder<ChessStatsModel>(
            future: _statsFuture,
            builder: (context, snap) {
              if (!snap.hasData) return SizedBox(height: 72);
              final s = snap.data!;
              return _StatsBanner(stats: s);
            },
          ),

          // Game list
          Expanded(
            child: FutureBuilder<List<ChessGameModel>>(
              future: _future,
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return Center(
                    child: CircularProgressIndicator(color: AppColors.primaryLight),
                  );
                }
                if (snap.hasError) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.wifi_off_rounded,
                            color: AppColors.textSecondary, size: 48),
                        SizedBox(height: 12),
                        Text(trId('could_not_load_games'),
                            style: TextStyle(color: AppColors.textSecondary)),
                      ],
                    ),
                  );
                }
                final games = snap.data ?? [];
                if (games.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('♟', style: TextStyle(fontSize: 48)),
                        SizedBox(height: 12),
                        Text(trId('no_games_yet'),
                            style: TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 16,
                                fontWeight: FontWeight.w600)),
                        SizedBox(height: 6),
                        Text(trId('play_your_first_game'),
                            style: TextStyle(color: AppColors.textSecondary)),
                      ],
                    ),
                  );
                }
                return ListView.builder(
                  padding: EdgeInsets.all(16),
                  itemCount: games.length,
                  itemBuilder: (context, i) => _GameTile(game: games[i]),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _StatsBanner extends StatelessWidget {
  final ChessStatsModel stats;
  const _StatsBanner({required this.stats});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.darkBg,
      padding: EdgeInsets.fromLTRB(20, 12, 20, 16),
      child: Column(
        children: [
          // Prestige title card
          PrestigeCard(stats: stats),
          SizedBox(height: 12),

          // Win / Games / Rate row
          Container(
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: AppTheme.gradientPrimary,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _Stat(
                  value: stats.ratingDisplay,
                  label: 'Rating',
                  sub: '±${stats.glickoRd.round()}',
                ),
                _Divider(),
                _Stat(
                  value: '${stats.gamesPlayed}',
                  label: 'Games',
                  sub: '${stats.wins}W ${stats.losses}L ${stats.draws}D',
                ),
                _Divider(),
                _Stat(
                  value: stats.winRateDisplay,
                  label: 'Win rate',
                  sub: stats.currentStreak != 0
                      ? '${stats.currentStreak > 0 ? '+' : ''}${stats.currentStreak} streak'
                      : '—',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  final String value;
  final String label;
  final String sub;

  const _Stat({required this.value, required this.label, required this.sub});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(value,
            style: TextStyle(
                color: AppColors.background, fontWeight: FontWeight.w800, fontSize: 22)),
        Text(label,
            style: TextStyle(color: Colors.white70, fontSize: 11)),
        SizedBox(height: 2),
        Text(sub,
            style: TextStyle(color: Colors.white54, fontSize: 10)),
      ],
    );
  }
}

class _Divider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(width: 1, height: 40, color: Colors.white24);
  }
}

class _GameTile extends StatelessWidget {
  final ChessGameModel game;
  const _GameTile({required this.game});

  @override
  Widget build(BuildContext context) {
    final white = game.whiteName ?? 'White';
    final black = game.blackName ?? 'Black';
    final dateStr = _formatDate(game.createdAt);

    Color resultColor;
    if (game.result == null) {
      resultColor = AppColors.textSecondary;
    } else if (game.result == 'draw') {
      resultColor = AppColors.warning;
    } else {
      resultColor = AppColors.primaryLight;
    }

    return Container(
      margin: EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Padding(
        padding: EdgeInsets.all(14),
        child: Row(
          children: [
            // Result badge
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: resultColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: Text(
                  game.resultEmoji,
                  style: TextStyle(fontSize: 20),
                ),
              ),
            ),
            SizedBox(width: 12),

            // Players + result
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$white vs $black',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                      color: AppColors.textPrimary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  SizedBox(height: 2),
                  Text(
                    game.resultLabel,
                    style: TextStyle(
                      fontSize: 12,
                      color: resultColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),

            // Meta + replay
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(dateStr,
                    style: TextStyle(
                        color: AppColors.textSecondary, fontSize: 11)),
                SizedBox(height: 4),
                Text(
                  '${game.totalMoves} moves',
                  style: TextStyle(
                      color: AppColors.textSecondary, fontSize: 11),
                ),
                SizedBox(height: 6),
                GestureDetector(
                  onTap: () => context.push('/chess/replay/${game.id}'),
                  child: Container(
                    padding: EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                          color: AppColors.primary.withOpacity(0.3)),
                    ),
                    child: Text(
                      trId('replay'),
                      style: TextStyle(
                          color: AppColors.primary,
                          fontSize: 11,
                          fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(String? iso) {
    if (iso == null) return '—';
    try {
      final dt = DateTime.parse(iso).toLocal();
      final months = [
        'Jan','Feb','Mar','Apr','May','Jun',
        'Jul','Aug','Sep','Oct','Nov','Dec'
      ];
      return '${dt.day} ${months[dt.month - 1]}';
    } catch (_) {
      return '—';
    }
  }
}
