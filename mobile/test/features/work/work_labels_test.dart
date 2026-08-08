import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:fyc_connect/core/l10n/registry/en.dart';
import 'package:fyc_connect/core/l10n/registry/hi.dart';
import 'package:fyc_connect/core/l10n/registry/ml.dart';
import 'package:fyc_connect/core/l10n/registry/ta.dart';
import 'package:fyc_connect/core/l10n/tr.dart';
import 'package:fyc_connect/core/storage/local_storage.dart';
import 'package:fyc_connect/core/theme/app_theme.dart';
import 'package:fyc_connect/service_locator.dart';

/// The category chips are the whole navigation of the work index.
///
/// A chip whose label failed to resolve renders as a bare count, or as nothing
/// — and the main screen becomes a row of empty pills with no way to tell what
/// any of them are. The keys are built by string interpolation from the
/// category code, so nothing at compile time catches a mismatch between the
/// enum and the registry. This does.
const _categories = [
  'TUITION', 'CARPENTRY', 'MASONRY', 'PAINTING', 'ELECTRICAL', 'PLUMBING',
  'WELDING', 'BIKE_REPAIR', 'CAR_REPAIR', 'MOBILE_REPAIR', 'COMPUTER',
  'SOFTWARE', 'PHOTOGRAPHY', 'VIDEOGRAPHY', 'TAILORING', 'CATERING',
  'DRIVER', 'DAILY_LABOUR', 'CLEANING', 'BEAUTY', 'EVENTS', 'REPAIRS_GENERAL',
];

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    if (!sl.isRegistered<LocalStorage>()) {
      sl.registerSingleton<LocalStorage>(LocalStorage(prefs));
    }
    await sl<LocalStorage>().saveLang('en');
  });

  test('every category has a name in every language', () {
    for (final lang in {'en': kEn, 'ta': kTa, 'hi': kHi, 'ml': kMl}.entries) {
      for (final c in _categories) {
        final key = 'work_cat_${c.toLowerCase()}';
        expect(lang.value[key], isNotNull,
            reason: '$key missing from ${lang.key} — the chip would render as '
                'its own id, or as a bare count');
        expect(lang.value[key]!.trim(), isNotEmpty);
      }
    }
  });

  test('no work string falls through to its own id', () {
    for (final id in [
      'work', 'work_search_hint', 'list_what_you_do', 'jobs_done',
      'work_member_since', 'work_be_the_first', 'new_no_jobs_yet',
      'nothing_found', 'publish_listing', 'i_am_a_shop',
    ]) {
      expect(trId(id), isNot(id), reason: '$id is not registered');
    }
  });

  testWidgets('a category chip renders a readable label, not a bare count',
      (t) async {
    await t.pumpWidget(MaterialApp(
      theme: AppTheme.lightFor('en'),
      home: Scaffold(
        body: ActionChip(
          label: Text('${trId('work_cat_carpentry')} · 12'),
          onPressed: () {},
        ),
      ),
    ));
    expect(find.text('Carpentry · 12'), findsOneWidget);
  });
}
