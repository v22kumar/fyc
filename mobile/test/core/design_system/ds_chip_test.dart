import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fyc_connect/core/design_system/components/ds_chip.dart';

Widget _wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

void main() {
  group('DSChip', () {
    testWidgets('renders its label', (tester) async {
      await tester.pumpWidget(_wrap(
        const DSChip(label: 'Cricket', kind: DSChipKind.sport),
      ));
      expect(find.text('Cricket'), findsOneWidget);
    });

    testWidgets('status factory maps known statuses without throwing', (tester) async {
      for (final status in ['LIVE', 'UPCOMING', 'COMPLETED', 'UNKNOWN_STATUS']) {
        await tester.pumpWidget(_wrap(DSChip.status(status)));
        expect(find.text(status), findsOneWidget);
      }
    });

    testWidgets('tap triggers onTap callback', (tester) async {
      var tapped = false;
      await tester.pumpWidget(_wrap(
        DSChip(label: 'Toggle', onTap: () => tapped = true),
      ));
      await tester.tap(find.byType(DSChip));
      await tester.pump();
      expect(tapped, isTrue);
    });
  });
}
