import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/design_system/components/ds_screen_header.dart';
import '../../../../core/design_system/components/ds_skeleton.dart';
import '../../../../core/design_system/tokens.dart';
import '../../../../core/l10n/tr.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../issues/domain/civic_categories.dart';
import '../../domain/entities/complaint_entities.dart' as e;
import '../bloc/complaint_list_bloc.dart';

/// Every complaint this member has, and where each one honestly stands.
///
/// What this replaced listed issues by a status column the server maintained
/// by inference: a complaint the app had never observed anything about still
/// showed "Under review", which was nobody's statement and frequently untrue.
/// This screen only ever renders things somebody said or things time can prove
/// — "You sent the letter", "Waiting to hear · 12 days", "Not sent to anyone
/// yet" — and orders them so the one being ignored the longest is on top.
///
/// The absence of news is the hardest state to render and the most important.
/// "Waiting to hear · 19 days" is the line that makes somebody act; a grey
/// "Pending" badge is the line that makes them close the app.
class MyComplaintsScreen extends StatefulWidget {
  const MyComplaintsScreen({super.key});

  @override
  State<MyComplaintsScreen> createState() => _MyComplaintsScreenState();
}

class _MyComplaintsScreenState extends State<MyComplaintsScreen> {
  @override
  void initState() {
    super.initState();
    context.read<ComplaintListBloc>().add(const ComplaintsRequested());
  }

  void _refresh() =>
      context.read<ComplaintListBloc>().add(const ComplaintsRequested());

  Future<void> _open(e.ComplaintSummary c) async {
    // Straight into the Complaint Box, carrying the category so the ladder is
    // already there when the screen opens rather than one wait later.
    await context.push('/complaints/${c.id}?category=${c.category}');
    // Something may have happened while they were in there — a call logged, a
    // letter sent, the whole thing closed. Coming back to a stale row is how a
    // list teaches people not to trust it.
    if (mounted) _refresh();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: DSScreenHeader(
        title: trId('my_complaints'),
        onBack: () => Navigator.of(context).maybePop(),
      ),
      body: BlocBuilder<ComplaintListBloc, ComplaintListState>(
        builder: (context, state) {
          if (state.loading && state.all.isEmpty) {
            return const DSSkeletonList();
          }
          if (state.failure != null && state.all.isEmpty) {
            return _CouldNotLoad(message: state.failure!, onRetry: _refresh);
          }
          if (state.isEmpty) return _NothingYet(onReport: () => context.push('/issues'));

          return RefreshIndicator(
            onRefresh: () async => _refresh(),
            child: ListView(
              padding: EdgeInsets.fromLTRB(
                  DSSpacing.md, DSSpacing.sm, DSSpacing.md, DSSpacing.xl),
              children: [
                _Segments(
                  openCount: state.open.length,
                  closedCount: state.closed.length,
                  showClosed: state.showClosed,
                  onChanged: (v) => context
                      .read<ComplaintListBloc>()
                      .add(ComplaintFilterChanged(v)),
                ),
                SizedBox(height: DSSpacing.sm),
                if (state.visible.isEmpty)
                  _NoneInThisTab(showClosed: state.showClosed)
                else
                  for (final c in state.visible) ...[
                    _ComplaintRow(summary: c, onTap: () => _open(c)),
                    SizedBox(height: DSSpacing.xs),
                  ],
              ],
            ),
          );
        },
      ),
    );
  }
}

/// Two tabs, each carrying its count.
///
/// The count is the point. "Still open · 3" answers the question the member
/// came with before they have read a single row.
class _Segments extends StatelessWidget {
  const _Segments({
    required this.openCount,
    required this.closedCount,
    required this.showClosed,
    required this.onChanged,
  });

  final int openCount, closedCount;
  final bool showClosed;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _Segment(
            label: '${trId('still_open')} · $openCount',
            selected: !showClosed,
            onTap: () => onChanged(false),
          ),
        ),
        SizedBox(width: DSSpacing.xs),
        Expanded(
          child: _Segment(
            label: '${trId('finished')} · $closedCount',
            selected: showClosed,
            onTap: () => onChanged(true),
          ),
        ),
      ],
    );
  }
}

class _Segment extends StatelessWidget {
  const _Segment(
      {required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      selected: selected,
      button: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(DSRadius.chip),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: EdgeInsets.symmetric(vertical: DSSpacing.xs),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected
                ? AppColors.primary.withValues(alpha: 0.12)
                : context.cSurface,
            borderRadius: BorderRadius.circular(DSRadius.chip),
            border: Border.all(
                color: selected ? AppColors.primary : context.cBorder),
          ),
          child: Text(
            label,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: selected ? AppColors.primary : context.cTextSecondary,
                ),
          ),
        ),
      ),
    );
  }
}

/// One complaint, said plainly.
class _ComplaintRow extends StatelessWidget {
  const _ComplaintRow({required this.summary, required this.onTap});

  final e.ComplaintSummary summary;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final s = _standing(context, summary);
    return Material(
      color: context.cSurface,
      borderRadius: BorderRadius.circular(DSRadius.card),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(DSRadius.card),
        child: Container(
          padding: EdgeInsets.all(DSSpacing.sm),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(DSRadius.card),
            border: Border.all(color: context.cBorder),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // The category, in colour borrowed from the standing. A row that
              // needs the member and a row that is finished should be
              // distinguishable before either is read.
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: s.tint.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(DSRadius.button),
                ),
                child: Icon(CivicCategory.iconFor(summary.category),
                    size: 22, color: s.tint),
              ),
              SizedBox(width: DSSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      CivicCategory.label(summary.category),
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    // Their own words, one line. The category alone does not
                    // tell somebody with four water complaints which is which.
                    Text(
                      summary.description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    if ((summary.placeName ?? '').isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Icon(Icons.place_outlined,
                              size: 13, color: context.cTextSecondary),
                          const SizedBox(width: 2),
                          Expanded(
                            child: Text(
                              summary.placeName!,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.labelSmall,
                            ),
                          ),
                        ],
                      ),
                    ],
                    SizedBox(height: DSSpacing.xs),
                    _StandingPill(standing: s),
                    // What the member last did, under the standing rather than
                    // instead of it. "Waiting to hear · 12 days" is the state;
                    // "You sent the letter" is how it got there.
                    if (s.detail != null) ...[
                      const SizedBox(height: 4),
                      Text(s.detail!,
                          style: Theme.of(context).textTheme.labelSmall),
                    ],
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: context.cTextSecondary),
            ],
          ),
        ),
      ),
    );
  }
}

class _StandingPill extends StatelessWidget {
  const _StandingPill({required this.standing});
  final _Standing standing;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: standing.tint.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(DSRadius.chip),
        ),
        child: Text(
          standing.label,
          style: Theme.of(context)
              .textTheme
              .labelSmall
              ?.copyWith(color: standing.tint),
        ),
      );
}

/// Where a complaint stands, as a sentence and a colour.
class _Standing {
  const _Standing(this.label, this.tint, {this.detail});
  final String label;
  final Color tint;

  /// The last thing somebody did, when it adds something the label does not.
  final String? detail;
}

_Standing _standing(BuildContext context, e.ComplaintSummary c) {
  if (c.isClosed) {
    final resolved = c.status == 'RESOLVED';
    return _Standing(
      resolved ? trId('resolved') : trId('closed'),
      resolved ? AppColors.success : context.cTextSecondary,
      detail: (c.closedReason ?? '').isEmpty ? null : c.closedReason,
    );
  }

  final last = _lastThing(c.lastEvent);

  if (c.lane == e.ComplaintLane.viaClub) {
    return _Standing(trId('fyc_is_handling'), AppColors.primary, detail: last);
  }

  // Nothing has left. Not a failure and not a status — a thing the member has
  // not done yet, said as such, with what to do about it.
  if (c.waitingDays == null) {
    return _Standing(trId('nothing_sent_yet'), AppColors.gold,
        detail: last ?? trId('open_it_and_act'));
  }

  if (c.lastEvent == 'REPLY_RECEIVED' || c.lastEvent == 'COPY_RECEIVED') {
    return _Standing(trId('last_they_replied'), AppColors.success,
        detail: _when(c.lastEventAt));
  }

  final d = c.waitingDays!;
  return _Standing(
    '${trId('waiting_to_hear')} · $d ${d == 1 ? trId('day') : trId('days')}',
    // Colour carries the age. Three weeks of silence should not look the same
    // as three days of it on a list somebody scans in four seconds.
    d >= 14 ? AppColors.accent : AppColors.warning,
    detail: last,
  );
}

String? _lastThing(String? event) => switch (event) {
      'CALLED' => trId('last_you_called'),
      'DRAFTED' => trId('last_you_wrote'),
      'SENT' => trId('last_you_sent'),
      'REPLY_RECEIVED' || 'COPY_RECEIVED' => trId('last_they_replied'),
      'HANDED_TO_FYC' => trId('last_fyc_has_it'),
      'FYC_FORWARDED' => trId('last_fyc_forwarded'),
      'ESCALATED' => trId('last_escalated'),
      _ => null,
    };

String? _when(DateTime? at) =>
    at == null ? null : DateFormat('d MMM').format(at);

/// Nothing has ever been reported.
class _NothingYet extends StatelessWidget {
  const _NothingYet({required this.onReport});
  final VoidCallback onReport;

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: EdgeInsets.all(DSSpacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 84,
                height: 84,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.primary.withValues(alpha: 0.10),
                ),
                child: Icon(Icons.inbox_rounded,
                    size: 38, color: AppColors.primary),
              ),
              SizedBox(height: DSSpacing.sm),
              Text(trId('no_complaints_yet'),
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleMedium),
              SizedBox(height: DSSpacing.xs),
              Text(trId('no_complaints_yet_help'),
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall),
              SizedBox(height: DSSpacing.md),
              FilledButton.icon(
                onPressed: onReport,
                icon: const Icon(Icons.add_a_photo_outlined),
                label: Text(trId('report_a_problem')),
              ),
            ],
          ),
        ),
      );
}

/// This tab is empty but the other one is not — a much smaller thing to say.
class _NoneInThisTab extends StatelessWidget {
  const _NoneInThisTab({required this.showClosed});
  final bool showClosed;

  @override
  Widget build(BuildContext context) => Padding(
        padding: EdgeInsets.symmetric(vertical: DSSpacing.xl),
        child: Center(
          child: Text(
            showClosed ? trId('no_complaints_yet') : trId('all_clear'),
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ),
      );
}

class _CouldNotLoad extends StatelessWidget {
  const _CouldNotLoad({required this.message, required this.onRetry});
  final String message;
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
              Text(trId('could_not_load_complaints'),
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleSmall),
              SizedBox(height: DSSpacing.xs),
              // The server's own words. A member who is offline and a member
              // whose session expired need different next steps.
              Text(message,
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
