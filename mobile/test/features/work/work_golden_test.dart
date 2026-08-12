@Tags(['golden'])
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:fyc_connect/core/storage/local_storage.dart';
import 'package:fyc_connect/core/theme/app_theme.dart';
import 'package:fyc_connect/service_locator.dart';
import 'package:fyc_connect/features/work/domain/entities/work_entities.dart';
import 'package:fyc_connect/features/work/presentation/widgets/listing_card.dart';

/// Visual regression, because the worst UI bugs are invisible to every other
/// kind of test.
///
/// Every chip label in the light theme painted nothing for as long as the
/// theme has existed: the text laid out at the correct width and simply did
/// not appear. `flutter analyze` was clean, every widget test passed, and
/// `find.text` found it — because it *was* there. Only a picture showed it,
/// and only because somebody looked at the picture.
///
/// A golden turns "somebody looked" into "CI looked".
///
///     flutter test --tags golden                       # check
///     flutter test --tags golden --update-goldens      # accept a change
///
/// These are exact-pixel comparisons, so they are only meaningful against a
/// fixed Flutter. CI pins one (see .github/workflows/ci-tests.yml); these
/// images were produced on 3.44.8. A different engine renders the same text a
/// fraction of a percent differently and every golden fails at once — which
/// is the signature of a version bump, not of a bug. Bump the pin and the
/// images together, and look at what changed before accepting it.
void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    if (!sl.isRegistered<LocalStorage>()) {
      sl.registerSingleton<LocalStorage>(LocalStorage(prefs));
    }
    await sl<LocalStorage>().saveLang('en');

    // Every weight in one loader. Loading 700 through a second FontLoader for
    // the same family does not merge with the first, and bold text then paints
    // nothing — which would bake a blank golden and lock the bug in.
    final latin = FontLoader('Plus Jakarta Sans');
    for (final w in ['400', '600', '700', '800']) {
      latin.addFont(File('assets/fonts/PlusJakartaSans-$w.ttf')
          .readAsBytes()
          .then((b) => b.buffer.asByteData()));
    }
    await latin.load();
  });

  const worked = WorkListing(
    id: 'l1', kind: ListingKind.person, displayName: 'Murugan A.',
    category: 'CARPENTRY', phone: '9443132365', area: 'Vadasery',
    about: 'interlock brick work, doors',
    trust: ListingTrust(
        phoneVerified: true, jobsConfirmed: 9, isNew: false,
        memberSinceYear: 2022),
  );

  const fresh = WorkListing(
    id: 'l2', kind: ListingKind.business, displayName: 'Selvam Furniture',
    category: 'CARPENTRY', phone: '9443100000', area: 'Putheri',
    about: 'Custom furniture and repairs', hours: '9am – 8pm',
    trust: ListingTrust(
        phoneVerified: true, jobsConfirmed: 0, isNew: true,
        memberSinceYear: 2026),
  );

  Widget frame(Widget child, Brightness b) => MaterialApp(
        theme: b == Brightness.light
            ? AppTheme.lightFor('en')
            : AppTheme.darkFor('en'),
        home: Scaffold(
          body: Padding(padding: const EdgeInsets.all(16), child: child),
        ),
      );

  for (final b in [Brightness.light, Brightness.dark]) {
    final name = b == Brightness.light ? 'light' : 'dark';

    testWidgets('listing cards — $name', (t) async {
      await t.binding.setSurfaceSize(const Size(390, 420));
      addTearDown(() => t.binding.setSurfaceSize(null));
      await t.pumpWidget(frame(
        Column(children: [
          ListingCard(listing: worked, onOpened: (_) {}),
          ListingCard(listing: fresh, onOpened: (_) {}),
        ]),
        b,
      ));
      await t.pump(const Duration(milliseconds: 200));
      await expectLater(find.byType(Column).first,
          matchesGoldenFile('goldens/cards_$name.png'));
    });

    testWidgets('a chip actually paints its label — $name', (t) async {
      // The specific failure this whole file exists for.
      await t.binding.setSurfaceSize(const Size(390, 120));
      addTearDown(() => t.binding.setSurfaceSize(null));
      await t.pumpWidget(frame(
        Align(
          alignment: Alignment.topLeft,
          child: ActionChip(
            label: const Text('Carpentry · 12'),
            onPressed: () {},
          ),
        ),
        b,
      ));
      await t.pump(const Duration(milliseconds: 200));
      await expectLater(find.byType(ActionChip),
          matchesGoldenFile('goldens/chip_$name.png'));
    });
  }
}
