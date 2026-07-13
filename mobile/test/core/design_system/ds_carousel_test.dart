import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fyc_connect/core/design_system/components/ds_carousel.dart';

Widget _wrap(Widget c) => MaterialApp(home: Scaffold(body: c));

void main() {
  testWidgets('DSCarousel renders its first item and a dot per item', (tester) async {
    await tester.pumpWidget(_wrap(SizedBox(
      height: 220,
      child: DSCarousel(
        itemCount: 3,
        height: 120,
        itemBuilder: (_, i) => Text('slide $i'),
      ),
    )));

    expect(find.text('slide 0'), findsOneWidget);
    // 3 animated dot indicators.
    expect(find.byType(AnimatedContainer), findsNWidgets(3));

    // Tear the widget down so the auto-advance Timer is cancelled in dispose()
    // (a pending timer fails the test otherwise).
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('DSCarousel with a single item shows no dots and starts no timer', (tester) async {
    await tester.pumpWidget(_wrap(SizedBox(
      height: 160,
      child: DSCarousel(
        itemCount: 1,
        height: 120,
        itemBuilder: (_, i) => const Text('only'),
      ),
    )));
    expect(find.text('only'), findsOneWidget);
    expect(find.byType(AnimatedContainer), findsNothing);
  });
}
