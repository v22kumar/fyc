import 'en.dart';
import 'ta.dart';
import 'hi.dart';
import 'ml.dart';

/// Central language registry.
///
/// Every user-facing string lives in the per-language maps (`en.dart`,
/// `ta.dart`, …) keyed by a stable string id. Look them up with `trId(id)`.
///
/// **The rule: every string exists in every registered language.** Falling back
/// to English is the right runtime behaviour and a terrible way to find out —
/// nothing throws, nothing logs, and a screen simply comes out half in English.
/// So it is a test, not a habit: `test/core/l10n/registry_parity_test.dart`
/// fails on any key English has and another language does not, and
/// `no_hardcoded_strings_test.dart` fails on any user-facing literal that never
/// reached this registry at all. Both run in CI on every push.
///
/// **To add a new language** (say French): create `fr.dart` with a
/// `const Map<String, String> kFr = { ... }` that translates the keys in
/// `en.dart`, then add two lines here — `'fr': kFr,` and `'fr'` in
/// [kRegisteredLangs]. No call-site changes anywhere. The parity test then
/// covers French automatically; there is nothing to remember on that side
/// either, and it will tell you exactly which keys are still outstanding.
const Map<String, Map<String, String>> kStrings = {
  'en': kEn,
  'ta': kTa,
  'hi': kHi,
  'ml': kMl,
};

/// Languages that have a registered map. Used to offer the language picker and
/// to validate a saved preference.
const List<String> kRegisteredLangs = ['en', 'ta', 'hi', 'ml'];
