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
                      onTap: null, // Sprint 6
                      comingSoon: true,
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
          context.read<GameBloc>().add(const NewGame()); // reset any previous
          context.push(
            '/chess/local',
            extra: {'white': white, 'black': black},
          );
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
