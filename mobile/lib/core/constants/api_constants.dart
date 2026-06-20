class ApiConstants {
  ApiConstants._();

  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://10.0.2.2:8000', // Android emulator → host localhost
  );

  static const String defaultOrgId = String.fromEnvironment(
    'DEFAULT_ORG_ID',
    defaultValue: '8f8b80b7-4b71-4770-b183-5c5f49e49a1d',
  );

  static const String googleWebClientId = String.fromEnvironment(
    'GOOGLE_WEB_CLIENT_ID',
    defaultValue: '717823550652-71od456bvv5q7k5fhifqbbe5h378sdq6.apps.googleusercontent.com',
  );

  // Auth
  static const String otpSend = '/api/v1/auth/otp/send';
  static const String otpVerify = '/api/v1/auth/otp/verify';
  static const String register = '/api/v1/auth/register';
  static const String loginPassword = '/api/v1/auth/login/password';
  static const String googleSignIn = '/api/v1/auth/google';
  static const String me = '/api/v1/auth/users/me';

  // Blood donors
  static const String bloodDonors = '/api/v1/blood-donors';
  static const String registerDonor = '/api/v1/blood-donors/register';

  // Issues
  static const String issues = '/api/v1/issues';

  // Events
  static const String events = '/api/v1/events';

  // Membership
  static const String membershipMyCard = '/api/v1/membership/my-card';

  // Sports
  static const String sportsTournaments = '/api/v1/sports/tournaments';
  static const String sportsChallenges = '/api/v1/sports/challenges';

  // Announcements
  static const String announcements = '/api/v1/announcements';

  // Directory
  static const String directory = '/api/v1/directory';

  // Gallery
  static const String gallery = '/api/v1/gallery';

  // Green FYC
  static const String greenStats = '/api/v1/green/stats';
  static const String greenDrives = '/api/v1/green/drives';
  static const String greenTrees = '/api/v1/green/trees';

  // Volunteers
  static const String myCertificate = '/api/v1/volunteers/my-certificate';

  // Opportunities
  static const String opportunities = '/api/v1/opportunities';

  // Media
  static const String mediaUpload = '/api/v1/media/upload';

  // Community
  static const String community = '/api/v1/community';

  // Thirukkural
  static const String thirukkuralDaily = '/api/v1/thirukkural/daily';

  // News
  static const String newsTop = '/api/v1/news/top';
  static const String newsIndia = '/api/v1/news/india';
  static const String newsKanyakumari = '/api/v1/news/kanyakumari';
  static const String newsTnJobs = '/api/v1/news/tn-jobs';
  static const String newsCentralJobs = '/api/v1/news/central-jobs';

  // User profile
  static const String fcmToken = '/api/v1/users/me/fcm-token';
  static const String myProfile = '/api/v1/users/me/profile';

  // Utilities
  static const String weatherCurrent = '/api/v1/utilities/weather';
  static const String goldPrice = '/api/v1/utilities/gold-price';
}
