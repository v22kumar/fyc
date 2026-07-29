import 'dart:async';
import 'package:flutter/material.dart';
import 'package:fyc_connect/core/l10n/tr.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../service_locator.dart';
import '../../domain/entities/cricket_match_state_entity.dart';
import '../../domain/repositories/sports_repository.dart';

/// Read-only live scorecard — the "streaming match" view for any user. Shows the
/// current score, the two batters at the crease, and the current bowler, and
/// auto-refreshes while open. No scoring controls.
class LiveScorecardScreen extends StatefulWidget {
  final String fixtureId;
  final String teamA;
  final String teamB;

  const LiveScorecardScreen({
    super.key,
    required this.fixtureId,
    required this.teamA,
    required this.teamB,
  });

  @override
  State<LiveScorecardScreen> createState() => _LiveScorecardScreenState();
}

class _LiveScorecardScreenState extends State<LiveScorecardScreen> {
  CricketMatchStateEntity? _state;
  String? _error;
  bool _fetching = false;
  Timer? _timer;
  StreamSubscription<CricketMatchStateEntity>? _sub;

  @override
  void initState() {
    super.initState();
    _fetch(); // instant first paint
    _startStream(); // realtime pushes over one connection
    // Safety net: a slow poll that also revives the stream if it dropped, so the
    // score is never stale even if SSE can't hold (proxy, flaky stadium wifi).
    _timer = Timer.periodic(const Duration(seconds: 20), (_) {
      _fetch();
      if (_sub == null) _startStream();
    });
  }

  void _startStream() {
    _sub?.cancel();
    _sub = sl<SportsRepository>().streamCricketMatchState(widget.fixtureId).listen(
      (s) {
        if (!mounted) return;
        setState(() {
          _state = s;
          _error = null;
        });
      },
      onError: (_) {
        // Fall back to polling until the next reconnect tick.
        _sub?.cancel();
        _sub = null;
      },
      onDone: () {
        _sub = null;
      },
      cancelOnError: true,
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    _sub?.cancel();
    super.dispose();
  }

  Future<void> _fetch() async {
    if (_fetching) return;
    _fetching = true;
    final res = await sl<SportsRepository>().fetchCricketMatchState(widget.fixtureId);
    if (!mounted) {
      _fetching = false;
      return;
    }
    res.fold(
      (l) => setState(() => _error = trId('could_not_load_the_live_score')),
      (s) => setState(() {
        _state = s;
        _error = null;
      }),
    );
    _fetching = false;
  }

  String? _currentBowlerId(CricketMatchStateEntity s) {
    if (s.oversHistory.isEmpty) return null;
    final over = s.oversHistory.last;
    if (over.balls.isEmpty) return null;
    return over.balls.last.bowlerId;
  }

  String? _strikerId(CricketMatchStateEntity s) {
    if (s.oversHistory.isEmpty) return null;
    final over = s.oversHistory.last;
    if (over.balls.isEmpty) return null;
    return over.balls.last.strikerId;
  }

  @override
  Widget build(BuildContext context) {
    final s = _state;
    return Scaffold(
      backgroundColor: context.cBackground,
      appBar: AppBar(
        title: Text('${widget.teamA}  ${trId('vs')}  ${widget.teamB}',
            overflow: TextOverflow.ellipsis),
      ),
      body: _error != null
          ? Center(child: Text(_error!, style: TextStyle(color: context.cTextSecondary)))
          : s == null
              ? Center(child: CircularProgressIndicator())
              : RefreshIndicator(
                  onRefresh: _fetch,
                  child: ListView(
                    padding: EdgeInsets.all(16),
                    children: [_scoreCard(context, s), SizedBox(height: 16), _crease(context, s)],
                  ),
                ),
    );
  }

  Widget _scoreCard(BuildContext context, CricketMatchStateEntity s) {
    String? note;
    if (s.status == 'INNINGS_BREAK') {
      note = trId('innings_break');
    } else if (s.innings == 2 && s.target != null) {
      final need = s.target! - s.score;
      note = need > 0
          ? tr(en: 'Need $need run${need == 1 ? '' : 's'}', ta: '$need ரன் தேவை', hi: '$need रन चाहिए', ml: '$need റൺ വേണം')
          : trId('target_reached');
    }
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: AppTheme.gradientAurora,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            tr(en: 'Innings ${s.innings}', ta: 'இன்னிங்ஸ் ${s.innings}', hi: 'पारी ${s.innings}', ml: 'ഇന്നിംഗ്സ് ${s.innings}'),
            style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w600),
          ),
          SizedBox(height: 6),
          Text('${s.score}/${s.wickets}',
              style: TextStyle(color: AppColors.background, fontSize: 40, fontWeight: FontWeight.w900, letterSpacing: -1)),
          Text('${trId('overs_2')} ${s.overs}.${s.balls}',
              style: TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.w600)),
          if (note != null) ...[
            SizedBox(height: 10),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(color: AppColors.background.withOpacity(0.15), borderRadius: BorderRadius.circular(8)),
              child: Text(note, style: TextStyle(color: AppColors.background, fontSize: 12.5, fontWeight: FontWeight.w700)),
            ),
          ],
          if (s.recentBalls.isNotEmpty) ...[
            SizedBox(height: 14),
            Text(trId('this_over'),
                style: TextStyle(color: Colors.white54, fontSize: 11, fontWeight: FontWeight.w600)),
            SizedBox(height: 6),
            Wrap(
              spacing: 6,
              children: s.recentBalls.take(8).map((b) => Container(
                    width: 28,
                    height: 28,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(color: AppColors.background.withOpacity(0.16), shape: BoxShape.circle),
                    child: Text(b, style: TextStyle(color: AppColors.background, fontSize: 11, fontWeight: FontWeight.w700)),
                  )).toList(),
            ),
          ],
        ],
      ),
    );
  }

  Widget _crease(BuildContext context, CricketMatchStateEntity s) {
    final striker = _strikerId(s);
    final atCrease = s.batters.where((b) => !b.out).toList();
    final bowlerId = _currentBowlerId(s);
    final bowler = bowlerId == null
        ? null
        : (s.bowlers.where((b) => b.id == bowlerId).isEmpty ? null : s.bowlers.firstWhere((b) => b.id == bowlerId));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(trId('batting_2'),
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: context.cTextSecondary)),
        SizedBox(height: 8),
        ...atCrease.map((b) => _row(context,
            name: '${b.name}${b.id == striker ? '  *' : ''}',
            value: '${b.runs} (${b.balls})',
            highlight: b.id == striker)),
        if (atCrease.isEmpty)
          Text(trId('yet_to_bat'),
              style: TextStyle(color: context.cTextSecondary, fontSize: 12)),
        SizedBox(height: 18),
        Text(trId('bowling_2'),
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: context.cTextSecondary)),
        SizedBox(height: 8),
        if (bowler != null)
          _row(context,
              name: bowler.name,
              value: '${bowler.legalBalls ~/ 6}.${bowler.legalBalls % 6}-${bowler.runs}-${bowler.wickets}')
        else
          Text(trId('str'), style: TextStyle(color: context.cTextSecondary)),
      ],
    );
  }

  Widget _row(BuildContext context, {required String name, required String value, bool highlight = false}) {
    return Container(
      margin: EdgeInsets.only(bottom: 8),
      padding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: context.cSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: highlight ? AppColors.primary.withOpacity(0.4) : context.cBorder),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    fontSize: 14, fontWeight: highlight ? FontWeight.w800 : FontWeight.w600, color: context.cText)),
          ),
          Text(value, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.primary)),
        ],
      ),
    );
  }
}
