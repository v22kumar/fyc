import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/l10n/tr.dart';
import '../../../../core/theme/app_theme.dart';
import '../../providers/ai_providers.dart';
import 'ai_sparkle.dart';

/// Pick the news summary for the app's current language (falls back to English,
/// then the legacy single `summary` field).
String _localizedSummary(Map<String, dynamic> data) {
  final en = ((data['summary_en'] ?? data['summary'] ?? '') as String? ?? '').trim();
  final ta = ((data['summary_ta'] ?? '') as String? ?? '').trim();
  return tr(en: en, ta: ta.isNotEmpty ? ta : en).trim();
}

/// Home "AI News Summary" — a clean, theme-aware surface card with a violet AI
/// accent and gradient trending-topic chips.
class AiNewsSummaryCard extends ConsumerWidget {
  const AiNewsSummaryCard({super.key});

  static const _accent1 = Color(0xFF7C3AED); // violet
  static const _accent2 = Color(0xFFDB2777); // pink

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final aiNewsState = ref.watch(aiNewsSummaryProvider);
    return aiNewsState.when(
      data: (data) {
        final summary = _localizedSummary(data);
        if (summary.isEmpty) return const SizedBox.shrink();
        final topics = List<String>.from(data['trending_topics'] ?? const []);
        return _shell(context, child: _content(context, summary, topics));
      },
      loading: () => _shell(context, child: _skeleton(context)),
      error: (error, stack) => const SizedBox.shrink(),
    );
  }

  Widget _shell(BuildContext context, {required Widget child}) {
    return Container(
      margin: const EdgeInsets.only(left: 16.0, right: 16.0, bottom: 16.0),
      padding: const EdgeInsets.all(18.0),
      decoration: BoxDecoration(
        color: context.cSurface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: context.cBorder),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 14, offset: const Offset(0, 4)),
        ],
      ),
      child: child,
    );
  }

  Widget _header(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: const BoxDecoration(
            gradient: LinearGradient(colors: [_accent1, _accent2]),
            shape: BoxShape.circle,
          ),
          alignment: Alignment.center,
          child: const AiSparkle(size: 17),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('AI News Summary',
                  style: TextStyle(color: context.cText, fontWeight: FontWeight.w800, fontSize: 15.5)),
              Text('The day in a glance',
                  style: TextStyle(color: context.cTextSecondary, fontWeight: FontWeight.w600, fontSize: 11.5)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _content(BuildContext context, String summary, List<String> topics) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _header(context),
        const SizedBox(height: 14),
        Text(summary,
            style: TextStyle(color: context.cText, fontSize: 14, height: 1.55, fontWeight: FontWeight.w500)),
        if (topics.isNotEmpty) ...[
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: topics.map(_chip).toList(),
          ),
        ],
      ],
    );
  }

  Widget _chip(String topic) {
    final label = topic.startsWith('#') ? topic : '#$topic';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [_accent1.withOpacity(0.12), _accent2.withOpacity(0.12)]),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _accent1.withOpacity(0.30)),
      ),
      child: Text(label,
          style: const TextStyle(fontSize: 12, color: _accent1, fontWeight: FontWeight.w700)),
    );
  }

  Widget _skeleton(BuildContext context) {
    final c = context.cTextSecondary;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _header(context),
        const SizedBox(height: 16),
        AiSkeletonBar(widthFactor: 0.95, color: c),
        const SizedBox(height: 9),
        AiSkeletonBar(widthFactor: 0.78, color: c),
        const SizedBox(height: 9),
        AiSkeletonBar(widthFactor: 0.55, color: c),
      ],
    );
  }
}
