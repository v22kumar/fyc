import 'package:fyc_connect/core/l10n/tr.dart';
import 'dart:async';
import 'core/services/error_reporter.dart';
import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter/material.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'core/services/sync_service.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'core/router/app_router.dart';
import 'core/services/local_notifications.dart';
import 'core/services/siren_controller.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/theme_manager.dart';
import 'core/l10n/app_localizations.dart';
import 'core/storage/local_storage.dart';
import 'core/widgets/offline_banner.dart';
import 'features/chess/presentation/active_game_watcher.dart';
import 'features/chess/presentation/widgets/chess_game_ready_banner.dart';
import 'core/network/api_client.dart';
import 'core/constants/api_constants.dart';
import 'features/auth/presentation/bloc/auth_bloc.dart';
import 'features/auth/presentation/bloc/auth_event.dart';
import 'features/auth/presentation/bloc/auth_state.dart';
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

/// Routes straight through the router singleton — a notification tap has no
/// meaningful BuildContext of its own, and fetching one from the navigator key
/// only to call `context.go` was borrowing trouble across async gaps.
void _handleNotificationClick(RemoteMessage message) {
  final route = message.data['route'];
  if (route != null && route.isNotEmpty) {
    appRouter.go(route);
  }
}

void main() async {
  // Catch anything that escapes — framework errors, async gaps, and errors
  // thrown during startup itself — and send it to our own backend. With no
  // device to test on, hearing about a failure the moment a member hits it is
  // the only feedback loop available. Everything in the reporter is
  // best-effort; it can never be the thing that breaks the app.
  runZonedGuarded(() async {
    await _bootstrap();
  }, (error, stack) {
    ErrorReporter.instance.report(error, stack, context: 'zone');
  });
}

Future<void> _bootstrap() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Real URLs in a browser, not `#/blood-donation`.
  //
  // Flutter web defaults to hash routing, which quietly undoes deep links: the
  // path never reaches go_router, so app.fycconnect.com/blood-requests/<id> —
  // where every blood notification points — opens the home screen instead of
  // the request. The nginx rule that serves index.html for unknown paths is
  // necessary for this and not sufficient on its own; both halves are needed.
  //
  // No-op off the web, so Android is unaffected.
  if (kIsWeb) usePathUrlStrategy();
  ErrorReporter.instance.install();
  await Hive.initFlutter();
  await SyncService.init();
  // Push is a nice-to-have; the app must start without it. Firebase can fail on
  // a device with missing or outdated Play Services — and unguarded, that
  // failure throws out of main() BEFORE runApp(), so the user gets a
  // permanently blank screen instead of an app with no notifications. The
  // FirebaseMessaging calls further down already defend against this state;
  // the initialisation itself did not.
  try {
    await Firebase.initializeApp();
    FirebaseMessaging.onBackgroundMessage(_onBackgroundMessage);
    await FirebaseMessaging.instance
        .requestPermission(alert: true, badge: true, sound: true);
  } catch (e) {
    debugPrint('[startup] push notifications unavailable: $e');
  }
  try {
    await LocalNotifications.init();
  } catch (e) {
    debugPrint('[startup] local notifications unavailable: $e');
  }
  LocalNotifications.onTapRoute = (route) {
    final context = appRouter.routerDelegate.navigatorKey.currentContext;
    if (context != null && route.isNotEmpty) context.go(route);
  };
  // Locale data for dates. Without this DateFormat throws on any
  // non-English locale, which is most of this app's members.
  await initializeDateFormatting();
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
  
  await ThemeManager.instance.init();
  
  _warmUpBackend();
  // Poll "do I have a chess game to join?" app-wide, so a player is pulled into
  // an accepted game from any screen (no reliance on the challenge screen or a
  // best-effort push). Self-guards on auth state, so it's a no-op when logged out.
  ChessActiveGameWatcher.instance.start(
    currentUserId: () {
      final s = sl<AuthBloc>().state;
      return s is AuthAuthenticated ? s.user.id : null;
    },
    fetchActive: () async =>
        (await sl<ApiClient>().dio.get('${ApiConstants.chessGames}/active'))
            .data,
  );
  runApp(const FycApp());
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
            if (mounted) _handleNotificationClick(message);
          });
        }
      });

      // Foreground message handler — post to the system tray (FCM only auto-posts
      // to the tray when the app is backgrounded) so the user sees it everywhere.
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        if (message.notification != null) {
          LocalNotifications.showFromMessage(message);
        }
        // An SOS arriving while the app is open gets the alarm too.
        //
        // In the foreground Android hands the message to us and posts nothing
        // itself, so the channel's alarm sound never plays — which would mean
        // the one member most likely to be holding their phone is the one who
        // hears nothing. The siren runs until they open the alert.
        if (LocalNotifications.isSos(message)) {
          SirenController.instance.start();
        }
      });

      // Background interaction handler
      FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
        if (mounted) _handleNotificationClick(message);
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
      child: ValueListenableBuilder<DesignTokens>(
        valueListenable: ThemeManager.instance.notifier,
        builder: (context, tokens, _) {
          return ValueListenableBuilder<Locale>(
            valueListenable: localeNotifier,
            builder: (context, locale, _) {
              return ValueListenableBuilder<ThemeMode>(
                valueListenable: themeModeNotifier,
                builder: (context, themeMode, __) {
                  return MaterialApp.router(
                    title: trId('fyc'),
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
                    const ChessGameReadyBanner(),
                    Expanded(child: child ?? const SizedBox()),
                  ],
                ),
              );
            },
          );
        },
      );
      },
      ),
    );
  }
}
// trigger build
