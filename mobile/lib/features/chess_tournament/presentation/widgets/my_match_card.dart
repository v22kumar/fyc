import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/l10n/tr.dart';
import '../../../../core/theme/app_theme.dart';
import '../../domain/entities/tournament_entities.dart';

/// The player's whole tournament, in one card at the top of the screen.
///
/// This is the surface that did not exist. The Ready button, the Play button,
/// the walkover claim and the venue all lived inside a pannable bracket
/// diagram, so a player's first job was to find their own name on a canvas.
/// A player must never need the bracket to participate: the card answers
/// *what do I do next* for every state the domain can produce, and when there
/// is nothing to do it says who they are waiting for instead of going blank.
class MyMatchCard extends StatelessWidget {
  const MyMatchCard({
    super.key,
    required this.detail,
    required this.uid,
    required this.busy,
    required this.onReady,
    required this.onPlay,
    required this.onClaimWalkover,
    this.roundName,
  });

  final TournamentDetail detail;
  final String uid;
  final bool busy;
  final ValueChanged<String> onReady;
  final ValueChanged<String> onPlay;
  final ValueChanged<String> onClaimWalkover;

  /// Names a round for people ("Semi-finals"), injected so the card carries
  /// no copy of the naming rule.
  final String Function(int round)? roundName;

  String _round(int r) => roundName?.call(r) ?? '${trId('round')} $r';

  @override
  Widget build(BuildContext context) {
    final match = detail.myMatch(uid);

    // Knocked out: say so plainly, with who — then get out of the way.
    if (match == null) {
      if (!detail.stillIn(uid)) {
        final loss = detail.matches
            .where((m) =>
                m.involves(uid) && m.isDecided && m.winnerId != uid)
            .toList();
        if (loss.isEmpty) return const SizedBox.shrink();
        final beatenBy = loss.last.opponentOf(uid)?.name ?? '';
        return _shell(
          context,
          tint: AppColors.textSecondary,
          child: Text(trId('youre_out', {'name': beatenBy}),
              style: Theme.of(context).textTheme.titleSmall),
        );
      }
      // Still in with nothing playable: through to a future round, or champion.
      if (detail.isCompleted && detail.champion?.id == uid) {
        return const SizedBox.shrink(); // the champion banner says it better
      }
      final next = detail.matches
          .where((m) => m.involves(uid) && !m.isDecided)
          .toList();
      if (next.isEmpty && detail.inProgress) {
        return _shell(
          context,
          tint: AppColors.success,
          child: Text(
              trId('youre_through', {'round': _round(detail.currentRound + 1)}),
              style: Theme.of(context).textTheme.titleSmall),
        );
      }
      return const SizedBox.shrink();
    }

    final action = match.actionFor(uid);
    final opponent = match.opponentOf(uid);
    final theme = Theme.of(context);

    return _shell(
      context,
      tint: AppColors.primary,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Both flexible: "உங்கள் ஆட்டம்" beside "காலிறுதிப் போட்டிகள்"
              // overflows a 390px card, and the widget test caught the English
              // pair doing it too.
              Flexible(
                child: Text(trId('your_match'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelSmall
                        ?.copyWith(color: AppColors.primary)),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(_round(match.round),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.right,
                    style: theme.textTheme.labelSmall),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            opponent != null
                ? trId('you_vs', {'name': opponent.name})
                : trId('tbd'),
            style: theme.textTheme.titleMedium,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 10),
          ..._body(context, match, action, opponent),
        ],
      ),
    );
  }

  List<Widget> _body(BuildContext context, BracketMatch match,
      MatchAction action, PlayerRef? opponent) {
    final theme = Theme.of(context);
    switch (action) {
      case MatchAction.ready:
        return [
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: busy ? null : () => onReady(match.id),
              icon: const Icon(Icons.front_hand_rounded, size: 18),
              label: Text(trId('im_ready')),
            ),
          ),
        ];
      case MatchAction.waitOpponent:
        return [
          Text(
            trId('waiting_for_opponent', {'name': opponent?.name ?? ''}),
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: 8),
          // The way past a no-show lives where the waiting happens. The server
          // decides whether the timeout has passed and says so if not.
          OutlinedButton(
            onPressed: busy ? null : () => onClaimWalkover(match.id),
            child: Text(trId('claim_walkover_now'),
                textAlign: TextAlign.center),
          ),
        ];
      case MatchAction.play:
        return [
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: busy ? null : () => onPlay(match.id),
              icon: const Icon(Icons.play_arrow_rounded),
              label: Text(trId('play_now')),
            ),
          ),
        ];
      case MatchAction.resume:
        return [
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: busy ? null : () => onPlay(match.id),
              icon: const Icon(Icons.play_arrow_rounded),
              label: Text(trId('return_to_board')),
            ),
          ),
        ];
      case MatchAction.attendVenue:
        final when = match.reportingTime != null
            ? ' · ${trId('report_by', {
                'time': DateFormat('d MMM, h:mm a').format(match.reportingTime!)
              })}'
            : '';
        return [
          Row(
            children: [
              Icon(Icons.groups_rounded,
                  size: 16, color: context.cTextSecondary),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  match.venue != null
                      ? '${trId('report_at', {'venue': match.venue})}$when'
                      : trId('played_at_venue'),
                  style: theme.textTheme.bodySmall,
                ),
              ),
            ],
          ),
        ];
      case MatchAction.waitRound:
        return [
          Text(
            trId('round_not_started', {'round': _round(match.round)}),
            style: theme.textTheme.bodySmall,
          ),
        ];
      case MatchAction.claimWalkover:
      case MatchAction.none:
        return const [];
    }
  }

  Widget _shell(BuildContext context,
          {required Color tint, required Widget child}) =>
      Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: context.cSurface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: tint.withValues(alpha: 0.45), width: 1.4),
        ),
        child: child,
      );
}
