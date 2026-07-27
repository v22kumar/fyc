import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/l10n/tr.dart';
import '../../providers/ai_providers.dart';
import 'ai_sparkle.dart';

/// Pick the digest text for the app's current language. Falls back to English
/// when the Tamil copy is absent, and to the legacy single `summary` field for
/// older backends.
String _localizedSummary(Map<String, dynamic> data) {
  final en = ((data['summary_en'] ?? data['summary'] ?? '') as String? ?? '').trim();
  final ta = ((data['summary_ta'] ?? '') as String? ?? '').trim();
  return tr(en: en, ta: ta.isNotEmpty ? ta : en).trim();
}

/// Home "AI Daily Briefing" — a premium gradient hero summarising the day's
/// community activity. Shows an on-brand skeleton while the digest is preparing.
class AiDailyDigestCard extends ConsumerWidget {
  const AiDailyDigestCard({super.key});

  static const _g1 = Color(0xFF4338CA); // indigo
  static const _g2 = Color(0xFF7C3AED); // violet
  static const _g3 = Color(0xFF0D9488); // teal

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final aiDigestState = ref.watch(aiDailyDigestProvider);
    return aiDigestState.when(
      data: (data) {
        final summary = _localizedSummary(data);
        if (summary.isEmpty) return const SizedBox.shrink();
        return _shell(child: _content(summary));
      },
      loading: () => _shell(child: _skeleton()),
      error: (error, stack) => const SizedBox.shrink(),
    );
  }

  Widget _shell({required Widget child}) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [_g1, _g2, _g3],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: _g2.withOpacity(0.35),
            blurRadius: 22,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      clipBehavior: Clip.hardEdge,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Soft decorative orbs.
          Positioned(right: -26, top: -30, child: _orb(120, 0.10)),
          Positioned(right: 40, bottom: -40, child: _orb(90, 0.08)),
          Positioned(
            right: 14,
            top: 14,
            child: Icon(Icons.auto_awesome, size: 64, color: Colors.white.withOpacity(0.10)),
          ),
          Padding(padding: const EdgeInsets.all(18.0), child: child),
        ],
      ),
    );
  }

  Widget _orb(double d, double o) => Container(
        width: d,
        height: d,
        decoration: BoxDecoration(color: Colors.white.withOpacity(o), shape: BoxShape.circle),
      );

  Widget _header() {
    return Row(
      children: [
        Container(
          width: 32,
          height: 32,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.18),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.white.withOpacity(0.25)),
          ),
          child: const Icon(Icons.wb_sunny_rounded, color: Colors.white, size: 18),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(trId('todays_summary'),
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 16)),
        ),
      ],
    );
  }

  Widget _content(String summary) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _header(),
        const SizedBox(height: 14),
        Text(
          summary,
          style: const TextStyle(color: Colors.white, fontSize: 14.5, height: 1.55, fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Icon(Icons.bolt_rounded, size: 14, color: Colors.white.withOpacity(0.75)),
            const SizedBox(width: 4),
            Text(trId('generated_for_fyc_refreshes_daily'),
                style: TextStyle(color: Colors.white.withOpacity(0.75), fontSize: 11, fontWeight: FontWeight.w600)),
          ],
        ),
      ],
    );
  }

  Widget _skeleton() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _header(),
        const SizedBox(height: 16),
        const AiSkeletonBar(widthFactor: 0.95),
        const SizedBox(height: 9),
        const AiSkeletonBar(widthFactor: 0.82),
        const SizedBox(height: 9),
        const AiSkeletonBar(widthFactor: 0.6),
        const SizedBox(height: 14),
        Text(trId('preparing_today_s_briefing'),
            style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 12, fontWeight: FontWeight.w600)),
      ],
    );
  }
}
