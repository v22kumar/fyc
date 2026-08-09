import 'package:dartz/dartz.dart';
import 'package:flutter/material.dart';
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
import 'package:fyc_connect/features/chess_tournament/presentation/screens/tournament_screen.dart';
import 'package:fyc_connect/features/chess_tournament/presentation/widgets/bracket_view.dart';
import 'package:fyc_connect/service_locator.dart';

import 'fake_tournament_repository.dart';
import 'tournament_fixtures.dart';

/// The three surfaces, each held to the defect that made it necessary.
///
/// Every test here is a regression test for something photographed broken in
/// the walkthrough (docs/chess/00-tournament-walkthrough.md): controls buried
/// in the bracket, the bracket opening on round 1 forever, the roster hidden
/// at the moment of the draw, a finished tournament never showing the final.
class _AuthRepo implements AuthRepository {
  _AuthRepo(this.user);
  final UserModel user;
  @override
  Future<Either<Failure, UserEntity>> getMe() async => Right(user);
  @override
  Future<void> logout() async {}
  @override
  dynamic noSuchMethod(Invocation i) => throw UnimplementedError();
}

UserModel _user(String id, {bool admin = false, String name = 'Member'}) =>
    UserModel(
      id: id,
      phoneNumber: '+919000000001',
      role: admin ? 'ADMIN' : 'USER',
      isVerified: true,
      preferredLanguage: 'en',
      fullNameEn: name,
    );

Future<FakeTournamentRepository> _pump(
  WidgetTester tester,
  Map<String, dynamic> stage, {
  required UserModel as,
  double textScale = 1.0,
}) async {
  SharedPreferences.setMockInitialValues({'fyc_has_session': true});
  final prefs = await SharedPreferences.getInstance();
  final storage = LocalStorage(prefs);
  await storage.saveLang('en');
  await storage.saveCachedUser(as.toJson());
  if (sl.isRegistered<LocalStorage>()) sl.unregister<LocalStorage>();
  sl.registerSingleton<LocalStorage>(storage);

  final repo = FakeTournamentRepository(stage);
  final authRepo = _AuthRepo(as);
  final auth = AuthBloc(
    sendOtp: SendOtpUseCase(authRepo),
    verifyOtp: VerifyOtpUseCase(authRepo),
    registerUser: RegisterUserUseCase(authRepo),
    repository: authRepo,
    storage: storage,
  )..add(const AuthCheckRequested());

  await tester.binding.setSurfaceSize(const Size(390, 1400));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(MultiBlocProvider(
    providers: [
      BlocProvider.value(value: auth),
      RepositoryProvider<TournamentRepository>.value(value: repo),
    ],
    child: MaterialApp(
      theme: AppTheme.lightFor('en'),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context)
            .copyWith(textScaler: TextScaler.linear(textScale)),
        child: child!,
      ),
      home: BlocProvider(
        create: (_) =>
            TournamentBloc(repo)..add(TournamentRequested(uid(1000))),
        child: TournamentScreen(tournamentId: uid(1000)),
      ),
    ),
  ));
  // Let the auth check and the tournament load settle.
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 60));
  }
  return repo;
}

void main() {
  group('the player surface —', () {
    testWidgets('Ready is on screen without touching the bracket',
        (tester) async {
      // The defect: the only Ready button lived inside a pannable canvas, and
      // the player's first job was to find their own name on a diagram.
      await _pump(tester, stageMyTurn, as: _user(uid(15), name: 'Prakash N.'));

      expect(find.text("I'm ready"), findsOneWidget);
      expect(find.text('You vs Latha M.'), findsOneWidget);
    });

    testWidgets('tapping Ready reaches the seam', (tester) async {
      final repo =
          await _pump(tester, stageMyTurn, as: _user(uid(15)));

      await tester.tap(find.text("I'm ready"));
      await tester.pump(const Duration(milliseconds: 60));

      expect(repo.calls.any((c) => c.startsWith('ready:')), isTrue);
    });

    testWidgets('a knocked-out player is told plainly, with who',
        (tester) async {
      await _pump(tester, stageBetweenRounds,
          as: _user(uid(11), name: 'Suresh K.'));
      // Suresh (index 1) lost round 1 to Arun (index 0).
      expect(find.textContaining("You're out"), findsOneWidget);
      expect(find.textContaining('Arun Kumar'), findsWidgets);
    });
  });

  group('the organiser surface —', () {
    testWidgets('the worklist names what blocks the round, on screen',
        (tester) async {
      // The defect: by round two, result buttons sat 340px off the right edge.
      // A vertical worklist has no off-screen.
      await _pump(tester, stageRoundOneLive,
          as: _user(kOrganiserId, admin: true));

      expect(find.textContaining('to finish before'), findsOneWidget);
      expect(find.textContaining('Win:'), findsWidgets);
    });

    testWidgets('a finished round offers Start Semi-finals', (tester) async {
      await _pump(tester, stageBetweenRounds,
          as: _user(kOrganiserId, admin: true));

      expect(find.text('Start Semi-finals'), findsOneWidget);
    });

    testWidgets('the roster is visible at the moment of the draw',
        (tester) async {
      // The defect: the approvals card vanished once the last pending entry
      // was decided, so the irreversible "draw the bracket" press showed no
      // list of who was being drawn.
      await _pump(tester, stageClosedReadyToStart,
          as: _user(kOrganiserId, admin: true));

      expect(find.text('Approved players'), findsOneWidget);
      expect(find.textContaining('enter the draw'), findsOneWidget);
      expect(find.text('Arun Kumar'), findsOneWidget);
    });

    testWidgets('recording a result asks for confirmation, naming the winner',
        (tester) async {
      final repo = await _pump(tester, stageRoundOneLive,
          as: _user(kOrganiserId, admin: true));

      await tester.tap(find.textContaining('Win: Latha M.').first);
      await tester.pump();
      expect(find.text('Win: Latha M.?'), findsOneWidget);

      await tester.tap(find.text('Record winner').last);
      await tester.pump(const Duration(milliseconds: 60));
      expect(repo.calls.any((c) => c.startsWith('result:')), isTrue);
    });
  });

  group('the spectator surface —', () {
    testWidgets('the bracket opens on the round being played', (tester) async {
      // THE defect: the bracket always opened on round 1, so the semi-finals
      // were played while the screen showed the quarter-finals.
      await _pump(tester, stageSemisPhysical,
          as: _user('spectator-1', name: 'Watcher'));

      final state =
          tester.state<ScrollableState>(find.descendant(
        of: find.byType(BracketView),
        matching: find.byType(Scrollable),
      ));
      expect(state.position.pixels, greaterThan(0),
          reason: 'round 2 is live; the view must not sit on round 1');
    });

    testWidgets('a completed tournament shows the final and both names',
        (tester) async {
      // The defect: a finished tournament never showed you the final.
      await _pump(tester, stageCompleted,
          as: _user('spectator-1', name: 'Watcher'));

      expect(find.text('Champion'), findsOneWidget);
      expect(find.textContaining('vs Devi A.'), findsOneWidget,
          reason: 'the runner-up belongs beside the champion');
      final state =
          tester.state<ScrollableState>(find.descendant(
        of: find.byType(BracketView),
        matching: find.byType(Scrollable),
      ));
      expect(state.position.pixels, greaterThan(0),
          reason: 'completed opens on the final, not the quarter-finals');
    });

    testWidgets('a live match is visibly live', (tester) async {
      await _pump(tester, stageRoundOneLive,
          as: _user('spectator-1', name: 'Watcher'));
      expect(find.text('LIVE'), findsWidgets);
    });
  });

  group('accessibility —', () {
    // Elder members run their phones at large font sizes. An overflow throws
    // in a widget test, so pumping every surface at 1.3× IS the assertion.
    testWidgets('the player surface survives big system fonts',
        (tester) async {
      await _pump(tester, stageMyTurn,
          as: _user(uid(15), name: 'Prakash N.'), textScale: 1.3);
      expect(find.text("I'm ready"), findsOneWidget);
    });

    testWidgets('the organiser surface survives big system fonts',
        (tester) async {
      await _pump(tester, stageRoundOneLive,
          as: _user(kOrganiserId, admin: true), textScale: 1.3);
      expect(find.textContaining('Win:'), findsWidgets);
    });

    testWidgets('the registration surface survives big system fonts',
        (tester) async {
      await _pump(tester, stageOpenWithPending,
          as: _user(kOrganiserId, admin: true), textScale: 1.3);
      expect(find.text('Pending approvals'), findsOneWidget);
    });
  });
}
