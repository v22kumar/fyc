import 'en.dart';
import 'ta.dart';
import 'hi.dart';
import 'ml.dart';

/// Central language registry.
///
/// Every user-facing string lives in the per-language maps (`en.dart`,
/// `ta.dart`, …) keyed by a stable string id. Look them up with `trId(id)`.
///
/// **To add a new language** (say French): create `fr.dart` with a
/// `const Map<String, String> kFr = { ... }` that translates the keys in
/// `en.dart`, then add one line here:  `'fr': kFr,`. No call-site changes are
/// needed anywhere in the app. Any key you don't translate falls back to
/// English automatically, so a language can be filled in progressively.
const Map<String, Map<String, String>> kStrings = {
  'en': kEn,
  'ta': kTa,
  'hi': kHi,
  'ml': kMl,
};

/// Languages that have a registered map. Used to offer the language picker and
/// to validate a saved preference.
const List<String> kRegisteredLangs = ['en', 'ta', 'hi', 'ml'];
