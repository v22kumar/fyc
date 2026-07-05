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
    testWidgets('renders exactly 4 tabs: Home, Play, Serve, Me', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: AppShellV2()));
      expect(find.text('Home'), findsOneWidget);
      expect(find.text('Play'), findsOneWidget);
      expect(find.text('Serve'), findsOneWidget);
      expect(find.text('Me'), findsOneWidget);
      // Confirms the locked IA decision: no separate Community tab/destination.
      expect(find.text('Community'), findsNothing);
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
      // Opens the real SOS action sheet (location SMS + emergency dial).
      expect(find.text('Emergency SOS'), findsOneWidget);
      expect(find.text('Send SOS to my contacts'), findsOneWidget);
    });
  });
}
