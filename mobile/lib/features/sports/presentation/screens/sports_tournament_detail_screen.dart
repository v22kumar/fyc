import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import '../../domain/entities/fixture_entity.dart';
import '../../domain/entities/team_entity.dart';
import '../bloc/sports_bloc.dart';
import '../bloc/sports_event.dart';
import '../bloc/sports_state.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/storage/local_storage.dart';
import '../../../../service_locator.dart';

class SportsTournamentDetailScreen extends StatefulWidget {
  final String tournamentId;
  const SportsTournamentDetailScreen({super.key, required this.tournamentId});

  @override
  State<SportsTournamentDetailScreen> createState() =>
      _SportsTournamentDetailScreenState();
}

class _SportsTournamentDetailScreenState
    extends State<SportsTournamentDetailScreen> {
  String get _lang => sl<LocalStorage>().getLang();

  @override
  void initState() {
    super.initState();
    context
        .read<SportsBloc>()
        .add(SportsTournamentSelected(widget.tournamentId));
  }

  void _reload() {
    context
        .read<SportsBloc>()
        .add(SportsTournamentSelected(widget.tournamentId));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_lang == 'ta' ? 'போட்டி விவரம்' : 'Tournament'),
      ),
      body: BlocBuilder<SportsBloc, SportsState>(
        builder: (context, state) {
          if (state is SportsLoading) {
            return const Center(child: CircularProgressIndicator());
          }
          if (state is SportsDetailLoaded) {
            if (state.fixtures.isEmpty && state.standings.isEmpty) {
              return _EmptyDetail(lang: _lang);
            }
            return RefreshIndicator(
              onRefresh: () async => _reload(),
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _SectionHeader(
                    label: _lang == 'ta' ? 'போட்டிகள்' : 'Fixtures',
                  ),
                  if (state.fixtures.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Text(
                        _lang == 'ta'
                            ? 'போட்டிகள் இல்லை'
                            : 'No fixtures scheduled',
                        style: const TextStyle(color: Colors.grey),
                      ),
                    )
                  else
                    ...state.fixtures.map(
                      (f) => _FixtureCard(fixture: f, lang: _lang),
                    ),
                  const SizedBox(height: 16),
                  _SectionHeader(
                    label: _lang == 'ta' ? 'புள்ளிப்பட்டியல்' : 'Standings',
                  ),
                  if (state.standings.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Text(
                        _lang == 'ta'
                            ? 'அணிகள் இல்லை'
                            : 'No teams yet',
                        style: const TextStyle(color: Colors.grey),
                      ),
                    )
                  else
                    _StandingsTable(teams: state.standings, lang: _lang),
                ],
              ),
            );
          }
          if (state is SportsFailure) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.error_outline, size: 48, color: Colors.grey),
                  const SizedBox(height: 12),
                  Text(state.message),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _reload,
                    child: Text(
                        _lang == 'ta' ? 'மீண்டும் முயற்சிக்கவும்' : 'Retry'),
                  ),
                ],
              ),
            );
          }
          return const SizedBox.shrink();
        },
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String label;
  const _SectionHeader({required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10, top: 4),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: AppColors.textSecondary,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

class _FixtureCard extends StatelessWidget {
  final FixtureEntity fixture;
  final String lang;

  const _FixtureCard({required this.fixture, required this.lang});

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat('d MMM yyyy · h:mm a');
    final teamA = fixture.teamAName ?? (lang == 'ta' ? 'அணி A' : 'Team A');
    final teamB = fixture.teamBName ?? (lang == 'ta' ? 'அணி B' : 'Team B');
    final hasScore =
        (fixture.teamAScore != null) || (fixture.teamBScore != null);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (fixture.matchNumber != null)
                  Text(
                    (lang == 'ta' ? 'போட்டி #' : 'Match #') +
                        '${fixture.matchNumber}',
                    style: const TextStyle(
                        fontSize: 12, color: AppColors.textSecondary),
                  ),
                const Spacer(),
                _FixtureStatusBadge(fixture: fixture, lang: lang),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: Text(
                    teamA,
                    style: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w600),
                  ),
                ),
                if (hasScore)
                  Text(
                    '${fixture.teamAScore ?? '-'} : ${fixture.teamBScore ?? '-'}',
                    style: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.bold),
                  )
                else
                  Text(
                    lang == 'ta' ? 'எதிராக' : 'vs',
                    style: const TextStyle(
                        fontSize: 13, color: AppColors.textSecondary),
                  ),
                Expanded(
                  child: Text(
                    teamB,
                    textAlign: TextAlign.right,
                    style: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
            if (fixture.scheduledAt != null) ...[
              const SizedBox(height: 10),
              Row(
                children: [
                  const Icon(Icons.schedule, size: 14, color: Colors.grey),
                  const SizedBox(width: 4),
                  Text(
                    fmt.format(fixture.scheduledAt!.toLocal()),
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
            ],
            if (fixture.venue != null && fixture.venue!.isNotEmpty) ...[
              const SizedBox(height: 6),
              Row(
                children: [
                  const Icon(Icons.place, size: 14, color: Colors.grey),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      fixture.venue!,
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ),
                ],
              ),
            ],
            if (fixture.resultNotes != null &&
                fixture.resultNotes!.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                fixture.resultNotes!,
                style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                    fontStyle: FontStyle.italic),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _FixtureStatusBadge extends StatelessWidget {
  final FixtureEntity fixture;
  final String lang;
  const _FixtureStatusBadge({required this.fixture, required this.lang});

  @override
  Widget build(BuildContext context) {
    Color color;
    String label = fixture.status.toUpperCase();
    if (fixture.isLive) {
      color = AppColors.success;
      label = 'LIVE';
    } else if (fixture.isCompleted) {
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
        label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

class _StandingsTable extends StatelessWidget {
  final List<TeamEntity> teams;
  final String lang;

  const _StandingsTable({required this.teams, required this.lang});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
              child: Row(
                children: [
                  Expanded(
                    flex: 4,
                    child: Text(
                      lang == 'ta' ? 'அணி' : 'Team',
                      style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textSecondary),
                    ),
                  ),
                  ..._headerCells(),
                ],
              ),
            ),
            const Divider(height: 1),
            ...teams.map((t) => _StandingsRow(team: t, lang: lang)),
          ],
        ),
      ),
    );
  }

  List<Widget> _headerCells() {
    const labels = ['P', 'W', 'L', 'D', 'Pts'];
    return labels
        .map(
          (l) => Expanded(
            flex: 1,
            child: Text(
              l,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textSecondary),
            ),
          ),
        )
        .toList();
  }
}

class _StandingsRow extends StatelessWidget {
  final TeamEntity team;
  final String lang;
  const _StandingsRow({required this.team, required this.lang});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: team.isFycTeam ? AppColors.primarySurface : null,
        borderRadius: BorderRadius.circular(8),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
      child: Row(
        children: [
          Expanded(
            flex: 4,
            child: Row(
              children: [
                if (team.isFycTeam)
                  const Padding(
                    padding: EdgeInsets.only(right: 4),
                    child: Text('⭐', style: TextStyle(fontSize: 12)),
                  ),
                Expanded(
                  child: Text(
                    team.name,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: team.isFycTeam
                          ? FontWeight.bold
                          : FontWeight.w500,
                      color: team.isFycTeam ? AppColors.primary : null,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          _cell('${team.played}'),
          _cell('${team.wins}'),
          _cell('${team.losses}'),
          _cell('${team.draws}'),
          _cell('${team.points}', bold: true),
        ],
      ),
    );
  }

  Widget _cell(String text, {bool bold = false}) {
    return Expanded(
      flex: 1,
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 13,
          fontWeight: bold ? FontWeight.bold : FontWeight.normal,
        ),
      ),
    );
  }
}

class _EmptyDetail extends StatelessWidget {
  final String lang;
  const _EmptyDetail({required this.lang});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('🏟️', style: TextStyle(fontSize: 64)),
          const SizedBox(height: 16),
          Text(
            lang == 'ta'
                ? 'விவரங்கள் இன்னும் இல்லை'
                : 'No details available yet',
            style: const TextStyle(fontSize: 16, color: Colors.grey),
          ),
        ],
      ),
    );
  }
}
