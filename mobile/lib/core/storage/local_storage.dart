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

  Future<void> clearToken() async =>
      _prefs.remove(AppConstants.tokenKey);

  // Language preference
  Future<void> saveLang(String lang) async =>
      _prefs.setString(AppConstants.langKey, lang);

  String getLang() =>
      _prefs.getString(AppConstants.langKey) ?? AppConstants.defaultLang;

  // Theme preference: 'light' | 'dark' | 'system'
  Future<void> saveTheme(String mode) async =>
      _prefs.setString(AppConstants.themeKey, mode);

  String getTheme() =>
      _prefs.getString(AppConstants.themeKey) ?? 'light';

  // Generic getString
  String? getString(String key) => _prefs.getString(key);

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
