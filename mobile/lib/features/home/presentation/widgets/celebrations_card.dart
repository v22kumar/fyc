import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/l10n/tr.dart';
import '../../../../core/router/app_router.dart' show pushMemberRoute;
import '../../../../core/theme/app_theme.dart';
import '../../domain/repositories/home_repository.dart';

/// The moment the member opens the app on somebody's day.
///
/// Not a notification — the card is *there* when the app opens, which is the
/// whole ask. Three shapes, all handling one celebrant or many:
///
/// * **your own day** — a gradient hero card greeting you by name, with the
///   ordinal for anniversaries ("10 years today!") and a "share the joy"
///   button that opens the composer prefilled;
/// * **others' days** — "Today's celebrations", each person a tappable row
///   into their member profile;
/// * **nobody's day** — nothing at all. The card earns its place or leaves.
class CelebrationsCard extends StatefulWidget {
  const CelebrationsCard(
      {super.key, required this.repo, required this.myUserId});

  final HomeRepository repo;
  final String? myUserId;

  @override
  State<CelebrationsCard> createState() => _CelebrationsCardState();
}

class _CelebrationsCardState extends State<CelebrationsCard> {
  late final Future<List<dynamic>> _future = widget.repo.celebrationsToday();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<dynamic>>(
      future: _future,
      builder: (context, snap) {
        final all = (snap.data ?? const [])
            .whereType<Map<String, dynamic>>()
            .toList();
        if (all.isEmpty) return const SizedBox.shrink();

        final ta = trLang() == 'ta';
        String nameOf(Map<String, dynamic> c) {
          final n = ta
              ? (c['full_name_ta'] as String?)?.trim()
              : (c['full_name_en'] as String?)?.trim();
          if (n != null && n.isNotEmpty) return n;
          return (c['full_name_en'] as String?)?.trim() ?? '';
        }

        final mine = all
            .where((c) => c['user_id']?.toString() == widget.myUserId)
            .toList();
        final others = all
            .where((c) => c['user_id']?.toString() != widget.myUserId)
            .toList();

        return Column(children: [
          // My own day comes first, as a hero — then everyone else's.
          for (final c in mine) ...[
            _HeroCard(celebration: c, name: nameOf(c)),
            const SizedBox(height: 14),
          ],
          if (others.isNotEmpty) ...[
            _OthersCard(celebrations: others, nameOf: nameOf),
            const SizedBox(height: 14),
          ],
        ]);
      },
    );
  }
}

class _HeroCard extends StatelessWidget {
  const _HeroCard({required this.celebration, required this.name});

  final Map<String, dynamic> celebration;
  final String name;

  @override
  Widget build(BuildContext context) {
    final isBirthday = celebration['kind'] == 'birthday';
    final years = celebration['years'] as int?;
    final isMilestone = celebration['is_milestone'] == true;

    final title = isBirthday
        ? trId('happy_birthday_name', {'name': name})
        : (isMilestone && years != null)
            ? trId('milestone_anniversary_name',
                {'years': years, 'name': name})
            : trId('happy_anniversary_name', {'name': name});

    final g1 = isBirthday ? const Color(0xFF7C2D12) : const Color(0xFF701A40);
    final g2 = isBirthday ? const Color(0xFFD97706) : const Color(0xFFBE185D);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
            colors: [g1, g2],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: g2.withValues(alpha: 0.35), blurRadius: 18),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 19,
                  fontWeight: FontWeight.w800,
                  height: 1.3)),
          const SizedBox(height: 6),
          Text(trId('from_fyc_family'),
              style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.85),
                  fontSize: 13)),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              style: FilledButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: g1,
                  minimumSize: const Size(48, 48)),
              onPressed: () => context.push('/feed/create', extra: title),
              icon: const Icon(Icons.celebration_rounded, size: 18),
              label: Text(trId('share_the_joy'),
                  style: const TextStyle(fontWeight: FontWeight.w800)),
            ),
          ),
        ],
      ),
    );
  }
}

class _OthersCard extends StatelessWidget {
  const _OthersCard({required this.celebrations, required this.nameOf});

  final List<Map<String, dynamic>> celebrations;
  final String Function(Map<String, dynamic>) nameOf;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
      decoration: BoxDecoration(
        color: context.cSurface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: context.cBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(trId('todays_celebrations'),
              style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: context.cText)),
          const SizedBox(height: 4),
          for (final c in celebrations)
            _CelebrantRow(celebration: c, name: nameOf(c)),
        ],
      ),
    );
  }
}

class _CelebrantRow extends StatelessWidget {
  const _CelebrantRow({required this.celebration, required this.name});

  final Map<String, dynamic> celebration;
  final String name;

  @override
  Widget build(BuildContext context) {
    final isBirthday = celebration['kind'] == 'birthday';
    final years = celebration['years'] as int?;
    final isMilestone = celebration['is_milestone'] == true;
    const gold = Color(0xFFB45309);

    return InkWell(
      onTap: () =>
          pushMemberRoute(context, '/members/${celebration['user_id']}'),
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(children: [
          Text(isBirthday ? '🎂' : '💐',
              style: const TextStyle(fontSize: 20)),
          const SizedBox(width: 12),
          Expanded(
            child: Text(name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    fontWeight: FontWeight.w700, color: context.cText)),
          ),
          if (years != null) ...[
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: (isMilestone ? gold : context.cTextSecondary)
                    .withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                trId('years_n', {'n': years}) + (isMilestone ? ' ✨' : ''),
                style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color:
                        isMilestone ? gold : context.cTextSecondary),
              ),
            ),
            const SizedBox(width: 6),
          ],
          Icon(Icons.chevron_right_rounded,
              size: 20, color: context.cTextSecondary),
        ]),
      ),
    );
  }
}
