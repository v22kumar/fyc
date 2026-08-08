import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Every path the app links to must be a path the app declares.
///
/// This has now been the same bug three times. The Complaint Box shipped on a
/// route nothing linked to. The work index shipped with every entry point
/// aimed at the old screen. And then the `/work` routes were lost in a rebase,
/// leaving the imports behind, `/opportunities` redirecting to a path that did
/// not exist, and every tile on Home landing on route-not-found.
///
/// Nothing catches that on its own. The analyzer sees an unused import and
/// shrugs, the widget tests never navigate, and CI goes green — only opening
/// the app finds it, and by then it is in somebody's hands.
void main() {
  final router = _read('lib/core/router/app_router.dart');
  final home = _read('lib/features/home/presentation/screens/home_screen.dart');
  final serve =
      _read('lib/features/serve/presentation/screens/serve_hub_screen.dart');

  Set<String> declared() => RegExp(r"path: '(/[^']*)'")
      .allMatches(router)
      .map((m) => m.group(1)!)
      .toSet();

  test('every redirect target is a route that exists', () {
    final targets = RegExp(r"redirect: \([^)]*\) => '(/[^']*)'")
        .allMatches(router)
        .map((m) => m.group(1)!)
        .toSet();

    for (final t in targets) {
      expect(declared(), contains(t),
          reason: '$t is redirected to but never declared, so every link to '
              'it lands on route-not-found');
    }
  });

  test('the work index is reachable', () {
    // Named explicitly, because this is the one that broke and a generic
    // assertion would pass happily on an app with no routes at all.
    expect(declared(), contains('/work'));
    expect(declared(), contains('/work/list'));
  });

  test('every route a Home tile names is declared', () {
    final tileRoutes = RegExp(r"route: '(/[^']*)'")
        .allMatches(home)
        .map((m) => m.group(1)!)
        .toSet();
    expect(tileRoutes, isNotEmpty, reason: 'the tiles moved — update this');

    for (final r in tileRoutes) {
      expect(declared(), contains(r.split('?').first),
          reason: 'a Home tile opens $r, which no route declares');
    }
  });

  test('no work-shaped tile still opens the community feed', () {
    // "Skills Directory — carpenters, electricians, tutors" opened threads and
    // photographs for as long as this feature had existed.
    final atCommunity = RegExp(r"skills_directory[\s\S]{0,400}?'/community'");
    expect(atCommunity.hasMatch(home), isFalse);
    expect(atCommunity.hasMatch(serve), isFalse);
  });
}

/// Read the source with `//` comments stripped.
///
/// Without this the assertions match their own explanation: a comment reading
/// "was '/community' — the feed" is indistinguishable from code that still
/// opens it. A test that greps prose will eventually fail on a sentence
/// somebody wrote about the bug it is guarding against.
String _read(String path) => File(path)
    .readAsLinesSync()
    .map((l) {
      final i = l.indexOf('//');
      return i == -1 ? l : l.substring(0, i);
    })
    .join('\n');
