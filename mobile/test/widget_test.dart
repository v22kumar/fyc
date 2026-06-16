import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:fyc_connect/main.dart';
import 'package:fyc_connect/service_locator.dart';

void main() {
  testWidgets('App boots to the splash screen without throwing', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await initServiceLocator();

    await tester.pumpWidget(const FycApp());
    // One frame for the splash animation + AuthCheckRequested to resolve
    // (no token in mock prefs, so it settles on AuthUnauthenticated locally,
    // no network call is made).
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.text('FYC Connect'), findsOneWidget);
  });
}
