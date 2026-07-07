import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/l10n/tr.dart';
import '../../../../service_locator.dart';
import '../../domain/entities/cricket_match_state_entity.dart';
import '../../domain/entities/fixture_entity.dart';
import '../../domain/entities/player_entity.dart';
import '../../domain/repositories/sports_repository.dart';
import '../bloc/cricket_scoring_cubit.dart';

/// Full ball-by-ball cricket scorer for admins/managers.
///
/// Lifecycle: toss + openers form → live scoring pad (runs, extras, wickets,
/// undo, strike rotation, over-end bowler picker) → innings break → second
/// innings → completed result. Player UUIDs come from the backend
/// (init/second-innings responses); the scorer only ever types NAMES.
class CricketScoringScreen extends StatelessWidget {
  final FixtureEntity fixture;

  const CricketScoringScreen({super.key, required this.fixture});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) =>
          CricketScoringCubit(sl<SportsRepository>(), fixture.id)..load(),
      child: _CricketScoringView(fixture: fixture),
    );
  }
}

class _CricketScoringView extends StatelessWidget {
  final FixtureEntity fixture;
  const _CricketScoringView({required this.fixture});

  String _teamName(String? teamId) {
    if (teamId == fixture.teamAId) return fixture.teamAName ?? 'Team A';
    if (teamId == fixture.teamBId) return fixture.teamBName ?? 'Team B';
    return '—';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          '${fixture.teamAName ?? "Team A"} vs ${fixture.teamBName ?? "Team B"}',
          style: const TextStyle(fontSize: 16),
        ),
        actions: [
          BlocBuilder<CricketScoringCubit, CricketScoringState>(
            builder: (context, state) {
              if (state is CricketScoringLoaded && !state.matchState.isCompleted) {
                return TextButton.icon(
                  icon: const Icon(Icons.undo),
                  label: const Text('Undo Last Ball', style: TextStyle(fontWeight: FontWeight.bold)),
                  style: TextButton.styleFrom(foregroundColor: Theme.of(context).colorScheme.error),
                  onPressed: () async {
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text('Undo Last Ball?'),
                        content: const Text('Are you sure you want to revert the last scored ball?'),
                        actions: [
                          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Undo')),
                        ],
                      ),
                    );
                    if (confirm == true && context.mounted) {
                      context.read<CricketScoringCubit>().undoBall();
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Ball reverted')),
                      );
                    }
                  },
                );
              }
              return const SizedBox.shrink();
            },
          ),
        ],
      ),
      body: BlocConsumer<CricketScoringCubit, CricketScoringState>(
        listener: (context, state) {
          if (state is CricketScoringLoaded && state.errorMessage != null) {
            ScaffoldMessenger.of(context)
                .showSnackBar(SnackBar(content: Text(state.errorMessage!)));
          }
        },
        builder: (context, state) {
          if (state is CricketScoringLoading || state is CricketScoringInitial) {
            return const Center(child: CircularProgressIndicator());
          }
          if (state is CricketScoringFailure) {
            return _ErrorRetry(message: state.message);
          }
          if (state is CricketScoringNotInitialized) {
            return _TossSetupForm(fixture: fixture);
          }
          if (state is CricketScoringLoaded) {
            final ms = state.matchState;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _ScoreHeader(ms: ms, teamName: _teamName),
                        const SizedBox(height: 12),
                        if (ms.isCompleted)
                          _ResultCard(ms: ms, teamName: _teamName)
                        else if (ms.isInningsBreak)
                          _SecondInningsForm(fixture: fixture, ms: ms, teamName: _teamName)
                        else if (state.players == null)
                          _ConfirmPlayersPanel(ms: ms)
                        else
                          const SizedBox.shrink(),
                        const SizedBox(height: 16),
                        _Scorecard(ms: ms),
                      ],
                    ),
                  ),
                ),
                if (!ms.isCompleted && !ms.isInningsBreak && state.players != null)
                  Container(
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surface,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 10,
                          offset: const Offset(0, -4),
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.only(left: 16, right: 16, bottom: 24, top: 12),
                    child: _ScoringPad(state: state),
                  ),
              ],
            );}
          return const SizedBox.shrink();
        },
      ),
    );
  }
}

class _ErrorRetry extends StatelessWidget {
  final String message;
  const _ErrorRetry({required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: () => context.read<CricketScoringCubit>().load(),
              child: Text(tr(en: 'Retry', ta: 'மீண்டும் முயற்சி',
                  hi: 'पुनः प्रयास करें', ml: 'വീണ്ടും ശ്രമിക്കുക')),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Toss + openers ───────────────────────────────────────────────────

class _TossSetupForm extends StatefulWidget {
  final FixtureEntity fixture;
  const _TossSetupForm({required this.fixture});

  @override
  State<_TossSetupForm> createState() => _TossSetupFormState();
}

class _TossSetupFormState extends State<_TossSetupForm> {
  String? _tossWinnerId;
  String _decision = 'BAT';
  final _overs = TextEditingController(text: '20');
  final _striker = TextEditingController();
  final _nonStriker = TextEditingController();
  final _bowler = TextEditingController();

  @override
  void dispose() {
    _overs.dispose();
    _striker.dispose();
    _nonStriker.dispose();
    _bowler.dispose();
    super.dispose();
  }

  bool get _valid =>
      _tossWinnerId != null &&
      (int.tryParse(_overs.text) ?? 0) > 0 &&
      _striker.text.trim().isNotEmpty &&
      _nonStriker.text.trim().isNotEmpty &&
      _bowler.text.trim().isNotEmpty;

  @override
  Widget build(BuildContext context) {
    final f = widget.fixture;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            tr(en: 'Start match', ta: 'போட்டியைத் தொடங்கு',
                hi: 'मैच शुरू करें', ml: 'മത്സരം ആരംഭിക്കുക'),
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 16),
          Text(tr(en: 'Toss won by', ta: 'டாஸ் வென்றது',
              hi: 'टॉस जीता', ml: 'ടോസ് നേടിയത്')),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              ChoiceChip(
                label: Text(f.teamAName ?? 'Team A'),
                selected: _tossWinnerId == f.teamAId,
                onSelected: (_) => setState(() => _tossWinnerId = f.teamAId),
              ),
              ChoiceChip(
                label: Text(f.teamBName ?? 'Team B'),
                selected: _tossWinnerId == f.teamBId,
                onSelected: (_) => setState(() => _tossWinnerId = f.teamBId),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(tr(en: 'Decision', ta: 'முடிவு', hi: 'निर्णय', ml: 'തീരുമാനം')),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              ChoiceChip(
                label: Text(tr(en: 'Bat', ta: 'பேட்டிங்', hi: 'बल्लेबाज़ी', ml: 'ബാറ്റിംഗ്')),
                selected: _decision == 'BAT',
                onSelected: (_) => setState(() => _decision = 'BAT'),
              ),
              ChoiceChip(
                label: Text(tr(en: 'Bowl', ta: 'பந்துவீச்சு', hi: 'गेंदबाज़ी', ml: 'ബൗളിംഗ്')),
                selected: _decision == 'BOWL',
                onSelected: (_) => setState(() => _decision = 'BOWL'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _overs,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: tr(en: 'Overs per innings', ta: 'ஓவர்கள்',
                  hi: 'ओवर', ml: 'ഓവറുകൾ'),
              border: const OutlineInputBorder(),
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _striker,
            decoration: InputDecoration(
              labelText: tr(en: 'Striker name', ta: 'ஸ்ட்ரைக்கர் பெயர்',
                  hi: 'स्ट्राइकर का नाम', ml: 'സ്ട്രൈക്കർ പേര്'),
              border: const OutlineInputBorder(),
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _nonStriker,
            decoration: InputDecoration(
              labelText: tr(en: 'Non-striker name', ta: 'நான்-ஸ்ட்ரைக்கர் பெயர்',
                  hi: 'नॉन-स्ट्राइकर का नाम', ml: 'നോൺ-സ്ട്രൈക്കർ പേര്'),
              border: const OutlineInputBorder(),
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _bowler,
            decoration: InputDecoration(
              labelText: tr(en: 'Opening bowler name', ta: 'தொடக்க பந்துவீச்சாளர்',
                  hi: 'गेंदबाज़ का नाम', ml: 'ഓപ്പണിംഗ് ബൗളർ'),
              border: const OutlineInputBorder(),
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: _valid
                ? () => context.read<CricketScoringCubit>().initMatch(
                      tossWinnerId: _tossWinnerId!,
                      tossDecision: _decision,
                      overs: int.parse(_overs.text),
                      strikerName: _striker.text,
                      nonStrikerName: _nonStriker.text,
                      bowlerName: _bowler.text,
                    )
                : null,
            child: Text(tr(en: 'Start scoring', ta: 'ஸ்கோரிங் தொடங்கு',
                hi: 'स्कोरिंग शुरू करें', ml: 'സ്കോറിംഗ് ആരംഭിക്കുക')),
          ),
        ],
      ),
    );
  }
}

// ── Score header ─────────────────────────────────────────────────────

class _ScoreHeader extends StatelessWidget {
  final CricketMatchStateEntity ms;
  final String Function(String?) teamName;
  const _ScoreHeader({required this.ms, required this.teamName});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final needed = ms.target != null ? ms.target! - ms.score : null;
    final ballsFaced = (ms.overs * 6) + ms.balls;
    final rr = ballsFaced > 0 ? (ms.score / ballsFaced) * 6 : 0.0;
    
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.shield, size: 28, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  teamName(ms.battingTeamId).toUpperCase(),
                  style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold, letterSpacing: 1.2),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              '${ms.score}/${ms.wickets}',
              style: theme.textTheme.displayLarge?.copyWith(
                fontWeight: FontWeight.w900,
                fontSize: 72,
                height: 1.0,
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Overs ${ms.oversText}',
                  style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(width: 16),
                Text(
                  'CRR ${rr.toStringAsFixed(1)}',
                  style: theme.textTheme.titleMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceVariant,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                'Innings ${ms.innings}',
                style: theme.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.bold),
              ),
            ),
            if (ms.target != null && !ms.isCompleted) ...[
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 8),
              Text(
                'Need ${needed! > 0 ? needed : 0} runs',
                style: theme.textTheme.titleLarge?.copyWith(
                  color: theme.colorScheme.error,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Target ${ms.target}',
                style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
            ],
            if (ms.recentBalls.isNotEmpty) ...[
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: ms.recentBalls.skip(ms.recentBalls.length > 8 ? ms.recentBalls.length - 8 : 0).map((b) => Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Container(
                    width: 32,
                    height: 32,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: b == 'W' ? theme.colorScheme.error : (b.contains('w') || b.contains('n') ? theme.colorScheme.tertiary : theme.colorScheme.surface),
                      shape: BoxShape.circle,
                      border: Border.all(color: theme.colorScheme.outlineVariant),
                    ),
                    child: Text(
                      b,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: b == 'W' ? theme.colorScheme.onError : (b.contains('w') || b.contains('n') ? theme.colorScheme.onTertiary : theme.colorScheme.onSurface),
                      ),
                    ),
                  ),
                )).toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ── Result ───────────────────────────────────────────────────────────

class _ResultCard extends StatelessWidget {
  final CricketMatchStateEntity ms;
  final String Function(String?) teamName;
  const _ResultCard({required this.ms, required this.teamName});

  String _resultText() {
    if (ms.target == null) {
      return tr(en: 'Match completed', ta: 'போட்டி முடிந்தது',
          hi: 'मैच समाप्त', ml: 'മത്സരം പൂർത്തിയായി');
    }
    if (ms.score >= ms.target!) {
      final byWkts = 10 - ms.wickets;
      final name = teamName(ms.battingTeamId);
      return tr(
        en: '$name won by $byWkts wickets',
        ta: '$name $byWkts விக்கெட்டுகளால் வென்றது',
        hi: '$name $byWkts विकेट से जीता',
        ml: '$name $byWkts വിക്കറ്റിന് ജയിച്ചു',
      );
    }
    if (ms.score == ms.target! - 1) {
      return tr(en: 'Match tied', ta: 'போட்டி சமன்', hi: 'मैच टाई', ml: 'മത്സരം സമനില');
    }
    final byRuns = ms.target! - 1 - ms.score;
    final name = teamName(ms.bowlingTeamId);
    return tr(
      en: '$name won by $byRuns runs',
      ta: '$name $byRuns ரன்களால் வென்றது',
      hi: '$name $byRuns रन से जीता',
      ml: '$name $byRuns റൺസിന് ജയിച്ചു',
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      color: theme.colorScheme.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const Icon(Icons.emoji_events, size: 40),
            const SizedBox(height: 8),
            Text(
              _resultText(),
              textAlign: TextAlign.center,
              style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Innings break → second innings ───────────────────────────────────

class _SecondInningsForm extends StatefulWidget {
  final FixtureEntity fixture;
  final CricketMatchStateEntity ms;
  final String Function(String?) teamName;
  const _SecondInningsForm({required this.fixture, required this.ms, required this.teamName});

  @override
  State<_SecondInningsForm> createState() => _SecondInningsFormState();
}

class _SecondInningsFormState extends State<_SecondInningsForm> {
  final _striker = TextEditingController();
  final _nonStriker = TextEditingController();
  final _bowler = TextEditingController();

  @override
  void dispose() {
    _striker.dispose();
    _nonStriker.dispose();
    _bowler.dispose();
    super.dispose();
  }

  bool get _valid =>
      _striker.text.trim().isNotEmpty &&
      _nonStriker.text.trim().isNotEmpty &&
      _bowler.text.trim().isNotEmpty;

  @override
  Widget build(BuildContext context) {
    // At innings break, batting/bowling team ids still refer to innings 1;
    // the chasing side is the current BOWLING team.
    final chasing = widget.teamName(widget.ms.bowlingTeamId);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              tr(en: 'Innings break', ta: 'இன்னிங்ஸ் இடைவேளை',
                  hi: 'पारी विश्राम', ml: 'ഇന്നിംഗ്സ് ഇടവേള'),
              style: Theme.of(context).textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Text(
              tr(
                en: '$chasing needs ${widget.ms.score + 1} to win',
                ta: '$chasing வெல்ல ${widget.ms.score + 1} ரன்கள் தேவை',
                hi: '$chasing को जीतने के लिए ${widget.ms.score + 1} रन चाहिए',
                ml: '$chasing ജയിക്കാൻ ${widget.ms.score + 1} റൺസ് വേണം',
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _striker,
              decoration: InputDecoration(
                labelText: tr(en: 'Striker name', ta: 'ஸ்ட்ரைக்கர் பெயர்',
                    hi: 'स्ट्राइकर का नाम', ml: 'സ്ട്രൈക്കർ പേര്'),
                border: const OutlineInputBorder(),
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _nonStriker,
              decoration: InputDecoration(
                labelText: tr(en: 'Non-striker name', ta: 'நான்-ஸ்ட்ரைக்கர் பெயர்',
                    hi: 'नॉन-स्ट्राइकर का नाम', ml: 'നോൺ-സ്ട്രൈക്കർ പേര്'),
                border: const OutlineInputBorder(),
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _bowler,
              decoration: InputDecoration(
                labelText: tr(en: 'Opening bowler name', ta: 'தொடக்க பந்துவீச்சாளர்',
                    hi: 'गेंदबाज़ का नाम', ml: 'ഓപ്പണിംഗ് ബൗളർ'),
                border: const OutlineInputBorder(),
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _valid
                  ? () => context.read<CricketScoringCubit>().startSecondInnings(
                        strikerName: _striker.text,
                        nonStrikerName: _nonStriker.text,
                        bowlerName: _bowler.text,
                        anyTeamId: widget.fixture.teamAId,
                      )
                  : null,
              child: Text(tr(en: 'Start 2nd innings', ta: '2-வது இன்னிங்ஸ் தொடங்கு',
                  hi: 'दूसरी पारी शुरू करें', ml: 'രണ്ടാം ഇന്നിംഗ്സ് ആരംഭിക്കുക')),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Confirm current players (resume mid-match) ───────────────────────

class _ConfirmPlayersPanel extends StatefulWidget {
  final CricketMatchStateEntity ms;
  const _ConfirmPlayersPanel({required this.ms});

  @override
  State<_ConfirmPlayersPanel> createState() => _ConfirmPlayersPanelState();
}

class _ConfirmPlayersPanelState extends State<_ConfirmPlayersPanel> {
  String? _strikerId;
  String? _nonStrikerId;
  String? _bowlerId;
  List<PlayerEntity> _battingSquad = [];
  List<PlayerEntity> _bowlingSquad = [];
  bool _loadingSquads = true;

  @override
  void initState() {
    super.initState();
    _loadSquads();
  }

  Future<void> _loadSquads() async {
    final repo = sl<SportsRepository>();
    final ms = widget.ms;
    if (ms.battingTeamId != null) {
      (await repo.fetchTeamPlayers(ms.battingTeamId!))
          .fold((_) {}, (players) => _battingSquad = players);
    }
    if (ms.bowlingTeamId != null) {
      (await repo.fetchTeamPlayers(ms.bowlingTeamId!))
          .fold((_) {}, (players) => _bowlingSquad = players);
    }
    if (mounted) setState(() => _loadingSquads = false);
  }

  String _nameOf(String id) {
    for (final b in widget.ms.batters) {
      if (b.id == id) return b.name;
    }
    for (final b in widget.ms.bowlers) {
      if (b.id == id) return b.name;
    }
    for (final p in [..._battingSquad, ..._bowlingSquad]) {
      if (p.id == id) return p.name;
    }
    return '';
  }

  @override
  Widget build(BuildContext context) {
    if (_loadingSquads) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Center(child: CircularProgressIndicator()),
        ),
      );
    }

    final ms = widget.ms;
    // Batting options: not-out batters first, then rest of the squad.
    final outIds = ms.batters.where((b) => b.out).map((b) => b.id).toSet();
    final seen = <String>{};
    final battingOptions = <MapEntry<String, String>>[];
    for (final b in ms.batters.where((b) => !b.out)) {
      if (seen.add(b.id)) battingOptions.add(MapEntry(b.id, b.name));
    }
    for (final p in _battingSquad) {
      if (!outIds.contains(p.id) && seen.add(p.id)) {
        battingOptions.add(MapEntry(p.id, p.name));
      }
    }
    final bowlerSeen = <String>{};
    final bowlingOptions = <MapEntry<String, String>>[];
    for (final b in ms.bowlers) {
      if (bowlerSeen.add(b.id)) bowlingOptions.add(MapEntry(b.id, b.name));
    }
    for (final p in _bowlingSquad) {
      if (bowlerSeen.add(p.id)) bowlingOptions.add(MapEntry(p.id, p.name));
    }

    Widget chips(List<MapEntry<String, String>> options, String? selected,
        void Function(String) onPick, {Set<String> disabled = const {}}) {
      return Wrap(
        spacing: 8,
        runSpacing: 4,
        children: options
            .map((o) => ChoiceChip(
                  label: Text(o.value),
                  selected: selected == o.key,
                  onSelected: disabled.contains(o.key) ? null : (_) => setState(() => onPick(o.key)),
                ))
            .toList(),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              tr(en: 'Confirm current players', ta: 'தற்போதைய வீரர்களை உறுதிசெய்க',
                  hi: 'वर्तमान खिलाड़ी चुनें', ml: 'നിലവിലെ കളിക്കാരെ സ്ഥിരീകരിക്കുക'),
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            Text(tr(en: 'Striker', ta: 'ஸ்ட்ரைக்கர்', hi: 'स्ट्राइकर', ml: 'സ്ട്രൈക്കർ')),
            const SizedBox(height: 4),
            chips(battingOptions, _strikerId, (id) => _strikerId = id,
                disabled: {if (_nonStrikerId != null) _nonStrikerId!}),
            const SizedBox(height: 12),
            Text(tr(en: 'Non-striker', ta: 'நான்-ஸ்ட்ரைக்கர்',
                hi: 'नॉन-स्ट्राइकर', ml: 'നോൺ-സ്ട്രൈക്കർ')),
            const SizedBox(height: 4),
            chips(battingOptions, _nonStrikerId, (id) => _nonStrikerId = id,
                disabled: {if (_strikerId != null) _strikerId!}),
            const SizedBox(height: 12),
            Text(tr(en: 'Bowler', ta: 'பந்துவீச்சாளர்', hi: 'गेंदबाज़', ml: 'ബൗളർ')),
            const SizedBox(height: 4),
            chips(bowlingOptions, _bowlerId, (id) => _bowlerId = id),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: (_strikerId != null &&
                      _nonStrikerId != null &&
                      _bowlerId != null &&
                      _strikerId != _nonStrikerId)
                  ? () => context.read<CricketScoringCubit>().setPlayers(
                        CricketPlayersEntity(
                          strikerId: _strikerId!,
                          nonStrikerId: _nonStrikerId!,
                          bowlerId: _bowlerId!,
                          strikerName: _nameOf(_strikerId!),
                          nonStrikerName: _nameOf(_nonStrikerId!),
                          bowlerName: _nameOf(_bowlerId!),
                        ),
                      )
                  : null,
              child: Text(tr(en: 'Continue scoring', ta: 'ஸ்கோரிங் தொடர்க',
                  hi: 'स्कोरिंग जारी रखें', ml: 'സ്കോറിംഗ് തുടരുക')),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Live scoring pad ─────────────────────────────────────────────────

class _ScoringPad extends StatelessWidget {
  final CricketScoringLoaded state;
  const _ScoringPad({required this.state});

  @override
  Widget build(BuildContext context) {
    final players = state.players!;
    final cubit = context.read<CricketScoringCubit>();
    final theme = Theme.of(context);

    // Find stats
    final strikerStats = state.matchState.batters.firstWhere((b) => b.id == players.strikerId, orElse: () => CricketBatterEntity(id: '', name: players.strikerName, runs: 0, balls: 0, fours: 0, sixes: 0, out: false));
    final nonStrikerStats = state.matchState.batters.firstWhere((b) => b.id == players.nonStrikerId, orElse: () => CricketBatterEntity(id: '', name: players.nonStrikerName, runs: 0, balls: 0, fours: 0, sixes: 0, out: false));
    final bowlerStats = state.matchState.bowlers.firstWhere((b) => b.id == players.bowlerId, orElse: () => CricketBowlerEntity(id: '', name: players.bowlerName, legalBalls: 0, runs: 0, wickets: 0));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Batter Card Row
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('🏏 ${strikerStats.name} *    ${strikerStats.runs}(${strikerStats.balls})',
                      style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold, color: theme.colorScheme.primary)),
                  const SizedBox(height: 4),
                  Text('🏏 ${nonStrikerStats.name}      ${nonStrikerStats.runs}(${nonStrikerStats.balls})',
                      style: theme.textTheme.bodyMedium),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.swap_vert, size: 28),
              onPressed: cubit.swapStrike,
              style: IconButton.styleFrom(backgroundColor: theme.colorScheme.secondaryContainer),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('🎯 ${bowlerStats.name}', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text('${bowlerStats.oversText}-${bowlerStats.runs}-${bowlerStats.wickets}',
                      style: theme.textTheme.bodyMedium),
                ],
              ),
            ),
          ],
        ),
        if (state.needsNewBowler)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: theme.colorScheme.tertiaryContainer, borderRadius: BorderRadius.circular(12)),
              child: const Text('Over complete — the next ball will ask for the new bowler.', style: TextStyle(fontWeight: FontWeight.w500)),
            ),
          ),
        const SizedBox(height: 16),
        // Ball controls
        Row(
          children: [0, 1, 2, 3, 4, 6].map((runs) {
            final isBoundary = runs == 4 || runs == 6;
            final isDot = runs == 0;
            return Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    padding: EdgeInsets.zero,
                    backgroundColor: isBoundary ? theme.colorScheme.primary : (isDot ? theme.colorScheme.surfaceVariant : theme.colorScheme.secondary),
                    foregroundColor: isBoundary ? theme.colorScheme.onPrimary : (isDot ? theme.colorScheme.onSurfaceVariant : theme.colorScheme.onSecondary),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    minimumSize: const Size(0, 56),
                  ),
                  onPressed: () => _withBowlerIfNeeded(context, (newBowlerName) => cubit.scoreBall(runsBatter: runs, newBowlerName: newBowlerName)),
                  child: Text('$runs', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            _actionBtn(context, 'Wide', () => _extrasDialog(context, 'WIDE')),
            const SizedBox(width: 8),
            _actionBtn(context, 'No Ball', () => _extrasDialog(context, 'NO_BALL')),
            const SizedBox(width: 8),
            _actionBtn(context, 'Bye', () => _extrasDialog(context, 'BYE')),
            const SizedBox(width: 8),
            _actionBtn(context, 'Leg Bye', () => _extrasDialog(context, 'LEG_BYE')),
          ],
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 56,
          child: FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: theme.colorScheme.error,
              foregroundColor: theme.colorScheme.onError,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
            onPressed: () => _wicketDialog(context),
            child: const Text('WICKET', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
          ),
        ),
      ],
    );
  }

  Widget _actionBtn(BuildContext context, String label, VoidCallback onTap) {
    return Expanded(
      child: OutlinedButton(
        style: OutlinedButton.styleFrom(
          padding: EdgeInsets.zero,
          minimumSize: const Size(0, 48),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        onPressed: onTap,
        child: Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
      ),
    );
  }

  Future<void> _withBowlerIfNeeded(
      BuildContext context, Future<void> Function(String?) send) async {
    final cubit = context.read<CricketScoringCubit>();
    if (!state.needsNewBowler) {
      await send(null);
      return;
    }
    final ms = state.matchState;
    final currentBowlerId = state.players!.bowlerId;
    final options = ms.bowlers.where((b) => b.id != currentBowlerId).toList();
    final nameCtrl = TextEditingController();

    final choice = await showDialog<(String?, String?)>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(tr(en: 'Next bowler', ta: 'அடுத்த பந்துவீச்சாளர்', hi: 'अगला गेंदबाज़', ml: 'അടുത്ത ബൗളർ')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 8,
              children: options
                  .map((b) => ActionChip(
                        label: Text(b.name),
                        onPressed: () => Navigator.pop(ctx, (b.id, b.name)),
                      ))
                  .toList(),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: nameCtrl,
              decoration: InputDecoration(
                labelText: tr(en: 'Or new bowler name', ta: 'அல்லது புதிய பெயர்', hi: 'या नया नाम', ml: 'അല്ലെങ്കിൽ പുതിയ പേര്'),
                border: const OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(tr(en: 'Cancel', ta: 'ரத்து', hi: 'रद्द करें', ml: 'റദ്ദാക്കുക')),
          ),
          FilledButton(
            onPressed: () {
              if (nameCtrl.text.trim().isNotEmpty) {
                Navigator.pop(ctx, (null, nameCtrl.text.trim()));
              }
            },
            child: Text(tr(en: 'OK', ta: 'சரி', hi: 'ठीक है', ml: 'ശരി')),
          ),
        ],
      ),
    );
    if (choice == null) return;
    final (existingId, name) = choice;
    if (existingId != null) {
      cubit.chooseBowler(existingId, name!);
      await send(null);
    } else {
      await send(name);
    }
  }

  Future<void> _extrasDialog(BuildContext context, String type) async {
    final cubit = context.read<CricketScoringCubit>();
    
    // Instead of nested dialog, we just show a quick bottom sheet or inline dialog for number of runs
    int runs = 1;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text('$type Runs'),
          content: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [1, 2, 3, 4, 5].map((r) => InkWell(
              onTap: () {
                setDialogState(() => runs = r);
              },
              child: Container(
                width: 48,
                height: 48,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: runs == r ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.surfaceVariant,
                  shape: BoxShape.circle,
                ),
                child: Text('$r', style: TextStyle(
                  color: runs == r ? Theme.of(context).colorScheme.onPrimary : Theme.of(context).colorScheme.onSurfaceVariant,
                  fontSize: 18, fontWeight: FontWeight.bold
                )),
              ),
            )).toList(),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Confirm'),
            ),
          ],
        ),
      ),
    );
    if (confirmed != true) return;
    if (type == 'NO_BALL' || type == 'WIDE') {
      final extraRuns = type == 'WIDE' ? runs - 1 : runs;
      await _withBowlerIfNeeded(context, (nb) => cubit.scoreBall(extrasType: type, extrasRuns: extraRuns, newBowlerName: nb));
    } else {
      await _withBowlerIfNeeded(context, (nb) => cubit.scoreBall(extrasType: type, extrasRuns: runs, newBowlerName: nb));
    }
  }

  Future<void> _wicketDialog(BuildContext context) async {
    final cubit = context.read<CricketScoringCubit>();
    final players = state.players!;
    String wicketType = 'BOWLED';
    String dismissedId = players.strikerId;
    final newBatter = TextEditingController();
    final lastWicket = state.matchState.wickets >= 9;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text(tr(en: 'Wicket', ta: 'விக்கெட்', hi: 'विकेट', ml: 'വിക്കറ്റ്')),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                DropdownButtonFormField<String>(
                  value: wicketType,
                  decoration: const InputDecoration(border: OutlineInputBorder()),
                  items: const [
                    DropdownMenuItem(value: 'BOWLED', child: Text('Bowled')),
                    DropdownMenuItem(value: 'CAUGHT', child: Text('Caught')),
                    DropdownMenuItem(value: 'LBW', child: Text('LBW')),
                    DropdownMenuItem(value: 'STUMPED', child: Text('Stumped')),
                    DropdownMenuItem(value: 'RUN_OUT', child: Text('Run out')),
                    DropdownMenuItem(value: 'HIT_WICKET', child: Text('Hit wicket')),
                  ],
                  onChanged: (v) => setDialogState(() => wicketType = v ?? 'BOWLED'),
                ),
                const SizedBox(height: 16),
                const Text('Who is out?', style: TextStyle(fontWeight: FontWeight.bold)),
                RadioListTile<String>(
                  dense: true,
                  title: Text('${players.strikerName} *'),
                  value: players.strikerId,
                  groupValue: dismissedId,
                  onChanged: (v) => setDialogState(() => dismissedId = v!),
                ),
                RadioListTile<String>(
                  dense: true,
                  title: Text(players.nonStrikerName),
                  value: players.nonStrikerId,
                  groupValue: dismissedId,
                  onChanged: (v) => setDialogState(() => dismissedId = v!),
                ),
                if (!lastWicket) ...[
                  const SizedBox(height: 16),
                  TextField(
                    controller: newBatter,
                    decoration: const InputDecoration(
                      labelText: 'New batter name',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.error),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Confirm Wicket'),
            ),
          ],
        ),
      ),
    );
    if (confirmed != true) return;
    await _withBowlerIfNeeded(
      context,
      (nb) => cubit.scoreBall(
        isWicket: true,
        wicketType: wicketType,
        playerDismissedId: dismissedId,
        newBatterName: lastWicket ? null : newBatter.text,
        newBowlerName: nb,
      ),
    );
  }
}

// ── Scorecard ────────────────────────────────────────────────────────

class _Scorecard extends StatelessWidget {
  final CricketMatchStateEntity ms;
  const _Scorecard({required this.ms});

  @override
  Widget build(BuildContext context) {
    if (ms.batters.isEmpty && ms.bowlers.isEmpty) return const SizedBox.shrink();
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(tr(en: 'Batting', ta: 'பேட்டிங்', hi: 'बल्लेबाज़ी', ml: 'ബാറ്റിംഗ്'),
                style: theme.textTheme.titleSmall),
            const SizedBox(height: 4),
            ...ms.batters.map((b) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          b.out ? '${b.name} (out)' : b.name,
                          style: b.out
                              ? TextStyle(color: theme.colorScheme.outline)
                              : null,
                        ),
                      ),
                      Text('${b.runs} (${b.balls})  4s:${b.fours} 6s:${b.sixes}'),
                    ],
                  ),
                )),
            if (ms.extrasTotal > 0)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(
                  '${tr(en: 'Extras', ta: 'எக்ஸ்ட்ராஸ்', hi: 'अतिरिक्त', ml: 'എക്സ്ട്രാസ്')}: ${ms.extrasTotal}',
                  style: theme.textTheme.bodySmall,
                ),
              ),
            const Divider(),
            Text(tr(en: 'Bowling', ta: 'பந்துவீச்சு', hi: 'गेंदबाज़ी', ml: 'ബൗളിംഗ്'),
                style: theme.textTheme.titleSmall),
            const SizedBox(height: 4),
            ...ms.bowlers.map((b) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Row(
                    children: [
                      Expanded(child: Text(b.name)),
                      Text('${b.oversText} ov · ${b.runs}r · ${b.wickets}w'),
                    ],
                  ),
                )),
          ],
        ),
      ),
    );
  }
}
