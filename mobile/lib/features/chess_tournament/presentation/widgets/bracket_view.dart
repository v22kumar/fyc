import 'package:flutter/material.dart';

import '../../../../core/l10n/tr.dart';
import '../../../../core/theme/app_theme.dart';
import '../../domain/entities/tournament_entities.dart';

/// The bracket: a scoreboard, and nothing but.
///
/// The previous bracket was the whole feature — every control lived inside a
/// pannable 600px canvas that always opened on round 1, so the semi-finals
/// were played while the screen showed the quarter-finals, and a finished
/// tournament never showed you the final. The controls have moved to the
/// player card and the organiser board; what remains is a projection, and a
/// projection's one job is to show *now* — so it opens scrolled to the
/// current round, and on a completed tournament, to the final.
///
/// The winner's mark is drawn, not the '👑' emoji, which rendered as a tofu
/// box on the handsets this club actually uses.
class BracketView extends StatefulWidget {
  const BracketView({
    super.key,
    required this.detail,
    this.highlightUid,
    this.roundName,
  });

  final TournamentDetail detail;

  /// The signed-in member, so their own path through the draw reads bolder.
  final String? highlightUid;

  final String Function(int round)? roundName;

  static const columnWidth = 264.0;
  static const columnGap = 20.0;

  @override
  State<BracketView> createState() => _BracketViewState();
}

class _BracketViewState extends State<BracketView> {
  late final ScrollController _horizontal;

  @override
  void initState() {
    super.initState();
    // Open on the round that matters: the current one while play is on, the
    // final once it is over. This one line is the fix for the walkthrough's
    // sharpest finding.
    final d = widget.detail;
    final focusRound =
        d.isCompleted ? d.rounds : (d.currentRound > 0 ? d.currentRound : 1);
    final offset =
        (focusRound - 1) * (BracketView.columnWidth + BracketView.columnGap);
    _horizontal = ScrollController(initialScrollOffset: offset);
  }

  @override
  void dispose() {
    _horizontal.dispose();
    super.dispose();
  }

  String _round(int r) => widget.roundName?.call(r) ?? '${trId('round')} $r';

  @override
  Widget build(BuildContext context) {
    final d = widget.detail;
    if (d.matches.isEmpty) return const SizedBox.shrink();

    final byRound = <int, List<BracketMatch>>{};
    for (final m in d.matches) {
      byRound.putIfAbsent(m.round, () => []).add(m);
    }
    final rounds = byRound.keys.toList()..sort();

    return SingleChildScrollView(
      controller: _horizontal,
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final r in rounds) ...[
            SizedBox(
              width: BracketView.columnWidth,
              child: _roundColumn(context, d, r, byRound[r]!),
            ),
            if (r != rounds.last)
              const SizedBox(width: BracketView.columnGap),
          ],
        ],
      ),
    );
  }

  Widget _roundColumn(BuildContext context, TournamentDetail d, int r,
      List<BracketMatch> matches) {
    matches.sort((a, b) => a.slot.compareTo(b.slot));
    final isCurrent = r == d.currentRound && d.inProgress;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          height: 34,
          alignment: Alignment.center,
          margin: const EdgeInsets.only(bottom: 10),
          decoration: BoxDecoration(
            color: isCurrent
                ? AppColors.primary.withValues(alpha: 0.1)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(17),
            border: Border.all(
                color: isCurrent ? AppColors.primary : context.cBorder),
          ),
          child: Text(
            _round(r),
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 13,
              color: isCurrent ? AppColors.primary : context.cTextSecondary,
            ),
          ),
        ),
        // Compact rows, not 180px cells around 60px of content. Alignment
        // across rounds is sacrificed for legibility on a phone; the diagram's
        // job here is "who plays whom and who won", not print typography.
        for (final m in matches) _matchTile(context, m),
      ],
    );
  }

  Widget _matchTile(BuildContext context, BracketMatch m) {
    final live = m.status == MatchStatus.live;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: context.cSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: live ? AppColors.danger : context.cBorder,
          width: live ? 1.4 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _side(context, m, m.playerA, isA: true),
          Divider(height: 10, color: context.cBorder),
          _side(context, m, m.playerB, isA: false),
          if (live) ...[
            const SizedBox(height: 6),
            Row(children: [
              Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                      shape: BoxShape.circle, color: AppColors.danger)),
              const SizedBox(width: 5),
              Text(trId('live_now'),
                  style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: AppColors.danger)),
            ]),
          ],
        ],
      ),
    );
  }

  Widget _side(BuildContext context, BracketMatch m, PlayerRef? p,
      {required bool isA}) {
    final won = p != null && m.winnerId == p.id;
    final mine = p != null && p.id == widget.highlightUid;
    final label = p?.name ??
        (m.status == MatchStatus.bye && !isA ? trId('bye') : trId('tbd'));
    return Row(
      children: [
        // Drawn, not the 👑 emoji: a tofu box beside the winner's name is not
        // a coronation.
        if (won)
          const Padding(
            padding: EdgeInsets.only(right: 4),
            child: Icon(Icons.emoji_events_rounded,
                size: 14, color: Color(0xFFD4AF37)),
          ),
        Expanded(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 13,
              fontWeight:
                  won || mine ? FontWeight.w800 : FontWeight.w500,
              color: p == null
                  ? context.cTextSecondary
                  : (mine ? AppColors.primary : context.cText),
            ),
          ),
        ),
      ],
    );
  }
}
