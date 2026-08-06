import 'package:flutter/material.dart';

import '../../../../core/l10n/tr.dart';
import '../../../../core/theme/app_theme.dart';

/// Where a donor's distance came from — the blue/green distinction, in one place.
///
/// A distance with a hidden basis cannot be judged. "3 km away" measured from a
/// fix taken twenty minutes ago and from a home area recorded last year are not
/// the same claim, and in an emergency the difference decides who you call
/// first. Every ride-hailing app people already use draws this distinction; we
/// are borrowing a habit, not inventing one.
///
/// Green is a position the phone actually reported. Blue is where they live.
/// Nothing is ever carried by colour alone — each state also has its own shape
/// and its own words, so the card still reads correctly in greyscale, at a
/// glance, or to someone who does not distinguish the two hues.
enum DonorPresence {
  /// Seen within the hour — filled dot, green. They are there now.
  live,

  /// Seen within the day — hollow ring, green. They were there recently.
  recent,

  /// No recent fix, so this is their registered home area — house, blue.
  home,

  /// No location basis at all (a plain search result, not a nearby query).
  unknown;

  static DonorPresence of(String? basis) => switch (basis) {
        'live' => DonorPresence.live,
        'recent' => DonorPresence.recent,
        'home' => DonorPresence.home,
        _ => DonorPresence.unknown,
      };

  Color get color => switch (this) {
        DonorPresence.live || DonorPresence.recent => AppColors.success,
        DonorPresence.home => AppColors.info,
        DonorPresence.unknown => AppColors.textSecondary,
      };

  IconData get icon => switch (this) {
        DonorPresence.live => Icons.circle,
        DonorPresence.recent => Icons.trip_origin,
        DonorPresence.home => Icons.home_rounded,
        DonorPresence.unknown => Icons.place_outlined,
      };

  /// The filled dot needs to be smaller than the outlined glyphs to read as the
  /// same weight beside them.
  double get _iconSize => this == DonorPresence.live ? 9 : 13;

  /// Distance and basis as one phrase, so translators control the word order.
  ///
  /// Kept as a single segment rather than "2.3 km away · here now" because the
  /// status line already carries eligibility and age, and Tamil runs long
  /// enough that a fourth segment pushes age off the card.
  String phrase(double km) {
    final d = km.toStringAsFixed(1);
    return switch (this) {
      DonorPresence.live => trId('km_away_now', {'d': d}),
      DonorPresence.recent => trId('km_away_today', {'d': d}),
      DonorPresence.home => trId('lives_km_away', {'d': d}),
      DonorPresence.unknown => '$d ${trId('km_away')}',
    };
  }
}

/// The glyph, sized and boxed so a row of cards keeps its text aligned whichever
/// state each one is in.
class PresenceGlyph extends StatelessWidget {
  const PresenceGlyph(this.presence, {super.key, this.size = 14});

  final DonorPresence presence;
  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Center(
        child: Icon(
          presence.icon,
          size: presence._iconSize * (size / 14),
          color: presence.color,
        ),
      ),
    );
  }
}
