import 'package:flutter_test/flutter_test.dart';
// GeolocatorPlatform comes through this export — no second dependency needed.
import 'package:geolocator/geolocator.dart';

import 'package:fyc_connect/core/location/member_location.dart';

/// A browser has no cached fix. `geolocator_web` answers
/// `getLastKnownPosition` by throwing, and that is not an error condition —
/// it is a platform without that feature, and the app should go and ask
/// instead.
///
/// It used to give up: one try block wrapped the cache lookup *and* the live
/// lookup, so the throw jumped past the fallback and every caller on the web
/// got null. The blood hub then ranked nobody and rendered a list with no
/// distances — which reads as "there is nobody near you", not as "this browser
/// can't do that". These tests pin the fallback so the web can't lose it again.
class _NoCachePlatform extends GeolocatorPlatform {
  _NoCachePlatform(this.live);

  /// What a live lookup would return. Null means "that fails too".
  final Position? live;
  int liveCalls = 0;

  @override
  Future<bool> isLocationServiceEnabled() async => true;

  @override
  Future<LocationPermission> checkPermission() async =>
      LocationPermission.whileInUse;

  @override
  Future<Position?> getLastKnownPosition({bool forceLocationManager = false}) =>
      throw UnsupportedError('getLastKnownPosition is not supported on the web');

  @override
  Future<Position> getCurrentPosition({LocationSettings? locationSettings}) {
    liveCalls++;
    if (live == null) throw const LocationServiceDisabledException();
    return Future.value(live);
  }
}

Position _at(double lat, double lng) => Position(
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

void main() {
  test('no cached fix falls through to asking, rather than returning null',
      () async {
    final platform = _NoCachePlatform(_at(8.1780, 77.4340));
    GeolocatorPlatform.instance = platform;

    final pos = await MemberLocation.ifAlreadyAllowed();

    expect(platform.liveCalls, 1,
        reason: 'the unsupported cache must not skip the live lookup');
    expect(pos?.latitude, closeTo(8.1780, 0.0001));
  });

  test('null stays an ordinary outcome when the live lookup also fails',
      () async {
    GeolocatorPlatform.instance = _NoCachePlatform(null);
    expect(await MemberLocation.ifAlreadyAllowed(), isNull);
  });
}
