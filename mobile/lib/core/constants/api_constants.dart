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

  // Chess — REST
  static const String chessGames = '/api/v1/chess/games';
  static const String chessMyGames = '/api/v1/chess/games/my';
  static const String chessMyStats = '/api/v1/chess/players/me/stats';
  static const String chessMembers = '/api/v1/chess/members';
  static const String chessChallenges = '/api/v1/chess/challenges';
  static const String chessChallengesIncoming = '/api/v1/chess/challenges/incoming';
  static const String chessChallengesOutgoing = '/api/v1/chess/challenges/outgoing';
  static const String chessLiveGames = '/api/v1/chess/games/live';

  // Chess — WebSocket
  // e.g. ws://10.0.2.2:8000/api/v1/chess/games/{id}/ws?token=...
  static String chessGameWs(String gameId) {
    final wsBase = baseUrl
        .replaceFirst('https://', 'wss://')
        .replaceFirst('http://', 'ws://');
    return '$wsBase/api/v1/chess/games/$gameId/ws';
  }

  // e.g. ws://10.0.2.2:8000/api/v1/chess/games/{id}/spectate?token=...
  static String chessGameSpectateWs(String gameId) {
    final wsBase = baseUrl
        .replaceFirst('https://', 'wss://')
        .replaceFirst('http://', 'ws://');
    return '$wsBase/api/v1/chess/games/$gameId/spectate';
  }
}
