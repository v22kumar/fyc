import 'dart:math' as math;
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

// ── Color palette ─────────────────────────────────────────────────────────────
const _kBg = Color(0xFF0D1117);
const _kCard = Color(0xFF1C2333);
const _kCardBorder = Color(0xFF2D3748);
const _kGreen = Color(0xFF16A34A);
const _kGreenLight = Color(0xFF22C55E);
const _kGold = Color(0xFFD4AF37);
const _kPurple = Color(0xFF7C3AED);
const _kBlue = Color(0xFF2563EB);
const _kTextSecondary = Color(0xFF9CA3AF);

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
    final games = _stats?.gamesPlayed ?? 0;

    return Scaffold(
      backgroundColor: _kBg,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildHeader(),
              const SizedBox(height: 20),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: _buildStatsRow(),
              ),
              if (_statsLoaded && games == 0) ...[
                const SizedBox(height: 16),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: _buildCtaBanner(),
                ),
              ],
              const SizedBox(height: 24),
              _buildPlayModes(),
              const SizedBox(height: 24),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: _buildAspirantCard(),
              ),
              const SizedBox(height: 24),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: _buildLiveGames(),
              ),
              const SizedBox(height: 24),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: _buildBottomGrid(),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  // ── Header ────────────────────────────────────────────────────────────────────

  Widget _buildHeader() {
    final rating = _stats?.glickoRating.round() ?? 0;
    final hasRating = _statsLoaded && rating > 100 && (_stats?.gamesPlayed ?? 0) > 0;

    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF111827), Color(0xFF0D1117)],
        ),
      ),
      child: Stack(
        children: [
          // Background queen — large, faint
          Positioned(
            right: -20,
            top: -10,
            child: AnimatedBuilder(
              animation: _auroraController,
              builder: (_, __) => Transform.translate(
                offset: Offset(0, _auroraFloat.value * 0.5),
                child: Transform.scale(
                  scale: _auroraScale.value,
                  child: Opacity(
                    opacity: 0.06,
                    child: const Text(
                      '♛',
                      style: TextStyle(
                        fontSize: 160,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          // Content
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Back arrow row
                Row(
                  children: [
                    GestureDetector(
                      onTap: () => context.pop(),
                      child: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.arrow_back,
                          color: Colors.white,
                          size: 18,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                // Tagline
                const Text(
                  'Think. Plan. Win.',
                  style: TextStyle(
                    color: _kTextSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 1.0,
                  ),
                ),
                const SizedBox(height: 6),
                // FYC
                const Text(
                  'FYC',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 38,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 4,
                    height: 1.0,
                  ),
                ),
                // CHESS ARENA
                const Text(
                  'CHESS ARENA',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 3,
                    height: 1.1,
                  ),
                ),
                const SizedBox(height: 6),
                // Tamil subtitle
                const Text(
                  'சதுரங்க களம்',
                  style: TextStyle(
                    color: _kTextSecondary,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 14),
                // Rating badge
                if (!_statsLoaded)
                  _buildUnratedBadge()
                else if (hasRating)
                  _buildRatingBadge(rating)
                else
                  _buildUnratedBadge(),
                const SizedBox(height: 6),
                // Sub-text
                const Text(
                  'Play games to earn your rating',
                  style: TextStyle(
                    color: _kTextSecondary,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUnratedBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _kTextSecondary.withOpacity(0.5), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'Unrated',
            style: TextStyle(
              color: _kTextSecondary,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: 4),
          const Text(
            'ⓘ',
            style: TextStyle(
              color: _kTextSecondary,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRatingBadge(int rating) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _kGold.withOpacity(0.6), width: 1),
        color: _kGold.withOpacity(0.08),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.star_rounded, color: _kGold, size: 14),
          const SizedBox(width: 5),
          Text(
            '$rating',
            style: const TextStyle(
              color: _kGold,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(width: 4),
          const Text(
            'Rating',
            style: TextStyle(
              color: _kTextSecondary,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  // ── Stats Row ─────────────────────────────────────────────────────────────────

  Widget _buildStatsRow() {
    final s = _stats;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
      decoration: BoxDecoration(
        color: _kCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _kCardBorder, width: 1),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildStatBubble(
            icon: '🎮',
            value: _statsLoaded ? '${s?.gamesPlayed ?? 0}' : '—',
            label: 'Games Played',
          ),
          Container(width: 1, height: 40, color: _kCardBorder),
          _buildStatBubble(
            icon: '🏆',
            value: _statsLoaded ? '${s?.wins ?? 0}' : '—',
            label: 'Wins',
            valueColor: _kGreenLight,
          ),
          Container(width: 1, height: 40, color: _kCardBorder),
          _buildStatBubble(
            icon: '⭐',
            value: _statsLoaded && (s?.gamesPlayed ?? 0) > 0
                ? '${s!.glickoRating.round()}'
                : '—',
            label: 'Best Rating',
            valueColor: _kGold,
          ),
          Container(width: 1, height: 40, color: _kCardBorder),
          _buildStatBubble(
            icon: '🔥',
            value: _statsLoaded ? '${s?.currentStreak ?? 0}' : '—',
            label: 'Win Streak',
            valueColor: const Color(0xFFFF6B35),
          ),
        ],
      ),
    );
  }

  Widget _buildStatBubble({
    required String icon,
    required String value,
    required String label,
    Color valueColor = Colors.white,
  }) {
    return Column(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.05),
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(icon, style: const TextStyle(fontSize: 14)),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          value,
          style: TextStyle(
            color: valueColor,
            fontSize: 18,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(
            color: _kTextSecondary,
            fontSize: 9,
            fontWeight: FontWeight.w500,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  // ── CTA Banner ────────────────────────────────────────────────────────────────

  Widget _buildCtaBanner() {
    return GestureDetector(
      onTap: () => _startLocalGame(context),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF0C3320), Color(0xFF052612)],
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _kGreen.withOpacity(0.4), width: 1),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Start your chess journey!',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Play your first game and unlock your potential',
                    style: TextStyle(
                      color: _kTextSecondary,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: _kGreen.withOpacity(0.2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.arrow_forward,
                color: _kGreenLight,
                size: 18,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Play Modes ────────────────────────────────────────────────────────────────

  Widget _buildPlayModes() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'PLAY MODES',
                style: TextStyle(
                  color: _kTextSecondary,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.5,
                ),
              ),
              GestureDetector(
                onTap: () => context.push('/chess/challenge'),
                child: const Text(
                  'Explore All >',
                  style: TextStyle(
                    color: _kGreenLight,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        SizedBox(
          height: 185,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            children: [
              _PlayModeCard(
                title: 'Local Game',
                subtitle: 'Play on one device',
                emoji: '♟',
                gradientColors: const [Color(0xFF2D1B69), Color(0xFF1A0F3E)],
                onTap: () => _startLocalGame(context),
              ),
              const SizedBox(width: 12),
              _PlayModeCard(
                title: 'vs Computer',
                subtitle: 'Practice & Improve',
                emoji: '♞',
                gradientColors: const [Color(0xFF1E1B4B), Color(0xFF0F0E2A)],
                onTap: () => _startAiGame(context),
              ),
              const SizedBox(width: 12),
              _PlayModeCard(
                title: 'Online Match',
                subtitle: 'Challenge members',
                emoji: '♛',
                gradientColors: const [Color(0xFF0F2060), Color(0xFF071040)],
                badge: '120+ Young Players',
                badgeColor: _kGreen,
                onTap: () => context.push('/chess/challenge'),
              ),
              const SizedBox(width: 12),
              _PlayModeCard(
                title: 'Daily Challenge',
                subtitle: 'Win rewards',
                emoji: '⚡',
                gradientColors: const [Color(0xFF1A2F1A), Color(0xFF0A1A0A)],
                badge: 'Win rewards',
                badgeColor: _kGold,
                onTap: () => ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Daily challenges coming soon!')),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ── Aspirant Card ─────────────────────────────────────────────────────────────

  Widget _buildAspirantCard() {
    final games = _stats?.gamesPlayed ?? 0;
    final xp = games % 10;

    final String rankTitle;
    final String rankEmoji;
    if (games == 0) {
      rankTitle = 'New Player';
      rankEmoji = '🌱';
    } else if (games <= 5) {
      rankTitle = 'Pawn';
      rankEmoji = '♙';
    } else if (games <= 15) {
      rankTitle = 'Knight';
      rankEmoji = '♞';
    } else if (games <= 30) {
      rankTitle = 'Bishop';
      rankEmoji = '♝';
    } else if (games <= 50) {
      rankTitle = 'Rook';
      rankEmoji = '♜';
    } else {
      rankTitle = 'Queen';
      rankEmoji = '♛';
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _kCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _kCardBorder, width: 1),
      ),
      child: Column(
        children: [
          Row(
            children: [
              // FYC circular avatar
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _kGreen.withOpacity(0.15),
                  border: Border.all(color: _kGreen.withOpacity(0.5), width: 1.5),
                ),
                child: const Center(
                  child: Text(
                    'FYC',
                    style: TextStyle(
                      color: _kGreenLight,
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // Title + subtitle + XP
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Text(
                          'Chess Aspirant',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Icon(Icons.edit, color: _kTextSecondary, size: 12),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      rankTitle,
                      style: const TextStyle(
                        color: _kTextSecondary,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 6),
                    // XP bar
                    Row(
                      children: [
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: xp / 10.0,
                              backgroundColor: Colors.white.withOpacity(0.08),
                              valueColor: const AlwaysStoppedAnimation<Color>(_kGreen),
                              minHeight: 5,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '$xp/10',
                          style: const TextStyle(
                            color: _kTextSecondary,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              // Rank badge
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.04),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: _kCardBorder),
                ),
                child: Center(
                  child: Text(
                    rankEmoji,
                    style: const TextStyle(fontSize: 22),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Divider
          Container(height: 1, color: _kCardBorder),
          const SizedBox(height: 10),
          // Quote + Bonus button
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Text(
                  '"Every master was once a beginner"',
                  style: TextStyle(
                    color: _kTextSecondary,
                    fontSize: 11,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              OutlinedButton(
                onPressed: () {},
                style: OutlinedButton.styleFrom(
                  foregroundColor: _kGreenLight,
                  side: const BorderSide(color: _kGreen, width: 1),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
                child: const Text(
                  'Bonus!',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Live Games ────────────────────────────────────────────────────────────────

  Widget _buildLiveGames() {
    return _LiveGamesSection(
      pulseOpacity: _pulseOpacity,
      onStartGame: () => _startLocalGame(context),
    );
  }

  // ── Bottom Grid ───────────────────────────────────────────────────────────────

  Widget _buildBottomGrid() {
    return Row(
      children: [
        Expanded(
          child: _BottomGridCard(
            icon: '🏆',
            title: 'Hall of Fame',
            subtitle: 'Top Players',
            onTap: () => context.push('/chess/legacy'),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _BottomGridCard(
            icon: '📋',
            title: 'History',
            subtitle: 'Your Games',
            onTap: () => context.push('/chess/history'),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _BottomGridCard(
            icon: '📖',
            title: 'Legends',
            subtitle: 'Chess Stories',
            onTap: () => context.push('/chess/legends'),
          ),
        ),
      ],
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

// ── Play Mode Card ────────────────────────────────────────────────────────────

class _PlayModeCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final String emoji;
  final List<Color> gradientColors;
  final String? badge;
  final Color? badgeColor;
  final VoidCallback onTap;

  const _PlayModeCard({
    required this.title,
    required this.subtitle,
    required this.emoji,
    required this.gradientColors,
    this.badge,
    this.badgeColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 140,
        height: 185,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: gradientColors,
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: Colors.white.withOpacity(0.07),
            width: 1,
          ),
        ),
        child: Stack(
          children: [
            // Large background emoji — decorative
            Positioned(
              right: -10,
              bottom: 20,
              child: Transform.rotate(
                angle: 0.15 * math.pi,
                child: Opacity(
                  opacity: 0.18,
                  child: Text(
                    emoji,
                    style: const TextStyle(
                      fontSize: 72,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ),
            // Badge at top
            if (badge != null)
              Positioned(
                top: 10,
                left: 10,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                  decoration: BoxDecoration(
                    color: (badgeColor ?? _kGreen).withOpacity(0.2),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: (badgeColor ?? _kGreen).withOpacity(0.6),
                      width: 1,
                    ),
                  ),
                  child: Text(
                    badge!,
                    style: TextStyle(
                      color: badgeColor ?? _kGreenLight,
                      fontSize: 8,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            // Title + subtitle at bottom
            Positioned(
              left: 10,
              right: 10,
              bottom: 12,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: _kTextSecondary,
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Bottom Grid Card ──────────────────────────────────────────────────────────

class _BottomGridCard extends StatelessWidget {
  final String icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _BottomGridCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 10),
        decoration: BoxDecoration(
          color: _kCard,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _kCardBorder, width: 1),
        ),
        child: Column(
          children: [
            Text(icon, style: const TextStyle(fontSize: 22)),
            const SizedBox(height: 6),
            Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: const TextStyle(
                color: _kTextSecondary,
                fontSize: 10,
              ),
              textAlign: TextAlign.center,
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
  final VoidCallback? onStartGame;

  const _LiveGamesSection({
    required this.pulseOpacity,
    this.onStartGame,
  });

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
                'LIVE GAMES',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                  letterSpacing: 1.2,
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
              const Spacer(),
              GestureDetector(
                onTap: () => context.push('/chess/challenge'),
                child: const Text(
                  'View All >',
                  style: TextStyle(
                    color: _kGreenLight,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
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
                        color: _kGreen,
                      ),
                    ),
                  ),
                );
              }
              final games = snap.data ?? [];
              if (games.isEmpty) {
                return Column(
                  children: [
                    const Text(
                      '♟',
                      style: TextStyle(
                        fontSize: 48,
                        color: _kTextSecondary,
                      ),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'No live games right now',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Be the first to start a game and let others watch',
                      style: TextStyle(
                        color: _kTextSecondary,
                        fontSize: 12,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 14),
                    OutlinedButton(
                      onPressed: widget.onStartGame,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: _kGreenLight,
                        side: const BorderSide(color: _kGreen, width: 1.5),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 24, vertical: 10),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(24),
                        ),
                      ),
                      child: const Text(
                        'Start a Game',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
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
              backgroundColor: _kGreen,
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
