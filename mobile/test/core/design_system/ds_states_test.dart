import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fyc_connect/core/design_system/components/ds_empty_state.dart';
import 'package:fyc_connect/core/design_system/components/ds_error_state.dart';
import 'package:fyc_connect/core/design_system/components/ds_skeleton.dart';

Widget _wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

void main() {
  group('DSEmptyState', () {
    testWidgets('never shows a raw "No Data" — always title, message, and a primary action', (tester) async {
      var primaryTapped = false;
      var secondaryTapped = false;
      await tester.pumpWidget(_wrap(
        DSEmptyState(
          title: 'No posts yet',
          message: 'Be the first to share something.',
          primaryLabel: 'Create Post',
          onPrimary: () => primaryTapped = true,
          secondaryLabel: 'Refresh',
          onSecondary: () => secondaryTapped = true,
        ),
      ));
      expect(find.text('No Data'), findsNothing);
      expect(find.text('No posts yet'), findsOneWidget);
      expect(find.text('Create Post'), findsOneWidget);
      expect(find.text('Refresh'), findsOneWidget);

      await tester.tap(find.text('Create Post'));
      await tester.pump();
      expect(primaryTapped, isTrue);

      await tester.tap(find.text('Refresh'));
      await tester.pump();
      expect(secondaryTapped, isTrue);
    });

    testWidgets('renders without a secondary action when none is supplied', (tester) async {
      await tester.pumpWidget(_wrap(
        DSEmptyState(
          title: 'Empty',
          message: 'Nothing here.',
          primaryLabel: 'Add',
          onPrimary: () {},
        ),
      ));
      expect(find.text('Add'), findsOneWidget);
    });
  });

  group('DSErrorState', () {
    testWidgets('shows a human message and a retry action, never a raw status code', (tester) async {
      var retried = false;
      await tester.pumpWidget(_wrap(
        DSErrorState(
          message: "We couldn't load your journey.",
          onRetry: () => retried = true,
        ),
      ));
      expect(find.text('500'), findsNothing);
      expect(find.textContaining("We couldn't load"), findsOneWidget);
      await tester.tap(find.text('Retry'));
      await tester.pump();
      expect(retried, isTrue);
    });
  });

  group('DSSkeleton', () {
    testWidgets('DSSkeletonList renders the requested number of placeholder cards', (tester) async {
      await tester.pumpWidget(_wrap(const DSSkeletonList(itemCount: 3)));
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.byType(DSSkeletonBlock), findsWidgets);
    });
  });
}
