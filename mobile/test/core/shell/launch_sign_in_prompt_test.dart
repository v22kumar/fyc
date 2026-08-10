import 'package:dartz/dartz.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:fyc_connect/core/design_system/shell/app_shell_v2.dart';
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

/// Opening the app asks who you are.
///
/// The club's call, and it reverses the older "no door" stance: the sign-in
/// sheet should meet a member at launch rather than waiting to be found.
/// Ignoring it stays a real answer — the noticeboard is still open to anyone.
///
/// The two things that must not go wrong: asking somebody we already know, and
/// asking again after they have said no once.
class _Repo implements AuthRepository {
  _Repo(this.result, {this.delay = Duration.zero});

  final Either<Failure, UserEntity> result;
  final Duration delay;

  @override
  Future<Either<Failure, UserEntity>> getMe() async {
    if (delay > Duration.zero) await Future<void>.delayed(delay);
    return result;
  }

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

Future<void> _register({
  required bool signedIn,
  bool cached = true,
  Duration checkTakes = Duration.zero,
}) async {
  SharedPreferences.setMockInitialValues({
    if (signedIn) 'fyc_has_session': true,
    if (signedIn) 'fyc_auth_token': 'a-real-token',
  });
  final storage = LocalStorage(await SharedPreferences.getInstance());
  if (signedIn && cached) await storage.saveCachedUser(_arun.toJson());
  final repo = _Repo(
      signedIn ? const Right(_arun) : const Left(AuthFailure('no session')),
      delay: checkTakes);
  final bloc = AuthBloc(
    sendOtp: SendOtpUseCase(repo),
    verifyOtp: VerifyOtpUseCase(repo),
    registerUser: RegisterUserUseCase(repo),
    repository: repo,
    storage: storage,
  );
  bloc.add(const AuthCheckRequested());
  await GetIt.I.reset();
  GetIt.I.registerSingleton<AuthBloc>(bloc);
  GetIt.I.registerSingleton<LocalStorage>(storage);
}

/// Mirrors the real tree: `main.dart` provides the AuthBloc above the router,
/// so the shell can read it.
Widget _app() => BlocProvider<AuthBloc>.value(
      value: GetIt.I<AuthBloc>(),
      child: const MaterialApp(
        home: AppShellV2(askWhoYouAreOnLaunch: true),
      ),
    );

void main() {
  setUp(() => AppShellV2.askedThisLaunch = false);
  tearDown(() => GetIt.I.reset());

  testWidgets('opening the app asks a stranger who they are', (tester) async {
    await _register(signedIn: false);
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    expect(find.text('Sign in'), findsOneWidget);
  });

  testWidgets('ignoring it leaves the noticeboard open', (tester) async {
    await _register(signedIn: false);
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    await tester.tapAt(const Offset(20, 20)); // dismiss via the scrim
    await tester.pumpAndSettle();

    expect(find.text('Sign in'), findsNothing);
    expect(find.byType(AppShellV2), findsOneWidget,
        reason: 'saying "not now" must not close the app or block a tab');
  });

  testWidgets('a member we already know is never asked', (tester) async {
    await _register(signedIn: true);
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    expect(find.text('Sign in'), findsNothing);
  });

  testWidgets('a slow session check is not mistaken for a stranger',
      (tester) async {
    // No cached profile, so the bloc cannot answer from storage — it has to
    // wait for `GET /me`. Until that lands the state is AuthInitial, which
    // means "we have not looked yet", NOT "signed out". Asking on it would put
    // a login sheet in front of a member of months on every cold start with a
    // slow network. This is the case the plain signed-in test cannot catch,
    // because there the cached profile answers before the first frame.
    await _register(
        signedIn: true, cached: false, checkTakes: const Duration(seconds: 1));
    await tester.pumpWidget(_app());
    await tester.pump(); // first frame — the check is still in flight

    expect(find.text('Sign in'), findsNothing,
        reason: 'must not ask before the answer is known');

    await tester.pumpAndSettle(const Duration(seconds: 2));
    expect(find.text('Sign in'), findsNothing,
        reason: 'and must not ask once the answer turns out to be "we know them"');
  });
}
