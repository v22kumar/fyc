import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/design_system/tokens.dart';
import '../../../../core/l10n/tr.dart';
import '../../../../core/theme/app_theme.dart';
import '../../domain/entities/complaint_entities.dart';

/// Hand the letter to the member's own mail app.
///
/// The club never sends it. That single decision removes the liability of
/// publishing whatever a member writes about a contractor, makes the complaint
/// land as a citizen grievance rather than a campaign, and sidesteps a small
/// club's SMTP being blocklisted by government mail servers.
///
/// What we cannot do is watch them press send. So this asks afterwards, once,
/// and believes the answer — unless the club's copy is on, in which case the
/// copy arriving says it for them.
class SendLetterSheet extends StatefulWidget {
  const SendLetterSheet({
    super.key,
    required this.draft,
    required this.onSentConfirmed,
    required this.onBccChanged,
  });

  final ComplaintDraft draft;
  final VoidCallback onSentConfirmed;
  final ValueChanged<bool> onBccChanged;

  @override
  State<SendLetterSheet> createState() => _SendLetterSheetState();
}

class _SendLetterSheetState extends State<SendLetterSheet> {
  bool _opened = false;

  Uri _mailto() {
    // Percent-encoded through Uri so a body with newlines and Tamil survives.
    // An email intent would also carry the photo as an attachment; this is the
    // fallback that works on every device with any mail app.
    final q = <String, String>{
      'subject': widget.draft.subject,
      'body': widget.draft.body,
      if (widget.draft.cc.isNotEmpty) 'cc': widget.draft.cc.join(','),
      if (widget.draft.bcc.isNotEmpty) 'bcc': widget.draft.bcc.join(','),
    };
    return Uri(
      scheme: 'mailto',
      path: widget.draft.toEmail ?? '',
      query: q.entries
          .map((e) =>
              '${e.key}=${Uri.encodeComponent(e.value)}')
          .join('&'),
    );
  }

  Future<void> _open() async {
    final uri = _mailto();
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
      if (mounted) setState(() => _opened = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final d = widget.draft;
    return Padding(
      padding: EdgeInsets.all(DSSpacing.md),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(d.toLabel, style: Theme.of(context).textTheme.titleMedium),
          SizedBox(height: DSSpacing.xs),
          Text(d.subject, style: Theme.of(context).textTheme.titleSmall),
          SizedBox(height: DSSpacing.sm),
          Flexible(
            child: SingleChildScrollView(
              child: Text(d.body,
                  style: Theme.of(context).textTheme.bodySmall),
            ),
          ),
          if (!d.aiWritten) ...[
            SizedBox(height: DSSpacing.xs),
            // Said quietly rather than hidden: the member should know the
            // letter is in their own words because the model was unavailable.
            Text(trId('written_in_your_words'),
                style: Theme.of(context).textTheme.bodySmall),
          ],
          const Divider(height: 28),
          // The blind copy is disclosed. A copy the sender does not know about
          // is something done to them.
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: d.bcc.isNotEmpty,
            onChanged: widget.onBccChanged,
            title: Text(trId('copy_to_club'),
                style: Theme.of(context).textTheme.bodyMedium),
          ),
          SizedBox(height: DSSpacing.xs),
          if (!_opened)
            FilledButton.icon(
              onPressed: _open,
              icon: const Icon(Icons.outgoing_mail),
              label: Text(trId('open_in_mail')),
            )
          else ...[
            // Asked only after their mail app was actually opened.
            Text(trId('did_you_send_it'),
                style: Theme.of(context).textTheme.titleSmall),
            SizedBox(height: DSSpacing.xs),
            Row(
              children: [
                Expanded(
                  child: FilledButton(
                    onPressed: () {
                      widget.onSentConfirmed();
                      Navigator.of(context).pop();
                    },
                    child: Text(trId('yes_i_sent_it')),
                  ),
                ),
                SizedBox(width: DSSpacing.xs),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text(trId('not_yet')),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
