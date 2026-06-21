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

// ── Dark theme color constants ─────────────────────────────────────────────────
const _kBg = Color(0xFF0D1117);
const _kCard = Color(0xFF1C2333);
const _kCardBorder = Color(0xFF2D3748);
const _kGold = Color(0xFFD4AF37);
const _kTextSecondary = Color(0xFF9CA3AF);
const _kGreen = Color(0xFF16A34A);
const _kPurple = Color(0xFF7C3AED);
const _kBlue = Color(0xFF2563EB);
const _kArrow = Color(0xFF374151);

// ── Chess Home Page ────────────────────────────────────────────────────────────

class ChessHomePage extends StatefulWidget {
  const ChessHomePage({super.key});

  @override
  State<ChessHomePage> createState() => _ChessHomePageState();
}

class _ChessHomePageState extends State<ChessHomePage>
    with TickerProviderStateMixin {
  // Aurora float animation for queen icon
  late final AnimationController _auroraController;
  late final Animation<double> _auroraFloat;
  late final Animation<double> _auroraScale;

  // Pulse animation for live dot
  late final AnimationController _pulseController;
  late final Animation<double> _pulseOpacity;

  // Stats
  ChessStatsModel? _stats;
  bool _statsLoaded = false;

  @override
  void initState() {
    super.initState();

    // Aurora float — gentle up/down
    _auroraController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat(reverse: true);

    _auroraFloat = Tween<double>(begin: -6.0, end: 6.0).animate(
      CurvedAnimation(parent: _auroraController, curve: Curves.easeInOut),
    );

    _auroraScale = Tween<double>(begin: 0.97, end: 1.03).animate(
      CurvedAnimation(parent: _auroraController, curve: Curves.easeInOut),
    );

    // Pulse for live dot
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);

    _pulseOpacity = Tween<double>(begin: 0.3, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    // Load stats
    sl<ChessRemoteDataSource>()
        .myStats()
        .then((s) {
          if (mounted) setState(() { _stats = s; _statsLoaded = true; });
        })
        .catchError((_) {
          if (mounted) setState(() => _statsLoaded = true);
        });
  }

  @override
  void dispose() {
    _auroraController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kBg,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.only(bottom: 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── Back button row ──────────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 12, 8, 0),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back, color: Colors.white),
                      onPressed: () => context.pop(),
                    ),
                  ],
                ),
              ),

              // ── Dark premium hero ────────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                child: Column(
                  children: [
                    // Animated queen icon with aurora glow
                    AnimatedBuilder(
                      animation: _auroraController,
                      builder: (_, __) => Transform.translate(
                        offset: Offset(0, _auroraFloat.value),
                        child: Transform.scale(
                          scale: _auroraScale.value,
                          child: Container(
                            width: 110,
                            height: 110,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: RadialGradient(
                                colors: [
                                  _kGold.withOpacity(0.18),
                                  _kGreen.withOpacity(0.10),
                                  Colors.transparent,
                                ],
                                stops: const [0.0, 0.5, 1.0],
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: _kGold.withOpacity(0.15),
                                  blurRadius: 32,
                                  spreadRadius: 4,
                                ),
                              ],
                            ),
                            child: const Center(
                              child: Text(
                                '♛',
                                style: TextStyle(fontSize: 60),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'FYC Chess Arena',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'சதுரங்க களம்',
                      style: TextStyle(
                        color: _kTextSecondary,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Rating display
                    _buildRatingBadge(),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // ── Stats bar / new-user CTA ─────────────────────────────────────
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: _buildStatsOrCta(),
              ),

              const SizedBox(height: 24),

              // ── Mode cards ───────────────────────────────────────────────────
              _PremiumModeCard(
                icon: Icons.group,
                iconBg: _kGreen,
                titleEn: 'Local Game',
                titleTa: 'இருவர் விளையாட்டு',
                subtitle: 'Pass & play on one device',
                onTap: () => _startLocalGame(context),
              ),
              _PremiumModeCard(
                icon: Icons.smart_toy_outlined,
                iconBg: _kPurple,
                titleEn: 'vs Computer',
                titleTa: 'கணினி எதிர்',
                subtitle: 'Practice against Stockfish AI',
                onTap: () => _startAiGame(context),
              ),
              _PremiumModeCard(
                icon: Icons.public,
                iconBg: _kBlue,
                titleEn: 'Online Match',
                titleTa: 'நேரடி போட்டி',
                subtitle: 'Challenge another FYC member',
                onTap: () => context.push('/chess/challenge'),
              ),

              const SizedBox(height: 8),

              // ── Daily Puzzle placeholder ─────────────────────────────────────
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
                child: _DailyPuzzleCard(),
              ),

              const SizedBox(height: 8),

              // ── Live Games section ────────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: _LiveGamesSection(pulseOpacity: _pulseOpacity),
              ),

              const SizedBox(height: 24),

              // ── Hall of Fame / History / Legends chips ───────────────────────
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    _NavChip(
                      icon: '🏆',
                      label: 'Hall of Fame',
                      onTap: () => context.push('/chess/legacy'),
                    ),
                    const SizedBox(width: 8),
                    _NavChip(
                      icon: '📋',
                      label: 'History',
                      onTap: () => context.push('/chess/history'),
                    ),
                    const SizedBox(width: 8),
                    _NavChip(
                      icon: '📖',
                      label: 'Legends',
                      onTap: () => context.push('/chess/legends'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Rating badge ─────────────────────────────────────────────────────────────

  Widget _buildRatingBadge() {
    if (!_statsLoaded) {
      return const SizedBox(
        height: 36,
        child: Center(
          child: SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: _kGold,
            ),
          ),
        ),
      );
    }

    final rating = _stats?.rating ?? 0;
    final hasRating = rating > 0;

    if (!hasRating) {
      return Column(
        children: [
          const Text(
            'Unrated',
            style: TextStyle(
              color: _kTextSecondary,
              fontSize: 20,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          GestureDetector(
            onTap: () => _startLocalGame(context),
            child: const Text(
              'Play to earn your rating →',
              style: TextStyle(
                color: _kGold,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      );
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.star_rounded, color: _kGold, size: 22),
        const SizedBox(width: 6),
        Text(
          '$rating',
          style: const TextStyle(
            color: _kGold,
            fontSize: 26,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(width: 6),
        const Text(
          'Rating',
          style: TextStyle(
            color: _kTextSecondary,
            fontSize: 14,
          ),
        ),
      ],
    );
  }

  // ── Stats row OR new-user CTA ─────────────────────────────────────────────────

  Widget _buildStatsOrCta() {
    if (!_statsLoaded) return const SizedBox.shrink();

    final games = _stats?.gamesPlayed ?? 0;

    if (games == 0) {
      return GestureDetector(
        onTap: () => _startLocalGame(context),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          decoration: BoxDecoration(
            color: _kCard,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _kGreen, width: 1.5),
          ),
          child: const Row(
            children: [
              Icon(Icons.play_circle_outline, color: _kGreen, size: 22),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Play your first game to earn a rating!',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Icon(Icons.arrow_forward_ios, color: _kGreen, size: 14),
            ],
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
      decoration: BoxDecoration(
        color: _kCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _kCardBorder, width: 1),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _StatItem(
            value: _stats?.ratingDisplay ?? '—',
            label: 'Rating',
            valueColor: _kGold,
          ),
          Container(width: 1, height: 36, color: _kCardBorder),
          _StatItem(
            value: '${_stats?.gamesPlayed ?? 0}',
            label: 'Games',
          ),
          Container(width: 1, height: 36, color: _kCardBorder),
          _StatItem(
            value: _stats?.winRateDisplay ?? '—',
            label: 'Win %',
            valueColor: _kGreen,
          ),
        ],
      ),
    );
  }

  // ── Dialog launchers (preserved) ─────────────────────────────────────────────

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

// ── Premium Mode Card ──────────────────────────────────────────────────────────

class _PremiumModeCard extends StatefulWidget {
  final IconData icon;
  final Color iconBg;
  final String titleEn;
  final String titleTa;
  final String subtitle;
  final VoidCallback onTap;

  const _PremiumModeCard({
    required this.icon,
    required this.iconBg,
    required this.titleEn,
    required this.titleTa,
    required this.subtitle,
    required this.onTap,
  });

  @override
  State<_PremiumModeCard> createState() => _PremiumModeCardState();
}

class _PremiumModeCardState extends State<_PremiumModeCard> {
  double _scale = 1.0;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _scale = 0.97),
      onTapUp: (_) {
        setState(() => _scale = 1.0);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _scale = 1.0),
      child: AnimatedScale(
        scale: _scale,
        duration: const Duration(milliseconds: 100),
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: _kCard,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _kCardBorder, width: 1),
          ),
          child: Row(
            children: [
              // Left: icon square
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: widget.iconBg.withOpacity(0.18),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(widget.icon, color: widget.iconBg, size: 26),
              ),
              const SizedBox(width: 14),
              // Center: title + subtitle
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.titleEn,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      widget.titleTa,
                      style: const TextStyle(
                        color: _kTextSecondary,
                        fontSize: 11,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      widget.subtitle,
                      style: const TextStyle(
                        color: _kTextSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              // Right: arrow
              const Icon(Icons.arrow_forward_ios, color: _kArrow, size: 15),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Daily Puzzle Placeholder Card ─────────────────────────────────────────────

class _DailyPuzzleCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Daily puzzles coming soon!')),
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: _kCard,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _kCardBorder, width: 1),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text('🔥', style: TextStyle(fontSize: 20)),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    'Daily Challenge',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: _kGold.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(20),
                    border:
                        Border.all(color: _kGold.withOpacity(0.4), width: 1),
                  ),
                  child: const Text(
                    'Coming Soon',
                    style: TextStyle(
                      color: _kGold,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            const Padding(
              padding: EdgeInsets.only(left: 30),
              child: Text(
                'Solve today\'s puzzle • maintain your streak',
                style: TextStyle(
                  color: _kTextSecondary,
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Live Games Section ────────────────────────────────────────────────────────

class _LiveGamesSection extends StatefulWidget {
  final Animation<double> pulseOpacity;

  const _LiveGamesSection({required this.pulseOpacity});

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
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _kCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _kCardBorder, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with blinking dot
          Row(
            children: [
              const Text(
                'Live Games',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 8),
              AnimatedBuilder(
                animation: widget.pulseOpacity,
                builder: (_, __) => Opacity(
                  opacity: widget.pulseOpacity.value,
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
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
                return const Column(
                  children: [
                    Text(
                      '♟',
                      style: TextStyle(
                        fontSize: 40,
                        color: _kTextSecondary,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'No live games',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Start a game — others can spectate',
                      style: TextStyle(
                        color: _kTextSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                );
              }
              return Column(
                children:
                    games.map((game) => _LiveGameTile(game: game)).toList(),
              );
            },
          ),
        ],
      ),
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
        color: const Color(0xFF0D1117),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _kCardBorder),
      ),
      child: Row(
        children: [
          const Text('♟',
              style: TextStyle(fontSize: 20, color: Colors.white)),
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
                    color: Colors.white,
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
                        color: _kTextSecondary,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(width: 10),
                    const Icon(Icons.visibility,
                        size: 12, color: _kTextSecondary),
                    const SizedBox(width: 3),
                    Text(
                      '${game.spectatorCount} watching',
                      style: const TextStyle(
                        color: _kTextSecondary,
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

// ── Nav Chip (Hall of Fame / History / Legends) ───────────────────────────────

class _NavChip extends StatelessWidget {
  final String icon;
  final String label;
  final VoidCallback onTap;

  const _NavChip({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: _kCard,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: _kCardBorder, width: 1),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(icon, style: const TextStyle(fontSize: 14)),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Stat item ─────────────────────────────────────────────────────────────────

class _StatItem extends StatelessWidget {
  final String value;
  final String label;
  final Color valueColor;

  const _StatItem({
    required this.value,
    required this.label,
    this.valueColor = Colors.white,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            color: valueColor,
            fontWeight: FontWeight.w800,
            fontSize: 20,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(color: _kTextSecondary, fontSize: 11),
        ),
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
      title: const Text('Player Names',
          style: TextStyle(fontWeight: FontWeight.w700)),
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
            final w =
                _white.text.trim().isEmpty ? 'White' : _white.text.trim();
            final b =
                _black.text.trim().isEmpty ? 'Black' : _black.text.trim();
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
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                  fontSize: 13)),
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
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: selected ? AppColors.primary : AppColors.surface,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color:
                          selected ? AppColors.primary : AppColors.border,
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
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                  fontSize: 13)),
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
