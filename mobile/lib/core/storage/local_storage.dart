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
