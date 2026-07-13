import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fyc_connect/core/storage/local_storage.dart';
import 'package:fyc_connect/service_locator.dart';
import 'package:fyc_connect/core/design_system/components/last_updated_pill.dart';

Widget _wrap(Widget c) => MaterialApp(home: Scaffold(body: c));

void main() {
  // tr() reads the language from sl<LocalStorage>(). The app is Tamil-first, so
  // register a stub and pin the language to English for these assertions.
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    if (!sl.isRegistered<LocalStorage>()) {
      sl.registerSingleton<LocalStorage>(LocalStorage(prefs));
    }
    await sl<LocalStorage>().saveLang('en');
  });

  testWidgets('LastUpdatedPill reads "just now" for a fresh timestamp', (tester) async {
    await tester.pumpWidget(_wrap(LastUpdatedPill(timestamp: DateTime.now())));
    expect(find.textContaining('just now'), findsOneWidget);
    expect(find.byIcon(Icons.schedule_rounded), findsOneWidget);
  });

  testWidgets('LastUpdatedPill shows minutes for an older timestamp', (tester) async {
    final ts = DateTime.now().subtract(const Duration(minutes: 5));
    await tester.pumpWidget(_wrap(LastUpdatedPill(timestamp: ts)));
    expect(find.textContaining('5m ago'), findsOneWidget);
  });
}
