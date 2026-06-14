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
import '../../service_locator.dart';
import '../../features/blood_donation/presentation/bloc/blood_donor_bloc.dart';

final appRouter = GoRouter(
  initialLocation: '/',
  redirect: (context, state) {
    final authState = sl<AuthBloc>().state;
    final isAuth = authState is AuthAuthenticated;
    final isAtAuth = state.matchedLocation == '/login' ||
        state.matchedLocation == '/register' ||
        state.matchedLocation == '/lang-select';

    if (!isAuth && !isAtAuth && state.matchedLocation != '/') {
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
  ],
  errorBuilder: (context, state) => Scaffold(
    body: Center(
      child: Text('Page not found: ${state.error}'),
    ),
  ),
);
