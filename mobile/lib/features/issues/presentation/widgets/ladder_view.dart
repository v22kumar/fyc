import 'package:flutter/material.dart';

import '../../../../core/l10n/tr.dart';
import '../../../../core/storage/local_storage.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../service_locator.dart';

/// The escalation ladder, drawn.
///
/// Used by the reviewer before anything is sent and by the reporter afterwards,
/// from the same data, so the two can never disagree about where a complaint is
/// headed. A spine with a dot per rung, because the shape *is* the message:
/// this starts at the bottom and only climbs when it has to.
///
/// An office with no address yet is shown greyed rather than hidden. Hiding it
/// would make the route look shorter than it is, and the gap is exactly what
/// the club needs to see.
class LadderView extends StatelessWidget {
  final List<Map<String, dynamic>> rungs;
  /// Which rung the complaint has already reached, if any.
  final int? currentPosition;

  const LadderView({super.key, required this.rungs, this.currentPosition});

  @override
  Widget build(BuildContext context) {
    if (rungs.isEmpty) {
      return Text(trId('queue_nothing_here'),
          style: TextStyle(fontSize: 13, color: context.cTextSecondary));
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < rungs.length; i++)
          _Rung(
            rung: rungs[i],
            isLast: i == rungs.length - 1,
            done: currentPosition != null &&
                (rungs[i]['position'] as int) <= currentPosition!,
          ),
      ],
    );
  }
}

class _Rung extends StatelessWidget {
  final Map<String, dynamic> rung;
  final bool isLast;
  final bool done;
  const _Rung({required this.rung, required this.isLast, required this.done});

  /// The Tamil name of an office when the app is in Tamil, the English one
  /// otherwise.
  ///
  /// The API returns both and this widget was reading only `_en`, so a reviewer
  /// working entirely in Tamil was shown "Sanitary Inspector" and "District
  /// Collector" — the two things on the screen that name a real person's desk.
  ///
  /// Hindi and Malayalam fall back to English rather than to Tamil: these are
  /// Tamil Nadu government designations, and an officer's title in a language
  /// the office does not use is less useful than the English one, which appears
  /// on the letterhead.
  String? _localised(String? ta, String? en) {
    String lang;
    try {
      lang = sl<LocalStorage>().getLang();
    } catch (_) {
      lang = 'en';
    }
    final preferred = lang == 'ta' ? ta : en;
    return (preferred == null || preferred.isEmpty) ? (en ?? ta) : preferred;
  }

  @override
  Widget build(BuildContext context) {
    final reachable = rung['reachable'] == true;
    final designation = _localised(
      rung['designation_ta'] as String?,
      rung['designation_en'] as String?,
    );
    final department = _localised(
          rung['department_name_ta'] as String?,
          rung['department_name_en'] as String?,
        ) ??
        '';
    final waitDays = rung['wait_days'] as int?;
    final colour = done
        ? AppColors.success
        : reachable
            ? AppColors.primary
            : context.cTextSecondary;

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              Container(
                width: 12, height: 12,
                margin: const EdgeInsets.only(top: 4),
                decoration: BoxDecoration(
                  color: done ? AppColors.success : Colors.transparent,
                  shape: BoxShape.circle,
                  border: Border.all(color: colour, width: 2),
                ),
              ),
              if (!isLast)
                Expanded(
                  child: Container(
                    width: 2,
                    margin: const EdgeInsets.symmetric(vertical: 3),
                    color: context.cBorder,
                  ),
                ),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    designation ?? department,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: reachable || done ? context.cText : context.cTextSecondary,
                    ),
                  ),
                  if (designation != null)
                    Text(department,
                        style: TextStyle(
                            fontSize: 12, color: context.cTextSecondary, height: 1.3)),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      if (!reachable)
                        Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: Icon(Icons.mail_outline_rounded,
                              size: 13, color: context.cTextSecondary),
                        ),
                      if (waitDays != null)
                        Text(trId('queue_due_in', {'n': waitDays}),
                            style: TextStyle(
                                fontSize: 11.5, color: context.cTextSecondary)),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
