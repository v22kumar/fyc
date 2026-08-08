import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
class LadderList extends StatelessWidget {
  const LadderList({
    super.key,
    required this.ladder,
    required this.onCalled,
    this.onWrite,
    this.onSuggestContact,
  });

  final CallLadder ladder;

  /// Fired after the dialler opens, so the member can say what happened.
  final void Function(LadderRung rung) onCalled;

  final void Function(LadderRung rung)? onWrite;

  /// Tapped on an office the club has no contact for. The member standing in
  /// front of that office is far more likely to have its number than any
  /// district web page.
  final void Function(LadderRung rung)? onSuggestContact;

  @override
  Widget build(BuildContext context) {
    if (ladder.rungs.isEmpty) return _NoRoute(ladder: ladder);

    // "Start here" belongs on the first rung they can actually use, not on
    // whichever office happens to sit at the top of the list. Marking an
    // office with no phone number as the place to start is worse than marking
    // nothing.
    final startAt = ladder.rungs.indexWhere((r) => r.canCall || r.canWrite);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < ladder.rungs.length; i++)
          _RungTile(
            rung: ladder.rungs[i],
            step: i + 1,
            isStart: i == startAt,
            isLast: i == ladder.rungs.length - 1,
            onCalled: onCalled,
            onWrite: onWrite,
            onSuggestContact: onSuggestContact,
          ),
      ],
    );
  }
}

class _RungTile extends StatelessWidget {
  const _RungTile({
    required this.rung,
    required this.step,
    required this.isStart,
    required this.isLast,
    required this.onCalled,
    this.onWrite,
    this.onSuggestContact,
  });

  final LadderRung rung;
  final int step;
  final bool isStart;
  final bool isLast;
  final void Function(LadderRung) onCalled;
  final void Function(LadderRung)? onWrite;
  final void Function(LadderRung)? onSuggestContact;

  /// Unreachable means *neither* route works. An office with a published email
  /// and no phone is not unreachable — it is one you write to, and dimming it
  /// would hide a letter somebody could send today.
  bool get _unreachable => !rung.canCall && !rung.canWrite;

  /// Group the digits the way a person reads them aloud.
  ///
  /// This number gets copied onto a wall and passed to a neighbour without the
  /// app. `9443132365` is a wall of digits; `94431 32365` is a phone number.
  static String _readable(String raw) {
    final d = raw.replaceAll(RegExp(r'[^0-9]'), '');
    if (d.length == 10) return '${d.substring(0, 5)} ${d.substring(5)}';
    // Landlines here are STD code + number, and the split is not fixed. The
    // Kanniyakumari codes are four or five digits.
    if (d.length == 11 && d.startsWith('0')) {
      return '${d.substring(0, 5)} ${d.substring(5)}';
    }
    return raw;
  }

  Future<void> _dial() async {
    final uri = Uri(scheme: 'tel', path: rung.phone);
    if (await canLaunchUrl(uri)) {
      // Ringing a government officer is a moment of commitment, and the app is
      // about to disappear behind the dialler. A tick confirms the tap landed.
      await HapticFeedback.selectionClick();
      await launchUrl(uri);
      // Asked only after the dialler actually opened. Prompting before would
      // be asking about a call that never happened.
      onCalled(rung);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // The rail. Four identical cards do not read as a sequence; a number
          // and a line do, which is the point — this is a route, and there is
          // always a next step.
          _Rail(step: step, isStart: isStart, isLast: isLast,
              dim: _unreachable),
          SizedBox(width: DSSpacing.sm),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: DSSpacing.sm),
              child: Container(
                padding: EdgeInsets.all(DSSpacing.sm),
                decoration: BoxDecoration(
                  // Tonal, not just outlined. A tinted surface reads as
                  // "this one" before anybody has parsed a word; a 1.5px
                  // border is something you notice only after reading.
                  color: isStart
                      ? Color.alphaBlend(
                          AppColors.primary.withValues(alpha: 0.06),
                          context.cSurface,
                        )
                      : context.cSurface,
                  borderRadius: BorderRadius.circular(DSRadius.card),
                  border: Border.all(
                    color: isStart
                        ? AppColors.primary.withValues(alpha: 0.45)
                        : context.cBorder,
                    width: isStart ? 1.5 : 1,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            rung.title,
                            style: t.textTheme.titleSmall?.copyWith(
                              color: _unreachable
                                  ? context.cTextSecondary
                                  : context.cText,
                            ),
                          ),
                        ),
                        if (isStart) _StartPill(),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(rung.covers, style: t.textTheme.bodySmall),

                    // The number, in full, as text.
                    //
                    // A screen whose whole job is "here is who to ring" that
                    // shows no digits is not doing it. People read the number
                    // before they trust the button, write it on a wall, and
                    // pass it to a neighbour who does not have the app.
                    if (rung.canCall) ...[
                      SizedBox(height: DSSpacing.xs),
                      // Plain text, not selectable. Dragging to select inside
                      // a scrolling list fights the scroll gesture, and the
                      // two things a member actually needs are to read the
                      // number and to dial it — the button does the second.
                      Semantics(
                        // Without this a screen reader reads 9443132365 as one
                        // enormous number. Spaced digits are read singly, which
                        // is the only way somebody can write it down.
                        label: rung.phone!.split('').join(' '),
                        excludeSemantics: true,
                        child: Text(
                          _readable(rung.phone!),
                          style: t.textTheme.titleSmall?.copyWith(
                            color: AppColors.primary,
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                        ),
                      ),
                    ],

                    if (_unreachable) ...[
                      const SizedBox(height: 4),
                      // Named, never hidden — a gap the club cannot see is a
                      // gap nobody fills. But said quietly: this is our
                      // missing data, not the member's problem, and a screen
                      // of amber warnings reads as broken.
                      Text(trId('no_contact_yet'),
                          style: t.textTheme.bodySmall
                              ?.copyWith(color: context.cTextSecondary)),
                      // The member standing outside this office is more likely
                      // to have its number than any district web page — which
                      // is exactly why these rows are the blank ones. Asking
                      // costs nothing and it is the only way the local desks
                      // ever get filled.
                      if (onSuggestContact != null)
                        Align(
                          alignment: Alignment.centerLeft,
                          child: TextButton.icon(
                            onPressed: () => onSuggestContact!(rung),
                            icon: const Icon(Icons.add_circle_outline_rounded,
                                size: 16),
                            label: Text(trId('know_this_contact')),
                            style: TextButton.styleFrom(
                              padding: EdgeInsets.zero,
                              minimumSize: const Size(0, 36),
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                          ),
                        ),
                    ],

                    if (rung.canCall || rung.canWrite) ...[
                      SizedBox(height: DSSpacing.xs),
                      Row(
                        children: [
                          if (rung.canCall)
                            Expanded(
                              // Only the rung we are recommending gets a
                              // filled button. Give the District Collector a
                              // call button as inviting as the ward
                              // engineer's and people will ring the Collector
                              // about a bulb — which is exactly how a club
                              // stops being taken seriously, and how the
                              // ladder's logic gets inverted.
                              // "Call" alone tells a screen-reader user
                              // nothing about who they are about to ring, and
                              // on this screen that is the entire question.
                              child: Semantics(
                                button: true,
                                label: '${trId('call')} ${rung.title}',
                                excludeSemantics: true,
                                child: isStart
                                    ? FilledButton.icon(
                                        onPressed: _dial,
                                        icon: const Icon(Icons.call_rounded,
                                            size: 18),
                                        label: Text(trId('call')),
                                      )
                                    : OutlinedButton.icon(
                                        onPressed: _dial,
                                        icon: const Icon(Icons.call_rounded,
                                            size: 18),
                                        label: Text(trId('call')),
                                      ),
                              ),
                            ),
                          if (rung.canCall && rung.canWrite && onWrite != null)
                            SizedBox(width: DSSpacing.xs),
                          if (rung.canWrite && onWrite != null)
                            Expanded(
                              child: Semantics(
                                button: true,
                                label: '${trId('write')} ${rung.title}',
                                excludeSemantics: true,
                                child: OutlinedButton.icon(
                                  onPressed: () => onWrite!(rung),
                                  icon: const Icon(Icons.mail_outline_rounded,
                                      size: 18),
                                  label: Text(trId('write')),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The numbered rail down the left, so the list reads as a climb.
class _Rail extends StatelessWidget {
  const _Rail({
    required this.step,
    required this.isStart,
    required this.isLast,
    required this.dim,
  });

  final int step;
  final bool isStart;
  final bool isLast;
  final bool dim;

  @override
  Widget build(BuildContext context) {
    final on = isStart ? AppColors.primary : context.cTextSecondary;
    return SizedBox(
      width: 26,
      child: Column(
        children: [
          Container(
            width: 24,
            height: 24,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isStart
                  ? AppColors.primary.withValues(alpha: 0.14)
                  : Colors.transparent,
              border: Border.all(color: on.withValues(alpha: dim ? 0.3 : 0.6)),
            ),
            child: Text('$step',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: dim ? on.withValues(alpha: 0.5) : on)),
          ),
          if (!isLast)
            Expanded(
              child: Container(
                width: 1.5,
                color: context.cBorder,
              ),
            ),
        ],
      ),
    );
  }
}

class _StartPill extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(left: 6),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          color: AppColors.primary.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(DSRadius.chip),
        ),
        child: Text(trId('start_here'),
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
