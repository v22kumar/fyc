class ApiConstants {
  ApiConstants._();

  /// Controls dev-only auth bypass. Activated by --dart-define=DEV_AUTH_BYPASS=true
  /// at build time. Always false in production Play Store builds.
  /// Allows admin/password123 login and skips the auth guard for fast testing.
  static const bool devBypassAuth = bool.fromEnvironment('DEV_AUTH_BYPASS', defaultValue: false);

  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://fyc-backend.fly.dev',
  );

  static const String defaultOrgId = String.fromEnvironment(
    'DEFAULT_ORG_ID',
    defaultValue: '8f8b80b7-4b71-4770-b183-5c5f49e49a1d',
  );

  static const String googleWebClientId = String.fromEnvironment(
    'GOOGLE_WEB_CLIENT_ID',
    defaultValue: '717823550652-71od456bvv5q7k5fhifqbbe5h378sdq6.apps.googleusercontent.com',
  );

  // serverClientId for the *mobile* app's Google Sign-In. This is the Web OAuth
  // client of THIS app's Firebase project (fyc-connect-25ab0 / 986299606001) —
  // distinct from googleWebClientId above, which is the website's project. It
  // must be the project whose SHA-1 is registered in Firebase, or Google returns
  // a null idToken. Not a secret (ships in google-services.json + every APK);
  // a build may override it via --dart-define=GOOGLE_SERVER_CLIENT_ID=... .
  static const String googleServerClientId = String.fromEnvironment(
    'GOOGLE_SERVER_CLIENT_ID',
    defaultValue:
        '986299606001-jj9nkt5grit2ra01dsf8gcqbt9k50lar.apps.googleusercontent.com',
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

  // Geography (taluk dropdown for location filtering)
  static const String geography = '/api/v1/geography';

  // Issues
  static const String issues = '/api/v1/issues';
  static const String issueStats = '/api/v1/issues/stats';

  // Events
  static const String events = '/api/v1/events';

  // Membership
  static const String membershipMyCard = '/api/v1/membership/my-card';

  // Sports
  static const String sportsTournaments = '/api/v1/sports/tournaments';
  static const String sportsChallenges = '/api/v1/sports/challenges';
  static const String sportsLiveEntries = '/api/v1/sports/live-entries';
  static String sportsGenerateFixtures(String tid) =>
      '/api/v1/sports/tournaments/$tid/generate-fixtures';
  static String sportsCloseRegistration(String tid) =>
      '/api/v1/sports/tournaments/$tid/close-registration';
  static String sportsFixtureLiveEntry(String fid) =>
      '/api/v1/sports/fixtures/$fid/live-entry';
  static String sportsTournamentFixtures(String tid) =>
      '/api/v1/sports/tournaments/$tid/fixtures';
  static String sportsTournamentTeams(String tid) =>
      '/api/v1/sports/tournaments/$tid/teams';
  static String sportsTeamPlayers(String teamId) =>
      '/api/v1/sports/teams/$teamId/players';
  // Cricket scoring router has NO /sports prefix (mounted at /api/v1 directly).
  static String sportsFixtureCricket(String fid) =>
      '/api/v1/fixtures/$fid/cricket';
  static String sportsFixtureCricketInit(String fid) =>
      '/api/v1/fixtures/$fid/cricket/init';
  static String sportsFixtureCricketBall(String fid) =>
      '/api/v1/fixtures/$fid/cricket/ball';
  static String sportsFixtureCricketUndo(String fid) =>
      '/api/v1/fixtures/$fid/cricket/undo';
  static String sportsFixtureCricketSecondInnings(String fid) =>
      '/api/v1/fixtures/$fid/cricket/second-innings';

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

  // App metadata / in-app updater
  static const String appInfo = '/api/v1/app/info';
  static const String appDownload = '/api/v1/app/download';

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
  static const String chessAwardsWeekly = '/api/v1/chess/awards/weekly';

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
