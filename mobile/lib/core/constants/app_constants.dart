class AppConstants {
  AppConstants._();

  static const String appName = 'FYC Connect';
  static const String tokenKey = 'fyc_auth_token';
  static const String refreshTokenKey = 'fyc_refresh_token';
  // Non-sensitive marker so `isLoggedIn` stays a synchronous check even though
  // the tokens themselves now live in encrypted secure storage.
  static const String hasSessionKey = 'fyc_has_session';
  static const String langKey = 'fyc_lang';
  static const String orgIdKey = 'fyc_org_id';
  static const String themeKey = 'fyc_theme'; // 'light' | 'dark' | 'system'
  /// The last profile the server confirmed, kept so a cold start with no
  /// network still knows whose app this is. Never a credential — the
  /// tokens stay in secure storage.
  static const String cachedUserKey = 'fyc_cached_user';
  static const String defaultLang = 'ta';

  static const List<String> bloodGroups = [
    'A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-',
  ];

  // Must match backend IssueCategory (v2.0). The Report-an-Issue screen carries
  // its own labelled list; this is kept in sync so nothing sends a retired value.
  static const List<String> issueCategories = [
    'ROAD_TRAFFIC', 'POWER_CUT', 'WATER', 'OTHER',
  ];

  static const List<String> volunteerRoles = [
    'PUBLIC_CITIZEN', 'VOLUNTEER',
  ];
}
