import 'package:flutter/material.dart';

import '../../../../core/design_system/tokens.dart';
import '../../../../core/l10n/tr.dart';
import '../../../../core/theme/app_theme.dart';
import '../../domain/entities/blood_donor_entity.dart';

/// One donor, answering one question: should I contact this person?
///
/// The card this replaces answered four questions at once — a badge for
/// distance, a badge for eligibility, a badge for whether they came from the
/// app or the import, and a location line that on most rows read "location not
/// specified" and truncated. Four competing signals in a row 80px tall, and the
/// name clipped at ten characters to make room.
///
/// The standard applied here:
/// * **One status line.** Distance and eligibility are the two facts that
///   decide anything, so they get the line under the name. Everything else goes.
/// * **Never a dead row.** If there is no location and no distance, the line
///   carries eligibility alone rather than reserving space to say nothing.
/// * **Source belongs to the section, not the row.** Club donors and imported
///   contacts sit under their own headings, so each card stops repeating which
///   pile it is in.
/// * **Age, because a hospital asks.** Held on the profile and never shown
///   until now.
class DonorCard extends StatelessWidget {
  const DonorCard({
    super.key,
    required this.donor,
    required this.lang,
    required this.onContact,
  });

  final BloodDonorEntity donor;
  final String lang;
  final VoidCallback onContact;

  /// The single line that decides whether this person is worth contacting.
  ///
  /// Ordered by what a person in a hurry needs: how far, then whether they can
  /// give today, then who they are.
  String _status() {
    final parts = <String>[];
    if (donor.distanceKm != null) {
      parts.add('${donor.distanceKm!.toStringAsFixed(1)} ${trId('km_away')}');
    } else {
      final where = donor.locationName(lang);
      if (where != null) parts.add(where);
    }
    parts.add(donor.isEligible
        ? trId('eligible_now')
        : (donor.eligibleOn != null
            ? trId('eligible_on', {'date': _shortDate(donor.eligibleOn!)})
            : trId('eligible_soon')));
    if (donor.age != null) parts.add(trId('age_years', {'n': donor.age}));
    return parts.join(' · ');
  }

  static String _shortDate(String iso) {
    // The API sends a plain ISO date. Showing "19 Sep" beats "eligible soon",
    // which is what the old badge said and told nobody anything.
    try {
      final d = DateTime.parse(iso);
      const months = [
        'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
      ];
      return '${d.day} ${months[d.month - 1]}';
    } catch (_) {
      return iso;
    }
  }

  @override
  Widget build(BuildContext context) {
    final ready = donor.isEligible && donor.isAvailable;
    final accent = ready ? AppColors.success : AppColors.textSecondary;

    return Card(
      margin: EdgeInsets.only(bottom: DSSpacing.sm),
      elevation: 0,
      color: context.cSurface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(DSRadius.card),
        side: BorderSide(color: context.cBorder),
      ),
      child: InkWell(
        onTap: onContact,
        borderRadius: BorderRadius.circular(DSRadius.card),
        child: Padding(
          padding: EdgeInsets.all(DSSpacing.md),
          child: Row(
            children: [
              // The blood group is what people scan for, so it is the anchor.
              CircleAvatar(
                radius: 26,
                backgroundColor: DSColors.danger.withOpacity(0.10),
                child: Text(
                  donor.bloodGroup,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: DSColors.danger,
                        fontWeight: FontWeight.w800,
                      ),
                ),
              ),
              SizedBox(width: DSSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      donor.displayName(lang),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        Icon(
                          ready
                              ? Icons.check_circle_rounded
                              : Icons.schedule_rounded,
                          size: 14,
                          color: accent,
                        ),
                        SizedBox(width: DSSpacing.xs),
                        Expanded(
                          child: Text(
                            _status(),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(color: accent),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              SizedBox(width: DSSpacing.xs),
              // One action. Tapping the row does the same thing, so this is an
              // affordance rather than the only way in.
              Icon(Icons.chevron_right_rounded, color: context.cTextSecondary),
            ],
          ),
        ),
      ),
    );
  }
}
