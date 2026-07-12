import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fyc_connect/core/design_system/components/ds_feature_card.dart';

Widget _wrap(Widget child) =>
    MaterialApp(home: Scaffold(body: Center(child: SizedBox(width: 180, height: 200, child: child))));

void main() {
  group('DSFeatureCard', () {
    testWidgets('renders title, subtitle and responds to tap', (tester) async {
      var tapped = false;
      await tester.pumpWidget(_wrap(
        DSFeatureCard(
          icon: Icons.bloodtype_rounded,
          title: 'Blood Donation',
          subtitle: 'Verified donors near you',
          tint: const Color(0xFFF43F5E),
          onTap: () => tapped = true,
        ),
      ));
      expect(find.text('Blood Donation'), findsOneWidget);
      expect(find.text('Verified donors near you'), findsOneWidget);
      await tester.tap(find.byType(DSFeatureCard));
      await tester.pump();
      expect(tapped, isTrue);
    });

    testWidgets('shows the status pill only when a label is given', (tester) async {
      await tester.pumpWidget(_wrap(
        DSFeatureCard(
          icon: Icons.work_rounded,
          title: 'Opportunities',
          subtitle: 'Jobs & gigs',
          tint: const Color(0xFFB78B12),
          pillLabel: 'Jobs',
          onTap: () {},
        ),
      ));
      // Pill upper-cases its label.
      expect(find.text('JOBS'), findsOneWidget);
    });
  });
}
