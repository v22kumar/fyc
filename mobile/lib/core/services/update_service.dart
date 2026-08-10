import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../constants/api_constants.dart';
import '../network/api_client.dart';
import '../../service_locator.dart';

/// Describes an available app update returned by GET /api/v1/app/info.
class UpdateInfo {
  final int latestVersionCode;
  final String latestVersionName;
  final String apkUrl;
  /// Whether the SERVER flagged this build as mandatory. Retained because the
  /// endpoint still sends it, but it is no longer what blocks anybody — see
  /// [blocking]. Every build used to ship this as true.
  final bool mandatory;

  /// The oldest version that can still run. Below it the app genuinely cannot
  /// work — a breaking API change, a security fix — and only then is anyone
  /// stopped.
  final String minSupportedVersionName;

  /// The version actually installed on this phone.
  final String installedVersionName;

  final String notes;

  /// Whether this copy of the app was installed by the Play Store.
  ///
  /// This decides which update is even *possible*, and getting it wrong bricks
  /// the app. A build delivered through Play is re-signed by Google (Play App
  /// Signing); the APK on the GitHub release is signed with the upload key.
  /// Android will not install one over the other — it refuses with "App not
  /// installed" — so offering a Play user the APK is offering them a download
  /// that cannot possibly succeed. They have to be sent to Play.
  final bool installedFromPlay;

  const UpdateInfo({
    required this.latestVersionCode,
    required this.latestVersionName,
    required this.apkUrl,
    required this.mandatory,
    required this.notes,
    this.minSupportedVersionName = '0.0.0',
    this.installedVersionName = '',
    this.installedFromPlay = false,
    this.playHasIt = false,
  });

  /// Whether this member must update before continuing.
  ///
  /// Three conditions, and all three have to hold. The old rule was one — the
  /// server said so — and every build said so.
  ///
  /// 1. **Below the floor.** Not merely "newer exists". A newer version is an
  ///    invitation; an unusable version is a wall, and only the second is
  ///    worth stopping somebody for.
  ///
  /// 2. **The update can actually be obtained.** This is the condition whose
  ///    absence locked the club out of its own app. Play review lags CI by
  ///    hours or days, so the app demanded a version the Play Store did not
  ///    have yet, and the only button led to a page with no Update on it.
  ///    Never block on something a member cannot get: if we are below the
  ///    floor but Play has not published it, the honest move is to let them
  ///    keep working.
  ///
  /// 3. Blocking is opt-in per release, not per build. See
  ///    MIN_SUPPORTED_VERSION in flutter-build.yml.
  bool get blocking {
    if (installedVersionName.isEmpty) return false;
    final belowFloor = UpdateService.compareVersions(
            minSupportedVersionName, installedVersionName) >
        0;
    if (!belowFloor) return false;
    // A Play install can only be updated once Play has the build. Until then a
    // block is a locked door with the key on the other side.
    if (installedFromPlay && !playHasIt) return false;
    return true;
  }

  /// Whether the newest build is actually downloadable from where this copy
  /// came from. For a sideloaded APK that is always true; for a Play install
  /// it is only true once Play has finished reviewing and publishing.
  final bool playHasIt;
}

/// The Play Store's own package name, which is what `installerStore` reports
/// for anything Play installed.
const _playStorePackage = 'com.android.vending';

/// Checks the backend for a newer Android build. Best-effort: any failure
/// (offline, parse error, missing fields) returns null so it never blocks the app.
class UpdateService {
  /// Returns an [UpdateInfo] when the backend's latest version code is greater
  /// than this build's, otherwise null.
  static Future<UpdateInfo?> check() async {
    try {
      final info = await PackageInfo.fromPlatform();
      // info.version is the display version ("1.0.<run>"); info.buildNumber is
      // the Android versionCode as a string.
      final currentName = info.version;
      final currentCode = int.tryParse(info.buildNumber) ?? 0;
      final fromPlay = info.installerStore == _playStorePackage;

      final res = await sl<ApiClient>()
          .dio
          .get(ApiConstants.appInfo)
          .timeout(const Duration(seconds: 8));
      final data = res.data;
      if (data is! Map) return null;

      final latestCode = (data['latest_version_code'] as num?)?.toInt() ?? 0;
      final latestName = (data['latest_version_name'] as String?) ?? '';
      final apkUrl = (data['apk_url'] ?? data['download_url']) as String?;
      if (apkUrl == null || apkUrl.isEmpty) return null;

      // Prefer comparing the semantic version_name ("1.0.81" > "1.0.80").
      // The raw versionCode is UNRELIABLE for split-per-abi APKs: Flutter's
      // --split-per-abi offsets each ABI's versionCode (arm64 +2000, arm32
      // +1000, x86_64 +4000), so the installed code is larger than the plain
      // build-number published in version.json and a code comparison would
      // report "up to date" forever. version_name carries no ABI offset and
      // increases every build, so it's the correct signal. Fall back to the
      // code only when a name is missing/unparseable.
      final bool isNewer = (latestName.isNotEmpty && currentName.isNotEmpty)
          ? compareVersions(latestName, currentName) > 0
          : latestCode > currentCode;
      if (!isNewer) return null; // already up to date

      return UpdateInfo(
        latestVersionCode: latestCode,
        latestVersionName: latestName,
        apkUrl: apkUrl,
        mandatory: data['mandatory'] as bool? ?? false,
        minSupportedVersionName:
            (data['min_supported_version_name'] as String?) ?? '0.0.0',
        installedVersionName: currentName,
        notes: (data['notes'] as String?) ?? '',
        installedFromPlay: fromPlay,
        // The server publishes the moment CI finishes; Play publishes when
        // review finishes. We cannot see Play's state from here, so we assume
        // it does NOT have the build yet. That errs towards letting members
        // keep working, which is the right way to be wrong.
        playHasIt: data['play_has_it'] as bool? ?? false,
      );
    } catch (e) {
      if (kDebugMode) debugPrint('UpdateService.check failed: $e');
      return null;
    }
  }

  /// Compares dotted numeric versions ("1.0.81" vs "1.0.80").
  /// Returns >0 if [a] is newer than [b], 0 if equal, <0 if older.
  /// Non-numeric segments are treated as 0 so a malformed value never throws.
  static int compareVersions(String a, String b) {
    final pa = a.split('.').map((e) => int.tryParse(e.trim()) ?? 0).toList();
    final pb = b.split('.').map((e) => int.tryParse(e.trim()) ?? 0).toList();
    final n = pa.length > pb.length ? pa.length : pb.length;
    for (var i = 0; i < n; i++) {
      final x = i < pa.length ? pa[i] : 0;
      final y = i < pb.length ? pb[i] : 0;
      if (x != y) return x - y;
    }
    return 0;
  }
}

/// The app's own package name, for the Play Store deep link.
///
/// Kept next to the updater rather than read from `PackageInfo` because it is
/// also the answer to "where would I even find this app", and that question
/// has to be answerable when the update has failed.
const kAndroidPackage = 'com.fycconnect.app';
