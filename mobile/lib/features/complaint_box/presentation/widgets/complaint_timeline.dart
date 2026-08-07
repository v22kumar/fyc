import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/design_system/tokens.dart';
import '../../../../core/l10n/tr.dart';
import '../../../../core/storage/local_storage.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../service_locator.dart';
import '../../domain/entities/complaint_entities.dart';

/// What has happened, and who says so.
///
/// This is where the rule becomes visible. Nothing here is a status the app
/// decided; every line is a sentence with an author. "You said you sent this"
/// cannot be wrong the way a badge reading "Sent" can — and this app cannot
/// see whether a letter left somebody's mail app, so a badge would eventually
/// be wrong in front of somebody standing at a government counter.
class ComplaintTimeline extends StatelessWidget {
  const ComplaintTimeline({super.key, required this.state});

  final ComplaintState state;

  @override
  Widget build(BuildContext context) {
    final lang = sl<LocalStorage>().getLang();
    final fmt = DateFormat.MMMd(lang);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (!state.isClosed && state.waitingDays != null)
          _WaitingChip(days: state.waitingDays!),
        SizedBox(height: DSSpacing.sm),
        for (final ev in state.events.reversed)
          Padding(
            padding: EdgeInsets.only(bottom: DSSpacing.sm),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Who acted is the whole point of this list, so the club's
                // entries must not look identical to the member's own. On a
                // screen where the club forwarded something and the member
                // did not, that difference is the information.
                Padding(
                  padding: const EdgeInsets.only(top: 3),
                  child: Icon(
                    _icon(ev.type),
                    size: 18,
                    color: ev.author == ComplaintAuthor.member
                        ? context.cTextSecondary
                        : AppColors.primary,
                  ),
                ),
                SizedBox(width: DSSpacing.xs),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        // Author first, always. The sentence is a report of
                        // what somebody stated, not an assertion by the app.
                        '${_who(ev)} · ${fmt.format(ev.at)}',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              color: ev.author == ComplaintAuthor.member
                                  ? null
                                  : AppColors.primary,
                            ),
                      ),
                      Text(_sentence(ev),
                          style: Theme.of(context).textTheme.bodyMedium),
                      if (ev.note != null && ev.note!.isNotEmpty)
                        Text(ev.note!,
                            style: Theme.of(context).textTheme.bodySmall),
                    ],
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  String _who(ComplaintEvent ev) => switch (ev.author) {
        ComplaintAuthor.member => trId('you_said'),
        ComplaintAuthor.club => trId('fyc_said'),
        ComplaintAuthor.system => trId('fyc_said'),
      };

  /// Deliberately phrased as reported speech.
  String _sentence(ComplaintEvent ev) {
    final office = ev.authorityLabel;
    return switch (ev.type) {
      'CALLED' => switch (ev.callOutcome) {
          CallOutcome.promised =>
            'called ${office ?? 'the office'} — they promised to act',
          CallOutcome.noAnswer => 'called ${office ?? 'the office'} — no answer',
          _ => 'spoke to ${office ?? 'the office'}',
        },
      'DRAFTED' => 'wrote a letter to ${office ?? 'the office'}',
      'SENT' => 'sent the letter${office != null ? ' to $office' : ''}',
      'COPY_RECEIVED' => 'received a copy of the letter',
      'REPLY_RECEIVED' => 'had a reply',
      'HANDED_TO_FYC' => 'asked FYC to take this on',
      'FYC_FORWARDED' => 'forwarded it to ${office ?? 'the department'}',
      'ESCALATED' => 'took it up a level',
      'RESOLVED' => 'marked this resolved',
      'CLOSED' => 'closed this',
      'REOPENED' => 'reopened this',
      _ => ev.type.toLowerCase(),
    };
  }

  IconData _icon(String type) => switch (type) {
        'CALLED' => Icons.call_rounded,
        'DRAFTED' => Icons.edit_note_rounded,
        'SENT' || 'FYC_FORWARDED' => Icons.outgoing_mail,
        'COPY_RECEIVED' => Icons.mark_email_read_outlined,
        'REPLY_RECEIVED' => Icons.reply_rounded,
        'RESOLVED' => Icons.check_circle_outline_rounded,
        'CLOSED' => Icons.do_not_disturb_on_outlined,
        'REOPENED' => Icons.refresh_rounded,
        _ => Icons.circle_outlined,
      };
}

/// The absence of news, named.
///
/// Not "Unknown", which reads as a bug. "Waiting to hear · 12 days" is true,
/// useful, and what a person would actually say about it.
class _WaitingChip extends StatelessWidget {
  const _WaitingChip({required this.days});
  final int days;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: AppColors.warning.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(DSRadius.chip),
        ),
        child: Text(
          '${trId('waiting_to_hear')} · $days ${trId('days')}',
          style: Theme.of(context)
              .textTheme
              .labelSmall
              ?.copyWith(color: AppColors.warning),
        ),
      );
}
