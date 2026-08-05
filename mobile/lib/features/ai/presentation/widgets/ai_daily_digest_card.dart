import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/l10n/tr.dart';
import '../../providers/ai_providers.dart';
import 'ai_sparkle.dart';
import 'package:fyc_connect/core/theme/app_theme.dart';
import '../../../../core/design_system/tokens.dart';

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

  // Derived from the club's own colour rather than a stock indigo-violet.
  // The card should still read as the richest thing on Home — that was right —
  // but it was the only place in the app those two purples appeared, so it read
  // as borrowed from somewhere else.
  static Color get _g1 => Color.lerp(AppColors.primary, Colors.black, 0.35)!;
  static Color get _g2 => AppColors.primary;
  static Color get _g3 => Color.lerp(AppColors.primary, DSColors.mint500, 0.65)!;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final aiDigestState = ref.watch(aiDailyDigestProvider);
    return aiDigestState.when(
      data: (data) {
        final summary = _localizedSummary(data);
        if (summary.isEmpty) return SizedBox.shrink();
        return _shell(child: _content(summary));
      },
      loading: () => _shell(child: _skeleton()),
      error: (error, stack) => SizedBox.shrink(),
    );
  }

  Widget _shell({required Widget child}) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      decoration: BoxDecoration(
        gradient: LinearGradient(
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
            child: Icon(Icons.auto_awesome, size: 64, color: AppColors.background.withOpacity(0.10)),
          ),
          Padding(padding: EdgeInsets.all(18.0), child: child),
        ],
      ),
    );
  }

  Widget _orb(double d, double o) => Container(
        width: d,
        height: d,
        decoration: BoxDecoration(color: AppColors.background.withOpacity(o), shape: BoxShape.circle),
      );

  Widget _header() {
    return Row(
      children: [
        Container(
          width: 32,
          height: 32,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: AppColors.background.withOpacity(0.18),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.background.withOpacity(0.25)),
          ),
          child: Icon(Icons.wb_sunny_rounded, color: AppColors.background, size: 18),
        ),
        SizedBox(width: 10),
        Expanded(
          child: Text(trId('todays_summary'),
              style: TextStyle(color: AppColors.background, fontWeight: FontWeight.w800, fontSize: 16)),
        ),
      ],
    );
  }

  Widget _content(String summary) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _header(),
        SizedBox(height: 14),
        Text(
          summary,
          style: TextStyle(color: AppColors.background, fontSize: 14.5, height: 1.55, fontWeight: FontWeight.w500),
        ),
        SizedBox(height: 14),
        Row(
          children: [
            Icon(Icons.bolt_rounded, size: 14, color: AppColors.background.withOpacity(0.75)),
            SizedBox(width: 4),
            Text(trId('generated_for_fyc_refreshes_daily'),
                style: TextStyle(color: AppColors.background.withOpacity(0.75), fontSize: 11, fontWeight: FontWeight.w600)),
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
        SizedBox(height: 16),
        AiSkeletonBar(widthFactor: 0.95),
        SizedBox(height: 9),
        AiSkeletonBar(widthFactor: 0.82),
        SizedBox(height: 9),
        AiSkeletonBar(widthFactor: 0.6),
        SizedBox(height: 14),
        Text(trId('preparing_today_s_briefing'),
            style: TextStyle(color: AppColors.background.withOpacity(0.8), fontSize: 12, fontWeight: FontWeight.w600)),
      ],
    );
  }
}
