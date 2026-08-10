import 'package:flutter/foundation.dart';
import 'package:in_app_update/in_app_update.dart';

/// Updates the way Android actually does them, for the copies that came from
/// Play.
///
/// What this replaces: the app compared version strings itself, then put up a
/// sheet saying "This update is required to continue" with one button leading
/// to the Play Store. Every build shipped that flag, and Play review lags CI by
/// hours or days — so the app demanded a version Play did not have yet, and the
/// button led to a page with no Update on it. The club was locked out of its
/// own app by its own release pipeline.
///
/// Google's In-App Updates API is the answer to this, and it is answering a
/// question we cannot: it asks Play whether an update is *actually available to
/// this device right now*, rather than inferring it from a version number the
/// server published the moment CI finished.
///
/// Two flows, and the distinction is the whole point:
///
/// * **Flexible** — the default. Play downloads in the background while the
///   member keeps using the app; nothing is blocked, nothing is asked. When it
///   is ready we can apply it on the next natural restart.
/// * **Immediate** — Play's own blocking, full-screen flow. Reserved for a
///   build below the support floor, where the app genuinely cannot work.
///
/// Every call is best-effort. On a sideloaded APK, on a device without Play
/// Services, or in a test, the platform channel simply is not there — and an
/// updater that crashes the app it was meant to improve is worse than no
/// updater. All of it is swallowed.
class PlayUpdate {
  const PlayUpdate._();

  /// Whether Play has an update ready for *this* device — the question the
  /// version-number comparison could never answer.
  static Future<bool> isAvailable() async {
    try {
      final info = await InAppUpdate.checkForUpdate();
      return info.updateAvailability == UpdateAvailability.updateAvailable;
    } catch (e) {
      if (kDebugMode) debugPrint('PlayUpdate.isAvailable: $e');
      return false;
    }
  }

  /// Start a background download. Returns true if Play accepted it.
  ///
  /// The member is not interrupted and not asked to wait: this is what "update
  /// in the background" means on Android, and it is what Play's own auto-update
  /// does when it gets the chance.
  static Future<bool> startBackgroundDownload() async {
    try {
      if (!await isAvailable()) return false;
      await InAppUpdate.startFlexibleUpdate();
      return true;
    } catch (e) {
      if (kDebugMode) debugPrint('PlayUpdate.startBackgroundDownload: $e');
      return false;
    }
  }

  /// Install a download that has already finished, quietly.
  static Future<void> completeIfDownloaded() async {
    try {
      await InAppUpdate.completeFlexibleUpdate();
    } catch (e) {
      if (kDebugMode) debugPrint('PlayUpdate.completeIfDownloaded: $e');
    }
  }

  /// Play's own blocking update flow.
  ///
  /// Only for a build below the support floor. Unlike our sheet, this one
  /// cannot deadlock: Play shows it only when Play has the update, so the
  /// member is never told to fetch something that does not exist yet.
  static Future<bool> runImmediate() async {
    try {
      if (!await isAvailable()) return false;
      await InAppUpdate.performImmediateUpdate();
      return true;
    } catch (e) {
      if (kDebugMode) debugPrint('PlayUpdate.runImmediate: $e');
      return false;
    }
  }
}
