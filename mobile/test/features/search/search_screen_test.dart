import 'package:dartz/dartz.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:fyc_connect/core/error/failures.dart';
import 'package:fyc_connect/core/storage/local_storage.dart';
import 'package:fyc_connect/features/auth/data/models/user_model.dart';
import 'package:fyc_connect/features/auth/domain/entities/user_entity.dart';
import 'package:fyc_connect/features/auth/domain/repositories/auth_repository.dart';
import 'package:fyc_connect/features/auth/domain/usecases/register_user_usecase.dart';
import 'package:fyc_connect/features/auth/domain/usecases/send_otp_usecase.dart';
import 'package:fyc_connect/features/auth/domain/usecases/verify_otp_usecase.dart';
import 'package:fyc_connect/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:fyc_connect/features/auth/presentation/bloc/auth_event.dart';
import 'package:fyc_connect/features/search/domain/entities/search_hit.dart';
import 'package:fyc_connect/features/search/domain/repositories/search_repository.dart';
import 'package:fyc_connect/features/search/presentation/screens/search_screen.dart';

/// The screen that answered "No results found" to its own suggested query.
///
/// These pin the two things the rewrite moved off the widget and onto the
/// server: the order results appear in, and where tapping one goes. Both used
/// to be invented here — ranking out of per-type buckets received in arbitrary
/// order, and routing out of a hand-kept `type → section` map that sent every
/// result to a list index.
class _Repo implements SearchRepository {
  _Repo(this.hits);
  final List<SearchHit> hits;
  String? lastQuery;

  @override
  Future<List<SearchHit>> search(String query, {String? lang}) async {
    lastQuery = query;
    return hits;
  }
}

const _arun = UserModel(
  id: 'u1', phoneNumber: '+919000000001', role: 'USER', isVerified: true,
  preferredLanguage: 'en', fullNameEn: 'Arun Kumar', fullNameTa: 'அருண்',
);

/// A signed-in member, because a search result on a personal route goes
/// through `pushMemberRoute` — which asks for a name when there isn't one.
class _Auth implements AuthRepository {
  @override
  Future<Either<Failure, UserEntity>> getMe() async => const Right(_arun);
  @override
  Future<void> logout() async {}
  @override
  dynamic noSuchMethod(Invocation i) => throw UnimplementedError();
}

Future<void> _pump(WidgetTester tester, _Repo repo,
    {List<String> extraRoutes = const []}) async {
  SharedPreferences.setMockInitialValues({
    'fyc_has_session': true,
    'fyc_auth_token': 'a-real-token',
  });
  await GetIt.I.reset();
  final storage = LocalStorage(await SharedPreferences.getInstance());
  await storage.saveCachedUser(_arun.toJson());
  GetIt.I.registerSingleton<LocalStorage>(storage);
  final auth = _Auth();
  final bloc = AuthBloc(
    sendOtp: SendOtpUseCase(auth), verifyOtp: VerifyOtpUseCase(auth),
    registerUser: RegisterUserUseCase(auth), repository: auth,
    storage: storage,
  )..add(const AuthCheckRequested());
  GetIt.I.registerSingleton<AuthBloc>(bloc);

  final router = GoRouter(
    initialLocation: '/search',
    routes: [
      GoRoute(path: '/search', builder: (_, __) => SearchScreen(repo: repo)),
      for (final r in extraRoutes)
        GoRoute(path: r, builder: (_, __) => Text('ARRIVED $r')),
    ],
  );
  await tester.pumpWidget(MaterialApp.router(routerConfig: router));
  await tester.pumpAndSettle();
}

void main() {
  tearDown(() => GetIt.I.reset());

  testWidgets('a place is offered before the things that mention it',
      (tester) async {
    final repo = _Repo(const [
      SearchHit(id: 'events', type: 'DESTINATION', title: 'Events',
          route: '/events', score: 210),
      SearchHit(id: 'e1', type: 'EVENT', title: 'Sports Meet',
          subtitle: 'Event', route: '/events', score: 60),
    ]);
    await _pump(tester, repo);

    await tester.enterText(find.byType(TextField), 'Events');
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();

    expect(find.text('GO TO'), findsOneWidget,
        reason: '"go here" is a different answer from "here is a match"');
    expect(find.text('Events'), findsWidgets);
    expect(find.text('Sports Meet'), findsOneWidget);
  });

  testWidgets('tapping a result goes where the server said, not to a section',
      (tester) async {
    final repo = _Repo(const [
      SearchHit(id: 'u1', type: 'USER', title: 'Arun Kumar',
          subtitle: 'Member', route: '/members/u1', score: 65),
    ]);
    await _pump(tester, repo, extraRoutes: ['/members/:id']);

    await tester.enterText(find.byType(TextField), 'kumar');
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Arun Kumar'));
    await tester.pumpAndSettle();

    // The old screen mapped USER -> '/directory' and dropped you on the roster.
    expect(find.text('ARRIVED /members/:id'), findsOneWidget);
  });

  testWidgets('results are rendered in the order they arrive', (tester) async {
    final repo = _Repo(const [
      SearchHit(id: 'a', type: 'EVENT', title: 'Exact Name', route: '/events',
          score: 110),
      SearchHit(id: 'b', type: 'TOURNAMENT', title: 'Mentions It',
          route: '/sports', score: 30),
    ]);
    await _pump(tester, repo);

    await tester.enterText(find.byType(TextField), 'exact name');
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();

    final exact = tester.getTopLeft(find.text('Exact Name')).dy;
    final weaker = tester.getTopLeft(find.text('Mentions It')).dy;
    expect(exact, lessThan(weaker),
        reason: 'ranking is the server\'s answer and must survive rendering');
  });

  testWidgets('one letter is not sent to the server', (tester) async {
    final repo = _Repo(const []);
    await _pump(tester, repo);

    await tester.enterText(find.byType(TextField), 'a');
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();

    expect(repo.lastQuery, isNull, reason: 'the server rejects it with a 422');
  });

  testWidgets('an empty answer still leaves somewhere to go', (tester) async {
    final repo = _Repo(const []);
    await _pump(tester, repo);

    await tester.enterText(find.byType(TextField), 'zzzz');
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();

    expect(find.text('No results found.'), findsOneWidget);
    // A bare "no results" on a black screen is where members were left.
    expect(find.text('Blood'), findsOneWidget);
    expect(find.text('Events'), findsOneWidget);
  });
}
