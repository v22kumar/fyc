import 'dart:io';
import 'dart:ui' as ui;

import 'package:dartz/dartz.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:fyc_connect/core/error/failures.dart';
import 'package:fyc_connect/core/network/api_client.dart';
import 'package:fyc_connect/core/storage/local_storage.dart';
import 'package:fyc_connect/core/theme/app_theme.dart';
import 'package:fyc_connect/features/auth/data/models/user_model.dart';
import 'package:fyc_connect/features/auth/domain/entities/user_entity.dart';
import 'package:fyc_connect/features/auth/domain/repositories/auth_repository.dart';
import 'package:fyc_connect/features/auth/domain/usecases/register_user_usecase.dart';
import 'package:fyc_connect/features/auth/domain/usecases/send_otp_usecase.dart';
import 'package:fyc_connect/features/auth/domain/usecases/verify_otp_usecase.dart';
import 'package:fyc_connect/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:fyc_connect/features/auth/presentation/bloc/auth_event.dart';
import 'package:fyc_connect/features/chess_tournament/chess_tournament_detail_screen.dart';
import 'package:fyc_connect/features/chess_tournament/chess_tournament_list_screen.dart';
import 'package:fyc_connect/features/chess_tournament/chess_tournament_models.dart';
import 'package:fyc_connect/service_locator.dart';

import 'tournament_fixtures.dart';

/// Photographs a chess tournament from creation to champion.
///
/// A camera, not an assertion suite — named without `_test` so `flutter test`
/// never collects it. Run it deliberately:
///
///     flutter test test/features/chess_tournament/tournament_render_harness.dart
///
/// The screens are the real ones, driven through the real `ApiClient`; only
/// the socket is replaced. Anything wrong in these pictures is wrong in the
/// app.
const _shotKey = Key('shot-boundary');

Future<void> _shoot(WidgetTester tester, String name) async {
  // `runAsync` lets the real async plumbing below Dio — stream reads, the
  // interceptor chain — actually run. Inside fake-async those futures are
  // parked, so the screen sat on its spinner however long we pumped, and the
  // first shot was a loading indicator.
  await tester.runAsync(() => Future<void>.delayed(
      const Duration(milliseconds: 120)));
  for (var i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
  final boundary =
      find.byKey(_shotKey).evaluate().first.renderObject! as RenderRepaintBoundary;
  final image = await boundary.toImage(pixelRatio: 2.0);
  final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  final dir = Directory('build/ui_shots')..createSync(recursive: true);
  File('${dir.path}/$name.png').writeAsBytesSync(bytes!.buffer.asUint8List());
}

class _Repo implements AuthRepository {
  _Repo(this.user);
  final UserModel user;
  @override
  Future<Either<Failure, UserEntity>> getMe() async => Right(user);
  @override
  Future<void> logout() async {}
  @override
  dynamic noSuchMethod(Invocation i) => throw UnimplementedError();
}

/// The organiser sees manager controls; a player sees their own status.
UserModel _organiser() => UserModel(
      id: kOrganiserId,
      phoneNumber: '+919000000001',
      role: 'ADMIN',
      isVerified: true,
      preferredLanguage: 'en',
      fullNameEn: 'FYC Organiser',
    );

UserModel _player() => UserModel(
      id: uid(15),
      phoneNumber: '+919000000015',
      role: 'USER',
      isVerified: true,
      preferredLanguage: 'en',
      fullNameEn: 'Prakash N.',
    );

Future<void> _pump(
  WidgetTester tester, {
  required Map<String, Object> routes,
  required Widget screen,
  required UserModel as,
  Size size = const Size(390, 844),
}) async {
  SharedPreferences.setMockInitialValues({'fyc_has_session': true});
  final prefs = await SharedPreferences.getInstance();
  final storage = LocalStorage(prefs);
  await storage.saveLang('en');
  await storage.saveCachedUser(as.toJson());

  if (sl.isRegistered<LocalStorage>()) sl.unregister<LocalStorage>();
  sl.registerSingleton<LocalStorage>(storage);

  final client = ApiClient(storage)..dio.httpClientAdapter = FakeAdapter(routes);
  if (sl.isRegistered<ApiClient>()) sl.unregister<ApiClient>();
  sl.registerSingleton<ApiClient>(client);

  final repo = _Repo(as);
  final auth = AuthBloc(
    sendOtp: SendOtpUseCase(repo),
    verifyOtp: VerifyOtpUseCase(repo),
    registerUser: RegisterUserUseCase(repo),
    repository: repo,
    storage: storage,
  )..add(const AuthCheckRequested());

  await tester.binding.setSurfaceSize(size);
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(BlocProvider.value(
    value: auth,
    child: MaterialApp(
      theme: AppTheme.lightFor('en'),
      builder: (_, child) => RepaintBoundary(key: _shotKey, child: child),
      home: screen,
    ),
  ));
  await tester.pump();
}

void main() {
  setUpAll(() async {
    for (final (family, file) in [
      ('Plus Jakarta Sans', 'assets/fonts/PlusJakartaSans-400.ttf'),
      ('Plus Jakarta Sans', 'assets/fonts/PlusJakartaSans-700.ttf'),
      ('Noto Sans Tamil', 'assets/fonts/NotoSansTamil-400.ttf'),
    ]) {
      final loader = FontLoader(family)
        ..addFont(File(file).readAsBytes().then((b) => b.buffer.asByteData()));
      await loader.load();
    }
    final icons = File(
        '/opt/flutter/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf');
    if (icons.existsSync()) {
      final loader = FontLoader('MaterialIcons')
        ..addFont(icons.readAsBytes().then((b) => b.buffer.asByteData()));
      await loader.load();
    }
  });

  Widget detail(Map<String, dynamic> stage) => ChessTournamentDetailScreen(
        tournamentId: uid(1000),
        preload: ChessTournamentDetail.fromJson(stage),
      );

  testWidgets('40 · the list a member opens', (t) async {
    await _pump(t,
        routes: {'/chess/tournaments': stageList},
        screen: ChessTournamentListScreen(
          preload: [for (final j in stageList) ChessTournament.fromJson(j)],
        ),
        as: _player());
    await _shoot(t, '40_tournament_list');
  });

  testWidgets('41 · created, nobody has joined', (t) async {
    await _pump(t,
        routes: {'/chess/tournaments/': stageOpenEmpty},
        screen: detail(stageOpenEmpty),
        as: _organiser());
    await _shoot(t, '41_open_empty');
  });

  testWidgets('42 · joining, three waiting on the manager', (t) async {
    await _pump(t,
        routes: {'/chess/tournaments/': stageOpenWithPending},
        screen: detail(stageOpenWithPending),
        as: _organiser());
    await _shoot(t, '42_approvals');
  });

  testWidgets('43 · a player waiting to be let in', (t) async {
    await _pump(t,
        routes: {'/chess/tournaments/': stagePlayerPending},
        screen: detail(stagePlayerPending),
        as: _player());
    await _shoot(t, '43_player_pending');
  });

  testWidgets('44 · closed, eight in, waiting to start', (t) async {
    await _pump(t,
        routes: {'/chess/tournaments/': stageClosedReadyToStart},
        screen: detail(stageClosedReadyToStart),
        as: _organiser());
    await _shoot(t, '44_ready_to_start');
  });

  testWidgets('45 · round one in play', (t) async {
    await _pump(t,
        routes: {'/chess/tournaments/': stageRoundOneLive},
        screen: detail(stageRoundOneLive),
        as: _organiser(),
        size: const Size(390, 1500));
    await _shoot(t, '45_round_one_live');
  });

  testWidgets('46 · between rounds', (t) async {
    await _pump(t,
        routes: {'/chess/tournaments/': stageBetweenRounds},
        screen: detail(stageBetweenRounds),
        as: _organiser(),
        size: const Size(390, 1500));
    await _shoot(t, '46_between_rounds');
  });

  testWidgets('47 · semi-finals, one played in person', (t) async {
    await _pump(t,
        routes: {'/chess/tournaments/': stageSemisPhysical},
        screen: detail(stageSemisPhysical),
        as: _organiser(),
        size: const Size(390, 1500));
    await _shoot(t, '47_semis_physical');
  });

  testWidgets('48 · the champion', (t) async {
    await _pump(t,
        routes: {'/chess/tournaments/': stageCompleted},
        screen: detail(stageCompleted),
        as: _organiser(),
        size: const Size(390, 1500));
    await _shoot(t, '48_completed');
  });
}
