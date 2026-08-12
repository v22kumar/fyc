import 'package:flutter/services.dart';

/// What this install actually is, asked of the install rather than inferred.
///
/// Google Sign-In fails with DEVELOPER_ERROR (code 10) when it does not
/// recognise the pair (package name, signing certificate). Diagnosing that from
/// outside means trusting a chain: that the APK on this phone is the one CI
/// published, signed with the key the workflow printed, matching the
/// fingerprint typed into the Firebase console. Every link in that chain looked
/// correct while sign-in kept failing — so one of them was not, and reading
/// them again was never going to say which.
///
/// This asks the phone. The fingerprint it returns is the one Google is
/// actually shown.
class AppIdentity {
  static const _channel = MethodChannel('fyc/app_identity');

  /// Colon-separated uppercase SHA-1, or null off Android.
  static Future<String?> signingSha1() async {
    try {
      return await _channel.invokeMethod<String>('signingSha1');
    } catch (_) {
      return null;
    }
  }

  static Future<String?> packageName() async {
    try {
      return await _channel.invokeMethod<String>('packageName');
    } catch (_) {
      return null;
    }
  }
}
