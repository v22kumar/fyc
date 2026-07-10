class AppConstants {
  AppConstants._();

  static const String appName = 'FYC Connect';
  static const String tokenKey = 'fyc_auth_token';
  static const String langKey = 'fyc_lang';
  static const String orgIdKey = 'fyc_org_id';
  static const String themeKey = 'fyc_theme'; // 'light' | 'dark' | 'system'
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
