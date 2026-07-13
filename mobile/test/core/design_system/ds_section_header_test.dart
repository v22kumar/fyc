import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fyc_connect/core/design_system/components/ds_section_header.dart';

Widget _wrap(Widget c) => MaterialApp(home: Scaffold(body: c));

void main() {
  testWidgets('DSSectionHeader shows title + action and fires onAction', (tester) async {
    var tapped = false;
    await tester.pumpWidget(_wrap(DSSectionHeader(
      title: 'Upcoming Events',
      icon: Icons.event_rounded,
      actionLabel: 'View all',
      onAction: () => tapped = true,
    )));

    expect(find.text('Upcoming Events'), findsOneWidget);
    expect(find.byIcon(Icons.event_rounded), findsOneWidget);

    await tester.tap(find.text('View all'));
    expect(tapped, isTrue);
  });

  testWidgets('DSSectionHeader omits the action when none is given', (tester) async {
    await tester.pumpWidget(_wrap(const DSSectionHeader(title: 'Our Impact')));
    expect(find.text('Our Impact'), findsOneWidget);
    expect(find.byIcon(Icons.chevron_right_rounded), findsNothing);
  });
}
