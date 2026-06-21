import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/storage/local_storage.dart';
import '../../../../service_locator.dart';
import '../../data/datasources/chess_remote_datasource.dart';
import '../../data/models/chess_game_model.dart';
import '../bloc/game_bloc.dart';
import '../bloc/game_event.dart';

class ChessHomePage extends StatelessWidget {
  const ChessHomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.darkBg,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                    onPressed: () => context.pop(),
                  ),
                  const SizedBox(width: 8),
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '♟ FYC Chess',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        'சதுரங்கம்',
                        style: TextStyle(
                          color: Colors.white54,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Aurora decoration
            const SizedBox(height: 32),
            Center(
              child: Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      AppColors.primaryLight.withOpacity(0.3),
                      Colors.transparent,
                    ],
                  ),
                ),
                child: const Center(
                  child: Text('♛', style: TextStyle(fontSize: 64)),
                ),
              ),
            ),
            const SizedBox(height: 40),

            // Mode cards
            Expanded(
              child: Container(
                decoration: const BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
                ),
                padding: const EdgeInsets.fromLTRB(20, 28, 20, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Choose Mode',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 16),
                    _ModeCard(
                      icon: '👥',
                      titleEn: 'Local Game',
                      titleTa: 'இருவர் விளையாட்டு',
                      description: 'Pass & play on one device',
                      color: AppColors.primary,
                      onTap: () => _startLocalGame(context),
                    ),
                    const SizedBox(height: 12),
                    _ModeCard(
                      icon: '🤖',
                      titleEn: 'vs Computer',
                      titleTa: 'கணினி எதிர்',
                      description: 'Practice against Stockfish AI',
                      color: const Color(0xFF7C3AED),
                      onTap: () => _startAiGame(context),
                    ),
                    const SizedBox(height: 12),
                    _ModeCard(
                      icon: '🌐',
                      titleEn: 'Online Match',
                      titleTa: 'நேரடி போட்டி',
                      description: 'Challenge another FYC member',
                      color: const Color(0xFF0EA5E9),
                      onTap: () => context.push('/chess/challenge'),
                    ),
                    const SizedBox(height: 24),

                    // Live Games section
                    _LiveGamesSection(),
                    const Spacer(),

                    // History button
                    OutlinedButton.icon(
                      onPressed: () => context.push('/chess/history'),
                      icon: const Icon(Icons.history_rounded, size: 18),
                      label: const Text('Game History'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.primary,
                        side: const BorderSide(color: AppColors.border),
                        minimumSize: const Size(double.infinity, 48),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppTheme.radiusBtn),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),

                    // Hall of Fame button
                    OutlinedButton.icon(
                      onPressed: () => context.push('/chess/legacy'),
                      icon: const Icon(Icons.emoji_events_rounded, size: 18),
                      label: const Text('Hall of Fame'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFFFFD700),
                        side: const BorderSide(color: Color(0xFFFFD700)),
                        minimumSize: const Size(double.infinity, 48),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppTheme.radiusBtn),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),

                    // Legends button
                    OutlinedButton.icon(
                      onPressed: () => context.push('/chess/legends'),
                      icon: const Icon(Icons.auto_stories_rounded, size: 18),
                      label: const Text('Chess Legends · சதுரங்க மேதைகள்'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFFA855F7),
                        side: const BorderSide(color: Color(0xFFA855F7)),
                        minimumSize: const Size(double.infinity, 48),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppTheme.radiusBtn),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Stats row (live from backend)
                    _StatsBanner(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _startLocalGame(BuildContext context) {
    final storage = sl<LocalStorage>();
    final myName = storage.getString('member_name') ?? 'White';
    showDialog(
      context: context,
      builder: (ctx) => _PlayerNamesDialog(
        defaultWhite: myName,
        defaultBlack: 'Black',
        onStart: (white, black) {
          Navigator.pop(ctx);
          context.read<GameBloc>().add(const NewGame());
          context.push(
            '/chess/local',
            extra: {'white': white, 'black': black},
          );
        },
      ),
    );
  }

  void _startAiGame(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => _DifficultyDialog(
        onStart: (depth, skill, playerIsWhite) {
          Navigator.pop(ctx);
          context.push('/chess/ai', extra: {
            'depth': depth,
            'skill': skill,
            'playerIsWhite': playerIsWhite,
          });
        },
      ),
    );
  }
}

class _ModeCard extends StatelessWidget {
  final String icon;
  final String titleEn;
  final String titleTa;
  final String description;
  final Color color;
  final VoidCallback? onTap;
  final bool comingSoon;

  const _ModeCard({
    required this.icon,
    required this.titleEn,
    required this.titleTa,
    required this.description,
    required this.color,
    required this.onTap,
    this.comingSoon = false,
  });

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: comingSoon ? 0.55 : 1.0,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border),
            boxShadow: AppTheme.cardShadow,
          ),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Center(
                  child: Text(icon, style: const TextStyle(fontSize: 26)),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          titleEn,
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                            color: comingSoon
                                ? AppColors.textSecondary
                                : AppColors.textPrimary,
                          ),
                        ),
                        if (comingSoon) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.border,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text(
                              'Soon',
                              style: TextStyle(
                                  fontSize: 10, color: AppColors.textSecondary),
                            ),
                          ),
                        ],
                      ],
                    ),
                    Text(
                      titleTa,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      description,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              if (!comingSoon)
                Icon(Icons.arrow_forward_ios, color: color, size: 16),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Live Games section ────────────────────────────────────────────────────────

class _LiveGamesSection extends StatefulWidget {
  @override
  State<_LiveGamesSection> createState() => _LiveGamesSectionState();
}

class _LiveGamesSectionState extends State<_LiveGamesSection> {
  late Future<List<LiveGameModel>> _future;

  @override
  void initState() {
    super.initState();
    _future = sl<ChessRemoteDataSource>().liveGames();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text(
              'Live Games',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              width: 8,
              height: 8,
              decoration: const BoxDecoration(
                color: Colors.red,
                shape: BoxShape.circle,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        FutureBuilder<List<LiveGameModel>>(
          future: _future,
          builder: (context, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return const SizedBox(
                height: 48,
                child: Center(
                  child: SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.primaryLight,
                    ),
                  ),
                ),
              );
            }
            final games = snap.data ?? [];
            if (games.isEmpty) {
              return Container(
                padding: const EdgeInsets.symmetric(vertical: 14),
                alignment: Alignment.center,
                child: const Text(
                  'No live games right now',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 13,
                  ),
                ),
              );
            }
            return Column(
              children: games
                  .map((game) => _LiveGameTile(game: game))
                  .toList(),
            );
          },
        ),
      ],
    );
  }
}

class _LiveGameTile extends StatelessWidget {
  final LiveGameModel game;
  const _LiveGameTile({required this.game});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Row(
        children: [
          const Text('♟', style: TextStyle(fontSize: 20)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${game.whiteName} vs ${game.blackName}',
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    color: AppColors.textPrimary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Text(
                      '${game.ply} moves',
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(width: 10),
                    const Icon(Icons.visibility, size: 12,
                        color: AppColors.textSecondary),
                    const SizedBox(width: 3),
                    Text(
                      '${game.spectatorCount} watching',
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          ElevatedButton(
            onPressed: () => _watch(context, game),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              minimumSize: const Size(64, 34),
              padding: const EdgeInsets.symmetric(horizontal: 14),
              textStyle: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text('Watch'),
          ),
        ],
      ),
    );
  }

  Future<void> _watch(BuildContext context, LiveGameModel game) async {
    final token = await sl<LocalStorage>().getToken() ?? '';
    if (!context.mounted) return;
    context.push(
      '/chess/spectate/${game.id}',
      extra: {'token': token},
    );
  }
}

// ── Stats banner ───────────────────────────────────────────────────────────────

class _StatsBanner extends StatefulWidget {
  @override
  State<_StatsBanner> createState() => _StatsBannerState();
}

class _StatsBannerState extends State<_StatsBanner> {
  ChessStatsModel? _stats;

  @override
  void initState() {
    super.initState();
    sl<ChessRemoteDataSource>()
        .myStats()
        .then((s) { if (mounted) setState(() => _stats = s); })
        .catchError((_) {}); // ignore if offline
  }

  @override
  Widget build(BuildContext context) {
    final s = _stats;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: AppTheme.gradientPrimary,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _StatItem(value: s != null ? s.ratingDisplay : '—', label: 'Rating'),
          _StatItem(value: s != null ? '${s.gamesPlayed}' : '—', label: 'Games'),
          _StatItem(value: s != null ? s.winRateDisplay : '—', label: 'Win %'),
        ],
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  final String value;
  final String label;
  const _StatItem({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(value,
            style: const TextStyle(
                color: Colors.white, fontWeight: FontWeight.w800, fontSize: 20)),
        Text(label,
            style: const TextStyle(color: Colors.white70, fontSize: 11)),
      ],
    );
  }
}

// ── Player name dialog ────────────────────────────────────────────────────────

class _PlayerNamesDialog extends StatefulWidget {
  final String defaultWhite;
  final String defaultBlack;
  final void Function(String white, String black) onStart;

  const _PlayerNamesDialog({
    required this.defaultWhite,
    required this.defaultBlack,
    required this.onStart,
  });

  @override
  State<_PlayerNamesDialog> createState() => _PlayerNamesDialogState();
}

class _PlayerNamesDialogState extends State<_PlayerNamesDialog> {
  late final TextEditingController _white;
  late final TextEditingController _black;

  @override
  void initState() {
    super.initState();
    _white = TextEditingController(text: widget.defaultWhite);
    _black = TextEditingController(text: widget.defaultBlack);
  }

  @override
  void dispose() {
    _white.dispose();
    _black.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Text('Player Names', style: TextStyle(fontWeight: FontWeight.w700)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _white,
            decoration: const InputDecoration(
              labelText: '♔ White',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _black,
            decoration: const InputDecoration(
              labelText: '♚ Black',
              border: OutlineInputBorder(),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            final w = _white.text.trim().isEmpty ? 'White' : _white.text.trim();
            final b = _black.text.trim().isEmpty ? 'Black' : _black.text.trim();
            widget.onStart(w, b);
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppTheme.radiusBtn)),
          ),
          child: const Text('Start Game'),
        ),
      ],
    );
  }
}

// ── Difficulty picker dialog ───────────────────────────────────────────────────

class _Difficulty {
  final String label;
  final String emoji;
  final int depth;
  final int skill;
  const _Difficulty(this.label, this.emoji, this.depth, this.skill);
}

class _DifficultyDialog extends StatefulWidget {
  final void Function(int depth, int skill, bool playerIsWhite) onStart;
  const _DifficultyDialog({required this.onStart});

  @override
  State<_DifficultyDialog> createState() => _DifficultyDialogState();
}

class _DifficultyDialogState extends State<_DifficultyDialog> {
  static const _levels = [
    _Difficulty('Beginner', '🌱', 1, 0),
    _Difficulty('Easy', '😊', 3, 5),
    _Difficulty('Medium', '🎯', 5, 10),
    _Difficulty('Hard', '🔥', 8, 15),
    _Difficulty('Expert', '💀', 12, 20),
  ];

  int _selectedIndex = 2; // Default: Medium
  bool _playerIsWhite = true;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Text('vs Computer',
          style: TextStyle(fontWeight: FontWeight.w700)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Difficulty',
              style: TextStyle(
                  fontWeight: FontWeight.w600, color: AppColors.textSecondary, fontSize: 13)),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: List.generate(_levels.length, (i) {
              final d = _levels[i];
              final selected = _selectedIndex == i;
              return GestureDetector(
                onTap: () => setState(() => _selectedIndex = i),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: selected ? AppColors.primary : AppColors.surface,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: selected ? AppColors.primary : AppColors.border,
                    ),
                  ),
                  child: Text(
                    '${d.emoji} ${d.label}',
                    style: TextStyle(
                      color: selected ? Colors.white : AppColors.textPrimary,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: 20),
          const Text('Play as',
              style: TextStyle(
                  fontWeight: FontWeight.w600, color: AppColors.textSecondary, fontSize: 13)),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _ColorChip(
                  label: '♔ White',
                  selected: _playerIsWhite,
                  onTap: () => setState(() => _playerIsWhite = true),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _ColorChip(
                  label: '♚ Black',
                  selected: !_playerIsWhite,
                  onTap: () => setState(() => _playerIsWhite = false),
                ),
              ),
            ],
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            final d = _levels[_selectedIndex];
            widget.onStart(d.depth, d.skill, _playerIsWhite);
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppTheme.radiusBtn)),
          ),
          child: const Text('Play'),
        ),
      ],
    );
  }
}

class _ColorChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _ColorChip(
      {required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : AppColors.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
              color: selected ? AppColors.primary : AppColors.border),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: selected ? Colors.white : AppColors.textPrimary,
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
        ),
      ),
    );
  }
}
