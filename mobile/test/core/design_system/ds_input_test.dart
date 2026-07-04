import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fyc_connect/core/design_system/components/ds_input.dart';

Widget _wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

void main() {
  group('DSSearchField', () {
    testWidgets('reports text changes via onChanged', (tester) async {
      String? changed;
      await tester.pumpWidget(_wrap(
        DSSearchField(hint: 'Search members…', onChanged: (v) => changed = v),
      ));
      await tester.enterText(find.byType(TextField), 'Ramesh');
      expect(changed, 'Ramesh');
    });
  });

  group('DSOtpField', () {
    testWidgets('calls onCompleted once all digits are entered', (tester) async {
      String? completed;
      await tester.pumpWidget(_wrap(
        DSOtpField(length: 6, onCompleted: (code) => completed = code),
      ));
      final fields = find.byType(TextField);
      expect(fields, findsNWidgets(6));
      for (var i = 0; i < 6; i++) {
        await tester.enterText(fields.at(i), '$i');
      }
      expect(completed, '012345');
    });
  });

  group('DSDateField / DSLocationField', () {
    testWidgets('DSDateField shows the hint until a value is set, and taps fire onTap', (tester) async {
      var tapped = false;
      await tester.pumpWidget(_wrap(
        DSDateField(hint: 'Select date', onTap: () => tapped = true),
      ));
      expect(find.text('Select date'), findsOneWidget);
      await tester.tap(find.byType(DSDateField));
      await tester.pump();
      expect(tapped, isTrue);
    });

    testWidgets('DSDateField shows the supplied value instead of the hint', (tester) async {
      await tester.pumpWidget(_wrap(
        DSDateField(value: '2026-07-04', hint: 'Select date', onTap: () {}),
      ));
      expect(find.text('2026-07-04'), findsOneWidget);
      expect(find.text('Select date'), findsNothing);
    });

    testWidgets('DSLocationField taps fire onTap', (tester) async {
      var tapped = false;
      await tester.pumpWidget(_wrap(
        DSLocationField(onTap: () => tapped = true),
      ));
      await tester.tap(find.byType(DSLocationField));
      await tester.pump();
      expect(tapped, isTrue);
    });
  });

  group('DSDropdown', () {
    testWidgets('renders label and hint when no value is selected', (tester) async {
      await tester.pumpWidget(_wrap(
        DSDropdown<String>(
          label: 'Category',
          value: null,
          hint: 'Choose one',
          items: const [
            DropdownMenuItem(value: 'cricket', child: Text('Cricket')),
            DropdownMenuItem(value: 'events', child: Text('Events')),
          ],
          onChanged: (_) {},
        ),
      ));
      expect(find.text('Category'), findsOneWidget);
      expect(find.text('Choose one'), findsOneWidget);
    });
  });
}
