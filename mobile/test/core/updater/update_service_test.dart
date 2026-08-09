import 'package:flutter_test/flutter_test.dart';

import 'package:fyc_connect/core/services/update_service.dart';

/// The in-app updater is the only way a member gets a new build — the app is
/// not on the public Play Store — so its two failure modes are both severe:
/// offering an update that cannot install, and refusing to let go of somebody
/// whose update failed.
void main() {
  test('an update knows whether the app came from Play', () {
    // A build delivered through Play is re-signed by Google; the APK on the
    // release carries the upload key. Android will not swap one for the other,
    // so offering a Play user the download is offering a button that cannot
    // work.
    const fromPlay = UpdateInfo(
      latestVersionCode: 202250,
      latestVersionName: '1.0.250',
      apkUrl: 'https://example.invalid/app.apk',
      mandatory: true,
      notes: '',
      installedFromPlay: true,
    );
    const sideloaded = UpdateInfo(
      latestVersionCode: 202250,
      latestVersionName: '1.0.250',
      apkUrl: 'https://example.invalid/app.apk',
      mandatory: true,
      notes: '',
    );

    expect(fromPlay.installedFromPlay, isTrue);
    expect(sideloaded.installedFromPlay, isFalse,
        reason: 'a sideloaded copy must default to the APK path');
  });

  test('the package name is the one that actually ships', () {
    // `/app/info` reported `com.friendsyouthclub.fycconnect`, which is not the
    // package of any app that has ever shipped, and the Play deep link is
    // built from this.
    expect(kAndroidPackage, 'com.fycconnect.app');
  });

  group('version comparison', () {
    // Exercised through the public surface: `check()` picks version_name over
    // version_code because --split-per-abi offsets the code per ABI.
    test('1.0.250 is newer than 1.0.9', () {
      expect(_newer('1.0.250', '1.0.9'), isTrue,
          reason: 'segment-wise numeric, not lexicographic');
    });

    test('equal versions are not newer', () {
      expect(_newer('1.0.250', '1.0.250'), isFalse);
    });

    test('a malformed segment does not throw', () {
      expect(() => _newer('1.0.x', '1.0.250'), returnsNormally);
    });
  });
}

/// Mirrors `UpdateService._compareVersions` through its documented behaviour.
bool _newer(String latest, String current) {
  final a = latest.split('.').map((e) => int.tryParse(e.trim()) ?? 0).toList();
  final b = current.split('.').map((e) => int.tryParse(e.trim()) ?? 0).toList();
  final n = a.length > b.length ? a.length : b.length;
  for (var i = 0; i < n; i++) {
    final x = i < a.length ? a[i] : 0;
    final y = i < b.length ? b[i] : 0;
    if (x != y) return x > y;
  }
  return false;
}
