import 'dart:async';
import 'dart:math' show sqrt;

import 'package:flutter/foundation.dart' show VoidCallback;
import 'package:sensors_plus/sensors_plus.dart';

/// Detects a deliberate "shake the phone" gesture from the accelerometer —
/// a fast, no-look way to open the Safety Center in an emergency (opens the
/// sheet for the user to confirm/send, it never fires an alert by itself).
///
/// Requires several sharp acceleration spikes in quick succession, not just
/// one jolt, so picking the phone up, walking, or a single bump don't
/// false-trigger it. Uses userAccelerometerEvents (gravity already removed)
/// so holding the phone at an angle doesn't bias the magnitude reading.
class ShakeDetector {
  static const _threshold = 18.0; // m/s^2 of device-caused acceleration
  static const _requiredSpikes = 3;
  static const _spikeWindow = Duration(milliseconds: 1200);
  static const _cooldown = Duration(seconds: 4);

  final VoidCallback onShake;
  ShakeDetector({required this.onShake});

  StreamSubscription<UserAccelerometerEvent>? _sub;
  final List<DateTime> _spikes = [];
  DateTime? _lastTrigger;

  void start() {
    if (_sub != null) return;
    _sub = userAccelerometerEventStream().listen(_onEvent, onError: (_) {});
  }

  void stop() {
    _sub?.cancel();
    _sub = null;
    _spikes.clear();
  }

  void _onEvent(UserAccelerometerEvent e) {
    final magnitude = sqrt(e.x * e.x + e.y * e.y + e.z * e.z);
    if (magnitude < _threshold) return;

    final now = DateTime.now();
    if (_lastTrigger != null && now.difference(_lastTrigger!) < _cooldown) return;

    _spikes.removeWhere((t) => now.difference(t) > _spikeWindow);
    _spikes.add(now);
    if (_spikes.length >= _requiredSpikes) {
      _spikes.clear();
      _lastTrigger = now;
      onShake();
    }
  }
}
