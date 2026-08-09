import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Press and hold to send.
///
/// The safety catch, and the reason the rest of the feature can afford a
/// hair-trigger. Apple, Android and Tamil Nadu's own Kavalan SOS all put a
/// deliberate gesture in front of the alert — a hold, or a five-second
/// countdown, always cancellable. The version this replaces had neither: every
/// button fired on the first tap, while shake-to-trigger was on by default.
/// A hair-trigger without a safety catch is exactly backwards.
///
/// Haptics fire on every quarter of the fill, so the gesture is legible with
/// the phone at your side and the screen unread.
class HoldRing extends StatefulWidget {
  const HoldRing({
    super.key,
    required this.onComplete,
    required this.label,
    required this.hint,
    this.duration = const Duration(seconds: 3),
    this.diameter = 216,
  });

  final VoidCallback onComplete;

  /// What the ring is for, inside it. Two words at most.
  final String label;

  /// What to do, under it.
  final String hint;

  final Duration duration;
  final double diameter;

  @override
  State<HoldRing> createState() => _HoldRingState();
}

class _HoldRingState extends State<HoldRing>
    with SingleTickerProviderStateMixin {
  late final AnimationController _fill = AnimationController(
    vsync: this,
    duration: widget.duration,
  )..addStatusListener(_onStatus);

  int _lastQuarter = 0;

  @override
  void initState() {
    super.initState();
    _fill.addListener(_pulse);
  }

  @override
  void dispose() {
    _fill.dispose();
    super.dispose();
  }

  void _pulse() {
    final quarter = (_fill.value * 4).floor();
    if (quarter != _lastQuarter && quarter > 0) {
      _lastQuarter = quarter;
      HapticFeedback.mediumImpact();
    }
  }

  void _onStatus(AnimationStatus status) {
    if (status != AnimationStatus.completed) return;
    HapticFeedback.heavyImpact();
    widget.onComplete();
    _fill.value = 0;
    _lastQuarter = 0;
  }

  void _down(PointerDownEvent _) {
    _lastQuarter = 0;
    HapticFeedback.selectionClick();
    _fill.forward();
  }

  void _up([Object? _]) {
    // Reversed rather than reset: letting go halfway should look like letting
    // go, not like the app losing the gesture.
    if (_fill.status != AnimationStatus.completed) _fill.reverse();
  }

  /// A thumb that slides off the ring is somebody changing their mind.
  ///
  /// With a raw [Listener] there is no recognizer to notice this, so the check
  /// is here: outside the disc, plus a little slack for a finger that rolls.
  void _move(PointerMoveEvent event) {
    if (_fill.status != AnimationStatus.forward) return;
    final centre = Offset(widget.diameter / 2, widget.diameter / 2);
    if ((event.localPosition - centre).distance > widget.diameter / 2 + 24) {
      _up();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: '${widget.label}. ${widget.hint}',
      // A raw [Listener], not a GestureDetector — and this is the whole reason
      // the hold works at all.
      //
      // The first version used `onTapDown` / `onTapUp` / `onTapCancel` with an
      // `onLongPressEnd` alongside. Declaring the long-press handler puts a
      // LongPressGestureRecognizer into the gesture arena next to the tap
      // recognizer; at `kLongPressTimeout` (500 ms) the long-press claims
      // victory, the tap recognizer is rejected, and the rejection arrives as
      // `onTapCancel`. Which reversed the fill. So the ring died at half a
      // second, every time, and an SOS could never be sent by holding it.
      //
      // Listener takes pointer events directly and never enters the arena, so
      // nothing can take the gesture away mid-hold — which is the correct
      // guarantee for a button somebody is pressing because they are in
      // trouble.
      child: Listener(
        behavior: HitTestBehavior.opaque,
        onPointerDown: _down,
        onPointerMove: _move,
        onPointerUp: _up,
        onPointerCancel: _up,
        child: SizedBox(
          width: widget.diameter,
          height: widget.diameter,
          child: AnimatedBuilder(
            animation: _fill,
            builder: (context, _) => CustomPaint(
              painter: _RingPainter(_fill.value),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      widget.label,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                        height: 1.1,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 28),
                      child: Text(
                        widget.hint,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.78),
                          fontSize: 13,
                          height: 1.25,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  const _RingPainter(this.progress);

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final centre = size.center(Offset.zero);
    final radius = size.width / 2;
    const stroke = 10.0;

    // The disc itself grows very slightly as it fills, so the gesture reads as
    // pressure rather than as a progress bar wrapped round a button.
    final discRadius = radius - stroke - 6 + progress * 4;

    canvas.drawCircle(
      centre,
      discRadius,
      Paint()..color = const Color(0xFFDC2626),
    );
    canvas.drawCircle(
      centre,
      discRadius,
      Paint()
        ..color = const Color(0xFFDC2626).withValues(alpha: 0.35)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, 12 + progress * 18),
    );

    canvas.drawCircle(
      centre,
      radius - stroke / 2,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..color = Colors.white.withValues(alpha: 0.16),
    );

    if (progress <= 0) return;
    canvas.drawArc(
      Rect.fromCircle(center: centre, radius: radius - stroke / 2),
      -math.pi / 2,
      2 * math.pi * progress,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..strokeCap = StrokeCap.round
        ..color = Colors.white,
    );
  }

  @override
  bool shouldRepaint(_RingPainter old) => old.progress != progress;
}
