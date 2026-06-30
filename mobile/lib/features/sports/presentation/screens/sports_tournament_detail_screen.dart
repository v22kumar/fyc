import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import '../../domain/entities/fixture_entity.dart';
import '../../domain/entities/team_entity.dart';
import '../bloc/sports_bloc.dart';
import '../bloc/sports_event.dart';
import '../bloc/sports_state.dart';
import '../widgets/live_score_entry_sheet.dart' as import_LiveScoreEntrySheet;
import '../widgets/register_team_sheet.dart' as import_RegisterTeamSheet;
import 'cricket_scoring_screen.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/storage/local_storage.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/constants/api_constants.dart';
import '../../../../service_locator.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../auth/presentation/bloc/auth_state.dart';
import 'package:fyc_connect/core/l10n/tr.dart';

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

  bool get _isAdmin {
    final s = context.read<AuthBloc>().state;
    return s is AuthAuthenticated && s.user.isAdmin;
  }

  bool get _isMember {
    final s = context.read<AuthBloc>().state;
    return s is AuthAuthenticated && s.user.isMember;
  }

  Future<void> _enterScore(FixtureEntity f) async {
    final state = context.read<SportsBloc>().state;
    if (state is SportsDetailLoaded && state.tournament.sport == 'cricket') {
      // Full ball-by-ball cricket scoring, in-app, for admin + manager
      // (backend gates these endpoints to EXECUTIVE_MEMBER and above).
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => CricketScoringScreen(fixtureId: f.id),
        ),
      );
      _reload();
      return;
    }

    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.cBackground,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (_) => import_LiveScoreEntrySheet.LiveScoreEntrySheet(fixture: f),
    );
    if (ok == true) _reload();
  }

  Future<void> _generateFixtures() async {
    try {
      await sl<ApiClient>().dio.post(
        ApiConstants.sportsGenerateFixtures(widget.tournamentId),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Fixtures generated'), backgroundColor: AppColors.primary),
      );
      _reload();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not generate — need ≥2 teams and no existing fixtures'),
          backgroundColor: AppColors.accent,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isAdmin = _isAdmin;
    final isMember = _isMember;
    return Scaffold(
      appBar: AppBar(
        title: Text(tr(en: 'Tournament', ta: 'போட்டி விவரம்', hi: 'टूर्नामेंट', ml: 'ടൂർണമെന്റ്')),
        actions: [
          if (isAdmin)
            IconButton(
              tooltip: tr(en: 'Generate Fixtures', ta: 'அட்டவணை உருவாக்கு', hi: 'फ़िक्स्चर बनाएं', ml: 'ഫിക്സ്ചറുകൾ സൃഷ്ടിക്കുക'),
              icon: const Icon(Icons.auto_awesome_motion_outlined),
              onPressed: _generateFixtures,
            ),
        ],
      ),
      body: BlocBuilder<SportsBloc, SportsState>(
        builder: (context, state) {
          if (state is SportsLoading) {
            return const Center(child: CircularProgressIndicator());
          }
          if (state is SportsDetailLoaded) {
            // NOTE: never gate the whole screen on fixtures/standings being
            // present — a brand-new tournament has neither, yet the user still
            // needs to see the details and the "Register Your Team" button.
            return RefreshIndicator(
              onRefresh: () async => _reload(),
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // ── Tournament header ───────────────────────────────────
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF0B6E4F), Color(0xFF12A150)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          state.tournament.displayName(_lang),
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 19,
                              fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.18),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                '${state.tournament.sport} · ${state.tournament.year}',
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                state.tournament.status,
                                style: const TextStyle(
                                    color: Color(0xFF0B6E4F),
                                    fontSize: 11,
                                    fontWeight: FontWeight.w800),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  _SectionHeader(
                    label: tr(en: 'Fixtures', ta: 'போட்டிகள்', hi: 'फ़िक्स्चर', ml: 'ഫിക്സ്ചറുകൾ'),
                  ),
                  if (state.fixtures.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Text(
                        tr(en: 'No fixtures scheduled', ta: 'போட்டிகள் இல்லை', hi: 'कोई फ़िक्स्चर निर्धारित नहीं', ml: 'ഫിക്സ്ചറുകളൊന്നും ഷെഡ്യൂൾ ചെയ്തിട്ടില്ല'),
                        style: const TextStyle(color: Colors.grey),
                      ),
                    )
                  else
                    ...state.fixtures.map(
                      (f) => _FixtureCard(
                        fixture: f,
                        lang: _lang,
                        onEnterScore:
                            (isMember && !f.isCompleted) ? () => _enterScore(f) : null,
                      ),
                    ),
                  const SizedBox(height: 16),
                  
                  if (state.tournament.descriptionEn != null && state.tournament.descriptionEn!.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: context.isDark ? Colors.grey[900] : Colors.grey[100],
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: context.cBorder),
                        ),
                        child: Text(
                          _lang == 'ta' && state.tournament.descriptionTa != null && state.tournament.descriptionTa!.isNotEmpty
                              ? state.tournament.descriptionTa!
                              : state.tournament.descriptionEn!,
                          style: TextStyle(fontSize: 13, color: context.cText, height: 1.5),
                        ),
                      ),
                    ),
                  
                  if (state.tournament.status == 'UPCOMING' || state.tournament.status == 'PUBLISHED')
                    Padding(
                      padding: const EdgeInsets.only(bottom: 24),
                      child: SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton.icon(
                          onPressed: () async {
                            final ok = await showModalBottomSheet<bool>(
                              context: context,
                              isScrollControlled: true,
                              backgroundColor: context.cBackground,
                              shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
                              builder: (_) => import_RegisterTeamSheet.RegisterTeamSheet(tournamentId: widget.tournamentId),
                            );
                            if (ok == true) _reload();
                          },
                          icon: const Icon(Icons.group_add, color: Colors.white),
                          label: Text(tr(en: 'Register Your Team', ta: 'அணியை பதிவு செய்', hi: 'अपनी टीम पंजीकृत करें', ml: 'നിങ്ങളുടെ ടീം രജിസ്റ്റർ ചെയ്യുക'), style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                          style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                        ),
                      ),
                    ),
                  
                  _SectionHeader(
                    label: tr(en: 'Standings', ta: 'புள்ளிப்பட்டியல்', hi: 'अंक तालिका', ml: 'പോയിന്റ് പട്ടിക'),
                  ),
                  if (state.standings.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Text(
                        tr(en: 'No teams yet', ta: 'அணிகள் இல்லை', hi: 'अभी कोई टीम नहीं', ml: 'ഇതുവരെ ടീമുകളൊന്നുമില്ല'),
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
                        tr(en: 'Retry', ta: 'மீண்டும் முயற்சிக்கவும்', hi: 'पुनः प्रयास करें', ml: 'വീണ്ടും ശ്രമിക്കുക')),
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
  final VoidCallback? onEnterScore;

  const _FixtureCard({required this.fixture, required this.lang, this.onEnterScore});

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat('d MMM yyyy · h:mm a');
    final teamA = fixture.teamAName ?? (tr(en: 'Team A', ta: 'அணி A', hi: 'टीम A', ml: 'ടീം A'));
    final teamB = fixture.teamBName ?? (tr(en: 'Team B', ta: 'அணி B', hi: 'टीम B', ml: 'ടീം B'));
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
                    (tr(en: 'Match #', ta: 'போட்டி #', hi: 'मैच #', ml: 'മത്സരം #')) +
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
                    tr(en: 'vs', ta: 'எதிராக', hi: 'बनाम', ml: 'vs'),
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
            if (onEnterScore != null) ...[
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: onEnterScore,
                  icon: const Icon(Icons.bolt_rounded, size: 16),
                  label: Text(tr(en: 'Enter Live Score', ta: 'ஸ்கோர் பதிவு செய்', hi: 'लाइव स्कोर दर्ज करें', ml: 'ലൈവ് സ്കോർ നൽകുക')),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    side: BorderSide(color: AppColors.primary.withOpacity(0.5)),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
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
                      tr(en: 'Team', ta: 'அணி', hi: 'टीम', ml: 'ടീം'),
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
            tr(en: 'No details available yet', ta: 'விவரங்கள் இன்னும் இல்லை', hi: 'अभी कोई विवरण उपलब्ध नहीं', ml: 'ഇതുവരെ വിശദാംശങ്ങളൊന്നുമില്ല'),
            style: const TextStyle(fontSize: 16, color: Colors.grey),
          ),
        ],
      ),
    );
  }
}
