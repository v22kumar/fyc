import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fyc_connect/core/design_system/components/ds_collapsible_section.dart';

Widget _wrap(Widget c) => MaterialApp(home: Scaffold(body: c));

void main() {
  testWidgets('DSCollapsibleSection toggles its child on header tap', (tester) async {
    await tester.pumpWidget(_wrap(const DSCollapsibleSection(
      title: 'Daily News',
      child: Text('body content'),
    )));

    // Expanded by default.
    expect(find.text('body content'), findsOneWidget);

    await tester.tap(find.text('Daily News'));
    await tester.pumpAndSettle();
    expect(find.text('body content'), findsNothing);

    await tester.tap(find.text('Daily News'));
    await tester.pumpAndSettle();
    expect(find.text('body content'), findsOneWidget);
  });

  testWidgets('DSCollapsibleSection respects initiallyExpanded: false', (tester) async {
    await tester.pumpWidget(_wrap(const DSCollapsibleSection(
      title: 'More',
      initiallyExpanded: false,
      child: Text('hidden'),
    )));
    expect(find.text('hidden'), findsNothing);
  });
}
