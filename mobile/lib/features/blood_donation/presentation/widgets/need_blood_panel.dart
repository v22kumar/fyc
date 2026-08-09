import 'package:flutter/material.dart';

import '../../../../core/design_system/tokens.dart';
import '../../../../core/l10n/tr.dart';

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
///
/// It used to carry its own "N of M available now" line. The map above it now
/// says the same thing, larger and over the dots it is counting — so the line
/// here was the same fact twice, two hundred pixels apart, which reads as two
/// facts that happen to agree.
class NeedBloodPanel extends StatelessWidget {
  const NeedBloodPanel({
    super.key,
    required this.onRaiseRequest,
  });

  final VoidCallback onRaiseRequest;

  @override
  Widget build(BuildContext context) {
    const danger = DSColors.danger;
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
                        color: Colors.white.withValues(alpha: 0.18),
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
                                ?.copyWith(color: Colors.white.withValues(alpha: 0.9)),
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
        ],
      ),
    );
  }
}
