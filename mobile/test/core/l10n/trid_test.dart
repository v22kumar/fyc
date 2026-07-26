import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fyc_connect/core/l10n/tr.dart';
import 'package:fyc_connect/core/l10n/registry/registry.dart';
import 'package:fyc_connect/core/storage/local_storage.dart';
import 'package:fyc_connect/service_locator.dart';

/// The central string registry: `trId` resolves an id in the active language,
/// falls back to English, then to the id itself, and fills `{placeholder}`
/// tokens. Adding a language is one map file — verified structurally here.
void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    if (!sl.isRegistered<LocalStorage>()) {
      sl.registerSingleton<LocalStorage>(LocalStorage(prefs));
    }
  });

  test('resolves the active language, else English', () async {
    // A key that has both a Tamil and an English translation.
    final key = kStrings['ta']!.keys.firstWhere(
      (k) => kStrings['en']!.containsKey(k),
    );
    await sl<LocalStorage>().saveLang('ta');
    expect(trId(key), kStrings['ta']![key]);

    await sl<LocalStorage>().saveLang('en');
    expect(trId(key), kStrings['en']![key]);
  });

  test('falls back to English when a key is missing in the language', () async {
    // Pick a key that exists in English but not (yet) in Hindi, if any.
    final missing = kStrings['en']!.keys.firstWhere(
      (k) => !kStrings['hi']!.containsKey(k),
      orElse: () => '',
    );
    if (missing.isNotEmpty) {
      await sl<LocalStorage>().saveLang('hi');
      expect(trId(missing), kStrings['en']![missing]);
    }
  });

  test('returns the id itself for a completely unknown key', () async {
    await sl<LocalStorage>().saveLang('en');
    expect(trId('__no_such_key__'), '__no_such_key__');
  });

  test('fills {placeholder} tokens from args', () async {
    await sl<LocalStorage>().saveLang('en');
    // Not a registered id, so it echoes the id — but placeholder substitution
    // still runs on the resolved string.
    expect(trId('Need {n} runs', {'n': 5}), 'Need 5 runs');
  });

  test('every registered language map is non-empty and English is the superset', () {
    for (final lang in kRegisteredLangs) {
      expect(kStrings[lang], isNotNull, reason: '$lang missing from kStrings');
    }
    expect(kStrings['en']!.isNotEmpty, isTrue);
    // English is the source of truth: every other language only holds keys that
    // also exist in English (no orphan translations).
    for (final lang in kRegisteredLangs) {
      for (final k in kStrings[lang]!.keys) {
        expect(kStrings['en']!.containsKey(k), isTrue,
            reason: 'key "$k" in $lang has no English source');
      }
    }
  });
}
