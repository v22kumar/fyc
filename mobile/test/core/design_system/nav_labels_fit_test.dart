import 'package:characters/characters.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fyc_connect/core/l10n/registry/en.dart';
import 'package:fyc_connect/core/l10n/registry/hi.dart';
import 'package:fyc_connect/core/l10n/registry/ml.dart';
import 'package:fyc_connect/core/l10n/registry/ta.dart';

/// The bottom navigation gives each of four labels a quarter of the screen,
/// and the docked "+" eats into the middle two. Translating the labels was the
/// right fix — they had been English for every member — but the first attempt
/// used the natural long words and "விளையாட்டு" promptly wrapped onto two
/// lines and collided with the button.
///
/// A length ceiling is a blunt instrument, but it is the one that would have
/// caught it, and it costs nothing to keep.
void main() {
  const navKeys = ['nav_home', 'nav_feed', 'nav_play', 'nav_serve'];

  // Measured against the narrowest phone the club has to support (360dp):
  // four labels, so ~90dp each, less the icon padding.
  const maxChars = 9;

  final registries = <String, Map<String, String>>{
    'en': kEn,
    'ta': kTa,
    'hi': kHi,
    'ml': kMl,
  };

  registries.forEach((lang, strings) {
    for (final key in navKeys) {
      test('$lang: $key fits on one line in the bottom navigation', () {
        final label = strings[key];
        expect(label, isNotNull,
            reason: '$key is missing from the $lang registry, so members of '
                'that language would silently fall back to English');
        expect(label!.characters.length, lessThanOrEqualTo(maxChars),
            reason: '"$label" is long enough to wrap into the create button. '
                'Pick a shorter word rather than shrinking the type.');
      });
    }
  });
}
