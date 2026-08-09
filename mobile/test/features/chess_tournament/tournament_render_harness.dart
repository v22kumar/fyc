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
import 'package:fyc_connect/features/chess_tournament/domain/repositories/tournament_repository.dart';
import 'package:fyc_connect/features/chess_tournament/presentation/bloc/tournament_bloc.dart';
import 'package:fyc_connect/features/chess_tournament/presentation/screens/tournament_list_screen.dart';
import 'package:fyc_connect/features/chess_tournament/presentation/screens/tournament_screen.dart';
import 'package:fyc_connect/service_locator.dart';

import 'fake_tournament_repository.dart';
import 'tournament_fixtures.dart';

/// Photographs a chess tournament from creation to champion — the REAL
/// screens, driven through the real bloc over a fake repository.
///
/// A camera, not an assertion suite — named without `_test` so `flutter test`
/// never collects it. Run deliberately:
///
///     flutter test test/features/chess_tournament/tournament_render_harness.dart
const _shotKey = Key('shot-boundary');

Future<void> _shoot(WidgetTester tester, String name) async {
  for (var i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
  final boundary = find.byKey(_shotKey).evaluate().first.renderObject!
      as RenderRepaintBoundary;
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

UserModel _organiser() => const UserModel(
      id: kOrganiserId,
      phoneNumber: '+919000000001',
      role: 'ADMIN',
      isVerified: true,
      preferredLanguage: 'en',
      fullNameEn: 'FYC Organiser');

UserModel _player() => UserModel(
      id: uid(15),
      phoneNumber: '+919000000015',
      role: 'USER',
      isVerified: true,
      preferredLanguage: 'en',
      fullNameEn: 'Prakash N.');

Future<void> _pump(
  WidgetTester tester, {
  required TournamentRepository repo,
  required UserModel as,
  bool list = false,
  Size size = const Size(390, 1400),
}) async {
  SharedPreferences.setMockInitialValues({'fyc_has_session': true});
  final prefs = await SharedPreferences.getInstance();
  final storage = LocalStorage(prefs);
  await storage.saveLang('en');
  await storage.saveCachedUser(as.toJson());
  if (sl.isRegistered<LocalStorage>()) sl.unregister<LocalStorage>();
  sl.registerSingleton<LocalStorage>(storage);

  final authRepo = _Repo(as);
  final auth = AuthBloc(
    sendOtp: SendOtpUseCase(authRepo),
    verifyOtp: VerifyOtpUseCase(authRepo),
    registerUser: RegisterUserUseCase(authRepo),
    repository: authRepo,
    storage: storage,
  )..add(const AuthCheckRequested());

  await tester.binding.setSurfaceSize(size);
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    MultiBlocProvider(
      providers: [
        BlocProvider.value(value: auth),
        RepositoryProvider<TournamentRepository>.value(value: repo),
      ],
      child: MaterialApp(
        theme: AppTheme.lightFor('en'),
        builder: (_, child) => RepaintBoundary(key: _shotKey, child: child),
        home: list
            ? BlocProvider(
                create: (_) => TournamentListBloc(repo),
                child: const TournamentListScreen())
            : BlocProvider(
                create: (_) => TournamentBloc(repo)
                  ..add(TournamentRequested(uid(1000))),
                child: TournamentScreen(tournamentId: uid(1000))),
      ),
    ),
  );
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

  testWidgets('50 · the list', (t) async {
    await _pump(t,
        repo: FakeTournamentRepository(stageOpenEmpty),
        as: _player(),
        list: true,
        size: const Size(390, 844));
    await _shoot(t, '50_list');
  });

  testWidgets('51 · open, empty — organiser', (t) async {
    await _pump(t,
        repo: FakeTournamentRepository(stageOpenEmpty), as: _organiser());
    await _shoot(t, '51_open_empty');
  });

  testWidgets('52 · approvals + roster — organiser', (t) async {
    await _pump(t,
        repo: FakeTournamentRepository(stageOpenWithPending),
        as: _organiser());
    await _shoot(t, '52_approvals_roster');
  });

  testWidgets('53 · ready to start, roster visible — organiser', (t) async {
    await _pump(t,
        repo: FakeTournamentRepository(stageClosedReadyToStart),
        as: _organiser());
    await _shoot(t, '53_ready_to_start');
  });

  testWidgets('54 · my turn — player sees Ready without the bracket',
      (t) async {
    await _pump(t, repo: FakeTournamentRepository(stageMyTurn), as: _player());
    await _shoot(t, '54_player_my_turn');
  });

  testWidgets('55 · round one — organiser worklist', (t) async {
    await _pump(t,
        repo: FakeTournamentRepository(stageRoundOneLive), as: _organiser());
    await _shoot(t, '55_organiser_worklist');
  });

  testWidgets('56 · between rounds — start semi-finals', (t) async {
    await _pump(t,
        repo: FakeTournamentRepository(stageBetweenRounds), as: _organiser());
    await _shoot(t, '56_between_rounds');
  });

  testWidgets('57 · semi-finals — bracket opens on the live round', (t) async {
    await _pump(t,
        repo: FakeTournamentRepository(stageSemisPhysical), as: _organiser());
    await _shoot(t, '57_semis');
  });

  testWidgets('58 · completed — champion, runner-up, and the final visible',
      (t) async {
    await _pump(t,
        repo: FakeTournamentRepository(stageCompleted), as: _organiser());
    await _shoot(t, '58_completed');
  });
}
