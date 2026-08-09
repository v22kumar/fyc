import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../domain/entities/tournament_entity.dart';
import '../bloc/sports_bloc.dart';
import '../bloc/sports_event.dart';
import '../bloc/sports_state.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/storage/local_storage.dart';
import '../../../../service_locator.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../auth/presentation/bloc/auth_state.dart';
import '../../../../core/widgets/shimmer_loader.dart';
import '../../../../core/widgets/empty_state.dart';
import 'package:fyc_connect/core/l10n/tr.dart';
import '../widgets/weekly_game_card.dart';
import '../widgets/create_weekly_game_sheet.dart';

class _SportFilter {
  final String value; // empty == all
  final IconData icon;
  final String labelEn;
  final String labelTa;
  const _SportFilter(this.value, this.icon, this.labelEn, this.labelTa);
}

const _sportFilters = <_SportFilter>[
  _SportFilter('', Icons.workspace_premium_rounded, 'All', 'அனைத்தும்'),
  _SportFilter('tournaments', Icons.emoji_events_rounded, 'Tournaments', 'போட்டிகள்'),
  _SportFilter('weekly_games', Icons.local_fire_department_rounded, 'Weekly Games', 'வாராந்திர விளையாட்டுகள்'),
  _SportFilter('chess', Icons.castle_rounded, 'Chess', 'சதுரங்கம்'),
];

IconData sportIcon(String sport) {
  final s = sport.toLowerCase();
  if (s.contains('cricket')) return Icons.sports_cricket_rounded;
  if (s.contains('kabaddi')) return Icons.sports_kabaddi_rounded;
  if (s.contains('volleyball')) return Icons.sports_volleyball_rounded;
  if (s.contains('football')) return Icons.sports_soccer_rounded;
  if (s.contains('chess')) return Icons.castle_rounded;
  return Icons.emoji_events_rounded;
}

class SportsHubScreen extends StatefulWidget {
  const SportsHubScreen({super.key});

  @override
  State<SportsHubScreen> createState() => _SportsHubScreenState();
}

class _SportsHubScreenState extends State<SportsHubScreen> {
  String get _lang => sl<LocalStorage>().getLang();
  String _selectedSport = '';

  @override
  void initState() {
    super.initState();
    context.read<SportsBloc>().add(const SportsFetchRequested());
  }

  void _selectSport(String sport) {
    if (sport == 'chess') {
      context.push('/chess');
      return;
    }
    setState(() => _selectedSport = sport);
    context.read<SportsBloc>().add(
          SportsFetchRequested(
            sport: sport == 'weekly_games' ? null : sport,
            filter: sport == 'weekly_games' ? 'weekly_games' : null,
          ),
        );
  }

  bool get _isAdmin {
    final s = context.read<AuthBloc>().state;
    return s is AuthAuthenticated && s.user.isAdmin;
  }

  void _showCreateWeeklyGameSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => BlocProvider.value(
        value: context.read<SportsBloc>(),
        child: const CreateWeeklyGameSheet(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isAdmin = _isAdmin;
    return Scaffold(
      appBar: AppBar(
        title: Text(trId('sports_hub')),
        actions: [
          if (isAdmin)
            IconButton(
              tooltip: trId('score_approvals'),
              icon: const Icon(Icons.fact_check_outlined),
              onPressed: () => context.push('/sports/approvals'),
            ),
        ],
      ),
      floatingActionButton: _selectedSport == 'weekly_games'
          ? FloatingActionButton.extended(
              onPressed: () => _showCreateWeeklyGameSheet(context),
              backgroundColor: AppColors.primary,
              icon: Icon(Icons.add, color: AppColors.background),
              label: Text(
                trId('schedule_game'),
                style: TextStyle(color: AppColors.background, fontWeight: FontWeight.w700),
              ),
            )
          : isAdmin
              ? FloatingActionButton.extended(
                  onPressed: () => context.push('/sports/create'),
                  backgroundColor: AppColors.primary,
                  icon: Icon(Icons.add, color: AppColors.background),
                  label: Text(
                    trId('create_2'),
                    style: TextStyle(color: AppColors.background, fontWeight: FontWeight.w700),
                  ),
                )
              : null,
      body: Column(
        children: [
          // Hero banner (street cricket at golden hour)
          SizedBox(
            height: 120,
            width: double.infinity,
            child: Stack(
              fit: StackFit.expand,
              children: [
                Image.asset(
                  'assets/images/sports_cricket.png',
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) =>
                      Container(color: AppColors.primary.withValues(alpha: 0.15)),
                ),
                DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        AppColors.textPrimary.withValues(alpha: 0.0),
                        AppColors.textPrimary.withValues(alpha: 0.45),
                      ],
                    ),
                  ),
                ),
                Positioned(
                  left: 16,
                  bottom: 12,
                  child: Text(
                    trId('play_compete_win'),
                    style: TextStyle(
                      color: AppColors.background,
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      shadows: const [Shadow(color: Colors.black54, blurRadius: 6)],
                    ),
                  ),
                ),
              ],
            ),
          ),
          _SportTabs(
            filters: _sportFilters,
            selected: _selectedSport,
            lang: _lang,
            onSelect: _selectSport,
          ),
          Expanded(
            child: BlocBuilder<SportsBloc, SportsState>(
              builder: (context, state) {
                if (state is SportsLoading) {
                  return const ShimmerCardList();
                }
                if (state is SportsLoaded) {
                  if (_selectedSport == 'weekly_games') {
                    if (state.weeklyGames.isEmpty) {
                      return EmptyState(
                        icon: Icons.local_fire_department_rounded,
                        title: trId('no_weekly_games'),
                        message: trId('there_are_no_weekly_games_scheduled_at_t'),
                        buttonText: trId('refresh'),
                        onAction: () => _selectSport(_selectedSport),
                      );
                    }
                    return RefreshIndicator(
                      onRefresh: () async {
                        context.read<SportsBloc>().add(const SportsFetchRequested(filter: 'weekly_games'));
                      },
                      child: ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: state.weeklyGames.length,
                        itemBuilder: (context, i) {
                          final g = state.weeklyGames[i];
                          final currentUserId = (context.read<AuthBloc>().state as AuthAuthenticated).user.id;
                          return WeeklyGameCard(
                            game: g,
                            lang: _lang,
                            currentUserId: currentUserId,
                          );
                        },
                      ),
                    );
                  }

                  if (state.tournaments.isEmpty) {
                    return EmptyState(
                      icon: Icons.emoji_events_rounded,
                      title: trId('no_tournaments'),
                      message: trId('there_are_no_active_sports_tournaments_a'),
                      buttonText: trId('refresh'),
                      onAction: () => _selectSport(_selectedSport),
                    );
                  }
                  return RefreshIndicator(
                    onRefresh: () async {
                      context.read<SportsBloc>().add(
                            SportsFetchRequested(
                              sport: _selectedSport.isEmpty
                                  ? null
                                  : _selectedSport,
                            ),
                          );
                    },
                    child: ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: state.tournaments.length,
                      itemBuilder: (context, i) {
                        final t = state.tournaments[i];
                        return _TournamentCard(
                          tournament: t,
                          lang: _lang,
                          onTap: () => context.go(
                            '/sports/tournament',
                            extra: {'tournamentId': t.id},
                          ),
                        );
                      },
                    ),
                  );
                }
                if (state is SportsFailure) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.error_outline,
                            size: 48, color: context.cTextSecondary),
                        const SizedBox(height: 12),
                        Text(state.message),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: () => _selectSport(_selectedSport),
                          child: Text(trId('retry')),
                        ),
                      ],
                    ),
                  );
                }
                return const SizedBox.shrink();
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _SportTabs extends StatelessWidget {
  final List<_SportFilter> filters;
  final String selected;
  final String lang;
  final ValueChanged<String> onSelect;

  const _SportTabs({
    required this.filters,
    required this.selected,
    required this.lang,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: context.cSurface,
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Row(
          children: filters.map((f) {
            final isSelected = f.value == selected;
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                selected: isSelected,
                onSelected: (_) => onSelect(f.value),
                avatar: Icon(f.icon, size: 16,
                    color: isSelected ? AppColors.background : context.cTextSecondary),
                label: Text(lang == 'ta' ? f.labelTa : f.labelEn),
                labelStyle: TextStyle(
                  color: isSelected ? AppColors.background : context.cText,
                  fontWeight: FontWeight.w600,
                ),
                selectedColor: AppColors.primary,
                backgroundColor: context.cBackground,
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}

class _TournamentCard extends StatelessWidget {
  final TournamentEntity tournament;
  final String lang;
  final VoidCallback onTap;

  const _TournamentCard({
    required this.tournament,
    required this.lang,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isOpen = tournament.isRegistrationOpen;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.radiusCard),
        side: isOpen
            ? BorderSide(color: AppColors.primary.withValues(alpha: 0.3), width: 1.5)
            : BorderSide.none,
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppTheme.radiusCard),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    alignment: Alignment.center,
                    child: Icon(
                      sportIcon(tournament.sport),
                      size: 24,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          tournament.displayName(lang),
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(Icons.emoji_events_rounded, size: 14, color: AppColors.accent),
                            const SizedBox(width: 4),
                            Text(
                              '${tournament.sport} · ${tournament.year}',
                              style: TextStyle(
                                  color: context.cTextSecondary, fontSize: 13),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              if (isOpen) ...[
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.how_to_reg, size: 16, color: AppColors.primary),
                      const SizedBox(width: 8),
                      Text(
                        trId('registration_open_2'),
                        style: TextStyle(
                          color: AppColors.primary,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (tournament.registrationCloseDate != null) ...[
                        const SizedBox(width: 8),
                        Text(
                          '• closes ${DateFormat('MMM d').format(tournament.registrationCloseDate!.toLocal())}',
                          style: TextStyle(
                            color: AppColors.primary.withValues(alpha: 0.8),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ] else if (tournament.isOngoing) ...[
                const SizedBox(height: 14),
                Row(
                  children: [
                    Icon(Icons.play_circle_fill, size: 16, color: AppColors.success),
                    const SizedBox(width: 8),
                    Text(
                      trId('tournament_is_live'),
                      style: TextStyle(
                        color: AppColors.success,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}


