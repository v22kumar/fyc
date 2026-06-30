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
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../auth/presentation/bloc/auth_state.dart';
import '../../../../core/widgets/shimmer_loader.dart';
import '../../../../core/widgets/empty_state.dart';
import 'package:fyc_connect/core/l10n/tr.dart';

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

  bool get _isAdmin {
    final s = context.read<AuthBloc>().state;
    return s is AuthAuthenticated && s.user.isAdmin;
  }

  @override
  Widget build(BuildContext context) {
    final isAdmin = _isAdmin;
    return Scaffold(
      appBar: AppBar(
        title: Text(tr(en: 'Sports Hub', ta: 'விளையாட்டு மையம்', hi: 'खेल केंद्र', ml: 'കായിക കേന്ദ്രം')),
        actions: [
          if (isAdmin)
            IconButton(
              tooltip: tr(en: 'Score Approvals', ta: 'மதிப்பீடுகள்', hi: 'स्कोर अनुमोदन', ml: 'സ്കോർ അംഗീകാരം'),
              icon: const Icon(Icons.fact_check_outlined),
              onPressed: () => context.push('/sports/approvals'),
            ),
        ],
      ),
      floatingActionButton: isAdmin
          ? FloatingActionButton.extended(
              onPressed: () => context.push('/sports/create'),
              backgroundColor: AppColors.primary,
              icon: const Icon(Icons.add, color: Colors.white),
              label: Text(
                tr(en: 'Create', ta: 'போட்டி உருவாக்கு', hi: 'बनाएं', ml: 'സൃഷ്ടിക്കുക'),
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
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
                      Container(color: AppColors.primary.withOpacity(0.15)),
                ),
                DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withOpacity(0.0),
                        Colors.black.withOpacity(0.45),
                      ],
                    ),
                  ),
                ),
                Positioned(
                  left: 16,
                  bottom: 12,
                  child: Text(
                    tr(en: 'Play. Compete. Win.', ta: 'விளையாடு · வெல்', hi: 'खेलें · प्रतिस्पर्धा · जीतें', ml: 'കളിക്കൂ · മത്സരിക്കൂ · ജയിക്കൂ'),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      shadows: [Shadow(color: Colors.black54, blurRadius: 6)],
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
          _ChallengeBanner(
            lang: _lang,
            onTap: () => context.go('/sports/challenge'),
          ),
          Expanded(
            child: BlocBuilder<SportsBloc, SportsState>(
              builder: (context, state) {
                if (state is SportsLoading) {
                  return const ShimmerCardList();
                }
                if (state is SportsLoaded) {
                  if (state.tournaments.isEmpty) {
                    return EmptyState(
                      emoji: '🏅',
                      title: tr(en: 'No Tournaments', ta: 'போட்டிகள் இல்லை', hi: 'कोई टूर्नामेंट नहीं', ml: 'ടൂർണമെന്റുകളൊന്നുമില്ല'),
                      message: tr(en: 'There are no active sports tournaments at the moment.', ta: 'தற்போது விளையாட்டுப் போட்டிகள் எதுவும் இல்லை.', hi: 'इस समय कोई सक्रिय खेल टूर्नामेंट नहीं है।', ml: 'ഇപ്പോൾ സജീവമായ കായിക ടൂർണമെന്റുകളൊന്നുമില്ല.'),
                      buttonText: tr(en: 'Refresh', ta: 'புதுப்பிக்கவும்', hi: 'ताज़ा करें', ml: 'പുതുക്കുക'),
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
                          child: Text(tr(en: 'Retry', ta: 'மீண்டும் முயற்சிக்கவும்', hi: 'पुनः प्रयास करें', ml: 'വീണ്ടും ശ്രമിക്കുക')),
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
                label: Text('${f.emoji} ${lang == 'ta' ? f.labelTa : f.labelEn}'),
                labelStyle: TextStyle(
                  color: isSelected ? Colors.white : context.cText,
                  fontWeight: FontWeight.w500,
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
                        tr(en: 'Challenge FYC', ta: 'FYC ஐ சவால் விடுங்கள்', hi: 'FYC को चुनौती दें', ml: 'FYC-യെ വെല്ലുവിളിക്കൂ'),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        tr(en: 'Send your team a match request', ta: 'உங்கள் அணியுடன் போட்டியிடுங்கள்', hi: 'अपनी टीम को मैच अनुरोध भेजें', ml: 'നിങ്ങളുടെ ടീമിന് ഒരു മത്സര അഭ്യർത്ഥന അയയ്ക്കൂ'),
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
                          TextStyle(color: context.cTextSecondary, fontSize: 13),
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

// Removed _EmptyTournaments
