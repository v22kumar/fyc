import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import '../../domain/entities/fixture_entity.dart';
import '../../domain/entities/team_entity.dart';
import '../../domain/entities/tournament_entity.dart';
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
    if (state is SportsDetailLoaded &&
        state.tournament.sport.toLowerCase() == 'cricket') {
      // Full ball-by-ball cricket scoring, in-app, for admin + manager
      // (backend gates these endpoints to EXECUTIVE_MEMBER and above).
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => CricketScoringScreen(fixture: f),
        ),
      );
      _reload();
      return;
    }

    final sport = state is SportsDetailLoaded ? state.tournament.sport : 'other';
    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.cBackground,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (_) => import_LiveScoreEntrySheet.LiveScoreEntrySheet(
        fixture: f,
        sport: sport,
        isManager: _isAdmin, // EXECUTIVE_MEMBER+ → result applies immediately
      ),
    );
    if (ok == true) _reload();
  }

  Future<void> _generateFixtures({bool force = false}) async {
    try {
      await sl<ApiClient>().dio.post(
        ApiConstants.sportsGenerateFixtures(widget.tournamentId),
        queryParameters: force ? {'force': true} : null,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(tr(en: 'Fixtures generated', ta: 'அட்டவணை உருவாக்கப்பட்டது',
              hi: 'फ़िक्स्चर बन गए', ml: 'ഫിക്സ്ചറുകൾ സൃഷ്ടിച്ചു')),
          backgroundColor: AppColors.primary,
        ),
      );
      _reload();
    } on DioException catch (e) {
      if (!mounted) return;
      final detail = e.response?.data is Map ? e.response?.data['detail'] as String? : null;
      // Registration still open → offer to close it early and force-generate.
      if (!force && detail != null && detail.contains('Registration is still open')) {
        final go = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Text(tr(en: 'Registration still open', ta: 'பதிவு இன்னும் திறந்துள்ளது',
                hi: 'रजिस्ट्रेशन अभी खुला है', ml: 'രജിസ്ട്രേഷൻ ഇപ്പോഴും തുറന്നിരിക്കുന്നു')),
            content: Text(detail),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: Text(tr(en: 'Wait', ta: 'காத்திரு', hi: 'रुकें', ml: 'കാത്തിരിക്കുക')),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: Text(tr(en: 'Close early & generate', ta: 'முன்கூட்டியே மூடி உருவாக்கு',
                    hi: 'जल्दी बंद करें और बनाएं', ml: 'നേരത്തെ അടച്ച് സൃഷ്ടിക്കുക')),
              ),
            ],
          ),
        );
        if (go == true) await _generateFixtures(force: true);
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(detail ??
              tr(en: 'Could not generate — need ≥2 approved teams and no existing fixtures',
                  ta: 'உருவாக்க முடியவில்லை — குறைந்தது 2 அணிகள் தேவை',
                  hi: 'नहीं बना — कम से कम 2 टीमें चाहिए',
                  ml: 'സൃഷ്ടിക്കാനായില്ല — കുറഞ്ഞത് 2 ടീമുകൾ വേണം')),
          backgroundColor: AppColors.accent,
        ),
      );
    }
  }

  Future<void> _closeRegistration() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(tr(en: 'Close registration?', ta: 'பதிவை மூடவா?',
            hi: 'रजिस्ट्रेशन बंद करें?', ml: 'രജിസ്ട്രേഷൻ അടയ്ക്കണോ?')),
        content: Text(tr(
            en: 'No new teams can register after this. You can then generate fixtures.',
            ta: 'இதற்குப் பிறகு புதிய அணிகள் பதிவு செய்ய முடியாது. பிறகு அட்டவணை உருவாக்கலாம்.',
            hi: 'इसके बाद कोई नई टीम रजिस्टर नहीं कर सकती। फिर आप फ़िक्स्चर बना सकते हैं।',
            ml: 'ഇതിനുശേഷം പുതിയ ടീമുകൾക്ക് രജിസ്റ്റർ ചെയ്യാനാകില്ല. പിന്നീട് ഫിക്സ്ചറുകൾ സൃഷ്ടിക്കാം.')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false),
              child: Text(tr(en: 'Cancel', ta: 'ரத்து', hi: 'रद्द', ml: 'റദ്ദാക്കുക'))),
          FilledButton(onPressed: () => Navigator.pop(ctx, true),
              child: Text(tr(en: 'Close registration', ta: 'பதிவை மூடு',
                  hi: 'रजिस्ट्रेशन बंद करें', ml: 'രജിസ്ട്രേഷൻ അടയ്ക്കുക'))),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      await sl<ApiClient>().dio.post(ApiConstants.sportsCloseRegistration(widget.tournamentId));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(tr(en: 'Registration closed', ta: 'பதிவு மூடப்பட்டது',
            hi: 'रजिस्ट्रेशन बंद', ml: 'രജിസ്ട്രേഷൻ അടച്ചു')),
        backgroundColor: AppColors.primary,
      ));
      _reload();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(tr(en: 'Could not close registration', ta: 'மூட முடியவில்லை',
            hi: 'बंद नहीं हो सका', ml: 'അടയ്ക്കാനായില്ല')),
        backgroundColor: AppColors.accent,
      ));
    }
  }

  /// Friendly, localized label + color for the tournament's lifecycle phase.
  (String, Color) _phaseChip(TournamentEntity t) {
    switch (t.effectivePhase) {
      case 'REGISTRATION_OPEN':
        return (tr(en: 'REGISTRATION OPEN', ta: 'பதிவு திறந்துள்ளது',
            hi: 'रजिस्ट्रेशन खुला', ml: 'രജിസ്ട്രേഷൻ തുറന്നു'), const Color(0xFF12A150));
      case 'REGISTRATION_CLOSED':
        return (tr(en: 'REGISTRATION CLOSED', ta: 'பதிவு மூடப்பட்டது',
            hi: 'रजिस्ट्रेशन बंद', ml: 'രജിസ്ട്രേഷൻ അടച്ചു'), const Color(0xFFD97706));
      case 'ONGOING':
        return (tr(en: 'ONGOING', ta: 'நடைபெறுகிறது', hi: 'चल रहा है', ml: 'നടക്കുന്നു'),
            const Color(0xFF2563EB));
      case 'COMPLETED':
        return (tr(en: 'COMPLETED', ta: 'முடிந்தது', hi: 'समाप्त', ml: 'പൂർത്തിയായി'),
            const Color(0xFF6B7280));
      default:
        return (t.status, const Color(0xFF0B6E4F));
    }
  }

  @override
  Widget build(BuildContext context) {
    final isAdmin = _isAdmin;
    final isMember = _isMember;
    return Scaffold(
      appBar: AppBar(
        title: Text(tr(en: 'Tournament', ta: 'போட்டி விவரம்', hi: 'टूर्नामेंट', ml: 'ടൂർണമെന്റ്')),
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
                            Builder(builder: (_) {
                              final (label, color) = _phaseChip(state.tournament);
                              return Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  label,
                                  style: TextStyle(
                                      color: color,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w800),
                                ),
                              );
                            }),
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
                      (f) {
                        // Cricket = ball-by-ball scoring: managers (EXECUTIVE_MEMBER+)
                        // only, matching the backend. Other sports use the
                        // club-member live-entry-for-approval flow.
                        final isCricket =
                            state.tournament.sport.toLowerCase() == 'cricket';
                        final canScore = isCricket ? isAdmin : isMember;
                        return _FixtureCard(
                          fixture: f,
                          lang: _lang,
                          onEnterScore:
                              (canScore && !f.isCompleted) ? () => _enterScore(f) : null,
                        );
                      },
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
                  
                  // Register: only while registration is open.
                  if (state.tournament.isRegistrationOpen)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
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

                  // Admin lifecycle actions: close registration → generate fixtures.
                  if (isAdmin && state.tournament.isRegistrationOpen)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 24),
                      child: SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: OutlinedButton.icon(
                          onPressed: _closeRegistration,
                          icon: const Icon(Icons.lock_clock_outlined),
                          label: Text(tr(en: 'Close registration now', ta: 'இப்போது பதிவை மூடு',
                              hi: 'रजिस्ट्रेशन अभी बंद करें', ml: 'ഇപ്പോൾ രജിസ്ട്രേഷൻ അടയ്ക്കുക')),
                        ),
                      ),
                    ),
                  if (isAdmin && state.tournament.isRegistrationClosed)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 24),
                      child: SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton.icon(
                          onPressed: _generateFixtures,
                          icon: const Icon(Icons.auto_awesome_motion_outlined, color: Colors.white),
                          label: Text(tr(en: 'Generate fixtures', ta: 'அட்டவணை உருவாக்கு',
                              hi: 'फ़िक्स्चर बनाएं', ml: 'ഫിക്സ്ചറുകൾ സൃഷ്ടിക്കുക'),
                              style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFD97706), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
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
