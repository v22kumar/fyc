import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/l10n/tr.dart';
import '../../../../service_locator.dart';
import '../../domain/entities/cricket_match_state_entity.dart';
import '../../domain/entities/fixture_entity.dart';
import '../../domain/entities/player_entity.dart';
import '../../domain/repositories/sports_repository.dart';
import '../bloc/cricket_scoring_cubit.dart';
import '../widgets/cricket_overs_history.dart';
import '../../../../core/widgets/pressable.dart';

/// Brand colors shared across this screen's gradients (scoreboard hero, run
/// buttons, chips, CTAs) — defined once so a brand-color change never has to
/// hunt down repeated literals.

/// Two people at the crease (or two openers) must be distinct — names are
/// compared trimmed + case-insensitive because that's how the backend
/// resolves player identity (by team + name). If two different physical
/// players are typed with the same name, the backend would silently merge
/// them into one Player row and their stats would mirror each other.
bool _sameName(String a, String b) => a.trim().toLowerCase() == b.trim().toLowerCase();

/// A themed choice chip with explicit, always-legible colors (selected =
/// solid navy→mint fill + white label; unselected = tinted surface + navy
/// label; disabled = muted so it visibly differs from a selectable chip) —
/// the stock ChipThemeData left unselected labels nearly invisible.
Widget _themedChip(BuildContext context, {required String label, required bool selected, required VoidCallback? onSelected}) {
  final disabled = onSelected == null;
  return Pressable(
    child: InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: onSelected,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          gradient: selected ? const LinearGradient(colors: [AppColors.primary, AppColors.primaryLight]) : null,
          color: selected ? null : (disabled ? const Color(0xFFF5F6FA) : const Color(0xFFEFF2FA)),
          borderRadius: BorderRadius.circular(999),
          border: selected ? null : Border.all(color: disabled ? const Color(0xFFE8EBF2) : const Color(0xFFD7DCEA)),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13.5,
            fontWeight: FontWeight.w700,
            color: selected ? Colors.white : (disabled ? const Color(0xFFB4B9C8) : const Color(0xFF0A1128)),
          ),
        ),
      ),
    ),
  );
}

/// The primary call-to-action for the setup/resume flows: a gradient,
/// press-responsive button matching the scoreboard/run-button language
/// shipped elsewhere in this screen, instead of a flat stock FilledButton.
Widget _gradientCTA({required String label, required VoidCallback? onPressed, IconData? icon}) {
  final enabled = onPressed != null;
  return Pressable(
    child: Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onPressed,
        child: Container(
          height: 54,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: enabled
                  ? const [AppColors.primary, AppColors.primaryLight]
                  : const [Color(0xFFAEB4C4), Color(0xFFAEB4C4)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: enabled
                ? [BoxShadow(color: AppColors.primary.withOpacity(0.28), blurRadius: 16, offset: const Offset(0, 6))]
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (icon != null) ...[Icon(icon, color: Colors.white, size: 19), const SizedBox(width: 8)],
              Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 15.5)),
            ],
          ),
        ),
      ),
    ),
  );
}

/// Shows the "next bowler" picker (existing bowlers as chips + a free-text
/// field for a new one) and applies the choice to the cubit. Returns true if a
/// bowler was chosen, false if cancelled. Used both proactively at the over
/// break and as a fallback when the next ball is tapped without a bowler set.
Future<bool> _pickNextBowler(BuildContext context, CricketScoringLoaded state) async {
  final cubit = context.read<CricketScoringCubit>();
  final ms = state.matchState;
  final currentBowlerId = state.players?.bowlerId;
  // Offer the BOWLING team's roster — never the accumulated match-state bowlers,
  // which across an innings change can include players now on the batting side
  // (that produced the "Bowler does not belong to the bowling team" error).
  // Every option here is guaranteed to be a valid bowling-team player.
  final options = <MapEntry<String, String>>[];
  final seen = <String>{};
  if (ms.bowlingTeamId != null) {
    final res = await sl<SportsRepository>().fetchTeamPlayers(ms.bowlingTeamId!);
    if (!context.mounted) return false;
    res.fold((_) {}, (players) {
      for (final p in players) {
        if (p.id != currentBowlerId && p.name.trim().isNotEmpty && seen.add(p.id)) {
          options.add(MapEntry(p.id, p.name));
        }
      }
    });
  }
  // Fallback if the roster couldn't be loaded: bowlers already recorded this
  // innings (innings-scoped now that the backend resets the scorecard).
  if (options.isEmpty) {
    for (final b in ms.bowlers) {
      if (b.id != currentBowlerId && b.name.trim().isNotEmpty && seen.add(b.id)) {
        options.add(MapEntry(b.id, b.name));
      }
    }
  }
  final nameCtrl = TextEditingController();

  final choice = await showDialog<(String?, String?)>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(tr(en: 'Next bowler', ta: 'அடுத்த பந்துவீச்சாளர்', hi: 'अगला गेंदबाज़', ml: 'അടുത്ത ബൗളർ')),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            tr(en: 'Over complete — who bowls next?', ta: 'ஓவர் முடிந்தது — அடுத்து யார்?',
                hi: 'ओवर पूरा — अगला कौन?', ml: 'ഓവർ പൂർത്തിയായി — അടുത്തത് ആര്?'),
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF5B6478)),
          ),
          const SizedBox(height: 12),
          if (options.isNotEmpty)
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: options
                  .map((o) => ActionChip(
                        label: Text(o.value, style: const TextStyle(fontWeight: FontWeight.w700)),
                        onPressed: () => Navigator.pop(ctx, (o.key, o.value)),
                      ))
                  .toList(),
            ),
          const SizedBox(height: 12),
          TextField(
            controller: nameCtrl,
            autofocus: options.isEmpty,
            decoration: InputDecoration(
              labelText: tr(en: 'Or new bowler name', ta: 'அல்லது புதிய பெயர்', hi: 'या नया नाम', ml: 'അല്ലെങ്കിൽ പുതിയ പേര്'),
              border: const OutlineInputBorder(),
            ),
            onSubmitted: (v) {
              if (v.trim().isNotEmpty) Navigator.pop(ctx, (null, v.trim()));
            },
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
  if (choice == null) return false;
  final (existingId, name) = choice;
  if (existingId != null) {
    cubit.chooseBowler(existingId, name!);
  } else if (name != null && name.isNotEmpty) {
    cubit.chooseNewBowler(name);
  } else {
    return false;
  }
  return true;
}

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
          // Prompt for the next bowler AT the over break (not on the first
          // ball of the next over). Fires once on the false→true transition;
          // if cancelled, tapping a run re-prompts as a fallback.
          if (state is CricketScoringLoaded &&
              state.needsNewBowler &&
              state.players != null &&
              !state.submitting &&
              state.errorMessage == null) {
            _pickNextBowler(context, state);
          }
        },
        listenWhen: (prev, curr) {
          final wasNeeding = prev is CricketScoringLoaded && prev.needsNewBowler;
          final nowNeeding = curr is CricketScoringLoaded && curr.needsNewBowler;
          final justNeeded = nowNeeding && !wasNeeding;
          final hasError = curr is CricketScoringLoaded && curr.errorMessage != null;
          return justNeeded || hasError;
        },
        builder: (context, state) {
          if (state is CricketScoringLoading || state is CricketScoringInitial) {
            return const Center(child: CircularProgressIndicator());
          }
          if (state is CricketScoringFailure) {
            return _ErrorRetry(message: state.message);
          }
          if (state is CricketScoringNotInitialized) {
            // A result-only match (e.g. a seeded round with no ball-by-ball)
            // can't be replayed — show its stored result instead of the
            // toss/start form. A not-yet-started match still gets the form.
            if (fixture.isCompleted) return _ResultOnlyView(fixture: fixture);
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
                        const SizedBox(height: 16),
                        _Scorecard(ms: ms),
                        const SizedBox(height: 16),
                        CricketOversHistory(ms: ms),
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

/// Read-only result for a completed match that has no ball-by-ball data (e.g. a
/// seeded round entered as a result). Shows the scores + result line.
class _ResultOnlyView extends StatefulWidget {
  final FixtureEntity fixture;
  const _ResultOnlyView({required this.fixture});

  @override
  State<_ResultOnlyView> createState() => _ResultOnlyViewState();
}

class _ResultOnlyViewState extends State<_ResultOnlyView> {
  late String? _scoreA = widget.fixture.teamAScore;
  late String? _scoreB = widget.fixture.teamBScore;
  late String? _notes = widget.fixture.resultNotes;
  late String? _winnerId = widget.fixture.winnerId;

  Future<void> _edit() async {
    final draft = await showModalBottomSheet<_ResultDraft>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _EditResultSheet(
        fixture: widget.fixture,
        scoreA: _scoreA,
        scoreB: _scoreB,
        winnerId: _winnerId,
        notes: _notes,
      ),
    );
    if (draft != null && mounted) {
      setState(() {
        _scoreA = draft.scoreA;
        _scoreB = draft.scoreB;
        _winnerId = draft.winnerId;
        _notes = draft.notes;
      });
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(tr(en: 'Result updated', ta: 'முடிவு புதுப்பிக்கப்பட்டது', hi: 'परिणाम अपडेट हुआ', ml: 'ഫലം അപ്ഡേറ്റ് ചെയ്തു')),
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final f = widget.fixture;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppColors.primary, AppColors.primaryLight],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              children: [
                const Icon(Icons.emoji_events_rounded, color: Colors.white, size: 34),
                const SizedBox(height: 10),
                Text(
                  _notes ??
                      tr(en: 'Match completed', ta: 'போட்டி முடிந்தது', hi: 'मैच समाप्त', ml: 'മത്സരം പൂർത്തിയായി'),
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 18),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _row(context, f.teamAName ?? 'Team A', _scoreA),
          const SizedBox(height: 10),
          _row(context, f.teamBName ?? 'Team B', _scoreB),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _edit,
            icon: const Icon(Icons.edit_rounded, size: 18),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primary,
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            label: Text(tr(en: 'Edit result', ta: 'முடிவைத் திருத்து', hi: 'परिणाम संपादित करें', ml: 'ഫലം തിരുത്തുക'),
                style: const TextStyle(fontWeight: FontWeight.w800)),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF3E0),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFF0B44A)),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline_rounded, size: 18, color: Color(0xFFB45309)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    tr(en: 'Recorded as a result only — no ball-by-ball to replay. You can still edit the scores above.',
                        ta: 'முடிவாக மட்டும் பதிவு — பந்து வாரியான விவரம் இல்லை. மேலே உள்ள மதிப்பெண்களைத் திருத்தலாம்.',
                        hi: 'केवल परिणाम दर्ज है — बॉल-बाय-बॉल नहीं। ऊपर स्कोर संपादित कर सकते हैं।',
                        ml: 'ഫലമായി മാത്രം രേഖപ്പെടുത്തി — ബോൾ-ബൈ-ബോൾ ഇല്ല. മുകളിലെ സ്കോർ തിരുത്താം.'),
                    style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: Color(0xFF92400E)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _row(BuildContext context, String name, String? score) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        color: context.cSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.cBorder),
      ),
      child: Row(
        children: [
          Expanded(child: Text(name, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Color(0xFF0A1128)))),
          Text(score ?? '—', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.primary)),
        ],
      ),
    );
  }
}

/// The canonical result values returned by the editor on a successful save.
class _ResultDraft {
  final String? scoreA;
  final String? scoreB;
  final String? winnerId;
  final String? notes;
  const _ResultDraft({this.scoreA, this.scoreB, this.winnerId, this.notes});
}

/// Structured editor for a result-only match: numeric runs/wickets/overs per
/// team compose a canonical, NRR-parseable score (the backend validates again),
/// so a typo can't skew NRR. Returns a [_ResultDraft] on success.
class _EditResultSheet extends StatefulWidget {
  final FixtureEntity fixture;
  final String? scoreA;
  final String? scoreB;
  final String? winnerId;
  final String? notes;
  const _EditResultSheet({
    required this.fixture,
    this.scoreA,
    this.scoreB,
    this.winnerId,
    this.notes,
  });

  @override
  State<_EditResultSheet> createState() => _EditResultSheetState();
}

class _EditResultSheetState extends State<_EditResultSheet> {
  final _runsA = TextEditingController();
  final _wktsA = TextEditingController();
  final _oversA = TextEditingController();
  final _ballsA = TextEditingController();
  final _runsB = TextEditingController();
  final _wktsB = TextEditingController();
  final _oversB = TextEditingController();
  final _ballsB = TextEditingController();
  late final _notes = TextEditingController(text: widget.notes ?? '');
  late String _winner = widget.winnerId ?? ''; // '' == draw / not set
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _fill(widget.scoreA, _runsA, _wktsA, _oversA, _ballsA);
    _fill(widget.scoreB, _runsB, _wktsB, _oversB, _ballsB);
  }

  void _fill(String? score, TextEditingController r, TextEditingController w,
      TextEditingController o, TextEditingController b) {
    if (score == null) return;
    final m = RegExp(r'\s*(\d+)\s*(?:/\s*(\d+))?\s*(?:\(\s*(\d+)(?:\.(\d+))?)?').firstMatch(score);
    if (m == null) return;
    r.text = m.group(1) ?? '';
    w.text = m.group(2) ?? '';
    o.text = m.group(3) ?? '';
    b.text = m.group(4) ?? '';
  }

  @override
  void dispose() {
    for (final c in [_runsA, _wktsA, _oversA, _ballsA, _runsB, _wktsB, _oversB, _ballsB, _notes]) {
      c.dispose();
    }
    super.dispose();
  }

  /// Compose a canonical score from the numeric fields, or throw a friendly
  /// message. Empty runs => no innings (returns null).
  String? _compose(TextEditingController r, TextEditingController w,
      TextEditingController o, TextEditingController b, String label) {
    final runsS = r.text.trim();
    if (runsS.isEmpty) {
      if (w.text.trim().isNotEmpty || o.text.trim().isNotEmpty || b.text.trim().isNotEmpty) {
        throw tr(en: '$label: enter the runs scored.', ta: '$label: ரன்களை உள்ளிடவும்.', hi: '$label: रन दर्ज करें।', ml: '$label: റൺ നൽകുക.');
      }
      return null;
    }
    final runs = int.tryParse(runsS);
    if (runs == null || runs < 0) throw tr(en: '$label: runs must be a number.', ta: '$label: ரன் எண்ணாக இருக்க வேண்டும்.', hi: '$label: रन संख्या हो।', ml: '$label: റൺ അക്കമായിരിക്കണം.');
    final wkts = w.text.trim().isEmpty ? 0 : int.tryParse(w.text.trim()) ?? -1;
    if (wkts < 0 || wkts > 10) throw tr(en: '$label: wickets run 0–10.', ta: '$label: விக்கெட் 0–10.', hi: '$label: विकेट 0–10।', ml: '$label: വിക്കറ്റ് 0–10.');
    final oS = o.text.trim(), bS = b.text.trim();
    if (oS.isEmpty && bS.isEmpty) return '$runs/$wkts';
    final overs = oS.isEmpty ? 0 : int.tryParse(oS) ?? -1;
    final balls = bS.isEmpty ? 0 : int.tryParse(bS) ?? -1;
    if (overs < 0) throw tr(en: '$label: overs must be a number.', ta: '$label: ஓவர் எண்ணாக இருக்க வேண்டும்.', hi: '$label: ओवर संख्या हो।', ml: '$label: ഓവർ അക്കമായിരിക്കണം.');
    if (balls < 0 || balls > 5) throw tr(en: '$label: an over has 6 balls (0–5).', ta: '$label: ஓவரில் 6 பந்துகள் (0–5).', hi: '$label: एक ओवर में 6 गेंद (0–5)।', ml: '$label: ഒരു ഓവറിൽ 6 പന്ത് (0–5).');
    return '$runs/$wkts ($overs.$balls ov)';
  }

  Future<void> _save() async {
    final f = widget.fixture;
    String? scoreA, scoreB;
    try {
      scoreA = _compose(_runsA, _wktsA, _oversA, _ballsA, f.teamAName ?? 'Team A');
      scoreB = _compose(_runsB, _wktsB, _oversB, _ballsB, f.teamBName ?? 'Team B');
    } catch (msg) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg.toString())));
      return;
    }
    setState(() => _saving = true);
    final res = await sl<SportsRepository>().submitFixtureResult(
      f.tournamentId,
      f.id,
      teamAScore: scoreA,
      teamBScore: scoreB,
      winnerId: _winner.isEmpty ? null : _winner,
      notes: _notes.text.trim().isEmpty ? null : _notes.text.trim(),
    );
    if (!mounted) return;
    setState(() => _saving = false);
    res.fold(
      (l) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(tr(
              en: "Couldn't save — check the scores and try again.",
              ta: 'சேமிக்க முடியவில்லை — மதிப்பெண்களைச் சரிபார்க்கவும்.',
              hi: 'सहेजा नहीं जा सका — स्कोर जांचें।',
              ml: 'സേവ് ചെയ്യാനായില്ല — സ്കോർ പരിശോധിക്കുക.')),
        ));
      },
      (fx) {
        Navigator.of(context).pop(_ResultDraft(
          scoreA: fx.teamAScore,
          scoreB: fx.teamBScore,
          winnerId: fx.winnerId,
          notes: fx.resultNotes,
        ));
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final f = widget.fixture;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: BoxDecoration(
          color: context.cBackground,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(width: 40, height: 4, margin: const EdgeInsets.only(bottom: 14),
                    decoration: BoxDecoration(color: context.cBorder, borderRadius: BorderRadius.circular(2))),
              ),
              Text(tr(en: 'Edit result', ta: 'முடிவைத் திருத்து', hi: 'परिणाम संपादित करें', ml: 'ഫലം തിരുത്തുക'),
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: context.cText)),
              const SizedBox(height: 16),
              _teamFields(context, f.teamAName ?? 'Team A', _runsA, _wktsA, _oversA, _ballsA),
              const SizedBox(height: 14),
              _teamFields(context, f.teamBName ?? 'Team B', _runsB, _wktsB, _oversB, _ballsB),
              const SizedBox(height: 16),
              Text(tr(en: 'Winner', ta: 'வெற்றியாளர்', hi: 'विजेता', ml: 'വിജയി'),
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: context.cTextSecondary)),
              const SizedBox(height: 6),
              DropdownButtonFormField<String>(
                value: _winner,
                isExpanded: true,
                decoration: _dec(context),
                items: [
                  DropdownMenuItem(value: '', child: Text(tr(en: 'Draw / not set', ta: 'சமன் / இல்லை', hi: 'ड्रॉ / नहीं', ml: 'സമനില / ഇല്ല'))),
                  DropdownMenuItem(value: f.teamAId, child: Text(f.teamAName ?? 'Team A')),
                  DropdownMenuItem(value: f.teamBId, child: Text(f.teamBName ?? 'Team B')),
                ],
                onChanged: (v) => setState(() => _winner = v ?? ''),
              ),
              const SizedBox(height: 14),
              Text(tr(en: 'Result note (optional)', ta: 'முடிவு குறிப்பு (விருப்பம்)', hi: 'परिणाम नोट (वैकल्पिक)', ml: 'ഫല കുറിപ്പ് (ഐച്ഛികം)'),
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: context.cTextSecondary)),
              const SizedBox(height: 6),
              TextField(controller: _notes, decoration: _dec(context, hint: tr(en: 'e.g. won by 8 wickets', ta: 'எ.கா. 8 விக்கெட்டில் வெற்றி', hi: 'जैसे 8 विकेट से जीत', ml: 'ഉദാ. 8 വിക്കറ്റിന് ജയം'))),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: _saving ? null : _save,
                style: FilledButton.styleFrom(backgroundColor: AppColors.primary, padding: const EdgeInsets.symmetric(vertical: 15)),
                child: _saving
                    ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : Text(tr(en: 'Save result', ta: 'முடிவைச் சேமி', hi: 'परिणाम सहेजें', ml: 'ഫലം സേവ് ചെയ്യുക'),
                        style: const TextStyle(fontWeight: FontWeight.w800)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  InputDecoration _dec(BuildContext context, {String? hint}) => InputDecoration(
        hintText: hint,
        isDense: true,
        filled: true,
        fillColor: context.cSurface,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: context.cBorder)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: context.cBorder)),
      );

  Widget _teamFields(BuildContext context, String name, TextEditingController r,
      TextEditingController w, TextEditingController o, TextEditingController b) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(name, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: context.cText)),
        const SizedBox(height: 6),
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(flex: 3, child: _num(context, r, tr(en: 'Runs', ta: 'ரன்', hi: 'रन', ml: 'റൺ'))),
            const SizedBox(width: 8),
            Expanded(flex: 2, child: _num(context, w, tr(en: 'Wkts', ta: 'விக்', hi: 'विकेट', ml: 'വിക്'))),
            const SizedBox(width: 8),
            Expanded(flex: 2, child: _num(context, o, tr(en: 'Overs', ta: 'ஓவர்', hi: 'ओवर', ml: 'ഓവർ'))),
            Padding(padding: const EdgeInsets.only(bottom: 12), child: Text('.', style: TextStyle(fontWeight: FontWeight.w900, color: context.cTextSecondary))),
            Expanded(flex: 1, child: _num(context, b, tr(en: 'Ball', ta: 'பந்து', hi: 'गेंद', ml: 'പന്ത്'))),
          ],
        ),
      ],
    );
  }

  Widget _num(BuildContext context, TextEditingController c, String label) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontSize: 10, color: context.cTextSecondary)),
        const SizedBox(height: 3),
        TextField(
          controller: c,
          keyboardType: TextInputType.number,
          textAlign: TextAlign.center,
          decoration: _dec(context),
        ),
      ],
    );
  }
}

class _TossSetupForm extends StatefulWidget {
  final FixtureEntity fixture;
  const _TossSetupForm({required this.fixture});

  @override
  State<_TossSetupForm> createState() => _TossSetupFormState();
}

class _TossSetupFormState extends State<_TossSetupForm> {
  String? _tossWinnerId;
  String _decision = 'BAT';
  bool _villageWides = false;
  final _overs = TextEditingController(text: '20');
  // Sensible defaults so the scorer can start in one tap and rename later
  // (players can be renamed from team management). Openers must differ, so
  // Player 1 / Player 2 by batting position.
  final _striker = TextEditingController(text: 'Player 1');
  final _nonStriker = TextEditingController(text: 'Player 2');
  final _bowler = TextEditingController(text: 'Bowler 1');

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
      _bowler.text.trim().isNotEmpty &&
      !_sameName(_striker.text, _nonStriker.text);

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
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: Color(0xFF0A1128)),
          ),
          const SizedBox(height: 18),
          Text(tr(en: 'Toss won by', ta: 'டாஸ் வென்றது',
              hi: 'टॉस जीता', ml: 'ടോസ് നേടിയത്'), style: const TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF5B6478))),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              _themedChip(context,
                  label: f.teamAName ?? 'Team A',
                  selected: _tossWinnerId == f.teamAId,
                  onSelected: () => setState(() => _tossWinnerId = f.teamAId)),
              _themedChip(context,
                  label: f.teamBName ?? 'Team B',
                  selected: _tossWinnerId == f.teamBId,
                  onSelected: () => setState(() => _tossWinnerId = f.teamBId)),
            ],
          ),
          const SizedBox(height: 18),
          Text(tr(en: 'Decision', ta: 'முடிவு', hi: 'निर्णय', ml: 'തീരുമാനം'), style: const TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF5B6478))),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              _themedChip(context,
                  label: tr(en: 'Bat', ta: 'பேட்டிங்', hi: 'बल्लेबाज़ी', ml: 'ബാറ്റിംഗ്'),
                  selected: _decision == 'BAT',
                  onSelected: () => setState(() => _decision = 'BAT')),
              _themedChip(context,
                  label: tr(en: 'Bowl', ta: 'பந்துவீச்சு', hi: 'गेंदबाज़ी', ml: 'ബൗളിംഗ്'),
                  selected: _decision == 'BOWL',
                  onSelected: () => setState(() => _decision = 'BOWL')),
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
          const SizedBox(height: 4),
          Container(
            decoration: BoxDecoration(
              border: Border.all(color: const Color(0xFFCBD2E0)),
              borderRadius: BorderRadius.circular(8),
            ),
            child: SwitchListTile(
              value: _villageWides,
              onChanged: (v) => setState(() => _villageWides = v),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12),
              title: Text(
                tr(en: '2 free wides per over', ta: 'ஓவருக்கு 2 இலவச வைடுகள்',
                    hi: 'प्रति ओवर 2 फ्री वाइड', ml: 'ഓവറിന് 2 ഫ്രീ വൈഡുകൾ'),
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
              ),
              subtitle: Text(
                tr(en: 'Village rule: first two wides in an over add no run (still re-bowled)',
                    ta: 'கிராம விதி: ஓவரின் முதல் இரண்டு வைடுகளுக்கு ரன் இல்லை (மீண்டும் வீசவும்)',
                    hi: 'गाँव नियम: ओवर की पहली दो वाइड पर रन नहीं (फिर भी दोबारा फेंकें)',
                    ml: 'ഗ്രാമ നിയമം: ഓവറിലെ ആദ്യ രണ്ട് വൈഡിന് റൺ ഇല്ല (വീണ്ടും എറിയണം)'),
                style: const TextStyle(fontSize: 11.5),
              ),
            ),
          ),

          const SizedBox(height: 20),
          if (!_valid)
            Container(
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.errorContainer,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Theme.of(context).colorScheme.error),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.warning_amber_rounded, color: Theme.of(context).colorScheme.error, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        'Complete match setup first',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (_tossWinnerId == null) const Text('• Select toss winner', style: TextStyle(fontSize: 13)),
                  if (int.tryParse(_overs.text) == null || int.parse(_overs.text) <= 0) const Text('• Enter valid overs', style: TextStyle(fontSize: 13)),
                  if (_striker.text.trim().isEmpty) const Text('• Select opening striker', style: TextStyle(fontSize: 13)),
                  if (_nonStriker.text.trim().isEmpty) const Text('• Select opening non-striker', style: TextStyle(fontSize: 13)),
                  if (_bowler.text.trim().isEmpty) const Text('• Select opening bowler', style: TextStyle(fontSize: 13)),
                  if (_striker.text.trim().isNotEmpty && _sameName(_striker.text, _nonStriker.text))
                    const Text('• Striker and non-striker must be different players', style: TextStyle(fontSize: 13)),
                ],
              ),
            ),
          _gradientCTA(
            label: tr(en: 'Start scoring', ta: 'ஸ்கோரிங் தொடங்கு',
                hi: 'स्कोरिंग शुरू करें', ml: 'സ്കോറിംഗ് ആരംഭിക്കുക'),
            icon: Icons.sports_cricket_rounded,
            onPressed: _valid
                ? () => context.read<CricketScoringCubit>().initMatch(
                      tossWinnerId: _tossWinnerId!,
                      tossDecision: _decision,
                      overs: int.parse(_overs.text),
                      strikerName: _striker.text,
                      nonStrikerName: _nonStriker.text,
                      bowlerName: _bowler.text,
                      villageWides: _villageWides,
                    )
                : null,
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
    final needed = ms.target != null ? ms.target! - ms.score : null;
    final ballsFaced = (ms.overs * 6) + ms.balls;
    final rr = ballsFaced > 0 ? (ms.score / ballsFaced) * 6 : 0.0;
    
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.primary, AppColors.primaryLight],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(color: AppColors.primary.withOpacity(0.32), blurRadius: 26, offset: const Offset(0, 12)),
        ],
      ),
      padding: const EdgeInsets.symmetric(vertical: 26, horizontal: 18),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(color: Color(0xFF7DF3D2), shape: BoxShape.circle),
              ),
              const SizedBox(width: 9),
              Text(
                teamName(ms.battingTeamId).toUpperCase(),
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 15, letterSpacing: 1.4),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            '${ms.score}/${ms.wickets}',
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 72, height: 1.0, letterSpacing: -1.5),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('Overs ${ms.oversText}',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 15)),
              const SizedBox(width: 16),
              Text('CRR ${rr.toStringAsFixed(1)}',
                  style: TextStyle(color: Colors.white.withOpacity(0.75), fontWeight: FontWeight.w600, fontSize: 15)),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.18),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text('Innings ${ms.innings}',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
          ),
          if (ms.target != null && !ms.isCompleted) ...[
            const SizedBox(height: 16),
            Divider(color: Colors.white.withOpacity(0.2)),
            const SizedBox(height: 8),
            Text('Need ${needed! > 0 ? needed : 0} runs',
                style: const TextStyle(color: Color(0xFFFFD37A), fontWeight: FontWeight.bold, fontSize: 20)),
            const SizedBox(height: 4),
            Text('Target ${ms.target}',
                style: TextStyle(color: Colors.white.withOpacity(0.75), fontSize: 13.5)),
          ],
          if (ms.recentBalls.isNotEmpty) ...[
            const SizedBox(height: 16),
            Divider(color: Colors.white.withOpacity(0.2)),
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
                    color: b == 'W'
                        ? const Color(0xFFF43F5E)
                        : (b.contains('w') || b.contains('n') ? const Color(0xFFF59E0B) : Colors.white.withOpacity(0.16)),
                    shape: BoxShape.circle,
                  ),
                  child: Text(b,
                      style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 12.5)),
                ),
              )).toList(),
            ),
          ],
        ],
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
  final _striker = TextEditingController(text: 'Player 1');
  final _nonStriker = TextEditingController(text: 'Player 2');
  final _bowler = TextEditingController(text: 'Bowler 1');

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
      _bowler.text.trim().isNotEmpty &&
      !_sameName(_striker.text, _nonStriker.text);

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
            if (!_valid)
              Container(
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.errorContainer,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Theme.of(context).colorScheme.error),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.warning_amber_rounded, color: Theme.of(context).colorScheme.error, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          'Complete match setup first',
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    if (_striker.text.trim().isEmpty) const Text('• Select opening striker', style: TextStyle(fontSize: 13)),
                    if (_nonStriker.text.trim().isEmpty) const Text('• Select opening non-striker', style: TextStyle(fontSize: 13)),
                    if (_bowler.text.trim().isEmpty) const Text('• Select opening bowler', style: TextStyle(fontSize: 13)),
                    if (_striker.text.trim().isNotEmpty && _sameName(_striker.text, _nonStriker.text))
                      const Text('• Striker and non-striker must be different players', style: TextStyle(fontSize: 13)),
                  ],
                ),
              ),
            _gradientCTA(
              label: tr(en: 'Start 2nd innings', ta: '2-வது இன்னிங்ஸ் தொடங்கு',
                  hi: 'दूसरी पारी शुरू करें', ml: 'രണ്ടാം ഇന്നിംഗ്സ് ആരംഭിക്കുക'),
              icon: Icons.sports_cricket_rounded,
              onPressed: _valid
                  ? () => context.read<CricketScoringCubit>().startSecondInnings(
                        strikerName: _striker.text,
                        nonStrikerName: _nonStriker.text,
                        bowlerName: _bowler.text,
                        anyTeamId: widget.fixture.teamAId,
                      )
                  : null,
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
    // Batting options: not-out batters first, then rest of the squad. Blank
    // names (a ghost/incomplete Player row) are filtered out — they used to
    // render as an unlabeled, unusable chip that blocked resuming the match.
    final outIds = ms.batters.where((b) => b.out).map((b) => b.id).toSet();
    final seen = <String>{};
    final battingOptions = <MapEntry<String, String>>[];
    for (final b in ms.batters.where((b) => !b.out)) {
      if (b.name.trim().isNotEmpty && seen.add(b.id)) battingOptions.add(MapEntry(b.id, b.name));
    }
    for (final p in _battingSquad) {
      if (!outIds.contains(p.id) && p.name.trim().isNotEmpty && seen.add(p.id)) {
        battingOptions.add(MapEntry(p.id, p.name));
      }
    }
    final bowlerSeen = <String>{};
    final bowlingOptions = <MapEntry<String, String>>[];
    for (final b in ms.bowlers) {
      if (b.name.trim().isNotEmpty && bowlerSeen.add(b.id)) bowlingOptions.add(MapEntry(b.id, b.name));
    }
    for (final p in _bowlingSquad) {
      if (p.name.trim().isNotEmpty && bowlerSeen.add(p.id)) bowlingOptions.add(MapEntry(p.id, p.name));
    }

    Widget chips(List<MapEntry<String, String>> options, String? selected,
        void Function(String) onPick, {Set<String> disabled = const {}}) {
      if (options.isEmpty) {
        return Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: const Color(0xFFFFF3E0), borderRadius: BorderRadius.circular(10)),
          child: Row(children: [
            const Icon(Icons.info_outline_rounded, size: 16, color: Color(0xFFB45309)),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                tr(en: 'No player found. Tap "Undo Last Ball" above to fix the previous delivery.',
                    ta: 'வீரர் இல்லை. மேலே "Undo Last Ball" தட்டி முந்தைய பந்தை சரிசெய்யவும்.',
                    hi: 'खिलाड़ी नहीं मिला। ऊपर "Undo Last Ball" दबाकर पिछली गेंद ठीक करें।',
                    ml: 'കളിക്കാരനെ കണ്ടെത്തിയില്ല. മുകളിലെ "Undo Last Ball" അമർത്തി മുൻ ബോൾ ശരിയാക്കുക.'),
                style: const TextStyle(fontSize: 12, color: Color(0xFF92400E), fontWeight: FontWeight.w600),
              ),
            ),
          ]),
        );
      }
      return Wrap(
        spacing: 8,
        runSpacing: 8,
        children: options
            .map((o) => _themedChip(context,
                  label: o.value,
                  selected: selected == o.key,
                  onSelected: disabled.contains(o.key) ? null : () => setState(() => onPick(o.key)),
                ))
            .toList(),
      );
    }

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: const BorderSide(color: Color(0xFFE3E7F0))),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [AppColors.primary, AppColors.primaryLight]),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.sports_cricket_rounded, color: Colors.white, size: 18),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  tr(en: 'Confirm current players', ta: 'தற்போதைய வீரர்களை உறுதிசெய்க',
                      hi: 'वर्तमान खिलाड़ी चुनें', ml: 'നിലവിലെ കളിക്കാരെ സ്ഥിരീകരിക്കുക'),
                  style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: Color(0xFF0A1128)),
                ),
              ),
            ]),
            const SizedBox(height: 16),
            Text(tr(en: 'Striker', ta: 'ஸ்ட்ரைக்கர்', hi: 'स्ट्राइकर', ml: 'സ്ട്രൈക്കർ'),
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5, color: Color(0xFF5B6478))),
            const SizedBox(height: 6),
            chips(battingOptions, _strikerId, (id) => _strikerId = id,
                disabled: {if (_nonStrikerId != null) _nonStrikerId!}),
            const SizedBox(height: 14),
            Text(tr(en: 'Non-striker', ta: 'நான்-ஸ்ட்ரைக்கர்',
                hi: 'नॉन-स्ट्राइकर', ml: 'നോൺ-സ്ട്രൈക്കർ'),
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5, color: Color(0xFF5B6478))),
            const SizedBox(height: 6),
            chips(battingOptions, _nonStrikerId, (id) => _nonStrikerId = id,
                disabled: {if (_strikerId != null) _strikerId!}),
            const SizedBox(height: 14),
            Text(tr(en: 'Bowler', ta: 'பந்துவீச்சாளர்', hi: 'गेंदबाज़', ml: 'ബൗളർ'),
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5, color: Color(0xFF5B6478))),
            const SizedBox(height: 6),
            chips(bowlingOptions, _bowlerId, (id) => _bowlerId = id),

            const SizedBox(height: 16),
            if (_strikerId == null || _nonStrikerId == null || _bowlerId == null || _strikerId == _nonStrikerId)
              Container(
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.errorContainer,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Theme.of(context).colorScheme.error),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.warning_amber_rounded, color: Theme.of(context).colorScheme.error, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          'Complete match setup first',
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    if (_strikerId == null) const Text('• Select striker', style: TextStyle(fontSize: 13)),
                    if (_nonStrikerId == null) const Text('• Select non-striker', style: TextStyle(fontSize: 13)),
                    if (_strikerId != null && _strikerId == _nonStrikerId) const Text('• Striker and non-striker must be different', style: TextStyle(fontSize: 13)),
                    if (_bowlerId == null) const Text('• Select bowler', style: TextStyle(fontSize: 13)),
                  ],
                ),
              ),
            _gradientCTA(
              label: tr(en: 'Continue scoring', ta: 'ஸ்கோரிங் தொடர்க',
                  hi: 'स्कोरिंग जारी रखें', ml: 'സ്കോറിംഗ് തുടരുക'),
              icon: Icons.check_circle_rounded,
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
        // A hairline progress line while a ball posts — the scoreboard stays
        // put (no full-screen reload), so entry feels instant.
        SizedBox(
          height: 3,
          child: state.submitting
              ? const LinearProgressIndicator(minHeight: 3, backgroundColor: Colors.transparent)
              : null,
        ),
        const SizedBox(height: 8),
        if (state.pendingSync > 0)
          Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF3E0),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFF0B44A)),
            ),
            child: Row(
              children: [
                const Icon(Icons.cloud_off_rounded, color: Color(0xFFB45309), size: 19),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    tr(
                      en: 'Offline — ${state.pendingSync} ball${state.pendingSync == 1 ? '' : 's'} will sync when you reconnect',
                      ta: 'ஆஃப்லைன் — ${state.pendingSync} பந்து மீண்டும் இணைந்ததும் ஒத்திசைக்கப்படும்',
                      hi: 'ऑफ़लाइन — ${state.pendingSync} गेंद फिर से कनेक्ट होने पर सिंक होंगी',
                      ml: 'ഓഫ്‌ലൈൻ — ${state.pendingSync} ബോൾ വീണ്ടും കണക്റ്റ് ചെയ്യുമ്പോൾ സിങ്ക് ചെയ്യും',
                    ),
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: Color(0xFF92400E)),
                  ),
                ),
              ],
            ),
          ),
        // Batter Card Row
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text.rich(TextSpan(children: [
                    WidgetSpan(alignment: PlaceholderAlignment.middle, child: Icon(Icons.sports_cricket_rounded, size: 15, color: theme.colorScheme.primary)),
                    TextSpan(text: ' ${strikerStats.name} *    ${strikerStats.runs}(${strikerStats.balls})'),
                  ]),
                      style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold, color: theme.colorScheme.primary)),
                  const SizedBox(height: 4),
                  Text.rich(TextSpan(children: [
                    WidgetSpan(alignment: PlaceholderAlignment.middle, child: Icon(Icons.sports_cricket_rounded, size: 15, color: theme.colorScheme.onSurfaceVariant)),
                    TextSpan(text: ' ${nonStrikerStats.name}      ${nonStrikerStats.runs}(${nonStrikerStats.balls})'),
                  ]),
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
                  Text.rich(TextSpan(children: [
                    WidgetSpan(alignment: PlaceholderAlignment.middle, child: Icon(Icons.my_location_rounded, size: 15, color: theme.colorScheme.primary)),
                    TextSpan(text: ' ${bowlerStats.name}'),
                  ]), style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
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
            child: Pressable(
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () => _pickNextBowler(context, state),
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF3E0),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFF0B44A)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.sports_baseball_rounded, color: Color(0xFFB45309), size: 20),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            tr(en: 'Over complete — tap to pick the next bowler',
                                ta: 'ஓவர் முடிந்தது — அடுத்த பந்துவீச்சாளரைத் தேர்ந்தெடுக்கத் தட்டவும்',
                                hi: 'ओवर पूरा — अगला गेंदबाज़ चुनने के लिए टैप करें',
                                ml: 'ഓവർ പൂർത്തിയായി — അടുത്ത ബൗളറെ തിരഞ്ഞെടുക്കാൻ ടാപ്പ് ചെയ്യുക'),
                            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: Color(0xFF92400E)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        const SizedBox(height: 16),
        // Ball controls
        Row(
          children: [0, 1, 2, 3, 4, 6].map((runs) {
            final isBoundary = runs == 4 || runs == 6;
            final isDot = runs == 0;
            final grad = isDot
                ? const [Color(0xFF334155), Color(0xFF1E293B)]
                : runs == 6
                    ? const [Color(0xFFF59E0B), Color(0xFFB45309)]
                    : isBoundary
                        ? const [AppColors.primary, AppColors.primaryLight]
                        : const [Color(0xFF14B891), Color(0xFF0F9B7E)];
            return Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 3),
                child: Pressable(
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(14),
                      onTap: () => _withBowlerIfNeeded(context, (newBowlerName) => cubit.scoreBall(runsBatter: runs, newBowlerName: newBowlerName)),
                      child: Container(
                        height: 58,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(colors: grad, begin: Alignment.topLeft, end: Alignment.bottomRight),
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: [BoxShadow(color: grad.last.withOpacity(0.35), blurRadius: 10, offset: const Offset(0, 4))],
                        ),
                        child: Text('$runs', style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w800, color: Colors.white)),
                      ),
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            // Every extra opens a run picker so it can carry runs — including a
            // free (village) wide that was still run on, and a bare "0nb".
            _actionBtn(context, state.matchState.nextWideIsFree ? 'Wide (free)' : 'Wide',
                () => _extrasSheet(context, 'WIDE')),
            const SizedBox(width: 8),
            _actionBtn(context, 'No Ball', () => _extrasSheet(context, 'NO_BALL')),
            const SizedBox(width: 8),
            _actionBtn(context, 'Bye', () => _extrasSheet(context, 'BYE')),
            const SizedBox(width: 8),
            _actionBtn(context, 'Leg Bye', () => _extrasSheet(context, 'LEG_BYE')),
          ],
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 56,
          child: Pressable(
            child: FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: theme.colorScheme.error,
                foregroundColor: theme.colorScheme.onError,
                minimumSize: const Size(double.infinity, 56),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              onPressed: () => _wicketDialog(context),
              child: const Text('WICKET', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
            ),
          ),
        ),
      ],
    );
  }

  Widget _actionBtn(BuildContext context, String label, VoidCallback onTap) {
    return Expanded(
      child: Pressable(
        child: OutlinedButton(
          style: OutlinedButton.styleFrom(
            padding: EdgeInsets.zero,
            minimumSize: const Size(0, 52),
            foregroundColor: const Color(0xFF0A1128),
            side: const BorderSide(color: Color(0xFFCBD2E0), width: 1.4),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          onPressed: onTap,
          child: Text(label, style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700)),
        ),
      ),
    );
  }

  /// If an over just ended and no bowler is chosen yet, prompt for one first;
  /// otherwise score straight through. The proactive over-break prompt usually
  /// resolves this already, so this is the tap-time fallback.
  Future<void> _withBowlerIfNeeded(
      BuildContext context, Future<void> Function(String?) send) async {
    if (state.needsNewBowler) {
      final picked = await _pickNextBowler(context, state);
      if (!picked || !context.mounted) return;
    }
    await send(null);
  }

  /// Run picker for an extra. Wides/no-balls allow 0 (a bare wide / "0nb");
  /// byes/leg-byes require at least one run. The picked value is the runs
  /// physically run off the delivery — the backend adds the 1-run penalty for
  /// a normal wide/no-ball itself.
  Future<void> _extrasSheet(BuildContext context, String type) async {
    final cubit = context.read<CricketScoringCubit>();
    final isWideOrNoBall = type == 'WIDE' || type == 'NO_BALL';
    final options = isWideOrNoBall ? const [0, 1, 2, 3, 4, 5, 6] : const [1, 2, 3, 4, 5, 6];
    final title = {
      'WIDE': tr(en: 'Wide', ta: 'வைடு', hi: 'वाइड', ml: 'വൈഡ്'),
      'NO_BALL': tr(en: 'No ball', ta: 'நோ பால்', hi: 'नो बॉल', ml: 'നോ ബോൾ'),
      'BYE': tr(en: 'Bye', ta: 'பை', hi: 'बाई', ml: 'ബൈ'),
      'LEG_BYE': tr(en: 'Leg bye', ta: 'லெக் பை', hi: 'लेग बाई', ml: 'ലെഗ് ബൈ'),
    }[type]!;
    final hint = isWideOrNoBall
        ? tr(en: 'Runs run off it (0 = none)', ta: 'ஓடிய ரன்கள் (0 = இல்லை)',
            hi: 'इस पर बने रन (0 = कोई नहीं)', ml: 'ഓടിയ റൺസ് (0 = ഇല്ല)')
        : tr(en: 'How many runs were run?', ta: 'எத்தனை ரன்கள் ஓடினர்?',
            hi: 'कितने रन बने?', ml: 'എത്ര റൺസ് ഓടി?');

    final picked = await showModalBottomSheet<int>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: const Color(0xFFD7DCEA), borderRadius: BorderRadius.circular(4)))),
            const SizedBox(height: 16),
            Text(title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: Color(0xFF0A1128))),
            const SizedBox(height: 4),
            Text(hint, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: Color(0xFF5B6478))),
            const SizedBox(height: 16),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: options
                  .map((r) => Pressable(
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(14),
                            onTap: () => Navigator.pop(ctx, r),
                            child: Container(
                              width: 58,
                              height: 58,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(colors: [AppColors.primary, AppColors.primaryLight]),
                                borderRadius: BorderRadius.circular(14),
                                boxShadow: [BoxShadow(color: AppColors.primary.withOpacity(0.25), blurRadius: 8, offset: const Offset(0, 3))],
                              ),
                              child: Text('$r', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: Colors.white)),
                            ),
                          ),
                        ),
                      ))
                  .toList(),
            ),
          ],
        ),
      ),
    );
    if (picked == null || !context.mounted) return;
    await _withBowlerIfNeeded(
        context, (nb) => cubit.scoreBall(extrasType: type, extrasRuns: picked, newBowlerName: nb));
  }

  Future<void> _wicketDialog(BuildContext context) async {
    final cubit = context.read<CricketScoringCubit>();
    final players = state.players!;
    String wicketType = 'BOWLED';
    String dismissedId = players.strikerId;
    int runOutRuns = 0; // runs completed before a run-out (crossed once, twice…)
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
                // Runs completed before a run-out (the batsmen crossed) — these
                // count. The backend credits runs_batter alongside the wicket.
                if (wicketType == 'RUN_OUT') ...[
                  const SizedBox(height: 14),
                  const Text('Runs completed', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: [0, 1, 2, 3, 4, 5, 6]
                        .map((r) => ChoiceChip(
                              label: Text('$r',
                                  style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                      color: runOutRuns == r ? Colors.white : const Color(0xFF0A1128))),
                              selected: runOutRuns == r,
                              selectedColor: AppColors.primary,
                              backgroundColor: const Color(0xFFEFF2FA),
                              onSelected: (_) => setDialogState(() => runOutRuns = r),
                            ))
                        .toList(),
                  ),
                ],
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
                    // Live-revalidate so Confirm enables/disables as they type —
                    // a blank name here used to be accepted silently, leaving
                    // the dismissed player's id on the crease for the next ball
                    // and corrupting the batting order.
                    onChanged: (_) => setDialogState(() {}),
                  ),
                  Builder(builder: (_) {
                    final survivingName = dismissedId == players.strikerId
                        ? players.nonStrikerName
                        : players.strikerName;
                    final typed = newBatter.text.trim();
                    if (typed.isEmpty) {
                      return const Padding(
                        padding: EdgeInsets.only(top: 6),
                        child: Text('Required — who is replacing them?',
                            style: TextStyle(fontSize: 12, color: Color(0xFF92400E))),
                      );
                    }
                    if (_sameName(typed, survivingName)) {
                      return const Padding(
                        padding: EdgeInsets.only(top: 6),
                        child: Text('Must be different from the other batter on the crease',
                            style: TextStyle(fontSize: 12, color: Color(0xFFDC2626))),
                      );
                    }
                    return const SizedBox.shrink();
                  }),
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
              onPressed: (lastWicket ||
                      (newBatter.text.trim().isNotEmpty &&
                          !_sameName(
                              newBatter.text,
                              dismissedId == players.strikerId ? players.nonStrikerName : players.strikerName)))
                  ? () => Navigator.pop(ctx, true)
                  : null,
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
        runsBatter: wicketType == 'RUN_OUT' ? runOutRuns : 0,
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
    const ink = Color(0xFF0A1128);
    const muted = Color(0xFF5B6478);
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: Color(0xFFE3E7F0))),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _sectionLabel(tr(en: 'Batting', ta: 'பேட்டிங்', hi: 'बल्लेबाज़ी', ml: 'ബാറ്റിംഗ്')),
            const SizedBox(height: 6),
            ...ms.batters.map((b) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          b.out ? '${b.name}  •  out' : b.name,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: b.out ? FontWeight.w500 : FontWeight.w700,
                            color: b.out ? muted : ink,
                          ),
                        ),
                      ),
                      Text('${b.runs} (${b.balls})   4s:${b.fours}  6s:${b.sixes}',
                          style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700, color: b.out ? muted : ink)),
                    ],
                  ),
                )),
            if (ms.extrasTotal > 0)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  '${tr(en: 'Extras', ta: 'எக்ஸ்ட்ராஸ்', hi: 'अतिरिक्त', ml: 'എക്സ്ട്രാസ്')}: ${ms.extrasTotal}',
                  style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: muted),
                ),
              ),
            const Divider(height: 24),
            _sectionLabel(tr(en: 'Bowling', ta: 'பந்துவீச்சு', hi: 'गेंदबाज़ी', ml: 'ബൗളിംഗ്')),
            const SizedBox(height: 6),
            ...ms.bowlers.map((b) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      Expanded(child: Text(b.name, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: ink))),
                      Text('${b.oversText} ov · ${b.runs}r · ${b.wickets}w',
                          style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700, color: ink)),
                    ],
                  ),
                )),
          ],
        ),
      ),
    );
  }

  Widget _sectionLabel(String text) => Text(
        text.toUpperCase(),
        style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, letterSpacing: 0.6, color: AppColors.primary),
      );
}
