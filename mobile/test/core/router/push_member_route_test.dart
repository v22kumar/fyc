import 'package:dartz/dartz.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:fyc_connect/core/error/failures.dart';
import 'package:fyc_connect/core/router/app_router.dart';
import 'package:fyc_connect/core/storage/local_storage.dart';
import 'package:fyc_connect/features/auth/data/models/user_model.dart';
import 'package:fyc_connect/features/auth/domain/entities/user_entity.dart';
import 'package:fyc_connect/features/auth/domain/repositories/auth_repository.dart';
import 'package:fyc_connect/features/auth/domain/usecases/register_user_usecase.dart';
import 'package:fyc_connect/features/auth/domain/usecases/send_otp_usecase.dart';
import 'package:fyc_connect/features/auth/domain/usecases/verify_otp_usecase.dart';
import 'package:fyc_connect/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:fyc_connect/features/auth/presentation/bloc/auth_event.dart';

/// The tap that went nowhere.
///
/// The app opens without a login wall on purpose — identity is a step in an
/// action, not a gate at the door — and `kMembersOnly` enforces that by
/// redirecting a signed-out member away from personal routes. But a redirect
/// is a backstop, not an answer: `context.push('/me')` on a fresh install
/// bounced straight back to Home, so the top-right avatar, the notification
/// bell and the members tile were all buttons that visibly did nothing. On a
/// fresh install that is every personal tap, and the avatar is the control
/// people reach for when they want to sign in — which meant there was no way
/// to sign in from the front page at all.
///
/// [pushMemberRoute] is the fix, and these pin both halves of it: a personal
/// route asks who you are first, a public one is never interrupted.
class _Repo implements AuthRepository {
  @override
  Future<Either<Failure, UserEntity>> getMe() async => const Right(_arun);

  @override
  Future<void> logout() async {}

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('not used by these tests');
}

const _arun = UserModel(
  id: 'u1',
  phoneNumber: '+919000000001',
  role: 'USER',
  isVerified: true,
  preferredLanguage: 'en',
  fullNameEn: 'Arun Kumar',
  fullNameTa: 'அருண் குமார்',
);

/// A genuinely signed-in member has both the session marker and a token — the
/// token in the legacy plaintext slot, because the Keystore has no platform
/// channel under `flutter test`.
Future<AuthBloc> _register({required bool signedIn}) async {
  SharedPreferences.setMockInitialValues({
    if (signedIn) 'fyc_has_session': true,
    if (signedIn) 'fyc_auth_token': 'a-real-token',
  });
  final storage = LocalStorage(await SharedPreferences.getInstance());
  if (signedIn) await storage.saveCachedUser(_arun.toJson());
  final repo = _Repo();
  final bloc = AuthBloc(
    sendOtp: SendOtpUseCase(repo),
    verifyOtp: VerifyOtpUseCase(repo),
    registerUser: RegisterUserUseCase(repo),
    repository: repo,
    storage: storage,
  );
  if (signedIn) bloc.add(const AuthCheckRequested());
  await GetIt.I.reset();
  GetIt.I.registerSingleton<AuthBloc>(bloc);
  GetIt.I.registerSingleton<LocalStorage>(storage);
  return bloc;
}

/// Two screens and a button, which is all the helper needs to be observed:
/// did we leave Home, and was anything asked of us on the way?
Widget _app(String route) {
  final router = GoRouter(
    initialLocation: '/app',
    routes: [
      GoRoute(
        path: '/app',
        builder: (_, __) => Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => pushMemberRoute(context, route),
              child: const Text('go'),
            ),
          ),
        ),
      ),
      GoRoute(path: '/members', builder: (_, __) => const Text('THE DIRECTORY')),
      GoRoute(path: '/events', builder: (_, __) => const Text('THE EVENTS')),
    ],
  );
  return MaterialApp.router(routerConfig: router);
}

void main() {
  tearDown(() => GetIt.I.reset());

  testWidgets('a personal route asks who you are before it opens',
      (tester) async {
    await _register(signedIn: false);
    await tester.pumpWidget(_app('/members'));
    await tester.pump(const Duration(milliseconds: 20));

    await tester.tap(find.text('go'));
    await tester.pumpAndSettle();

    // The sheet, not the silent bounce back to Home the redirect used to give.
    expect(find.text('Sign in'), findsOneWidget);
    expect(find.text('THE DIRECTORY'), findsNothing);
  });

  testWidgets('dismissing the sheet simply does not navigate', (tester) async {
    await _register(signedIn: false);
    await tester.pumpWidget(_app('/members'));
    await tester.pump(const Duration(milliseconds: 20));

    await tester.tap(find.text('go'));
    await tester.pumpAndSettle();
    // Tapping the scrim is how a member says "not now" — an ordinary answer.
    await tester.tapAt(const Offset(20, 20));
    await tester.pumpAndSettle();

    expect(find.text('Sign in'), findsNothing);
    expect(find.text('THE DIRECTORY'), findsNothing);
    expect(find.text('go'), findsOneWidget);
  });

  testWidgets('a signed-in member goes straight through', (tester) async {
    await _register(signedIn: true);
    await tester.pumpWidget(_app('/members'));
    await tester.pump(const Duration(milliseconds: 20));

    await tester.tap(find.text('go'));
    await tester.pumpAndSettle();

    expect(find.text('THE DIRECTORY'), findsOneWidget);
    expect(find.text('Sign in'), findsNothing);
  });

  testWidgets('a public route is never interrupted', (tester) async {
    await _register(signedIn: false);
    await tester.pumpWidget(_app('/events'));
    await tester.pump(const Duration(milliseconds: 20));

    await tester.tap(find.text('go'));
    await tester.pumpAndSettle();

    // The club's noticeboard stays open to anyone who installed the app.
    expect(find.text('THE EVENTS'), findsOneWidget);
    expect(find.text('Sign in'), findsNothing);
  });
}
