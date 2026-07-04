import 'dart:convert';
import 'package:flutter/foundation.dart';
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
import 'service_locator.dart';

final localeNotifier = ValueNotifier<Locale>(const Locale('ta'));
final themeModeNotifier = ValueNotifier<ThemeMode>(ThemeMode.light);

ThemeMode themeModeFromString(String s) => switch (s) {
      'dark' => ThemeMode.dark,
      'system' => ThemeMode.system,
      _ => ThemeMode.light,
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
  SyncService.triggerSync();
  await Firebase.initializeApp();
  FirebaseMessaging.onBackgroundMessage(_onBackgroundMessage);
  await FirebaseMessaging.instance.requestPermission(alert: true, badge: true, sound: true);
  await LocalNotifications.init();
  LocalNotifications.onTapRoute = (route) {
    final context = appRouter.routerDelegate.navigatorKey.currentContext;
    if (context != null && route.isNotEmpty) context.go(route);
  };
  await initServiceLocator();
  localeNotifier.value = Locale(sl<LocalStorage>().getLang());
  themeModeNotifier.value = themeModeFromString(sl<LocalStorage>().getTheme());
  
  _warmUpBackend();
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
            _handleNotificationClick(appRouter.routerDelegate.navigatorKey.currentContext!, message);
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
        if (mounted) {
          _handleNotificationClick(appRouter.routerDelegate.navigatorKey.currentContext!, message);
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
                theme: AppTheme.light,
                darkTheme: AppTheme.dark,
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
