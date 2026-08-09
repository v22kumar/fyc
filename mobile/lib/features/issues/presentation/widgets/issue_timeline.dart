import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/l10n/tr.dart';
import '../../../../core/theme/app_theme.dart';
import 'ladder_view.dart';
import '../../domain/repositories/civic_repository.dart';
import '../../../../service_locator.dart';

/// What happened to your complaint, and what happens next.
///
/// Every piece of this already existed on the server — the rung a complaint is
/// on, the office it went to, the date the club will be asked to climb — and
/// none of it was ever shown to the person who reported the thing. They got
/// "submitted" and then silence, which is what teaches people not to bother a
/// second time.
///
/// Two halves, because a citizen asks two different questions:
///
/// * **what has been done** — the rungs already tried, with dates
/// * **what happens if nothing comes back** — the next office by name, and the
///   date it would go there
///
/// The second half is the one that changes behaviour. "Waiting" invites a phone
/// call to the club; "Next: Block Development Office, if nothing by 14 Aug"
/// does not.
class IssueTimeline extends StatefulWidget {
  final String issueId;
  const IssueTimeline({super.key, required this.issueId});

  @override
  State<IssueTimeline> createState() => _IssueTimelineState();
}

class _IssueTimelineState extends State<IssueTimeline> {
  List<Map<String, dynamic>> _history = const [];
  Map<String, dynamic>? _route;
  Map<String, dynamic>? _issue;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant IssueTimeline old) {
    super.didUpdateWidget(old);
    // go_router reuses State across a path-parameter change, so opening a
    // second complaint from a notification would otherwise show the first one's
    // history under the second one's heading.
    if (old.issueId != widget.issueId) _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final results = await Future.wait([
        sl<CivicRepository>().history(widget.issueId),
        sl<CivicRepository>().route(widget.issueId),
        sl<CivicRepository>().issue(widget.issueId),
      ]);
      if (!mounted) return;
      setState(() {
        _history = results[0] as List<Map<String, dynamic>>;
        _route = results[1] as Map<String, dynamic>;
        _issue = results[2] as Map<String, dynamic>;
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  DateTime? _parse(Object? raw) =>
      raw is String ? DateTime.tryParse(raw)?.toLocal() : null;

  String _date(DateTime when) => DateFormat.MMMd().format(when);

  List<Map<String, dynamic>> get _rungs =>
      ((_route?['rungs'] as List?) ?? const [])
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();

  /// The office a complaint would climb to next — by name, not "the next one".
  Map<String, dynamic>? get _nextRung {
    final sent = _history.map((h) => h['position'] as int).toSet();
    for (final rung in _rungs) {
      if (rung['reachable'] == true && !sent.contains(rung['position'])) {
        return rung;
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.all(24),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    final status = _issue?['status'] as String? ?? 'NEW';
    final reviewedAt = _parse(_issue?['reviewed_at']);
    final createdAt = _parse(_issue?['created_at']);
    final dueAt = _parse(_issue?['next_action_due_at']);
    final next = _nextRung;

    final steps = <_Step>[
      if (createdAt != null)
        _Step(trId('timeline_reported'), _date(createdAt), done: true),
      if (reviewedAt != null)
        _Step(trId('timeline_reviewed'), _date(reviewedAt), done: true),
      for (final sent in _history)
        _Step(
          trId('timeline_sent_to', {'office': sent['sent_to_label'] ?? ''}),
          () {
            final at = _parse(sent['dispatched_at']);
            return at == null ? '' : _date(at);
          }(),
          done: true,
        ),
      if (status == 'RESOLVED') _Step(trId('timeline_fixed'), '', done: true),
      if (status == 'REJECTED')
        _Step(trId('timeline_not_sent'), _issue?['review_note'] as String? ?? '',
            done: true),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(trId('timeline_title'),
            style: TextStyle(
                fontSize: 16, fontWeight: FontWeight.w800, color: context.cText)),
        const SizedBox(height: 12),
        if (steps.isEmpty)
          Text(trId('timeline_nothing_yet'),
              style: TextStyle(fontSize: 13, color: context.cTextSecondary))
        else
          for (var i = 0; i < steps.length; i++)
            _StepRow(step: steps[i], isLast: i == steps.length - 1 && next == null),
        // What happens if nobody answers — the half that stops the phone call.
        if (next != null && status != 'RESOLVED' && status != 'REJECTED') ...[
          _StepRow(
            step: _Step(
              trId('timeline_next_is', {
                'office': next['designation_en'] ?? next['department_name_en'] ?? '',
              }),
              dueAt == null
                  ? trId('timeline_waiting')
                  : trId('timeline_expected_by', {'date': _date(dueAt)}),
              done: false,
            ),
            isLast: true,
          ),
        ],
        const SizedBox(height: 18),
        // The full route underneath, so "next" has somewhere visible to lead.
        LadderView(
          rungs: _rungs,
          currentPosition: _issue?['current_position'] as int?,
        ),
      ],
    );
  }
}

class _Step {
  final String label;
  final String detail;
  final bool done;
  const _Step(this.label, this.detail, {required this.done});
}

class _StepRow extends StatelessWidget {
  final _Step step;
  final bool isLast;
  const _StepRow({required this.step, required this.isLast});

  @override
  Widget build(BuildContext context) {
    final colour = step.done ? AppColors.success : context.cTextSecondary;
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              Icon(
                step.done ? Icons.check_circle_rounded : Icons.schedule_rounded,
                size: 16,
                color: colour,
              ),
              if (!isLast)
                Expanded(
                  child: Container(
                    width: 2,
                    margin: const EdgeInsets.symmetric(vertical: 2),
                    color: context.cBorder,
                  ),
                ),
            ],
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(step.label,
                      style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: context.cText)),
                  if (step.detail.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(step.detail,
                          style: TextStyle(
                              fontSize: 12.5,
                              height: 1.3,
                              color: context.cTextSecondary)),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
