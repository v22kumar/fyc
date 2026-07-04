import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fyc_connect/core/design_system/components/ds_button.dart';

Widget _wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

void main() {
  group('DSButton', () {
    testWidgets('filled variant renders label and responds to tap', (tester) async {
      var tapped = false;
      await tester.pumpWidget(_wrap(
        DSButton.filled(label: 'Save', onPressed: () => tapped = true),
      ));
      expect(find.text('Save'), findsOneWidget);
      await tester.tap(find.byType(DSButton));
      await tester.pump();
      expect(tapped, isTrue);
    });

    testWidgets('all variants render their label', (tester) async {
      await tester.pumpWidget(_wrap(Column(children: [
        DSButton.filled(label: 'Filled', onPressed: () {}),
        DSButton.outlined(label: 'Outlined', onPressed: () {}),
        DSButton.tonal(label: 'Tonal', onPressed: () {}),
        DSButton.text(label: 'Text', onPressed: () {}),
        DSButton.danger(label: 'Danger', onPressed: () {}),
      ])));
      for (final label in ['Filled', 'Outlined', 'Tonal', 'Text', 'Danger']) {
        expect(find.text(label), findsOneWidget);
      }
    });

    testWidgets('disabled button (onPressed null) does not respond to tap', (tester) async {
      var tapped = false;
      await tester.pumpWidget(_wrap(
        DSButton.filled(label: 'Disabled', onPressed: null),
      ));
      await tester.tap(find.byType(DSButton), warnIfMissed: false);
      await tester.pump();
      expect(tapped, isFalse);
    });

    testWidgets('loading state hides the label and shows a spinner', (tester) async {
      await tester.pumpWidget(_wrap(
        DSButton.filled(label: 'Submitting', onPressed: () {}, loading: true),
      ));
      expect(find.text('Submitting'), findsNothing);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });
  });
}
