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
      final currentCode = int.tryParse(info.buildNumber) ?? 0;

      final res = await sl<ApiClient>()
          .dio
          .get(ApiConstants.appInfo)
          .timeout(const Duration(seconds: 8));
      final data = res.data;
      if (data is! Map) return null;

      final latestCode = (data['latest_version_code'] as num?)?.toInt() ?? 0;
      final apkUrl = (data['apk_url'] ?? data['download_url']) as String?;
      if (latestCode <= currentCode || apkUrl == null || apkUrl.isEmpty) {
        return null; // already up to date (or nothing to download)
      }

      return UpdateInfo(
        latestVersionCode: latestCode,
        latestVersionName: (data['latest_version_name'] as String?) ?? '',
        apkUrl: apkUrl,
        mandatory: data['mandatory'] as bool? ?? false,
        notes: (data['notes'] as String?) ?? '',
      );
    } catch (e) {
      if (kDebugMode) debugPrint('UpdateService.check failed: $e');
      return null;
    }
  }
}
