import 'package:flutter/material.dart';

import '../../../../core/design_system/tokens.dart';
import '../../../../core/l10n/tr.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../data/question_scheduler.dart';
import '../../../../core/theme/app_theme.dart';
import '../../domain/repositories/profile_repository.dart';

/// One question, asked once in a while.
///
/// Registration stays deliberately short, so the fields the app needs — blood
/// group above all — are empty for nearly everyone. Asking for them up front
/// would cost us members; asking for them never leaves the blood-donation
/// screen unable to work. So we ask afterwards, one at a time, days apart.
///
/// Everything about this card is built so it never reads as a form:
/// * one question, never a queue;
/// * answers are taps, not typing;
/// * dismissing is free and sits right there, not hidden;
/// * it disappears the moment it is dealt with, and the server keeps it away
///   for days afterwards.
///
/// When there is nothing to ask — the common case — it renders nothing at all.
class QuickQuestionCard extends StatefulWidget {
  final ProfileRepository repo;
  const QuickQuestionCard({super.key, required this.repo});

  @override
  State<QuickQuestionCard> createState() => _QuickQuestionCardState();
}

class _QuickQuestionCardState extends State<QuickQuestionCard> {
  /// Fetched once per app run, shared across every instance of the card.
  ///
  /// Asking the server is not free of consequence: /next records that the
  /// question was shown, and the server then stays quiet for a day. Home
  /// rebuilds several times while it loads, so a per-instance fetch meant the
  /// first rebuild consumed the question and a later one was correctly told
  /// there was nothing to ask — leaving a blank space where the card should be.
  static Future<Map<String, dynamic>?>? _pending;

  Map<String, dynamic>? _question;
  bool _done = false;
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    _pending ??= _fetch();
    final data = await _pending;
    if (mounted && data != null) setState(() => _question = data);
  }

  Future<Map<String, dynamic>?> _fetch() async {
    try {
      // The catalogue, not "what should I ask" — the phone decides that. This
      // request is small, changes rarely, and 304s in the steady state.
      final data = await widget.repo.promptCatalogue();
      if (data == null) return null;

      final scheduler = QuestionScheduler(await SharedPreferences.getInstance());
      final chosen = scheduler.pick(
        questions: (data['questions'] as List? ?? const [])
            .cast<Map<String, dynamic>>(),
        answered: ((data['answered'] as List? ?? const []).cast<String>()).toSet(),
        quietDaysAfterResponse: data['quiet_days_after_response'] as int? ?? 2,
        quietDaysAfterDismiss: data['quiet_days_after_dismiss'] as int? ?? 14,
        quietDaysAfterShown: data['quiet_days_after_shown'] as int? ?? 1,
        maxDismissals: data['max_dismissals'] as int? ?? 3,
      );
      if (chosen != null) await scheduler.markShown();
      return chosen;
    } catch (_) {
      // A question we failed to fetch is a question not worth showing. This
      // must never be the reason a screen looks broken.
      return null;
    }
  }

  Future<void> _send(String path, String answer) async {
    if (_sending) return;
    setState(() => _sending = true);
    final id = _question?['id'] as String?;
    if (id == null) return;
    // Record locally first: the phone owns the cadence now, and it must hold
    // even if the upload fails or the member is offline.
    final scheduler = QuestionScheduler(await SharedPreferences.getInstance());
    if (path == 'answer') {
      await scheduler.markAnswered(id);
    } else {
      await scheduler.markDismissed(id);
    }
    try {
      await widget.repo.submitPromptAnswer(
          path, {'question_id': id, 'answer': answer});
    } catch (_) {
      // Losing one answer is not worth an error message. The server will ask
      // again in a few days.
    }
    if (mounted) setState(() => _done = true);
  }

  /// Blood groups are written the same way everywhere; the rest are phrases
  /// that need translating.
  String _label(String option) =>
      RegExp(r'^(A|B|AB|O)[+-]$').hasMatch(option) ? option : trId('opt_$option');

  @override
  Widget build(BuildContext context) {
    final q = _question;
    if (q == null || _done) return const SizedBox.shrink();

    final options = (q['options'] as List?)?.cast<String>() ?? const <String>[];
    final accent = AppColors.primary;

    return Padding(
      padding: EdgeInsets.symmetric(
          horizontal: DSSpacing.md, vertical: DSSpacing.xs),
      child: Container(
        padding: EdgeInsets.all(DSSpacing.md),
        decoration: BoxDecoration(
          color: context.cSurface,
          borderRadius: BorderRadius.circular(DSRadius.card),
          border: Border.all(color: accent.withValues(alpha: 0.25)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.chat_bubble_outline_rounded, size: 15, color: accent),
                SizedBox(width: DSSpacing.xs),
                // Flexible, not fixed: "ஒரு சிறு கேள்வி" is half again as long
                // as "Quick question", and this row previously overflowed by
                // 43px in Tamil with the dismiss button beside it.
                Flexible(
                  child: Text(
                    trId('quick_question'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: accent,
                          letterSpacing: 0.4,
                        ),
                  ),
                ),
              ],
            ),
            SizedBox(height: DSSpacing.xs),
            Text(
              trId(q['prompt_id'] as String? ?? ''),
              style: Theme.of(context).textTheme.titleMedium,
            ),
            SizedBox(height: DSSpacing.sm),
            Wrap(
              spacing: DSSpacing.xs,
              runSpacing: DSSpacing.xs,
              children: [
                for (final o in options)
                  ActionChip(
                    label: Text(_label(o)),
                    onPressed: _sending ? null : () => _send('answer', o),
                    backgroundColor: accent.withValues(alpha: 0.08),
                    side: BorderSide(color: accent.withValues(alpha: 0.28)),
                    labelStyle: Theme.of(context)
                        .textTheme
                        .titleSmall
                        ?.copyWith(color: accent),
                  ),
              ],
            ),
            // Dismissing sits after the answers, on its own line. It has to be
            // as easy to find as answering — a hidden dismissal turns the card
            // into a demand — but it should not crowd the question, and in
            // Tamil there is simply no room for it on the title row.
            Align(
              alignment: AlignmentDirectional.centerEnd,
              child: TextButton(
                onPressed: _sending ? null : () => _send('dismiss', '-'),
                child: Text(trId('ask_me_later')),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
