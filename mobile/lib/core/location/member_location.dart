import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:geolocator/geolocator.dart';

import '../constants/api_constants.dart';
import '../network/api_client.dart';
import '../../service_locator.dart';
import 'location_disclosure.dart';

/// The one place the app asks the phone where it is.
///
/// Before this, five screens each rolled their own version of the same eight
/// lines — and each one called `requestPermission` cold, so whichever screen a
/// member happened to open first got to spend the single, permanent chance to
/// ask. Routing every caller through here means the explanation always comes
/// first, and it comes once.
///
/// Two kinds of position, deliberately separated, because they answer different
/// questions and cost different amounts:
///
/// * [forRanking] — "who is near me, roughly?" A cached fix from another app is
///   a perfectly good answer, so this never wakes the GPS. Free, instant, and
///   accurate to well inside the kilometre that a blood search works in.
/// * [precise] — "where is home?" This one is stored and reused for months, so
///   a stale cached fix would be wrong for a long time. Worth a real fix and the
///   few seconds it takes.
class MemberLocation {
  MemberLocation._();

  /// How old a cached fix may be before it stops being a fair answer to "where
  /// are you now". Half a day of not moving is common; half a day of moving and
  /// being ranked from where you started is not something to publish.
  static const _staleAfter = Duration(hours: 12);

  /// A fixed position for development, as "lat,lng".
  ///
  /// The desktop embedder used by the screenshot harness has no location
  /// provider, so without this every distance-aware screen photographs itself in
  /// its no-location state and the one thing you wanted to review is invisible.
  /// Same shape and same guard as `DEBUG_TOKEN` in LocalStorage: debug builds
  /// only, and absent unless someone passes `--dart-define` on purpose.
  static const _debugLatLng = String.fromEnvironment('DEBUG_LATLNG');

  static Position? get _debugPosition {
    if (!kDebugMode || _debugLatLng.isEmpty) return null;
    final parts = _debugLatLng.split(',');
    if (parts.length != 2) return null;
    final lat = double.tryParse(parts[0].trim());
    final lng = double.tryParse(parts[1].trim());
    if (lat == null || lng == null) return null;
    return Position(
      latitude: lat,
      longitude: lng,
      timestamp: DateTime.now(),
      accuracy: 30,
      altitude: 0,
      altitudeAccuracy: 0,
      heading: 0,
      headingAccuracy: 0,
      speed: 0,
      speedAccuracy: 0,
    );
  }

  /// A good-enough position for distance ranking, or null.
  ///
  /// Null is an ordinary outcome, not a failure: location off, permission
  /// declined, no fix on record. Callers rank by whatever else they have.
  static Future<Position?> forRanking(BuildContext context) async {
    if (_debugPosition != null) return _debugPosition;
    // Ask the phone before asking the member. If location is switched off at
    // the system level, agreeing to our sheet would achieve nothing — and we
    // would have spent the ask.
    if (!await Geolocator.isLocationServiceEnabled()) return null;
    if (!context.mounted) return null;
    if (!await LocationDisclosure.ensure(context)) return null;

    try {
      final cached = await Geolocator.getLastKnownPosition();
      if (cached != null && !_isStale(cached)) return cached;
      try {
        return await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.medium,
            timeLimit: Duration(seconds: 8),
          ),
        );
      } catch (_) {
        // A stale fix still beats nothing for "who is nearest" — it is only
        // unfit for being written down as a home area.
        return cached;
      }
    } catch (_) {
      return null;
    }
  }

  /// A fresh, accurate position, or null — for pinning a home area.
  static Future<Position?> precise(BuildContext context) async {
    if (_debugPosition != null) return _debugPosition;
    if (!await Geolocator.isLocationServiceEnabled()) return null;
    if (!context.mounted) return null;
    if (!await LocationDisclosure.ensure(context)) return null;
    try {
      return await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 8),
        ),
      );
    } catch (_) {
      return null;
    }
  }

  /// A position only if we may already take one — never asks, never prompts.
  ///
  /// For moments where an explanation would be an interruption: the member is
  /// mid-task, has tapped submit, and a bottom sheet about location is not what
  /// they meant. They will be asked properly somewhere they are browsing.
  static Future<Position?> ifAlreadyAllowed() async {
    if (_debugPosition != null) return _debugPosition;
    final perm = await Geolocator.checkPermission();
    if (perm != LocationPermission.always &&
        perm != LocationPermission.whileInUse) {
      return null;
    }
    if (!await Geolocator.isLocationServiceEnabled()) return null;
    try {
      final cached = await Geolocator.getLastKnownPosition();
      if (cached != null && !_isStale(cached)) return cached;
      return await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: Duration(seconds: 8),
        ),
      );
    } catch (_) {
      return null;
    }
  }

  static bool _isStale(Position p) =>
      DateTime.now().toUtc().difference(p.timestamp.toUtc()) > _staleAfter;

  /// Tell the server where we last saw this member, best effort.
  ///
  /// This is the green half of the two-stage display: it writes `last_seen_*`
  /// and never touches the home area. The server drops it on the floor unless
  /// the member is a donor who has consented, so calling it is always safe.
  ///
  /// Failures are silent on purpose. Nothing the member asked for depends on
  /// this, so a dead network should cost them a snackbar they cannot act on.
  static Future<void> report(Position pos) async {
    try {
      await sl<ApiClient>().dio.patch(
        '${ApiConstants.bloodDonors}/me/location',
        data: {'lat': pos.latitude, 'lng': pos.longitude},
      );
    } catch (_) {
      // Opportunistic by definition — the next app open tries again.
    }
  }
}
