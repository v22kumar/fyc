import 'package:dio/dio.dart';
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
  final bool mandatory;
  final String notes;

  const UpdateInfo({
    required this.latestVersionCode,
    required this.latestVersionName,
    required this.apkUrl,
    required this.mandatory,
    required this.notes,
  });
}

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
          ? _compareVersions(latestName, currentName) > 0
          : latestCode > currentCode;
      if (!isNewer) return null; // already up to date

      return UpdateInfo(
        latestVersionCode: latestCode,
        latestVersionName: latestName,
        apkUrl: apkUrl,
        mandatory: data['mandatory'] as bool? ?? false,
        notes: (data['notes'] as String?) ?? '',
      );
    } catch (e) {
      if (kDebugMode) debugPrint('UpdateService.check failed: $e');
      return null;
    }
  }

  /// Compares dotted numeric versions ("1.0.81" vs "1.0.80").
  /// Returns >0 if [a] is newer than [b], 0 if equal, <0 if older.
  /// Non-numeric segments are treated as 0 so a malformed value never throws.
  static int _compareVersions(String a, String b) {
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
