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
import '../../features/blood_donation/presentation/screens/blood_donation_hub_screen.dart';
import '../../features/blood_donation/presentation/screens/donor_registration_screen.dart';
import '../../features/events/presentation/screens/events_list_screen.dart';
import '../../features/issues/presentation/screens/submit_issue_screen.dart';
import '../../features/common/screens/coming_soon_screen.dart';
import '../../service_locator.dart';
import '../../features/blood_donation/presentation/bloc/blood_donor_bloc.dart';
import '../../features/events/presentation/bloc/event_bloc.dart';
import '../../features/issues/presentation/bloc/issue_bloc.dart';

final appRouter = GoRouter(
  initialLocation: '/',
  redirect: (context, state) {
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
      builder: (context, state) => const RegisterScreen(),
    ),
    GoRoute(
      path: '/home',
      builder: (context, state) => const HomeScreen(),
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
      path: '/gallery',
      builder: (context, state) => const ComingSoonScreen(
        title: 'Gallery',
        emoji: '📷',
        subtitleEn: 'Our photo gallery is being curated. Check back soon!',
        subtitleTa: 'புகைப்பட தொகுப்பு விரைவில் வருகிறது.',
      ),
    ),
    GoRoute(
      path: '/directory',
      builder: (context, state) => const ComingSoonScreen(
        title: 'Member Directory',
        emoji: '📋',
        subtitleEn: 'The member directory will be available in the next update.',
        subtitleTa: 'உறுப்பினர் அட்டவணை விரைவில் கிடைக்கும்.',
      ),
    ),
    GoRoute(
      path: '/opportunities',
      builder: (context, state) => const ComingSoonScreen(
        title: 'Opportunity Hub',
        emoji: '📚',
        subtitleEn: 'Volunteer opportunities and skill-building resources coming soon.',
        subtitleTa: 'தன்னார்வ வாய்ப்புகள் விரைவில் வருகின்றன.',
      ),
    ),
  ],
  errorBuilder: (context, state) => Scaffold(
    body: Center(child: Text('Page not found: ${state.error}')),
  ),
);
