import 'package:flutter/material.dart';

import '../../../../core/l10n/tr.dart';
import '../../../../core/theme/app_theme.dart';
import '../../domain/entities/tournament_entities.dart';

/// The organiser's worklist: what is blocking this round, and the button that
/// unblocks each row.
///
/// This surface replaces running the event through the bracket diagram, where
/// by round two the result buttons sat 340px off the right edge of a 390px
/// phone. A vertical list has no off-screen: every undecided match is a row,
/// every row carries its action, and when the list is empty the next round's
/// start button appears in its place.
class RoundBoard extends StatelessWidget {
  const RoundBoard({
    super.key,
    required this.detail,
    required this.busy,
    required this.onRecordResult,
    required this.onStartNextRound,
    this.roundName,
  });

  final TournamentDetail detail;
  final bool busy;
  final void Function(BracketMatch match, PlayerRef winner) onRecordResult;
  final VoidCallback onStartNextRound;
  final String Function(int round)? roundName;

  String _round(int r) => roundName?.call(r) ?? '${trId('round')} $r';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final blocking = detail.blocking;
    final nextName = _round(detail.currentRound + 1);

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.cSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.cBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(trId('running_the_round', {'round': _round(detail.currentRound)}),
              style: theme.textTheme.titleSmall),
          const SizedBox(height: 4),
          Text(
            blocking.isEmpty
                ? trId('round_all_done', {'round': nextName})
                : blocking.length == 1
                    ? trId('one_match_blocks', {'round': nextName})
                    : trId('n_matches_block',
                        {'n': blocking.length, 'round': nextName}),
            style: theme.textTheme.bodySmall?.copyWith(
              color: blocking.isEmpty
                  ? AppColors.success
                  : context.cTextSecondary,
            ),
          ),
          const SizedBox(height: 10),
          for (final m in blocking) _row(context, m),
          if (detail.canStartNextRound)
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: busy ? null : onStartNextRound,
                icon: const Icon(Icons.skip_next_rounded),
                label: Text(trId('start_round_n', {'round': nextName})),
              ),
            ),
        ],
      ),
    );
  }

  Widget _row(BuildContext context, BracketMatch m) {
    final theme = Theme.of(context);
    final a = m.playerA;
    final b = m.playerB;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: context.cBackground,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: m.status == MatchStatus.live
              ? AppColors.danger
              : context.cBorder,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '${a?.name ?? trId('tbd')} ${trId('vs_2')} ${b?.name ?? trId('tbd')}',
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(fontWeight: FontWeight.w600),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              _statusChip(context, m),
            ],
          ),
          if (m.bothSeated && !m.isDecided) ...[
            const SizedBox(height: 8),
            // Which button decides which player is explicit, not positional:
            // long Tamil names truncate, and a truncated label on the wrong
            // side of a Row is how the wrong winner gets recorded.
            Row(
              children: [
                Expanded(child: _winButton(context, m, a!)),
                const SizedBox(width: 8),
                Expanded(child: _winButton(context, m, b!)),
              ],
            ),
          ],
        ],
      ),
    );
  }

  // No compact density here: this tap records a winner, and 48px is the
  // floor for anything a thumb does under tournament stress — the touch
  // test measures it.
  Widget _winButton(BuildContext context, BracketMatch m, PlayerRef p) =>
      OutlinedButton(
        onPressed: busy ? null : () => onRecordResult(m, p),
        style: OutlinedButton.styleFrom(
            minimumSize: const Size(48, 48),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10)),
        child: Text('${trId('win')}: ${p.name}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 12)),
      );

  Widget _statusChip(BuildContext context, BracketMatch m) {
    final (label, color) = switch (m.status) {
      MatchStatus.live => (trId('live_now'), AppColors.danger),
      MatchStatus.ready => (trId('pending'), AppColors.warning),
      _ => (trId('pending'), Theme.of(context).disabledColor),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        if (m.status == MatchStatus.live) ...[
          Container(
              width: 6,
              height: 6,
              decoration:
                  BoxDecoration(shape: BoxShape.circle, color: color)),
          const SizedBox(width: 4),
        ],
        Text(label,
            style: TextStyle(
                fontSize: 10.5, fontWeight: FontWeight.w800, color: color)),
      ]),
    );
  }
}
