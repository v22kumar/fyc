import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../features/auth/presentation/bloc/auth_bloc.dart';
import '../../features/auth/presentation/bloc/auth_state.dart';
import '../../features/auth/presentation/screens/splash_screen.dart';
import '../../features/auth/presentation/screens/language_select_screen.dart';
import '../../features/auth/presentation/screens/otp_login_screen.dart';
import '../../features/auth/presentation/screens/register_screen.dart';
import '../../features/auth/presentation/screens/complete_profile_screen.dart';
import '../../features/auth/presentation/widgets/sign_in_sheet.dart';
import '../../features/home/presentation/screens/home_screen.dart';
import '../../features/search/presentation/screens/search_screen.dart';
import '../../features/blood_donation/presentation/screens/blood_donation_hub_screen.dart';
import '../../features/blood_donation/presentation/screens/donor_registration_screen.dart';
import '../../features/blood_donation/presentation/screens/blood_request_flow.dart';
import '../../features/blood_donation/presentation/screens/imported_directory_screen.dart';
import '../../features/events/presentation/screens/events_list_screen.dart';
import '../../features/issues/presentation/screens/report_issue_screen.dart';
import '../../features/issues/presentation/screens/review_queue_screen.dart';
import '../../features/membership/presentation/screens/membership_card_screen.dart';
import '../../features/membership/presentation/bloc/membership_bloc.dart';
import '../../features/events/presentation/screens/qr_scan_screen.dart';
import '../../service_locator.dart';
import '../storage/local_storage.dart';
import '../../features/settings/presentation/screens/settings_screen.dart';
import '../constants/api_constants.dart';
import '../../features/blood_donation/presentation/bloc/blood_donor_bloc.dart';
import '../../features/events/presentation/bloc/event_bloc.dart';

// Sports
import '../../features/sports/presentation/bloc/sports_bloc.dart';
import '../../features/sports/presentation/screens/sports_hub_screen.dart';
import '../../features/sports/presentation/screens/sports_tournament_detail_screen.dart';
import '../../features/sports/presentation/screens/create_tournament_screen.dart';
import '../../features/sports/presentation/screens/live_entries_approval_screen.dart';

// Chess
import '../../features/chess/data/datasources/chess_remote_datasource.dart';
import '../../features/chess/domain/repositories/chess_repository.dart';
import '../../features/chess/presentation/bloc/game_bloc.dart';
import '../../features/chess/presentation/bloc/online_game_bloc.dart';
import '../../features/chess/presentation/bloc/online_game_event.dart';
import '../../features/chess/presentation/bloc/spectator_bloc.dart';
import '../../features/chess/presentation/bloc/spectator_event.dart';
import '../../features/chess/presentation/bloc/ai_game_bloc.dart';
import '../../features/chess/presentation/pages/chess_home_page.dart';
import '../../features/chess_tournament/domain/repositories/tournament_repository.dart';
import '../../features/chess_tournament/presentation/bloc/tournament_bloc.dart';
import '../../features/chess_tournament/presentation/screens/tournament_list_screen.dart';
import '../../features/chess_tournament/presentation/screens/tournament_screen.dart';
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

// About
import '../../features/about/presentation/screens/about_screen.dart';

// Volunteer certificate
import '../../features/volunteers/presentation/screens/certificate_screen.dart';

// Community
import '../../features/community/presentation/bloc/community_bloc.dart';
import '../../features/community/presentation/screens/community_directory_screen.dart';
import '../../features/community/presentation/screens/members_roster_screen.dart';

// Journey
import '../../features/journey/presentation/screens/journey_screen.dart';
import '../../features/journey/presentation/bloc/journey_bloc.dart';
import '../../features/profile/presentation/screens/profile_screen.dart';

// Community Feed
import '../../features/feed/feed_screen.dart';
import '../../features/feed/create_post_screen.dart';

// Design System v2 (Sprint 1)
import '../design_system/design_system_gallery_screen.dart';
import '../../features/work/domain/repositories/work_repository.dart';
import '../../features/work/presentation/bloc/work_bloc.dart';
import '../../features/work/presentation/screens/create_listing_screen.dart';
import '../../features/work/presentation/screens/work_home_screen.dart';
import '../../features/complaint_box/domain/repositories/complaint_repository.dart';
import '../../features/safety/domain/repositories/safety_repository.dart';
import '../../features/safety/presentation/bloc/responder_bloc.dart';
import '../../features/safety/presentation/bloc/safety_setup_bloc.dart';
import '../../features/safety/presentation/bloc/sos_bloc.dart';
import '../../features/safety/presentation/screens/live_incidents_screen.dart';
import '../../features/safety/presentation/screens/responder_alert_screen.dart';
import '../../features/safety/presentation/screens/safety_setup_screen.dart';
import '../../features/safety/presentation/screens/sos_screen.dart';
import '../../features/complaint_box/presentation/bloc/complaint_bloc.dart';
import '../../features/complaint_box/presentation/bloc/complaint_list_bloc.dart';
import '../../features/complaint_box/presentation/screens/complaint_detail_screen.dart';
import '../../features/complaint_box/presentation/screens/my_complaints_screen.dart';
import '../design_system/shell/app_shell_v2.dart';
import '../../features/serve/presentation/screens/serve_hub_screen.dart';
import '../../features/profile/presentation/screens/me_hub_screen.dart';

/// Where the app opens, and where a signed-out member is sent if they reach
/// for something personal.
const kHomeRoute = '/app';

/// The only routes that require a session.
///
/// Everything else is open, because everything else is the club talking to the
/// village it serves: announcements, events, live scores, who has blood nearby.
/// A person who has just installed the app should be able to read all of that
/// before deciding whether to hand over a phone number — and the API already
/// answers every one of these anonymously.
///
/// This list is deliberately about *people's data*, not about features. A
/// member's phone number, a private profile, a membership card, a saved
/// certificate: those need a name attached. Reading the club's noticeboard does
/// not.
const kMembersOnly = <String>[
  '/me',
  '/profile',
  '/membership',
  '/certificate',
  '/journey',
  '/directory',
  '/members',
  '/settings',
  '/notifications',
];

final appRouter = GoRouter(
  initialLocation: '/',
  redirect: (context, state) {
    // DEV ONLY — bypass the auth guard so every route is reachable for testing.
    if (ApiConstants.devBypassAuth) return null;
    final authState = sl<AuthBloc>().state;
    final isAuth = authState is AuthAuthenticated;
    if (!isAuth && kMembersOnly.any(state.matchedLocation.startsWith)) {
      // Somewhere personal, without a session. Send them to the club's front
      // page rather than a login wall — signing in happens at the moment an
      // action needs it, not at the door.
      return kHomeRoute;
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
      path: '/complete-profile',
      builder: (context, state) => const CompleteProfileScreen(),
    ),
    GoRoute(
      path: '/register',
      builder: (context, state) {
        final extra = state.extra as Map<String, dynamic>?;
        return RegisterScreen(
          organizationId: extra?['organizationId'] as String? ?? '',
          phoneNumber: extra?['phoneNumber'] as String? ?? '',
          registrationToken: extra?['registrationToken'] as String? ?? '',
          prefillEmail: extra?['email'] as String?,
          prefillName: extra?['fullName'] as String?,
        );
      },
    ),
    GoRoute(
      // Home is only ever shown embedded in the one nav shell (AppShellV2) —
      // there is no standalone Home with its own bottom bar. `/home` and the
      // legacy fallback both resolve to the same shell as `/app` (audit #05:
      // one navigation, one FAB, one information architecture).
      path: '/home',
      builder: _appShellBuilder,
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
        // The Friends2Support directory is a destination in its own right, not
        // a section of the hub — it holds its own state and never touches the
        // hub's list.
        GoRoute(
          path: 'directory',
          builder: (context, state) => const ImportedDirectoryScreen(),
        ),
      ],
    ),
    // Where a blood notification lands.
    //
    // The server has been sending `route: /blood-requests/<id>` with every
    // blood push since the feature was written, and nothing has ever answered
    // it: a donor tapping "can you help?" and a requester tapping "a donor
    // responded" both arrived nowhere. The screen existed the whole time —
    // it was only reachable by raising a request in the same session.
    GoRoute(
      path: '/blood-requests/:id',
      builder: (context, state) =>
          BloodRequestScreen(requestId: state.pathParameters['id']!),
    ),
    GoRoute(
      path: '/events',
      builder: (context, state) => BlocProvider(
        create: (_) => sl<EventBloc>(),
        child: const EventsListScreen(),
      ),
    ),
    // Reporting: photo first, asked once, and straight into the Complaint Box
    // afterwards so the member gets a next step rather than a receipt.
    //
    // This used to open the older screen while the rebuilt one sat on
    // /issues/report, deliberately, so the two could run side by side instead
    // of switching on a flag day. Nothing ever linked to that route, so every
    // member tapping "Report an issue" got the old flow — which asks for the
    // same description twice, in two languages, promises "auto mail to
    // department" that the club no longer sends, and opens with a 50%
    // resolution rate computed from two reports.
    GoRoute(
      path: '/issues',
      builder: (context, state) => const ReportIssueScreen(),
    ),
    // Kept so anything holding the old link still lands somewhere sensible.
    GoRoute(
      path: '/issues/report',
      redirect: (_, __) => '/issues',
    ),
    // The club's side of the workflow. Without it a complaint stops at the
    // club instead of passing through it: nothing reaches a government office
    // until a member has read it, and until now there was no screen to read it
    // on.
    GoRoute(
      path: '/issues/queue',
      builder: (context, state) => const ReviewQueueScreen(),
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
    // The Complaint Box: one complaint, its three routes, and its timeline.
    GoRoute(
      path: '/complaints/:id',
      builder: (context, state) => BlocProvider(
        create: (_) => ComplaintBloc(sl<ComplaintRepository>())
          ..add(LoadComplaint(
            state.pathParameters['id']!,
            category: state.uri.queryParameters['category'],
          )),
        child: ComplaintDetailScreen(
          complaintId: state.pathParameters['id']!,
          category: state.uri.queryParameters['category'],
        ),
      ),
    ),
    // "My complaints" — the way back into anything already reported.
    //
    // The path is unchanged because half the app links to it. What is behind
    // it is not: the old screen listed issues by a status column the server
    // maintained by inference, so a complaint nobody had touched still read
    // "Under review". This one shows what somebody actually said.
    GoRoute(
      path: '/issues/track',
      builder: (context, state) => BlocProvider(
        create: (_) => ComplaintListBloc(sl<ComplaintRepository>()),
        child: const MyComplaintsScreen(),
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
    // ── Safety ────────────────────────────────────────────────────────────
    // One committed act with a way to take it back, and three screens behind
    // it. See docs/safety/01-architecture.md.
    GoRoute(
      path: '/sos',
      builder: (context, state) => BlocProvider(
        create: (_) => SosBloc(sl<SafetyRepository>()),
        child: const SosScreen(),
      ),
    ),
    GoRoute(
      // Where the SOS push lands. A notification row was where the old
      // broadcast ended — there was nothing on the other side of the tap, so
      // nobody could answer it and nobody did.
      path: '/safety/respond/:id',
      builder: (context, state) => BlocProvider(
        create: (_) => ResponderBloc(sl<SafetyRepository>()),
        child: ResponderAlertScreen(incidentId: state.pathParameters['id']!),
      ),
    ),
    GoRoute(
      path: '/safety/live',
      builder: (context, state) => const LiveIncidentsScreen(),
    ),
    GoRoute(
      path: '/settings/safety',
      builder: (context, state) => BlocProvider(
        create: (_) => SafetySetupBloc(sl<SafetyRepository>()),
        child: const SafetySetupScreen(),
      ),
    ),
    GoRoute(
      path: '/certificate',
      builder: (context, state) => const CertificateScreen(),
    ),
    GoRoute(
      // Local-trade / service-provider directory (carpenter, electrician…).
      // Reached from Opportunities, not the Members nav.
      path: '/community',
      builder: (context, state) => BlocProvider(
        create: (_) => sl<CommunityBloc>(),
        child: const CommunityDirectoryScreen(),
      ),
    ),
    GoRoute(
      // Real club-member roster (names/role/photo).
      path: '/members',
      builder: (context, state) => const MembersRosterScreen(),
    ),
    // The local work index — one place for skills, jobs and gigs.
    //
    // These two routes were lost in a rebase: the imports survived, and
    // /opportunities was left redirecting to a path that did not exist, so
    // every entry point in the app led to a route-not-found. The analyzer said
    // so, in the only way it can — four unused imports.
    GoRoute(
      path: '/work',
      builder: (context, state) => BlocProvider(
        create: (_) => WorkBloc(sl<WorkRepository>()),
        child: const WorkHomeScreen(),
      ),
    ),
    GoRoute(
      path: '/work/list',
      builder: (context, state) =>
          CreateListingScreen(repo: sl<WorkRepository>()),
    ),
    // The old opportunities screen: a create form with nothing to browse.
    // Replaced by the work index, and kept as a redirect so any held link
    // still lands somewhere useful.
    GoRoute(
      path: '/opportunities',
      redirect: (_, __) => '/work',
    ),

    // Chess
    GoRoute(
      path: '/chess',
      builder: (context, state) => BlocProvider(
        create: (_) => GameBloc(remote: sl<ChessRemoteDataSource>()),
        child: ChessHomePage(
            repo: sl<ChessRepository>(),
            storage: sl<LocalStorage>()),
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
          builder: (context, state) =>
              GameHistoryPage(repo: sl<ChessRepository>()),
        ),
        GoRoute(
          path: 'challenge',
          builder: (context, state) => ChallengePage(
              repo: sl<ChessRepository>(),
              authToken: () => sl<LocalStorage>().getToken()),
        ),
        GoRoute(
          path: 'online/:gameId',
          builder: (context, state) {
            final extra = state.extra as Map<String, dynamic>? ?? {};
            final gameId = state.pathParameters['gameId']!;
            final token = extra['token'] as String? ?? '';
            final myColor = (extra['color'] ?? extra['myColor']) as String? ?? 'white';
            return BlocProvider(
              create: (_) => OnlineGameBloc(
                  storedToken: () => sl<LocalStorage>().getToken())
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
                storage: sl<LocalStorage>(),
              ),
            );
          },
        ),
        GoRoute(
          path: 'replay/:gameId',
          builder: (context, state) {
            final gameId = state.pathParameters['gameId']!;
            return ReplayPage(gameId: gameId, repo: sl<ChessRepository>());
          },
        ),
        GoRoute(
          path: 'legacy',
          builder: (context, state) => LegacyPage(repo: sl<ChessRepository>()),
        ),
        GoRoute(
          path: 'legends',
          builder: (context, state) => const LegendsPage(),
        ),
        GoRoute(
          path: 'tournaments',
          builder: (context, state) => RepositoryProvider<TournamentRepository>.value(
            value: sl<TournamentRepository>(),
            child: BlocProvider(
              create: (_) => TournamentListBloc(sl<TournamentRepository>()),
              child: const TournamentListScreen(),
            ),
          ),
          routes: [
            // Deep-linked from push notifications (backend sends
            // /chess/tournaments/<id> as the tap route) — was previously
            // unregistered, so tapping a tournament notification crashed to
            // the router's error screen instead of opening the tournament.
            GoRoute(
              path: ':id',
              builder: (context, state) => BlocProvider(
                create: (_) => TournamentBloc(sl<TournamentRepository>(),
                    authToken: () => sl<LocalStorage>().getToken())
                  ..add(TournamentRequested(state.pathParameters['id']!)),
                child: TournamentScreen(
                  tournamentId: state.pathParameters['id']!,
                ),
              ),
            ),
          ],
        ),
      ],
    ),

    // Design System v2 (Sprint 1) — component gallery + shell preview.
    // Not linked from any production screen; reachable only via this direct
    // route for design/QA review while the new system is built out.
    GoRoute(
      path: '/design-system',
      builder: (context, state) => const DesignSystemGalleryScreen(),
    ),

    // Sprint 2 cutover — the real 4-tab design-system shell wired to live
    // feature screens (Home · Feed · Play · Serve) with the center Create FAB.
    // `/app` is the live post-login entry point (behind ApiConstants
    // .useAppShellV2); `/v2` stays as an explicit review alias. Home is
    // embedded so the shell owns the bottom nav.
    GoRoute(path: '/app', builder: _appShellBuilder),
    GoRoute(path: '/v2', builder: _appShellBuilder),
    // Account/profile hub — reached from the avatar in Home's top-right
    // corner, not a bottom-nav tab (see AppShellV2's doc comment).
    GoRoute(
      path: '/me',
      builder: (context, state) => const MeHubScreen(),
    ),
  ],
  errorBuilder: (context, state) => Scaffold(
    body: Center(child: Text('Page not found: ${state.error}')),
  ),
);

/// Builds the live 4-tab shell: Home (embedded) · Feed · Play · Serve, with
/// the center Create FAB wired to Home's create-actions sheet. Shared by
/// `/app` (the post-login entry point) and `/v2` (review alias).
Widget _appShellBuilder(BuildContext context, GoRouterState state) => AppShellV2(
      // Creating anything is signed by whoever created it, so this is one of
      // the moments identity is actually needed. Everything else in the shell —
      // the noticeboard, the feed, live scores, the service hub — reads fine
      // without a name attached.
      onCreate: () async {
        if (await SignInSheet.ensure(context) && context.mounted) {
          showHomeCreateSheet(context);
        }
      },
      tabs: [
        const HomeScreen(),
        const FeedScreen(),
        BlocProvider(
          create: (_) => sl<SportsBloc>(),
          child: const SportsHubScreen(),
        ),
        const ServeHubScreen(),
      ],
    );
