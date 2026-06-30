import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../features/auth/presentation/bloc/auth_bloc.dart';
import '../../features/auth/presentation/bloc/auth_state.dart';
import '../../features/auth/presentation/screens/splash_screen.dart';
import '../../features/auth/presentation/screens/language_select_screen.dart';
import '../../features/auth/presentation/screens/otp_login_screen.dart';
import '../../features/auth/presentation/screens/register_screen.dart';
import '../../features/home/presentation/screens/home_screen.dart';
import '../../features/search/presentation/screens/search_screen.dart';
import '../../features/blood_donation/presentation/screens/blood_donation_hub_screen.dart';
import '../../features/blood_donation/presentation/screens/donor_registration_screen.dart';
import '../../features/events/presentation/screens/events_list_screen.dart';
import '../../features/issues/presentation/screens/submit_issue_screen.dart';
import '../../features/common/screens/opportunities_screen.dart';
import '../../features/membership/presentation/screens/membership_card_screen.dart';
import '../../features/membership/presentation/bloc/membership_bloc.dart';
import '../../features/events/presentation/screens/qr_scan_screen.dart';
import '../../service_locator.dart';
import '../constants/api_constants.dart';
import '../../features/blood_donation/presentation/bloc/blood_donor_bloc.dart';
import '../../features/events/presentation/bloc/event_bloc.dart';
import '../../features/issues/presentation/bloc/issue_bloc.dart';

// Sports
import '../../features/sports/presentation/bloc/sports_bloc.dart';
import '../../features/sports/presentation/screens/sports_hub_screen.dart';
import '../../features/sports/presentation/screens/sports_tournament_detail_screen.dart';
import '../../features/sports/presentation/screens/challenge_form_screen.dart';
import '../../features/sports/presentation/screens/create_tournament_screen.dart';
import '../../features/sports/presentation/screens/live_entries_approval_screen.dart';

// Chess
import '../../features/chess/data/datasources/chess_remote_datasource.dart';
import '../../features/chess/presentation/bloc/game_bloc.dart';
import '../../features/chess/presentation/bloc/online_game_bloc.dart';
import '../../features/chess/presentation/bloc/online_game_event.dart';
import '../../features/chess/presentation/bloc/spectator_bloc.dart';
import '../../features/chess/presentation/bloc/spectator_event.dart';
import '../../features/chess/presentation/bloc/ai_game_bloc.dart';
import '../../features/chess/presentation/pages/chess_home_page.dart';
import '../../features/chess/presentation/pages/local_game_page.dart';
import '../../features/chess/presentation/pages/game_history_page.dart';
import '../../features/chess/presentation/pages/challenge_page.dart';
import '../../features/chess/presentation/pages/online_game_page.dart';
import '../../features/chess/presentation/pages/spectator_page.dart';
import '../../features/chess/presentation/pages/ai_game_page.dart';
import '../../features/chess/presentation/pages/replay_page.dart';
import '../../features/chess/presentation/pages/legacy_page.dart';
import '../../features/chess/presentation/pages/legends_page.dart';

// Green FYC
import '../../features/green_fyc/presentation/bloc/green_bloc.dart';
import '../../features/green_fyc/presentation/screens/green_fyc_screen.dart';
import '../../features/green_fyc/presentation/screens/tree_registration_screen.dart';

// Directory
import '../../features/directory/presentation/bloc/directory_bloc.dart';
import '../../features/directory/presentation/screens/directory_screen.dart';

// Announcements
import '../../features/announcements/domain/entities/announcement_entity.dart';
import '../../features/announcements/presentation/bloc/announcement_bloc.dart';
import '../../features/announcements/presentation/screens/announcements_screen.dart';
import '../../features/announcements/presentation/screens/announcement_detail_screen.dart';
import '../../features/notifications/presentation/bloc/notification_bloc.dart';
import '../../features/notifications/presentation/pages/notification_screen.dart';

// Gallery
import '../../features/gallery/domain/entities/photo_entity.dart';
import '../../features/gallery/presentation/bloc/gallery_bloc.dart';
import '../../features/gallery/presentation/screens/gallery_screen.dart';
import '../../features/gallery/presentation/screens/photo_viewer_screen.dart';

// Issue tracking
import '../../features/issues/presentation/bloc/issue_list_bloc.dart';
import '../../features/issues/presentation/screens/issues_track_screen.dart';

// About
import '../../features/about/presentation/screens/about_screen.dart';
import '../../features/settings/presentation/screens/settings_screen.dart';

// Volunteer certificate
import '../../features/volunteers/presentation/screens/certificate_screen.dart';

// Community
import '../../features/community/presentation/bloc/community_bloc.dart';
import '../../features/community/presentation/screens/community_directory_screen.dart';

// Journey
import '../../features/journey/presentation/screens/journey_screen.dart';
import '../../features/journey/presentation/bloc/journey_bloc.dart';
import '../../features/profile/presentation/screens/profile_screen.dart';

// Community Feed
import '../../features/feed/feed_screen.dart';
import '../../features/feed/create_post_screen.dart';

final appRouter = GoRouter(
  initialLocation: '/',
  redirect: (context, state) {
    // DEV ONLY — bypass the auth guard so every route is reachable for testing.
    if (ApiConstants.devBypassAuth) return null;
    final authState = sl<AuthBloc>().state;
    final isAuth = authState is AuthAuthenticated;
    final publicRoutes = {'/', '/lang-select', '/login', '/register'};
    if (!isAuth && !publicRoutes.contains(state.matchedLocation)) {
      return '/lang-select';
    }
    return null;
  },
  routes: [
    GoRoute(
      path: '/',
      builder: (context, state) => const SplashScreen(),
    ),
    GoRoute(
      path: '/lang-select',
      builder: (context, state) => const LanguageSelectScreen(),
    ),
    GoRoute(
      path: '/login',
      builder: (context, state) => const OtpLoginScreen(),
    ),
    GoRoute(
      path: '/register',
      builder: (context, state) {
        final extra = state.extra as Map<String, dynamic>?;
        return RegisterScreen(
          organizationId: extra?['organizationId'] as String? ?? '',
          phoneNumber: extra?['phoneNumber'] as String? ?? '',
        );
      },
    ),
    GoRoute(
      path: '/home',
      builder: (context, state) => const HomeScreen(),
    ),
    GoRoute(
      path: '/search',
      builder: (context, state) => const SearchScreen(),
    ),
    GoRoute(
      path: '/profile',
      builder: (context, state) => const ProfileScreen(),
    ),
    GoRoute(
      path: '/journey',
      builder: (context, state) => BlocProvider(
        create: (_) => sl<JourneyBloc>(),
        child: const JourneyScreen(),
      ),
    ),
    GoRoute(
      path: '/feed',
      builder: (context, state) => const FeedScreen(),
      routes: [
        GoRoute(
          path: 'create',
          builder: (context, state) => const CreatePostScreen(),
        ),
      ],
    ),
    GoRoute(
      path: '/blood-donation',
      builder: (context, state) => BlocProvider(
        create: (_) => sl<BloodDonorBloc>(),
        child: const BloodDonationHubScreen(),
      ),
      routes: [
        GoRoute(
          path: 'register',
          builder: (context, state) => BlocProvider(
            create: (_) => sl<BloodDonorBloc>(),
            child: const DonorRegistrationScreen(),
          ),
        ),
      ],
    ),
    GoRoute(
      path: '/events',
      builder: (context, state) => BlocProvider(
        create: (_) => sl<EventBloc>(),
        child: const EventsListScreen(),
      ),
    ),
    GoRoute(
      path: '/issues',
      builder: (context, state) => BlocProvider(
        create: (_) => sl<IssueBloc>(),
        child: const SubmitIssueScreen(),
      ),
    ),
    GoRoute(
      path: '/membership',
      builder: (context, state) => BlocProvider(
        create: (_) => sl<MembershipBloc>(),
        child: const MembershipCardScreen(),
      ),
    ),
    GoRoute(
      path: '/scan',
      builder: (context, state) => const QrScanScreen(),
    ),
    GoRoute(
      path: '/gallery',
      builder: (context, state) => BlocProvider(
        create: (_) => sl<GalleryBloc>(),
        child: const GalleryScreen(),
      ),
      routes: [
        GoRoute(
          path: 'photo',
          builder: (context, state) =>
              PhotoViewerScreen(photo: state.extra as PhotoEntity),
        ),
      ],
    ),
    GoRoute(
      path: '/directory',
      builder: (context, state) => BlocProvider(
        create: (_) => sl<DirectoryBloc>(),
        child: const DirectoryScreen(),
      ),
    ),
    GoRoute(
      path: '/sports',
      builder: (context, state) => BlocProvider(
        create: (_) => sl<SportsBloc>(),
        child: const SportsHubScreen(),
      ),
      routes: [
        GoRoute(
          path: 'tournament',
          builder: (context, state) {
            final extra = state.extra as Map<String, dynamic>?;
            return BlocProvider(
              create: (_) => sl<SportsBloc>(),
              child: SportsTournamentDetailScreen(
                tournamentId: extra?['tournamentId'] as String? ?? '',
              ),
            );
          },
        ),
        GoRoute(
          path: 'challenge',
          builder: (context, state) => BlocProvider(
            create: (_) => sl<SportsBloc>(),
            child: const ChallengeFormScreen(),
          ),
        ),
        GoRoute(
          path: 'create',
          builder: (context, state) => const CreateTournamentScreen(),
        ),
        GoRoute(
          path: 'approvals',
          builder: (context, state) => const LiveEntriesApprovalScreen(),
        ),
      ],
    ),
    GoRoute(
      path: '/green',
      builder: (context, state) => BlocProvider(
        create: (_) => sl<GreenBloc>(),
        child: const GreenFycScreen(),
      ),
      routes: [
        GoRoute(
          path: 'register',
          builder: (context, state) => BlocProvider(
            create: (_) => sl<GreenBloc>(),
            child: const TreeRegistrationScreen(),
          ),
        ),
      ],
    ),
    GoRoute(
      path: '/notifications',
      builder: (context, state) => BlocProvider(
        create: (_) => sl<NotificationBloc>(),
        child: const NotificationScreen(),
      ),
    ),
    GoRoute(
      path: '/announcements',
      builder: (context, state) => BlocProvider(
        create: (_) => sl<AnnouncementBloc>(),
        child: const AnnouncementsScreen(),
      ),
      routes: [
        GoRoute(
          path: 'detail',
          builder: (context, state) => AnnouncementDetailScreen(
            announcement: state.extra as AnnouncementEntity,
          ),
        ),
      ],
    ),
    GoRoute(
      path: '/issues/track',
      builder: (context, state) => BlocProvider(
        create: (_) => sl<IssueListBloc>(),
        child: const IssuesTrackScreen(),
      ),
    ),
    GoRoute(
      path: '/about',
      builder: (context, state) => const AboutScreen(),
    ),
    GoRoute(
      path: '/settings',
      builder: (context, state) => const SettingsScreen(),
    ),
    GoRoute(
      path: '/certificate',
      builder: (context, state) => const CertificateScreen(),
    ),
    GoRoute(
      path: '/community',
      builder: (context, state) => BlocProvider(
        create: (_) => sl<CommunityBloc>(),
        child: const CommunityDirectoryScreen(),
      ),
    ),
    GoRoute(
      path: '/opportunities',
      builder: (context, state) => const OpportunitiesScreen(),
    ),

    // Chess
    GoRoute(
      path: '/chess',
      builder: (context, state) => BlocProvider(
        create: (_) => GameBloc(remote: sl<ChessRemoteDataSource>()),
        child: const ChessHomePage(),
      ),
      routes: [
        GoRoute(
          path: 'local',
          builder: (context, state) {
            final extra = state.extra as Map<String, dynamic>? ?? {};
            return BlocProvider(
              create: (_) => GameBloc(remote: sl<ChessRemoteDataSource>()),
              child: LocalGamePage(
                whiteName: extra['white'] as String? ?? 'White',
                blackName: extra['black'] as String? ?? 'Black',
              ),
            );
          },
        ),
        GoRoute(
          path: 'history',
          builder: (context, state) => const GameHistoryPage(),
        ),
        GoRoute(
          path: 'challenge',
          builder: (context, state) => const ChallengePage(),
        ),
        GoRoute(
          path: 'online/:gameId',
          builder: (context, state) {
            final extra = state.extra as Map<String, dynamic>? ?? {};
            final gameId = state.pathParameters['gameId']!;
            final token = extra['token'] as String? ?? '';
            final myColor = (extra['color'] ?? extra['myColor']) as String? ?? 'white';
            return BlocProvider(
              create: (_) => OnlineGameBloc()
                ..add(ConnectToGame(
                  gameId: gameId,
                  token: token,
                  myColor: myColor,
                )),
              child: OnlineGamePage(gameId: gameId),
            );
          },
        ),
        GoRoute(
          path: 'spectate/:gameId',
          builder: (context, state) {
            final extra = state.extra as Map<String, dynamic>? ?? {};
            final gameId = state.pathParameters['gameId']!;
            final token = extra['token'] as String? ?? '';
            return BlocProvider(
              create: (_) => SpectatorBloc()
                ..add(ConnectSpectator(gameId: gameId, token: token)),
              child: SpectatorPage(gameId: gameId),
            );
          },
        ),
        GoRoute(
          path: 'ai',
          builder: (context, state) {
            final extra = state.extra as Map<String, dynamic>? ?? {};
            return BlocProvider(
              create: (_) => AiGameBloc(),
              child: AiGamePage(
                depth: extra['depth'] as int? ?? 5,
                skill: extra['skill'] as int? ?? 10,
                playerIsWhite: extra['playerIsWhite'] as bool? ?? true,
              ),
            );
          },
        ),
        GoRoute(
          path: 'replay/:gameId',
          builder: (context, state) {
            final gameId = state.pathParameters['gameId']!;
            return ReplayPage(gameId: gameId);
          },
        ),
        GoRoute(
          path: 'legacy',
          builder: (context, state) => const LegacyPage(),
        ),
        GoRoute(
          path: 'legends',
          builder: (context, state) => const LegendsPage(),
        ),
      ],
    ),
  ],
  errorBuilder: (context, state) => Scaffold(
    body: Center(child: Text('Page not found: ${state.error}')),
  ),
);
