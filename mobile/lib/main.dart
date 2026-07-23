import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'core/services/sync_service.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'core/router/app_router.dart';
import 'core/services/local_notifications.dart';
import 'core/theme/app_theme.dart';
import 'core/l10n/app_localizations.dart';
import 'core/storage/local_storage.dart';
import 'core/widgets/offline_banner.dart';
import 'core/network/api_client.dart';
import 'core/constants/api_constants.dart';
import 'features/auth/presentation/bloc/auth_bloc.dart';
import 'features/auth/presentation/bloc/auth_event.dart';
import 'service_locator.dart';

final localeNotifier = ValueNotifier<Locale>(const Locale('ta'));
// The app follows the OS light/dark setting automatically — there is no
// manual toggle in Settings. 'light'/'dark' remain valid stored values (in
// case a device/QA build ever needs to force one) but default to 'system'.
final themeModeNotifier = ValueNotifier<ThemeMode>(ThemeMode.system);

ThemeMode themeModeFromString(String s) => switch (s) {
      'dark' => ThemeMode.dark,
      'light' => ThemeMode.light,
      _ => ThemeMode.system,
    };


@pragma('vm:entry-point')
Future<void> _onBackgroundMessage(RemoteMessage message) async {
  await Firebase.initializeApp();
}

void _handleNotificationClick(BuildContext context, RemoteMessage message) {
  final route = message.data['route'];
  if (route != null && route.isNotEmpty) {
    context.go(route);
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();
  await SyncService.init();
  await Firebase.initializeApp();
  FirebaseMessaging.onBackgroundMessage(_onBackgroundMessage);
  await FirebaseMessaging.instance.requestPermission(alert: true, badge: true, sound: true);
  await LocalNotifications.init();
  LocalNotifications.onTapRoute = (route) {
    final context = appRouter.routerDelegate.navigatorKey.currentContext;
    if (context != null && route.isNotEmpty) context.go(route);
  };
  await initServiceLocator();
  // A mid-session 401 (the 60-minute access token expired, no refresh
  // mechanism) previously failed silently — every request kept breaking
  // until the user force-closed and reopened the app. Reset auth state via
  // the bloc (consistent with the Logout button's own path) and bounce them
  // back to login. Wired here, not in ApiClient itself, so the networking
  // layer never has to import the router/feature layer directly.
  ApiClient.onSessionExpired = () {
    sl<AuthBloc>().add(const AuthLogoutRequested());
    final context = appRouter.routerDelegate.navigatorKey.currentContext;
    if (context != null) context.go('/lang-select');
  };
  // Drain the offline outbox only after the service locator is ready — the
  // sync path resolves sl<ApiClient>() and would fail on an unregistered
  // dependency if triggered earlier in startup.
  SyncService.triggerSync();
  localeNotifier.value = Locale(sl<LocalStorage>().getLang());
  themeModeNotifier.value = themeModeFromString(sl<LocalStorage>().getTheme());
  
  _warmUpBackend();
  runApp(
    const ProviderScope(
      child: FycApp(),
    ),
  );
}

Future<void> _warmUpBackend() async {
  try {
    await sl<ApiClient>().dio
        .get('/api/health')
        .timeout(const Duration(seconds: 20));
  } catch (_) {}
}

class FycApp extends StatefulWidget {
  const FycApp({super.key});

  @override
  State<FycApp> createState() => _FycAppState();
}

class _FycAppState extends State<FycApp> {
  @override
  void initState() {
    super.initState();
    _setupFCM();
  }

  Future<void> _setupFCM() async {
    // Every FirebaseMessaging access below can throw SYNCHRONOUSLY if
    // Firebase failed to initialize (missing/outdated Play Services on a
    // real device; always true in widget tests, which never call
    // Firebase.initializeApp()). This is called fire-and-forget from
    // initState, so an uncaught throw here would surface as an unhandled
    // async exception and crash app startup — guard the whole thing so a
    // broken push stack never blocks the app from opening.
    try {
      // Background message interaction
      FirebaseMessaging.instance.getInitialMessage().then((message) {
        if (message != null && mounted) {
          // Delay to allow router to initialize
          Future.delayed(const Duration(milliseconds: 500), () {
            final navContext = appRouter.routerDelegate.navigatorKey.currentContext;
            if (mounted && navContext != null) {
              _handleNotificationClick(navContext, message);
            }
          });
        }
      });

      // Foreground message handler — post to the system tray (FCM only auto-posts
      // to the tray when the app is backgrounded) so the user sees it everywhere.
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        if (message.notification != null) {
          LocalNotifications.showFromMessage(message);
        }
      });

      // Background interaction handler
      FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
        final navContext = appRouter.routerDelegate.navigatorKey.currentContext;
        if (mounted && navContext != null) {
          _handleNotificationClick(navContext, message);
        }
      });

      // Token Sync
      final token = await FirebaseMessaging.instance.getToken();
      if (token != null) _syncToken(token);
      FirebaseMessaging.instance.onTokenRefresh.listen(_syncToken);
    } catch (_) {
      // Best-effort: push setup should never block the app from starting.
    }
  }

  Future<void> _syncToken(String token) async {
    try {
      await sl<ApiClient>().dio.post(
        ApiConstants.fcmToken,
        data: {'token': token},
      );
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(
      value: sl<AuthBloc>(),
      child: ValueListenableBuilder<Locale>(
        valueListenable: localeNotifier,
        builder: (context, locale, _) {
          return ValueListenableBuilder<ThemeMode>(
            valueListenable: themeModeNotifier,
            builder: (context, themeMode, __) {
              return MaterialApp.router(
                title: 'FYC',
                debugShowCheckedModeBanner: false,
                // Theme is rebuilt per language so the correct script font
                // (Plus Jakarta / Noto Sans Tamil-Devanagari-Malayalam) is
                // always active — Outfit had no Tamil glyphs.
                theme: AppTheme.lightFor(locale.languageCode),
                darkTheme: AppTheme.darkFor(locale.languageCode),
                themeMode: themeMode,
                routerConfig: appRouter,
                locale: locale,
                localizationsDelegates: AppLocalizations.localizationsDelegates,
                supportedLocales: AppLocalizations.supportedLocales,
                builder: (context, child) => Column(
                  children: [
                    const OfflineBanner(),
                    Expanded(child: child ?? const SizedBox()),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}
// trigger build
