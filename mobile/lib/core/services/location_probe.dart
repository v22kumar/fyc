import 'package:geolocator/geolocator.dart';

/// Where the phone thinks it is, with how sure it is and when.
///
/// The previous helper returned a bare `Position`, and the accuracy went in
/// the bin. That is the wrong thing to throw away: a responder deciding
/// whether to set off needs to know whether the pin is twelve metres out or
/// two kilometres, and a member reading their own screen needs to know whether
/// the place name under it means anything.
class LocationFix {
  const LocationFix({
    required this.latitude,
    required this.longitude,
    required this.accuracyM,
    required this.at,
    this.placeName,
  });

  final double latitude;
  final double longitude;
  final double accuracyM;
  final DateTime at;
  final String? placeName;

  /// Good enough to send somebody to. Anything worse is still worth sending —
  /// it is just worth labelling.
  bool get isSharp => accuracyM <= 100;
}

/// Best-effort location. Never throws, never blocks past its own cap.
class LocationProbe {
  const LocationProbe({this.timeout = const Duration(seconds: 6)});

  final Duration timeout;

  /// Returns null when location is off, denied, or slow.
  ///
  /// Null is a normal answer on this path, not an error: the SOS still goes,
  /// the alert says the location is unknown, and the ring widens because of
  /// it. Blocking a person's emergency on a GPS fix would be the worst trade
  /// this app could make.
  Future<LocationFix?> current() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) return null;
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return null;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: timeout,
        ),
      );
      return LocationFix(
        latitude: position.latitude,
        longitude: position.longitude,
        accuracyM: position.accuracy,
        at: DateTime.now(),
      );
    } catch (_) {
      // A timed-out high-accuracy fix is common indoors. Fall back to whatever
      // the phone already had — a stale fix with its age visible beats
      // nothing at all.
      try {
        final last = await Geolocator.getLastKnownPosition();
        if (last == null) return null;
        return LocationFix(
          latitude: last.latitude,
          longitude: last.longitude,
          accuracyM: last.accuracy,
          at: last.timestamp,
        );
      } catch (_) {
        return null;
      }
    }
  }
}
