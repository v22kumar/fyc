/// DEV ONLY: walk every screen and save a PNG of each.
///
/// The app was built without anyone ever looking at it on a device. This drives
/// the REAL widget tree at a real phone size, visits each route in turn, and
/// writes what actually renders to disk — so a design review can be about what
/// is on screen rather than what the code suggests should be.
///
/// Not part of the shipped app and not referenced by anything.
///
///   flutter run -d linux -t lib/dev_screenshot_harness.dart \
///     --dart-define=API_BASE_URL=http://127.0.0.1:8151 \
///     --dart-define=TOKEN=... --dart-define=DEBUG_TOKEN=<same token> \
///     --dart-define=OUT=/tmp/shots
///
/// DEBUG_TOKEN is what actually authenticates: this embedder has no keyring, so
/// the token written through LocalStorage is swallowed and every authenticated
/// screen renders signed-out.
import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/l10n/app_localizations.dart';
import 'core/router/app_router.dart';
import 'core/storage/local_storage.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/presentation/bloc/auth_bloc.dart';
import 'main.dart' show localeNotifier;
import 'service_locator.dart';

const _token = String.fromEnvironment('TOKEN');
const _out = String.fromEnvironment('OUT', defaultValue: '/tmp/shots');

/// Comma-separated routes to visit instead of the full list.
///
/// The whole walk takes minutes, which is the wrong loop when you are iterating
/// on one screen. `--dart-define=ROUTES=/blood-donation` gets you a photograph
/// of that screen in seconds.
const _routesOverride = String.fromEnvironment('ROUTES');

/// Every screen a member can reach, in the order they'd meet them.
/// Routes needing an id are given one by the seeding script.
const _routes = <String>[
  '/lang-select',
  '/login',
  '/app',            // home tab of the shell
  '/search',
  '/me',
  '/profile',
  '/journey',
  '/feed',
  '/feed/create',
  '/blood-donation',
  '/blood-donation/register',
  '/blood-donation/directory',
  '/events',
  '/issues',
  '/issues/track',
  '/membership',
  '/certificate',
  '/gallery',
  '/directory',
  '/members',
  '/community',
  '/sports',
  '/green',
  '/green/register',
  '/notifications',
  '/announcements',
  '/opportunities',
  '/about',
  '/settings',
  '/settings/safety',
  '/chess',
  '/chess/local',
  '/chess/history',
  '/chess/challenge',
  '/chess/ai',
  '/chess/legends',
  '/chess/legacy',
  '/chess/tournaments',
  '/design-system',
];

final _rootKey = GlobalKey();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Let the app register its own services — registering LocalStorage first
  // makes initServiceLocator throw on the duplicate.
  // Locale data for dates. Without this DateFormat throws on any
  // non-English locale, which is most of this app's members.
  await initializeDateFormatting();
  await initServiceLocator();
  await sl<LocalStorage>().saveToken(_token);

  Directory(_out).createSync(recursive: true);

  runApp(ProviderScope(
    child: RepaintBoundary(
    key: _rootKey,
    // A phone-shaped viewport: reviewing a 1280px-wide desktop window would
    // hide exactly the crowding this is meant to find.
    child: Center(
      child: SizedBox(
        width: 412,
        height: 915,
        // The same wrapping the real app uses, so this reviews the real thing:
        // the auth bloc the screens read, and the per-language theme that picks
        // the correct script font.
        child: BlocProvider.value(
          value: sl<AuthBloc>(),
          child: ValueListenableBuilder<Locale>(
            valueListenable: localeNotifier,
            builder: (context, locale, _) => MaterialApp.router(
              debugShowCheckedModeBanner: false,
              theme: AppTheme.lightFor(locale.languageCode),
              routerConfig: appRouter,
              locale: locale,
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
            ),
          ),
        ),
      ),
    ),
  )));

  unawaited(_walk());
}

Future<void> _walk() async {
  // Let the first frame and any startup work settle before moving.
  await Future<void>.delayed(const Duration(seconds: 4));

  final routes = _routesOverride.isEmpty
      ? _routes
      : _routesOverride.split(',').map((r) => r.trim()).toList();

  for (var i = 0; i < routes.length; i++) {
    final route = routes[i];
    try {
      appRouter.go(route);
    } catch (e) {
      stderr.writeln('NAV FAILED $route: $e');
      continue;
    }
    // Real network, real images: give each screen time to actually load.
    await Future<void>.delayed(const Duration(milliseconds: 2600));
    // Home pops an "update available" sheet on entry, which in this build is an
    // artefact of the local backend's version number. Dismiss any modal sitting
    // above the screen so the review sees the screen.
    //
    // Only popups. This used to pop anything poppable, which quietly walked
    // back out of every nested route — a request for /blood-donation/directory
    // photographed /blood-donation instead, and looked like the route was
    // broken rather than the harness.
    final nav = appRouter.routerDelegate.navigatorKey.currentState;
    if (nav != null && nav.canPop()) {
      final top = ModalRoute.of(nav.context);
      if (top is PopupRoute) {
        nav.pop();
        await Future<void>.delayed(const Duration(milliseconds: 600));
      }
    }
    final name = '${i.toString().padLeft(2, '0')}'
        '${route.replaceAll('/', '_')}.png';
    await _capture('$_out/$name');
    stdout.writeln('captured $route');
  }
  stdout.writeln('DONE');
  exit(0);
}

Future<void> _capture(String path) async {
  try {
    final boundary =
        _rootKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
    if (boundary == null) return;
    final image = await boundary.toImage(pixelRatio: 2.0);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    if (bytes == null) return;
    File(path).writeAsBytesSync(bytes.buffer.asUint8List());
  } catch (e) {
    stderr.writeln('CAPTURE FAILED $path: $e');
  }
}
