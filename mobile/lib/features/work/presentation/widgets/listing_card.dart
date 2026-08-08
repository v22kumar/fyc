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

    final bits = <String>[
      if (trust.phoneVerified) '✓ ${trId('number_verified')}',
      '${trust.jobsConfirmed} ${trId('jobs_done')}',
      if (trust.memberSinceYear != null)
        '${trId('member_since')} ${trust.memberSinceYear}',
    ];
    return Text(bits.join(' · '),
        style: t.textTheme.bodySmall?.copyWith(color: AppColors.primary));
  }
}
