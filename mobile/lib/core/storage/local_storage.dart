import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../constants/app_constants.dart';
import '../constants/api_constants.dart';

class LocalStorage {
  final SharedPreferences _prefs;

  /// Encrypted store (Android Keystore / iOS Keychain) for the auth + refresh
  /// tokens. Previously these sat in plaintext SharedPreferences, where a rooted
  /// device or an ADB backup could lift a 60-day refresh token and silently take
  /// over the account.
  static const FlutterSecureStorage _secure = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  LocalStorage(this._prefs);

  /// A token supplied at build time, for harnesses that have no keyring.
  ///
  /// The screenshot harness and the integration tests run on the Linux desktop
  /// embedder, where flutter_secure_storage has no keyring to talk to: writes
  /// are swallowed and reads come back null. Every authenticated screen then
  /// renders its signed-out state, which is how a whole design review came to
  /// be conducted against screens that were never logged in.
  ///
  /// Double-gated. `kDebugMode` means a release build ignores this even if the
  /// define is somehow present, so it cannot become a way to ship a hardcoded
  /// credential; and it only ever *reads* — nothing is written anywhere new.
  static const String _debugToken = String.fromEnvironment('DEBUG_TOKEN');

  static bool get _useDebugToken => kDebugMode && _debugToken.isNotEmpty;

  // Every secure-storage call is guarded: in a `flutter test` (no platform
  // channels) the plugin throws, and a token lookup must degrade to "no token"
  // rather than crash the caller.
  Future<String?> _secureRead(String key) async {
    try {
      return await _secure.read(key: key);
    } catch (_) {
      return null;
    }
  }

  Future<void> _secureWrite(String key, String? value) async {
    try {
      if (value == null) {
        await _secure.delete(key: key);
      } else {
        await _secure.write(key: key, value: value);
      }
    } catch (_) {/* best-effort: on failure the user simply re-authenticates */}
  }

  // Auth token
  Future<void> saveToken(String token) async {
    await _secureWrite(AppConstants.tokenKey, token);
    await _prefs.setBool(AppConstants.hasSessionKey, true);
  }

  Future<String?> getToken() async {
    if (_useDebugToken) return _debugToken;
    return _secureRead(AppConstants.tokenKey)
        .then(_migrateIfNeeded(AppConstants.tokenKey));
  }

  // Long-lived refresh token — used to silently mint new access tokens so the
  // user stays signed in until they explicitly log out.
  Future<void> saveRefreshToken(String token) async =>
      _secureWrite(AppConstants.refreshTokenKey, token);

  Future<String?> getRefreshToken() async => _secureRead(AppConstants.refreshTokenKey)
      .then(_migrateIfNeeded(AppConstants.refreshTokenKey));

  Future<void> clearRefreshToken() async =>
      _secureWrite(AppConstants.refreshTokenKey, null);

  /// Clears BOTH tokens — this is the session-over / logout path.
  Future<void> clearToken() async {
    await _secureWrite(AppConstants.tokenKey, null);
    await _secureWrite(AppConstants.refreshTokenKey, null);
    // Drop any legacy plaintext copies too, and the session marker.
    await _prefs.remove(AppConstants.tokenKey);
    await _prefs.remove(AppConstants.refreshTokenKey);
    await _prefs.remove(AppConstants.hasSessionKey);
  }

  /// One-time migration: if the token still lives in the old plaintext prefs
  /// (upgrade from a prior build), move it into secure storage on first read and
  /// scrub the plaintext copy.
  Future<String?> Function(String?) _migrateIfNeeded(String key) => (secureValue) async {
        if (secureValue != null) return secureValue;
        final legacy = _prefs.getString(key);
        if (legacy != null) {
          await _secureWrite(key, legacy);
          await _prefs.remove(key);
          if (key == AppConstants.tokenKey) {
            await _prefs.setBool(AppConstants.hasSessionKey, true);
          }
          return legacy;
        }
        return null;
      };

  // Language preference
  Future<void> saveLang(String lang) async =>
      _prefs.setString(AppConstants.langKey, lang);

  String getLang() =>
      _prefs.getString(AppConstants.langKey) ?? AppConstants.defaultLang;

  // Theme preference: 'light' | 'dark' | 'system'. Defaults to 'system' —
  // the app follows the OS setting automatically; there is no manual
  // light/dark toggle in the UI.
  Future<void> saveTheme(String mode) async =>
      _prefs.setString(AppConstants.themeKey, mode);

  String getTheme() =>
      _prefs.getString(AppConstants.themeKey) ?? 'system';

  // Generic getString / saveString
  String? getString(String key) => _prefs.getString(key);

  Future<void> saveString(String key, String value) async =>
      _prefs.setString(key, value);

  // Draft form data
  Future<void> saveDraft(String key, String value) async =>
      _prefs.setString(key, value);
      
  String? getDraft(String key) => _prefs.getString(key);
  
  Future<void> clearDraft(String key) async => _prefs.remove(key);

  // Organization ID
  Future<void> saveOrgId(String orgId) async =>
      _prefs.setString(AppConstants.orgIdKey, orgId);

  String? getOrgId() =>
      _prefs.getString(AppConstants.orgIdKey) ?? ApiConstants.defaultOrgId;

  // Sync check backed by a non-sensitive flag (the real token is in secure
  // storage). The legacy-plaintext fallback keeps users signed in across the
  // upgrade, until their next getToken() migrates and sets the flag.
  bool get isLoggedIn =>
      (_prefs.getBool(AppConstants.hasSessionKey) ?? false) ||
      _prefs.getString(AppConstants.tokenKey) != null;

  bool get isFirstLaunch =>
      _prefs.getString(AppConstants.langKey) == null;
}
