import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fyc_connect/core/design_system/components/ds_animated_counter.dart';

Widget _wrap(Widget c) => MaterialApp(home: Scaffold(body: c));

void main() {
  testWidgets('DSAnimatedCounter settles on its final value with suffix', (tester) async {
    await tester.pumpWidget(_wrap(const DSAnimatedCounter(value: 1500, suffix: '+')));
    await tester.pumpAndSettle();
    expect(find.text('1500+'), findsOneWidget);
  });

  testWidgets('DSAnimatedCounter jumps to final value when animations are disabled', (tester) async {
    await tester.pumpWidget(_wrap(
      const MediaQuery(
        data: MediaQueryData(disableAnimations: true),
        child: DSAnimatedCounter(value: 80),
      ),
    ));
    await tester.pump();
    expect(find.text('80'), findsOneWidget);
  });
}
