import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/design_system/components/ds_screen_header.dart';
import '../../../../core/design_system/tokens.dart';
import '../../../../core/l10n/tr.dart';
import '../../../../core/theme/app_theme.dart';
import '../../domain/entities/complaint_entities.dart' as e;
import '../bloc/complaint_bloc.dart';
import '../widgets/complaint_timeline.dart';
import '../widgets/ladder_list.dart';
import '../widgets/send_letter_sheet.dart';

/// One complaint: what to do about it, and what has happened so far.
///
/// The three routes appear in the order they are most likely to work. Calling
/// first, because most civic problems are fixed by ringing the right person and
/// a letter is the slower, colder way to ask. Writing second. Handing it to the
/// club third — for members who would rather not deal with an office at all,
/// which is a reasonable preference and not a failure on their part.
///
/// Nothing is forced, and the routes combine: calling, getting nowhere, then
/// writing is the normal path, and the letter already knows about the call.
class ComplaintDetailScreen extends StatelessWidget {
  const ComplaintDetailScreen({
    super.key,
    required this.complaintId,
    this.category,
  });

  final String complaintId;
  final String? category;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: DSScreenHeader(
        title: trId('complaint_box'),
        onBack: () => Navigator.of(context).maybePop(),
      ),
      body: BlocConsumer<ComplaintBloc, ComplaintViewState>(
        listenWhen: (a, b) =>
            (a.draft != b.draft && b.draft != null) ||
            (a.failure != b.failure && b.failure != null),
        listener: (context, state) {
          // A failed action used to be silent: `failure` was only rendered
          // when the complaint itself had not loaded, so tapping "mark
          // resolved" on a dropped connection did nothing at all and the
          // member had no way to know whether it worked.
          if (state.failure != null && state.complaint != null) {
            ScaffoldMessenger.of(context)
              ..hideCurrentSnackBar()
              ..showSnackBar(SnackBar(
                content: Text(trId('action_failed_try_again')),
                backgroundColor: AppColors.accent,
              ));
            return;
          }
          if (state.draft != null) _openSendSheet(context, state.draft!);
        },
        builder: (context, state) {
          if (state.loading) {
            return const Center(child: CircularProgressIndicator());
          }
          final c = state.complaint;
          if (c == null) {
            return _CouldNotLoad(
              onRetry: () => context
                  .read<ComplaintBloc>()
                  .add(LoadComplaint(complaintId, category: category)),
            );
          }
          return Column(
            children: [
              // Actions used to only disable their buttons. On a slow
              // connection a disabled button that never comes back is
              // indistinguishable from a broken one; this says the app is
              // still working without moving anything the member is reading.
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 180),
                child: state.busy
                    ? const LinearProgressIndicator(minHeight: 2)
                    : const SizedBox(height: 2),
              ),
              Expanded(
                child: ListView(
            padding: EdgeInsets.all(DSSpacing.md),
            children: [
              if (c.severity == e.ComplaintSeverity.serious && !c.isClosed)
                const _SeriousAdvice(),
              if (!c.isClosed) ...[
                _SectionTitle(trId('call_someone')),
                if (state.ladderFailed)
                  _LadderUnavailable(
                    onRetry: () => context
                        .read<ComplaintBloc>()
                        .add(LoadComplaint(complaintId, category: category)),
                  )
                else if (state.ladder != null)
                  LadderList(
                    ladder: state.ladder!,
                    onCalled: (rung) => _askHowItWent(context, rung),
                    // Address the letter to the office they tapped. This
                    // discarded its argument and always drafted to nobody,
                    // which made the per-rung Write button do the one thing it
                    // exists not to do.
                    onWrite: (rung) => context
                        .read<ComplaintBloc>()
                        .add(DraftRequested(authorityId: rung.authorityId)),
                  ),
                SizedBox(height: DSSpacing.md),
                _SectionTitle(trId('send_it_yourself')),
                FilledButton.icon(
                  onPressed: state.busy
                      ? null
                      : () => context
                          .read<ComplaintBloc>()
                          .add(const DraftRequested()),
                  icon: const Icon(Icons.edit_note_rounded),
                  label: Text(trId('write')),
                ),
                SizedBox(height: DSSpacing.sm),
                if (c.lane == e.ComplaintLane.self)
                  OutlinedButton.icon(
                    onPressed: state.busy
                        ? null
                        : () => context
                            .read<ComplaintBloc>()
                            .add(const HandedToClub()),
                    icon: const Icon(Icons.volunteer_activism_rounded),
                    label: Text(trId('ask_fyc_to_help')),
                  ),
                const Divider(height: 32),
              ],
              // The timeline grows as things happen. Crossfading rather than
              // snapping keeps the member's eye on the entry that changed,
              // which on a screen whose whole point is "what happened" is the
              // difference between motion that informs and motion that
              // decorates.
              AnimatedSize(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOutCubic,
                alignment: Alignment.topCenter,
                child: ComplaintTimeline(state: c),
              ),
              const Divider(height: 32),
              _Ending(state: c),
            ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  void _openSendSheet(BuildContext context, e.ComplaintDraft draft) {
    final bloc = context.read<ComplaintBloc>();
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      // A drag handle and a tall top radius are what a sheet looks like now,
      // and more usefully they tell the member this thing can be dismissed —
      // which matters when it is holding a letter they have not decided to
      // send yet.
      showDragHandle: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (_) => SendLetterSheet(
        draft: draft,
        onSentConfirmed: () => bloc.add(const SendConfirmed()),
        onBccChanged: (on) => bloc.add(DraftRequested(bccClub: on)),
      ),
    );
  }

  /// Asked after the dialler has closed, never before — and the answer is
  /// taken at face value, because nothing here can observe a phone call.
  void _askHowItWent(BuildContext context, e.LadderRung rung) {
    final bloc = context.read<ComplaintBloc>();
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (sheet) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: EdgeInsets.all(DSSpacing.md),
              child: Text(trId('how_did_the_call_go'),
                  style: Theme.of(sheet).textTheme.titleMedium),
            ),
            for (final (outcome, label) in [
              (e.CallOutcome.promised, trId('promised')),
              (e.CallOutcome.reached, trId('reached')),
              (e.CallOutcome.noAnswer, trId('no_answer')),
            ])
              ListTile(
                title: Text(label),
                onTap: () {
                  bloc.add(CallLogged(
                      outcome: outcome, authorityLabel: rung.title));
                  Navigator.of(sheet).pop();
                },
              ),
          ],
        ),
      ),
    );
  }
}

/// The contacts could not be fetched — which is not the same as there being
/// none, and must not be worded as though it were.
class _LadderUnavailable extends StatelessWidget {
  const _LadderUnavailable({required this.onRetry});
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Container(
        padding: EdgeInsets.all(DSSpacing.sm),
        decoration: BoxDecoration(
          color: context.cSurface,
          borderRadius: BorderRadius.circular(DSRadius.card),
          border: Border.all(color: context.cBorder),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(trId('contacts_unavailable'),
                  style: Theme.of(context).textTheme.bodyMedium),
            ),
            TextButton(onPressed: onRetry, child: Text(trId('try_again'))),
          ],
        ),
      );
}

/// Nothing loaded, and a way to try again.
///
/// The previous version was a centred sentence with no action, which on a
/// patchy connection is a dead end — and a dead end on the screen a member
/// opened to report a problem is the worst place to have one.
class _CouldNotLoad extends StatelessWidget {
  const _CouldNotLoad({required this.onRetry});
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: EdgeInsets.all(DSSpacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.wifi_off_rounded,
                  size: 40, color: context.cTextSecondary),
              SizedBox(height: DSSpacing.sm),
              Text(trId('could_not_load'),
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleSmall),
              SizedBox(height: DSSpacing.xs),
              Text(trId('check_connection'),
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall),
              SizedBox(height: DSSpacing.md),
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

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: EdgeInsets.only(bottom: DSSpacing.xs),
        child: Text(text, style: Theme.of(context).textTheme.titleMedium),
      );
}

/// Shown for serious complaints only. A call leaves no evidence; a letter is
/// dated, addressed and quotable. Advice, never a block.
class _SeriousAdvice extends StatelessWidget {
  const _SeriousAdvice();

  @override
  Widget build(BuildContext context) => Container(
        margin: EdgeInsets.only(bottom: DSSpacing.md),
        padding: EdgeInsets.all(DSSpacing.sm),
        decoration: BoxDecoration(
          color: AppColors.warning.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(DSRadius.card),
        ),
        child: Row(
          children: [
            Icon(Icons.description_outlined, color: AppColors.warning),
            SizedBox(width: DSSpacing.xs),
            Expanded(
              child: Text(trId('serious_write_instead'),
                  style: Theme.of(context).textTheme.bodyMedium),
            ),
          ],
        ),
      );
}

/// Ending it, available whatever the app knows.
///
/// Somebody who fixed the problem by walking into the office must be able to
/// say so. A complaint that can only be closed by an event we can observe stays
/// open forever, and a list full of dead complaints is a list nobody opens.
class _Ending extends StatelessWidget {
  const _Ending({required this.state});
  final e.ComplaintState state;

  @override
  Widget build(BuildContext context) {
    if (state.isClosed) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (state.closedReason != null)
            Text(state.closedReason!,
                style: Theme.of(context).textTheme.bodyMedium),
          SizedBox(height: DSSpacing.xs),
          OutlinedButton.icon(
            onPressed: () =>
                context.read<ComplaintBloc>().add(const Reopened()),
            icon: const Icon(Icons.refresh_rounded),
            label: Text(trId('reopen')),
          ),
        ],
      );
    }
    return Row(
      children: [
        Expanded(
          child: FilledButton.icon(
            onPressed: () {
              // Ending a complaint stops the nudges and takes it off the
              // active list. Worth a tick of feedback, not worth a dialog —
              // reopening is one tap, so a mistake costs nothing.
              HapticFeedback.mediumImpact();
              context.read<ComplaintBloc>().add(const Closed(resolved: true));
            },
            icon: const Icon(Icons.check_circle_outline_rounded),
            label: Text(trId('mark_resolved')),
          ),
        ),
        SizedBox(width: DSSpacing.xs),
        Expanded(
          child: OutlinedButton(
            onPressed: () {
              HapticFeedback.selectionClick();
              context.read<ComplaintBloc>().add(const Closed(resolved: false));
            },
            child: Text(trId('mark_closed')),
          ),
        ),
      ],
    );
  }
}
