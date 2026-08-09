import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fyc_connect/features/safety/presentation/widgets/hold_ring.dart';

/// The hold is the safety catch. If it cannot complete, the SOS cannot be
/// sent — which is the worst possible way for a gesture to fail.
void main() {
  Future<void> pumpRing(WidgetTester tester, VoidCallback onComplete) =>
      tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Center(
            child: HoldRing(
              label: 'Hold to send',
              hint: 'Hold for 3 seconds',
              onComplete: onComplete,
              duration: const Duration(seconds: 3),
            ),
          ),
        ),
      ));

  testWidgets('holding for the full duration sends', (tester) async {
    var fired = 0;
    await pumpRing(tester, () => fired++);

    final gesture = await tester.startGesture(
        tester.getCenter(find.byType(HoldRing)));
    // Past the long-press timeout, which is where this used to die: declaring
    // `onLongPressEnd` put a LongPressGestureRecognizer in the arena, it
    // claimed victory at 500ms, the tap recognizer was rejected, and the
    // resulting onTapCancel reversed the fill. The ring could never finish.
    await tester.pump(const Duration(milliseconds: 600));
    expect(fired, 0, reason: 'not yet — three seconds have not passed');

    // Pumped in frames rather than one long jump. A controller that crosses
    // its end mid-frame reports `completed` on the next tick, so a single
    // pump straight to the duration lands a frame early — and a device, which
    // produces a frame every 16 ms, never sees that.
    await _pumpFrames(tester, const Duration(seconds: 3));
    await gesture.up();
    await tester.pumpAndSettle();

    expect(fired, 1);
  });

  testWidgets('letting go early sends nothing', (tester) async {
    var fired = 0;
    await pumpRing(tester, () => fired++);

    final gesture = await tester.startGesture(
        tester.getCenter(find.byType(HoldRing)));
    await tester.pump(const Duration(milliseconds: 900));
    await gesture.up();
    await tester.pumpAndSettle();

    expect(fired, 0, reason: 'a released hold is a cancelled hold');
  });

  testWidgets('dragging off the ring cancels it', (tester) async {
    // A thumb that slides away is somebody changing their mind, and on this
    // screen that has to be respected.
    var fired = 0;
    await pumpRing(tester, () => fired++);

    final gesture = await tester.startGesture(
        tester.getCenter(find.byType(HoldRing)));
    await tester.pump(const Duration(milliseconds: 400));
    await gesture.moveBy(const Offset(400, 0));
    await _pumpFrames(tester, const Duration(seconds: 3));
    await gesture.up();
    await tester.pumpAndSettle();

    expect(fired, 0);
  });

  testWidgets('a second hold works after the first completes', (tester) async {
    var fired = 0;
    await pumpRing(tester, () => fired++);

    for (var i = 0; i < 2; i++) {
      final gesture = await tester.startGesture(
          tester.getCenter(find.byType(HoldRing)));
      await _pumpFrames(tester, const Duration(seconds: 3));
      await gesture.up();
      await tester.pumpAndSettle();
    }

    expect(fired, 2);
  });
}

/// Pump real frames for [total], the way a device would.
Future<void> _pumpFrames(WidgetTester tester, Duration total) async {
  const frame = Duration(milliseconds: 50);
  for (var elapsed = Duration.zero;
      elapsed < total + frame * 4;
      elapsed += frame) {
    await tester.pump(frame);
  }
}
