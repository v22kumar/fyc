import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:fyc_connect/core/storage/local_storage.dart';
import 'package:fyc_connect/features/safety/presentation/bloc/sos_bloc.dart';
import 'package:fyc_connect/features/safety/presentation/screens/sos_screen.dart';
import 'package:fyc_connect/service_locator.dart';

import '../../core/safety/fake_safety_repository.dart';

/// Raising an SOS and arriving somewhere useful.
///
/// The failure this covers is the worst one the feature can have: the alert
/// goes out — the server has the incident, members have been pushed — and the
/// member is left looking at a blank screen, with no way to say they are safe,
/// no way to see whether anybody is coming, and no Call 112 button.
void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    if (!sl.isRegistered<LocalStorage>()) {
      sl.registerSingleton<LocalStorage>(LocalStorage(prefs));
    }
    await sl<LocalStorage>().saveLang('en');
  });

  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<void> pumpRoute(WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    // Exactly what the router builds for `/sos`.
    await tester.pumpWidget(MaterialApp(
      home: BlocProvider(
        create: (_) => SosBloc(
          FakeSafetyRepository(contacts: 1),
          probe: fakeProbe(),
        ),
        child: const SosScreen(),
      ),
    ));
    await tester.pump();
  }

  Future<void> holdAndWait(WidgetTester tester) async {
    final gesture =
        await tester.startGesture(tester.getCenter(find.text('Hold to\nsend SOS')));
    for (var i = 0; i < 80; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    await gesture.up();
    // Five seconds of countdown, then the raise.
    for (var i = 0; i < 14; i++) {
      await tester.pump(const Duration(milliseconds: 500));
    }
  }

  testWidgets('raising an SOS lands on the live screen, not a blank one',
      (tester) async {
    await pumpRoute(tester);
    await holdAndWait(tester);

    // The bug: the live screen was reached with `Navigator.pushReplacement`
    // onto the root navigator, which puts it OUTSIDE the BlocProvider that
    // the route created — and disposes that provider on the way. Its
    // BlocBuilder threw ProviderNotFoundException, which in a release build
    // is a grey rectangle where the screen should be.
    expect(tester.takeException(), isNull);
    expect(find.text('SOS sent'), findsOneWidget);
  });

  testWidgets('the live screen keeps 112 and "I\'m safe" reachable',
      (tester) async {
    await pumpRoute(tester);
    await holdAndWait(tester);

    // The two things a member must still be able to do after the alert has
    // gone. Losing them is what made the blank screen dangerous rather than
    // merely broken.
    expect(find.text('Call 112 now'), findsOneWidget);
    expect(find.text("I'm safe"), findsOneWidget);
  });

  testWidgets('cancelling during the countdown sends nothing', (tester) async {
    await pumpRoute(tester);

    final gesture =
        await tester.startGesture(tester.getCenter(find.text('Hold to\nsend SOS')));
    for (var i = 0; i < 80; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    await gesture.up();
    await tester.pump(const Duration(seconds: 1));

    expect(find.text('CANCEL'), findsOneWidget);
    await tester.tap(find.text('CANCEL'));
    await tester.pump();
    for (var i = 0; i < 14; i++) {
      await tester.pump(const Duration(milliseconds: 500));
    }

    expect(find.text('SOS sent'), findsNothing);
    expect(find.text('Hold to\nsend SOS'), findsOneWidget);
  });
}
