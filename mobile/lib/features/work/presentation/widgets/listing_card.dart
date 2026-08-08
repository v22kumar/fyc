import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/design_system/tokens.dart';
import '../../../../core/l10n/tr.dart';
import '../../../../core/theme/app_theme.dart';
import '../../domain/entities/work_entities.dart';

/// One person or shop, scannable in about a second.
///
/// A member reduces twenty results to three on name, area and trust. Anything
/// else on this card is noise competing with the number they came for — which
/// is why the number is here, on the list, rather than behind a detail screen.
/// Somebody whose door is broken should not have to open a profile to ring.
class ListingCard extends StatelessWidget {
  const ListingCard({
    super.key,
    required this.listing,
    required this.onOpened,
  });

  final WorkListing listing;

  /// Fired when they act on it, so the owner's view count means something.
  final void Function(WorkListing) onOpened;

  Future<void> _dial(BuildContext context) async {
    onOpened(listing);
    await HapticFeedback.selectionClick();
    final uri = Uri(scheme: 'tel', path: listing.phone);
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }

  Future<void> _whatsapp(BuildContext context) async {
    onOpened(listing);
    final digits = (listing.whatsapp ?? listing.phone).replaceAll(RegExp(r'\D'), '');
    // Assume an Indian number when no country code is given, which is what
    // everybody types.
    final full = digits.length == 10 ? '91$digits' : digits;
    final uri = Uri.parse('https://wa.me/$full');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Container(
      margin: EdgeInsets.only(bottom: DSSpacing.sm),
      padding: EdgeInsets.all(DSSpacing.sm),
      decoration: BoxDecoration(
        color: context.cSurface,
        borderRadius: BorderRadius.circular(DSRadius.card),
        border: Border.all(color: context.cBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(listing.displayName, style: t.textTheme.titleSmall),
          if (listing.area != null || listing.about != null) ...[
            const SizedBox(height: 2),
            Text(
              [listing.area, listing.about]
                  .where((s) => s != null && s.isNotEmpty)
                  .join(' · '),
              style: t.textTheme.bodySmall,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
          // Hours come after the place, because somebody asks "where" before
          // "when" — and sitting between the name and the description they
          // separated the two things that identify the listing.
          if (listing.kind == ListingKind.business && listing.hours != null) ...[
            const SizedBox(height: 2),
            Row(
              children: [
                Icon(Icons.schedule_rounded, size: 14,
                    color: context.cTextSecondary),
                const SizedBox(width: 4),
                Text(listing.hours!, style: t.textTheme.bodySmall),
              ],
            ),
          ],
          SizedBox(height: DSSpacing.xs),
          _TrustLine(trust: listing.trust),
          SizedBox(height: DSSpacing.xs),
          Row(
            children: [
              Expanded(
                child: Semantics(
                  button: true,
                  label: '${trId('call')} ${listing.displayName}',
                  excludeSemantics: true,
                  child: FilledButton.icon(
                    onPressed: () => _dial(context),
                    icon: const Icon(Icons.call_rounded, size: 18),
                    label: Text(trId('call')),
                  ),
                ),
              ),
              SizedBox(width: DSSpacing.xs),
              Expanded(
                child: Semantics(
                  button: true,
                  label: '${trId('whatsapp')} ${listing.displayName}',
                  excludeSemantics: true,
                  child: OutlinedButton.icon(
                    onPressed: () => _whatsapp(context),
                    icon: const Icon(Icons.chat_outlined, size: 18),
                    label: Text(trId('whatsapp')),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// The facts, never a score.
///
/// A five-star average in a town this size is a popularity contest with a feud
/// attached. These are things that are simply true, shown plainly, letting the
/// person looking decide for themselves.
class _TrustLine extends StatelessWidget {
  const _TrustLine({required this.trust});
  final ListingTrust trust;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);

    if (trust.isNew) {
      // Said out loud. Letting a blank record look like a good one is how a
      // directory spends the only trust it has.
      return Text(trId('new_no_jobs_yet'),
          style: t.textTheme.bodySmall?.copyWith(color: context.cTextSecondary));
    }

    // Compact, and an icon rather than a "✓" character.
    //
    // Spelled out, this line wrapped to two rows and took as much space as the
    // description — on a card meant to be scanned in a second, the trust
    // signal must be readable at a glance, not read. And the tick glyph is not
    // in the app's typeface, so it rendered as a box.
    final bits = <String>[
      '${trust.jobsConfirmed} ${trId('jobs_done')}',
      if (trust.memberSinceYear != null)
        '${trId('work_member_since')} ${trust.memberSinceYear}',
    ];
    return Row(
      children: [
        if (trust.phoneVerified) ...[
          Icon(Icons.verified_rounded, size: 15, color: AppColors.primary),
          const SizedBox(width: 4),
        ],
        Flexible(
          child: Text(bits.join(' · '),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: t.textTheme.bodySmall?.copyWith(color: AppColors.primary)),
        ),
      ],
    );
  }
}
