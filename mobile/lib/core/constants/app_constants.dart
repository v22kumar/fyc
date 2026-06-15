class AppConstants {
  AppConstants._();

  static const String appName = 'FYC Connect';
  static const String tokenKey = 'fyc_auth_token';
  static const String langKey = 'fyc_lang';
  static const String orgIdKey = 'fyc_org_id';
  static const String defaultLang = 'ta';

  static const List<String> bloodGroups = [
    'A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-',
  ];

  static const List<String> issueCategories = [
    'ROAD', 'WATER', 'STREET_LIGHT', 'GARBAGE', 'SAFETY', 'OTHER',
  ];

  static const List<String> volunteerRoles = [
    'PUBLIC_CITIZEN', 'VOLUNTEER',
  ];
}
