import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../domain/entities/tournament_entity.dart';
import '../bloc/sports_bloc.dart';
import '../bloc/sports_event.dart';
import '../bloc/sports_state.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/storage/local_storage.dart';
import '../../../../service_locator.dart';

class _SportFilter {
  final String value; // empty == all
  final String emoji;
  final String labelEn;
  final String labelTa;
  const _SportFilter(this.value, this.emoji, this.labelEn, this.labelTa);
}

const _sportFilters = <_SportFilter>[
  _SportFilter('', '🏅', 'All', 'அனைத்தும்'),
  _SportFilter('cricket', '🏏', 'Cricket', 'கிரிக்கெட்'),
  _SportFilter('kabaddi', '🤼', 'Kabaddi', 'கபடி'),
  _SportFilter('volleyball', '🏐', 'Volleyball', 'கைப்பந்து'),
  _SportFilter('football', '⚽', 'Football', 'கால்பந்து'),
  _SportFilter('other', '🎯', 'Other', 'மற்றவை'),
];

String sportEmoji(String sport) {
  for (final f in _sportFilters) {
    if (f.value == sport.toLowerCase()) return f.emoji;
  }
  return '🎯';
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
    setState(() => _selectedSport = sport);
    context.read<SportsBloc>().add(
          SportsFetchRequested(sport: sport.isEmpty ? null : sport),
        );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_lang == 'ta' ? 'விளையாட்டு மையம்' : 'Sports Hub'),
      ),
      body: Column(
        children: [
          _SportTabs(
            filters: _sportFilters,
            selected: _selectedSport,
            lang: _lang,
            onSelect: _selectSport,
          ),
          _ChallengeBanner(
            lang: _lang,
            onTap: () => context.go('/sports/challenge'),
          ),
          Expanded(
            child: BlocBuilder<SportsBloc, SportsState>(
              builder: (context, state) {
                if (state is SportsLoading) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (state is SportsLoaded) {
                  if (state.tournaments.isEmpty) {
                    return _EmptyTournaments(lang: _lang);
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
                        const Icon(Icons.error_outline,
                            size: 48, color: Colors.grey),
                        const SizedBox(height: 12),
                        Text(state.message),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: () => _selectSport(_selectedSport),
                          child: Text(_lang == 'ta'
                              ? 'மீண்டும் முயற்சிக்கவும்'
                              : 'Retry'),
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
      color: AppColors.surface,
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
                label: Text('${f.emoji} ${lang == 'ta' ? f.labelTa : f.labelEn}'),
                labelStyle: TextStyle(
                  color: isSelected ? Colors.white : AppColors.textPrimary,
                  fontWeight: FontWeight.w500,
                ),
                selectedColor: AppColors.primary,
                backgroundColor: AppColors.background,
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}

class _ChallengeBanner extends StatelessWidget {
  final String lang;
  final VoidCallback onTap;

  const _ChallengeBanner({required this.lang, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: Material(
        color: AppColors.accent,
        borderRadius: BorderRadius.circular(AppTheme.radiusCard),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppTheme.radiusCard),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                const Text('⚔️', style: TextStyle(fontSize: 22)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        lang == 'ta' ? 'FYC ஐ சவால் விடுங்கள்' : 'Challenge FYC',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        lang == 'ta'
                            ? 'உங்கள் அணியுடன் போட்டியிடுங்கள்'
                            : 'Send your team a match request',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right, color: Colors.white),
              ],
            ),
          ),
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
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppTheme.radiusCard),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Text(
                sportEmoji(tournament.sport),
                style: const TextStyle(fontSize: 30),
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
                    Text(
                      '${tournament.sport} · ${tournament.year}',
                      style:
                          TextStyle(color: Colors.grey[600], fontSize: 13),
                    ),
                  ],
                ),
              ),
              _StatusBadge(status: tournament.status),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String status;
  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final s = status.toLowerCase();
    Color color;
    if (s == 'live' || s == 'ongoing') {
      color = AppColors.success;
    } else if (s == 'completed') {
      color = AppColors.textSecondary;
    } else {
      color = AppColors.accent;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        status.toUpperCase(),
        style: const TextStyle(
          color: Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

class _EmptyTournaments extends StatelessWidget {
  final String lang;
  const _EmptyTournaments({required this.lang});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('🏅', style: TextStyle(fontSize: 64)),
          const SizedBox(height: 16),
          Text(
            lang == 'ta' ? 'போட்டிகள் இல்லை' : 'No tournaments yet',
            style: const TextStyle(fontSize: 16, color: Colors.grey),
          ),
        ],
      ),
    );
  }
}
