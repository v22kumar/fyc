import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Strings must go *through* the registry, not just exist in it.
///
/// The parity test proves every registered string has four translations. It
/// cannot see a label that was never registered — and that is how the chess
/// screen ended up with a Tamil headline over "Games Played", "Best Rating"
/// and "Win Streak" in English. Nothing was missing; those words had simply
/// never been offered for translation.
///
/// So this walks the source for text handed straight to a widget as a literal.
/// It is deliberately narrow — the named parameters that end up on screen —
/// because a broad "no string literals" rule would be noise nobody reads.
void main() {
  // Text a member reads, passed by name.
  final labelParam = RegExp(
    r"""(?:^|[\s(\[{,])(?:label|title|text|hint|hintText|labelText|tooltip|helperText|errorText)\s*:\s*'([^'\\]{2,}?)'""",
  );
  final hasLetters = RegExp(r'[A-Za-z]{2}|[஀-௿]|[ऀ-ॿ]|[ഀ-ൿ]');

  /// Not text: identifiers, assets, routes, and the separator between two
  /// player names, which reads the same in every script this app supports.
  bool isExempt(String s) =>
      s.startsWith('http') ||
      s.startsWith('/') ||
      s.startsWith('assets') ||
      s.trim() == 'vs' ||
      s.contains(r'$');

  test('no user-facing literal bypasses the registry', () {
    final offenders = <String>[];
    final lib = Directory('lib');

    for (final entity in lib.listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      // The registry itself is where the literals belong. The design-system
      // gallery is a developer surface, not a member-facing screen.
      final normalizedPath = entity.path.replaceAll(r'\', '/');
      if (normalizedPath.contains('l10n/registry') ||
          normalizedPath.contains('design_system/design_system_gallery') ||
          normalizedPath.contains('dev_screenshot_harness')) {
        continue;
      }

      final lines = entity.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        final line = lines[i];
        if (line.contains('trId(') || line.contains('tr(')) continue;
        for (final m in labelParam.allMatches(line)) {
          final value = m.group(1)!;
          if (!hasLetters.hasMatch(value) || isExempt(value)) continue;
          offenders.add('${entity.path}:${i + 1}  $value');
        }
      }
    }

    expect(
      offenders,
      isEmpty,
      reason: '${offenders.length} literal(s) will never be translated. '
          'Add an id to lib/core/l10n/registry/en.dart (and the other three '
          'languages) and call trId():\n  ${offenders.join('\n  ')}',
    );
  });
}
