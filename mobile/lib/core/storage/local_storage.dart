import 'package:shared_preferences/shared_preferences.dart';
import '../constants/app_constants.dart';
import '../constants/api_constants.dart';

class LocalStorage {
  final SharedPreferences _prefs;

  LocalStorage(this._prefs);

  // Auth token
  Future<void> saveToken(String token) async =>
      _prefs.setString(AppConstants.tokenKey, token);

  Future<String?> getToken() async =>
      _prefs.getString(AppConstants.tokenKey);

  // Long-lived refresh token — used to silently mint new access tokens so the
  // user stays signed in until they explicitly log out.
  Future<void> saveRefreshToken(String token) async =>
      _prefs.setString(AppConstants.refreshTokenKey, token);

  Future<String?> getRefreshToken() async =>
      _prefs.getString(AppConstants.refreshTokenKey);

  Future<void> clearRefreshToken() async =>
      _prefs.remove(AppConstants.refreshTokenKey);

  /// Clears BOTH tokens — this is the session-over / logout path.
  Future<void> clearToken() async {
    await _prefs.remove(AppConstants.tokenKey);
    await _prefs.remove(AppConstants.refreshTokenKey);
  }

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

  bool get isLoggedIn =>
      _prefs.getString(AppConstants.tokenKey) != null;

  bool get isFirstLaunch =>
      _prefs.getString(AppConstants.langKey) == null;
}
