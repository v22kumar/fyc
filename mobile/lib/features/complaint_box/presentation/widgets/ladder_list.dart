import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/design_system/tokens.dart';
import '../../../../core/l10n/tr.dart';
import '../../../../core/theme/app_theme.dart';
import '../../domain/entities/complaint_entities.dart';

/// Every office worth trying, nearest first.
///
/// Shows the whole ladder on purpose. Hand a member one "correct" officer and,
/// when he does not pick up or listens and does nothing, they have no visible
/// next step and stop. Seeing the route means the next step is always obvious —
/// and they can judge who is worth ringing, because they know things about the
/// local office this directory never will.
///
/// Offices with no number yet are shown greyed rather than hidden. A gap the
/// club cannot see is a gap nobody fills.
class LadderList extends StatelessWidget {
  const LadderList({
    super.key,
    required this.ladder,
    required this.onCalled,
    this.onWrite,
  });

  final CallLadder ladder;

  /// Fired after the dialler is opened, so the member can say what happened.
  final void Function(LadderRung rung) onCalled;

  final void Function(LadderRung rung)? onWrite;

  @override
  Widget build(BuildContext context) {
    if (ladder.rungs.isEmpty) {
      return _NoRoute(ladder: ladder);
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < ladder.rungs.length; i++)
          _RungTile(
            rung: ladder.rungs[i],
            isFirst: i == 0,
            onCalled: onCalled,
            onWrite: onWrite,
          ),
      ],
    );
  }
}

class _RungTile extends StatelessWidget {
  const _RungTile({
    required this.rung,
    required this.isFirst,
    required this.onCalled,
    this.onWrite,
  });

  final LadderRung rung;
  final bool isFirst;
  final void Function(LadderRung) onCalled;
  final void Function(LadderRung)? onWrite;

  Future<void> _dial(BuildContext context) async {
    final uri = Uri(scheme: 'tel', path: rung.phone);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
      // Ask only after the dialler has actually opened. Prompting before would
      // be asking about a call that never happened.
      onCalled(rung);
    }
  }

  @override
  Widget build(BuildContext context) {
    final muted = !rung.canCall;
    return Opacity(
      opacity: muted ? 0.55 : 1,
      child: Container(
        margin: EdgeInsets.only(bottom: DSSpacing.xs),
        padding: EdgeInsets.all(DSSpacing.sm),
        decoration: BoxDecoration(
          color: context.cSurface,
          borderRadius: BorderRadius.circular(DSRadius.card),
          border: Border.all(
            color: isFirst && rung.canCall
                ? AppColors.primary.withOpacity(0.45)
                : context.cBorder,
            width: isFirst && rung.canCall ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(rung.title,
                            style: Theme.of(context).textTheme.titleSmall,
                            maxLines: 2, overflow: TextOverflow.ellipsis),
                      ),
                      if (isFirst && rung.canCall) ...[
                        SizedBox(width: DSSpacing.xs),
                        _Pill(text: trId('start_here')),
                      ],
                    ],
                  ),
                  SizedBox(height: 2),
                  Text(
                    rung.covers,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  if (muted) ...[
                    SizedBox(height: 4),
                    // Named, not hidden. Somebody has to know it is missing.
                    Text(trId('no_number_yet'),
                        style: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.copyWith(color: AppColors.warning)),
                  ],
                ],
              ),
            ),
            if (rung.canCall)
              IconButton(
                onPressed: () => _dial(context),
                icon: const Icon(Icons.call_rounded),
                color: AppColors.primary,
                tooltip: trId('call'),
              ),
            if (rung.canWrite && onWrite != null)
              IconButton(
                onPressed: () => onWrite!(rung),
                icon: const Icon(Icons.mail_outline_rounded),
                tooltip: trId('write'),
              ),
          ],
        ),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          color: AppColors.primary.withOpacity(0.12),
          borderRadius: BorderRadius.circular(DSRadius.chip),
        ),
        child: Text(text,
            style: Theme.of(context)
                .textTheme
                .labelSmall
                ?.copyWith(color: AppColors.primary)),
      );
}

/// No route at all. Still gives the member somewhere to go.
class _NoRoute extends StatelessWidget {
  const _NoRoute({required this.ladder});
  final CallLadder ladder;

  @override
  Widget build(BuildContext context) {
    final helpline = ladder.fallbackHelpline;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(trId('no_office_listed_yet'),
            style: Theme.of(context).textTheme.titleSmall),
        SizedBox(height: DSSpacing.xs),
        Text(trId('no_office_listed_yet_help'),
            style: Theme.of(context).textTheme.bodySmall),
        if (helpline != null) ...[
          SizedBox(height: DSSpacing.sm),
          FilledButton.icon(
            onPressed: () => launchUrl(Uri(scheme: 'tel', path: helpline)),
            icon: const Icon(Icons.support_agent_rounded),
            label: Text('${trId('helpline')} $helpline'),
          ),
        ],
      ],
    );
  }
}
