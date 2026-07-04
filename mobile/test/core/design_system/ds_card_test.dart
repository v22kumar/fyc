import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fyc_connect/core/design_system/components/ds_card.dart';

Widget _wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

void main() {
  group('DSCard', () {
    testWidgets('renders child content and responds to tap', (tester) async {
      var tapped = false;
      await tester.pumpWidget(_wrap(
        DSCard(
          kind: DSCardKind.event,
          onTap: () => tapped = true,
          child: const Text('Event details'),
        ),
      ));
      expect(find.text('Event details'), findsOneWidget);
      await tester.tap(find.byType(DSCard));
      await tester.pump();
      expect(tapped, isTrue);
    });

    testWidgets('every kind renders without throwing', (tester) async {
      for (final kind in DSCardKind.values) {
        await tester.pumpWidget(_wrap(
          DSCard(kind: kind, child: Text(kind.name)),
        ));
        expect(find.text(kind.name), findsOneWidget);
      }
    });

    testWidgets('DSCardIcon renders an icon per kind', (tester) async {
      await tester.pumpWidget(_wrap(const DSCardIcon(kind: DSCardKind.blood)));
      expect(find.byType(Icon), findsOneWidget);
    });
  });
}
