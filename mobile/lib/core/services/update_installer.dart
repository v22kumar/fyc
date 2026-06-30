import 'dart:io';

import 'package:dio/dio.dart';
import 'package:open_filex/open_filex.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';

import '../constants/api_constants.dart';
import '../storage/local_storage.dart';
import '../../service_locator.dart';

/// Handles the in-app update lifecycle: download the APK into the app's own
/// private cache, launch the system installer, and — once the new build is
/// confirmed running and the backend is reachable — delete the leftover
/// installer so it never bloats low-storage devices.
class UpdateInstaller {
  static const _pendingKey = 'fyc_pending_update_code';
  static const _apkPrefix = 'fyc-connect-';

  /// Downloads [apkUrl] into the private cache and opens the installer.
  /// Reports progress in 0..1. Throws on failure so the UI can fall back to a
  /// plain browser download.
  static Future<void> downloadAndInstall(
    String apkUrl,
    int versionCode, {
    void Function(double progress)? onProgress,
  }) async {
    final dir = await getTemporaryDirectory();
    final path = '${dir.path}/$_apkPrefix$versionCode.apk';

    // Remember the target so cleanupAfterUpdate() can verify + purge next launch.
    await sl<LocalStorage>().saveString(_pendingKey, '$versionCode');

    // Plain Dio — no backend baseUrl / auth interceptors on a GitHub CDN URL.
    final dio = Dio();
    await dio.download(
      apkUrl,
      path,
      options: Options(
        followRedirects: true,
        receiveTimeout: const Duration(minutes: 5),
      ),
      onReceiveProgress: (received, total) {
        if (total > 0 && onProgress != null) onProgress(received / total);
      },
    );

    final result = await OpenFilex.open(path);
    if (result.type != ResultType.done) {
      throw Exception('installer-open-failed: ${result.message}');
    }
  }

  /// Best-effort cleanup, safe to call on every launch. Deletes cached APK(s)
  /// only when the freshly-installed build is actually running AND the backend
  /// is reachable — i.e. "the new version is working fine".
  static Future<void> cleanupAfterUpdate() async {
    try {
      final storage = sl<LocalStorage>();
      final pendingStr = storage.getString(_pendingKey);
      if (pendingStr == null || pendingStr.isEmpty) return;
      final pending = int.tryParse(pendingStr);
      if (pending == null) return;

      final info = await PackageInfo.fromPlatform();
      final current = int.tryParse(info.buildNumber) ?? 0;
      if (current < pending) return; // update not installed yet

      if (!await _backendHealthy()) return; // backend not confirmed fine

      await _deleteCachedApks();
      await storage.saveString(_pendingKey, '');
    } catch (_) {
      // Never let cleanup break startup.
    }
  }

  static Future<bool> _backendHealthy() async {
    try {
      final dio = Dio(BaseOptions(
        connectTimeout: const Duration(seconds: 5),
        receiveTimeout: const Duration(seconds: 5),
      ));
      final res = await dio.get('${ApiConstants.baseUrl}/api/health');
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  static Future<void> _deleteCachedApks() async {
    try {
      final dir = await getTemporaryDirectory();
      for (final entity in dir.listSync()) {
        if (entity is File &&
            entity.path.contains(_apkPrefix) &&
            entity.path.endsWith('.apk')) {
          try {
            await entity.delete();
          } catch (_) {/* ignore individual file errors */}
        }
      }
    } catch (_) {/* ignore */}
  }
}
