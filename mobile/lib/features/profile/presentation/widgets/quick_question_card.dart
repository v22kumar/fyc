import 'package:flutter/material.dart';

import '../../../../core/constants/api_constants.dart';
import '../../../../core/design_system/tokens.dart';
import '../../../../core/l10n/tr.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../service_locator.dart';

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
  const QuickQuestionCard({super.key});

  @override
  State<QuickQuestionCard> createState() => _QuickQuestionCardState();
}

class _QuickQuestionCardState extends State<QuickQuestionCard> {
  Map<String, dynamic>? _question;
  bool _done = false;
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final r = await sl<ApiClient>().dio.get<dynamic>(
            '${ApiConstants.baseUrl}/api/v1/profile-prompts/next',
          );
      final data = r.data;
      if (mounted && data is Map<String, dynamic>) {
        setState(() => _question = data);
      }
    } catch (_) {
      // A question we failed to fetch is a question not worth showing. This
      // must never be the reason a screen looks broken.
    }
  }

  Future<void> _send(String path, String answer) async {
    if (_sending) return;
    setState(() => _sending = true);
    final id = _question?['id'] as String?;
    if (id == null) return;
    try {
      await sl<ApiClient>().dio.post<void>(
        '${ApiConstants.baseUrl}/api/v1/profile-prompts/$path',
        data: {'question_id': id, 'answer': answer},
      );
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
          border: Border.all(color: accent.withOpacity(0.25)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.chat_bubble_outline_rounded, size: 15, color: accent),
                SizedBox(width: DSSpacing.xs),
                Text(
                  trId('quick_question'),
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: accent,
                        letterSpacing: 0.4,
                      ),
                ),
                const Spacer(),
                // Dismissing has to be as easy as answering, or the card is a
                // demand rather than a question.
                TextButton(
                  onPressed: _sending ? null : () => _send('dismiss', '-'),
                  child: Text(trId('ask_me_later')),
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
                    backgroundColor: accent.withOpacity(0.08),
                    side: BorderSide(color: accent.withOpacity(0.28)),
                    labelStyle: Theme.of(context)
                        .textTheme
                        .titleSmall
                        ?.copyWith(color: accent),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
