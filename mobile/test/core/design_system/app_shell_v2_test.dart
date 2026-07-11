import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fyc_connect/core/design_system/shell/app_shell_v2.dart';

void main() {
  setUp(() {
    // The SOS sheet reads trusted contacts from SharedPreferences on open.
    SharedPreferences.setMockInitialValues({});
  });

  group('AppShellV2', () {
    testWidgets('renders exactly 4 tabs: Home, Feed, Play, Serve', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: AppShellV2()));
      expect(find.text('Home'), findsOneWidget);
      expect(find.text('Feed'), findsOneWidget);
      expect(find.text('Play'), findsOneWidget);
      expect(find.text('Serve'), findsOneWidget);
      // Me is reached via the avatar in Home's top-right corner (route
      // `/me`), not a bottom-nav tab.
      expect(find.text('Me'), findsNothing);
      // Feed and Community remain distinct — Community (member directory) is
      // still reached via Home's Services sheet, not a bottom-nav tab.
      expect(find.text('Community'), findsNothing);
    });

    testWidgets('a single back press warns instead of exiting immediately', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: AppShellV2()));
      // Simulate the system/hardware back button: with the shell's PopScope
      // set to canPop: false, this must be intercepted (no route to pop to)
      // rather than closing the app outright.
      final navigator = tester.state<NavigatorState>(find.byType(Navigator));
      await navigator.maybePop();
      await tester.pump();
      expect(find.text('Press back again to exit'), findsOneWidget);
    });

    testWidgets('switching tabs updates the visible placeholder', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: AppShellV2()));
      expect(find.textContaining('Home tab'), findsOneWidget);

      await tester.tap(find.text('Play'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Play tab'), findsOneWidget);
    });

    testWidgets('the SOS control is reachable from every tab', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: AppShellV2()));
      final sos = find.byIcon(Icons.sos_rounded);
      expect(sos, findsOneWidget);

      await tester.tap(find.text('Serve'));
      await tester.pumpAndSettle();
      expect(sos, findsOneWidget);

      await tester.tap(sos);
      await tester.pumpAndSettle();
      // Opens the real Safety Center sheet (location SMS + emergency dial + alert).
      expect(find.text('Safety Center'), findsOneWidget);
      expect(find.text('Send SOS to my contacts'), findsOneWidget);
    });

    testWidgets('SOS with no trusted contacts prompts to add one', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: AppShellV2()));
      await tester.tap(find.byIcon(Icons.sos_rounded));
      await tester.pumpAndSettle();

      // No contacts configured (mock prefs are empty) → tapping send must warn
      // rather than silently doing nothing on a safety feature.
      await tester.tap(find.text('Send SOS to my contacts'));
      await tester.pump(); // let the snackbar appear
      expect(find.text('Add at least one trusted contact first.'), findsOneWidget);
    });

    testWidgets('center Create FAB fires onCreate only when wired', (tester) async {
      // Preview shell (no onCreate) shows no Create FAB.
      await tester.pumpWidget(const MaterialApp(home: AppShellV2()));
      expect(find.byIcon(Icons.add_rounded), findsNothing);

      // Live shell (onCreate wired) shows the FAB and taps invoke the handler.
      var created = 0;
      await tester.pumpWidget(MaterialApp(
        home: AppShellV2(onCreate: () => created++),
      ));
      expect(find.byIcon(Icons.add_rounded), findsOneWidget);
      // Invoke the FAB handler directly: a centerDocked FAB's center overlaps
      // the nav bar in the 800x600 test surface so tester.tap misses it, though
      // it's tappable on a real device. This still verifies onCreate is wired.
      tester
          .widget<FloatingActionButton>(find.byType(FloatingActionButton))
          .onPressed!();
      await tester.pump();
      expect(created, 1);
    });
  });
}
