import 'package:flutter_test/flutter_test.dart';
import 'package:fyc_connect/core/services/update_service.dart';

/// The release pipeline that locked the club out of its own app.
///
/// Every build shipped `mandatory: true`, so the app told every member "This
/// update is required to continue" and offered one button: Play Store. Play
/// review lags CI by hours or days, so the page it opened had no Update on it.
/// A required update that cannot be obtained is a locked door with the key on
/// the other side.
UpdateInfo _info({
  String installed = '1.0.270',
  String minSupported = '0.0.0',
  bool fromPlay = true,
  bool playHasIt = false,
  bool mandatory = false,
}) =>
    UpdateInfo(
      latestVersionCode: 277,
      latestVersionName: '1.0.277',
      apkUrl: 'https://example.test/app.apk',
      mandatory: mandatory,
      notes: '',
      minSupportedVersionName: minSupported,
      installedVersionName: installed,
      installedFromPlay: fromPlay,
      playHasIt: playHasIt,
    );

void main() {
  group('what actually blocks a member', () {
    test('a newer version existing is an invitation, not a wall', () {
      expect(_info().blocking, isFalse,
          reason: 'v1.0.277 exists and v1.0.270 is installed — so what');
    });

    test('the server calling every build mandatory no longer blocks anybody',
        () {
      expect(_info(mandatory: true).blocking, isFalse,
          reason: 'this flag shipped true on all 277 builds');
    });

    test('a Play install is never told to fetch what Play does not have', () {
      final stranded = _info(
          installed: '1.0.270', minSupported: '1.0.277',
          fromPlay: true, playHasIt: false);
      expect(stranded.blocking, isFalse,
          reason: 'this exact case is what locked the club out');
    });

    test('below the floor, once Play actually has it, does block', () {
      final real = _info(
          installed: '1.0.270', minSupported: '1.0.277',
          fromPlay: true, playHasIt: true);
      expect(real.blocking, isTrue,
          reason: 'a breaking change is worth stopping for — when it is gettable');
    });

    test('a sideloaded build below the floor blocks, because the APK is there',
        () {
      final sideloaded = _info(
          installed: '1.0.270', minSupported: '1.0.277', fromPlay: false);
      expect(sideloaded.blocking, isTrue);
    });

    test('exactly at the floor is supported, not below it', () {
      expect(_info(installed: '1.0.277', minSupported: '1.0.277',
              fromPlay: false).blocking,
          isFalse, reason: 'the floor is a minimum, not an exclusion');
    });

    test('an unknown installed version never blocks', () {
      expect(_info(installed: '', minSupported: '9.9.9').blocking, isFalse,
          reason: 'not knowing is not grounds for locking somebody out');
    });
  });

  group('version comparison', () {
    test('orders builds the way humans read them', () {
      expect(UpdateService.compareVersions('1.0.277', '1.0.270'),
          greaterThan(0));
      expect(UpdateService.compareVersions('1.0.9', '1.0.10'), lessThan(0));
      expect(UpdateService.compareVersions('1.0.277', '1.0.277'), 0);
    });

    test('a malformed version is not a crash', () {
      expect(() => UpdateService.compareVersions('', 'x.y.z'), returnsNormally);
    });
  });
}
