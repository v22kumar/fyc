import 'package:flutter_test/flutter_test.dart';
import 'package:fyc_connect/core/l10n/registry/registry.dart';

/// Every string, in every language. Enforced, not remembered.
///
/// `trId` falls back to English when a key is missing, which is the right
/// runtime behaviour and a terrible way to find out: nothing throws, nothing
/// logs, and the screen simply comes out half in English. That is exactly how
/// this app shipped a Tamil blood-donation sheet with "Units" and "Hospital
/// (optional)" in the middle of it — for a club in Nagercoil, on the screen
/// that matters most.
///
/// So the rule is a test. Add a string to `en.dart` and this fails until it
/// exists in every other registered language.
///
/// **Adding a language** stays a two-line job: create `xx.dart`, add it to
/// `kStrings` and `kRegisteredLangs` in `registry.dart`. This test then covers
/// it automatically — there is nothing to remember here either.
void main() {
  final english = kStrings['en']!;

  test('English is the complete set every other language is measured against',
      () {
    expect(english, isNotEmpty);
    expect(kRegisteredLangs.first, 'en',
        reason: 'English is the reference; keep it first');
  });

  for (final lang in kRegisteredLangs.where((l) => l != 'en')) {
    group(lang, () {
      final strings = kStrings[lang];

      test('is registered', () {
        expect(strings, isNotNull,
            reason: '$lang is in kRegisteredLangs but has no map in kStrings');
      });

      test('translates every English string', () {
        final missing = english.keys.where((k) => !strings!.containsKey(k)).toList()
          ..sort();
        expect(
          missing,
          isEmpty,
          reason: '${missing.length} string(s) have no $lang translation and '
              'will render in English mid-screen:\n  ${missing.join('\n  ')}',
        );
      });

      test('has no keys English does not', () {
        // A key here and not in English is a typo or a leftover: it can never
        // be looked up, because every call site resolves through an id that
        // English defines.
        final orphans = strings!.keys.where((k) => !english.containsKey(k)).toList()
          ..sort();
        expect(orphans, isEmpty,
            reason: 'unreachable $lang keys:\n  ${orphans.join('\n  ')}');
      });

      test('keeps every placeholder the English string has', () {
        // '{n} donors' translated as 'donors' silently drops the number.
        final placeholder = RegExp(r'\{(\w+)\}');
        final broken = <String>[];
        for (final entry in english.entries) {
          final mine = strings![entry.key];
          if (mine == null) continue;
          final want = placeholder
              .allMatches(entry.value)
              .map((m) => m.group(1)!)
              .toSet();
          final got =
              placeholder.allMatches(mine).map((m) => m.group(1)!).toSet();
          if (want.difference(got).isNotEmpty) {
            broken.add('${entry.key}: expected ${want.toList()}, got ${got.toList()}');
          }
        }
        expect(broken, isEmpty,
            reason: 'placeholders dropped in $lang:\n  ${broken.join('\n  ')}');
      });
    });
  }
}
