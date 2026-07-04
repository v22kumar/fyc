import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fyc_connect/core/design_system/components/ds_badge.dart';

Widget _wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

void main() {
  group('DSBadge', () {
    testWidgets('every kind renders its default label', (tester) async {
      const expected = {
        DSBadgeKind.live: 'LIVE',
        DSBadgeKind.urgent: 'URGENT',
        DSBadgeKind.isNew: 'NEW',
        DSBadgeKind.verified: 'VERIFIED',
        DSBadgeKind.closed: 'CLOSED',
        DSBadgeKind.volunteer: 'VOLUNTEER',
      };
      for (final entry in expected.entries) {
        await tester.pumpWidget(_wrap(DSBadge(kind: entry.key)));
        await tester.pump(const Duration(milliseconds: 100));
        expect(find.text(entry.value), findsOneWidget);
      }
    });

    testWidgets('labelOverride replaces the default text', (tester) async {
      await tester.pumpWidget(_wrap(
        const DSBadge(kind: DSBadgeKind.verified, labelOverride: 'ADMIN'),
      ));
      expect(find.text('ADMIN'), findsOneWidget);
      expect(find.text('VERIFIED'), findsNothing);
    });

    testWidgets('live badge pulses without throwing across frames', (tester) async {
      await tester.pumpWidget(_wrap(const DSBadge(kind: DSBadgeKind.live)));
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byType(DSBadge), findsOneWidget);
    });
  });
}
