import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:fyc_connect/core/storage/local_storage.dart';
import 'package:fyc_connect/core/theme/app_theme.dart';
import 'package:fyc_connect/service_locator.dart';
import 'package:fyc_connect/features/complaint_box/domain/entities/complaint_entities.dart';
import 'package:fyc_connect/features/complaint_box/presentation/widgets/ladder_list.dart';

/// Someone who needs a government office is disproportionately likely to be
/// using a large system font. The ladder is the screen they cannot do without,
/// so it has to survive 200% without losing a phone number off the edge.
void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    if (!sl.isRegistered<LocalStorage>()) {
      sl.registerSingleton<LocalStorage>(LocalStorage(prefs));
    }
    await sl<LocalStorage>().saveLang('en');
  });

  const ladder = CallLadder(
    category: 'STREET_LIGHT',
    rungs: [
      LadderRung(
        position: 1, departmentCode: 'ULB', departmentName: 'Corporation',
        covers: 'your ward', canCall: false, canWrite: false, waitDays: 14,
        designation: 'Ward Councillor',
      ),
      LadderRung(
        position: 2, departmentCode: 'ULB', departmentName: 'Corporation',
        covers: 'your area', canCall: true, canWrite: true, waitDays: 14,
        designation: 'Assistant Engineer — Street Lighting',
        phone: '9443132365', email: 'ae@x.gov.in',
      ),
    ],
  );

  Future<void> pumpAt(WidgetTester t, double scale) async {
    await t.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => t.binding.setSurfaceSize(null));
    await t.pumpWidget(MaterialApp(
      theme: AppTheme.lightFor('en'),
      home: MediaQuery(
        data: MediaQueryData(textScaler: TextScaler.linear(scale)),
        child: Scaffold(
          body: SingleChildScrollView(
            child: LadderList(
                ladder: ladder, onCalled: (_) {}, onWrite: (_) {}),
          ),
        ),
      ),
    ));
    await t.pump();
  }

  for (final scale in [1.0, 1.5, 2.0]) {
    testWidgets('the ladder survives ${scale}x text without overflowing',
        (t) async {
      await pumpAt(t, scale);
      expect(recordedExceptions(), isEmpty,
          reason: 'a RenderFlex overflow at ${scale}x means a member with '
              'large type loses part of the screen they came for');
    });
  }

  testWidgets('the phone number is still on screen at 2x', (t) async {
    await pumpAt(t, 2.0);
    expect(find.text('94431 32365'), findsOneWidget);
  });

  testWidgets('a screen reader is given the number as separate digits',
      (t) async {
    await pumpAt(t, 1.0);
    final handle = t.ensureSemantics();
    // Read as one integer, "9443132365" is useless to somebody writing it down.
    expect(
      find.bySemanticsLabel('9 4 4 3 1 3 2 3 6 5'),
      findsOneWidget,
    );
    handle.dispose();
  });

  testWidgets('a call button says who it calls', (t) async {
    await pumpAt(t, 1.0);
    final handle = t.ensureSemantics();
    expect(
      find.bySemanticsLabel('Call Assistant Engineer — Street Lighting'),
      findsOneWidget,
    );
    handle.dispose();
  });
}

/// Any exception the framework recorded while laying out — overflow errors
/// arrive this way rather than as thrown exceptions.
List<Object> recordedExceptions() {
  final errors = <Object>[];
  final caught = TestWidgetsFlutterBinding.instance.takeException();
  if (caught != null) errors.add(caught as Object);
  return errors;
}
