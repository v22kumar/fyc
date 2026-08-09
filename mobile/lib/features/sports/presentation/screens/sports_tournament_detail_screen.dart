import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import '../../domain/entities/fixture_entity.dart';
import '../../domain/entities/team_entity.dart';
import '../../domain/entities/tournament_entity.dart';
import '../bloc/sports_bloc.dart';
import '../bloc/sports_event.dart';
import '../bloc/sports_state.dart';
import '../widgets/live_score_entry_sheet.dart' as import_LiveScoreEntrySheet;
import '../widgets/register_team_sheet.dart' as import_RegisterTeamSheet;
import '../widgets/add_fixture_sheet.dart' as import_AddFixtureSheet;
import 'cricket_scoring_screen.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/storage/local_storage.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/constants/api_constants.dart';
import '../../../../core/widgets/share_link_sheet.dart';
import '../../../../service_locator.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../auth/presentation/bloc/auth_state.dart';
import 'package:fyc_connect/core/l10n/tr.dart';
import 'create_tournament_screen.dart';
import '../widgets/edit_team_sheet.dart';

class SportsTournamentDetailScreen extends StatefulWidget {
  final String tournamentId;
  const SportsTournamentDetailScreen({super.key, required this.tournamentId});

  @override
  State<SportsTournamentDetailScreen> createState() =>
      _SportsTournamentDetailScreenState();
}

class _SportsTournamentDetailScreenState
    extends State<SportsTournamentDetailScreen> {
  late String _lang;

  @override
  void initState() {
    super.initState();
    _lang = sl<LocalStorage>().getLang();
    _reload();
  }

  void _reload() {
    context
        .read<SportsBloc>()
        .add(SportsTournamentSelected(widget.tournamentId));
  }

  bool get _isAdmin {
    final s = sl<AuthBloc>().state;
    return s is AuthAuthenticated && s.user.isAdmin;
  }

  bool get _isMember {
    final s = sl<AuthBloc>().state;
    return s is AuthAuthenticated && s.user.role == 'MEMBER';
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
          content: Text(trId('fixtures_generated')),
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
            title: Text(trId('registration_still_open')),
            content: Text(detail),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: Text(trId('wait')),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: Text(trId('close_early_generate')),
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
              trId('could_not_generate_need_2_approved_teams')),
          backgroundColor: AppColors.accent,
        ),
      );
    }
  }

  Future<void> _closeRegistration() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(trId('close_registration')),
        content: Text(trId('no_new_teams_can_register_after_this_you')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false),
              child: Text(trId('cancel_2'))),
          FilledButton(onPressed: () => Navigator.pop(ctx, true),
              child: Text(trId('close_registration_2'))),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      await sl<ApiClient>().dio.post(ApiConstants.sportsCloseRegistration(widget.tournamentId));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(trId('registration_closed')),
        backgroundColor: AppColors.primary,
      ));
      _reload();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(trId('could_not_close_registration')),
        backgroundColor: AppColors.accent,
      ));
    }
  }

  Future<void> _showAddFixtureSheet() async {
    final s = context.read<SportsBloc>().state;
    if (s is! SportsDetailLoaded) return;
    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.cBackground,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (_) => import_AddFixtureSheet.AddFixtureSheet(
        tournamentId: widget.tournamentId,
        teams: s.standings,
      ),
    );
    if (ok == true) _reload();
  }

  void _editFixture(FixtureEntity f, List<TeamEntity> teams) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => import_AddFixtureSheet.AddFixtureSheet(
        tournamentId: widget.tournamentId,
        teams: teams,
        fixture: f,
      ),
    ).then((val) {
      if (val == true) {
        _reload();
      }
    });
  }

  Future<void> _deleteFixture(FixtureEntity f) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(trId('delete_fixture')),
        content: Text(trId('are_you_sure_you_want_to_delete_this_fix')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(trId('cancel_2')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.danger),
            child: Text(trId('delete')),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await sl<ApiClient>().dio.delete(
          '${ApiConstants.sportsTournaments}/${widget.tournamentId}/fixtures/${f.id}',
        );
        _reload();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(trId('fixture_deleted_successfully')), backgroundColor: AppColors.success),
          );
        }
      } catch (_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(trId('failed_to_delete_fixture')), backgroundColor: AppColors.accent),
          );
        }
      }
    }
  }

  /// Friendly, localized label + color for the tournament's lifecycle phase.
  (String, Color) _phaseChip(TournamentEntity t) {
    switch (t.effectivePhase) {
      case 'REGISTRATION_OPEN':
        return (trId('registration_open'), const Color(0xFF12A150));
      case 'REGISTRATION_CLOSED':
        return (trId('registration_closed_2'), const Color(0xFFD97706));
      case 'ONGOING':
        return (trId('ongoing'),
            const Color(0xFF2563EB));
      case 'COMPLETED':
        return (trId('completed_3'),
            const Color(0xFF6B7280));
      default:
        return (t.status, const Color(0xFF0B6E4F));
    }
  }

  /// Build a plain-text scoreboard and open the share sheet (user picks
  /// WhatsApp etc.). Standings are already ranked by points → NRR.
  void _shareScoreboard(TournamentEntity t, List<TeamEntity> teams) {
    final b = StringBuffer();
    b.writeln('${t.nameEn} — ${trId('standings')}');
    b.writeln('');
    if (teams.isEmpty) {
      b.writeln(trId('no_teams_yet'));
    } else {
      var i = 1;
      for (final tm in teams) {
        final nrr = tm.netRunRate == null
            ? ''
            : '  NRR ${tm.netRunRate! >= 0 ? '+' : ''}${tm.netRunRate!.toStringAsFixed(2)}';
        final out = tm.eliminated ? ' (OUT)' : '';
        b.writeln('$i. ${tm.name}$out   ${tm.wins}W-${tm.losses}L   ${tm.points} pts$nrr');
        i++;
      }
    }
    b.writeln('');
    // Short, typeable link so recipients can open the tournament directly.
    if (t.shortCode != null && t.shortCode!.isNotEmpty) {
      b.writeln('🔗 ${ApiConstants.webBaseUrl}/t/${t.shortCode}');
      b.writeln('');
    }
    b.writeln('— FYC Connect');
    Share.share(b.toString(), subject: '${t.nameEn} — ${trId('scoreboard')}');
  }

  @override
  Widget build(BuildContext context) {
    final isAdmin = _isAdmin;
    final isMember = _isMember;
    return Scaffold(
      appBar: AppBar(
        title: Text(trId('tournament_2')),
        actions: [
          BlocBuilder<SportsBloc, SportsState>(
            builder: (context, state) {
              if (state is SportsDetailLoaded) {
                final code = state.tournament.shortCode;
                return Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (code != null && code.isNotEmpty)
                      IconButton(
                        icon: const Icon(Icons.qr_code_2),
                        tooltip: trId('share_link'),
                        onPressed: () => showShareLinkSheet(
                          context,
                          path: '/t/$code',
                          title: state.tournament.nameEn,
                        ),
                      ),
                    IconButton(
                      icon: const Icon(Icons.share_outlined),
                      tooltip: trId('share_scoreboard'),
                      onPressed: () => _shareScoreboard(state.tournament, state.standings),
                    ),
                  ],
                );
              }
              return const SizedBox.shrink();
            },
          ),
          if (isAdmin)
            BlocBuilder<SportsBloc, SportsState>(
              builder: (context, state) {
                if (state is SportsDetailLoaded) {
                  return IconButton(
                    icon: const Icon(Icons.edit),
                    onPressed: () async {
                      final res = await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => CreateTournamentScreen(tournament: state.tournament),
                        ),
                      );
                      if (res == true) {
                        _reload();
                      }
                    },
                  );
                }
                return const SizedBox.shrink();
              },
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
                          style: TextStyle(
                              color: AppColors.background,
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
                                color: AppColors.background.withValues(alpha: 0.18),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                '${state.tournament.sport} · ${state.tournament.year}',
                                style: TextStyle(
                                    color: AppColors.background,
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
                                  color: AppColors.background,
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
                    label: trId('fixtures'),
                  ),
                  if (state.fixtures.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Text(
                        trId('no_fixtures_scheduled'),
                        style: TextStyle(color: AppColors.textSecondary),
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
                          // Cricket fixtures stay openable after completion (to
                          // view + edit the scorecard anytime); other sports only
                          // while still live.
                          onEnterScore: (canScore && (isCricket || !f.isCompleted))
                              ? () => _enterScore(f)
                              : null,
                          onEditFixture: isAdmin ? () => _editFixture(f, state.standings) : null,
                          onDeleteFixture: isAdmin ? () => _deleteFixture(f) : null,
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
                          color: context.isDark ? AppColors.textSecondary.withValues(alpha: 0.9) : AppColors.textSecondary.withValues(alpha: 0.1),
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
                  
                  // Register: only while registration is open, OR if admin —
                  // but never once the tournament is completed.
                  if ((state.tournament.isRegistrationOpen || isAdmin) &&
                      !state.tournament.isTournamentCompleted)
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
                          icon: Icon(Icons.group_add, color: AppColors.background),
                          label: Text(trId('register_your_team'), style: TextStyle(color: AppColors.background, fontSize: 16, fontWeight: FontWeight.bold)),
                          style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                        ),
                      ),
                    ),

                  // Admin lifecycle actions: close registration → generate
                  // fixtures. Hidden once the tournament is completed.
                  if (isAdmin && !state.tournament.isTournamentCompleted)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 24),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: _generateFixtures,
                                  icon: Icon(Icons.auto_awesome_motion_outlined, color: AppColors.background),
                                  label: Text(
                                    trId('generate_fixtures'),
                                    style: TextStyle(color: AppColors.background, fontSize: 12, fontWeight: FontWeight.bold),
                                  ),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFFD97706),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                    padding: EdgeInsets.zero,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: _showAddFixtureSheet,
                                  icon: const Icon(Icons.add_circle_outline),
                                  label: Text(
                                    trId('add_fixture'),
                                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                                  ),
                                  style: OutlinedButton.styleFrom(
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                    padding: EdgeInsets.zero,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          if (state.tournament.isRegistrationOpen) ...[
                            const SizedBox(height: 12),
                            SizedBox(
                              width: double.infinity,
                              height: 48,
                              child: OutlinedButton.icon(
                                onPressed: _closeRegistration,
                                icon: const Icon(Icons.lock_clock_outlined),
                                label: Text(trId('close_registration_now')),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  
                  _SectionHeader(
                    label: trId('standings_2'),
                  ),
                  if (state.standings.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Text(
                        trId('no_teams_yet_2'),
                        style: TextStyle(color: AppColors.textSecondary),
                      ),
                    )
                  else
                    _StandingsTable(
                      teams: state.standings,
                      lang: _lang,
                      tournamentId: widget.tournamentId,
                      onTeamUpdated: _reload,
                    ),
                ],
              ),
            );
          }
          if (state is SportsFailure) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.error_outline, size: 48, color: AppColors.textSecondary),
                  const SizedBox(height: 12),
                  Text(state.message),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _reload,
                    child: Text(
                        trId('retry')),
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
        style: TextStyle(
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
  final VoidCallback? onEditFixture;
  final VoidCallback? onDeleteFixture;

  const _FixtureCard({
    required this.fixture,
    required this.lang,
    this.onEnterScore,
    this.onEditFixture,
    this.onDeleteFixture,
  });

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat('d MMM yyyy · h:mm a');
    final teamA = fixture.teamAName ?? (trId('team_a'));
    final teamB = fixture.teamBName ?? (trId('team_b'));
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
                    '${trId('match')}${fixture.matchNumber}',
                    style: TextStyle(
                        fontSize: 12, color: AppColors.textSecondary),
                  ),
                const Spacer(),
                _FixtureStatusBadge(fixture: fixture, lang: lang),
                if (onEditFixture != null || onDeleteFixture != null) ...[
                  const SizedBox(width: 8),
                  PopupMenuButton<String>(
                    icon: Icon(Icons.more_vert, size: 18, color: AppColors.textSecondary),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    onSelected: (val) {
                      if (val == 'edit' && onEditFixture != null) {
                        onEditFixture!();
                      } else if (val == 'delete' && onDeleteFixture != null) {
                        onDeleteFixture!();
                      }
                    },
                    itemBuilder: (context) => [
                      PopupMenuItem(
                        value: 'edit',
                        child: Row(
                          children: [
                            const Icon(Icons.edit, size: 16),
                            const SizedBox(width: 8),
                            Text(trId('edit_fixture'), style: const TextStyle(fontSize: 13)),
                          ],
                        ),
                      ),
                      PopupMenuItem(
                        value: 'delete',
                        child: Row(
                          children: [
                            Icon(Icons.delete, color: AppColors.danger, size: 16),
                            const SizedBox(width: 8),
                            Text(trId('delete'), style: TextStyle(color: AppColors.danger, fontSize: 13)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
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
                  Flexible(
                    child: Text(
                      '${fixture.teamAScore ?? '-'} : ${fixture.teamBScore ?? '-'}',
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      style: const TextStyle(
                          fontSize: 12.5, fontWeight: FontWeight.bold),
                    ),
                  )
                else
                  Text(
                    trId('vs_2'),
                    style: TextStyle(
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
            if (fixture.resultNotes != null && fixture.resultNotes!.trim().isNotEmpty) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.emoji_events_rounded, size: 15, color: AppColors.primary),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      fixture.resultNotes!,
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.primary),
                    ),
                  ),
                ],
              ),
            ],
            if (fixture.scheduledAt != null) ...[
              const SizedBox(height: 10),
              Row(
                children: [
                  Icon(Icons.schedule, size: 14, color: AppColors.textSecondary),
                  const SizedBox(width: 4),
                  Text(
                    fmt.format(fixture.scheduledAt!.toLocal()),
                    style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                  ),
                ],
              ),
            ],
            if (fixture.venue != null && fixture.venue!.isNotEmpty) ...[
              const SizedBox(height: 6),
              Row(
                children: [
                  Icon(Icons.place, size: 14, color: AppColors.textSecondary),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      fixture.venue!,
                      style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
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
                style: TextStyle(
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
                  icon: Icon(fixture.isCompleted ? Icons.scoreboard_outlined : Icons.bolt_rounded, size: 16),
                  label: Text(fixture.isCompleted
                      ? trId('view_edit_scorecard')
                      : trId('enter_live_score')),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    side: BorderSide(color: AppColors.primary.withValues(alpha: 0.5)),
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
        style: TextStyle(
          color: AppColors.background,
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
  final String tournamentId;
  final VoidCallback onTeamUpdated;

  const _StandingsTable({
    required this.teams,
    required this.lang,
    required this.tournamentId,
    required this.onTeamUpdated,
  });

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
                      trId('team'),
                      style: TextStyle(
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
            ...teams.map((t) => _StandingsRow(
                  team: t,
                  lang: lang,
                  tournamentId: tournamentId,
                  onTeamUpdated: onTeamUpdated,
                )),
          ],
        ),
      ),
    );
  }

  List<Widget> _headerCells() {
    Widget h(String l, {int flex = 1}) => Expanded(
          flex: flex,
          child: Text(
            l,
            textAlign: TextAlign.center,
            style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: AppColors.textSecondary),
          ),
        );
    // NRR is wider (e.g. "+10.20") so it gets extra flex.
    return [h('P'), h('W'), h('L'), h('D'), h('Pts'), h('NRR', flex: 2)];
  }
}

class _StandingsRow extends StatelessWidget {
  final TeamEntity team;
  final String lang;
  final String tournamentId;
  final VoidCallback onTeamUpdated;

  const _StandingsRow({
    required this.team,
    required this.lang,
    required this.tournamentId,
    required this.onTeamUpdated,
  });

  @override
  Widget build(BuildContext context) {
    final authState = sl<AuthBloc>().state;
    final isAdmin = authState is AuthAuthenticated && authState.user.isAdmin;

    Widget content = Container(
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
                      color: team.eliminated
                          ? AppColors.textSecondary
                          : (team.isFycTeam ? AppColors.primary : null),
                      decoration: team.eliminated ? TextDecoration.lineThrough : null,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (team.eliminated)
                  Container(
                    margin: const EdgeInsets.only(left: 6),
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                    decoration: BoxDecoration(
                      color: AppColors.accent.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      trId('out'),
                      style: TextStyle(
                          fontSize: 9, fontWeight: FontWeight.w800, color: AppColors.accent),
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
          _cell(_fmtNrr(team.netRunRate), flex: 2),
        ],
      ),
    );

    if (isAdmin) {
      return InkWell(
        onTap: () {
          showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            backgroundColor: Colors.transparent,
            builder: (_) => EditTeamSheet(
              tournamentId: tournamentId,
              team: team,
              onTeamUpdated: onTeamUpdated,
            ),
          );
        },
        child: content,
      );
    }
    return content;
  }

  Widget _cell(String text, {bool bold = false, int flex = 1}) {
    return Expanded(
      flex: flex,
      child: Text(
        text,
        textAlign: TextAlign.center,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: 13,
          fontWeight: bold ? FontWeight.bold : FontWeight.normal,
        ),
      ),
    );
  }

  String _fmtNrr(double? v) {
    // Signed, 2 decimals; em dash until a team has a completed result.
    if (v == null) return '—';
    return (v >= 0 ? '+' : '') + v.toStringAsFixed(2);
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
            trId('no_details_available_yet'),
            style: TextStyle(fontSize: 16, color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}
