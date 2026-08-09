import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/l10n/tr.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../auth/presentation/bloc/auth_state.dart';
import '../../domain/entities/tournament_entities.dart';
import '../bloc/tournament_bloc.dart';
import '../widgets/bracket_view.dart';
import '../widgets/my_match_card.dart';
import '../widgets/round_board.dart';

/// One tournament, three kinds of reader.
///
/// The 705-line predecessor served everyone with a single pannable bracket
/// that carried every control. This screen is a composition instead:
///
/// * the **player's card** first — what do I do next, without the bracket;
/// * the **organiser's board** — what blocks this round, and the button that
///   unblocks each row;
/// * the **bracket** last — read-only, opened on the round being played.
///
/// Which sections render is a function of the domain state and the viewer's
/// role; nothing here computes a tournament rule.
class TournamentScreen extends StatelessWidget {
  const TournamentScreen({super.key, required this.tournamentId});

  final String tournamentId;

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthBloc>().state;
    final uid = auth is AuthAuthenticated ? auth.user.id : null;
    final isAdmin = auth is AuthAuthenticated && auth.user.isAdmin;

    return BlocConsumer<TournamentBloc, TournamentState>(
      listenWhen: (a, b) =>
          (a.openGame != b.openGame && b.openGame != null) ||
          (a.failure != b.failure && b.failure != null),
      listener: (context, state) async {
        final ticket = state.openGame;
        if (ticket != null) {
          await context.push('/chess/online/${ticket.gameId}',
              extra: {'token': ticket.token, 'color': ticket.color});
          if (context.mounted) {
            context.read<TournamentBloc>().add(const TournamentRefreshed());
          }
          return;
        }
        if (state.failure != null) {
          // The server's own sentence — "Please wait ~3 more minutes" from a
          // walkover, "Finish the current round first" from next-round — is
          // the message. A generic "action failed" would erase exactly the
          // words that tell the person what to do.
          ScaffoldMessenger.of(context)
            ..hideCurrentSnackBar()
            ..showSnackBar(SnackBar(
              content: Text(state.failure!),
              backgroundColor: AppColors.accent,
              duration: const Duration(seconds: 5),
            ));
        }
      },
      builder: (context, state) {
        final d = state.detail;
        return Scaffold(
          backgroundColor: context.cBackground,
          appBar: AppBar(title: Text(d?.name ?? trId('tournament_3'))),
          body: state.loading
              ? const Center(child: CircularProgressIndicator())
              : d == null
                  ? _CouldNotLoad(
                      message: state.failure,
                      onRetry: () => context
                          .read<TournamentBloc>()
                          .add(TournamentRequested(tournamentId)),
                    )
                  : RefreshIndicator(
                      onRefresh: () async => context
                          .read<TournamentBloc>()
                          .add(const TournamentRefreshed()),
                      child: _Body(
                          detail: d,
                          uid: uid,
                          isAdmin: isAdmin,
                          busy: state.busy),
                    ),
        );
      },
    );
  }
}

class _Body extends StatelessWidget {
  const _Body(
      {required this.detail,
      required this.uid,
      required this.isAdmin,
      required this.busy});

  final TournamentDetail detail;
  final String? uid;
  final bool isAdmin;
  final bool busy;

  String _roundName(int r) {
    final total = detail.rounds;
    if (total == 0) return '${trId('round')} $r';
    if (r == total) return trId('final');
    if (r == total - 1) return trId('semi_finals');
    if (r == total - 2) return trId('quarter_finals');
    return '${trId('round')} $r';
  }

  @override
  Widget build(BuildContext context) {
    final bloc = context.read<TournamentBloc>();
    final d = detail;
    final children = <Widget>[
      // The thin progress line: actions keep the screen in place, but the
      // member must be able to see the app is working.
      AnimatedSwitcher(
        duration: const Duration(milliseconds: 180),
        child: busy
            ? const LinearProgressIndicator(minHeight: 2)
            : const SizedBox(height: 2),
      ),
      const SizedBox(height: 8),
    ];

    if (d.status == TournamentStatus.unknown) {
      children.add(_Notice(
          title: trId('state_unknown'), body: trId('state_unknown_help')));
    }

    if (d.champion != null) children.add(_ChampionBanner(detail: d));

    if ((d.description ?? '').isNotEmpty) {
      children.add(Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Text(d.description!,
            style:
                TextStyle(color: context.cTextSecondary, height: 1.4)),
      ));
    }

    // ── Player first. Always. ────────────────────────────────────────────
    if (d.inProgress || d.isCompleted) {
      if (uid != null && d.matches.any((m) => m.involves(uid))) {
        children.add(MyMatchCard(
          detail: d,
          uid: uid!,
          busy: busy,
          roundName: _roundName,
          onReady: (id) => bloc.add(ReadyPressed(id)),
          onPlay: (id) => bloc.add(PlayPressed(id, uid: uid!)),
          onClaimWalkover: (id) => _confirmWalkover(context, id),
        ));
      }
    }

    // ── Registration stages ──────────────────────────────────────────────
    if (d.isOpen || d.isClosed) {
      children.add(_RegistrationCard(
          detail: d, uid: uid, isAdmin: isAdmin, busy: busy));
      if (isAdmin && d.pendingEntries.isNotEmpty) {
        children.add(_ApprovalsCard(detail: d, busy: busy));
      }
      // The roster, at the one moment it matters most: the irreversible
      // "draw the bracket" press. It used to vanish the moment the last
      // pending entry was decided, so the eight people about to be drawn
      // were nowhere on the screen that draws them.
      if (d.approvedEntries.isNotEmpty) {
        children.add(_RosterCard(detail: d));
      }
    }

    // ── Organiser board ──────────────────────────────────────────────────
    if (isAdmin && d.inProgress) {
      children.add(RoundBoard(
        detail: d,
        busy: busy,
        roundName: _roundName,
        onStartNextRound: () => bloc.add(const NextRoundPressed()),
        onRecordResult: (m, winner) => _confirmResult(context, m, winner),
      ));
      children.add(_ConductCard(detail: d, busy: busy, roundName: _roundName));
    }

    // ── The scoreboard ───────────────────────────────────────────────────
    if (d.matches.isNotEmpty) {
      children.add(const SizedBox(height: 4));
      children.add(Text(trId('tournament_bracket'),
          style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              color: context.cText)));
      children.add(const SizedBox(height: 10));
      children.add(
          BracketView(detail: d, highlightUid: uid, roundName: _roundName));
    }

    if (d.shortCode != null) children.add(_ShareCode(code: d.shortCode!));

    return ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24), children: children);
  }

  Future<void> _confirmWalkover(BuildContext context, String matchId) async {
    final bloc = context.read<TournamentBloc>();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(trId('claim_walkover')),
        content: Text(trId('claim_walkover_confirm')),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(trId('cancel_2'))),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(trId('claim_walkover'))),
        ],
      ),
    );
    if (ok == true) bloc.add(WalkoverClaimed(matchId));
  }

  Future<void> _confirmResult(
      BuildContext context, BracketMatch m, PlayerRef winner) async {
    final bloc = context.read<TournamentBloc>();
    // Recording a result is irreversible and names a person; it is worth one
    // deliberate confirmation naming them back.
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(trId('record_winner')),
        content: Text('${trId('win')}: ${winner.name}?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(trId('cancel_2'))),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(trId('record_winner'))),
        ],
      ),
    );
    if (ok == true) {
      bloc.add(ResultReported(m.id, winnerId: winner.id));
    }
  }
}

// ── Sections ─────────────────────────────────────────────────────────────────

class _ChampionBanner extends StatelessWidget {
  const _ChampionBanner({required this.detail});
  final TournamentDetail detail;

  @override
  Widget build(BuildContext context) {
    final finalMatch = detail.finalMatch;
    final runnerUp = finalMatch == null || detail.champion == null
        ? null
        : (finalMatch.playerA?.id == detail.champion!.id
            ? finalMatch.playerB
            : finalMatch.playerA);
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
            colors: [Color(0xFFD4AF37), Color(0xFFF0C75E)]),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(children: [
        const Icon(Icons.emoji_events_rounded, size: 34, color: Colors.white),
        const SizedBox(width: 12),
        Expanded(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(trId('champion'),
                style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                    fontWeight: FontWeight.w700)),
            Text(detail.champion!.name,
                style: TextStyle(
                    color: AppColors.background,
                    fontSize: 18,
                    fontWeight: FontWeight.w900)),
            if (runnerUp != null)
              Text('${trId('vs_2')} ${runnerUp.name}',
                  style:
                      const TextStyle(color: Colors.white70, fontSize: 12)),
          ]),
        ),
      ]),
    );
  }
}

class _RegistrationCard extends StatelessWidget {
  const _RegistrationCard(
      {required this.detail,
      required this.uid,
      required this.isAdmin,
      required this.busy});

  final TournamentDetail detail;
  final String? uid;
  final bool isAdmin;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final bloc = context.read<TournamentBloc>();
    final d = detail;
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
          color: context.cSurface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: context.cBorder)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Wrap, not Row: "8 approved" + "3 pending" + "Registration closed"
        // is three labels in two languages, and a Row overflowed at 390px in
        // the widget test before a single Tamil string was involved.
        Wrap(
          spacing: 8,
          runSpacing: 6,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text('${d.entryCount} ${trId('approved')}',
                style: theme.textTheme.titleSmall),
            if (d.pendingCount > 0)
              _pill(context, '${d.pendingCount} ${trId('pending')}',
                  AppColors.warning),
            if (d.isClosed)
              _pill(context, trId('registration_closed_on'),
                  context.cTextSecondary),
          ],
        ),
        // The deadline: fetched, parsed and dropped by the old screen — the
        // one fact a member needs while registration is open.
        if (d.isOpen && d.registrationDeadline != null) ...[
          const SizedBox(height: 6),
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Icon(Icons.schedule_rounded,
                  size: 14, color: context.cTextSecondary),
            ),
            const SizedBox(width: 5),
            // Expanded, because at a 1.3× system font this line overflowed by
            // 435px — big fonts wrap the date to a second line instead.
            Expanded(
              child: Text(
                trId('closes_on', {
                  'date': DateFormat('EEE d MMM, h:mm a')
                      .format(d.registrationDeadline!)
                }),
                style: theme.textTheme.bodySmall,
              ),
            ),
          ]),
        ],
        const SizedBox(height: 10),
        if (uid != null && !d.isRegistered && d.isOpen)
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: busy ? null : () => bloc.add(const RegisterPressed()),
              icon: const Icon(Icons.how_to_reg_rounded, size: 18),
              label: Text(trId('register_to_play')),
            ),
          )
        else if (d.isRegistered)
          _myStatus(context, d.myStatus),
        if (isAdmin) ...[
          const SizedBox(height: 8),
          if (d.isOpen)
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: busy
                    ? null
                    : () => bloc.add(const CloseRegistrationPressed()),
                icon: const Icon(Icons.lock_clock_rounded, size: 18),
                label: Text(trId('close_registration_3')),
              ),
            ),
          if (d.isClosed) ...[
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed:
                    busy ? null : () => bloc.add(const StartTournamentPressed()),
                icon: const Icon(Icons.play_circle_rounded, size: 18),
                label: Text(trId('start_tournament_draw_bracket')),
              ),
            ),
            const SizedBox(height: 6),
            Center(
              child: TextButton.icon(
                onPressed: busy
                    ? null
                    : () => bloc.add(const ReopenRegistrationPressed()),
                icon: const Icon(Icons.lock_open_rounded, size: 16),
                label: Text(trId('reopen_registration')),
              ),
            ),
          ],
        ],
      ]),
    );
  }

  Widget _myStatus(BuildContext context, String? status) {
    final (icon, color, text) = switch (status) {
      'PENDING' => (
          Icons.hourglass_top_rounded,
          AppColors.warning,
          trId('registered_waiting_for_approval')
        ),
      'REJECTED' => (
          Icons.block_rounded,
          AppColors.danger,
          trId('registration_declined')
        ),
      _ => (
          Icons.check_circle_rounded,
          AppColors.success,
          trId('youre_in_the_draw')
        ),
    };
    return Row(children: [
      Icon(icon, size: 18, color: color),
      const SizedBox(width: 8),
      Expanded(
          child: Text(text,
              style: TextStyle(fontWeight: FontWeight.w700, color: color))),
    ]);
  }

  Widget _pill(BuildContext context, String label, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
            color: color.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(20)),
        child: Text(label,
            style: TextStyle(
                fontSize: 10.5, fontWeight: FontWeight.w800, color: color)),
      );
}

class _ApprovalsCard extends StatelessWidget {
  const _ApprovalsCard({required this.detail, required this.busy});
  final TournamentDetail detail;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final bloc = context.read<TournamentBloc>();
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
          color: context.cSurface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: context.cBorder)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(trId('pending_approvals'),
            style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 2),
        Text(trId('only_approved_players_enter_the_bracket'),
            style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: 6),
        for (final e in detail.pendingEntries)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(children: [
              Expanded(
                  child: Text(e.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w600))),
              IconButton(
                onPressed: busy
                    ? null
                    : () =>
                        bloc.add(RegistrationDecided(e.id, approve: true)),
                icon: Icon(Icons.check_circle_rounded,
                    color: AppColors.success),
                tooltip: trId('approve'),
              ),
              IconButton(
                onPressed: busy
                    ? null
                    : () =>
                        bloc.add(RegistrationDecided(e.id, approve: false)),
                icon: Icon(Icons.cancel_rounded, color: AppColors.danger),
                tooltip: trId('reject'),
              ),
            ]),
          ),
      ]),
    );
  }
}

/// The approved list, visible at the moment the draw is made from it.
class _RosterCard extends StatelessWidget {
  const _RosterCard({required this.detail});
  final TournamentDetail detail;

  @override
  Widget build(BuildContext context) {
    final players = detail.approvedEntries;
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
          color: context.cSurface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: context.cBorder)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(trId('approved_players'),
            style: Theme.of(context).textTheme.titleSmall),
        if (detail.isClosed) ...[
          const SizedBox(height: 2),
          Text(trId('these_enter_the_draw', {'n': players.length}),
              style: Theme.of(context).textTheme.bodySmall),
        ],
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final p in players)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: context.cBackground,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: context.cBorder),
                ),
                child: Text(p.name,
                    style: const TextStyle(
                        fontSize: 12.5, fontWeight: FontWeight.w600)),
              ),
          ],
        ),
      ]),
    );
  }
}

/// Organiser: switch a semi-final/final between in-app and in-person.
class _ConductCard extends StatelessWidget {
  const _ConductCard(
      {required this.detail, required this.busy, required this.roundName});
  final TournamentDetail detail;
  final bool busy;
  final String Function(int) roundName;

  @override
  Widget build(BuildContext context) {
    final eligible = detail.matches
        .where((m) =>
            m.round >= detail.rounds - 1 &&
            m.bothSeated &&
            !m.isDecided)
        .toList();
    if (eligible.isEmpty) return const SizedBox.shrink();

    final bloc = context.read<TournamentBloc>();
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
          color: context.cSurface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: context.cBorder)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(trId('conduct'), style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 6),
        for (final m in eligible)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            // Label above the toggle: two segment labels in Tamil beside a
            // match title do not share 330px, and the widget test proved even
            // English loses by half a pixel.
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
              Text(
                '${roundName(m.round)} · ${m.playerA!.name} ${trId('vs_2')} ${m.playerB!.name}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12.5),
              ),
              const SizedBox(height: 6),
              SegmentedButton<String>(
                segments: [
                  ButtonSegment(
                      value: 'APP', label: Text(trId('in_app'))),
                  ButtonSegment(
                      value: 'PHYSICAL', label: Text(trId('in_person'))),
                ],
                selected: {m.isPhysical ? 'PHYSICAL' : 'APP'},
                showSelectedIcon: false,
                style: const ButtonStyle(
                    visualDensity: VisualDensity.compact),
                onSelectionChanged: busy
                    ? null
                    : (sel) => sel.first == 'PHYSICAL'
                        ? _pickVenue(context, bloc, m)
                        : bloc.add(ConductChanged(m.id, mode: 'APP')),
              ),
            ]),
          ),
      ]),
    );
  }

  Future<void> _pickVenue(
      BuildContext context, TournamentBloc bloc, BracketMatch m) async {
    final venue = TextEditingController(text: m.venue ?? '');
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(trId('in_person')),
        content: TextField(
          controller: venue,
          decoration: InputDecoration(labelText: trId('venue')),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(trId('cancel_2'))),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(trId('save'))),
        ],
      ),
    );
    if (ok == true) {
      bloc.add(ConductChanged(m.id,
          mode: 'PHYSICAL',
          venue: venue.text.trim().isEmpty ? null : venue.text.trim()));
    }
  }
}

class _ShareCode extends StatelessWidget {
  const _ShareCode({required this.code});
  final String code;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          Clipboard.setData(ClipboardData(text: code));
          ScaffoldMessenger.of(context)
            ..hideCurrentSnackBar()
            ..showSnackBar(SnackBar(content: Text(trId('copied'))));
        },
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(Icons.link_rounded, size: 16, color: context.cTextSecondary),
          const SizedBox(width: 6),
          Text('${trId('share_code')}: $code',
              style: TextStyle(
                  fontWeight: FontWeight.w800,
                  color: context.cTextSecondary)),
        ]),
      ),
    );
  }
}

class _Notice extends StatelessWidget {
  const _Notice({required this.title, required this.body});
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.warning.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 4),
          Text(body, style: Theme.of(context).textTheme.bodySmall),
        ]),
      );
}

class _CouldNotLoad extends StatelessWidget {
  const _CouldNotLoad({required this.onRetry, this.message});
  final VoidCallback onRetry;
  final String? message;

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.wifi_off_rounded,
                  size: 40, color: context.cTextSecondary),
              const SizedBox(height: 10),
              Text(message ?? trId('could_not_load'),
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium),
              const SizedBox(height: 14),
              FilledButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded),
                label: Text(trId('try_again')),
              ),
            ],
          ),
        ),
      );
}
