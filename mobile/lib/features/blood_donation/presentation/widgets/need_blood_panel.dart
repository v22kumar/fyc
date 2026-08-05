import 'package:flutter/material.dart';

import '../../../../core/design_system/tokens.dart';
import '../../../../core/l10n/tr.dart';
import '../../../../core/theme/app_theme.dart';

/// The one thing this screen exists for.
///
/// The hub used to open on a filter row and a directory: pick a blood group,
/// pick a taluk, scroll a list of names, cold-call strangers. That asks the
/// person having the worst night of their life to do all the work, and it asks
/// it as a *decision* — two hundred rows, no basis to choose between them.
///
/// The request already existed; it was a thin red banner between the filters.
/// This makes it the screen: state the need once, and the people who can help
/// are notified. Browsing stays available underneath for anyone who wants it,
/// which is progressive disclosure rather than removal.
class NeedBloodPanel extends StatelessWidget {
  const NeedBloodPanel({
    super.key,
    required this.onRaiseRequest,
    required this.availableNow,
    required this.totalDonors,
  });

  final VoidCallback onRaiseRequest;

  /// Registered members who are eligible and marked available right now.
  final int availableNow;

  /// Registered members overall. Distinct from the imported directory — those
  /// are strangers to the club and are not counted as if they were members.
  final int totalDonors;

  @override
  Widget build(BuildContext context) {
    final danger = DSColors.danger;
    return Padding(
      padding: EdgeInsets.fromLTRB(
          DSSpacing.md, DSSpacing.md, DSSpacing.md, DSSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Material(
            color: danger,
            borderRadius: BorderRadius.circular(DSRadius.card),
            elevation: DSElevation.card,
            child: InkWell(
              onTap: onRaiseRequest,
              borderRadius: BorderRadius.circular(DSRadius.card),
              child: Padding(
                padding: EdgeInsets.all(DSSpacing.md),
                child: Row(
                  children: [
                    Container(
                      padding: EdgeInsets.all(DSSpacing.sm),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.18),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.emergency_rounded,
                          color: Colors.white, size: 26),
                    ),
                    SizedBox(width: DSSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            trId('i_need_blood'),
                            style: Theme.of(context)
                                .textTheme
                                .titleLarge
                                ?.copyWith(color: Colors.white),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            trId('i_need_blood_help'),
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(color: Colors.white.withOpacity(0.9)),
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.chevron_right_rounded,
                        color: Colors.white, size: 26),
                  ],
                ),
              ),
            ),
          ),
          SizedBox(height: DSSpacing.sm),
          // Honest, specific reassurance rather than a slogan: how many people
          // this would actually reach. A number the requester can trust is
          // worth more than "3 lives saved".
          Row(
            children: [
              Icon(Icons.check_circle_rounded,
                  size: 16, color: AppColors.success),
              SizedBox(width: DSSpacing.xs),
              Expanded(
                child: Text(
                  availableNow > 0
                      ? trId('donors_available_now',
                          {'n': availableNow, 'total': totalDonors})
                      : trId('no_donors_available_now'),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
